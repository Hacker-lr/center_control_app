import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 时序电源设备连接服务（单例模式）
/// 继承 BaseConnection 基类，只需提供设备配置参数
/// ============================================================
class DeviceConnection extends BaseConnection {
  static final DeviceConnection _instance = DeviceConnection._internal();
  factory DeviceConnection() => _instance;
  DeviceConnection._internal();

  @override
  String get deviceIp => DeviceConfig.powerDeviceIp;

  @override
  int get devicePort => DeviceConfig.powerDevicePort;

  @override
  bool get sendAsHex => DeviceConfig.powerSendAsHex;

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}