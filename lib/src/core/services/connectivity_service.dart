import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'logger_service.dart';

enum ConnectionStatus { online, offline }

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      final status = _isOnline ? ConnectionStatus.online : ConnectionStatus.offline;
      AppLogger.info('Connectivity changed: $status');
      _statusController.add(status);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
