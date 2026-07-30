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
/// 【开发者可调区】全局默认参数（唯一数据源 / Single Source of Truth）
/// ============================================================
/// 本类集中存放所有"默认值"。下方三处均引用此处常量，杜绝同一数值
/// 在「字段初始化 / _loadAllConfig 加载 / resetAll 重置」三处重复出现而漂移：
///   1) 各配置字段的初始化值（如  `int _x = ConfigDefaults.x;`）
///   2) _loadAllConfig 中的回退默认值（如 `_loadInt('x', ConfigDefaults.x)`）
///   3) resetAll 中的重置值（如 `_x = ConfigDefaults.x;`）
/// 开发者调整默认 IP / 端口 / Join 号 / 指令 / 开关时，只需改本类对应常量。
/// （品牌相关默认值由各 *BrandConfigs 列表管理，见 DeviceConfig 内。）
/// ============================================================
class ConfigDefaults {
  // ---- 网络 / 设备 ----
  static const String deviceIp = '192.168.0.64'; // 直连设备默认 IP（网关/设备地址）
  static const int devicePort = 5000; // 直连设备默认 TCP 端口（品牌可覆盖）
  static const int viscaPort = 52381; // 摄像头 VISCA over IP 端口
  static const int cipPort = 41794; // Crestron 明文 CIP 端口
  static const int cipIpId = 0x0A; // Crestron IP-ID（0x00-0xFF）

  // ---- 默认品牌（与上方 *BrandConfigs 列表首项保持一致）----
  static const String brandDefault = '默认品牌';
  static const String ledPowerBrandDefault = '利亚德';

  // ---- Crestron Join 默认映射（crestronMode 开启时生效）----
  static const int joinPowerOn = 21;
  static const int joinPowerOff = 22;
  static const int joinLedPowerOn = 23;
  static const int joinLedPowerOff = 24;
  static const int joinLayoutFull = 552; // 全屏
  static const int joinLayoutFull169 = 553; // 全屏16:9
  static const int joinLayoutSplit2 = 554; // 二分屏
  static const int joinLayoutSplit3 = 555; // 三分屏
  static const int joinLayoutSplit4 = 556; // 四分屏
  static const int joinLayoutSplit5 = 557; // 五分屏
  static const int joinMatrixInputBase = 50; // 输入 X → base + X 脉冲
  static const int joinMatrixOutputBase = 130; // 输出 Y → base + Y 脉冲
  static const int joinCamUp = 524; // 云台 上
  static const int joinCamDown = 525; // 云台 下
  static const int joinCamLeft = 526; // 云台 左
  static const int joinCamRight = 527; // 云台 右
  static const int joinCamTele = 528; // 变焦 推近
  static const int joinCamWide = 529; // 变焦 拉远
  static const int joinCamPresetRecallBase = 530; // 预置位 N → base + N
  static const int joinCamSpeedLow = 521; // 速度 低速
  static const int joinCamSpeedHigh = 522; // 速度 高速
  static const int joinCamSaveBtn = 523; // 预置位保存按钮
  static const int joinCamSelectBase = 510; // 摄像机 X → base + X 脉冲

  // ---- 页面 / 区块显示开关（true=显示）----
  static const bool showPowerControl = true;
  static const bool showBigScreen = true;
  static const bool showVideoMatrix = true;
  static const bool showCameraControl = true;
  static const bool showCrestronControl = true;
  static const bool showTimingPowerControl = true; // 电源页：时序电源区块
  static const bool showLedPowerControl = true; // 电源页：大屏电源区块（PLC）
  static const bool showBigScreenFull = true;
  static const bool showBigScreenFull169 = true;
  static const bool showBigScreenSplit2 = true;
  static const bool showBigScreenSplit3 = true;
  static const bool showBigScreenSplit4 = true;
  static const bool showBigScreenSplit5 = true;
  static const bool crestronMode = false; // Crestron VTP 双模式总开关

  // ---- Crestron 连接凭据 ----
  static const bool cipSecure = false;
  static const String cipUsername = '';
  static const String cipPassword = '';

  // ---- 网络连接通用参数 ----
  static const int connectionTimeoutSeconds = 5;
  static const int heartbeatIntervalSeconds = 60;
  static const int heartbeatTimeoutMultiplier = 2;
  static const int reconnectIntervalSeconds = 3;

  // ---- 设备协议开关（协议/发送模式）----
  static const bool powerUseTcp = true;
  static const bool matrixUseTcp = true;
  static const bool bigScreenUseTcp = true;
  static const bool ledPowerUseTcp = true;
  static const bool powerSendAsHex = false;
  static const bool matrixSendAsHex = false;
  static const bool bigScreenSendAsHex = false;
  static const bool ledPowerSendAsHex = false;
  static const bool cameraSendAsHex = true; // VISCA 固定 16 进制，勿改

  // ---- 视频矩阵通道数量 ----
  static const int matrixInputCount = 16;
  static const int matrixOutputCount = 16;

  // ---- 大屏分屏输出通道映射（1-based，按分屏区域顺序）----
  static const List<int> bigScreenOutputChannels = [4, 5, 6, 7, 8];

  // ---- ASCII 指令模板（sendAsHex=false 时生效）----
  static const String powerOnAsciiCmd = 'POWER_ON\r\n';
  static const String powerOffAsciiCmd = 'POWER_OFF\r\n';
  static const String matrixSwitchAsciiCmd =
      'MATRIX:IN{input}->OUT{output}\r\n';
  static const String bigScreenLayoutAsciiCmd = 'LAYOUT:{layout}\r\n';

  // ---- 16 进制指令模板（sendAsHex=true 时生效）----
  static const String hexPowerOnCmd = '01 05 00 00 FF 00';
  static const String hexPowerOffCmd = '01 05 00 00 00 00';
  static const String hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';
  static const String hexBigScreenLayoutCmd = '03 01 {layout02X} FF';

  // ---- 大屏电箱 PLC 开关指令（Modbus ASCII，参考 LED_Leyard_PWR.usp）----
  static const String ledPowerOnAsciiCmd = ':001000B0000100013E\r\n'; // 开
  static const String ledPowerOffAsciiCmd = ':001000B0000100023D\r\n'; // 关
  static const String hexLedPowerOnCmd = '';
  static const String hexLedPowerOffCmd = '';

  // ---- 摄像头参数 ----
  static const int cameraSpeedLow = 1;
  static const int cameraSpeedHigh = 15;
  static const int cameraPresetCount = 8;

  // ---- 摄像头设备默认列表（IP / 端口 / VISCA 地址）----
  /// 列表长度即摄像头数量；选中时仅连接对应设备，其余断开
  static const List<Map<String, dynamic>> cameraDevices = [
    {'ip': deviceIp, 'port': viscaPort, 'viscaAddr': 1},
    {'ip': '192.168.0.65', 'port': viscaPort, 'viscaAddr': 1},
    {'ip': '192.168.0.66', 'port': viscaPort, 'viscaAddr': 1},
    {'ip': '192.168.0.67', 'port': viscaPort, 'viscaAddr': 1},
    {'ip': '192.168.0.68', 'port': viscaPort, 'viscaAddr': 1},
  ];

  // ---- 按钮网格布局 ----
  static const int gridItemsPerPage = 16;
  static const int gridRowCount = 2;
  static const double gridBtnHeightFactor = 0.80;
  static const double gridSpacing4Cross = 10.0;
  static const double gridSpacing4Main = 8.0;
  static const double gridSpacing8Cross = 6.0;
  static const double gridSpacing8Main = 6.0;
  static const double gridHorizontalPadding = 24.0;
  static const double gridVerticalPadding = 16.0;

  // ---- 按钮交互 ----
  static const int longPressDurationMs = 2000;
  static const int longPressTickIntervalMs = 50;
  static const int channelNameMaxLength = 10;
}

