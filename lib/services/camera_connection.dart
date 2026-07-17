import 'package:flutter/foundation.dart';
import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 单个摄像头设备连接（非单例，每个摄像头独立实例）
/// 实现 Sony VISCA over IP 协议，继承 BaseConnection 基类
/// 每次发送VISCA指令前需清空缓冲区，停止指令后需再次清空
/// IP包头格式：01 00 00 [长度] 00 00 00 01
/// 清空包头格式：02 00 00 01 00 00 00 00 01
/// ============================================================
class CameraConnection extends BaseConnection {
  final String _ip;
  final int _port;
  final int _viscaAddr; // VISCA摄像机地址(1-7)

  CameraConnection({
    required String ip,
    required int port,
    required int viscaAddr,
  })  : _ip = ip,
        _port = port,
        _viscaAddr = viscaAddr;

  @override
  String get deviceIp => _ip;

  @override
  int get devicePort => _port;

  @override
  bool get sendAsHex => DeviceConfig.cameraSendAsHex;

  /// VISCA协议不需要常规心跳，摄像头通过指令响应维持连接
  @override
  String get heartbeatCommand => '';

  /// 获取VISCA地址字节（0x80 + 摄像机地址）
  int get _addr => 0x80 + _viscaAddr;

  /// 清空指令缓冲区（VISCA over IP专用9字节清空包头）
  /// 每次发送VISCA指令前调用，确保指令不被缓冲区中的旧指令干扰
  Future<bool> clearBuffer() async {
    return sendCommand('02 00 00 01 00 00 00 00 01');
  }

  /// 发送VISCA指令（自动添加IP包头，发送前自动清空缓冲区）
  /// viscaPayload: 空格分隔的16进制字符串，如 "81 01 06 01 0F 0F 01 01 FF"
  Future<bool> sendViscaCommand(String viscaPayload) async {
    if (!sendAsHex) {
      debugPrint('[CameraConnection] 错误：VISCA协议必须使用16进制模式');
      return false;
    }
    // 先清空缓冲区，确保指令立即执行
    await clearBuffer();
    await Future.delayed(const Duration(milliseconds: 20));
    // 解析VISCA负载获取长度
    final parts = viscaPayload.split(' ').where((s) => s.isNotEmpty).toList();
    final int length = parts.length;
    // 构建完整报文：IP包头(8字节) + VISCA负载
    final header = '01 00 00 ${length.toRadixString(16).padLeft(2, '0')} 00 00 00 01';
    final fullHex = '$header $viscaPayload';
    return sendCommand(fullHex);
  }

  /// 发送VISCA指令（带前后清空缓冲区，用于停止指令）
  Future<bool> _sendViscaWithPostClear(String viscaPayload) async {
    if (!sendAsHex) return false;
    await clearBuffer();
    await Future.delayed(const Duration(milliseconds: 20));
    final parts = viscaPayload.split(' ').where((s) => s.isNotEmpty).toList();
    final int length = parts.length;
    final header = '01 00 00 ${length.toRadixString(16).padLeft(2, '0')} 00 00 00 01';
    final fullHex = '$header $viscaPayload';
    final result = await sendCommand(fullHex);
    await Future.delayed(const Duration(milliseconds: 20));
    await clearBuffer();
    return result;
  }

  // ==================== 云台控制 ====================

  /// 云台方向移动
  /// panSpeed/tiltSpeed: 云台移动速度
  /// panDir: 01=左, 02=右, 03=停止
  /// tiltDir: 01=上, 02=下, 03=停止
  Future<bool> panTiltMove(int panSpeed, int tiltSpeed, int panDir, int tiltDir) async {
    final cmd = '${_hex(_addr)} 01 06 01 ${_hex(panSpeed)} ${_hex(tiltSpeed)} ${_hex(panDir)} ${_hex(tiltDir)} FF';
    return sendViscaCommand(cmd);
  }

  /// 云台停止（释放方向键时调用，前后各清空一次缓冲区）
  Future<bool> panTiltStop() async {
    return _sendViscaWithPostClear('${_hex(_addr)} 01 06 01 18 18 03 03 FF');
  }

  // ==================== 变焦控制 ====================

  /// 变焦放大（Tele Standard）
  Future<bool> zoomTele() async {
    return sendViscaCommand('${_hex(_addr)} 01 04 07 23 FF');
  }

  /// 变焦缩小（Wide Standard）
  Future<bool> zoomWide() async {
    return sendViscaCommand('${_hex(_addr)} 01 04 07 33 FF');
  }

