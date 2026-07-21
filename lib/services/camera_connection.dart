import 'package:flutter/foundation.dart';
import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 单个摄像头设备连接类（非单例，每个摄像头对应独立实例）
/// 
/// 实现 Sony VISCA over IP 协议的摄像头控制，继承自 BaseConnection 基类
/// 
/// VISCA over IP 协议说明：
/// - 每次发送VISCA指令前需清空缓冲区，停止指令后需再次清空
/// - IP包头格式：01 00 00 [长度] 00 00 00 01（8字节）
///   - 01：版本号
///   - 00 00：保留字段
///   - [长度]：后续VISCA负载的字节数（1字节，16进制）
///   - 00 00 00：保留字段
///   - 01：序列号（固定为1）
/// - 清空包头格式：02 00 00 01 00 00 00 00 01（9字节）
///   - 02：清空命令标识
///   - 其余字段含义与IP包头类似
/// 
/// VISCA指令格式：[地址] [类别] [指令] [参数...] [FF]
/// - 地址：0x80 + 摄像机地址(1-7)，如摄像机地址1则为0x81
/// - 类别：01表示摄像机控制指令
/// - FF：指令结束符
/// ============================================================
class CameraConnection extends BaseConnection {
  /// 摄像头设备的IP地址
  final String _ip;

  /// 摄像头设备的端口号（VISCA over IP通常使用52381）
  final int _port;

  /// VISCA摄像机地址（范围1-7，对应协议中的设备选择）
  /// 同一网络中多个摄像头可通过此地址区分
  final int _viscaAddr;

  /// 创建摄像头连接实例
  /// 
  /// 参数：
  /// - ip: 摄像头的IP地址
  /// - port: 摄像头的端口号
  /// - viscaAddr: VISCA摄像机地址（1-7）
  CameraConnection({
    required this._ip,
    required this._port,
    required this._viscaAddr,
  });

  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  /// 获取设备IP地址（实现基类抽象属性）
  @override
  String get deviceIp => _ip;

  /// 获取设备端口号（实现基类抽象属性）
  @override
  int get devicePort => _port;

  /// 获取协议类型（实现基类抽象属性）
  /// VISCA协议默认使用TCP
  @override
  bool get useTcp => true;

  /// 获取数据发送模式（实现基类抽象属性）
  /// VISCA协议必须使用16进制模式发送
  @override
  bool get sendAsHex => _config.cameraSendAsHex;

  /// 获取心跳指令（实现基类抽象属性）
  /// 
  /// VISCA协议不需要常规心跳包，摄像头通过指令响应维持连接状态
  /// 返回空字符串表示不发送心跳包
  @override
  String get heartbeatCommand => '';

  /// 计算VISCA地址字节
  /// 
  /// VISCA协议中，地址字节为 0x80 + 摄像机地址
  /// 例如：摄像机地址为1时，地址字节为0x81
  int get _addr => 0x80 + _viscaAddr;

  /// 清空指令缓冲区（VISCA over IP专用）
  /// 
  /// 发送VISCA指令前必须调用此方法，确保缓冲区中的旧指令不会干扰新指令
  /// 使用VISCA over IP的专用清空命令，格式为9字节的清空包头
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> clearBuffer() async {
    // 发送清空命令：02 00 00 01 00 00 00 00 01
    // 02标识清空操作，00 00 01表示长度为1字节，后续为清空参数
    return sendCommand('02 00 00 01 00 00 00 00 01');
  }

