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

  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  @override
  String get deviceIp => _config.powerDeviceIp;

  @override
  int get devicePort => _config.powerDevicePort;

  @override
  bool get useTcp => _config.powerUseTcp;

  @override
  bool get sendAsHex => _config.powerSendAsHex;

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}
