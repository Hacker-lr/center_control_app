import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'device_config.dart';
import 'device_connection.dart';

/// ============================================================
/// 视频矩阵设备连接管理服务（单例模式）
/// 负责管理与视频矩阵设备的TCP/UDP连接
/// 包含心跳检测与自动重连机制
/// 遵循与 DeviceConnection 相同的架构模式
/// ============================================================
class MatrixConnection extends ChangeNotifier {
  // ---------- 单例模式 ----------
  static final MatrixConnection _instance = MatrixConnection._internal();

  /// 工厂构造函数：返回全局唯一的单例实例
  factory MatrixConnection() => _instance;

  /// 私有内部构造函数：防止外部直接实例化
  MatrixConnection._internal();

  // ---------- 连接相关成员变量 ----------

  /// 视频矩阵设备的TCP Socket 实例
  Socket? _socket;

  /// 当前与视频矩阵设备的连接状态
  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// 心跳定时器（周期性检测连接是否存活）
  Timer? _heartbeatTimer;

  /// 自动重连定时器（断连后定期尝试重连）
  Timer? _reconnectTimer;

  /// 最近一次收到设备响应的时间戳（用于心跳超时判定）
  DateTime? _lastHeartbeatResponse;

  /// 标记是否为用户主动断开连接（主动断开时不自动重连）
  bool _isManualDisconnect = false;

  /// 心跳包累计发送次数计数器
  int _heartbeatCount = 0;

  // ---------- 公开属性（供UI层读取） ----------

  /// 获取当前连接状态
  ConnectionStatus get status => _status;

  /// 判断当前是否已与视频矩阵设备建立连接
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 获取心跳包发送次数
  int get heartbeatCount => _heartbeatCount;

  /// 获取最近一次收到设备响应的时间
  DateTime? get lastHeartbeatResponse => _lastHeartbeatResponse;

  // ---------- 连接管理公开方法 ----------

  /// ============================================================
  /// 建立与视频矩阵设备的TCP/UDP连接
  /// App启动时调用，连接成功后自动启动心跳检测
  /// ============================================================
  Future<void> connect() async {
    // 防止重复连接
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      debugPrint('[矩阵连接] 已连接或正在连接中，跳过');
      return;
    }

