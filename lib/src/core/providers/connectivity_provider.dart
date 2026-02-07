import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/connectivity_service.dart';

part 'connectivity_provider.g.dart';

/// Connectivity state provider - watches network status
@Riverpod(keepAlive: true)
class Connectivity extends _$Connectivity {
  StreamSubscription<ConnectionStatus>? _subscription;

  @override
  bool build() {
    _subscription?.cancel();
    _subscription = ConnectivityService().statusStream.listen((status) {
      state = status == ConnectionStatus.online;
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return ConnectivityService().isOnline;
  }
}
