import 'dart:convert';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class PaidVideoService {
  static final PaidVideoService instance = PaidVideoService._internal();
  PaidVideoService._internal();

  static String get baseUrl => AppConfig.baseUrl;

  /// In-memory cache for unlocked video IDs to provide instantaneous O(1) feed checks
  final Set<String> _unlockedCache = {};

  bool isLocallyUnlocked(String videoId) => _unlockedCache.contains(videoId);

  void markLocallyUnlocked(String videoId) {
    _unlockedCache.add(videoId);
  }

  /// Checks if the authenticated user has unlocked this video
  Future<bool> checkAccess(String videoId) async {
    if (videoId.isEmpty) return false;
    if (_unlockedCache.contains(videoId)) return true;

    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await httpClientService.get(
        Uri.parse('$baseUrl/api/paid-videos/check-access/$videoId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isUnlocked = data['isUnlocked'] == true;
        if (isUnlocked) {
          _unlockedCache.add(videoId);
        }
        return isUnlocked;
      }
      return false;
    } catch (e) {
      AppLogger.log('⚠️ PaidVideoService: checkAccess error: $e');
      return false;
    }
  }

  /// Unlocks a video on the backend with RevenueCat transaction details
  Future<bool> unlockVideo({
    required String videoId,
    required String transactionId,
    required String priceTier,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception('Authentication required');

      final response = await httpClientService.post(
        Uri.parse('$baseUrl/api/paid-videos/unlock'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'videoId': videoId,
          'revenueCatTransactionId': transactionId,
          'priceTier': priceTier,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        if (success) {
          _unlockedCache.add(videoId);
        }
        return success;
      } else {
        AppLogger.log('❌ PaidVideoService: Failed to unlock video: ${response.body}');
        return false;
      }
    } catch (e) {
      AppLogger.log('❌ PaidVideoService: Error unlocking video: $e');
      return false;
    }
  }

  /// Fetches sales summary and transactions for the creator
  Future<Map<String, dynamic>?> getCreatorSales() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final response = await httpClientService.get(
        Uri.parse('$baseUrl/api/paid-videos/creator-sales'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      AppLogger.log('❌ PaidVideoService: Error fetching creator sales: $e');
      return null;
    }
  }
}
