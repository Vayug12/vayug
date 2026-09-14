import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:vayug/features/auth/data/services/authservices.dart';
import 'package:vayug/shared/config/app_config.dart';
import 'package:vayug/shared/utils/app_logger.dart';
import 'package:vayug/features/video/paid/data/services/paid_video_service.dart';

enum PaidVideoPurchaseOutcome { success, cancelled, failed, unavailable }

class PaidVideoPurchaseResult {
  final PaidVideoPurchaseOutcome outcome;
  final String message;

  const PaidVideoPurchaseResult(this.outcome, this.message);
}

class PaidVideoPurchaseService {
  static final PaidVideoPurchaseService instance =
      PaidVideoPurchaseService._internal();
  PaidVideoPurchaseService._internal();

  final AuthService _authService = AuthService();
  bool _configured = false;

  bool get isAvailable => AppConfig.revenueCatAndroidKey.isNotEmpty;

  Future<bool> _ensureReady() async {
    final userData = await _authService.getUserData();
    final googleId = (userData?['googleId'] ?? userData?['id'])?.toString();
    if (googleId == null || googleId.isEmpty) {
      AppLogger.log('⚠️ PaidVideoPurchase: not signed in');
      return false;
    }

    if (!isAvailable) {
      return true; // Mock mode in local development
    }

    if (!_configured) {
      await Purchases.configure(
        PurchasesConfiguration(AppConfig.revenueCatAndroidKey)
          ..appUserID = googleId,
      );
      _configured = true;
    } else {
      await Purchases.logIn(googleId);
    }

    return true;
  }

  /// Initiates Google Play In-App Purchase for a paid video
  Future<PaidVideoPurchaseResult> purchaseVideo({
    required String videoId,
    required String priceTierId,
  }) async {
    try {
      final ready = await _ensureReady();
      if (!ready) {
        return const PaidVideoPurchaseResult(
          PaidVideoPurchaseOutcome.unavailable,
          'Please sign in to unlock this video.',
        );
      }

      String transactionId = 'tx_${DateTime.now().millisecondsSinceEpoch}';

      // If RevenueCat is configured with live keys, purchase via Google Play
      if (isAvailable) {
        try {
          final products = await Purchases.getProducts([priceTierId]);
          if (products.isEmpty) {
            return const PaidVideoPurchaseResult(
              PaidVideoPurchaseOutcome.unavailable,
              'Product tier not available.',
            );
          }
          final purchaseResult = await Purchases.purchase(
            PurchaseParams.storeProduct(products.first),
          );
          transactionId = purchaseResult.customerInfo.originalAppUserId;
        } on PlatformException catch (e) {
          final code = PurchasesErrorHelper.getErrorCode(e);
          if (code == PurchasesErrorCode.purchaseCancelledError) {
            return const PaidVideoPurchaseResult(
              PaidVideoPurchaseOutcome.cancelled,
              'Purchase cancelled.',
            );
          }
          AppLogger.log('❌ RevenueCat purchase error: $e');
          return PaidVideoPurchaseResult(
            PaidVideoPurchaseOutcome.failed,
            e.message ?? 'Purchase failed.',
          );
        }
      }

      // Record unlock on backend
      final unlockSuccess = await PaidVideoService.instance.unlockVideo(
        videoId: videoId,
        transactionId: transactionId,
        priceTier: priceTierId,
      );

      if (unlockSuccess) {
        return const PaidVideoPurchaseResult(
          PaidVideoPurchaseOutcome.success,
          'Video unlocked successfully!',
        );
      } else {
        return const PaidVideoPurchaseResult(
          PaidVideoPurchaseOutcome.failed,
          'Payment succeeded but unlock verification failed. Please refresh.',
        );
      }
    } catch (e) {
      AppLogger.log('❌ PaidVideoPurchaseService error: $e');
      return PaidVideoPurchaseResult(
        PaidVideoPurchaseOutcome.failed,
        'Something went wrong: $e',
      );
    }
  }
}
