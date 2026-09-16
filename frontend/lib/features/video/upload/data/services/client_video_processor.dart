import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../../shared/utils/app_logger.dart';

/// Result container for client-side video processing
class ClientVideoProcessResult {
  final File file;
  final bool wasOptimized;
  final bool isSuccess;
  final String? message;

  const ClientVideoProcessResult({
    required this.file,
    required this.wasOptimized,
    required this.isSuccess,
    this.message,
  });
}

/// Metadata extracted via client ffprobe
class ClientVideoMeta {
  final int width;
  final int height;
  final double duration;
  final String codec;
  final bool isPortrait;

  const ClientVideoMeta({
    required this.width,
    required this.height,
    required this.duration,
    required this.codec,
    required this.isPortrait,
  });
}

/// Robust on-device video processor targeting 480p H.265 (HEVC).
///
/// Designed with graceful fallback: if compression fails for any reason
/// (timeout, low memory, unsupported format), it returns the original file
/// so that the server worker can transcode it without user disruption.
class ClientVideoProcessor {
  /// Probes video metadata using FFprobeKit
  static Future<ClientVideoMeta?> probeVideo(String filePath) async {
    try {
      final session = await FFprobeKit.getMediaInformation(filePath);
      final info = session.getMediaInformation();
      if (info == null) return null;

      final streams = info.getStreams();
      if (streams.isEmpty) return null;

      int width = 0;
      int height = 0;
      String codec = 'unknown';

      for (final s in streams) {
        final codecType = s.getType();
        if (codecType == 'video') {
          width = s.getWidth()?.toInt() ?? 0;
          height = s.getHeight()?.toInt() ?? 0;
          codec = (s.getCodec() ?? 'unknown').toLowerCase();
          break;
        }
      }

      final durStr = info.getDuration();
      final duration = durStr != null ? (double.tryParse(durStr) ?? 0.0) : 0.0;

      // Detect rotation from tags
      int rotation = 0;
      for (final s in streams) {
        final tags = s.getTags();
        if (tags != null && tags['rotate'] != null) {
          rotation = int.tryParse(tags['rotate'].toString()) ?? 0;
        }
      }

      if (rotation.abs() == 90 || rotation.abs() == 270) {
        final temp = width;
        width = height;
        height = temp;
      }

      final isPortrait = height > width;

      return ClientVideoMeta(
        width: width,
        height: height,
        duration: duration,
        codec: codec,
        isPortrait: isPortrait,
      );
    } catch (e) {
      AppLogger.log('⚠️ ClientVideoProcessor: probe failed: $e');
      return null;
    }
  }

  /// Evaluates whether the video is already pre-optimized for 480p H.265/H.264
  static bool shouldCompress(ClientVideoMeta? meta, int fileSizeInBytes) {
    if (meta == null) return true;

    // Check if dimensions are already within 480p boundary
    final isAlready480p = meta.isPortrait ? (meta.width <= 480) : (meta.height <= 480);

    // Check if codec is modern web-streamable
    final isCompatibleCodec =
        meta.codec.contains('hevc') ||
        meta.codec.contains('h265') ||
        meta.codec.contains('h264') ||
        meta.codec.contains('avc');

    // If already 480p, compatible codec, and small file (< 35MB), skip compression
    if (isAlready480p && isCompatibleCodec && fileSizeInBytes <= 35 * 1024 * 1024) {
      AppLogger.log('🎯 ClientVideoProcessor: Video is already <= 480p. Skipping client compression.');
      return false;
    }

    return true;
  }