  /// 发送VISCA指令（自动处理IP包头和缓冲区清空）
  /// 
  /// 参数：
  /// - viscaPayload: 空格分隔的16进制字符串，如 "81 01 06 01 0F 0F 01 01 FF"
  ///   需包含完整的VISCA指令（地址 + 类别 + 指令 + 参数 + FF结束符）
  /// 
  /// 返回值：发送成功返回true，失败返回false
  /// 
  /// 执行流程：
  /// 1. 检查是否为16进制模式，非16进制模式直接返回失败
  /// 2. 清空缓冲区，确保指令立即执行
  /// 3. 等待20ms，确保清空操作完成
  /// 4. 解析VISCA负载长度，构建IP包头
  /// 5. 拼接IP包头和VISCA负载，发送完整报文
  Future<bool> sendViscaCommand(String viscaPayload) async {
    // 检查发送模式：VISCA协议必须使用16进制模式
    if (!sendAsHex) {
      debugPrint('[CameraConnection] 错误：VISCA协议必须使用16进制模式');
      return false;
    }

    // 发送指令前先清空缓冲区，确保新指令不受旧指令干扰
    await clearBuffer();

    // 等待20ms，给设备足够时间处理清空操作
    await Future.delayed(const Duration(milliseconds: 20));

    // 解析VISCA负载：按空格分割，过滤空字符串
    final parts = viscaPayload.split(' ').where((s) => s.isNotEmpty).toList();

    // 获取负载长度（字节数）
    final int length = parts.length;

    // 构建IP包头：01 00 00 [长度] 00 00 00 01
    // 将长度转为2位16进制字符串，不足补0
    final header = '01 00 00 ${length.toRadixString(16).padLeft(2, '0')} 00 00 00 01';

    // 拼接完整报文：IP包头 + VISCA负载
    final fullHex = '$header $viscaPayload';

    // 发送完整报文
    return sendCommand(fullHex);
  }

  /// 发送VISCA指令（带前后清空缓冲区）
  /// 
  /// 适用于停止类指令，需要在发送前和发送后都清空缓冲区
  /// 确保设备完全停止当前动作，不会残留指令
  /// 
  /// 参数：
  /// - viscaPayload: 空格分隔的16进制字符串
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> _sendViscaWithPostClear(String viscaPayload) async {
    // 检查发送模式
    if (!sendAsHex) return false;

    // 发送前清空缓冲区
    await clearBuffer();

    // 等待清空完成
    await Future.delayed(const Duration(milliseconds: 20));

    // 解析负载并构建完整报文（与sendViscaCommand相同）
    final parts = viscaPayload.split(' ').where((s) => s.isNotEmpty).toList();
    final int length = parts.length;
    final header = '01 00 00 ${length.toRadixString(16).padLeft(2, '0')} 00 00 00 01';
    final fullHex = '$header $viscaPayload';

    // 发送指令
    final result = await sendCommand(fullHex);

    // 等待指令执行完成
    await Future.delayed(const Duration(milliseconds: 20));

    // 发送后再次清空缓冲区（关键：确保设备完全停止）
    await clearBuffer();

    return result;
  }

  // ==================== 云台控制 ====================

  /// 云台方向移动控制
  /// 
  /// VISCA协议格式：[地址] 01 06 01 [panSpeed] [tiltSpeed] [panDir] [tiltDir] FF
  /// - 01：摄像机控制类别
  /// - 06：云台控制指令
  /// - 01：连续移动子指令
  /// - panSpeed: 水平移动速度（01-18，0x18为最快）
  /// - tiltSpeed: 垂直移动速度（01-18，0x18为最快）
  /// - panDir: 水平方向（01=左, 02=右, 03=停止）
  /// - tiltDir: 垂直方向（01=上, 02=下, 03=停止）
  /// 
  /// 参数：
  /// - panSpeed: 水平移动速度（1-24）
  /// - tiltSpeed: 垂直移动速度（1-24）
  /// - panDir: 水平方向（01=左, 02=右, 03=停止）
  /// - tiltDir: 垂直方向（01=上, 02=下, 03=停止）
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> panTiltMove(int panSpeed, int tiltSpeed, int panDir, int tiltDir) async {
    // 构建VISCA指令：地址 + 类别 + 指令 + 速度 + 方向 + 结束符
    final cmd = '${_hex(_addr)} 01 06 01 ${_hex(panSpeed)} ${_hex(tiltSpeed)} ${_hex(panDir)} ${_hex(tiltDir)} FF';

    // 发送指令（自动处理缓冲区清空）
    return sendViscaCommand(cmd);
  }

