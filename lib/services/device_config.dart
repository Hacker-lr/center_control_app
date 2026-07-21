import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// [开发者注意] 设备品牌配置数据结构
/// ============================================================
/// 每个品牌对应一组完整的通信参数：
///   - 通信协议（TCP / UDP）
///   - 端口号
///   - 发送模式（ASCII / 16进制）
///   - ASCII 指令模板（仅 sendAsHex=false 时生效）
///   - 16进制指令模板（仅 sendAsHex=true 时生效）
///
/// 同一设备类型下的不同品牌的发送模式相互独立：
///   例如视频矩阵选择"品牌A"时使用ASCII模式，
///   切换到"品牌B"后可以独立设置成16进制模式。
/// 开发者只需在下方品牌配置列表中预定义好每个品牌的参数，
/// 运行时通过配置页面选择品牌即可自动应用对应参数，
/// 无需手动修改协议、端口、发送模式或指令代码。
/// ============================================================
class BrandConfig {
  /// 品牌名称（用于在配置页下拉框中显示）
  final String name;

  /// 通信协议：true=TCP, false=UDP
  final bool useTcp;

  /// 通信端口号
  final int port;

  /// 指令发送模式：false=ASCII 文本模式, true=16进制 字节模式
  /// 每个品牌独立配置，不同品牌可以使用不同的发送模式
  final bool sendAsHex;

  /// ASCII 指令模板（仅 sendAsHex=false 时生效）
  /// 模板中可用占位符：
  ///   {input}    - 矩阵输入通道号（1-based）
  ///   {output}   - 矩阵输出通道号（1-based）
  ///   {layout}   - 大屏分屏号
  final String asciiCmd;

  /// 16进制指令模板（仅 sendAsHex=true 时生效）
  /// 模板中可用占位符：
  ///   {input02X}    - 矩阵输入通道号（1字节16进制，例如 01）
  ///   {output02X}   - 矩阵输出通道号（1字节16进制，例如 01）
  ///   {layout02X}   - 大屏分屏号（1字节16进制）
  final String hexCmd;

  const BrandConfig({
    required this.name,
    required this.useTcp,
    required this.port,
    required this.sendAsHex,
    required this.asciiCmd,
    required this.hexCmd,
  });
}

/// ============================================================
/// [开发者注意] 全局配置中心（动态版本）
/// ============================================================
/// 本文件是整个项目的【唯一参数配置中心】。
/// 所有设备参数、布局参数、UI主题、交互参数均集中于此。
///
/// 【开发者修改指南】：
///   1. 添加新品牌：在下方"设备品牌配置"列表中添加 BrandConfig 即可，
///      配置页面会自动列出该品牌。
///   2. 调整默认IP/端口：直接修改本文件中对应的默认值。
///   3. 调整UI：修改底部的"UI主题"和"动画尺寸"常量。
///   4. 添加新页面开关：在"页面显示开关"区域添加新的布尔配置项，
///      并在 main.dart 中根据该开关决定是否显示对应页面。
///
/// 【持久化机制】：
///   - 所有运行时修改的配置会自动保存到 SharedPreferences。
///   - 启动时自动从 SharedPreferences 加载，覆盖默认值。
///   - 调用 resetAll() 可恢复所有默认配置。
///
/// 【配置通知机制】：
///   - 修改配置后调用 notifyListeners() 通知所有监听者刷新。
///   - 需要响应配置变化的 Widget 通过 `context.watch<DeviceConfig>()` 订阅。
/// ============================================================
class DeviceConfig extends ChangeNotifier {
  /// ============================================================
  /// 单例模式
  /// ============================================================
  /// 整个App共用一个 DeviceConfig 实例，
  /// 通过 DeviceConfig() 获取单例
  static final DeviceConfig _instance = DeviceConfig._internal();
  factory DeviceConfig() => _instance;
  DeviceConfig._internal() {
    init(); // 启动时从 SharedPreferences 加载配置
  }

  /// SharedPreferences 实例（用于持久化存储）
  SharedPreferences? _prefs;

  /// ============================================================
  /// 配置键前缀（避免与其它业务键冲突）
  /// ============================================================
  static const String _keyPrefix = 'center_control_config_';

  /// ============================================================
  /// 视频矩阵品牌配置列表
  /// ============================================================
  /// 【开发者提示】在此添加新的视频矩阵品牌。
  /// 每个品牌的 sendAsHex 独立配置，可与其它品牌的发送模式不同。
  static final List<BrandConfig> matrixBrandConfigs = [
    // 默认品牌小鸟：UDP协议，端口5000，ASCII模式
    const BrandConfig(
      name: 'DIGBIRD小鸟矩阵',
      useTcp: false,
      port: 5000,
      sendAsHex: false,
      asciiCmd: '({input},{output},1,D,B)',
      hexCmd: '02 03 {input02X} {output02X} FF',
    ),
    // 品牌乐泰：TCP协议，端口6000，ASCII模式(乐泰原生网络控制不稳定，用网转串控制)
    const BrandConfig(
      name: 'LOHTEA乐泰16路矩阵',
      useTcp: false,
      port: 6000,
      sendAsHex: true,
      asciiCmd: 'SWITCH {input} {output}\r\n',
      hexCmd: '23 41 00 03 04 {(output-1)02X} {(input-1)02X} 46 FF',
    ),
    // 品牌B：TCP协议，端口8080，16进制模式
    // const BrandConfig(
    //   name: '品牌B',
    //   useTcp: true,
    //   port: 8080,
    //   sendAsHex: true,
    //   asciiCmd: 'IN{input} OUT{output}\r\n',
    //   hexCmd: '00 01 {input02X} {output02X} FF',
    // ),
  ];

