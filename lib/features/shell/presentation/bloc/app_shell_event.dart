import 'package:equatable/equatable.dart';

/// Events understood by [AppShellBloc].
///
/// Per ADR-0001, every state transition is triggered by a named event.
/// This is the auditable, testable seam — the UI cannot mutate state
/// directly.
sealed class AppShellEvent extends Equatable {
  const AppShellEvent();

  @override
  List<Object?> get props => const [];
}

/// User selected a bottom navigation tab.
class AppShellTabSelected extends AppShellEvent {
  final int index;
  const AppShellTabSelected(this.index);

  @override
  List<Object?> get props => [index];
}