  /// Processes video on-device to 480p H.265 (HEVC) with graceful fallback.
  ///
  /// Never throws: on failure, returns [originalVideo] with [wasOptimized: false].
  static Future<ClientVideoProcessResult> processVideo({
    required File originalVideo,
    VoidCallback? onStarted,
    Function(double progress)? onProgress,
  }) async {
    if (!await originalVideo.exists()) {
      return ClientVideoProcessResult(
        file: originalVideo,
        wasOptimized: false,
        isSuccess: false,
        message: 'Original video file not found',
      );
    }

    final originalSize = await originalVideo.length();

    // Probe media info
    final meta = await probeVideo(originalVideo.path);

    // If video is already pre-optimized, skip local encode
    if (!shouldCompress(meta, originalSize)) {
      return ClientVideoProcessResult(
        file: originalVideo,
        wasOptimized: true,
        isSuccess: true,
        message: 'Video already 480p',
      );
    }

    // Acquire wakelock to prevent OS sleep during encode
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    String? outputPath;
    Session? activeSession;

    try {
      final tempDir = await getTemporaryDirectory();
      outputPath =
          '${tempDir.path}/opt_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final isPortrait = meta?.isPortrait ?? true;
      final scaleFilter = isPortrait
          ? "scale='min(480,iw)':-2"
          : "scale=-2:'min(480,ih)'";

      // 480p H.265 (HEVC) sweet spot: veryfast preset, CRF 23, 1000k bitrate, 2-sec GOP for instant zero-buffer streaming
      final cmd = '-y -i "${originalVideo.path}" '
          '-vf "$scaleFilter" '
          '-c:v libx265 -tag:v hvc1 -preset veryfast -crf 23 -pix_fmt yuv420p -threads 3 '
          '-maxrate 1000k -bufsize 1500k '
          '-x265-params keyint=60:min-keyint=30:scenecut=40 '
          '-c:a aac -b:a 80k -ar 44100 '
          '-movflags +faststart '
          '"$outputPath"';

      AppLogger.log('🎬 ClientVideoProcessor: Starting 480p H.265 encoding...');
      onStarted?.call();
      final duration = (meta?.duration != null && meta!.duration > 0)
          ? meta.duration
          : 30.0;

      final completer = Completer<Session>();

      final session = await FFmpegKit.executeAsync(
        cmd,
        (s) {
          if (!completer.isCompleted) completer.complete(s);
        },
        null,
        (statistics) {
          final timeMs = statistics.getTime();
          if (timeMs > 0 && duration > 0) {
            final pct = (timeMs / (duration * 1000)).clamp(0.0, 0.98);
            onProgress?.call(pct);
          }
        },
      );

      activeSession = session;

      // Timeout watchdog: allow up to 180 seconds for client compression
      final timeoutDuration = Duration(
        seconds: (duration * 3 + 60).toInt().clamp(60, 180),
      );

      final completedSession = await completer.future.timeout(timeoutDuration);
      final returnCode = await completedSession.getReturnCode();
      final isSuccess = ReturnCode.isSuccess(returnCode);

      if (isSuccess && await File(outputPath).exists()) {
        final compressedFile = File(outputPath);
        final compressedSize = await compressedFile.length();

        // Safety check: ensure file is non-empty and actually smaller or valid
        if (compressedSize > 10000) {
          final savingsPct = ((originalSize - compressedSize) / originalSize * 100).toInt();
          AppLogger.log(
            '✅ ClientVideoProcessor: 480p H.265 encode complete. '
            'Original: ${(originalSize / (1024 * 1024)).toStringAsFixed(1)}MB -> '
            'Compressed: ${(compressedSize / (1024 * 1024)).toStringAsFixed(1)}MB ($savingsPct% savings)',
          );

          onProgress?.call(1.0);
          return ClientVideoProcessResult(
            file: compressedFile,
            wasOptimized: true,
            isSuccess: true,
          );
        }
      }

      // If ReturnCode was not success, clean up output file
      AppLogger.log('⚠️ ClientVideoProcessor: FFmpeg return code: $returnCode');
      _cleanupFile(outputPath);
      return ClientVideoProcessResult(
        file: originalVideo,
        wasOptimized: false,
        isSuccess: false,
        message: 'FFmpeg non-zero return code',
      );
    } on TimeoutException {
      AppLogger.log('⚠️ ClientVideoProcessor: Encoding timed out. Falling back to server worker.');
      try {
        if (activeSession != null) {
          await FFmpegKit.cancel(activeSession.getSessionId());
        }
      } catch (_) {}
      _cleanupFile(outputPath);
      return ClientVideoProcessResult(
        file: originalVideo,
        wasOptimized: false,
        isSuccess: false,
        message: 'Timeout',
      );
    } catch (e) {
      AppLogger.log('⚠️ ClientVideoProcessor: Compression error: $e. Falling back to server worker.');
      _cleanupFile(outputPath);
      return ClientVideoProcessResult(
        file: originalVideo,
        wasOptimized: false,
        isSuccess: false,
        message: e.toString(),
      );
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  /// Generates a single-frame JPG thumbnail at 1.0s timestamp
  static Future<File?> generateThumbnail(File videoFile) async {
    try {
      if (!await videoFile.exists()) return null;
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final cmd = '-y -ss 00:00:01 -i "${videoFile.path}" -vframes 1 -q:v 2 "$outputPath"';
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && await File(outputPath).exists()) {
        return File(outputPath);
      }
      return null;
    } catch (e) {
      AppLogger.log('⚠️ ClientVideoProcessor: generateThumbnail failed: $e');
      return null;
    }
  }

  static void _cleanupFile(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {}
  }
}

