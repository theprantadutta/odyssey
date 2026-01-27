import 'dart:async';

/// Events that can be emitted when authentication state changes externally
enum AuthEvent {
  /// Session expired (e.g., refresh token failed or 401 received)
  sessionExpired,

  /// Token refresh failed
  tokenRefreshFailed,
}

/// Service for broadcasting authentication events across the app.
///
/// This allows the network layer (interceptors) to notify the auth provider
/// when session expires without creating circular dependencies.
class AuthEventService {
  AuthEventService._();

  static final AuthEventService _instance = AuthEventService._();
  factory AuthEventService() => _instance;

  final _controller = StreamController<AuthEvent>.broadcast();

  /// Stream of auth events
  Stream<AuthEvent> get events => _controller.stream;

  /// Emit an auth event
  void emit(AuthEvent event) => _controller.add(event);

  /// Dispose the controller (typically never called for singleton)
  void dispose() => _controller.close();
}
