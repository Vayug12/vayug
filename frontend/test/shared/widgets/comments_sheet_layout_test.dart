import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vayug/core/interfaces/i_comment_service.dart';
import 'package:vayug/core/providers/auth_providers.dart';
import 'package:vayug/core/providers/comment_providers.dart';
import 'package:vayug/core/providers/telegram_providers.dart';
import 'package:vayug/features/auth/presentation/controllers/google_sign_in_controller.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/services/telegram_notification_service.dart';
import 'package:vayug/shared/widgets/comments/telegram_connect_banner.dart';
import 'package:vayug/shared/widgets/comments/video_comments_bottom_sheet.dart';

class MockComments extends Mock implements ICommentService {}

class MockAuth extends Mock implements GoogleSignInController {}

class MockTelegram extends Mock implements TelegramNotificationService {}

class MockVideo extends Mock implements VideoModel {}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpSheet(
    WidgetTester tester, {
    bool connected = true,
    bool empty = false,
    bool owner = true,
    Size viewport = const Size(360, 800),
    double textScale = 1,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = MockAuth();
    when(() => auth.userData).thenReturn({'id': owner ? 'creator' : 'viewer'});
    when(() => auth.isSignedIn).thenReturn(true);
    final telegram = MockTelegram();
    when(() => telegram.getStatus())
        .thenAnswer((_) async => TelegramStatus(isConnected: connected));
    final video = MockVideo();
    when(() => video.id).thenReturn('video');
    when(() => video.uploader)
        .thenReturn(Uploader(id: 'creator', name: 'Creator', profilePic: ''));
    final comments = MockComments();
    when(() => comments.getComments('video', page: 1, limit: 20))
        .thenAnswer((_) async => CommentPageResult(
              comments: empty
                  ? []
                  : [
                      CommentModel(
                        id: 'comment',
                        videoId: 'video',
                        content: 'Love this! Keep creating.',
                        user: const CommentUser(
                            id: 'creator', name: 'Raj Mehra', profilePic: ''),
                        createdAt: DateTime.now(),
                      )
                    ],
              currentPage: 1,
              totalPages: 1,
              totalComments: empty ? 0 : 1,
              hasNextPage: false,
            ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        googleSignInProvider.overrideWith((ref) => auth),
        commentServiceProvider.overrideWithValue(comments),
        telegramNotificationServiceProvider.overrideWithValue(telegram),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!,
          ),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Builder(
                builder: (context) => Center(
                      child: TextButton(
                        onPressed: () => VideoCommentsBottomSheet.show(context,
                            video: video),
                        child: const Text('Open comments'),
                      ),
                    )),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open comments'));
    await tester.pumpAndSettle();
  }

  testWidgets('connected creator sees no Telegram banner or shortcut',
      (tester) async {
    await pumpSheet(tester);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Telegram alerts'), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.text('@Raj Mehra'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open comments'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('unconnected creator can dismiss and still access Connect',
      (tester) async {
    await pumpSheet(tester, connected: false);
    expect(find.text('Telegram alerts'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss Telegram suggestion'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram alerts'), findsNothing);
    expect(find.byTooltip('Connect Telegram'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('viewers never see creator Telegram controls', (tester) async {
    await pumpSheet(tester, connected: false, owner: false);
    expect(find.byType(TelegramConnectBanner), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('narrow screen with large text and keyboard stays usable',
      (tester) async {
    await pumpSheet(tester,
        connected: false,
        viewport: const Size(320, 720),
        textScale: 1.6,
        keyboard: 280);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final composer = tester.getRect(find.byType(TextField));
    expect(composer.bottom, lessThanOrEqualTo(440));
    expect(find.byTooltip('Post comment'), findsOneWidget);
  });

  testWidgets('empty sheet remains draggable and refreshable', (tester) async {
    await pumpSheet(tester, empty: true);
    final sheet = find.byType(DraggableScrollableSheet);
    final height = tester.getSize(sheet).height;
    await tester.drag(find.text('No comments yet'), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, greaterThan(height));
    expect(find.text('Start the conversation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
