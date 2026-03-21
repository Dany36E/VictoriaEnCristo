import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio singleton para monitorear conectividad de red.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService I = ConnectivityService._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    isOnline.value = !results.contains(ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = !results.contains(ConnectivityResult.none);
    });
    debugPrint('🌐 [CONNECTIVITY] init → online=${isOnline.value}');
  }

  bool get hasInternet => isOnline.value;

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
