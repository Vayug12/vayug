import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/services/connectivity_service.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class TelegramStatus {
  final bool isConnected;
  final String? username;
  final bool notifyOnComments;

  const TelegramStatus({
    this.isConnected = false,
    this.username,
    this.notifyOnComments = true,
  });

  factory TelegramStatus.fromJson(Map<String, dynamic> json) {
    return TelegramStatus(
      isConnected: json['isConnected'] == true,
      username: json['username']?.toString(),
      notifyOnComments: json['notifyOnComments'] ?? true,
    );
  }
}

class TelegramNotificationService {
  static final TelegramNotificationService instance =
      TelegramNotificationService._internal();

  TelegramNotificationService._internal();

  final HttpClientService _httpClient = HttpClientService.instance;
  static String get _baseUrl => NetworkHelper.getBaseUrl();

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty && !token.startsWith('temp_')) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      throw Exception('Please sign in to connect Telegram');
    }
    return headers;
  }

  /// Null means unavailable, never a confirmed disconnected account.
  Future<TelegramStatus?> getStatus() async {
    try {
      final hasInternet = await ConnectivityService.hasInternetConnection();
      if (!hasInternet) return null;
      final headers = await _getAuthHeaders();
      final response = await _httpClient.dio.get(
        '$_baseUrl/api/telegram/status',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        if (data['isConnected'] is bool) {
          return TelegramStatus.fromJson(data);
        }
      }
    } catch (_) {
      AppLogger.error('Telegram connection status unavailable');
    }
    return null;
  }

  /// Get Telegram deep link URL
  Future<String?> getLinkUrl() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!hasInternet) throw Exception('No internet connection');

    try {
      final headers = await _getAuthHeaders();
      final response = await _httpClient.dio.post(
        '$_baseUrl/api/telegram/link-token',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        return data['linkUrl']?.toString();
      }
    } catch (e) {
      AppLogger.error('TelegramNotificationService.getLinkUrl failed: $e');
      rethrow;
    }
    return null;
  }

  /// Launch Telegram app with deep link
  Future<bool> launchTelegramConnect() async {
    final linkUrl = await getLinkUrl();
    if (linkUrl == null || linkUrl.isEmpty) return false;

    final uri = Uri.parse(linkUrl);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Disconnect Telegram
  Future<bool> disconnect() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await _httpClient.dio.delete(
        '$_baseUrl/api/telegram/disconnect',
        options: Options(headers: headers),
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('TelegramNotificationService.disconnect failed: $e');
      return false;
    }
  }
}
