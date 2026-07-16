import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 视频矩阵设备连接服务（单例模式）
/// 继承 BaseConnection 基类，只需提供设备配置参数
/// ============================================================
class MatrixConnection extends BaseConnection {
  static final MatrixConnection _instance = MatrixConnection._internal();
  factory MatrixConnection() => _instance;
  MatrixConnection._internal();

  @override
  String get deviceIp => DeviceConfig.matrixDeviceIp;

  @override
  int get devicePort => DeviceConfig.matrixDevicePort;

  @override
  bool get sendAsHex => DeviceConfig.matrixSendAsHex;

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}