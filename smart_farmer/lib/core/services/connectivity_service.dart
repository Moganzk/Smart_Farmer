import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Simple wrapper around connectivity_plus that exposes reactive
/// connectivity changes and can drive sync-retry logic.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  bool get isOnline => _isOnline;

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _onlineController.stream;

  void _init() {
    _connectivity.checkConnectivity().then((results) {
      _update(results);
    });
    _sub = _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _isOnline) {
      _isOnline = online;
      if (kDebugMode) Log.i('Connectivity', 'Online: $online');
      _onlineController.add(online);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _onlineController.close();
    super.dispose();
  }
}
