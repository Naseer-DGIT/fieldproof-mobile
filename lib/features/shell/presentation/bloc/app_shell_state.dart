import 'package:equatable/equatable.dart';

/// States emitted by [AppShellBloc].
sealed class AppShellState extends Equatable {
  final int selectedIndex;

  const AppShellState(this.selectedIndex);

  @override
  List<Object?> get props => [selectedIndex];
}

/// Shell has not received any event yet.
class AppShellInitial extends AppShellState {
  const AppShellInitial() : super(0);
}

/// A tab is active.
class AppShellActive extends AppShellState {
  const AppShellActive(super.selectedIndex);
}
