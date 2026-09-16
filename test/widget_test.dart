import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/app.dart';
import 'package:fieldproof_mobile/core/config/env.dart';

void main() {
  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
  });

  testWidgets('FieldProofApp renders the shell with Attendance tab active',
      (tester) async {
    await tester.pumpWidget(const FieldProofApp());
    await tester.pumpAndSettle();

    expect(find.text('Attendance — S2 will fill this'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tapping History tab switches the visible screen',
      (tester) async {
    await tester.pumpWidget(const FieldProofApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('History — S7 will fill this'), findsOneWidget);
    expect(find.text('Attendance — S2 will fill this'), findsNothing);
  });
}
