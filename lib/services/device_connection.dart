import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'device_config.dart';

/// ============================================================
/// 设备连接状态枚举
/// 用于描述当前与设备的连接情况
/// ============================================================
enum ConnectionStatus {
  disconnected,  // 未连接
  connecting,    // 正在连接中
  connected,     // 已连接
  error,         // 连接出错
}

/// ============================================================
/// 设备连接管理服务（单例模式）
/// 负责管理与时序电源设备的TCP/UDP连接
/// 包含心跳检测与自动重连机制
/// ============================================================
class DeviceConnection extends ChangeNotifier {
  // ---------- 单例模式 ----------
  static final DeviceConnection _instance = DeviceConnection._internal();

  /// 工厂构造函数返回单例实例
  factory DeviceConnection() => _instance;

  /// 私有内部构造函数
  DeviceConnection._internal();

  // ---------- 连接相关成员变量 ----------

  /// TCP Socket 实例
  Socket? _socket;

  /// 当前连接状态，外部通过 [status] getter 访问
  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// 心跳定时器
  Timer? _heartbeatTimer;

  /// 重连定时器
  Timer? _reconnectTimer;

  /// 上一次心跳响应时间（用于判断连接是否存活）
  DateTime? _lastHeartbeatResponse;

  /// 标记是否用户主动断开（避免自动重连）
  bool _isManualDisconnect = false;

  /// 心跳包发送次数计数器
  int _heartbeatCount = 0;

  // ---------- 公开属性 ----------

  /// 当前连接状态
  ConnectionStatus get status => _status;

  /// 是否处于已连接状态
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 心跳计数
  int get heartbeatCount => _heartbeatCount;

  /// 上一次心跳响应时间
  DateTime? get lastHeartbeatResponse => _lastHeartbeatResponse;

  // ---------- 连接管理 ----------

  /// ============================================================
  /// 初始化连接：App启动时调用，自动建立与设备的TCP/UDP连接
  /// 并根据配置启动心跳检测机制
  /// ============================================================
  Future<void> connect() async {
    // 如果已经连接或正在连接，则不重复操作
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
  /// [manual] 为true表示用户主动断开，不触发自动重连
  /// ============================================================
  void disconnect({bool manual = true}) {
    _isManualDisconnect = manual;

    // 停止所有定时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 关闭Socket连接
    _socket?.destroy();
    _socket = null;

    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[设备连接] 已断开连接');
  }

  /// ============================================================
  /// 发送控制指令到设备
  /// [command] 控制指令内容，根据 [DeviceConfig.powerSendAsHex] 决定解析方式：
  ///   - ASCII模式(powerSendAsHex=false): command 为纯文本字符串，按字符编码发送
  ///   - 16进制模式(powerSendAsHex=true):  command 为空格分隔的16进制字符串，
  ///     如 "01 05 00 00 FF 00"，解析为原始字节后发送
  /// 返回是否发送成功
  /// ============================================================
  Future<bool> sendCommand(String command) async {
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[设备连接] 未连接，无法发送指令: $command');
      return false;
    }

    try {
      // 根据配置选择发送方式
      final Uint8List data = DeviceConfig.powerSendAsHex
          ? _hexStringToBytes(command) // 16进制模式：解析hex字符串为字节数组
          : Uint8List.fromList(command.codeUnits); // ASCII模式：直接编码为字节

      // 将字节数组写入Socket
      _socket!.add(data);
      await _socket!.flush();

      // 日志输出：16进制模式下同时打印原始hex和解析后的字节
      if (DeviceConfig.powerSendAsHex) {
        final hexStr =
            data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        debugPrint('[设备连接] 指令发送成功(HEX): $command → [$hexStr]');
      } else {
        debugPrint('[设备连接] 指令发送成功: $command');
      }
      return true;
    } catch (e) {
      debugPrint('[设备连接] 指令发送失败: $e');
      // 发送失败说明连接可能已断开，触发重连
      _handleDisconnection();
      return false;
    }
  }

  /// ============================================================
  /// 释放所有资源：在App退出时调用
  /// ============================================================
  @override
  void dispose() {
    disconnect(manual: true);
    super.dispose();
  }

