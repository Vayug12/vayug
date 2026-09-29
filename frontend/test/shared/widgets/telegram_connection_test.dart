import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vayug/core/providers/telegram_providers.dart';
import 'package:vayug/shared/services/telegram_notification_service.dart';

class MockTelegramService extends Mock implements TelegramNotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockTelegramService service;

  setUp(() => service = MockTelegramService());

  test('connected creator never gets a prompt while checking or offline',
      () async {
    final pending = Completer<TelegramStatus?>();
    when(() => service.getStatus()).thenAnswer((_) => pending.future);
    final notifier = CreatorTelegramNotifier(service);
    addTearDown(notifier.dispose);
    expect(notifier.state.showBanner, isFalse);
    final request = notifier.checkStatus();
    verify(() => service.getStatus()).called(1);
    pending.complete(const TelegramStatus(isConnected: true));
    await request;
    expect(notifier.state.canOfferConnection, isFalse);
    when(() => service.getStatus()).thenAnswer((_) async => null);
    await notifier.checkStatus();
    expect(notifier.state.isConnected, isTrue);
    expect(notifier.state.canOfferConnection, isFalse);
  });

  test('unknown connection status is never advertised as disconnected',
      () async {
    when(() => service.getStatus()).thenAnswer((_) async => null);
    final notifier = CreatorTelegramNotifier(service);
    addTearDown(notifier.dispose);
    await notifier.checkStatus();
    expect(notifier.state.showBanner, isFalse);
    expect(notifier.state.isLoading, isFalse);
  });

  test('returning from Telegram refreshes the verified connection', () async {
    when(() => service.getStatus())
        .thenAnswer((_) async => const TelegramStatus());
    when(() => service.launchTelegramConnect()).thenAnswer((_) async => true);
    final notifier = CreatorTelegramNotifier(service);
    addTearDown(notifier.dispose);
    await notifier.checkStatus();
    expect(notifier.state.showBanner, isTrue);
    expect(await notifier.connect(), isTrue);
    // Opening the app alone must not claim a successful connection.
    expect(notifier.state.isConnected, isFalse);
    when(() => service.getStatus())
        .thenAnswer((_) async => const TelegramStatus(isConnected: true));
    notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await notifier.checkStatus();
    expect(notifier.state.canOfferConnection, isFalse);
  });

  test('dismissal preserves the shortcut and disconnect clears username',
      () async {
    when(() => service.getStatus()).thenAnswer((_) async =>
        const TelegramStatus(isConnected: true, username: 'creator'));
    when(() => service.disconnect()).thenAnswer((_) async => true);
    final notifier = CreatorTelegramNotifier(service);
    addTearDown(notifier.dispose);
    await notifier.checkStatus();
    expect(await notifier.disconnect(), isTrue);
    expect(notifier.state.username, isNull);
    notifier.dismissBanner();
    expect(notifier.state.showBanner, isFalse);
    expect(notifier.state.canOfferConnection, isTrue);
  });

  test('failed launches recover and repeated taps do not open twice', () async {
    when(() => service.getStatus())
        .thenAnswer((_) async => const TelegramStatus());
    final launch = Completer<bool>();
    when(() => service.launchTelegramConnect())
        .thenAnswer((_) => launch.future);
    final notifier = CreatorTelegramNotifier(service);
    addTearDown(notifier.dispose);
    await notifier.checkStatus();
    final first = notifier.connect();
    expect(await notifier.connect(), isFalse);
    launch.completeError(Exception('launch failed'));
    expect(await first, isFalse);
    expect(notifier.state.isConnecting, isFalse);
    expect(notifier.state.showBanner, isTrue);
    verify(() => service.launchTelegramConnect()).called(1);
  });

  test(
      'account changes reset status and ignore a late response for old account',
      () async {
    final account = StateProvider<String?>((ref) => 'first');
    final firstResult = Completer<TelegramStatus?>();
    when(() => service.getStatus()).thenAnswer((_) => firstResult.future);
    final container = ProviderContainer(overrides: [
      telegramAccountIdProvider.overrideWith((ref) => ref.watch(account)),
      telegramNotificationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    final firstNotifier = container.read(creatorTelegramProvider.notifier);
    final firstRequest = firstNotifier.checkStatus();
    when(() => service.getStatus())
        .thenAnswer((_) async => const TelegramStatus());
    container.read(account.notifier).state = 'second';
    final secondNotifier = container.read(creatorTelegramProvider.notifier);
    await secondNotifier.checkStatus();
    expect(secondNotifier.state.showBanner, isTrue);
    firstResult.complete(const TelegramStatus(isConnected: true));
    await firstRequest;
    expect(container.read(creatorTelegramProvider).isConnected, isFalse);
    container.read(account.notifier).state = null;
    expect(container.read(creatorTelegramProvider).showBanner, isFalse);
    verify(() => service.getStatus()).called(2);
  });
}
