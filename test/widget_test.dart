import 'package:flutter/services.dart';
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

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('FieldProofApp shows the login form when unauthenticated',
      (tester) async {
    await tester.pumpWidget(const FieldProofApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('FieldProof'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