  /// ============================================================
  /// 大屏拼接器品牌配置列表
  /// ============================================================
  /// 【开发者提示】在此添加新的大屏拼接器品牌。
  /// 每个品牌的 sendAsHex 独立配置。
  static final List<BrandConfig> bigScreenBrandConfigs = [
    // 默认品牌：TCP协议，端口5000，ASCII模式
    const BrandConfig(
      name: 'Leyard利亚德大屏拼接器',
      useTcp: true,
      port: 6000,
      sendAsHex: false,
      asciiCmd: 'LAYOUT:{layout}\r\n',
      hexCmd: '03 01 {layout02X} FF',
    ),
    // 品牌A：UDP协议，端口7000，ASCII模式
    // const BrandConfig(
    //   name: '品牌A',
    //   useTcp: false,
    //   port: 7000,
    //   sendAsHex: false,
    //   asciiCmd: 'SET_LAYOUT {layout}\r\n',
    //   hexCmd: '11 22 {layout02X} 33',
    // ),
    // 品牌B：TCP协议，端口9090，16进制模式
    // const BrandConfig(
    //   name: '品牌B',
    //   useTcp: true,
    //   port: 9090,
    //   sendAsHex: true,
    //   asciiCmd: 'DISPLAY {layout}\r\n',
    //   hexCmd: '00 02 {layout02X} FF',
    // ),
  ];

  /// ============================================================
  /// 时序电源品牌配置列表
  /// ============================================================
  /// 【开发者提示】在此添加新的时序电源品牌。
  /// 每个品牌的 sendAsHex 独立配置。
  static final List<BrandConfig> powerBrandConfigs = [
    // 默认品牌：TCP协议，端口5000，ASCII模式
    const BrandConfig(
      name: '默认品牌',
      useTcp: true,
      port: 5000,
      sendAsHex: false,
      asciiCmd: 'POWER_ON\r\n',
      hexCmd: '01 05 00 00 FF 00',
    ),
    // 品牌A：UDP协议，端口5500，ASCII模式
    const BrandConfig(
      name: '品牌A',
      useTcp: false,
      port: 5500,
      sendAsHex: false,
      asciiCmd: 'ON\r\n',
      hexCmd: 'AA 01 FF',
    ),
    // 品牌B：TCP协议，端口6600，16进制模式
    const BrandConfig(
      name: '品牌B',
      useTcp: true,
      port: 6600,
      sendAsHex: true,
      asciiCmd: 'POWER 1\r\n',
      hexCmd: '00 01 00 01',
    ),
  ];

  /// ============================================================
  /// 当前选中的品牌配置（运行时动态修改）
  /// ============================================================

  /// 视频矩阵当前选中的品牌名称
  String _matrixBrand = '默认品牌';
  String get matrixBrand => _matrixBrand;
  void setMatrixBrand(String value) {
    _matrixBrand = value;
    _saveString('matrixBrand', value);
    _applyBrandConfig('matrix', value);
    notifyListeners();
  }

  /// 大屏拼接器当前选中的品牌名称
  String _bigScreenBrand = '默认品牌';
  String get bigScreenBrand => _bigScreenBrand;
  void setBigScreenBrand(String value) {
    _bigScreenBrand = value;
    _saveString('bigScreenBrand', value);
    _applyBrandConfig('bigScreen', value);
    notifyListeners();
  }

  /// 时序电源当前选中的品牌名称
  String _powerBrand = '默认品牌';
  String get powerBrand => _powerBrand;
  void setPowerBrand(String value) {
    _powerBrand = value;
    _saveString('powerBrand', value);
    _applyBrandConfig('power', value);
    notifyListeners();
  }

  /// 根据品牌名称应用对应的配置参数
  /// 切换品牌时会自动覆盖：协议(TCP/UDP)、端口、发送模式(ASCII/16进制)、控制指令
  void _applyBrandConfig(String deviceType, String brandName) {
    BrandConfig? config;
    switch (deviceType) {
      case 'matrix':
        // 查找匹配的品牌配置，找不到则使用列表第一个
        config = matrixBrandConfigs.firstWhere(
          (b) => b.name == brandName,
          orElse: () => matrixBrandConfigs[0],
        );
        // 应用品牌的协议配置
        _matrixUseTcp = config.useTcp;
        // 应用品牌的端口配置
        _matrixDevicePort = config.port;
        // 应用品牌的发送模式配置（每个品牌独立）
        _matrixSendAsHex = config.sendAsHex;
        // 应用品牌的ASCII指令模板
        _matrixSwitchAsciiCmd = config.asciiCmd;
        // 应用品牌的16进制指令模板
        _hexMatrixSwitchCmd = config.hexCmd;
        // 持久化保存
        _saveBool('matrixUseTcp', config.useTcp);
        _saveInt('matrixDevicePort', config.port);
        _saveBool('matrixSendAsHex', config.sendAsHex);
        _saveString('matrixSwitchAsciiCmd', config.asciiCmd);
        _saveString('hexMatrixSwitchCmd', config.hexCmd);
        break;
      case 'bigScreen':
        config = bigScreenBrandConfigs.firstWhere(
          (b) => b.name == brandName,
          orElse: () => bigScreenBrandConfigs[0],
        );
        _bigScreenUseTcp = config.useTcp;
        _bigScreenDevicePort = config.port;
        _bigScreenSendAsHex = config.sendAsHex;
        _bigScreenLayoutAsciiCmd = config.asciiCmd;
        _hexBigScreenLayoutCmd = config.hexCmd;
        _saveBool('bigScreenUseTcp', config.useTcp);
        _saveInt('bigScreenDevicePort', config.port);
        _saveBool('bigScreenSendAsHex', config.sendAsHex);
        _saveString('bigScreenLayoutAsciiCmd', config.asciiCmd);
        _saveString('hexBigScreenLayoutCmd', config.hexCmd);
        break;
      case 'power':
        config = powerBrandConfigs.firstWhere(
          (b) => b.name == brandName,
          orElse: () => powerBrandConfigs[0],
        );
        _powerUseTcp = config.useTcp;
        _powerDevicePort = config.port;
        _powerSendAsHex = config.sendAsHex;
        _powerOnAsciiCmd = config.asciiCmd;
        _hexPowerOnCmd = config.hexCmd;
        _saveBool('powerUseTcp', config.useTcp);
        _saveInt('powerDevicePort', config.port);
        _saveBool('powerSendAsHex', config.sendAsHex);
        _saveString('powerOnAsciiCmd', config.asciiCmd);
        _saveString('hexPowerOnCmd', config.hexCmd);
        break;
    }
  }

