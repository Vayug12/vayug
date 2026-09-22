import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:vayug/shared/utils/app_logger.dart';

/// Service that handles shared videos sent from external apps (Gallery, WhatsApp, etc.)
class ShareReceiverService {
  ShareReceiverService._();
  static final ShareReceiverService instance = ShareReceiverService._();

  static const MethodChannel _channel =
      MethodChannel('com.snehayog.vayug/share_receiver');

  final StreamController<File> _videoSharedController =
      StreamController<File>.broadcast();

  /// Stream of shared video files received from external apps
  Stream<File> get onVideoShared => _videoSharedController.stream;

  File? _pendingSharedVideo;

  /// Holds the pending video file if received before a listener subscribed
  File? get pendingSharedVideo => _pendingSharedVideo;

  bool _isInitialized = false;

  /// Initializes the share receiver channel and checks for cold-start intents
  void initialize({void Function(File videoFile)? onVideoReceived}) {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    _checkInitialSharedVideo();

    if (onVideoReceived != null) {
      onVideoShared.listen(onVideoReceived);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onVideoReceived') {
      final String? path = call.arguments as String?;
      if (path != null && path.isNotEmpty) {
        _processIncomingFilePath(path);
      }
    }
  }

  Future<void> _checkInitialSharedVideo() async {
    try {
      final String? path =
          await _channel.invokeMethod<String>('getInitialSharedVideo');
      if (path != null && path.isNotEmpty) {
        _processIncomingFilePath(path);
      }
    } catch (e) {
      AppLogger.log(
          '⚠️ ShareReceiverService: Error getting initial shared video: $e');
    }
  }

  void _processIncomingFilePath(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        AppLogger.log(
            '📥 ShareReceiverService: Received shared video at: $path');
        _pendingSharedVideo = file;
        _videoSharedController.add(file);
      }
    } catch (e) {
      AppLogger.log(
          '❌ ShareReceiverService: Failed to process file $path: $e');
    }
  }

  /// Consumes and clears any pending shared video file (e.g. on app launch)
  File? consumePendingSharedVideo() {
    final file = _pendingSharedVideo;
    _pendingSharedVideo = null;
    return file;
  }

  void dispose() {
    _videoSharedController.close();
  }
}
