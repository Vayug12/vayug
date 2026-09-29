import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vayug/features/video/core/data/models/comment_model.dart';
import 'package:vayug/shared/widgets/comments/comment_input_field.dart';
import 'package:vayug/shared/widgets/comments/comment_item_widget.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget child,
      {double textScale = 1}) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (_, __) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('long names and text scale keep content and actions accessible',
      (tester) async {
    var likes = 0;
    var deletes = 0;
    final comment = CommentModel(
      id: 'comment',
      videoId: 'video',
      content: List.filled(20, 'A thoughtful comment.').join(' '),
      user: const CommentUser(
          id: 'creator',
          name: 'A creator with a very long display name',
          profilePic: ''),
      createdAt: DateTime.now(),
    );
    await pump(
        tester,
        CommentItemWidget(
            comment: comment,
            isOwner: true,
            onLike: () => likes++,
            onDelete: () => deletes++),
        textScale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Like'));
    expect(likes, 1);
    await tester.tap(find.byTooltip('Comment options'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed submission keeps draft; success clears it without duplicate sends',
      (tester) async {
    var calls = 0;
    var result = Completer<bool>();
    await pump(
        tester,
        CommentInputField(
          onSubmit: (_) {
            calls++;
            return result.future;
          },
          onSignInRequired: () {},
        ));
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pump();
    await tester.tap(find.byTooltip('Post comment'));
    expect(calls, 1);
    result.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsOneWidget);
    result = Completer<bool>();
    await tester.tap(find.byTooltip('Post comment'));
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsNothing);
    expect(calls, 2);
  });

  testWidgets('emoji shortcuts respect the 500 character limit',
      (tester) async {
    await pump(
        tester,
        CommentInputField(
          onSubmit: (_) async => true,
          onSignInRequired: () {},
        ));
    final draft = List.filled(500, 'a').join();
    await tester.enterText(find.byType(TextField), draft);
    await tester.pumpAndSettle();
    await tester.tap(find.text('❤️'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, draft);
  });

  testWidgets('signed out composer still starts sign in', (tester) async {
    var signIns = 0;
    await pump(
        tester,
        CommentInputField(
          isSignedIn: false,
          onSubmit: (_) async => true,
          onSignInRequired: () => signIns++,
        ));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(signIns, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
}
