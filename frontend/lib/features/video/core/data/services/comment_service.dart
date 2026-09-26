import 'package:dio/dio.dart';
import 'package:vayug/core/interfaces/i_comment_service.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/services/connectivity_service.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class CommentServiceImpl implements ICommentService {
  final HttpClientService _httpClient = HttpClientService.instance;

  static String get baseUrl => NetworkHelper.getBaseUrl();

  Future<Map<String, String>> _getAuthHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty && !token.startsWith('temp_')) {
      headers['Authorization'] = 'Bearer $token';
    } else if (requireAuth) {
      throw Exception('Please sign in to continue');
    }

    return headers;
  }

  @override
  Future<CommentPageResult> getComments(
    String videoId, {
    int page = 1,
    int limit = 20,
  }) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection. Please check your network.');
    }

    try {
      final headers = await _getAuthHeaders(requireAuth: false);
      final url = '$baseUrl/api/videos/$videoId/comments?page=$page&limit=$limit';

      final response = await _httpClient.dio.get(
        url,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        return CommentPageResult.fromJson(data, videoId: videoId);
      } else {
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      AppLogger.log('❌ CommentService: Error fetching comments: $e');
      rethrow;
    }
  }

  @override
  Future<CommentModel> addComment(String videoId, String content) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection. Please check your network.');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    try {
      final headers = await _getAuthHeaders(requireAuth: true);
      final url = '$baseUrl/api/videos/$videoId/comments';

      final response = await _httpClient.dio.post(
        url,
        data: {'content': trimmed},
        options: Options(headers: headers),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final commentData = data['comment'] is Map
            ? Map<String, dynamic>.from(data['comment'] as Map)
            : data;

        return CommentModel.fromJson(commentData, targetVideoId: videoId);
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (e) {
      AppLogger.log('❌ CommentService: Error adding comment: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteComment(String videoId, String commentId) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection. Please check your network.');
    }

    try {
      final headers = await _getAuthHeaders(requireAuth: true);
      final url = '$baseUrl/api/videos/$videoId/comments/$commentId';

      final response = await _httpClient.dio.delete(
        url,
        options: Options(headers: headers),
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.log('❌ CommentService: Error deleting comment: $e');
      rethrow;
    }
  }

  @override
  Future<CommentModel> toggleLikeComment(String videoId, String commentId) async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection. Please check your network.');
    }

    try {
      final headers = await _getAuthHeaders(requireAuth: true);
      final url = '$baseUrl/api/videos/$videoId/comments/$commentId/like';

      final response = await _httpClient.dio.post(
        url,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final isLiked = data['isLiked'] == true;
        final likes = (data['likes'] is int)
            ? data['likes'] as int
            : int.tryParse(data['likes']?.toString() ?? '0') ?? 0;

        return CommentModel(
          id: commentId,
          videoId: videoId,
          content: '',
          user: const CommentUser(id: '', name: '', profilePic: ''),
          likes: likes,
          isLiked: isLiked,
          createdAt: DateTime.now(),
        );
      } else {
        throw Exception('Failed to like comment');
      }
    } catch (e) {
      AppLogger.log('❌ CommentService: Error liking comment: $e');
      rethrow;
    }
  }
}
