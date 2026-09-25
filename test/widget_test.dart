import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tide/widgets/hotkey_badge.dart';

void main() {
  testWidgets('HotkeyBadge renders shortcut keys properly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HotkeyBadge(
            shortcutText: '⇧ ⌘ 2',
            isHighlighted: true,
          ),
        ),
      ),
    );

    expect(find.text('⇧'), findsOneWidget);
    expect(find.text('⌘'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