  /// 云台停止移动
  /// 
  /// 释放方向键时调用此方法，使用带前后清空的发送方式
  /// 确保云台完全停止，不会因缓冲区残留指令继续移动
  /// 
  /// VISCA指令：[地址] 01 06 01 18 18 03 03 FF
  /// - 18 18：默认速度
  /// - 03 03：水平和垂直方向都停止
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> panTiltStop() async {
    return _sendViscaWithPostClear('${_hex(_addr)} 01 06 01 18 18 03 03 FF');
  }

  // ==================== 变焦控制 ====================

  /// 变焦放大（标准速度）
  /// 
  /// VISCA协议格式：[地址] 01 04 07 23 FF
  /// - 01：摄像机控制类别
  /// - 04：镜头控制指令
  /// - 07：变焦控制子指令
  /// - 23：Tele Standard（标准速度放大）
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> zoomTele() async {
    return sendViscaCommand('${_hex(_addr)} 01 04 07 23 FF');
  }

  /// 变焦缩小（标准速度）
  /// 
  /// VISCA协议格式：[地址] 01 04 07 33 FF
  /// - 01：摄像机控制类别
  /// - 04：镜头控制指令
  /// - 07：变焦控制子指令
  /// - 33：Wide Standard（标准速度缩小）
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> zoomWide() async {
    return sendViscaCommand('${_hex(_addr)} 01 04 07 33 FF');
  }

  /// 变焦停止
  /// 
  /// 释放变焦键时调用此方法，使用带前后清空的发送方式
  /// 确保变焦完全停止，不会因缓冲区残留指令继续变焦
  /// 
  /// VISCA指令：[地址] 01 04 07 00 FF
  /// - 00：停止变焦
  /// 
  /// 返回值：发送成功返回true，失败返回false
  Future<bool> zoomStop() async {
    return _sendViscaWithPostClear('${_hex(_addr)} 01 04 07 00 FF');
  }

  // ==================== 预置位 ====================

  /// 保存预置位
  /// 
  /// 将当前摄像头的位置（云台位置+变焦）保存到指定预置位
  /// 
  /// VISCA协议格式：[地址] 01 04 3F 01 [presetNum] FF
  /// - 01：摄像机控制类别
  /// - 04：镜头控制指令
  /// - 3F：预置位控制指令
  /// - 01：保存子指令
  /// - presetNum：预置位编号（0-based，0-15）
  /// 
  /// 参数：
  /// - presetNum: 预置位编号（1-based，1-16），内部转换为0-based
  /// 
  /// 返回值：保存成功返回true，失败返回false
  Future<bool> presetSave(int presetNum) async {
    // 构建保存预置位指令，预置位编号减1转为0-based
    final cmd = '${_hex(_addr)} 01 04 3F 01 ${_hex(presetNum - 1)} FF';

    // 预置位操作需要额外的缓冲区管理：
    // 1. 先清空缓冲区，确保设备就绪
    await clearBuffer();

    // 2. 发送保存指令
    final result = await sendViscaCommand(cmd);

    // 3. 等待保存操作完成
    await Future.delayed(const Duration(milliseconds: 20));

    // 4. 再次清空缓冲区，确保保存操作完全生效
    await clearBuffer();

    return result;
  }

