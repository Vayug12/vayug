import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vayug/shared/services/telegram_notification_service.dart';

class CreatorTelegramState {
  final bool isConnected;
  final String? username;
  final bool notifyOnComments;
  final bool isLoading;
  final bool isConnecting;
  final bool isDismissed;

  const CreatorTelegramState({
    this.isConnected = false,
    this.username,
    this.notifyOnComments = true,
    this.isLoading = false,
    this.isConnecting = false,
    this.isDismissed = false,
  });

  CreatorTelegramState copyWith({
    bool? isConnected,
    String? username,
    bool? notifyOnComments,
    bool? isLoading,
    bool? isConnecting,
    bool? isDismissed,
  }) {
    return CreatorTelegramState(
      isConnected: isConnected ?? this.isConnected,
      username: username ?? this.username,
      notifyOnComments: notifyOnComments ?? this.notifyOnComments,
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

class CreatorTelegramNotifier extends StateNotifier<CreatorTelegramState> {
  final TelegramNotificationService _service;

  CreatorTelegramNotifier(this._service) : super(const CreatorTelegramState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    final status = await _service.getStatus();
    state = state.copyWith(
      isConnected: status.isConnected,
      username: status.username,
      notifyOnComments: status.notifyOnComments,
      isLoading: false,
    );
  }

  Future<bool> connect() async {
    state = state.copyWith(isConnecting: true);
    try {
      final launched = await _service.launchTelegramConnect();
      return launched;
    } finally {
      state = state.copyWith(isConnecting: false);
    }
  }

  Future<bool> disconnect() async {
    state = state.copyWith(isLoading: true);
    final success = await _service.disconnect();
    if (success) {
      state = state.copyWith(
        isConnected: false,
        username: null,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
    return success;
  }

  void dismissBanner() {
    state = state.copyWith(isDismissed: true);
  }
}

final creatorTelegramProvider =
    StateNotifierProvider<CreatorTelegramNotifier, CreatorTelegramState>((ref) {
  return CreatorTelegramNotifier(TelegramNotificationService.instance);
});
