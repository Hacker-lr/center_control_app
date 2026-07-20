import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'device_config.dart';

/// 连接状态枚举，定义了设备连接的四种状态
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

/// 设备连接抽象基类，提供TCP连接管理、心跳检测和自动重连功能
/// 继承自ChangeNotifier，用于通知连接状态变化
abstract class BaseConnection extends ChangeNotifier {
  /// TCP套接字实例，用于与设备进行网络通信，初始值为null表示未连接
  Socket? _socket;
  
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
  
  /// 是否以十六进制格式发送数据，子类必须实现此抽象属性
  bool get sendAsHex;
  
  /// 心跳检测命令，子类必须实现此抽象属性
  String get heartbeatCommand;

  /// 建立与设备的TCP连接
/// 如果当前已连接或正在连接，则直接返回
/// 连接成功后会自动启动心跳检测
Future<void> connect() async {
    // 避免重复连接，如果已连接或正在连接则直接返回
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      return;
    }
    // 设置为非手动断开状态，允许自动重连
    _isManualDisconnect = false;
    // 执行实际的TCP连接建立操作
    await _establishConnection();
    // 连接成功后启动心跳检测机制
    _startHeartbeat();
  }

  /// 断开与设备的TCP连接
/// [manual] 参数表示是否为手动断开，默认值为true
/// 手动断开时不会触发自动重连，自动断开（如网络异常）时会触发重连
void disconnect({bool manual = true}) {
    // 记录断开方式，用于决定是否触发自动重连
    _isManualDisconnect = manual;
    // 取消并清空心跳定时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    // 取消并清空重连定时器
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // 销毁套接字并清空引用
    _socket?.destroy();
    _socket = null;
    // 更新连接状态为未连接
    _updateStatus(ConnectionStatus.disconnected);
    debugPrint('[$runtimeType] 已断开连接');
  }

  /// 释放资源，清理连接相关的所有定时器和套接字
  /// 继承自ChangeNotifier，在对象被销毁时调用
  @override
  void dispose() {
    // 以手动方式断开连接，避免触发自动重连
    disconnect(manual: true);
    // 调用父类的dispose方法，清理ChangeNotifier资源
    super.dispose();
  }

  /// 向设备发送指令
/// [command] 参数为要发送的指令字符串，可以是普通文本或十六进制格式
/// 返回值为bool类型，true表示发送成功，false表示发送失败或未连接
Future<bool> sendCommand(String command) async {
    // 检查套接字是否存在以及连接状态是否为已连接
    if (_socket == null || _status != ConnectionStatus.connected) {
      debugPrint('[$runtimeType] 未连接，无法发送指令: $command');
      return false;
    }

    try {
      // 根据sendAsHex配置决定数据转换方式
      // 如果sendAsHex为true，将十六进制字符串转换为字节
      // 否则将普通字符串转换为UTF-8字节
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(command)
          : Uint8List.fromList(command.codeUnits);

      // 将数据写入套接字缓冲区
      _socket!.add(data);
      // 刷新缓冲区，确保数据立即发送
      await _socket!.flush();

      // 根据发送格式打印调试日志
      if (sendAsHex) {
        final hexStr =
            data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        debugPrint('[$runtimeType] 指令发送成功(HEX): $command → [$hexStr]');
      } else {
        debugPrint('[$runtimeType] 指令发送成功: $command');
      }
      // 返回发送成功
      return true;
    } catch (e) {
      // 捕获发送过程中的异常
      debugPrint('[$runtimeType] 指令发送失败: $e');
      // 处理连接断开
      _handleDisconnection();
      return false;
    }
  }

  /// 将十六进制字符串转换为字节列表
