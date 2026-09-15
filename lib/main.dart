import 'package:flutter/material.dart';
import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flavor is passed at build time:
  //   flutter run --dart-define=FLAVOR=dev
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  await Env.load(flavor);

  runApp(const FieldProofApp());
}