  /// 验证品牌名称是否有效
  /// 如果保存的品牌名称不在品牌配置列表中，重置为默认品牌
  /// 防止 DropdownButton 因 value 不在 items 中而报错
  void _validateBrandName() {
    final bool matrixBrandValid = matrixBrandConfigs.any((b) => b.name == _matrixBrand);
    if (!matrixBrandValid) {
      _matrixBrand = matrixBrandConfigs[0].name;
    }
    final bool bigScreenBrandValid = bigScreenBrandConfigs.any((b) => b.name == _bigScreenBrand);
    if (!bigScreenBrandValid) {
      _bigScreenBrand = bigScreenBrandConfigs[0].name;
    }
    final bool powerBrandValid = powerBrandConfigs.any((b) => b.name == _powerBrand);
    if (!powerBrandValid) {
      _powerBrand = powerBrandConfigs[0].name;
    }
  }

  /// ============================================================
  /// 一、时序电源设备配置
  /// ============================================================

  /// 时序电源设备的IP地址
  String _powerDeviceIp = '192.168.0.64';
  String get powerDeviceIp => _powerDeviceIp;
  void setPowerDeviceIp(String value) {
    _powerDeviceIp = value;
    _saveString('powerDeviceIp', value);
    notifyListeners();
  }

  /// 时序电源设备的TCP端口号
  int _powerDevicePort = 5000;
  int get powerDevicePort => _powerDevicePort;
  void setPowerDevicePort(int value) {
    _powerDevicePort = value;
    _saveInt('powerDevicePort', value);
    notifyListeners();
  }

  /// ============================================================
  /// 二、视频矩阵设备配置
  /// ============================================================

  /// 视频矩阵设备的IP地址
  String _matrixDeviceIp = '192.168.0.64';
  String get matrixDeviceIp => _matrixDeviceIp;
  void setMatrixDeviceIp(String value) {
    _matrixDeviceIp = value;
    _saveString('matrixDeviceIp', value);
    notifyListeners();
  }

  /// 视频矩阵设备的TCP端口号
  int _matrixDevicePort = 5000;
  int get matrixDevicePort => _matrixDevicePort;
  void setMatrixDevicePort(int value) {
    _matrixDevicePort = value;
    _saveInt('matrixDevicePort', value);
    notifyListeners();
  }

  /// ============================================================
  /// 三、大屏拼接器设备配置
  /// ============================================================

  /// 大屏拼接器设备的IP地址
  String _bigScreenDeviceIp = '192.168.0.64';
  String get bigScreenDeviceIp => _bigScreenDeviceIp;
  void setBigScreenDeviceIp(String value) {
    _bigScreenDeviceIp = value;
    _saveString('bigScreenDeviceIp', value);
    notifyListeners();
  }

  /// 大屏拼接器设备的TCP端口号
  int _bigScreenDevicePort = 5000;
  int get bigScreenDevicePort => _bigScreenDevicePort;
  void setBigScreenDevicePort(int value) {
    _bigScreenDevicePort = value;
    _saveInt('bigScreenDevicePort', value);
    notifyListeners();
  }

  /// ============================================================
  /// 四、摄像头设备配置
  /// ============================================================

  /// 摄像头设备列表配置
  /// 每个摄像头独立配置IP和端口，选中时仅连接对应设备，其余断开
  /// ip: 摄像头VISCA over IP网关地址
  /// port: VISCA over IP端口（默认52381）
  /// viscaAddr: VISCA协议中的摄像机地址（1-7，指令中会加上0x80偏移）
  /// 列表长度即为摄像头数量，无需单独配置 cameraCount
  List<Map<String, dynamic>> _cameraDevices = [
    {'ip': '192.168.0.64', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.65', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.66', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.67', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.68', 'port': 52381, 'viscaAddr': 1},
  ];
  List<Map<String, dynamic>> get cameraDevices => _cameraDevices;
  void setCameraDevices(List<Map<String, dynamic>> value) {
    _cameraDevices = value;
    _saveCameraDevices();
    notifyListeners();
  }

  /// ============================================================
  /// 五、控制页面显示开关配置
  /// ============================================================
  /// 【开发者说明】：
  ///   - 每个开关对应一个控制页面以及底部导航栏的对应按钮。
  ///   - true=显示该页面，false=隐藏该页面（导航栏上也不显示）。
  ///   - 这些开关在配置页面中可以由调试人员手动切换。
  ///   - 当所有开关都为 false 时，主页面会显示提示信息。
  ///   - main.dart 中的 _buildPageEntries() 会根据这些开关动态构建页面列表。
  /// ============================================================

  /// 是否显示"时序电源控制"页面
  /// true: 显示电源控制页面，并在底部导航栏显示"电源控制"按钮
  /// false: 完全隐藏电源控制功能
  bool _showPowerControl = true;
  bool get showPowerControl => _showPowerControl;
  void setShowPowerControl(bool value) {
    _showPowerControl = value;
    _saveBool('showPowerControl', value);
    notifyListeners();
  }

  /// 是否显示"大屏控制"页面
  /// true: 显示大屏分屏控制页面，并在底部导航栏显示"大屏控制"按钮
  /// false: 完全隐藏大屏控制功能
  bool _showBigScreen = true;
  bool get showBigScreen => _showBigScreen;
  void setShowBigScreen(bool value) {
    _showBigScreen = value;
    _saveBool('showBigScreen', value);
    notifyListeners();
  }

