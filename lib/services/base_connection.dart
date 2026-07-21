import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'device_config.dart';

/// ============================================================
/// 连接状态枚举，定义了设备连接的四种状态
/// ============================================================
enum ConnectionStatus {
  /// 未连接状态，设备尚未建立连接或已断开
  disconnected,

  /// 连接中状态，正在尝试建立连接
  connecting,

  /// 已连接状态，设备连接成功且正常通信
  connected,

  /// 错误状态，连接过程中发生错误
  error,
}

/// ============================================================
/// 设备连接抽象基类，提供TCP/UDP连接管理、心跳检测和自动重连功能
/// 继承自ChangeNotifier，用于通知连接状态变化
/// ============================================================
abstract class BaseConnection extends ChangeNotifier {
  /// TCP套接字实例，用于TCP模式下与设备进行网络通信，初始值为null表示未连接
  Socket? _tcpSocket;

  /// UDP数据报套接字实例，用于UDP模式下与设备进行网络通信，初始值为null表示未连接
  RawDatagramSocket? _udpSocket;

  /// 当前连接状态，初始值为disconnected表示未连接
  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// 心跳定时器，用于定期发送心跳包检测连接状态，初始值为null
  Timer? _heartbeatTimer;

  /// 重连定时器，用于连接断开后自动尝试重连，初始值为null
  Timer? _reconnectTimer;

  /// 最后一次收到心跳响应的时间戳，用于判断连接是否超时，初始值为null
  DateTime? _lastHeartbeatResponse;

  /// 是否为手动断开连接的标志，初始值为false表示自动连接状态
  bool _isManualDisconnect = false;

  /// 心跳包发送计数器，记录已发送的心跳包数量，初始值为0
  int _heartbeatCount = 0;

  /// 配置实例，用于获取连接超时、心跳间隔等配置参数
  final DeviceConfig _config = DeviceConfig();

  /// 获取当前连接状态
  ConnectionStatus get status => _status;

  /// 判断是否已连接，返回true表示已成功连接
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 获取心跳包发送次数
  int get heartbeatCount => _heartbeatCount;

  /// 获取最后一次心跳响应的时间
  DateTime? get lastHeartbeatResponse => _lastHeartbeatResponse;

  /// 设备IP地址，子类必须实现此抽象属性
  String get deviceIp;

  /// 设备端口号，子类必须实现此抽象属性
  int get devicePort;

  /// 是否使用TCP协议（true=TCP，false=UDP），子类必须实现此抽象属性
  bool get useTcp;

  /// 是否以十六进制格式发送数据，子类必须实现此抽象属性
  bool get sendAsHex;

  /// 心跳检测命令，子类必须实现此抽象属性
  String get heartbeatCommand;

