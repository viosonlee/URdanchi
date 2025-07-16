import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  final StreamController<NetworkStatus> _statusController = StreamController<NetworkStatus>.broadcast();

  Stream<NetworkStatus> get networkStatus => _statusController.stream;

  bool get hasConnection => _connectionStatus.isNotEmpty && !_connectionStatus.contains(ConnectivityResult.none);
  
  bool get isOnUnmeteredNetwork {
    return _connectionStatus.contains(ConnectivityResult.wifi) || 
           _connectionStatus.contains(ConnectivityResult.ethernet);
  }
  
  bool get isOnMeteredNetwork {
    return _connectionStatus.contains(ConnectivityResult.mobile) ||
           _connectionStatus.contains(ConnectivityResult.vpn);
  }

  NetworkStatus get currentStatus {
    if (!hasConnection) return NetworkStatus.offline;
    if (isOnUnmeteredNetwork) return NetworkStatus.unmetered;
    if (isOnMeteredNetwork) return NetworkStatus.metered;
    return NetworkStatus.unknown;
  }

  Future<void> initialize() async {
    try {
      final initialStatus = await _connectivity.checkConnectivity();
      _connectionStatus = initialStatus;
      _statusController.add(currentStatus);
      
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> result) {
          _connectionStatus = result;
          _statusController.add(currentStatus);
          debugPrint('网络状态变化: ${result.map((e) => e.name).join(', ')} -> ${currentStatus.name}');
        },
      );
    } catch (e) {
      debugPrint('初始化网络状态监听错误: $e');
      _connectionStatus = [ConnectivityResult.none];
      _statusController.add(NetworkStatus.offline);
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _statusController.close();
  }
}

enum NetworkStatus {
  offline,     // 无网络连接
  unmetered,   // 非计费网络(WiFi, 以太网)
  metered,     // 计费网络(移动数据, VPN)
  unknown      // 未知网络类型
}