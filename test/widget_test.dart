// Basic smoke test for the Vibrate Timer app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibrate_timer/main.dart';

void main() {
  testWidgets('App builds and shows the START button', (WidgetTester tester) async {
    // Provide in-memory prefs so SharedPreferences works under test.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const VibrateTimerApp());
    await tester.pumpAndSettle();

    expect(find.text('START'), findsOneWidget);
    expect(find.text('STOPPED'), findsOneWidget);
  });
}