/// [hexStr] 参数为十六进制格式的字符串，支持多种格式如"0x1A 0x2B"、"1A,2B"、"1A 2B"等
/// 返回值为转换后的Uint8List字节数组
Uint8List _hexStringToBytes(String hexStr) {
    // 清理输入字符串，移除各种格式标记和分隔符
    // 移除0x前缀、逗号、分号，将多个空白字符替换为单个空格，然后去除首尾空格
    final String cleaned = hexStr
        .replaceAll('0x', '')
        .replaceAll('0X', '')
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 将清理后的字符串按空格分割成单个十六进制数值字符串
    final List<String> parts = cleaned.split(' ');
    // 创建用于存储转换结果的字节列表
    final List<int> bytes = [];

    // 遍历每个十六进制数值字符串
    for (final part in parts) {
      // 跳过空字符串
      if (part.isEmpty) continue;
      try {
        // 将十六进制字符串解析为整数，并限制在0-255范围内
        bytes.add(int.parse(part, radix: 16).clamp(0, 255));
      } catch (e) {
        // 解析失败时记录错误日志，并用0填充
        debugPrint('[$runtimeType] 16进制解析错误: "$part"');
        bytes.add(0);
      }
    }
    // 将整数列表转换为Uint8List并返回
    return Uint8List.fromList(bytes);
  }

  /// 建立TCP连接的内部方法
/// 负责创建Socket连接、设置监听回调、处理连接成功和失败的情况
Future<void> _establishConnection() async {
    // 更新状态为连接中
    _updateStatus(ConnectionStatus.connecting);

    try {
      // 创建TCP连接，连接指定的设备IP和端口，设置超时时间
      _socket = await Socket.connect(
        deviceIp,
        devicePort,
        timeout: Duration(seconds: DeviceConfig.connectionTimeoutSeconds),
      );
      // 禁用Nagle算法，确保数据立即发送
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      // 设置Socket数据监听回调
      // onDataReceived: 收到数据时的处理方法
      // onError: 发生错误时的处理方法
      // onDone: 连接关闭时的处理方法
      // cancelOnError: 设置为false，即使发生错误也保持监听
      _socket!.listen(
        _onDataReceived,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );
      debugPrint('[$runtimeType] TCP连接成功 -> $deviceIp:$devicePort');

      // 连接成功，更新状态为已连接
      _updateStatus(ConnectionStatus.connected);
      // 记录当前时间作为最后一次心跳响应时间
      _lastHeartbeatResponse = DateTime.now();
      // 取消重连定时器，因为连接已成功建立
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } catch (e) {
      // 连接失败，记录错误日志
      debugPrint('[$runtimeType] 连接失败: $e');
      // 更新状态为错误
      _updateStatus(ConnectionStatus.error);
      // 启动自动重连机制
      _startReconnect();
    }
  }

  /// Socket数据接收回调方法
/// 当收到设备发送的数据时被调用
/// [data] 参数为接收到的原始字节数据
void _onDataReceived(Uint8List data) {
    // 更新最后一次心跳响应时间为当前时间
    // 这表明设备仍然在线，连接正常
    _lastHeartbeatResponse = DateTime.now();
    debugPrint('[$runtimeType] 收到数据: ${String.fromCharCodes(data)}');
  }

  /// Socket错误回调方法
  /// 当Socket发生错误时被调用
  /// [error] 参数为错误信息
  void _onSocketError(dynamic error) {
    debugPrint('[$runtimeType] Socket错误: $error');
    // 处理连接断开逻辑
    _handleDisconnection();
  }

  /// Socket关闭回调方法
  /// 当Socket连接被关闭时被调用
  void _onSocketDone() {
    debugPrint('[$runtimeType] Socket已关闭');
    // 处理连接断开逻辑
    _handleDisconnection();
  }

  /// 处理连接断开的内部方法
/// 负责清理Socket资源、更新状态，并根据断开方式决定是否启动自动重连
void _handleDisconnection() {
    // 销毁Socket并清空引用
    _socket?.destroy();
    _socket = null;
    // 如果当前状态不是未连接，则更新为未连接状态
    if (_status != ConnectionStatus.disconnected) {
      _updateStatus(ConnectionStatus.disconnected);
    }
    // 如果不是手动断开连接，则启动自动重连
    if (!_isManualDisconnect) {
      _startReconnect();
    }
  }

  /// 启动心跳检测机制