  // ---------- 16进制解析工具 ----------

  /// ============================================================
  /// 将空格分隔的16进制字符串解析为字节数组
  /// [hexStr] 格式示例: "01 05 00 00 FF 00" 或 "01,05,00,00,FF,00"
  /// 支持大小写混合、逗号或空格分隔、可选的0x前缀
  /// 返回解析后的Uint8List
  /// ============================================================
  static Uint8List _hexStringToBytes(String hexStr) {
    // 去除所有可能的分隔符：空格、逗号、制表符、换行符
    final String cleaned = hexStr
        .replaceAll('0x', '')   // 去除 0x 前缀
        .replaceAll('0X', '')   // 去除 0X 前缀
        .replaceAll(',', ' ')   // 逗号替换为空格
        .replaceAll(';', ' ')   // 分号替换为空格
        .replaceAll(RegExp(r'\s+'), ' ') // 合并多个连续空白
        .trim();

    // 按空格分割，逐个解析为字节
    final List<String> parts = cleaned.split(' ');
    final List<int> bytes = [];

    for (final part in parts) {
      // 跳过空字符串
      if (part.isEmpty) continue;

      try {
        // 将16进制字符串解析为整数
        final int byteValue = int.parse(part, radix: 16);
        // 确保值在0~255之间（单字节范围）
        bytes.add(byteValue.clamp(0, 255));
      } catch (e) {
        debugPrint('[设备连接] 16进制解析错误: "$part" 不是有效的16进制值');
        // 解析失败时填入0x00占位
        bytes.add(0);
      }
    }

    return Uint8List.fromList(bytes);
  }

  // ---------- 私有方法：内部实现 ----------

