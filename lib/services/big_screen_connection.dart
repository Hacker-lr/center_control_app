import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 大屏拼接器设备连接服务（单例模式）
/// 继承 BaseConnection 基类，只需提供设备配置参数
/// ============================================================
class BigScreenConnection extends BaseConnection {
  static final BigScreenConnection _instance = BigScreenConnection._internal();
  factory BigScreenConnection() => _instance;
  BigScreenConnection._internal();

  @override
  String get deviceIp => DeviceConfig.bigScreenDeviceIp;

  @override
  int get devicePort => DeviceConfig.bigScreenDevicePort;

  @override
  bool get sendAsHex => DeviceConfig.bigScreenSendAsHex;

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}