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

  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  @override
  String get deviceIp => _config.matrixDeviceIp;

  @override
  int get devicePort => _config.matrixDevicePort;

  @override
  bool get useTcp => _config.matrixUseTcp;

  @override
  bool get sendAsHex => _config.matrixSendAsHex;

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}
