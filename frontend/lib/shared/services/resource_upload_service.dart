import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class ResourceUploadResult {
  final String url;
  final String fileName;
  final int fileSize;

  ResourceUploadResult({
    required this.url,
    required this.fileName,
    required this.fileSize,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// **ResourceUploadService - Direct uploads for APK, PDF, Notes, Docs to Cloud Storage**
class ResourceUploadService {
  final Dio _dio = Dio();

  static final ResourceUploadService _instance = ResourceUploadService._internal();
  factory ResourceUploadService() => _instance;
  ResourceUploadService._internal();

  static String getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.apk':
        return 'application/vnd.android.package-archive';
      case '.pdf':
        return 'application/pdf';
      case '.zip':
        return 'application/zip';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      case '.epub':
        return 'application/epub+zip';
      default:
        return 'application/octet-stream';
    }
  }

  Future<ResourceUploadResult> uploadResource({
    required File file,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!await file.exists()) {
      throw Exception('Selected file does not exist.');
    }

    final fileSize = await file.length();
    if (fileSize > 200 * 1024 * 1024) {
      throw Exception('File size exceeds the 200MB limit.');
    }

    final fileName = p.basename(file.path);
    final mimeType = getMimeType(file.path);

    final token = await AuthService.getToken();

    try {
      AppLogger.log('📤 ResourceUpload: Requesting presigned URL for $fileName ($fileSize bytes)...');
      
      final presignedResponse = await _dio.post(
        '${NetworkHelper.apiBaseUrl}/upload/resource/presigned',
        data: {
          'fileName': fileName,
          'fileType': mimeType,
          'fileSize': fileSize,
        },
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      final uploadUrl = presignedResponse.data['uploadUrl'] as String?;
      final publicUrl = presignedResponse.data['publicUrl'] as String?;

      if (uploadUrl != null && publicUrl != null) {
        AppLogger.log('🚀 ResourceUpload: Uploading stream to R2 storage...');
        
        final r2Dio = Dio();
        await r2Dio.put(
          uploadUrl,
          data: file.openRead(),
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'Content-Type': mimeType,
              'Content-Length': fileSize,
              'Cache-Control': 'public, max-age=31536000, immutable',
            },
          ),
          onSendProgress: (sent, total) {
            if (total > 0 && onProgress != null) {
              onProgress(sent / total);
            }
          },
        );

        AppLogger.log('✅ ResourceUpload: R2 upload complete: $publicUrl');
        return ResourceUploadResult(
          url: publicUrl,
          fileName: fileName,
          fileSize: fileSize,
        );
      }
    } catch (presignedErr) {
      AppLogger.log('⚠️ ResourceUpload: Presigned upload failed, attempting multipart fallback: $presignedErr');
    }

    // Multipart Fallback
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _dio.post(
        '${NetworkHelper.apiBaseUrl}/upload/resource',
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final uploadedUrl = response.data['url'] as String;
      AppLogger.log('✅ ResourceUpload: Multipart upload complete: $uploadedUrl');
      return ResourceUploadResult(
        url: uploadedUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      AppLogger.log('❌ ResourceUpload: Both presigned and multipart fallback failed: $e');
      throw Exception('Failed to upload file. Please try again.');
    }
  }
}
