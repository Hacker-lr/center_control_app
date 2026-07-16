import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

abstract class BaseConnection extends ChangeNotifier {
  Socket? _socket;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastHeartbeatResponse;
  bool _isManualDisconnect = false;
  int _heartbeatCount = 0;

  ConnectionStatus get status => _status;
  bool get isConnected => _status == ConnectionStatus.connected;
  int get heartbeatCount => _heartbeatCount;
  DateTime? get lastHeartbeatResponse => _lastHeartbeatResponse;

  String get deviceIp;
  int get devicePort;
  bool get sendAsHex;
  String get heartbeatCommand;

  Future<void> connect() async {
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      return;
    }
    _isManualDisconnect = false;
    await _establishConnection();
    _startHeartbeat();
  }

  void disconnect({bool manual = true}) {
    _isManualDisconnect = manual;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.destroy();
    _socket = null;
    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[${runtimeType}] 已断开连接');
  }

  @override
  void dispose() {
    disconnect(manual: true);
    super.dispose();
  }

  Future<bool> sendCommand(String command) async {
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[${runtimeType}] 未连接，无法发送指令: $command');
      return false;
    }

    try {
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(command)
          : Uint8List.fromList(command.codeUnits);

      _socket!.add(data);
      await _socket!.flush();

      if (sendAsHex) {
        final hexStr =
            data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        debugPrint('[${runtimeType}] 指令发送成功(HEX): $command → [$hexStr]');
      } else {
        debugPrint('[${runtimeType}] 指令发送成功: $command');
      }
      return true;
    } catch (e) {
      debugPrint('[${runtimeType}] 指令发送失败: $e');
      _handleDisconnection();
      return false;
    }
  }

  Uint8List _hexStringToBytes(String hexStr) {
    final String cleaned = hexStr
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final List<String> parts = cleaned.split(' ');
    final List<int> bytes = [];

    for (final part in parts) {
      if (part.isEmpty) continue;
      try {
        bytes.add(int.parse(part, radix: 16).clamp(0, 255));
      } catch (e) {
        debugPrint('[${runtimeType}] 16进制解析错误: "$part"');
        bytes.add(0);
      }
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> _establishConnection() async {
    _updateStatus(ConnectionStatus.connecting);

    try {
      _socket = await Socket.connect(
        deviceIp,
        devicePort,
        timeout: const Duration(seconds: 5),
      );
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      _socket!.listen(
        _onDataReceived,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );
      debugPrint('[${runtimeType}] TCP连接成功 -> $deviceIp:$devicePort');

      _updateStatus(ConnectionStatus.connected);
      _lastHeartbeatResponse = DateTime.now();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      debugPrint('[${runtimeType}] 连接失败: $e');
      _updateStatus(ConnectionStatus.error);
      _startReconnect();
    }
  }

  void _onDataReceived(Uint8List data) {
    _lastHeartbeatResponse = DateTime.now();
    debugPrint('[${runtimeType}] 收到数据: ${String.fromCharCodes(data)}');
  }

  void _onSocketError(dynamic error) {
    debugPrint('[${runtimeType}] Socket错误: $error');
    _handleDisconnection();
  }

  void _onSocketDone() {
    debugPrint('[${runtimeType}] Socket已关闭');
    _handleDisconnection();
  }

  void _handleDisconnection() {
    _socket?.destroy();
    _socket = null;
    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _sendHeartbeat(),
    );
    debugPrint('[${runtimeType}] 心跳检测已启动');
  }

  Future<void> _sendHeartbeat() async {
    if (_socket == null || _status != ConnectionStatus.connected) return;

    try {
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(heartbeatCommand)
          : Uint8List.fromList(heartbeatCommand.codeUnits);
      _socket!.add(data);
      await _socket!.flush();

      _heartbeatCount++;
      debugPrint('[${runtimeType}] 心跳包已发送 (#$_heartbeatCount)');

      if (_lastHeartbeatResponse != null) {
        final elapsed = DateTime.now().difference(_lastHeartbeatResponse!).inSeconds;
        if (elapsed > 180) {
          debugPrint('[${runtimeType}] 心跳超时');
          _handleDisconnection();
        }
      }
    } catch (e) {
      debugPrint('[${runtimeType}] 心跳异常: $e');
      _handleDisconnection();
    }
  }

  void _startReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    if (_isManualDisconnect) return;

    debugPrint('[${runtimeType}] 自动重连已启动');
    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        if (_isManualDisconnect) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }
        if (_status == ConnectionStatus.connected) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }
        await _establishConnection();
        if (_status == ConnectionStatus.connected) {
          _startHeartbeat();
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }
      },
    );
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      debugPrint('[${runtimeType}] 状态变更: $newStatus');
    }
  }
}