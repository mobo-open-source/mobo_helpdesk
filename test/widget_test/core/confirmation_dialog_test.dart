import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_helpdesk/core/widgets/confirmation_dialog_widget.dart';

const _longMessage =
    'Live Chat needs more Odoo apps that are not installed on your server '
    'yet. Saving installs them now. This can take a few minutes and the '
    'server reloads when it is done. Keep the app open until it finishes.';

/// Opens the dialog on a screen of the given size and text scale.
Future<void> _open(
  WidgetTester tester, {
  required Size screen,
  double textScale = 1,
  String negative = 'Cancel',
  String positive = 'Delete',
  String message = 'Are you sure?',
  Brightness mode = Brightness.light,
  void Function(bool?)? onResult,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: mode),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await ConfirmationDialogWidget.show(
                  context: context,
                  title: 'Install required apps?',
                  subTitle: message,
                  negativeButtonText: negative,
                  positiveButtonText: positive,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _positive(String label) => find.widgetWithText(ElevatedButton, label);
Finder _negative(String label) => find.widgetWithText(OutlinedButton, label);

void main() {
  // Flutter's test font (Ahem) draws every glyph a full em wide, so a label
  // measures about twice as wide here as in the app. The labels in the
  // side-by-side test are short enough to sit together in either font.
  testWidgets('short labels sit side by side at equal height', (tester) async {
    await _open(
      tester,
      screen: const Size(360, 640),
      negative: 'No',
      positive: 'Yes',
    );

    final no = tester.getRect(_negative('No'));
    final yes = tester.getRect(_positive('Yes'));

    expect(no.top, yes.top);
    expect(no.height, yes.height);
    expect(no.right, lessThan(yes.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long label stacks full width, action first', (tester) async {
    await _open(
      tester,
      screen: const Size(360, 640),
      positive: 'Install and create',
      message: _longMessage,
    );

    final cancel = tester.getRect(_negative('Cancel'));
    final install = tester.getRect(_positive('Install and create'));

    expect(install.bottom, lessThan(cancel.top), reason: 'action sits on top');
    expect(install.width, cancel.width);
    expect(install.left, cancel.left);
    expect(install.height, greaterThanOrEqualTo(48));
    expect(cancel.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the longest real label also stacks on a 320 wide phone', (
    tester,
  ) async {
    await _open(
      tester,
      screen: const Size(320, 568),
      positive: 'Install and save',
      message: _longMessage,
    );

    expect(_positive('Install and save'), findsOneWidget);
    expect(_negative('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large system text neither overflows nor clips the buttons', (
    tester,
  ) async {
    await _open(
      tester,
      screen: const Size(360, 640),
      textScale: 2,
      positive: 'Install and create',
      message: _longMessage,
    );

    expect(tester.takeException(), isNull);
    final screen = tester.view.physicalSize;
    for (final finder in [_positive('Install and create'), _negative('Cancel')]) {
      final rect = tester.getRect(finder);
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screen.width));
    }
  });

  testWidgets('landscape keeps the buttons on screen and scrolls the message', (
    tester,
  ) async {
    await _open(
      tester,
      screen: const Size(640, 300),
      positive: 'Install and create',
      message: _longMessage,
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(_positive('Install and create')).bottom,
      lessThanOrEqualTo(300),
    );
    expect(
      tester.getRect(_negative('Cancel')).bottom,
      lessThanOrEqualTo(300),
    );
  });

  testWidgets('a wide screen keeps the dialog at a readable width', (
    tester,
  ) async {
    await _open(tester, screen: const Size(1200, 800), message: _longMessage);

    // The Dialog widget spans the screen; the visible card is its Material.
    final card = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(card.width, lessThanOrEqualTo(420));
    expect(card.width, greaterThan(280), reason: 'still a real dialog');
    expect(tester.takeException(), isNull);
  });

  testWidgets('both buttons still answer the dialog', (tester) async {
    bool? answer;
    await _open(
      tester,
      screen: const Size(360, 640),
      positive: 'Install and create',
      onResult: (value) => answer = value,
    );

    await tester.tap(_positive('Install and create'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(_negative('Cancel'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('dark theme lays out the same way', (tester) async {
    await _open(
      tester,
      screen: const Size(360, 640),
      positive: 'Install and create',
      mode: Brightness.dark,
      message: _longMessage,
    );

    expect(tester.takeException(), isNull);
    expect(_positive('Install and create'), findsOneWidget);
  });
}
