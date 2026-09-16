import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/env.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/shell/presentation/bloc/app_shell_bloc.dart';

class FieldProofApp extends StatelessWidget {
  const FieldProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AppShellBloc>(
      create: (_) => AppShellBloc(),
      child: MaterialApp(
        title: 'FieldProof',
        debugShowCheckedModeBanner: !Env.isProd,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const AppShell(),
      ),
    );
  }
}
