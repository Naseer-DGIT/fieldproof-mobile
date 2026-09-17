import 'dart:async';

/// Global signal channel from the network layer to the auth layer.
///
/// The Dio error interceptor cannot reach the AuthBloc directly (it has no
/// BuildContext). It pushes a signal here; the AuthBloc subscribes in its
/// constructor and reacts by emitting Unauthenticated.
class AuthSignals {
  AuthSignals._();

  static final _controller = StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void sessionExpired() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  static Future<void> dispose() => _controller.close();
}