  /// 是否显示"视频矩阵控制"页面
  /// true: 显示视频矩阵输入/输出切换页面，并在底部导航栏显示"视频矩阵"按钮
  /// false: 完全隐藏视频矩阵控制功能
  bool _showVideoMatrix = true;
  bool get showVideoMatrix => _showVideoMatrix;
  void setShowVideoMatrix(bool value) {
    _showVideoMatrix = value;
    _saveBool('showVideoMatrix', value);
    notifyListeners();
  }

  /// 是否显示"摄像头控制"页面
  /// true: 显示摄像头云台控制和预置位管理页面，并在底部导航栏显示"摄像头"按钮
  /// false: 完全隐藏摄像头控制功能
  bool _showCameraControl = true;
  bool get showCameraControl => _showCameraControl;
  void setShowCameraControl(bool value) {
    _showCameraControl = value;
    _saveBool('showCameraControl', value);
    notifyListeners();
  }

  /// ============================================================
  /// 六、大屏分屏按钮显示开关配置
  /// ============================================================
  /// 【开发者说明】：用于控制大屏分屏页面的分屏模式按钮显示。
  ///   - showBigScreenFull:     全屏单画面（4:3）
  ///   - showBigScreenFull169:  全屏单画面（16:9）
  ///   - showBigScreenSplit2:   二分屏
  ///   - showBigScreenSplit3:   三分屏
  ///   - showBigScreenSplit4:   四分屏
  ///   - showBigScreenSplit5:   五分屏
  ///   - true=显示该分屏模式按钮，false=隐藏该分屏模式按钮
  bool _showBigScreenFull = true;
  bool get showBigScreenFull => _showBigScreenFull;
  void setShowBigScreenFull(bool value) {
    _showBigScreenFull = value;
    _saveBool('showBigScreenFull', value);
    notifyListeners();
  }

  bool _showBigScreenFull169 = true;
  bool get showBigScreenFull169 => _showBigScreenFull169;
  void setShowBigScreenFull169(bool value) {
    _showBigScreenFull169 = value;
    _saveBool('showBigScreenFull169', value);
    notifyListeners();
  }

  bool _showBigScreenSplit2 = true;
  bool get showBigScreenSplit2 => _showBigScreenSplit2;
  void setShowBigScreenSplit2(bool value) {
    _showBigScreenSplit2 = value;
    _saveBool('showBigScreenSplit2', value);
    notifyListeners();
  }

  bool _showBigScreenSplit3 = true;
  bool get showBigScreenSplit3 => _showBigScreenSplit3;
  void setShowBigScreenSplit3(bool value) {
    _showBigScreenSplit3 = value;
    _saveBool('showBigScreenSplit3', value);
    notifyListeners();
  }

  bool _showBigScreenSplit4 = true;
  bool get showBigScreenSplit4 => _showBigScreenSplit4;
  void setShowBigScreenSplit4(bool value) {
    _showBigScreenSplit4 = value;
    _saveBool('showBigScreenSplit4', value);
    notifyListeners();
  }

  bool _showBigScreenSplit5 = true;
  bool get showBigScreenSplit5 => _showBigScreenSplit5;
  void setShowBigScreenSplit5(bool value) {
    _showBigScreenSplit5 = value;
    _saveBool('showBigScreenSplit5', value);
    notifyListeners();
  }

  /// ============================================================
  /// 七、网络连接通用配置
  /// ============================================================

  /// 连接超时时间（秒）
  int _connectionTimeoutSeconds = 5;
  int get connectionTimeoutSeconds => _connectionTimeoutSeconds;
  void setConnectionTimeoutSeconds(int value) {
    _connectionTimeoutSeconds = value;
    _saveInt('connectionTimeoutSeconds', value);
    notifyListeners();
  }

  /// 心跳包发送间隔（秒）
  int _heartbeatIntervalSeconds = 60;
  int get heartbeatIntervalSeconds => _heartbeatIntervalSeconds;
  void setHeartbeatIntervalSeconds(int value) {
    _heartbeatIntervalSeconds = value;
    _saveInt('heartbeatIntervalSeconds', value);
    notifyListeners();
  }

  /// 心跳超时判定倍数
  int _heartbeatTimeoutMultiplier = 3;
  int get heartbeatTimeoutMultiplier => _heartbeatTimeoutMultiplier;
  void setHeartbeatTimeoutMultiplier(int value) {
    _heartbeatTimeoutMultiplier = value;
    _saveInt('heartbeatTimeoutMultiplier', value);
    notifyListeners();
  }

  /// 自动重连间隔（秒）
  int _reconnectIntervalSeconds = 5;
  int get reconnectIntervalSeconds => _reconnectIntervalSeconds;
  void setReconnectIntervalSeconds(int value) {
    _reconnectIntervalSeconds = value;
    _saveInt('reconnectIntervalSeconds', value);
    notifyListeners();
  }

  /// 通信协议类型：true = TCP, false = UDP（全局配置，已废弃，保留兼容性）
  bool _useTcp = true;
  bool get useTcp => _useTcp;
  void setUseTcp(bool value) {
    _useTcp = value;
    _saveBool('useTcp', value);
    notifyListeners();
  }

  /// 时序电源设备 - true=TCP协议, false=UDP协议
  bool _powerUseTcp = true;
  bool get powerUseTcp => _powerUseTcp;
  void setPowerUseTcp(bool value) {
    _powerUseTcp = value;
    _saveBool('powerUseTcp', value);
    notifyListeners();
  }

  /// 视频矩阵设备 - true=TCP协议, false=UDP协议
  bool _matrixUseTcp = true;
  bool get matrixUseTcp => _matrixUseTcp;
  void setMatrixUseTcp(bool value) {
    _matrixUseTcp = value;
    _saveBool('matrixUseTcp', value);
    notifyListeners();
  }