  /// ============================================================
  /// 建立与设备的连接（自动选择TCP或UDP）
  /// 如果当前已连接或正在连接，则直接返回
  /// 连接成功后会自动启动心跳检测
  /// ============================================================
  Future<void> connect() async {
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      return;
    }
    _isManualDisconnect = false;
    await _establishConnection();
    _startHeartbeat();
  }

  /// ============================================================
  /// 断开与设备的连接
  /// [manual] 参数表示是否为手动断开，默认值为true
  /// 手动断开时不会触发自动重连，自动断开（如网络异常）时会触发重连
  /// ============================================================
  void disconnect({bool manual = true}) {
    _isManualDisconnect = manual;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _tcpSocket?.destroy();
    _tcpSocket = null;

    _udpSocket?.close();
    _udpSocket = null;

    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[$runtimeType] 已断开连接');
  }

  /// ============================================================
  /// 释放资源，清理连接相关的所有定时器和套接字
  /// ============================================================
  @override
  void dispose() {
    disconnect(manual: true);
    super.dispose();
  }

  /// ============================================================
  /// 向设备发送指令
  /// [command] 参数为要发送的指令字符串，可以是普通文本或十六进制格式
  /// 返回值为bool类型，true表示发送成功，false表示发送失败或未连接
  /// ============================================================
  Future<bool> sendCommand(String command) async {
    if (_status != ConnectionStatus.connected) {
      debugPrint('[$runtimeType] 未连接，无法发送指令: $command');
      return false;
    }

    try {
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(command)
          : Uint8List.fromList(command.codeUnits);

      if (useTcp) {
        if (_tcpSocket == null) {
          debugPrint('[$runtimeType] TCP套接字为空');
          return false;
        }
        _tcpSocket!.add(data);
        await _tcpSocket!.flush();
      } else {
        if (_udpSocket == null) {
          debugPrint('[$runtimeType] UDP套接字为空');
          return false;
        }
        _udpSocket!.send(data, InternetAddress(deviceIp), devicePort);
      }

      if (sendAsHex) {
        final hexStr = data
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        debugPrint('[$runtimeType] 指令发送成功(HEX): $command → [$hexStr]');
      } else {
        debugPrint('[$runtimeType] 指令发送成功: $command');
      }
      return true;
    } catch (e) {
      debugPrint('[$runtimeType] 指令发送失败: $e');
      _handleDisconnection();
      return false;
    }
  }

  /// ============================================================
  /// 将十六进制字符串转换为字节列表
  /// [hexStr] 参数为十六进制格式的字符串，支持多种格式如"0x1A 0x2B"、"1A,2B"、"1A 2B"等
  /// 返回值为转换后的Uint8List字节数组
  /// ============================================================
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
        debugPrint('[$runtimeType] 16进制解析错误: "$part"');
        bytes.add(0);
      }
    }
    return Uint8List.fromList(bytes);
  }

  /// ============================================================
  /// 建立连接的内部方法（支持TCP和UDP）
  /// ============================================================
  Future<void> _establishConnection() async {
    _updateStatus(ConnectionStatus.connecting);

    try {
      if (useTcp) {
        _tcpSocket = await Socket.connect(
          deviceIp,
          devicePort,
          timeout: Duration(seconds: _config.connectionTimeoutSeconds),
        );
        _tcpSocket!.setOption(SocketOption.tcpNoDelay, true);
        _tcpSocket!.listen(
          _onDataReceived,
          onError: _onSocketError,
          onDone: _onSocketDone,
          cancelOnError: false,
        );
        debugPrint('[$runtimeType] TCP连接成功 -> $deviceIp:$devicePort');
      } else {
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _udpSocket!.listen(_onUdpDataReceived);
        debugPrint('[$runtimeType] UDP连接成功 -> $deviceIp:$devicePort');
      }

      _updateStatus(ConnectionStatus.connected);
      _lastHeartbeatResponse = DateTime.now();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      debugPrint('[$runtimeType] 连接失败: $e');
      _updateStatus(ConnectionStatus.error);
      _startReconnect();
    }
  }

  /// ============================================================
  /// TCP Socket数据接收回调方法
  /// ============================================================
  void _onDataReceived(Uint8List data) {
    _lastHeartbeatResponse = DateTime.now();
    debugPrint('[$runtimeType] 收到数据: ${String.fromCharCodes(data)}');
  }

  /// ============================================================
  /// UDP Socket数据接收回调方法
  /// ============================================================
  void _onUdpDataReceived(RawSocketEvent event) {
    if (event == RawSocketEvent.read && _udpSocket != null) {
      final Datagram? datagram = _udpSocket!.receive();
      if (datagram != null) {
        _lastHeartbeatResponse = DateTime.now();
        debugPrint(
          '[$runtimeType] UDP收到数据: ${String.fromCharCodes(datagram.data)}',
        );
      }
    }
  }

  /// ============================================================
  /// TCP Socket错误回调方法
  /// ============================================================
  void _onSocketError(dynamic error) {
    debugPrint('[$runtimeType] Socket错误: $error');
    _handleDisconnection();
  }

  /// ============================================================
  /// TCP Socket关闭回调方法
  /// ============================================================
  void _onSocketDone() {
    debugPrint('[$runtimeType] Socket已关闭');
    _handleDisconnection();
  }

  /// ============================================================
  /// 处理连接断开的内部方法
  /// ============================================================
  void _handleDisconnection() {
    _tcpSocket?.destroy();
    _tcpSocket = null;
    _udpSocket?.close();
    _udpSocket = null;

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  /// ============================================================
  /// 启动心跳检测机制
  /// ============================================================
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (heartbeatCommand.isEmpty) {
      debugPrint('[$runtimeType] 心跳命令为空，跳过心跳检测');
      return;
    }
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: _config.heartbeatIntervalSeconds),
      (_) => _sendHeartbeat(),
    );
    debugPrint('[$runtimeType] 心跳检测已启动');
  }

  /// ============================================================
  /// 发送心跳包的内部方法（支持TCP和UDP）
  /// ============================================================
  Future<void> _sendHeartbeat() async {
    if (_status != ConnectionStatus.connected) return;

    try {
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(heartbeatCommand)
          : Uint8List.fromList(heartbeatCommand.codeUnits);

      if (useTcp) {
        if (_tcpSocket == null) return;
        _tcpSocket!.add(data);
        await _tcpSocket!.flush();
      } else {
        if (_udpSocket == null) return;
        _udpSocket!.send(data, InternetAddress(deviceIp), devicePort);
      }

      _heartbeatCount++;
      debugPrint('[$runtimeType] 心跳包已发送 (#$_heartbeatCount)');

      if (_lastHeartbeatResponse != null) {
        final elapsed = DateTime.now()
            .difference(_lastHeartbeatResponse!)
            .inSeconds;
        if (elapsed >
            _config.heartbeatIntervalSeconds *
                _config.heartbeatTimeoutMultiplier) {
          debugPrint('[$runtimeType] 心跳超时');
          _handleDisconnection();
        }
      }
    } catch (e) {
      debugPrint('[$runtimeType] 心跳异常: $e');
      _handleDisconnection();
    }
  }

  /// ============================================================
  /// 启动自动重连机制
  /// ============================================================
  void _startReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    if (_isManualDisconnect) return;

    debugPrint('[$runtimeType] 自动重连已启动');
    _reconnectTimer = Timer.periodic(
      Duration(seconds: _config.reconnectIntervalSeconds),
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

  /// ============================================================
  /// 更新连接状态的内部方法
  /// ============================================================
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      debugPrint('[$runtimeType] 状态变更: $newStatus');
    }
  }
}