/// 创建周期性定时器，定期发送心跳包检测设备连接状态
void _startHeartbeat() {
    // 如果已有心跳定时器，先取消它以避免重复
    _heartbeatTimer?.cancel();
    // 如果心跳命令为空，不启动心跳检测
    if (heartbeatCommand.isEmpty) {
      debugPrint('[$runtimeType] 心跳命令为空，跳过心跳检测');
      return;
    }
    // 创建周期性定时器，按照配置的心跳间隔发送心跳包
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.heartbeatIntervalSeconds),
      (_) => _sendHeartbeat(),
    );
    debugPrint('[$runtimeType] 心跳检测已启动');
  }

  /// 发送心跳包的内部方法
/// 负责发送心跳命令并检查心跳响应是否超时
Future<void> _sendHeartbeat() async {
    // 检查套接字是否存在以及连接状态是否为已连接
    if (_socket == null || _status != ConnectionStatus.connected) return;

    try {
      // 根据sendAsHex配置转换心跳命令为字节数据
      final Uint8List data = sendAsHex
          ? _hexStringToBytes(heartbeatCommand)
          : Uint8List.fromList(heartbeatCommand.codeUnits);
      // 将心跳数据写入套接字并刷新
      _socket!.add(data);
      await _socket!.flush();

      // 心跳计数器加1
      _heartbeatCount++;
      debugPrint('[$runtimeType] 心跳包已发送 (#$_heartbeatCount)');

      // 检查心跳响应是否超时
      if (_lastHeartbeatResponse != null) {
        // 计算距上次心跳响应的时间间隔（秒）
        final elapsed = DateTime.now().difference(_lastHeartbeatResponse!).inSeconds;
        // 如果超过超时阈值（心跳间隔 * 超时倍数），判定为心跳超时
        if (elapsed > DeviceConfig.heartbeatIntervalSeconds * DeviceConfig.heartbeatTimeoutMultiplier) {
          debugPrint('[$runtimeType] 心跳超时');
          // 处理连接断开，触发自动重连
          _handleDisconnection();
        }
      }
    } catch (e) {
      // 捕获发送异常
      debugPrint('[$runtimeType] 心跳异常: $e');
      // 处理连接断开
      _handleDisconnection();
    }
  }

  /// 启动自动重连机制
/// 创建周期性定时器，定期尝试重新建立连接
void _startReconnect() {
    // 如果重连定时器已存在且正在运行，直接返回
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    // 如果是手动断开连接，不启动自动重连
    if (_isManualDisconnect) return;

    debugPrint('[$runtimeType] 自动重连已启动');
    // 创建周期性定时器，按照配置的重连间隔尝试重连
    _reconnectTimer = Timer.periodic(
      Duration(seconds: DeviceConfig.reconnectIntervalSeconds),
      (_) async {
        // 检查是否已手动断开连接，如果是则取消重连定时器
        if (_isManualDisconnect) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }
        // 如果已经成功连接，取消重连定时器
        if (_status == ConnectionStatus.connected) {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          return;
        }
        // 尝试建立连接
        await _establishConnection();
        // 如果连接成功，启动心跳检测并取消重连定时器
        if (_status == ConnectionStatus.connected) {
          _startHeartbeat();
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
        }
      },
    );
  }

  /// 更新连接状态的内部方法
/// 当状态发生变化时通知所有监听器
/// [newStatus] 参数为新的连接状态
void _updateStatus(ConnectionStatus newStatus) {
    // 只有当状态发生变化时才进行更新
    if (_status != newStatus) {
      // 更新内部状态
      _status = newStatus;
      // 通知所有监听器状态已变化
      notifyListeners();
      debugPrint('[$runtimeType] 状态变更: $newStatus');
    }
  }
}