  /// 大屏拼接器设备 - true=TCP协议, false=UDP协议
  bool _bigScreenUseTcp = true;
  bool get bigScreenUseTcp => _bigScreenUseTcp;
  void setBigScreenUseTcp(bool value) {
    _bigScreenUseTcp = value;
    _saveBool('bigScreenUseTcp', value);
    notifyListeners();
  }

  /// ============================================================
  /// 八、指令发送模式配置（每种设备独立控制）
  /// ============================================================

  /// 时序电源设备 - false=ASCII模式, true=16进制模式
  bool _powerSendAsHex = false;
  bool get powerSendAsHex => _powerSendAsHex;
  void setPowerSendAsHex(bool value) {
    _powerSendAsHex = value;
    _saveBool('powerSendAsHex', value);
    notifyListeners();
  }

  /// 视频矩阵设备 - false=ASCII模式, true=16进制模式
  bool _matrixSendAsHex = false;
  bool get matrixSendAsHex => _matrixSendAsHex;
  void setMatrixSendAsHex(bool value) {
    _matrixSendAsHex = value;
    _saveBool('matrixSendAsHex', value);
    notifyListeners();
  }

  /// 大屏拼接器设备 - false=ASCII模式, true=16进制模式
  bool _bigScreenSendAsHex = false;
  bool get bigScreenSendAsHex => _bigScreenSendAsHex;
  void setBigScreenSendAsHex(bool value) {
    _bigScreenSendAsHex = value;
    _saveBool('bigScreenSendAsHex', value);
    notifyListeners();
  }

  /// 摄像头设备 - VISCA协议必须使用16进制模式，请勿修改
  bool _cameraSendAsHex = true;
  bool get cameraSendAsHex => _cameraSendAsHex;
  void setCameraSendAsHex(bool value) {
    _cameraSendAsHex = value;
    _saveBool('cameraSendAsHex', value);
    notifyListeners();
  }

  /// ============================================================
  /// 九、视频矩阵通道配置
  /// ============================================================

  /// 视频矩阵输入通道数量
  int _matrixInputCount = 16;
  int get matrixInputCount => _matrixInputCount;
  void setMatrixInputCount(int value) {
    _matrixInputCount = value;
    _saveInt('matrixInputCount', value);
    notifyListeners();
  }

