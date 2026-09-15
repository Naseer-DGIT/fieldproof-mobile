import 'package:flutter/material.dart';

import 'core/config/env.dart';
import 'core/logging/secure_logger.dart';

class FieldProofApp extends StatelessWidget {
  const FieldProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldProof',
      debugShowCheckedModeBanner: !Env.isProd,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _BootScreen(),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('FieldProof — S1 Day 2', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text('environment: ${Env.current.name}'),
            Text('log level:   ${Env.logLevel}'),
            Text('pinning:     ${Env.certificatePinning}'),
            Text('api base:    ${Env.apiBaseUrl}', textAlign: TextAlign.center),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