/// ============================================================
/// [开发者注意] 全局配置中心（动态版本）
/// ============================================================
/// 本文件是整个项目的【唯一参数配置中心】。
/// 所有设备参数、布局参数、UI主题、交互参数均集中于此。
///
/// 【开发者修改指南】：
///   1. 添加新品牌：在 DeviceConfig 内对应 *BrandConfigs 列表中添加 BrandConfig。
///   2. 调整默认 IP / 端口 / Join 号 / 指令 / 开关：只改上方 ConfigDefaults。
///   3. 调整 UI：修改底部"UI 主题"和"动画尺寸"常量。
///   4. 添加新页面开关：在 ConfigDefaults 与"页面显示开关"区域各加一项。
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
///
/// 【Crestron join 号默认映射总览】（crestronMode 开启时生效，数值见 ConfigDefaults）
///   电源          ：开 21 / 关 22
///   大屏电源(PLC) ：开 23 / 关 24
///   分屏布局      ：全屏 552 / 全屏16:9 553 / 2分 554 / 3分 555 / 4分 556 / 5分 557
///   矩阵          ：输入基址 50 / 输出基址 130（通道数见 matrixInputCount/OutputCount）
///   摄像机选择    ：基址 510（摄像机 X → 510 + X，脉冲触发）
///   摄像机云台    ：上 524 / 下 525 / 左 526 / 右 527
///   摄像机变焦    ：推近 528 / 拉远 529
///   摄像机预置位  ：调出基址 530（预置位 N → 530 + N）
///   摄像机速度    ：低速 521 / 高速 522 / 保存 523
///   说明          ：基址类 join 均为「基址 + 偏移」形式；分屏六个按钮各有独立 join（非基址）。
///   时序电源、矩阵、大屏、摄像头等"直连设备"字段仅在 crestronMode 关闭时启用。
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
      name: 'DIGBIRD小鸟',
      useTcp: false,
      port: 5000,
      sendAsHex: false,
      asciiCmd: '({input},{output},1,D,B)',
      hexCmd: '02 03 {input02X} {output02X} FF',
    ),
    // 品牌乐泰：TCP协议，端口6000，ASCII模式(乐泰原生网络控制不稳定，用网转串控制)
    const BrandConfig(
      name: 'LOHTEA乐泰16路',
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
    // 默认品牌：TCP协议，端口6000，ASCII模式
    const BrandConfig(
      name: 'Leyard利亚德拼接器',
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
  /// 大屏电箱 PLC（LED 电源）品牌配置列表
  /// ============================================================
  /// 【开发者提示】在此添加新的大屏电箱 PLC 品牌。
  /// 每个品牌的 sendAsHex 独立配置。
  ///
  /// 参考文件 LED_Leyard_PWR.usp（利亚德 LED 屏电源控制模块）：
  ///   通讯协议: Modbus ASCII over RS485（经网转串 TCP 网关透传）
  ///   串口参数: 波特率 9600, 1 停止位, 无奇偶校验
  ///   命令格式: :AA FC RR RR NN NN DD DD CC\r\n
  ///     AA=从站地址(00)  FC=功能码(10=写多寄存器)
  ///     RRRR=起始寄存器(00B0=176)  NNNN=寄存器数(0001)
  ///     DDDD=控制数据(0001=开, 0002=关)  CC=LRC 校验
  ///   开: :001000B0000100013E\r\n  (数据 0001)
  ///   关: :001000B0000100023D\r\n  (数据 0002)
  /// 因整条指令为固定 ASCII 帧，发送模式固定为 ASCII（sendAsHex=false），
  /// 故 BrandConfig.asciiCmd 仅承载"开"指令；"关"指令为独立固定字段
  /// （_ledPowerOffAsciiCmd，默认值取自 .usp），不随品牌切换而改变。
  static final List<BrandConfig> ledPowerBrandConfigs = [
    // 默认品牌：利亚德（Leyard）LED 屏电源，TCP 协议，端口 5000，ASCII 模式
    const BrandConfig(
      name: '利亚德',
      useTcp: true,
      port: 5000,
      sendAsHex: false,
      // 开指令：寄存器 00B0 写入 0001，LRC=3E
      asciiCmd: ':001000B0000100013E\r\n',
      // ASCII 模式下不使用 16 进制指令；此处保留空字符串
      hexCmd: '',
    ),
  ];

  /// ============================================================
  /// 当前选中的品牌配置（运行时动态修改）
  /// ============================================================

  /// 视频矩阵当前选中的品牌名称
  String _matrixBrand = ConfigDefaults.brandDefault;
  String get matrixBrand => _matrixBrand;
  void setMatrixBrand(String value) {
    _matrixBrand = value;
    _saveString('matrixBrand', value);
    _applyBrandConfig('matrix', value);
    notifyListeners();
  }

  /// 大屏拼接器当前选中的品牌名称
  String _bigScreenBrand = ConfigDefaults.brandDefault;
  String get bigScreenBrand => _bigScreenBrand;
  void setBigScreenBrand(String value) {
    _bigScreenBrand = value;
    _saveString('bigScreenBrand', value);
    _applyBrandConfig('bigScreen', value);
    notifyListeners();
  }

  /// 时序电源当前选中的品牌名称
  String _powerBrand = ConfigDefaults.brandDefault;
  String get powerBrand => _powerBrand;
  void setPowerBrand(String value) {
    _powerBrand = value;
    _saveString('powerBrand', value);
    _applyBrandConfig('power', value);
    notifyListeners();
  }

  /// 大屏电箱 PLC（LED 电源）当前选中的品牌名称
  /// 默认品牌为"利亚德"，参考 LED_Leyard_PWR.usp
  String _ledPowerBrand = ConfigDefaults.ledPowerBrandDefault;
  String get ledPowerBrand => _ledPowerBrand;
  void setLedPowerBrand(String value) {
    _ledPowerBrand = value;
    _saveString('ledPowerBrand', value);
    _applyBrandConfig('ledPower', value);
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
      case 'ledPower':
        // 查找匹配的品牌配置，找不到则使用列表第一个（利亚德）
        config = ledPowerBrandConfigs.firstWhere(
          (b) => b.name == brandName,
          orElse: () => ledPowerBrandConfigs[0],
        );
        _ledPowerUseTcp = config.useTcp;
        _ledPowerDevicePort = config.port;
        _ledPowerSendAsHex = config.sendAsHex;
        // BrandConfig 仅承载"开"指令；"关"指令为独立字段，不在此处覆盖
        _ledPowerOnAsciiCmd = config.asciiCmd;
        _hexLedPowerOnCmd = config.hexCmd;
        _saveBool('ledPowerUseTcp', config.useTcp);
        _saveInt('ledPowerDevicePort', config.port);
        _saveBool('ledPowerSendAsHex', config.sendAsHex);
        _saveString('ledPowerOnAsciiCmd', config.asciiCmd);
        _saveString('hexLedPowerOnCmd', config.hexCmd);
        break;
    }
  }

  /// 校验单个设备当前选中品牌是否有效
  /// 若 [current] 为 null 或不在 [configs] 列表中，回退到该列表首项（默认品牌）
  /// 防止 DropdownButton 因 value 不在 items 中而抛运行时异常
  void _validateBrand(
    String? current,
    List<BrandConfig> configs,
    void Function(String) apply,
  ) {
    if (current == null || !configs.any((b) => b.name == current)) {
      apply(configs[0].name);
    }
  }

  /// 验证品牌名称是否有效
  /// 遍历所有设备类型，调用 [_validateBrand] 把无效品牌重置为默认品牌
  void _validateBrandName() {
    _validateBrand(_matrixBrand, matrixBrandConfigs, (n) => _matrixBrand = n);
    _validateBrand(
      _bigScreenBrand,
      bigScreenBrandConfigs,
      (n) => _bigScreenBrand = n,
    );
    _validateBrand(_powerBrand, powerBrandConfigs, (n) => _powerBrand = n);
    _validateBrand(
      _ledPowerBrand,
      ledPowerBrandConfigs,
      (n) => _ledPowerBrand = n,
    );
  }

  /// ============================================================
  /// 一、时序电源设备配置
  /// ============================================================

  /// 时序电源设备的IP地址
  String _powerDeviceIp = ConfigDefaults.deviceIp;
  String get powerDeviceIp => _powerDeviceIp;
  void setPowerDeviceIp(String value) {
    _powerDeviceIp = value;
    _saveString('powerDeviceIp', value);
    notifyListeners();
  }

  /// 时序电源设备的TCP端口号
  int _powerDevicePort = ConfigDefaults.devicePort;
  int get powerDevicePort => _powerDevicePort;
  void setPowerDevicePort(int value) {
    _powerDevicePort = value;
    _saveInt('powerDevicePort', value);
    notifyListeners();
  }

  /// ============================================================
  /// 一-B、大屏电箱 PLC（LED 电源）设备配置
  /// ============================================================

  /// 大屏电箱 PLC 设备的 IP 地址（即 LED 屏电源箱内的 PLC 网转串网关地址）
  String _ledPowerDeviceIp = ConfigDefaults.deviceIp;
  String get ledPowerDeviceIp => _ledPowerDeviceIp;
  void setLedPowerDeviceIp(String value) {
    _ledPowerDeviceIp = value;
    _saveString('ledPowerDeviceIp', value);
    notifyListeners();
  }

  /// 大屏电箱 PLC 设备的 TCP 端口号
  int _ledPowerDevicePort = ConfigDefaults.devicePort;
  int get ledPowerDevicePort => _ledPowerDevicePort;
  void setLedPowerDevicePort(int value) {
    _ledPowerDevicePort = value;
    _saveInt('ledPowerDevicePort', value);
    notifyListeners();
  }

  /// ============================================================
  /// 二、视频矩阵设备配置
  /// ============================================================

  /// 视频矩阵设备的IP地址
  String _matrixDeviceIp = ConfigDefaults.deviceIp;
  String get matrixDeviceIp => _matrixDeviceIp;
  void setMatrixDeviceIp(String value) {
    _matrixDeviceIp = value;
    _saveString('matrixDeviceIp', value);
    notifyListeners();
  }

  /// 视频矩阵设备的TCP端口号
  int _matrixDevicePort = ConfigDefaults.devicePort;
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
  String _bigScreenDeviceIp = ConfigDefaults.deviceIp;
  String get bigScreenDeviceIp => _bigScreenDeviceIp;
  void setBigScreenDeviceIp(String value) {
    _bigScreenDeviceIp = value;
    _saveString('bigScreenDeviceIp', value);
    notifyListeners();
  }

  /// 大屏拼接器设备的TCP端口号
  int _bigScreenDevicePort = ConfigDefaults.devicePort;
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
  List<Map<String, dynamic>> _cameraDevices = ConfigDefaults.cameraDevices;
  List<Map<String, dynamic>> get cameraDevices => _cameraDevices;
  void setCameraDevices(List<Map<String, dynamic>> value) {
    _cameraDevices = value;
    _saveCameraDevices();
    notifyListeners();
  }

  /// ============================================================
  /// 四-B、Crestron 中控（CIP / SCIP）配置
  /// ============================================================
  /// 是否显示“Crestron 中控”页面
  bool _showCrestronControl = ConfigDefaults.showCrestronControl;
  bool get showCrestronControl => _showCrestronControl;
  void setShowCrestronControl(bool value) {
    _showCrestronControl = value;
    _saveBool('showCrestronControl', value);
    notifyListeners();
  }

  /// Crestron 处理器 IP 地址
  String _cipHost = ConfigDefaults.deviceIp;
  String get cipHost => _cipHost;
  void setCipHost(String value) {
    _cipHost = value;
    _saveString('cipHost', value);
    notifyListeners();
  }

  /// CIP 端口（明文 41794 / 安全 41796）
  int _cipPort = ConfigDefaults.cipPort;
  int get cipPort => _cipPort;
  void setCipPort(int value) {
    _cipPort = value;
    _saveInt('cipPort', value);
    notifyListeners();
  }

  /// IP-ID（Crestron 程序中 IP 表里配置的 ID，1 字节 0x00-0xFF）
  int _cipIpId = ConfigDefaults.cipIpId;
  int get cipIpId => _cipIpId;
  void setCipIpId(int value) {
    _cipIpId = value.clamp(0, 0xFF);
    _saveInt('cipIpId', _cipIpId);
    notifyListeners();
  }

  /// 是否使用安全 CIP（SCIP / 4 系列 TLS）
  bool _cipSecure = ConfigDefaults.cipSecure;
  bool get cipSecure => _cipSecure;
  void setCipSecure(bool value) {
    _cipSecure = value;
    _saveBool('cipSecure', value);
    notifyListeners();
  }

  /// 安全认证用户名（4 系列开启身份验证时填写）
  String _cipUsername = ConfigDefaults.cipUsername;
  String get cipUsername => _cipUsername;
  void setCipUsername(String value) {
    _cipUsername = value;
    _saveString('cipUsername', value);
    notifyListeners();
  }

  /// 安全认证密码（仅保存在本机 SharedPreferences，明文存储，注意安全）
  String _cipPassword = ConfigDefaults.cipPassword;
  String get cipPassword => _cipPassword;
  void setCipPassword(String value) {
    _cipPassword = value;
    _saveString('cipPassword', value);
    notifyListeners();
  }

  /// ============================================================
  /// 四-C、Crestron VTP 双模式（Button → Join）配置
  /// ============================================================
  /// 当 crestronMode=true 时，四个控制页的按钮不再走原有直连协议，
  /// 而是向 Crestron 处理器发送对应的 join（数字/模拟）。
  /// 每个动作对应一个可配置的 join 号，在调试配置页统一管理。
  ///
  /// 映射规则（与 Crestron VTP 一致）：
  ///   - 电源开/关           → 数字 join（脉冲 pulse）
  ///   - 大屏分屏模式(全屏/16:9/二分/三分/四分/五分) → 各自独立数字 join（脉冲）
  ///   - 矩阵 输入X 按下      → 数字 join = joinMatrixInputBase + X（脉冲）
  ///   - 矩阵 输出Y 按下      → 数字 join = joinMatrixOutputBase + Y（脉冲）
  ///     （具体路由切换逻辑由中控程序根据"最后按下的输入"完成，与真实 Crestron 面板一致）
  ///   - 云台 上/下/左/右      → 数字 join（按下 press / 抬起 release）
  ///   - 变焦 放大/缩小        → 数字 join（press / release）
  ///   - 预置位 N（调用/保存共用）→ 数字 join = 预置位基址 + N（脉冲）
  ///     保存与调用发同一个 join，中控根据"保存按钮"join 的待命状态区分语义
  ///   - 速度 低速/高速        → 数字 join（脉冲，两个独立按钮）
  ///   - 保存按钮              → 数字 join（脉冲，点击进入/退出保存待命时上报）
  ///   - 摄像机选择 X          → 数字 join = joinCamSelectBase + X（脉冲）
  /// ============================================================

  /// Crestron VTP 双模式总开关
  bool _crestronMode = ConfigDefaults.crestronMode;
  bool get crestronMode => _crestronMode;
  void setCrestronMode(bool value) {
    _crestronMode = value;
    _saveBool('crestronMode', value);
    notifyListeners();
  }

  // ---- 电源：数字 join ----
  int _joinPowerOn = ConfigDefaults.joinPowerOn;
  int get joinPowerOn => _joinPowerOn;
  void setJoinPowerOn(int value) {
    _joinPowerOn = value.clamp(1, 9999);
    _saveInt('joinPowerOn', _joinPowerOn);
    notifyListeners();
  }

  int _joinPowerOff = ConfigDefaults.joinPowerOff;
  int get joinPowerOff => _joinPowerOff;
  void setJoinPowerOff(int value) {
    _joinPowerOff = value.clamp(1, 9999);
    _saveInt('joinPowerOff', _joinPowerOff);
    notifyListeners();
  }

  // ---- 大屏分屏：每个模式一个独立的数字 join（不再使用基址）----
  int _joinLayoutFull = ConfigDefaults.joinLayoutFull; // 全屏
  int get joinLayoutFull => _joinLayoutFull;
  void setJoinLayoutFull(int value) {
    _joinLayoutFull = value.clamp(1, 9999);
    _saveInt('joinLayoutFull', _joinLayoutFull);
    notifyListeners();
  }

  int _joinLayoutFull169 = ConfigDefaults.joinLayoutFull169; // 全屏16:9
  int get joinLayoutFull169 => _joinLayoutFull169;
  void setJoinLayoutFull169(int value) {
    _joinLayoutFull169 = value.clamp(1, 9999);
    _saveInt('joinLayoutFull169', _joinLayoutFull169);
    notifyListeners();
  }

  int _joinLayoutSplit2 = ConfigDefaults.joinLayoutSplit2; // 二分屏
  int get joinLayoutSplit2 => _joinLayoutSplit2;
  void setJoinLayoutSplit2(int value) {
    _joinLayoutSplit2 = value.clamp(1, 9999);
    _saveInt('joinLayoutSplit2', _joinLayoutSplit2);
    notifyListeners();
  }

  int _joinLayoutSplit3 = ConfigDefaults.joinLayoutSplit3; // 三分屏
  int get joinLayoutSplit3 => _joinLayoutSplit3;
  void setJoinLayoutSplit3(int value) {
    _joinLayoutSplit3 = value.clamp(1, 9999);
    _saveInt('joinLayoutSplit3', _joinLayoutSplit3);
    notifyListeners();
  }

  int _joinLayoutSplit4 = ConfigDefaults.joinLayoutSplit4; // 四分屏
  int get joinLayoutSplit4 => _joinLayoutSplit4;
  void setJoinLayoutSplit4(int value) {
    _joinLayoutSplit4 = value.clamp(1, 9999);
    _saveInt('joinLayoutSplit4', _joinLayoutSplit4);
    notifyListeners();
  }

  int _joinLayoutSplit5 = ConfigDefaults.joinLayoutSplit5; // 五分屏
  int get joinLayoutSplit5 => _joinLayoutSplit5;
  void setJoinLayoutSplit5(int value) {
    _joinLayoutSplit5 = value.clamp(1, 9999);
    _saveInt('joinLayoutSplit5', _joinLayoutSplit5);
    notifyListeners();
  }

  // ---- 视频矩阵：数字 join 基址（输入 X → inputBase + X 脉冲）----
  int _joinMatrixInputBase = ConfigDefaults.joinMatrixInputBase;
  int get joinMatrixInputBase => _joinMatrixInputBase;
  void setJoinMatrixInputBase(int value) {
    _joinMatrixInputBase = value.clamp(1, 9999);
    _saveInt('joinMatrixInputBase', _joinMatrixInputBase);
    notifyListeners();
  }

  // ---- 视频矩阵：数字 join 基址（输出 Y → outputBase + Y 脉冲）----
  int _joinMatrixOutputBase = ConfigDefaults.joinMatrixOutputBase;
  int get joinMatrixOutputBase => _joinMatrixOutputBase;
  void setJoinMatrixOutputBase(int value) {
    _joinMatrixOutputBase = value.clamp(1, 9999);
    _saveInt('joinMatrixOutputBase', _joinMatrixOutputBase);
    notifyListeners();
  }

  // ---- 摄像头：数字 join（方向/变焦/停止）----
  int _joinCamUp = ConfigDefaults.joinCamUp;
  int get joinCamUp => _joinCamUp;
  void setJoinCamUp(int value) {
    _joinCamUp = value.clamp(1, 9999);
    _saveInt('joinCamUp', _joinCamUp);
    notifyListeners();
  }

  int _joinCamDown = ConfigDefaults.joinCamDown;
  int get joinCamDown => _joinCamDown;
  void setJoinCamDown(int value) {
    _joinCamDown = value.clamp(1, 9999);
    _saveInt('joinCamDown', _joinCamDown);
    notifyListeners();
  }

  int _joinCamLeft = ConfigDefaults.joinCamLeft;
  int get joinCamLeft => _joinCamLeft;
  void setJoinCamLeft(int value) {
    _joinCamLeft = value.clamp(1, 9999);
    _saveInt('joinCamLeft', _joinCamLeft);
    notifyListeners();
  }

  int _joinCamRight = ConfigDefaults.joinCamRight;
  int get joinCamRight => _joinCamRight;
  void setJoinCamRight(int value) {
    _joinCamRight = value.clamp(1, 9999);
    _saveInt('joinCamRight', _joinCamRight);
    notifyListeners();
  }

  int _joinCamTele = ConfigDefaults.joinCamTele;
  int get joinCamTele => _joinCamTele;
  void setJoinCamTele(int value) {
    _joinCamTele = value.clamp(1, 9999);
    _saveInt('joinCamTele', _joinCamTele);
    notifyListeners();
  }

  int _joinCamWide = ConfigDefaults.joinCamWide;
  int get joinCamWide => _joinCamWide;
  void setJoinCamWide(int value) {
    _joinCamWide = value.clamp(1, 9999);
    _saveInt('joinCamWide', _joinCamWide);
    notifyListeners();
  }

  int _joinCamPresetRecallBase = ConfigDefaults.joinCamPresetRecallBase;
  int get joinCamPresetRecallBase => _joinCamPresetRecallBase;
  void setJoinCamPresetRecallBase(int value) {
    _joinCamPresetRecallBase = value.clamp(1, 9999);
    _saveInt('joinCamPresetRecallBase', _joinCamPresetRecallBase);
    notifyListeners();
  }

  // ---- 摄像头速度：低速/高速 两个独立数字 join（脉冲）----
  int _joinCamSpeedLow = ConfigDefaults.joinCamSpeedLow;
  int get joinCamSpeedLow => _joinCamSpeedLow;
  void setJoinCamSpeedLow(int value) {
    _joinCamSpeedLow = value.clamp(1, 9999);
    _saveInt('joinCamSpeedLow', _joinCamSpeedLow);
    notifyListeners();
  }

  int _joinCamSpeedHigh = ConfigDefaults.joinCamSpeedHigh;
  int get joinCamSpeedHigh => _joinCamSpeedHigh;
  void setJoinCamSpeedHigh(int value) {
    _joinCamSpeedHigh = value.clamp(1, 9999);
    _saveInt('joinCamSpeedHigh', _joinCamSpeedHigh);
    notifyListeners();
  }

  // ---- 预置位保存按钮：数字 join（脉冲，进入/退出保存待命时上报）----
  int _joinCamSaveBtn = ConfigDefaults.joinCamSaveBtn;
  int get joinCamSaveBtn => _joinCamSaveBtn;
  void setJoinCamSaveBtn(int value) {
    _joinCamSaveBtn = value.clamp(1, 9999);
    _saveInt('joinCamSaveBtn', _joinCamSaveBtn);
    notifyListeners();
  }

  // ---- 摄像机选择：数字 join 基址（摄像机 X → base + X 脉冲）----
  int _joinCamSelectBase = ConfigDefaults.joinCamSelectBase;
  int get joinCamSelectBase => _joinCamSelectBase;
  void setJoinCamSelectBase(int value) {
    _joinCamSelectBase = value.clamp(1, 9999);
    _saveInt('joinCamSelectBase', _joinCamSelectBase);
    notifyListeners();
  }

  // ---- 大屏电箱 PLC（LED 电源）：数字 join（脉冲）----
  int _joinLedPowerOn = ConfigDefaults.joinLedPowerOn; // 大屏电源开
  int get joinLedPowerOn => _joinLedPowerOn;
  void setJoinLedPowerOn(int value) {
    _joinLedPowerOn = value.clamp(1, 9999);
    _saveInt('joinLedPowerOn', _joinLedPowerOn);
    notifyListeners();
  }

  int _joinLedPowerOff = ConfigDefaults.joinLedPowerOff; // 大屏电源关
  int get joinLedPowerOff => _joinLedPowerOff;
  void setJoinLedPowerOff(int value) {
    _joinLedPowerOff = value.clamp(1, 9999);
    _saveInt('joinLedPowerOff', _joinLedPowerOff);
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
  bool _showPowerControl = ConfigDefaults.showPowerControl;
  bool get showPowerControl => _showPowerControl;
  void setShowPowerControl(bool value) {
    _showPowerControl = value;
    _saveBool('showPowerControl', value);
    notifyListeners();
  }

  /// 是否显示"大屏控制"页面
  /// true: 显示大屏分屏控制页面，并在底部导航栏显示"大屏控制"按钮
  /// false: 完全隐藏大屏控制功能
  bool _showBigScreen = ConfigDefaults.showBigScreen;
  bool get showBigScreen => _showBigScreen;
  void setShowBigScreen(bool value) {
    _showBigScreen = value;
    _saveBool('showBigScreen', value);
    notifyListeners();
  }

  /// 是否显示"视频矩阵控制"页面
  /// true: 显示视频矩阵输入/输出切换页面，并在底部导航栏显示"视频矩阵"按钮
  /// false: 完全隐藏视频矩阵控制功能
  bool _showVideoMatrix = ConfigDefaults.showVideoMatrix;
  bool get showVideoMatrix => _showVideoMatrix;
  void setShowVideoMatrix(bool value) {
    _showVideoMatrix = value;
    _saveBool('showVideoMatrix', value);
    notifyListeners();
  }

  /// 是否显示"摄像头控制"页面
  /// true: 显示摄像头云台控制和预置位管理页面，并在底部导航栏显示"摄像头"按钮
  /// false: 完全隐藏摄像头控制功能
  bool _showCameraControl = ConfigDefaults.showCameraControl;
  bool get showCameraControl => _showCameraControl;
  void setShowCameraControl(bool value) {
    _showCameraControl = value;
    _saveBool('showCameraControl', value);
    notifyListeners();
  }

  /// ============================================================
  /// 五-B、电源控制页区块显示开关配置
  /// ============================================================
  /// 【开发者说明】：用于控制"电源控制页"内部两个控制区块的显隐。
  ///   - showTimingPowerControl: 时序电源控制区块（原有电源开/关）
  ///   - showLedPowerControl:    大屏电源控制区块（大屏电箱 PLC 开/关）
  ///   - true=显示该区块，false=隐藏该区块
  ///   - 两者相互独立，可单独或同时勾选（勾选哪个就显示哪个）
  bool _showTimingPowerControl = ConfigDefaults.showTimingPowerControl;
  bool get showTimingPowerControl => _showTimingPowerControl;
  void setShowTimingPowerControl(bool value) {
    _showTimingPowerControl = value;
    _saveBool('showTimingPowerControl', value);
    notifyListeners();
  }

  bool _showLedPowerControl = ConfigDefaults.showLedPowerControl;
  bool get showLedPowerControl => _showLedPowerControl;
  void setShowLedPowerControl(bool value) {
    _showLedPowerControl = value;
    _saveBool('showLedPowerControl', value);
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
  bool _showBigScreenFull = ConfigDefaults.showBigScreenFull;
  bool get showBigScreenFull => _showBigScreenFull;
  void setShowBigScreenFull(bool value) {
    _showBigScreenFull = value;
    _saveBool('showBigScreenFull', value);
    notifyListeners();
  }

  bool _showBigScreenFull169 = ConfigDefaults.showBigScreenFull169;
  bool get showBigScreenFull169 => _showBigScreenFull169;
  void setShowBigScreenFull169(bool value) {
    _showBigScreenFull169 = value;
    _saveBool('showBigScreenFull169', value);
    notifyListeners();
  }

  bool _showBigScreenSplit2 = ConfigDefaults.showBigScreenSplit2;
  bool get showBigScreenSplit2 => _showBigScreenSplit2;
  void setShowBigScreenSplit2(bool value) {
    _showBigScreenSplit2 = value;
    _saveBool('showBigScreenSplit2', value);
    notifyListeners();
  }

  bool _showBigScreenSplit3 = ConfigDefaults.showBigScreenSplit3;
  bool get showBigScreenSplit3 => _showBigScreenSplit3;
  void setShowBigScreenSplit3(bool value) {
    _showBigScreenSplit3 = value;
    _saveBool('showBigScreenSplit3', value);
    notifyListeners();
  }

  bool _showBigScreenSplit4 = ConfigDefaults.showBigScreenSplit4;
  bool get showBigScreenSplit4 => _showBigScreenSplit4;
  void setShowBigScreenSplit4(bool value) {
    _showBigScreenSplit4 = value;
    _saveBool('showBigScreenSplit4', value);
    notifyListeners();
  }

  bool _showBigScreenSplit5 = ConfigDefaults.showBigScreenSplit5;
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
  int _connectionTimeoutSeconds = ConfigDefaults.connectionTimeoutSeconds;
  int get connectionTimeoutSeconds => _connectionTimeoutSeconds;
  void setConnectionTimeoutSeconds(int value) {
    _connectionTimeoutSeconds = value;
    _saveInt('connectionTimeoutSeconds', value);
    notifyListeners();
  }

  /// 心跳包发送间隔（秒）
  int _heartbeatIntervalSeconds = ConfigDefaults.heartbeatIntervalSeconds;
  int get heartbeatIntervalSeconds => _heartbeatIntervalSeconds;
  void setHeartbeatIntervalSeconds(int value) {
    _heartbeatIntervalSeconds = value;
    _saveInt('heartbeatIntervalSeconds', value);
    notifyListeners();
  }

  /// 心跳超时判定倍数（CIP 已用更小值重写，此处为其它设备默认值）
  int _heartbeatTimeoutMultiplier = ConfigDefaults.heartbeatTimeoutMultiplier;
  int get heartbeatTimeoutMultiplier => _heartbeatTimeoutMultiplier;
  void setHeartbeatTimeoutMultiplier(int value) {
    _heartbeatTimeoutMultiplier = value;
    _saveInt('heartbeatTimeoutMultiplier', value);
    notifyListeners();
  }

  /// 自动重连间隔（秒），断线后按此周期尝试重连
  int _reconnectIntervalSeconds = ConfigDefaults.reconnectIntervalSeconds;
  int get reconnectIntervalSeconds => _reconnectIntervalSeconds;
  void setReconnectIntervalSeconds(int value) {
    _reconnectIntervalSeconds = value;
    _saveInt('reconnectIntervalSeconds', value);
    notifyListeners();
  }

  /// 时序电源设备 - true=TCP协议, false=UDP协议
  bool _powerUseTcp = ConfigDefaults.powerUseTcp;
  bool get powerUseTcp => _powerUseTcp;
  void setPowerUseTcp(bool value) {
    _powerUseTcp = value;
    _saveBool('powerUseTcp', value);
    notifyListeners();
  }

  /// 视频矩阵设备 - true=TCP协议, false=UDP协议
  bool _matrixUseTcp = ConfigDefaults.matrixUseTcp;
  bool get matrixUseTcp => _matrixUseTcp;
  void setMatrixUseTcp(bool value) {
    _matrixUseTcp = value;
    _saveBool('matrixUseTcp', value);
    notifyListeners();
  }

  /// 大屏拼接器设备 - true=TCP协议, false=UDP协议
  bool _bigScreenUseTcp = ConfigDefaults.bigScreenUseTcp;
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
  bool _powerSendAsHex = ConfigDefaults.powerSendAsHex;
  bool get powerSendAsHex => _powerSendAsHex;
  void setPowerSendAsHex(bool value) {
    _powerSendAsHex = value;
    _saveBool('powerSendAsHex', value);
    notifyListeners();
  }

  /// 视频矩阵设备 - false=ASCII模式, true=16进制模式
  bool _matrixSendAsHex = ConfigDefaults.matrixSendAsHex;
  bool get matrixSendAsHex => _matrixSendAsHex;
  void setMatrixSendAsHex(bool value) {
    _matrixSendAsHex = value;
    _saveBool('matrixSendAsHex', value);
    notifyListeners();
  }

  /// 大屏拼接器设备 - false=ASCII模式, true=16进制模式
  bool _bigScreenSendAsHex = ConfigDefaults.bigScreenSendAsHex;
  bool get bigScreenSendAsHex => _bigScreenSendAsHex;
  void setBigScreenSendAsHex(bool value) {
    _bigScreenSendAsHex = value;
    _saveBool('bigScreenSendAsHex', value);
    notifyListeners();
  }

  /// 大屏电箱 PLC 设备 - true=TCP协议, false=UDP协议
  bool _ledPowerUseTcp = ConfigDefaults.ledPowerUseTcp;
  bool get ledPowerUseTcp => _ledPowerUseTcp;
  void setLedPowerUseTcp(bool value) {
    _ledPowerUseTcp = value;
    _saveBool('ledPowerUseTcp', value);
    notifyListeners();
  }

  /// 大屏电箱 PLC 设备 - false=ASCII模式, true=16进制模式
  /// 参考 .usp：指令为固定 ASCII 帧，默认 ASCII 模式
  bool _ledPowerSendAsHex = ConfigDefaults.ledPowerSendAsHex;
  bool get ledPowerSendAsHex => _ledPowerSendAsHex;
  void setLedPowerSendAsHex(bool value) {
    _ledPowerSendAsHex = value;
    _saveBool('ledPowerSendAsHex', value);
    notifyListeners();
  }

  /// 摄像头设备 - VISCA协议必须使用16进制模式，请勿修改
  bool _cameraSendAsHex = ConfigDefaults.cameraSendAsHex;
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
  int _matrixInputCount = ConfigDefaults.matrixInputCount;
  int get matrixInputCount => _matrixInputCount;
  void setMatrixInputCount(int value) {
    _matrixInputCount = value;
    _saveInt('matrixInputCount', value);
    notifyListeners();
  }

  /// 视频矩阵输出通道数量
  int _matrixOutputCount = ConfigDefaults.matrixOutputCount;
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
  List<int> _bigScreenOutputChannels = ConfigDefaults.bigScreenOutputChannels;
  List<int> get bigScreenOutputChannels => _bigScreenOutputChannels;
  void setBigScreenOutputChannels(List<int> value) {
    _bigScreenOutputChannels = value;
    _saveBigScreenOutputChannels();
    notifyListeners();
  }

  /// 当前启用的分屏模式中，区域数量的最大值（1~5）。
  /// 用于配置页"分屏输出通道映射"决定显示几行（区域1~区域N）。
  /// 不同模式区域数：全屏/全屏16:9=1、二分=2、三分=3、四分=4、五分=5。
  int get bigScreenMaxAreaCount {
    int max = 1;
    if (_showBigScreenFull169) max = 1;
    if (_showBigScreenSplit2) max = 2;
    if (_showBigScreenSplit3) max = 3;
    if (_showBigScreenSplit4) max = 4;
    if (_showBigScreenSplit5) max = 5;
    return max;
  }

  /// ============================================================
  /// 十一、ASCII 指令模板配置（仅 sendAsHex=false 时生效）
  /// ============================================================

  String _powerOnAsciiCmd = ConfigDefaults.powerOnAsciiCmd;
  String get powerOnAsciiCmd => _powerOnAsciiCmd;
  void setPowerOnAsciiCmd(String value) {
    _powerOnAsciiCmd = value;
    _saveString('powerOnAsciiCmd', value);
    notifyListeners();
  }

  String _powerOffAsciiCmd = ConfigDefaults.powerOffAsciiCmd;
  String get powerOffAsciiCmd => _powerOffAsciiCmd;
  void setPowerOffAsciiCmd(String value) {
    _powerOffAsciiCmd = value;
    _saveString('powerOffAsciiCmd', value);
    notifyListeners();
  }

  String _matrixSwitchAsciiCmd = ConfigDefaults.matrixSwitchAsciiCmd;
  String get matrixSwitchAsciiCmd => _matrixSwitchAsciiCmd;
  void setMatrixSwitchAsciiCmd(String value) {
    _matrixSwitchAsciiCmd = value;
    _saveString('matrixSwitchAsciiCmd', value);
    notifyListeners();
  }

  String _bigScreenLayoutAsciiCmd = ConfigDefaults.bigScreenLayoutAsciiCmd;
  String get bigScreenLayoutAsciiCmd => _bigScreenLayoutAsciiCmd;
  void setBigScreenLayoutAsciiCmd(String value) {
    _bigScreenLayoutAsciiCmd = value;
    _saveString('bigScreenLayoutAsciiCmd', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十二、16进制指令模板配置（仅 sendAsHex=true 时生效）
  /// ============================================================

  String _hexPowerOnCmd = ConfigDefaults.hexPowerOnCmd;
  String get hexPowerOnCmd => _hexPowerOnCmd;
  void setHexPowerOnCmd(String value) {
    _hexPowerOnCmd = value;
    _saveString('hexPowerOnCmd', value);
    notifyListeners();
  }

  String _hexPowerOffCmd = ConfigDefaults.hexPowerOffCmd;
  String get hexPowerOffCmd => _hexPowerOffCmd;
  void setHexPowerOffCmd(String value) {
    _hexPowerOffCmd = value;
    _saveString('hexPowerOffCmd', value);
    notifyListeners();
  }

  String _hexMatrixSwitchCmd = ConfigDefaults.hexMatrixSwitchCmd;
  String get hexMatrixSwitchCmd => _hexMatrixSwitchCmd;
  void setHexMatrixSwitchCmd(String value) {
    _hexMatrixSwitchCmd = value;
    _saveString('hexMatrixSwitchCmd', value);
    notifyListeners();
  }

  String _hexBigScreenLayoutCmd = ConfigDefaults.hexBigScreenLayoutCmd;
  String get hexBigScreenLayoutCmd => _hexBigScreenLayoutCmd;
  void setHexBigScreenLayoutCmd(String value) {
    _hexBigScreenLayoutCmd = value;
    _saveString('hexBigScreenLayoutCmd', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十二-B、大屏电箱 PLC 开关指令配置
  /// ============================================================
  /// 指令格式参考 LED_Leyard_PWR.usp（Modbus ASCII）：
  ///   开：:001000B0000100013E\r\n  （寄存器 00B0 写入 0001，LRC=3E）
  ///   关：:001000B0000100023D\r\n  （寄存器 00B0 写入 0002，LRC=3D）

  /// 大屏电源开指令（ASCII 模式）
  String _ledPowerOnAsciiCmd = ConfigDefaults.ledPowerOnAsciiCmd;
  String get ledPowerOnAsciiCmd => _ledPowerOnAsciiCmd;
  void setLedPowerOnAsciiCmd(String value) {
    _ledPowerOnAsciiCmd = value;
    _saveString('ledPowerOnAsciiCmd', value);
    notifyListeners();
  }

  /// 大屏电源关指令（ASCII 模式）
  String _ledPowerOffAsciiCmd = ConfigDefaults.ledPowerOffAsciiCmd;
  String get ledPowerOffAsciiCmd => _ledPowerOffAsciiCmd;
  void setLedPowerOffAsciiCmd(String value) {
    _ledPowerOffAsciiCmd = value;
    _saveString('ledPowerOffAsciiCmd', value);
    notifyListeners();
  }

  /// 大屏电源开指令（16进制模式，默认未使用）
  String _hexLedPowerOnCmd = ConfigDefaults.hexLedPowerOnCmd;
  String get hexLedPowerOnCmd => _hexLedPowerOnCmd;
  void setHexLedPowerOnCmd(String value) {
    _hexLedPowerOnCmd = value;
    _saveString('hexLedPowerOnCmd', value);
    notifyListeners();
  }

  /// 大屏电源关指令（16进制模式，默认未使用）
  String _hexLedPowerOffCmd = ConfigDefaults.hexLedPowerOffCmd;
  String get hexLedPowerOffCmd => _hexLedPowerOffCmd;
  void setHexLedPowerOffCmd(String value) {
    _hexLedPowerOffCmd = value;
    _saveString('hexLedPowerOffCmd', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十三、摄像头参数配置
  /// ============================================================

  int get cameraCount => _cameraDevices.length;

  int _cameraSpeedLow = ConfigDefaults.cameraSpeedLow;
  int get cameraSpeedLow => _cameraSpeedLow;
  void setCameraSpeedLow(int value) {
    _cameraSpeedLow = value;
    _saveInt('cameraSpeedLow', value);
    notifyListeners();
  }

  int _cameraSpeedHigh = ConfigDefaults.cameraSpeedHigh;
  int get cameraSpeedHigh => _cameraSpeedHigh;
  void setCameraSpeedHigh(int value) {
    _cameraSpeedHigh = value;
    _saveInt('cameraSpeedHigh', value);
    notifyListeners();
  }

  int _cameraPresetCount = ConfigDefaults.cameraPresetCount;
  int get cameraPresetCount => _cameraPresetCount;
  void setCameraPresetCount(int value) {
    // 限制范围：最少 1 个，最多 16 个预置位
    _cameraPresetCount = value.clamp(1, 16);
    _saveInt('cameraPresetCount', _cameraPresetCount);
    notifyListeners();
  }

  /// ============================================================
  /// 十四、按钮网格布局配置
  /// ============================================================

  int _gridItemsPerPage = ConfigDefaults.gridItemsPerPage;
  int get gridItemsPerPage => _gridItemsPerPage;
  void setGridItemsPerPage(int value) {
    _gridItemsPerPage = value;
    _saveInt('gridItemsPerPage', value);
    notifyListeners();
  }

  int _gridRowCount = ConfigDefaults.gridRowCount;
  int get gridRowCount => _gridRowCount;
  void setGridRowCount(int value) {
    _gridRowCount = value;
    _saveInt('gridRowCount', value);
    notifyListeners();
  }

  double _gridBtnHeightFactor = ConfigDefaults.gridBtnHeightFactor;
  double get gridBtnHeightFactor => _gridBtnHeightFactor;
  void setGridBtnHeightFactor(double value) {
    _gridBtnHeightFactor = value;
    _saveDouble('gridBtnHeightFactor', value);
    notifyListeners();
  }

  double _gridSpacing4Cross = ConfigDefaults.gridSpacing4Cross;
  double get gridSpacing4Cross => _gridSpacing4Cross;
  void setGridSpacing4Cross(double value) {
    _gridSpacing4Cross = value;
    _saveDouble('gridSpacing4Cross', value);
    notifyListeners();
  }

  double _gridSpacing4Main = ConfigDefaults.gridSpacing4Main;
  double get gridSpacing4Main => _gridSpacing4Main;
  void setGridSpacing4Main(double value) {
    _gridSpacing4Main = value;
    _saveDouble('gridSpacing4Main', value);
    notifyListeners();
  }

  double _gridSpacing8Cross = ConfigDefaults.gridSpacing8Cross;
  double get gridSpacing8Cross => _gridSpacing8Cross;
  void setGridSpacing8Cross(double value) {
    _gridSpacing8Cross = value;
    _saveDouble('gridSpacing8Cross', value);
    notifyListeners();
  }

  double _gridSpacing8Main = ConfigDefaults.gridSpacing8Main;
  double get gridSpacing8Main => _gridSpacing8Main;
  void setGridSpacing8Main(double value) {
    _gridSpacing8Main = value;
    _saveDouble('gridSpacing8Main', value);
    notifyListeners();
  }

  double _gridHorizontalPadding = ConfigDefaults.gridHorizontalPadding;
  double get gridHorizontalPadding => _gridHorizontalPadding;
  void setGridHorizontalPadding(double value) {
    _gridHorizontalPadding = value;
    _saveDouble('gridHorizontalPadding', value);
    notifyListeners();
  }

  double _gridVerticalPadding = ConfigDefaults.gridVerticalPadding;
  double get gridVerticalPadding => _gridVerticalPadding;
  void setGridVerticalPadding(double value) {
    _gridVerticalPadding = value;
    _saveDouble('gridVerticalPadding', value);
    notifyListeners();
  }

  /// ============================================================
  /// 十五、按钮交互配置
  /// ============================================================

  int _longPressDurationMs = ConfigDefaults.longPressDurationMs;
  int get longPressDurationMs => _longPressDurationMs;
  void setLongPressDurationMs(int value) {
    _longPressDurationMs = value;
    _saveInt('longPressDurationMs', value);
    notifyListeners();
  }

  int _longPressTickIntervalMs = ConfigDefaults.longPressTickIntervalMs;
  int get longPressTickIntervalMs => _longPressTickIntervalMs;
  void setLongPressTickIntervalMs(int value) {
    _longPressTickIntervalMs = value;
    _saveInt('longPressTickIntervalMs', value);
    notifyListeners();
  }

  int _channelNameMaxLength = ConfigDefaults.channelNameMaxLength;
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
  static const double buttonFontSizeRatio = 0.25;
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
    _powerDeviceIp = _loadString('powerDeviceIp', ConfigDefaults.deviceIp);
    _powerDevicePort = _loadInt('powerDevicePort', ConfigDefaults.devicePort);
    _ledPowerDeviceIp = _loadString(
      'ledPowerDeviceIp',
      ConfigDefaults.deviceIp,
    );
    _ledPowerDevicePort = _loadInt(
      'ledPowerDevicePort',
      ConfigDefaults.devicePort,
    );
    _matrixDeviceIp = _loadString('matrixDeviceIp', ConfigDefaults.deviceIp);
    _matrixDevicePort = _loadInt('matrixDevicePort', ConfigDefaults.devicePort);
    _bigScreenDeviceIp = _loadString(
      'bigScreenDeviceIp',
      ConfigDefaults.deviceIp,
    );
    _bigScreenDevicePort = _loadInt(
      'bigScreenDevicePort',
      ConfigDefaults.devicePort,
    );
    _matrixBrand = _loadString('matrixBrand', ConfigDefaults.brandDefault);
    _bigScreenBrand = _loadString(
      'bigScreenBrand',
      ConfigDefaults.brandDefault,
    );
    _powerBrand = _loadString('powerBrand', ConfigDefaults.brandDefault);
    _ledPowerBrand = _loadString(
      'ledPowerBrand',
      ConfigDefaults.ledPowerBrandDefault,
    );
    // 验证品牌名称是否有效，无效则重置为默认品牌（不覆盖用户手动修改的其他参数）
    _validateBrandName();
    _loadCameraDevices();
    _showPowerControl = _loadBool(
      'showPowerControl',
      ConfigDefaults.showPowerControl,
    );
    _showBigScreen = _loadBool('showBigScreen', ConfigDefaults.showBigScreen);
    _showVideoMatrix = _loadBool(
      'showVideoMatrix',
      ConfigDefaults.showVideoMatrix,
    );
    _showCameraControl = _loadBool(
      'showCameraControl',
      ConfigDefaults.showCameraControl,
    );
    _showCrestronControl = _loadBool(
      'showCrestronControl',
      ConfigDefaults.showCrestronControl,
    );
    _showTimingPowerControl = _loadBool(
      'showTimingPowerControl',
      ConfigDefaults.showTimingPowerControl,
    );
    _showLedPowerControl = _loadBool(
      'showLedPowerControl',
      ConfigDefaults.showLedPowerControl,
    );
    _cipHost = _loadString('cipHost', ConfigDefaults.deviceIp);
    _cipPort = _loadInt('cipPort', ConfigDefaults.cipPort);
    _cipIpId = _loadInt('cipIpId', ConfigDefaults.cipIpId);
    _cipSecure = _loadBool('cipSecure', ConfigDefaults.cipSecure);
    _cipUsername = _loadString('cipUsername', ConfigDefaults.cipUsername);
    _cipPassword = _loadString('cipPassword', ConfigDefaults.cipPassword);
    _crestronMode = _loadBool('crestronMode', ConfigDefaults.crestronMode);
    _joinPowerOn = _loadInt('joinPowerOn', ConfigDefaults.joinPowerOn);
    _joinPowerOff = _loadInt('joinPowerOff', ConfigDefaults.joinPowerOff);
    _joinLayoutFull = _loadInt('joinLayoutFull', ConfigDefaults.joinLayoutFull);
    _joinLayoutFull169 = _loadInt(
      'joinLayoutFull169',
      ConfigDefaults.joinLayoutFull169,
    );
    _joinLayoutSplit2 = _loadInt(
      'joinLayoutSplit2',
      ConfigDefaults.joinLayoutSplit2,
    );
    _joinLayoutSplit3 = _loadInt(
      'joinLayoutSplit3',
      ConfigDefaults.joinLayoutSplit3,
    );
    _joinLayoutSplit4 = _loadInt(
      'joinLayoutSplit4',
      ConfigDefaults.joinLayoutSplit4,
    );
    _joinLayoutSplit5 = _loadInt(
      'joinLayoutSplit5',
      ConfigDefaults.joinLayoutSplit5,
    );
    _joinMatrixInputBase = _loadInt(
      'joinMatrixInputBase',
      ConfigDefaults.joinMatrixInputBase,
    );
    _joinMatrixOutputBase = _loadInt(
      'joinMatrixOutputBase',
      ConfigDefaults.joinMatrixOutputBase,
    );
    _joinCamUp = _loadInt('joinCamUp', ConfigDefaults.joinCamUp);
    _joinCamDown = _loadInt('joinCamDown', ConfigDefaults.joinCamDown);
    _joinCamLeft = _loadInt('joinCamLeft', ConfigDefaults.joinCamLeft);
    _joinCamRight = _loadInt('joinCamRight', ConfigDefaults.joinCamRight);
    _joinCamTele = _loadInt('joinCamTele', ConfigDefaults.joinCamTele);
    _joinCamWide = _loadInt('joinCamWide', ConfigDefaults.joinCamWide);
    _joinCamPresetRecallBase = _loadInt(
      'joinCamPresetRecallBase',
      ConfigDefaults.joinCamPresetRecallBase,
    );
    _joinCamSpeedLow = _loadInt(
      'joinCamSpeedLow',
      ConfigDefaults.joinCamSpeedLow,
    );
    _joinCamSpeedHigh = _loadInt(
      'joinCamSpeedHigh',
      ConfigDefaults.joinCamSpeedHigh,
    );
    _joinCamSaveBtn = _loadInt('joinCamSaveBtn', ConfigDefaults.joinCamSaveBtn);
    _joinCamSelectBase = _loadInt(
      'joinCamSelectBase',
      ConfigDefaults.joinCamSelectBase,
    );
    _joinLedPowerOn = _loadInt('joinLedPowerOn', ConfigDefaults.joinLedPowerOn);
    _joinLedPowerOff = _loadInt(
      'joinLedPowerOff',
      ConfigDefaults.joinLedPowerOff,
    );
    _showBigScreenFull = _loadBool(
      'showBigScreenFull',
      ConfigDefaults.showBigScreenFull,
    );
    _showBigScreenFull169 = _loadBool(
      'showBigScreenFull169',
      ConfigDefaults.showBigScreenFull169,
    );
    _showBigScreenSplit2 = _loadBool(
      'showBigScreenSplit2',
      ConfigDefaults.showBigScreenSplit2,
    );
    _showBigScreenSplit3 = _loadBool(
      'showBigScreenSplit3',
      ConfigDefaults.showBigScreenSplit3,
    );
    _showBigScreenSplit4 = _loadBool(
      'showBigScreenSplit4',
      ConfigDefaults.showBigScreenSplit4,
    );
    _showBigScreenSplit5 = _loadBool(
      'showBigScreenSplit5',
      ConfigDefaults.showBigScreenSplit5,
    );
    _connectionTimeoutSeconds = _loadInt(
      'connectionTimeoutSeconds',
      ConfigDefaults.connectionTimeoutSeconds,
    );
    _heartbeatIntervalSeconds = _loadInt(
      'heartbeatIntervalSeconds',
      ConfigDefaults.heartbeatIntervalSeconds,
    );
    _heartbeatTimeoutMultiplier = _loadInt(
      'heartbeatTimeoutMultiplier',
      ConfigDefaults.heartbeatTimeoutMultiplier,
    );
    _reconnectIntervalSeconds = _loadInt(
      'reconnectIntervalSeconds',
      ConfigDefaults.reconnectIntervalSeconds,
    );
    _powerUseTcp = _loadBool('powerUseTcp', ConfigDefaults.powerUseTcp);
    _matrixUseTcp = _loadBool('matrixUseTcp', ConfigDefaults.matrixUseTcp);
    _bigScreenUseTcp = _loadBool(
      'bigScreenUseTcp',
      ConfigDefaults.bigScreenUseTcp,
    );
    _ledPowerUseTcp = _loadBool(
      'ledPowerUseTcp',
      ConfigDefaults.ledPowerUseTcp,
    );
    _powerSendAsHex = _loadBool(
      'powerSendAsHex',
      ConfigDefaults.powerSendAsHex,
    );
    _matrixSendAsHex = _loadBool(
      'matrixSendAsHex',
      ConfigDefaults.matrixSendAsHex,
    );
    _bigScreenSendAsHex = _loadBool(
      'bigScreenSendAsHex',
      ConfigDefaults.bigScreenSendAsHex,
    );
    _ledPowerSendAsHex = _loadBool(
      'ledPowerSendAsHex',
      ConfigDefaults.ledPowerSendAsHex,
    );
    _cameraSendAsHex = _loadBool(
      'cameraSendAsHex',
      ConfigDefaults.cameraSendAsHex,
    );
    _matrixInputCount = _loadInt(
      'matrixInputCount',
      ConfigDefaults.matrixInputCount,
    );
    _matrixOutputCount = _loadInt(
      'matrixOutputCount',
      ConfigDefaults.matrixOutputCount,
    );
    _loadBigScreenOutputChannels();
    _powerOnAsciiCmd = _loadString(
      'powerOnAsciiCmd',
      ConfigDefaults.powerOnAsciiCmd,
    );
    _powerOffAsciiCmd = _loadString(
      'powerOffAsciiCmd',
      ConfigDefaults.powerOffAsciiCmd,
    );
    _matrixSwitchAsciiCmd = _loadString(
      'matrixSwitchAsciiCmd',
      ConfigDefaults.matrixSwitchAsciiCmd,
    );
    _bigScreenLayoutAsciiCmd = _loadString(
      'bigScreenLayoutAsciiCmd',
      ConfigDefaults.bigScreenLayoutAsciiCmd,
    );
    _hexPowerOnCmd = _loadString('hexPowerOnCmd', ConfigDefaults.hexPowerOnCmd);
    _hexPowerOffCmd = _loadString(
      'hexPowerOffCmd',
      ConfigDefaults.hexPowerOffCmd,
    );
    _hexMatrixSwitchCmd = _loadString(
      'hexMatrixSwitchCmd',
      ConfigDefaults.hexMatrixSwitchCmd,
    );
    _hexBigScreenLayoutCmd = _loadString(
      'hexBigScreenLayoutCmd',
      ConfigDefaults.hexBigScreenLayoutCmd,
    );
    _ledPowerOnAsciiCmd = _loadString(
      'ledPowerOnAsciiCmd',
      ConfigDefaults.ledPowerOnAsciiCmd,
    );
    _ledPowerOffAsciiCmd = _loadString(
      'ledPowerOffAsciiCmd',
      ConfigDefaults.ledPowerOffAsciiCmd,
    );
    _hexLedPowerOnCmd = _loadString(
      'hexLedPowerOnCmd',
      ConfigDefaults.hexLedPowerOnCmd,
    );
    _hexLedPowerOffCmd = _loadString(
      'hexLedPowerOffCmd',
      ConfigDefaults.hexLedPowerOffCmd,
    );
    _cameraSpeedLow = _loadInt('cameraSpeedLow', ConfigDefaults.cameraSpeedLow);
    _cameraSpeedHigh = _loadInt(
      'cameraSpeedHigh',
      ConfigDefaults.cameraSpeedHigh,
    );
    _cameraPresetCount = _loadInt(
      'cameraPresetCount',
      ConfigDefaults.cameraPresetCount,
    );
    _gridItemsPerPage = _loadInt(
      'gridItemsPerPage',
      ConfigDefaults.gridItemsPerPage,
    );
    _gridRowCount = _loadInt('gridRowCount', ConfigDefaults.gridRowCount);
    _gridBtnHeightFactor = _loadDouble(
      'gridBtnHeightFactor',
      ConfigDefaults.gridBtnHeightFactor,
    );
    _gridSpacing4Cross = _loadDouble(
      'gridSpacing4Cross',
      ConfigDefaults.gridSpacing4Cross,
    );
    _gridSpacing4Main = _loadDouble(
      'gridSpacing4Main',
      ConfigDefaults.gridSpacing4Main,
    );
    _gridSpacing8Cross = _loadDouble(
      'gridSpacing8Cross',
      ConfigDefaults.gridSpacing8Cross,
    );
    _gridSpacing8Main = _loadDouble(
      'gridSpacing8Main',
      ConfigDefaults.gridSpacing8Main,
    );
    _gridHorizontalPadding = _loadDouble(
      'gridHorizontalPadding',
      ConfigDefaults.gridHorizontalPadding,
    );
    _gridVerticalPadding = _loadDouble(
      'gridVerticalPadding',
      ConfigDefaults.gridVerticalPadding,
    );
    _longPressDurationMs = _loadInt(
      'longPressDurationMs',
      ConfigDefaults.longPressDurationMs,
    );
    _longPressTickIntervalMs = _loadInt(
      'longPressTickIntervalMs',
      ConfigDefaults.longPressTickIntervalMs,
    );
    _channelNameMaxLength = _loadInt(
      'channelNameMaxLength',
      ConfigDefaults.channelNameMaxLength,
    );
    debugPrint('[DeviceConfig] 所有配置加载完成');
    // 关键：异步加载完成后必须通知监听者。
    // 主页面依赖此通知检测 crestronMode 等开关的持久化恢复
    // （否则重启 App 后 Crestron 模式已开启但全局 CIP 连接不会建立）。
    notifyListeners();
  }

  /// 重置所有配置为默认值
  void resetAll() {
    _powerDeviceIp = ConfigDefaults.deviceIp;
    _powerDevicePort = ConfigDefaults.devicePort;
    _ledPowerDeviceIp = ConfigDefaults.deviceIp;
    _ledPowerDevicePort = ConfigDefaults.devicePort;
    _matrixDeviceIp = ConfigDefaults.deviceIp;
    _matrixDevicePort = ConfigDefaults.devicePort;
    _bigScreenDeviceIp = ConfigDefaults.deviceIp;
    _bigScreenDevicePort = ConfigDefaults.devicePort;
    _matrixBrand = ConfigDefaults.brandDefault;
    _bigScreenBrand = ConfigDefaults.brandDefault;
    _powerBrand = ConfigDefaults.brandDefault;
    _ledPowerBrand = ConfigDefaults.ledPowerBrandDefault;
    _cameraDevices = ConfigDefaults.cameraDevices;
    _showPowerControl = ConfigDefaults.showPowerControl;
    _showBigScreen = ConfigDefaults.showBigScreen;
    _showVideoMatrix = ConfigDefaults.showVideoMatrix;
    _showCameraControl = ConfigDefaults.showCameraControl;
    _showCrestronControl = ConfigDefaults.showCrestronControl;
    _showTimingPowerControl = ConfigDefaults.showTimingPowerControl;
    _showLedPowerControl = ConfigDefaults.showLedPowerControl;
    _cipHost = ConfigDefaults.deviceIp;
    _cipPort = ConfigDefaults.cipPort;
    _cipIpId = ConfigDefaults.cipIpId;
    _cipSecure = ConfigDefaults.cipSecure;
    _cipUsername = ConfigDefaults.cipUsername;
    _cipPassword = ConfigDefaults.cipPassword;
    _crestronMode = ConfigDefaults.crestronMode;
    _joinPowerOn = ConfigDefaults.joinPowerOn;
    _joinPowerOff = ConfigDefaults.joinPowerOff;
    _joinLayoutFull = ConfigDefaults.joinLayoutFull;
    _joinLayoutFull169 = ConfigDefaults.joinLayoutFull169;
    _joinLayoutSplit2 = ConfigDefaults.joinLayoutSplit2;
    _joinLayoutSplit3 = ConfigDefaults.joinLayoutSplit3;
    _joinLayoutSplit4 = ConfigDefaults.joinLayoutSplit4;
    _joinLayoutSplit5 = ConfigDefaults.joinLayoutSplit5;
    _joinMatrixInputBase = ConfigDefaults.joinMatrixInputBase;
    _joinMatrixOutputBase = ConfigDefaults.joinMatrixOutputBase;
    _joinCamUp = ConfigDefaults.joinCamUp;
    _joinCamDown = ConfigDefaults.joinCamDown;
    _joinCamLeft = ConfigDefaults.joinCamLeft;
    _joinCamRight = ConfigDefaults.joinCamRight;
    _joinCamTele = ConfigDefaults.joinCamTele;
    _joinCamWide = ConfigDefaults.joinCamWide;
    _joinCamPresetRecallBase = ConfigDefaults.joinCamPresetRecallBase;
    _joinCamSpeedLow = ConfigDefaults.joinCamSpeedLow;
    _joinCamSpeedHigh = ConfigDefaults.joinCamSpeedHigh;
    _joinCamSaveBtn = ConfigDefaults.joinCamSaveBtn;
    _joinCamSelectBase = ConfigDefaults.joinCamSelectBase;
    _joinLedPowerOn = ConfigDefaults.joinLedPowerOn;
    _joinLedPowerOff = ConfigDefaults.joinLedPowerOff;
    _showBigScreenFull = ConfigDefaults.showBigScreenFull;
    _showBigScreenFull169 = ConfigDefaults.showBigScreenFull169;
    _showBigScreenSplit2 = ConfigDefaults.showBigScreenSplit2;
    _showBigScreenSplit3 = ConfigDefaults.showBigScreenSplit3;
    _showBigScreenSplit4 = ConfigDefaults.showBigScreenSplit4;
    _showBigScreenSplit5 = ConfigDefaults.showBigScreenSplit5;
    _connectionTimeoutSeconds = ConfigDefaults.connectionTimeoutSeconds;
    _heartbeatIntervalSeconds = ConfigDefaults.heartbeatIntervalSeconds;
    _heartbeatTimeoutMultiplier = ConfigDefaults.heartbeatTimeoutMultiplier;
    _reconnectIntervalSeconds = ConfigDefaults.reconnectIntervalSeconds;
    _powerUseTcp = ConfigDefaults.powerUseTcp;
    _matrixUseTcp = ConfigDefaults.matrixUseTcp;
    _bigScreenUseTcp = ConfigDefaults.bigScreenUseTcp;
    _ledPowerUseTcp = ConfigDefaults.ledPowerUseTcp;
    _powerSendAsHex = ConfigDefaults.powerSendAsHex;
    _matrixSendAsHex = ConfigDefaults.matrixSendAsHex;
    _bigScreenSendAsHex = ConfigDefaults.bigScreenSendAsHex;
    _ledPowerSendAsHex = ConfigDefaults.ledPowerSendAsHex;
    _cameraSendAsHex = ConfigDefaults.cameraSendAsHex;
    _matrixInputCount = ConfigDefaults.matrixInputCount;
    _matrixOutputCount = ConfigDefaults.matrixOutputCount;
    _bigScreenOutputChannels = ConfigDefaults.bigScreenOutputChannels;
    _powerOnAsciiCmd = ConfigDefaults.powerOnAsciiCmd;
    _powerOffAsciiCmd = ConfigDefaults.powerOffAsciiCmd;
    _matrixSwitchAsciiCmd = ConfigDefaults.matrixSwitchAsciiCmd;
    _bigScreenLayoutAsciiCmd = ConfigDefaults.bigScreenLayoutAsciiCmd;
    _hexPowerOnCmd = ConfigDefaults.hexPowerOnCmd;
    _hexPowerOffCmd = ConfigDefaults.hexPowerOffCmd;
    _hexMatrixSwitchCmd = ConfigDefaults.hexMatrixSwitchCmd;
    _hexBigScreenLayoutCmd = ConfigDefaults.hexBigScreenLayoutCmd;
    _ledPowerOnAsciiCmd = ConfigDefaults.ledPowerOnAsciiCmd;
    _ledPowerOffAsciiCmd = ConfigDefaults.ledPowerOffAsciiCmd;
    _hexLedPowerOnCmd = ConfigDefaults.hexLedPowerOnCmd;
    _hexLedPowerOffCmd = ConfigDefaults.hexLedPowerOffCmd;
    _cameraSpeedLow = ConfigDefaults.cameraSpeedLow;
    _cameraSpeedHigh = ConfigDefaults.cameraSpeedHigh;
    _cameraPresetCount = ConfigDefaults.cameraPresetCount;
    _gridItemsPerPage = ConfigDefaults.gridItemsPerPage;
    _gridRowCount = ConfigDefaults.gridRowCount;
    _gridBtnHeightFactor = ConfigDefaults.gridBtnHeightFactor;
    _gridSpacing4Cross = ConfigDefaults.gridSpacing4Cross;
    _gridSpacing4Main = ConfigDefaults.gridSpacing4Main;
    _gridSpacing8Cross = ConfigDefaults.gridSpacing8Cross;
    _gridSpacing8Main = ConfigDefaults.gridSpacing8Main;
    _gridHorizontalPadding = ConfigDefaults.gridHorizontalPadding;
    _gridVerticalPadding = ConfigDefaults.gridVerticalPadding;
    _longPressDurationMs = ConfigDefaults.longPressDurationMs;
    _longPressTickIntervalMs = ConfigDefaults.longPressTickIntervalMs;
    _channelNameMaxLength = ConfigDefaults.channelNameMaxLength;
    _prefs?.clear();
    // 重置后把无效品牌默认值("默认品牌")纠正为各品牌列表首项；
    // 否则配置页 DropdownButton 会因 value 不在 items 中而抛运行时异常
    _validateBrandName();
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
          'ip': parts.isNotEmpty ? parts[0] : ConfigDefaults.deviceIp,
          'port': parts.length > 1
              ? int.tryParse(parts[1]) ?? ConfigDefaults.viscaPort
              : ConfigDefaults.viscaPort,
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
    final List<int> normalized = List.filled(5, 0);
    if (encoded != null && encoded.isNotEmpty) {
      final List<int> parsed = encoded
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      for (int i = 0; i < 5; i++) {
        final v = i < parsed.length ? parsed[i] : 0;
        normalized[i] = v > 0 ? v : (4 + i);
      }
    } else {
      for (int i = 0; i < 5; i++) {
        normalized[i] = 4 + i;
      }
    }
    _bigScreenOutputChannels = normalized;
  }
}
