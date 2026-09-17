import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell_event.dart';
import 'app_shell_state.dart';

/// FieldProof app shell BLoC.
///
/// Owns the selected bottom navigation tab. Later sprints add more
/// events to this BLoC (e.g. `AppShellEnvironmentChanged`) without
/// touching the widgets — the pattern from ADR-0001.
class AppShellBloc extends Bloc<AppShellEvent, AppShellState> {
  AppShellBloc() : super(const AppShellInitial()) {
    on<AppShellTabSelected>(_onTabSelected);
  }

  void _onTabSelected(
    AppShellTabSelected event,
    Emitter<AppShellState> emit,
  ) {
    if (event.index == state.selectedIndex) {
      return; // no-op transition is dropped, not re-emitted
    }
    emit(AppShellActive(event.index));
  }
}
