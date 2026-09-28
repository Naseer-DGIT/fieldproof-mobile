import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/logging/secure_logger.dart';
import 'core/network/api_client.dart';
import 'core/security/rekey_policy.dart';
import 'core/storage/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  await Env.load(flavor);

  SecureLogger.init();
  ApiClient.init();
  SecureLogger.i('app.start', data: {'environment': Env.current.name});

  // Open the encrypted DB at startup. This is what creates the file
  // on first install. S2 fills it with the real queue; S1 just proves
  // the open path works end to end.
  await AppDatabase.instance;

  // Rekey the DB if the 90-day interval has passed. Runs on the main
  // isolate after the DB is open. A failure is logged, not fatal.
  await RekeyPolicy.runIfDue();

  runApp(const FieldProofApp());
}