  /// 视频矩阵输出通道数量
  int _matrixOutputCount = 16;
  int get matrixOutputCount => _matrixOutputCount;
  void setMatrixOutputCount(int value) {
    _matrixOutputCount = value;
    _saveInt('matrixOutputCount', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十、大屏分屏输出通道映射
  /// ============================================================

  /// 大屏分屏区域对应的矩阵输出通道（1-based，按分屏区域顺序）
  List<int> _bigScreenOutputChannels = [4, 5, 6, 7, 8];
  List<int> get bigScreenOutputChannels => _bigScreenOutputChannels;
  void setBigScreenOutputChannels(List<int> value) {
    _bigScreenOutputChannels = value;
    _saveBigScreenOutputChannels();
    notifyListeners();
  }

  /// ============================================================
  /// 十一、ASCII 指令模板配置（仅 sendAsHex=false 时生效）
  /// ============================================================

  String _powerOnAsciiCmd = 'POWER_ON\r\n';
  String get powerOnAsciiCmd => _powerOnAsciiCmd;
  void setPowerOnAsciiCmd(String value) {
    _powerOnAsciiCmd = value;
    _saveString('powerOnAsciiCmd', value);
    notifyListeners();
  }

  String _powerOffAsciiCmd = 'POWER_OFF\r\n';
  String get powerOffAsciiCmd => _powerOffAsciiCmd;
  void setPowerOffAsciiCmd(String value) {
    _powerOffAsciiCmd = value;
    _saveString('powerOffAsciiCmd', value);
    notifyListeners();
  }

  String _matrixSwitchAsciiCmd = 'MATRIX:IN{input}->OUT{output}\r\n';
  String get matrixSwitchAsciiCmd => _matrixSwitchAsciiCmd;
  void setMatrixSwitchAsciiCmd(String value) {
    _matrixSwitchAsciiCmd = value;
    _saveString('matrixSwitchAsciiCmd', value);
    notifyListeners();
  }

  String _bigScreenLayoutAsciiCmd = 'LAYOUT:{layout}\r\n';
  String get bigScreenLayoutAsciiCmd => _bigScreenLayoutAsciiCmd;
  void setBigScreenLayoutAsciiCmd(String value) {
    _bigScreenLayoutAsciiCmd = value;
    _saveString('bigScreenLayoutAsciiCmd', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十二、16进制指令模板配置（仅 sendAsHex=true 时生效）
  /// ============================================================

  String _hexPowerOnCmd = '01 05 00 00 FF 00';
  String get hexPowerOnCmd => _hexPowerOnCmd;
  void setHexPowerOnCmd(String value) {
    _hexPowerOnCmd = value;
    _saveString('hexPowerOnCmd', value);
    notifyListeners();
  }

  String _hexPowerOffCmd = '01 05 00 00 00 00';
  String get hexPowerOffCmd => _hexPowerOffCmd;
  void setHexPowerOffCmd(String value) {
    _hexPowerOffCmd = value;
    _saveString('hexPowerOffCmd', value);
    notifyListeners();
  }

  String _hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';
  String get hexMatrixSwitchCmd => _hexMatrixSwitchCmd;
  void setHexMatrixSwitchCmd(String value) {
    _hexMatrixSwitchCmd = value;
    _saveString('hexMatrixSwitchCmd', value);
    notifyListeners();
  }

  String _hexBigScreenLayoutCmd = '03 01 {layout02X} FF';
  String get hexBigScreenLayoutCmd => _hexBigScreenLayoutCmd;
  void setHexBigScreenLayoutCmd(String value) {
    _hexBigScreenLayoutCmd = value;
    _saveString('hexBigScreenLayoutCmd', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十三、摄像头参数配置
  /// ============================================================

  int get cameraCount => _cameraDevices.length;

  int _cameraSpeedLow = 1;
  int get cameraSpeedLow => _cameraSpeedLow;
  void setCameraSpeedLow(int value) {
    _cameraSpeedLow = value;
    _saveInt('cameraSpeedLow', value);
    notifyListeners();
  }

  int _cameraSpeedHigh = 15;
  int get cameraSpeedHigh => _cameraSpeedHigh;
  void setCameraSpeedHigh(int value) {
    _cameraSpeedHigh = value;
    _saveInt('cameraSpeedHigh', value);
    notifyListeners();
  }

  int _cameraPresetCount = 8;
  int get cameraPresetCount => _cameraPresetCount;
  void setCameraPresetCount(int value) {
    _cameraPresetCount = value;
    _saveInt('cameraPresetCount', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十四、按钮网格布局配置
  /// ============================================================

  int _gridItemsPerPage = 16;
  int get gridItemsPerPage => _gridItemsPerPage;
  void setGridItemsPerPage(int value) {
    _gridItemsPerPage = value;
    _saveInt('gridItemsPerPage', value);
    notifyListeners();
  }

  int _gridRowCount = 2;
  int get gridRowCount => _gridRowCount;
  void setGridRowCount(int value) {
    _gridRowCount = value;
    _saveInt('gridRowCount', value);
    notifyListeners();
  }

  double _gridBtnHeightFactor = 0.80;
  double get gridBtnHeightFactor => _gridBtnHeightFactor;
  void setGridBtnHeightFactor(double value) {
    _gridBtnHeightFactor = value;
    _saveDouble('gridBtnHeightFactor', value);
    notifyListeners();
  }

  double _gridSpacing4Cross = 10.0;
  double get gridSpacing4Cross => _gridSpacing4Cross;
  void setGridSpacing4Cross(double value) {
    _gridSpacing4Cross = value;
    _saveDouble('gridSpacing4Cross', value);
    notifyListeners();
  }

  double _gridSpacing4Main = 8.0;
  double get gridSpacing4Main => _gridSpacing4Main;
  void setGridSpacing4Main(double value) {
    _gridSpacing4Main = value;
    _saveDouble('gridSpacing4Main', value);
    notifyListeners();
  }

  double _gridSpacing8Cross = 6.0;
  double get gridSpacing8Cross => _gridSpacing8Cross;
  void setGridSpacing8Cross(double value) {
    _gridSpacing8Cross = value;
    _saveDouble('gridSpacing8Cross', value);
    notifyListeners();
  }

  double _gridSpacing8Main = 6.0;
  double get gridSpacing8Main => _gridSpacing8Main;
  void setGridSpacing8Main(double value) {
    _gridSpacing8Main = value;
    _saveDouble('gridSpacing8Main', value);
    notifyListeners();
  }

  double _gridHorizontalPadding = 24.0;
  double get gridHorizontalPadding => _gridHorizontalPadding;
  void setGridHorizontalPadding(double value) {
    _gridHorizontalPadding = value;
    _saveDouble('gridHorizontalPadding', value);
    notifyListeners();
  }

  double _gridVerticalPadding = 16.0;
  double get gridVerticalPadding => _gridVerticalPadding;
  void setGridVerticalPadding(double value) {
    _gridVerticalPadding = value;
    _saveDouble('gridVerticalPadding', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十五、按钮交互配置
  /// ============================================================

  int _longPressDurationMs = 2000;
  int get longPressDurationMs => _longPressDurationMs;
  void setLongPressDurationMs(int value) {
    _longPressDurationMs = value;
    _saveInt('longPressDurationMs', value);
    notifyListeners();
  }

  int _longPressTickIntervalMs = 50;
  int get longPressTickIntervalMs => _longPressTickIntervalMs;
  void setLongPressTickIntervalMs(int value) {
    _longPressTickIntervalMs = value;
    _saveInt('longPressTickIntervalMs', value);
    notifyListeners();
  }

  int _channelNameMaxLength = 10;
  int get channelNameMaxLength => _channelNameMaxLength;
  void setChannelNameMaxLength(int value) {
    _channelNameMaxLength = value;
    _saveInt('channelNameMaxLength', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十六、UI 主题颜色配置（这些配置不支持运行时修改，如需修改请直接改代码）
  /// ============================================================

  static const Color colorCardBg = Color(0xFF0D1117);
  static const Color colorCardBorder = Color(0xFF1E2228);
  static const Color colorButtonBg = Color(0xFF2A2A3E);
  static const Color colorButtonBorder = Color(0xFF3A3F48);
  static const Color colorHighlightInput = Color(0xFF1F4068);
  static const Color colorHighlightOutput = Color(0xFF3E6B48);
  static const Color colorAccent = Color(0xFF6B9BD2);
  static const Color colorPressing = Color(0xFFFFA726);
  static const Color colorStatusConnected = Color(0xFF4CAF50);
  static const Color colorStatusConnecting = Color(0xFFFFA726);
  static const Color colorStatusError = Color(0xFFE53935);
  static const Color colorStatusDisconnected = Color(0xFF9E9E9E);
  static const Color colorSnackBarBg = Color(0xFF3A5A8C);
  static const Color colorDialogBg = Color(0xFF161B22);
  static const Color colorDialogFieldBg = Color(0xFF21262D);
  static const Color colorSplitAreaBg = Color(0xFF1E2228);
  static const Color colorSplitAreaBorder = Color(0xFF2A3038);

  /// ============================================================
  /// 十七、UI 动画与尺寸配置（这些配置不支持运行时修改，如需修改请直接改代码）
  /// ============================================================

  static const int animationDurationMs = 250;
  static const int hintAnimationDurationMs = 300;
  static const double buttonBorderRadiusRatio = 0.12;
  static const double buttonShadowBlurRatio = 0.12;
  static const double buttonShadowBlurSmallRatio = 0.05;
  static const double buttonFontSizeRatio = 0.35;
  static const double buttonPaddingHorizontalRatio = 0.08;
  static const double buttonPaddingVerticalRatio = 0.10;
  static const double longPressIndicatorHeight = 3.0;
  static const double cardBorderRadius = 10.0;
  static const double statusChipBorderRadius = 12.0;
  static const double bannerBorderRadius = 10.0;
  static const double splitAreaGap = 4.0;

  /// ============================================================
  /// 私有方法：初始化和持久化
  /// ============================================================

  /// 初始化 SharedPreferences 并加载配置
  Future<void> init() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
        debugPrint('[DeviceConfig] SharedPreferences 初始化成功');
        _loadAllConfig();
      }
    } catch (e) {
      debugPrint('[DeviceConfig] SharedPreferences 初始化失败: $e');
    }
  }

  /// 加载所有配置项
  void _loadAllConfig() {
    _powerDeviceIp = _loadString('powerDeviceIp', '192.168.0.64');
    _powerDevicePort = _loadInt('powerDevicePort', 5000);
    _matrixDeviceIp = _loadString('matrixDeviceIp', '192.168.0.64');
    _matrixDevicePort = _loadInt('matrixDevicePort', 5000);
    _bigScreenDeviceIp = _loadString('bigScreenDeviceIp', '192.168.0.64');
    _bigScreenDevicePort = _loadInt('bigScreenDevicePort', 5000);
    _matrixBrand = _loadString('matrixBrand', '默认品牌');
    _bigScreenBrand = _loadString('bigScreenBrand', '默认品牌');
    _powerBrand = _loadString('powerBrand', '默认品牌');
    // 验证品牌名称是否有效，无效则重置为默认品牌（不覆盖用户手动修改的其他参数）
    _validateBrandName();
    _loadCameraDevices();
    _showPowerControl = _loadBool('showPowerControl', true);
    _showBigScreen = _loadBool('showBigScreen', true);
    _showVideoMatrix = _loadBool('showVideoMatrix', true);
    _showCameraControl = _loadBool('showCameraControl', true);
    _showBigScreenFull = _loadBool('showBigScreenFull', true);
    _showBigScreenFull169 = _loadBool('showBigScreenFull169', true);
    _showBigScreenSplit2 = _loadBool('showBigScreenSplit2', true);
    _showBigScreenSplit3 = _loadBool('showBigScreenSplit3', true);
    _showBigScreenSplit4 = _loadBool('showBigScreenSplit4', true);
    _showBigScreenSplit5 = _loadBool('showBigScreenSplit5', true);
    _connectionTimeoutSeconds = _loadInt('connectionTimeoutSeconds', 5);
    _heartbeatIntervalSeconds = _loadInt('heartbeatIntervalSeconds', 60);
    _heartbeatTimeoutMultiplier = _loadInt('heartbeatTimeoutMultiplier', 3);
    _reconnectIntervalSeconds = _loadInt('reconnectIntervalSeconds', 5);
    _useTcp = _loadBool('useTcp', true);
    _powerUseTcp = _loadBool('powerUseTcp', true);
    _matrixUseTcp = _loadBool('matrixUseTcp', true);
    _bigScreenUseTcp = _loadBool('bigScreenUseTcp', true);
    _powerSendAsHex = _loadBool('powerSendAsHex', false);
    _matrixSendAsHex = _loadBool('matrixSendAsHex', false);
    _bigScreenSendAsHex = _loadBool('bigScreenSendAsHex', false);
    _cameraSendAsHex = _loadBool('cameraSendAsHex', true);
    _matrixInputCount = _loadInt('matrixInputCount', 16);
    _matrixOutputCount = _loadInt('matrixOutputCount', 16);
    _loadBigScreenOutputChannels();
    _powerOnAsciiCmd = _loadString('powerOnAsciiCmd', 'POWER_ON\r\n');
    _powerOffAsciiCmd = _loadString('powerOffAsciiCmd', 'POWER_OFF\r\n');
    _matrixSwitchAsciiCmd = _loadString(
      'matrixSwitchAsciiCmd',
      'MATRIX:IN{input}->OUT{output}\r\n',
    );
    _bigScreenLayoutAsciiCmd = _loadString(
      'bigScreenLayoutAsciiCmd',
      'LAYOUT:{layout}\r\n',
    );
    _hexPowerOnCmd = _loadString('hexPowerOnCmd', '01 05 00 00 FF 00');
    _hexPowerOffCmd = _loadString('hexPowerOffCmd', '01 05 00 00 00 00');
    _hexMatrixSwitchCmd = _loadString(
      'hexMatrixSwitchCmd',
      '02 03 {input02X} {output02X} FF',
    );
    _hexBigScreenLayoutCmd = _loadString(
      'hexBigScreenLayoutCmd',
      '03 01 {layout02X} FF',
    );
    _cameraSpeedLow = _loadInt('cameraSpeedLow', 1);
    _cameraSpeedHigh = _loadInt('cameraSpeedHigh', 15);
    _cameraPresetCount = _loadInt('cameraPresetCount', 8);
    _gridItemsPerPage = _loadInt('gridItemsPerPage', 16);
    _gridRowCount = _loadInt('gridRowCount', 2);
    _gridBtnHeightFactor = _loadDouble('gridBtnHeightFactor', 0.80);
    _gridSpacing4Cross = _loadDouble('gridSpacing4Cross', 10.0);
    _gridSpacing4Main = _loadDouble('gridSpacing4Main', 8.0);
    _gridSpacing8Cross = _loadDouble('gridSpacing8Cross', 6.0);
    _gridSpacing8Main = _loadDouble('gridSpacing8Main', 6.0);
    _gridHorizontalPadding = _loadDouble('gridHorizontalPadding', 24.0);
    _gridVerticalPadding = _loadDouble('gridVerticalPadding', 16.0);
    _longPressDurationMs = _loadInt('longPressDurationMs', 2000);
    _longPressTickIntervalMs = _loadInt('longPressTickIntervalMs', 50);
    _channelNameMaxLength = _loadInt('channelNameMaxLength', 10);
    debugPrint('[DeviceConfig] 所有配置加载完成');
  }

  /// 重置所有配置为默认值
  void resetAll() {
    _powerDeviceIp = '192.168.0.64';
    _powerDevicePort = 5000;
    _matrixDeviceIp = '192.168.0.64';
    _matrixDevicePort = 5000;
    _bigScreenDeviceIp = '192.168.0.64';
    _bigScreenDevicePort = 5000;
    _matrixBrand = '默认品牌';
    _bigScreenBrand = '默认品牌';
    _powerBrand = '默认品牌';
    _cameraDevices = [
      {'ip': '192.168.0.64', 'port': 52381, 'viscaAddr': 1},
      {'ip': '192.168.0.65', 'port': 52381, 'viscaAddr': 1},
      {'ip': '192.168.0.66', 'port': 52381, 'viscaAddr': 1},
      {'ip': '192.168.0.67', 'port': 52381, 'viscaAddr': 1},
      {'ip': '192.168.0.68', 'port': 52381, 'viscaAddr': 1},
    ];
    _showPowerControl = true;
    _showBigScreen = true;
    _showVideoMatrix = true;
    _showCameraControl = true;
    _showBigScreenFull = true;
    _showBigScreenFull169 = true;
    _showBigScreenSplit2 = true;
    _showBigScreenSplit3 = true;
    _showBigScreenSplit4 = true;
    _showBigScreenSplit5 = true;
    _connectionTimeoutSeconds = 5;
    _heartbeatIntervalSeconds = 60;
    _heartbeatTimeoutMultiplier = 3;
    _reconnectIntervalSeconds = 5;
    _useTcp = true;
    _powerUseTcp = true;
    _matrixUseTcp = true;
    _bigScreenUseTcp = true;
    _powerSendAsHex = false;
    _matrixSendAsHex = false;
    _bigScreenSendAsHex = false;
    _cameraSendAsHex = true;
    _matrixInputCount = 16;
    _matrixOutputCount = 16;
    _bigScreenOutputChannels = [4, 5, 6, 7, 8];
    _powerOnAsciiCmd = 'POWER_ON\r\n';
    _powerOffAsciiCmd = 'POWER_OFF\r\n';
    _matrixSwitchAsciiCmd = 'MATRIX:IN{input}->OUT{output}\r\n';
    _bigScreenLayoutAsciiCmd = 'LAYOUT:{layout}\r\n';
    _hexPowerOnCmd = '01 05 00 00 FF 00';
    _hexPowerOffCmd = '01 05 00 00 00 00';
    _hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';
    _hexBigScreenLayoutCmd = '03 01 {layout02X} FF';
    _cameraSpeedLow = 1;
    _cameraSpeedHigh = 15;
    _cameraPresetCount = 8;
    _gridItemsPerPage = 16;
    _gridRowCount = 2;
    _gridBtnHeightFactor = 0.80;
    _gridSpacing4Cross = 10.0;
    _gridSpacing4Main = 8.0;
    _gridSpacing8Cross = 6.0;
    _gridSpacing8Main = 6.0;
    _gridHorizontalPadding = 24.0;
    _gridVerticalPadding = 16.0;
    _longPressDurationMs = 2000;
    _longPressTickIntervalMs = 50;
    _channelNameMaxLength = 10;
    _prefs?.clear();
    notifyListeners();
    debugPrint('[DeviceConfig] 所有配置已重置为默认值');
  }

  /// 持久化存储辅助方法
  String _loadString(String key, String defaultValue) =>
      _prefs?.getString('$_keyPrefix$key') ?? defaultValue;
  int _loadInt(String key, int defaultValue) =>
      _prefs?.getInt('$_keyPrefix$key') ?? defaultValue;
  bool _loadBool(String key, bool defaultValue) =>
      _prefs?.getBool('$_keyPrefix$key') ?? defaultValue;
  double _loadDouble(String key, double defaultValue) =>
      _prefs?.getDouble('$_keyPrefix$key') ?? defaultValue;

  void _saveString(String key, String value) =>
      _prefs?.setString('$_keyPrefix$key', value);
  void _saveInt(String key, int value) =>
      _prefs?.setInt('$_keyPrefix$key', value);
  void _saveBool(String key, bool value) =>
      _prefs?.setBool('$_keyPrefix$key', value);
  void _saveDouble(String key, double value) =>
      _prefs?.setDouble('$_keyPrefix$key', value);

  /// 摄像头列表序列化/反序列化
  void _saveCameraDevices() {
    final List<String> encoded = _cameraDevices.map((dev) {
      return '${dev['ip']},${dev['port']},${dev['viscaAddr']}';
    }).toList();
    _prefs?.setStringList('${_keyPrefix}cameraDevices', encoded);
  }

  void _loadCameraDevices() {
    final List<String>? encoded = _prefs?.getStringList(
      '${_keyPrefix}cameraDevices',
    );
    if (encoded != null && encoded.isNotEmpty) {
      _cameraDevices = encoded.map((str) {
        final parts = str.split(',');
        return {
          'ip': parts.isNotEmpty ? parts[0] : '192.168.0.64',
          'port': parts.length > 1 ? int.tryParse(parts[1]) ?? 52381 : 52381,
          'viscaAddr': parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1,
        };
      }).toList();
    }
  }

  /// 大屏输出通道序列化/反序列化
  void _saveBigScreenOutputChannels() {
    _prefs?.setStringList(
      '${_keyPrefix}bigScreenOutputChannels',
      _bigScreenOutputChannels.map((e) => '$e').toList(),
    );
  }

  void _loadBigScreenOutputChannels() {
    final List<String>? encoded = _prefs?.getStringList(
      '${_keyPrefix}bigScreenOutputChannels',
    );
    if (encoded != null && encoded.isNotEmpty) {
      _bigScreenOutputChannels = encoded
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e > 0)
          .toList();
    }
  }
}
