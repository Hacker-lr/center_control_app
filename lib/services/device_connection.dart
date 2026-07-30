import 'base_connection.dart';
import 'device_config.dart';

/// ============================================================
/// 设备档案：区分三种"配置驱动"的硬件设备连接
/// - timingPower：时序电源
/// - bigScreen ：大屏拼接器
/// - ledPower   ：大屏电箱 PLC（LED 电源）
///
/// 三者均继承 BaseConnection 基类，仅取数的 DeviceConfig 字段不同，
/// 故合并为同一个通用连接类，按档案区分实例，避免三份重复代码。
/// ============================================================
enum DeviceProfile {
  /// 时序电源设备
  timingPower,

  /// 大屏拼接器设备
  bigScreen,

  /// 大屏电箱 PLC（LED 电源）设备
  ledPower,
}

/// ============================================================
/// 通用设备连接服务（单例，按 DeviceProfile 区分实例）
/// 继承 BaseConnection 基类，仅根据档案从 DeviceConfig 取对应配置
/// ============================================================
class DeviceConnection extends BaseConnection {
  /// 设备档案
  final DeviceProfile profile;

  /// 各档案对应的唯一实例缓存（懒初始化一次）
  static final Map<DeviceProfile, DeviceConnection> _instances = {
    for (final DeviceProfile p in DeviceProfile.values)
      p: DeviceConnection._internal(p),
  };

  /// 工厂构造函数：按档案取对应单例
  /// 例：DeviceConnection(DeviceProfile.timingPower)
  factory DeviceConnection(DeviceProfile profile) => _instances[profile]!;

  /// 便捷静态访问器，调用处可读性更好，等价于工厂构造：
  ///   DeviceConnection.timingPower / .bigScreen / .ledPower
  static DeviceConnection get timingPower =>
      _instances[DeviceProfile.timingPower]!;
  static DeviceConnection get bigScreen =>
      _instances[DeviceProfile.bigScreen]!;
  static DeviceConnection get ledPower => _instances[DeviceProfile.ledPower]!;

  DeviceConnection._internal(this.profile);

  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  @override
  String get deviceIp {
    switch (profile) {
      case DeviceProfile.timingPower:
        return _config.powerDeviceIp;
      case DeviceProfile.bigScreen:
        return _config.bigScreenDeviceIp;
      case DeviceProfile.ledPower:
        return _config.ledPowerDeviceIp;
    }
  }

  @override
  int get devicePort {
    switch (profile) {
      case DeviceProfile.timingPower:
        return _config.powerDevicePort;
      case DeviceProfile.bigScreen:
        return _config.bigScreenDevicePort;
      case DeviceProfile.ledPower:
        return _config.ledPowerDevicePort;
    }
  }

  @override
  bool get useTcp {
    switch (profile) {
      case DeviceProfile.timingPower:
        return _config.powerUseTcp;
      case DeviceProfile.bigScreen:
        return _config.bigScreenUseTcp;
      case DeviceProfile.ledPower:
        return _config.ledPowerUseTcp;
    }
  }

  @override
  bool get sendAsHex {
    switch (profile) {
      case DeviceProfile.timingPower:
        return _config.powerSendAsHex;
      case DeviceProfile.bigScreen:
        return _config.bigScreenSendAsHex;
      case DeviceProfile.ledPower:
        return _config.ledPowerSendAsHex;
    }
  }

  @override
  String get heartbeatCommand => 'HEARTBEAT\r\n';
}