  /// 调用预置位
  /// 
  /// 将摄像头移动到指定预置位保存的位置
  /// 
  /// VISCA协议格式：[地址] 01 04 3F 02 [presetNum] FF
  /// - 01：摄像机控制类别
  /// - 04：镜头控制指令
  /// - 3F：预置位控制指令
  /// - 02：调用子指令
  /// - presetNum：预置位编号（0-based，0-15）
  /// 
  /// 参数：
  /// - presetNum: 预置位编号（1-based，1-16），内部转换为0-based
  /// 
  /// 返回值：调用成功返回true，失败返回false
  Future<bool> presetRecall(int presetNum) async {
    // 构建调用预置位指令，预置位编号减1转为0-based
    final cmd = '${_hex(_addr)} 01 04 3F 02 ${_hex(presetNum - 1)} FF';

    // 预置位操作需要额外的缓冲区管理：
    // 1. 先清空缓冲区，确保设备就绪
    await clearBuffer();

    // 2. 发送调用指令
    final result = await sendViscaCommand(cmd);

    // 3. 等待移动操作启动
    await Future.delayed(const Duration(milliseconds: 20));

    // 4. 再次清空缓冲区，确保调用操作不受干扰
    await clearBuffer();

    return result;
  }

  /// 将整数转换为2位16进制字符串（大写）
  /// 
  /// 用于构建VISCA指令中的各个字节
  /// 
  /// 参数：
  /// - value: 需要转换的整数（0-255）
  /// 
  /// 返回值：2位16进制字符串，如15转为"0F"，255转为"FF"
  String _hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// ============================================================
/// 摄像头连接管理器（单例模式）
/// 
/// 负责管理所有摄像头连接实例，实现互斥连接机制：
/// - 同一时间仅能有一个摄像头处于连接状态
/// - 选中某个摄像头时，自动断开其他所有摄像头的连接
/// - 离开摄像头页面时，断开所有连接
/// 
/// 继承 ChangeNotifier，支持状态变化通知，UI层可监听连接状态变化
/// ============================================================
class CameraConnectionManager extends ChangeNotifier {
  /// 单例实例（私有）
  static final CameraConnectionManager _instance = CameraConnectionManager._internal();

  /// 工厂构造函数，返回单例实例
  factory CameraConnectionManager() => _instance;

  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  /// 私有构造函数，初始化所有摄像头连接实例
  /// 
  /// 从 DeviceConfig 中读取所有摄像头配置，为每个摄像头创建连接实例
  /// 此时仅创建实例，不进行实际连接
  CameraConnectionManager._internal() {
    // 遍历所有配置的摄像头设备
    for (int i = 0; i < _config.cameraDevices.length; i++) {
      final dev = _config.cameraDevices[i];

      // 创建摄像头连接实例并添加到列表
      _connections.add(CameraConnection(
        ip: dev['ip'] as String,           // 设备IP地址
        port: dev['port'] as int,          // 设备端口号
        viscaAddr: dev['viscaAddr'] as int, // VISCA摄像机地址
      ));
    }
  }

  /// 所有摄像头连接实例列表
  /// 索引0对应摄像头1，索引1对应摄像头2，以此类推
  final List<CameraConnection> _connections = [];

  /// 当前选中的摄像头索引（0-based）
  /// -1 表示未选中任何摄像头
  int _activeIndex = -1;

  /// 获取当前活跃的摄像头连接
  /// 
  /// 返回值：当前选中的摄像头连接实例，未选中或索引无效时返回null
  CameraConnection? get activeConnection =>
      (_activeIndex >= 0 && _activeIndex < _connections.length)
          ? _connections[_activeIndex]
          : null;

  /// 获取当前选中的摄像头编号（1-based）
  /// 
  /// 返回值：摄像头编号（1-摄像头总数），未选中时返回0
  int get activeCameraNumber => _activeIndex + 1;

  /// 获取当前连接状态（基于活跃摄像头）
  /// 
  /// 返回值：当前活跃摄像头的连接状态，未选中时返回disconnected
  ConnectionStatus get status =>
      activeConnection?.status ?? ConnectionStatus.disconnected;

  /// 获取摄像头总数
  /// 
  /// 返回值：配置文件中定义的摄像头数量
  int get cameraCount => _connections.length;

