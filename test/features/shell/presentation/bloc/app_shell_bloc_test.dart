import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/features/shell/presentation/bloc/app_shell_bloc.dart';
import 'package:fieldproof_mobile/features/shell/presentation/bloc/app_shell_event.dart';
import 'package:fieldproof_mobile/features/shell/presentation/bloc/app_shell_state.dart';

void main() {
  group('AppShellBloc', () {
    test('initial state is AppShellInitial with index 0', () {
      final bloc = AppShellBloc();
      expect(bloc.state, const AppShellInitial());
      expect(bloc.state.selectedIndex, 0);
      bloc.close();
    });

    blocTest<AppShellBloc, AppShellState>(
      'emits AppShellActive(2) when AppShellTabSelected(2) is added',
      build: AppShellBloc.new,
      act: (bloc) => bloc.add(const AppShellTabSelected(2)),
      expect: () => [const AppShellActive(2)],
    );

    blocTest<AppShellBloc, AppShellState>(
      'drops transition when the requested index equals the current one',
      build: AppShellBloc.new,
      act: (bloc) => bloc.add(const AppShellTabSelected(0)),
      expect: () => <AppShellState>[],
    );

    blocTest<AppShellBloc, AppShellState>(
      'transitions are observable in order',
      build: AppShellBloc.new,
      act: (bloc) {
        bloc.add(const AppShellTabSelected(1));
        bloc.add(const AppShellTabSelected(3));
        bloc.add(const AppShellTabSelected(2));
      },
      expect: () => [
        const AppShellActive(1),
        const AppShellActive(3),
        const AppShellActive(2),
      ],
    );
  });
}
