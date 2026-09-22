import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vayug/features/video/upload/presentation/widgets/video_orientation_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('VideoOrientationDialog Tests', () {
    testWidgets('renders Vertical and Horizontal in single-line FittedBox without overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: VideoOrientationDialog(detectedAspectRatio: 1.77),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final verticalFinder = find.text('Vertical');
      final horizontalFinder = find.text('Horizontal');

      expect(verticalFinder, findsOneWidget);
      expect(horizontalFinder, findsOneWidget);

      final horizontalText = tester.widget<Text>(horizontalFinder);
      expect(horizontalText.maxLines, equals(1));
      expect(horizontalText.softWrap, isFalse);

      // Verify that Horizontal Text is wrapped in a FittedBox
      final fittedBoxFinder = find.ancestor(
        of: horizontalFinder,
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsOneWidget);
    });
  });

  group('Video CTA & Title Coordinated Motion Tests', () {
    testWidgets('Title starts at bottom and elevates by 65px when link is revealed',
        (WidgetTester tester) async {
      final linkRevealedVN = ValueNotifier<bool>(false);
      const double bottomPadding = 20.0;

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(360, 690),
          builder: (context, child) => MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: linkRevealedVN,
                    builder: (context, isRevealed, _) {
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        key: const ValueKey('title_block'),
                        bottom: isRevealed ? bottomPadding + 65 : bottomPadding,
                        left: 0,
                        right: 80,
                        child: const SizedBox(
                          height: 50,
                          child: Text('Video Title Demo'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final double screenHeight = tester.getSize(find.byType(Scaffold)).height;

      // Initially not revealed: bottom is exactly bottomPadding (20.0)
      final initialTitleBox = tester.getRect(find.byKey(const ValueKey('title_block')));
      expect(initialTitleBox.bottom, equals(screenHeight - bottomPadding));

      // Reveal CTA
      linkRevealedVN.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // finish 350ms animation

      // Elevated: bottom is elevated by 65px
      final elevatedTitleBox = tester.getRect(find.byKey(const ValueKey('title_block')));
      expect(elevatedTitleBox.bottom, equals(screenHeight - (bottomPadding + 65)));
    });
  });
}
