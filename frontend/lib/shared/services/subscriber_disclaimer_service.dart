import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/services/http_client_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/shared/widgets/subscriber_disclaimer_dialog.dart';

/// Centralized service to manage consent for creator off-platform contact
/// and email export.
class SubscriberDisclaimerService {
  SubscriberDisclaimerService._();

  static const String _prefPrefix = 'has_acknowledged_subscriber_export_';

  /// In-memory cache for ultra-fast lookup within session
  static final Set<String> _inMemoryAcknowledgedUsers = {};

  /// Check whether the user has already acknowledged/dismissed the disclaimer.
  static Future<bool> hasAcknowledged(String? userId) async {
    final cleanId = userId?.trim();
    if (cleanId == null || cleanId.isEmpty || cleanId == 'unknown') {
      return false;
    }

    if (_inMemoryAcknowledgedUsers.contains(cleanId)) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final localVal = prefs.getBool('$_prefPrefix$cleanId') ?? false;
      if (localVal) {
        _inMemoryAcknowledgedUsers.add(cleanId);
        return true;
      }
    } catch (e) {
      AppLogger.log('⚠️ SubscriberDisclaimerService: Prefs read error: $e');
    }

    return false;
  }

  /// Mark the disclaimer as acknowledged both locally and on backend (if neverAskAgain).
  static Future<void> acknowledge(
    String? userId, {
    required bool neverAskAgain,
  }) async {
    final cleanId = userId?.trim();
    if (cleanId == null || cleanId.isEmpty || cleanId == 'unknown') {
      return;
    }

    if (neverAskAgain) {
      _inMemoryAcknowledgedUsers.add(cleanId);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('$_prefPrefix$cleanId', true);
      } catch (e) {
        AppLogger.log('⚠️ SubscriberDisclaimerService: Prefs write error: $e');
      }

      // Sync with backend asynchronously
      _syncWithBackend();
    }
  }

  /// Fire-and-forget sync to backend
  static void _syncWithBackend() {
    Future.microtask(() async {
      try {
        final authService = AuthService();
        final userData = await authService.getUserData();
        final token = userData?['token'];
        if (token == null) return;

        final response = await HttpClientService.instance.post(
          Uri.parse(
              '${NetworkHelper.usersEndpoint}/acknowledge-subscriber-export'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          AppLogger.log(
              '✅ SubscriberDisclaimerService: Backend acknowledged successfully');
        } else {
          AppLogger.log(
              '⚠️ SubscriberDisclaimerService: Backend sync status: ${response.statusCode}');
        }
      } catch (e) {
        AppLogger.log(
            '⚠️ SubscriberDisclaimerService: Backend sync failed: $e');
      }
    });
  }

  /// Helper to resolve the current user's ID
  static Future<String?> resolveCurrentUserId(WidgetRef? ref) async {
    if (ref != null) {
      try {
        final authController = ref.read(googleSignInProvider);
        if (authController.isSignedIn && authController.userData != null) {
          final id = authController.userData!['googleId'] ??
              authController.userData!['id'] ??
              authController.userData!['_id'];
          if (id != null) return id.toString().trim();
        }
      } catch (_) {}
    }

    try {
      final authService = AuthService();
      final userData = await authService.getUserData();
      if (userData != null) {
        final id = userData['googleId'] ?? userData['id'] ?? userData['_id'];
        if (id != null) return id.toString().trim();
      }
    } catch (_) {}

    return null;
  }

  /// Ensures the user has given consent before proceeding with subscription.
  ///
  /// - Returns `true` if already acknowledged or user confirmed.
  /// - Returns `false` if user cancelled the dialog.
  static Future<bool> ensureConsent(
    BuildContext context, {
    WidgetRef? ref,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? await resolveCurrentUserId(ref);

    // If already acknowledged, proceed with 0ms delay
    if (await hasAcknowledged(effectiveUserId)) {
      return true;
    }

    if (!context.mounted) return false;

    // Show Apple HIG compliant disclaimer dialog
    final result = await SubscriberDisclaimerDialog.show(context);

    // User cancelled
    if (result == null) {
      return false;
    }

    // User confirmed with or without "Don't ask again"
    final bool dontAskAgain = result;
    if (dontAskAgain && effectiveUserId != null) {
      await acknowledge(effectiveUserId, neverAskAgain: true);
    }

    return true;
  }
}