  /// 变焦停止（释放变焦键时调用，前后各清空一次缓冲区）
  Future<bool> zoomStop() async {
    return _sendViscaWithPostClear('${_hex(_addr)} 01 04 07 00 FF');
  }

  // ==================== 预置位 ====================

  /// 预置位保存
  /// presetNum: 预置位编号(1-based)，协议内部转为0-based
  Future<bool> presetSave(int presetNum) async {
    final cmd = '${_hex(_addr)} 01 04 3F 01 ${_hex(presetNum - 1)} FF';
    await clearBuffer();
    final result = await sendViscaCommand(cmd);
    await Future.delayed(const Duration(milliseconds: 20));
    await clearBuffer();
    return result;
  }

  /// 预置位调用
  /// presetNum: 预置位编号(1-based)，协议内部转为0-based
  Future<bool> presetRecall(int presetNum) async {
    final cmd = '${_hex(_addr)} 01 04 3F 02 ${_hex(presetNum - 1)} FF';
    await clearBuffer();
    final result = await sendViscaCommand(cmd);
    await Future.delayed(const Duration(milliseconds: 20));
    await clearBuffer();
    return result;
  }

  /// 将整数转为2位16进制字符串（大写）
  String _hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// ============================================================
/// 摄像头连接管理器（单例模式）
/// 管理所有摄像头连接实例，实现互斥连接：
/// 选中某个摄像头时，仅连接该摄像头对应的设备，其余断开
/// ============================================================
class CameraConnectionManager extends ChangeNotifier {
  static final CameraConnectionManager _instance = CameraConnectionManager._internal();
  factory CameraConnectionManager() => _instance;
  CameraConnectionManager._internal() {
    // 根据配置初始化所有摄像头连接实例
    for (int i = 0; i < DeviceConfig.cameraDevices.length; i++) {
      final dev = DeviceConfig.cameraDevices[i];
      _connections.add(CameraConnection(
        ip: dev['ip'] as String,
        port: dev['port'] as int,
        viscaAddr: dev['viscaAddr'] as int,
      ));
    }
  }

  /// 所有摄像头连接实例（索引0对应摄像头1）
  final List<CameraConnection> _connections = [];

  /// 当前选中的摄像头索引（0-based），-1表示未选中
  int _activeIndex = -1;

  /// 获取当前活跃的摄像头连接，未选中时返回null
  CameraConnection? get activeConnection =>
      (_activeIndex >= 0 && _activeIndex < _connections.length)
          ? _connections[_activeIndex]
          : null;

  /// 当前选中的摄像头编号（1-based），0表示未选中
  int get activeCameraNumber => _activeIndex + 1;

  /// 获取当前连接状态（基于活跃摄像头）
  ConnectionStatus get status =>
      activeConnection?.status ?? ConnectionStatus.disconnected;

  /// 摄像头总数
  int get cameraCount => _connections.length;

  /// 获取指定索引的连接实例
  CameraConnection getConnection(int index) => _connections[index];

  /// 连接指定摄像头（互斥：断开其他，仅连接选中的）
  /// cameraNumber: 摄像头编号（1-based）
  void connectCamera(int cameraNumber) {
    final int index = cameraNumber - 1;
    if (index < 0 || index >= _connections.length) return;
    if (_activeIndex == index && _connections[index].isConnected) return;

    // 断开之前的连接
    _disconnectAll();

    // 连接新选中的摄像头
    _activeIndex = index;
    _connections[index].connect();

    // 监听该连接的状态变化，转发通知
    _connections[index].addListener(_onConnectionChanged);
    notifyListeners();
  }

  /// 断开所有连接（离开摄像头页面时调用）
  void disconnectAll() {
    _disconnectAll();
    _activeIndex = -1;
    notifyListeners();
  }

  /// 内部断开所有连接，移除监听并取消所有重连定时器
  /// 对所有连接都调用 disconnect()，确保那些处于 error 状态
  /// 但重连 timer 仍在运行的连接也被彻底清理
  void _disconnectAll() {
    for (final conn in _connections) {
      conn.removeListener(_onConnectionChanged);
      conn.disconnect(); // 无条件断开：取消心跳、取消重连、销毁 socket
    }
  }

  /// 连接状态变化回调，转发通知到UI
  void _onConnectionChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _disconnectAll();
    for (final conn in _connections) {
      conn.dispose();
    }
    super.dispose();
  }
}