  /// 获取指定索引的摄像头连接实例
  /// 
  /// 参数：
  /// - index: 摄像头索引（0-based）
  /// 
  /// 返回值：指定索引的摄像头连接实例
  CameraConnection getConnection(int index) => _connections[index];

  /// 连接指定摄像头（互斥连接机制）
  /// 
  /// 互斥连接逻辑说明：
  /// 1. 验证摄像头编号有效性（1-based）
  /// 2. 如果选中的摄像头已连接，直接返回（避免重复连接）
  /// 3. 断开所有已存在的连接（确保互斥）
  /// 4. 设置新的活跃索引
  /// 5. 连接新选中的摄像头
  /// 6. 监听新连接的状态变化
  /// 7. 通知UI层状态变化
  /// 
  /// 参数：
  /// - cameraNumber: 摄像头编号（1-based，1到摄像头总数）
  void connectCamera(int cameraNumber) {
    // 将1-based编号转换为0-based索引
    final int index = cameraNumber - 1;

    // 验证索引有效性：索引必须在0到摄像头总数-1之间
    if (index < 0 || index >= _connections.length) return;

    // 如果选中的摄像头已连接且是当前活跃摄像头，直接返回
    // 避免重复连接操作，减少不必要的网络开销
    if (_activeIndex == index && _connections[index].isConnected) return;

    // ==================== 互斥连接核心逻辑 ====================
    // 断开之前所有摄像头的连接，确保同一时间仅有一个连接
    // 这是互斥连接的关键步骤：先断后连
    _disconnectAll();

    // 更新当前活跃索引为新选中的摄像头
    _activeIndex = index;

    // 连接新选中的摄像头
    _connections[index].connect();

    // 监听该连接的状态变化，当连接状态改变时通知UI层
    _connections[index].addListener(_onConnectionChanged);

    // 通知所有监听者（UI层）状态已变化
    notifyListeners();
  }

  /// 断开所有摄像头连接（公开方法）
  /// 
  /// 离开摄像头页面时调用，断开所有连接并重置活跃索引
  void disconnectAll() {
    // 调用内部方法断开所有连接
    _disconnectAll();

    // 重置活跃索引为-1，表示未选中任何摄像头
    _activeIndex = -1;

    // 通知所有监听者状态已变化
    notifyListeners();
  }

  /// 内部方法：断开所有连接并清理资源
  /// 
  /// 对所有连接执行以下操作：
  /// 1. 移除状态变化监听器（避免内存泄漏和重复通知）
  /// 2. 调用disconnect()方法断开连接
  ///    - 取消心跳定时器
  ///    - 取消自动重连定时器
  ///    - 销毁Socket连接
  /// 
  /// 此方法确保即使连接处于error状态但重连timer仍在运行，也能被彻底清理
  void _disconnectAll() {
    // 遍历所有连接实例
    for (final conn in _connections) {
      // 移除状态变化监听器，防止已断开的连接继续触发通知
      conn.removeListener(_onConnectionChanged);

      // 无条件断开连接：无论当前状态如何，都强制断开
      // 这会取消心跳、取消重连、销毁socket
      conn.disconnect();
    }
  }

  /// 连接状态变化回调
  /// 
  /// 当活跃摄像头的连接状态发生变化时，转发通知到UI层
  void _onConnectionChanged() {
    // 通知所有监听者（UI层）状态已变化
    notifyListeners();
  }

  /// 销毁管理器，释放所有资源
  /// 
  /// 调用顺序：
  /// 1. 断开所有连接
  /// 2. 释放每个连接实例的资源
  /// 3. 调用父类dispose()方法
  @override
  void dispose() {
    // 断开所有连接
    _disconnectAll();

    // 遍历所有连接实例，调用dispose()释放资源
    for (final conn in _connections) {
      conn.dispose();
    }

    // 调用父类dispose()方法
    super.dispose();
  }
}
