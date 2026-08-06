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

  /// 轻量级存活看门狗定时器：仅周期性比对"最后收到数据的时间戳"，
  /// 不额外产生网络流量，用于把离线判定的时机从"心跳发送边界"解耦出来，
  /// 从而在不增加心跳频率的前提下缩短检测延迟
  Timer? _watchdogTimer;

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

  /// TCP 串行写队列：所有 TCP 写（指令/心跳/原始帧）共用此队列依次执行
  /// Dart Socket 不允许并发 add/flush（并发时第二次 flush 会抛
  /// "Bad state: StreamSink is bound to a stream" 并导致连接被误杀）
  Future<void> _txQueue = Future.value();

  /// 连接代数：每次成功建立连接 +1。
  /// 队列中的写任务携带入队时的代数，执行时若代数已变（期间发生过断线重连），
  /// 则丢弃该帧，避免旧连接的残留数据被误发到新连接上
  int _connGeneration = 0;

  /// 获取当前连接状态
  ConnectionStatus get status => _status;

  /// 判断是否已连接，返回true表示已成功连接
  bool get isConnected => _status == ConnectionStatus.connected;

  /// 获取心跳包发送次数
  int get heartbeatCount => _heartbeatCount;

  /// 获取最后一次心跳响应的时间
  DateTime? get lastHeartbeatResponse => _lastHeartbeatResponse;

  /// 供子类（不同 library）在应用层探活/收到确认包时刷新「最近存活」时间戳，
  /// 驱动基类看门狗逻辑（避免直接访问私有字段）。
  void markAlive() => _lastHeartbeatResponse = DateTime.now();

  /// 供子类（不同 library）在应用层探活/看门狗判定链路死亡时调用，
  /// 触发断连与自动重连（避免直接访问私有的 _handleDisconnection）。
  void reportTransportLost() => _handleDisconnection();

  /// 心跳间隔（秒），子类可重写（CIP 不发送心跳，此值对其不生效）
  int get heartbeatInterval => _config.heartbeatIntervalSeconds;

  /// 心跳超时倍数：连续多少个心跳周期无响应即判定离线。
  /// 子类可重写（CIP 用较小值以更快反馈）。实际阈值 = heartbeatInterval × 此倍数
  int get heartbeatTimeoutMultiplier => _config.heartbeatTimeoutMultiplier;

  /// 存活看门狗检查间隔（秒）：仅做时间戳比对，几乎零开销。
  /// 子类可重写。值越小离线反馈越快，但过小意义不大，默认 1 秒
  int get livenessCheckIntervalSeconds => 1;

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
    // 新生代：使任何在途的旧建连（disconnect/重连并发触发）失效，避免双 socket/双会话
    _connGeneration++;
    await _establishConnection();
    // 若建连因世代失效而中止（status 非 connected），不要启动保活定时器
    if (_status == ConnectionStatus.connected) _startKeepalive();
  }

  /// ============================================================
  /// 断开与设备的连接
  /// [manual] 参数表示是否为手动断开，默认值为true
  /// 手动断开时不会触发自动重连，自动断开（如网络异常）时会触发重连
  /// ============================================================
  void disconnect({bool manual = true}) {
    // 新生代：使任何在途建连与待发写失效，避免断连后残留帧串到新连接
    _connGeneration++;
    _isManualDisconnect = manual;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 清理TCP套接字
    _tcpSocket?.destroy();
    _tcpSocket = null;

    // 清理UDP套接字
    _udpSocket?.close();
    _udpSocket = null;

    _updateStatus(ConnectionStatus.disconnected);
    // 子类钩子：复位协议层状态（如 CIP 握手标志）
    onTransportDisconnected();
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
        // TCP模式：经串行写队列发送（失败已在队列内处理断线）
        final bool ok = await _enqueueTcpWrite(data);
        if (!ok) {
          debugPrint('[$runtimeType] 指令发送失败(TCP): $command');
          return false;
        }
      } else {
        // UDP模式：通过UDP套接字发送
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
  /// 原始字节发送（子类协议如 CIP 使用）
  /// 直接通过已建立的 Socket 发送二进制帧，绕过文本/十六进制转换
  /// TCP 模式下自动进入串行写队列，天然防并发 flush 竞态
  /// ============================================================
  Future<bool> rawSend(Uint8List data) async {
    if (_status != ConnectionStatus.connected) {
      debugPrint('[$runtimeType] 未连接，无法发送原始数据');
      return false;
    }
    if (useTcp) {
      return _enqueueTcpWrite(data);
    }
    try {
      if (_udpSocket == null) return false;
      _udpSocket!.send(data, InternetAddress(deviceIp), devicePort);
      return true;
    } catch (e) {
      debugPrint('[$runtimeType] 原始数据发送失败: $e');
      _handleDisconnection();
      return false;
    }
  }

  /// ============================================================
  /// TCP 串行写入（内部统一入口）
  /// 所有 TCP 写操作（sendCommand / rawSend / 心跳）都经过此队列，
  /// 确保任何时刻只有一个 add+flush 在进行，彻底避免
  /// "Bad state: StreamSink is bound to a stream" 竞态
  /// ============================================================
  Future<bool> _enqueueTcpWrite(Uint8List data) {
    final Completer<bool> completer = Completer<bool>();
    final int generation = _connGeneration;
    _txQueue = _txQueue.then((_) async {
      // 出队真正执行时再次检查连接（排队期间可能已断开）
      // 且代数必须一致（期间未发生断线重连），防止旧帧串到新连接
      if (generation != _connGeneration ||
          _status != ConnectionStatus.connected ||
          _tcpSocket == null) {
        completer.complete(false);
        return;
      }
      try {
        _tcpSocket!.add(data);
        await _tcpSocket!.flush();
        completer.complete(true);
      } catch (e) {
        debugPrint('[$runtimeType] TCP写入失败: $e');
        _handleDisconnection();
        completer.complete(false);
      }
    });
    return completer.future;
  }

  /// ============================================================
  /// 协议层异常通知（子类可调用）
  /// CIP 等子类在检测到注册失败、控制系统中断等异常时调用，触发重连
  /// ============================================================
  void notifyConnectionError() {
    _handleDisconnection();
  }

  /// ============================================================
  /// 创建 TCP Socket（子类可重写以支持 TLS 等安全连接）
  /// CIP 安全模式（SCIP，4系列）通过重写此方法返回 SecureSocket
  /// ============================================================
  Future<Socket> createTcpSocket() async {
    return await Socket.connect(
      deviceIp,
      devicePort,
      timeout: Duration(seconds: _config.connectionTimeoutSeconds),
    );
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
    // 捕获本次建连世代；若在 awaitsocket 期间发生 disconnect/新 connect/重连，
    // _connGeneration 会变化，本次建连应作废（销毁新 socket，不提交），
    // 否则会出现「两个 socket 同时完成握手、向对端重复注册同一会话」的错乱。
    final int myGen = _connGeneration;

    try {
      if (useTcp) {
        // TCP模式：创建TCP连接（CIP安全模式会重写 createTcpSocket 返回 SecureSocket）
        final Socket socket = await createTcpSocket();
        // 期间若发生 disconnect / 新 connect / 重连，放弃本次建连
        if (myGen != _connGeneration) {
          try {
            socket.destroy();
          } catch (_) {}
          return;
        }
        // 防御性：销毁可能残留的旧 socket，避免泄漏（旧实现直接覆盖 _tcpSocket 会丢引用）
        if (_tcpSocket != null && _tcpSocket != socket) {
          try {
            _tcpSocket!.destroy();
          } catch (_) {}
        }
        _tcpSocket = socket;
        _tcpSocket!.setOption(SocketOption.tcpNoDelay, true);
        _tcpSocket!.listen(
          _onDataReceived,
          onError: _onSocketError,
          onDone: _onSocketDone,
          cancelOnError: false,
        );
        debugPrint('[$runtimeType] TCP连接成功 -> $deviceIp:$devicePort');
      } else {
        // UDP模式：创建UDP套接字并绑定到本地端口
        _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        if (myGen != _connGeneration) {
          try {
            _udpSocket?.close();
          } catch (_) {}
          _udpSocket = null;
          return;
        }
        _udpSocket!.listen(_onUdpDataReceived);
        debugPrint('[$runtimeType] UDP连接成功 -> $deviceIp:$devicePort');
      }

      _updateStatus(ConnectionStatus.connected);
      _lastHeartbeatResponse = DateTime.now();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      // 子类钩子：复位协议状态机（如 CIP 的握手状态与接收缓冲）
      onTransportConnected();
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
    // 子类钩子：用于处理自定义二进制协议（如 CIP）的接收数据
    processReceivedData(data);
  }

  /// ============================================================
  /// 接收数据处理钩子（子类可重写）
  /// 默认空实现；CIP 等自定义协议在此解析私有帧格式
  /// ============================================================
  void processReceivedData(Uint8List data) {}

  /// ============================================================
  /// 传输层连接建立钩子（子类可重写）
  /// 每次 TCP/UDP 连接成功后调用，用于复位协议状态机、清空接收缓冲
  /// ============================================================
  void onTransportConnected() {}

  /// ============================================================
  /// 传输层断开钩子（子类可重写）
  /// 连接断开（无论手动或异常）时调用，用于复位协议层状态
  /// ============================================================
  void onTransportDisconnected() {}

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
    // 新生代：使在途建连与待发写失效，避免断连后残留帧串到新连接
    _connGeneration++;
    // 异常断线时同样取消心跳/看门狗定时器，避免重连等待期空转调度
    _heartbeatTimer?.cancel();
    _watchdogTimer?.cancel();
    _tcpSocket?.destroy();
    _tcpSocket = null;
    _udpSocket?.close();
    _udpSocket = null;

    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }
    // 子类钩子：复位协议层状态（如 CIP 握手标志）
    onTransportDisconnected();
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  /// ============================================================
  /// 启动心跳检测机制
  /// ============================================================
  /// 启动连接保活：心跳 ping 是否发送由 [autoStartHeartbeatPings] 决定；
  /// 存活看门狗是否启用由 [enableLivenessWatchdog] 决定。
  /// CIP 等事件驱动协议应禁用看门狗（空闲无数据是正常行为，TCP 层断连已能感知），
  /// 否则会被「无数据超时」误杀，造成「连上→空闲→断连→重连」循环。
  void _startKeepalive() {
    if (enableLivenessWatchdog) _startWatchdog();
    if (autoStartHeartbeatPings) startHeartbeatPings();
  }

  /// 是否启用存活看门狗（无数据超时判定离线）。默认 true；
  /// CIP 等事件驱动协议重写为 false——这类协议空闲时对端本就不主动发数据，
  /// 用「无数据超时」会误杀正常空闲连接，应仅依赖 TCP 层断连(onDone/onError)感知。
  bool get enableLivenessWatchdog => true;

  /// 是否在建连后立即发送心跳 ping。默认 true（大多数设备握手简单，连上即可保活）；
  /// CIP 重写为 false（CP4 不兼容 0x0D 心跳 ping，收到即断开，故 CIP 不发心跳）。
  bool get autoStartHeartbeatPings => true;

  /// 启动心跳 ping 定时器（含立即探活一次）。看门狗需由调用方先启动。
  void startHeartbeatPings() {
    if (heartbeatCommand.isEmpty) {
      debugPrint('[$runtimeType] 心跳命令为空，跳过心跳检测');
      return;
    }
    if (_heartbeatTimer != null) return; // 防重复启动
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: heartbeatInterval),
      (_) => _sendHeartbeat(),
    );
    // 连接建立后立即探活一次，缩短首次离线检测的等待窗口
    _sendHeartbeat();
    debugPrint('[$runtimeType] 心跳检测已启动');
  }

  /// 启动轻量级存活看门狗：周期性检查"距上次收到数据是否超过阈值"，
  /// 与心跳发送解耦，使离线判定可在两次心跳之间及时触发，且不增加网络流量
  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(
      Duration(seconds: livenessCheckIntervalSeconds),
      (_) => _checkLiveness(),
    );
  }

  /// 存活检查：若已连接但超过 (heartbeatInterval × 超时倍数) 未收到任何数据，
  /// 立即判定离线并触发重连
  void _checkLiveness() {
    if (_status != ConnectionStatus.connected) return;
    if (_lastHeartbeatResponse == null) return;
    final elapsed = DateTime.now()
        .difference(_lastHeartbeatResponse!)
        .inSeconds;
    if (elapsed > heartbeatInterval * heartbeatTimeoutMultiplier) {
      debugPrint('[$runtimeType] 看门狗判定心跳超时($elapsed s)，断开连接');
      _handleDisconnection();
    }
  }

  /// 将单个字节值格式化为 2 位大写十六进制字符串（如 255 -> "FF"）
  /// 供各子类（CIP / 摄像头等）统一复用，避免重复实现
  static String hexByte(int b) =>
      b.toRadixString(16).padLeft(2, '0').toUpperCase();

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
        // TCP模式发送心跳：与其它写操作共用串行队列，避免并发 flush 竞态
        final bool ok = await _enqueueTcpWrite(data);
        if (!ok) return; // 失败时队列内部已触发断线处理
      } else {
        // UDP模式发送心跳
        if (_udpSocket == null) return;
        _udpSocket!.send(data, InternetAddress(deviceIp), devicePort);
      }

      _heartbeatCount++;
      debugPrint('[$runtimeType] 心跳包已发送 (#$_heartbeatCount)');
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
        // 新生代：使本次重连之前的在途建连失效
        _connGeneration++;
        await _establishConnection();
        if (_status == ConnectionStatus.connected) {
          _startKeepalive();
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
