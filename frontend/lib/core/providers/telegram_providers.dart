import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/shared/services/telegram_notification_service.dart';
import 'package:vayug/shared/utils/app_logger.dart';

class CreatorTelegramState {
  final bool isConnected;
  final String? username;
  final bool notifyOnComments;
  final bool isLoading;
  final bool hasCheckedStatus;
  final bool isConnecting;
  final bool isDismissed;

  const CreatorTelegramState({
    this.isConnected = false,
    this.username,
    this.notifyOnComments = true,
    this.isLoading = false,
    this.hasCheckedStatus = false,
    this.isConnecting = false,
    this.isDismissed = false,
  });

  bool get canOfferConnection => hasCheckedStatus && !isLoading && !isConnected;
  bool get showBanner => canOfferConnection && !isDismissed;

  CreatorTelegramState copyWith({
    bool? isConnected,
    String? username,
    bool clearUsername = false,
    bool? notifyOnComments,
    bool? isLoading,
    bool? hasCheckedStatus,
    bool? isConnecting,
    bool? isDismissed,
  }) =>
      CreatorTelegramState(
        isConnected: isConnected ?? this.isConnected,
        username: clearUsername ? null : username ?? this.username,
        notifyOnComments: notifyOnComments ?? this.notifyOnComments,
        isLoading: isLoading ?? this.isLoading,
        hasCheckedStatus: hasCheckedStatus ?? this.hasCheckedStatus,
        isConnecting: isConnecting ?? this.isConnecting,
        isDismissed: isDismissed ?? this.isDismissed,
      );
}

class CreatorTelegramNotifier extends StateNotifier<CreatorTelegramState>
    with WidgetsBindingObserver {
  final TelegramNotificationService _service;
  final bool _isSignedIn;
  Future<void>? _statusRequest;

  CreatorTelegramNotifier(this._service, {bool isSignedIn = true})
      : _isSignedIn = isSignedIn,
        super(const CreatorTelegramState()) {
    WidgetsBinding.instance.addObserver(this);
    checkStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkStatus();
  }

  Future<void> checkStatus() {
    if (!_isSignedIn || !mounted) return Future.value();
    return _statusRequest ??= _refreshStatus().whenComplete(() {
      _statusRequest = null;
    });
  }

  Future<void> _refreshStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final status = await _service.getStatus();
      if (!mounted) return;
      state = state.copyWith(
        isConnected: status?.isConnected,
        username: status?.username,
        clearUsername: status != null && status.username == null,
        notifyOnComments: status?.notifyOnComments,
        hasCheckedStatus: status != null,
        isLoading: false,
      );
    } catch (_) {
      AppLogger.error('Unable to refresh Telegram connection');
      if (mounted) {
        state = state.copyWith(isLoading: false, hasCheckedStatus: false);
      }
    }
  }

  Future<bool> connect() async {
    if (!_isSignedIn || state.isConnecting || state.isConnected) return false;
    state = state.copyWith(isConnecting: true);
    try {
      return await _service.launchTelegramConnect();
    } catch (_) {
      AppLogger.error('Unable to launch Telegram connection');
      return false;
    } finally {
      if (mounted) state = state.copyWith(isConnecting: false);
    }
  }

  Future<bool> disconnect() async {
    if (!_isSignedIn || state.isLoading || state.isConnecting) return false;
    state = state.copyWith(isLoading: true);
    try {
      final success = await _service.disconnect();
      if (mounted && success) {
        state = state.copyWith(
          isConnected: false,
          clearUsername: true,
          hasCheckedStatus: true,
          isDismissed: false,
        );
      }
      return success;
    } catch (_) {
      AppLogger.error('Unable to disconnect Telegram');
      return false;
    } finally {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void dismissBanner() => state = state.copyWith(isDismissed: true);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final telegramAccountIdProvider = Provider<String?>((ref) {
  return ref.watch(googleSignInProvider.select((auth) =>
      (auth.userData?['googleId'] ??
              auth.userData?['id'] ??
              auth.userData?['_id'])
          ?.toString()));
});

final telegramNotificationServiceProvider =
    Provider<TelegramNotificationService>(
  (ref) => TelegramNotificationService.instance,
);

final creatorTelegramProvider =
    StateNotifierProvider<CreatorTelegramNotifier, CreatorTelegramState>((ref) {
  final accountId = ref.watch(telegramAccountIdProvider);
  return CreatorTelegramNotifier(
    ref.watch(telegramNotificationServiceProvider),
    isSignedIn: accountId != null && accountId.isNotEmpty,
  );
});