  /// ============================================================
  /// 建立TCP或UDP连接的核心方法
  /// 根据 [DeviceConfig.useTcp] 选择协议类型
  /// ============================================================
  Future<void> _establishConnection() async {
    _updateStatus(ConnectionStatus.connecting);

    try {
      if (DeviceConfig.useTcp) {
        // ---- TCP连接模式 ----
        _socket = await Socket.connect(
          DeviceConfig.powerDeviceIp,
          DeviceConfig.powerDevicePort,
          timeout: Duration(seconds: DeviceConfig.connectionTimeoutSeconds),
        );

        // 设置TCP选项：启用TCP_NODELAY以立即发送数据（不等待缓冲区填满）
        _socket!.setOption(SocketOption.tcpNoDelay, true);

        // 监听来自设备的数据（服务器可能回传确认信息）
        _socket!.listen(
          _onDataReceived,
          onError: _onSocketError,
          onDone: _onSocketDone,
          cancelOnError: false,
        );

        debugPrint('[设备连接] TCP连接建立成功 -> '
            '${DeviceConfig.powerDeviceIp}:${DeviceConfig.powerDevicePort}');
      } else {
        // ---- UDP连接模式 ----
        // 创建UDP Socket并绑定到任意可用端口
        final udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0, // 端口号0表示系统自动分配
        );

        // 监听UDP数据接收
        udpSocket.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = udpSocket.receive();
            if (datagram != null) {
              _lastHeartbeatResponse = DateTime.now();
              debugPrint('[设备连接-UDP] 收到数据: '
                  '${String.fromCharCodes(datagram.data)}');
            }
          }
        });

        debugPrint('[设备连接] UDP绑定成功，目标 -> '
            '${DeviceConfig.powerDeviceIp}:${DeviceConfig.powerDevicePort}');
      }

      _updateStatus(ConnectionStatus.connected);
      _lastHeartbeatResponse = DateTime.now();

      // 停止重连定时器（如果之前有在重连）
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      debugPrint('[设备连接] 连接建立失败: $e');
      _updateStatus(ConnectionStatus.error);
      // 连接失败，自动启动重连机制
      _startReconnect();
    }
  }

  /// ============================================================
  /// 收到设备数据时的回调
  /// [data] 接收到的原始字节数据
  /// ============================================================
  void _onDataReceived(Uint8List data) {
    // 收到任何数据都视为连接存活，更新心跳响应时间
    _lastHeartbeatResponse = DateTime.now();
    final message = String.fromCharCodes(data);
    debugPrint('[设备连接] 收到数据: $message');
  }

  /// ============================================================
  /// Socket发生错误时的回调
  /// ============================================================
  void _onSocketError(dynamic error) {
    debugPrint('[设备连接] Socket错误: $error');
    _handleDisconnection();
  }

  /// ============================================================
  /// Socket连接关闭时的回调（对方主动断开或网络中断）
  /// ============================================================
  void _onSocketDone() {
    debugPrint('[设备连接] Socket连接已关闭');
    _handleDisconnection();
  }

  /// ============================================================
  /// 处理断连：更新状态并启动重连机制
  /// ============================================================
  void _handleDisconnection() {
    _socket?.destroy();
    _socket = null;

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }

    // 非手动断开时，自动启动重连
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  /// ============================================================
  /// 心跳检测机制
  /// 每隔 [DeviceConfig.heartbeatIntervalSeconds] 秒发送一次心跳包
  /// 检测连接是否存活
  /// ============================================================
  void _startHeartbeat() {
    // 取消已有的心跳定时器
    _heartbeatTimer?.cancel();

    // 创建周期性心跳定时器
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.heartbeatIntervalSeconds),
      (_) => _sendHeartbeat(),
    );

    debugPrint('[设备连接] 心跳检测已启动，间隔: '
        '${DeviceConfig.heartbeatIntervalSeconds}秒');
  }

  /// ============================================================
  /// 发送心跳包
  /// 若发送失败或超时未响应，判定为断连并触发重连
  /// ============================================================
  Future<void> _sendHeartbeat() async {
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[设备连接] 未连接，跳过心跳发送');
      return;
    }

    try {
      // [开发者可修改] 心跳包指令内容
      // ASCII模式示例: 'HEARTBEAT\r\n'
      // 16进制模式示例: 'FF 00 00 00 01' (根据实际设备协议修改)
      // 指令格式跟随 [DeviceConfig.powerSendAsHex] 配置自动切换
      const heartbeatCommand = 'HEARTBEAT\r\n';

      // 根据配置选择发送方式
      final Uint8List data = DeviceConfig.powerSendAsHex
          ? _hexStringToBytes(heartbeatCommand)
          : Uint8List.fromList(heartbeatCommand.codeUnits);
      _socket!.add(data);
      await _socket!.flush();

      _heartbeatCount++;
      debugPrint('[设备连接] 心跳包已发送 (#$_heartbeatCount)');

      // 检查上一次心跳响应是否超时
      // 如果上次心跳响应在2倍心跳间隔内未收到，可能已断连
      if (_lastHeartbeatResponse != null) {
        final elapsed = DateTime.now()
            .difference(_lastHeartbeatResponse!)
            .inSeconds;
        if (elapsed > DeviceConfig.heartbeatIntervalSeconds * 3) {
          debugPrint('[设备连接] 心跳超时未响应，判定为断连');
          _handleDisconnection();
        }
      }
    } catch (e) {
      debugPrint('[设备连接] 心跳发送异常: $e');
      _handleDisconnection();
    }
  }

  /// ============================================================
  /// 自动重连机制
  /// 每隔 [DeviceConfig.reconnectIntervalSeconds] 秒尝试重连
  /// ============================================================
  void _startReconnect() {
    // 避免重复启动重连定时器
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }
    // 手动断开时不重连
    if (_isManualDisconnect) {
      return;
    }

    debugPrint('[设备连接] 自动重连已启动，间隔: '
        '${DeviceConfig.reconnectIntervalSeconds}秒');

    _reconnectTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.reconnectIntervalSeconds),
      (_) async {
        if (_isManualDisconnect) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }

        if (_status == ConnectionStatus.connected) {
          // 已经连接成功，停止重连
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }

        debugPrint('[设备连接] 尝试重连...');
        await _establishConnection();

        // 重连成功后启动心跳
        if (_status == ConnectionStatus.connected) {
          _startHeartbeat();
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }
      },
    );
  }

  /// ============================================================
  /// 更新连接状态并通知所有监听者（UI组件）
  /// ============================================================
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners(); // 通知UI刷新
      debugPrint('[设备连接] 状态变更: $newStatus');
    }
  }
}