    _isManualDisconnect = false;
    await _establishConnection();
    _startHeartbeat();
  }

  /// ============================================================
  /// 断开与视频矩阵设备的连接
  /// [manual] 为 true 时表示用户主动断开，不触发自动重连机制
  /// ============================================================
  void disconnect({bool manual = true}) {
    _isManualDisconnect = manual;

    // 取消所有定时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 销毁Socket连接
    _socket?.destroy();
    _socket = null;

    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[矩阵连接] 已断开连接');
  }

  /// ============================================================
  /// 向视频矩阵设备发送控制指令
  /// [command] 控制指令内容，根据 [DeviceConfig.matrixSendAsHex] 决定解析方式：
  ///   - ASCII模式(matrixSendAsHex=false): command 为纯文本字符串，按字符编码发送
  ///   - 16进制模式(matrixSendAsHex=true):  command 为空格分隔的16进制字符串，
  ///     如 "02 03 01 03 FF"，解析为原始字节后发送
  /// 返回值：true 表示发送成功，false 表示发送失败
  /// ============================================================
  Future<bool> sendCommand(String command) async {
    // 检查连接是否存在
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[矩阵连接] 未连接，无法发送指令: $command');
      return false;
    }

    try {
      // 根据配置选择发送方式
      final Uint8List data = DeviceConfig.matrixSendAsHex
          ? _hexStringToBytes(command) // 16进制模式：解析hex字符串为字节数组
          : Uint8List.fromList(command.codeUnits); // ASCII模式：直接编码为字节

      // 将字节数组写入Socket
      _socket!.add(data);
      await _socket!.flush(); // 确保数据立即发送

      // 日志输出：16进制模式下同时打印原始hex和解析后的字节
      if (DeviceConfig.matrixSendAsHex) {
        final hexStr =
            data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        debugPrint('[矩阵连接] 指令发送成功(HEX): $command → [$hexStr]');
      } else {
        debugPrint('[矩阵连接] 指令发送成功: $command');
      }
      return true;
    } catch (e) {
      debugPrint('[矩阵连接] 指令发送失败: $e');
      // 发送异常说明连接可能已断开，触发断连处理
      _handleDisconnection();
      return false;
    }
  }

  /// ============================================================
  /// 释放连接资源（App退出时调用）
  /// ============================================================
  @override
  void dispose() {
    disconnect(manual: true);
    super.dispose();
  }

  // ---------- 16进制解析工具 ----------

  /// ============================================================
  /// 将空格分隔的16进制字符串解析为字节数组
  /// [hexStr] 格式示例: "02 03 01 05 FF" 或 "02,03,01,05,FF"
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
        debugPrint('[矩阵连接] 16进制解析错误: "$part" 不是有效的16进制值');
        // 解析失败时填入0x00占位
        bytes.add(0);
      }
    }

    return Uint8List.fromList(bytes);
  }

  // ---------- 私有方法：连接建立与维护 ----------

  /// ============================================================
  /// 建立TCP或UDP连接的核心实现
  /// 根据 [DeviceConfig.useTcp] 的值选择通信协议
  /// ============================================================
  Future<void> _establishConnection() async {
    _updateStatus(ConnectionStatus.connecting);

    try {
      if (DeviceConfig.useTcp) {
        // ---- TCP连接模式 ----
        _socket = await Socket.connect(
          DeviceConfig.matrixDeviceIp,
          DeviceConfig.matrixDevicePort,
          timeout: Duration(seconds: DeviceConfig.connectionTimeoutSeconds),
        );

        // 启用TCP_NODELAY选项：数据不等待缓冲区填满，立即发送
        _socket!.setOption(SocketOption.tcpNoDelay, true);

        // 注册数据接收回调，监听设备下发的响应数据
        _socket!.listen(
          _onDataReceived,
          onError: _onSocketError,
          onDone: _onSocketDone,
          cancelOnError: false,
        );

        debugPrint('[矩阵连接] TCP连接建立成功 -> '
            '${DeviceConfig.matrixDeviceIp}:${DeviceConfig.matrixDevicePort}');
      } else {
        // ---- UDP连接模式 ----
        final udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0, // 端口号0：由操作系统自动分配可用端口
        );

        // 监听UDP数据接收事件
        udpSocket.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = udpSocket.receive();
            if (datagram != null) {
              _lastHeartbeatResponse = DateTime.now();
              debugPrint('[矩阵连接-UDP] 收到数据: '
                  '${String.fromCharCodes(datagram.data)}');
            }
          }
        });

        debugPrint('[矩阵连接] UDP绑定成功，目标 -> '
            '${DeviceConfig.matrixDeviceIp}:${DeviceConfig.matrixDevicePort}');
      }

      // 更新状态为已连接，记录响应时间
      _updateStatus(ConnectionStatus.connected);
      _lastHeartbeatResponse = DateTime.now();

      // 连接成功后停止重连定时器
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      debugPrint('[矩阵连接] 连接建立失败: $e');
      _updateStatus(ConnectionStatus.error);
      // 连接失败立即启动自动重连
      _startReconnect();
    }
  }

  /// ============================================================
  /// 收到视频矩阵设备下发数据的回调
  /// 接收到任何数据都视为连接存活，刷新心跳响应时间
  /// ============================================================
  void _onDataReceived(Uint8List data) {
    _lastHeartbeatResponse = DateTime.now();
    final message = String.fromCharCodes(data);
    debugPrint('[矩阵连接] 收到数据: $message');
  }

  /// ============================================================
  /// Socket发生错误时的回调（网络中断等）
  /// ============================================================
  void _onSocketError(dynamic error) {
    debugPrint('[矩阵连接] Socket错误: $error');
    _handleDisconnection();
  }

  /// ============================================================
  /// Socket被对端关闭时的回调
  /// ============================================================
  void _onSocketDone() {
    debugPrint('[矩阵连接] Socket连接已关闭');
    _handleDisconnection();
  }

  /// ============================================================
  /// 统一处理断连逻辑：
  /// 1. 销毁Socket 2. 更新状态 3. 启动自动重连
  /// ============================================================
  void _handleDisconnection() {
    _socket?.destroy();
    _socket = null;

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }

    // 非手动断开时自动启动重连
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  // ---------- 心跳机制 ----------

  /// ============================================================
  /// 启动心跳检测定时器
  /// 每隔 [DeviceConfig.heartbeatIntervalSeconds] 秒发送一次心跳包
  /// ============================================================
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.heartbeatIntervalSeconds),
      (_) => _sendHeartbeat(),
    );

    debugPrint('[矩阵连接] 心跳检测已启动，间隔: '
        '${DeviceConfig.heartbeatIntervalSeconds}秒');
  }

  /// ============================================================
  /// 发送心跳包并检测连接是否存活
  /// 若连续超时未收到响应，判定为断连并触发重连
  /// ============================================================
  Future<void> _sendHeartbeat() async {
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[矩阵连接] 未连接，跳过心跳发送');
      return;
    }

    try {
      // [开发者可修改] 视频矩阵设备的心跳包指令内容
      // ASCII模式示例: 'HEARTBEAT\r\n'
      // 16进制模式示例: 'FF 00 00 00 01' (根据实际设备协议修改)
      // 指令格式跟随 [DeviceConfig.matrixSendAsHex] 配置自动切换
      const heartbeatCommand = 'HEARTBEAT\r\n';

      // 根据配置选择发送方式
      final Uint8List data = DeviceConfig.matrixSendAsHex
          ? _hexStringToBytes(heartbeatCommand)
          : Uint8List.fromList(heartbeatCommand.codeUnits);
      _socket!.add(data);
      await _socket!.flush();

      _heartbeatCount++;
      debugPrint('[矩阵连接] 心跳包已发送 (#$_heartbeatCount)');

      // 检测上次心跳是否超时（超过3倍心跳间隔未响应即为超时）
      if (_lastHeartbeatResponse != null) {
        final elapsed = DateTime.now()
            .difference(_lastHeartbeatResponse!)
            .inSeconds;
        if (elapsed > DeviceConfig.heartbeatIntervalSeconds * 3) {
          debugPrint('[矩阵连接] 心跳超时未响应，判定为断连');
          _handleDisconnection();
        }
      }
    } catch (e) {
      debugPrint('[矩阵连接] 心跳发送异常: $e');
      _handleDisconnection();
    }
  }

  // ---------- 自动重连机制 ----------

  /// ============================================================
  /// 启动自动重连定时器
  /// 每隔 [DeviceConfig.reconnectIntervalSeconds] 秒尝试重新连接
  /// ============================================================
  void _startReconnect() {
    // 防止重复启动
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    // 手动断开时不进行自动重连
    if (_isManualDisconnect) return;

    debugPrint('[矩阵连接] 自动重连已启动，间隔: '
        '${DeviceConfig.reconnectIntervalSeconds}秒');

    _reconnectTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.reconnectIntervalSeconds),
      (_) async {
        // 如果用户主动断开，停止重连
        if (_isManualDisconnect) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }
        // 如果已经连接成功，停止重连
        if (_status == ConnectionStatus.connected) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }

        debugPrint('[矩阵连接] 尝试重连...');
        await _establishConnection();

        // 重连成功则启动心跳
        if (_status == ConnectionStatus.connected) {
          _startHeartbeat();
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }
      },
    );
  }

  /// ============================================================
  /// 更新连接状态并通知所有监听者刷新UI
  /// ============================================================
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      debugPrint('[矩阵连接] 状态变更: $newStatus');
    }
  }
}
