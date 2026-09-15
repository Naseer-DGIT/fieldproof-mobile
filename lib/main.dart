import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/logging/secure_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  await Env.load(flavor);

  SecureLogger.init();
  SecureLogger.i('app.start', data: {'environment': Env.current.name});

  runApp(const FieldProofApp());
}
