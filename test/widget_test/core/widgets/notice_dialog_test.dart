import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/app/themes/app_colors.dart';
import 'package:mobo_helpdesk/core/widgets/notice_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    String? detail = 'The server could not finish the installation.',
    String? hint = 'You can switch them off and save.',
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => NoticeDialog.show(
                context: context,
                title: 'Apps not installed',
                message: 'The team "Support" was created.',
                detail: detail,
                hint: hint,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AlertDialog dialog(WidgetTester tester) =>
      tester.widget<AlertDialog>(find.byType(AlertDialog));

  group('NoticeDialog', () {
    testWidgets('is clean white with the heading, the message and one button', (
      tester,
    ) async {
      await open(tester);

      expect(dialog(tester).backgroundColor, AppColors.white);
      expect(dialog(tester).surfaceTintColor, AppColors.white);
      expect(find.text('Apps not installed'), findsOneWidget);
      expect(find.text('The team "Support" was created.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('the server\'s words sit in their own box and can be copied', (
      tester,
    ) async {
      await open(tester);

      expect(
        find.widgetWithText(SelectableText, 'The server could not finish the installation.'),
        findsOneWidget,
      );
      expect(find.text('You can switch them off and save.'), findsOneWidget);
    });

    testWidgets('without detail or hint it is just the message', (tester) async {
      await open(tester, detail: null, hint: null);

      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('The team "Support" was created.'), findsOneWidget);
    });

    testWidgets('dark theme gets a dark surface, not white', (tester) async {
      await open(tester, brightness: Brightness.dark);

      expect(dialog(tester).backgroundColor, isNot(AppColors.white));
      expect(dialog(tester).backgroundColor, const Color(0xFF1E1E1E));
    });

    testWidgets('OK closes it and the caller carries on', (tester) async {
      await open(tester);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('long text on a small phone scrolls instead of overflowing', (
      tester,
    ) async {
      await open(
        tester,
        size: const Size(320, 480),
        detail: List.filled(40, 'a file it needs is missing').join(' '),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('OK'), findsOneWidget, reason: 'the button stays reachable');
    });
  });
}
