import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    // Initial check
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen to changes
    _connectivity.onConnectivityChanged.listen((results) {
      // connectivity_plus 6.0.0+ returns a List<ConnectivityResult>
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // We are online if any result is NOT .none
    final bool online =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
      debugPrint(
        'Connectivity Status Changed: ${online ? "ONLINE" : "OFFLINE"}',
      );
    }
  }

  void dispose() {
    _controller.close();
  }
}
