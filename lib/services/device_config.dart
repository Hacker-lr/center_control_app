import 'package:flutter/material.dart';

/// ============================================================
/// [开发者注意] 全局配置中心
/// 所有设备参数、布局参数、UI主题、交互参数均集中于此
/// 修改本文件即可适配不同设备环境或调整UI表现
/// ============================================================

class DeviceConfig {
  // ============================================================
  // 一、时序电源设备配置
  // ============================================================

  /// [开发者修改处] 时序电源设备的IP地址
  static const String powerDeviceIp = '192.168.0.64';

  /// [开发者修改处] 时序电源设备的TCP端口号
  static const int powerDevicePort = 5000;

  // ============================================================
  // 二、视频矩阵设备配置
  // ============================================================

  /// [开发者修改处] 视频矩阵设备的IP地址
  static const String matrixDeviceIp = '192.168.0.64';

  /// [开发者修改处] 视频矩阵设备的TCP端口号
  static const int matrixDevicePort = 5000;

  // ============================================================
  // 三、大屏拼接器设备配置
  // ============================================================

  /// [开发者修改处] 大屏拼接器设备的IP地址
  static const String bigScreenDeviceIp = '192.168.0.64';

  /// [开发者修改处] 大屏拼接器设备的TCP端口号
  static const int bigScreenDevicePort = 5000;

  // ============================================================
  // 四、摄像头设备配置
  // ============================================================

  /// [开发者修改处] 摄像头设备列表配置
  /// 每个摄像头独立配置IP和端口，选中时仅连接对应设备，其余断开
  /// ip: 摄像头VISCA over IP网关地址
  /// port: VISCA over IP端口（默认52381）
  /// viscaAddr: VISCA协议中的摄像机地址（1-7，指令中会加上0x80偏移）
  /// 列表长度即为摄像头数量，无需单独配置 cameraCount
  static const List<Map<String, dynamic>> cameraDevices = [
    {'ip': '192.168.0.64', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.65', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.66', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.67', 'port': 52381, 'viscaAddr': 1},
    {'ip': '192.168.0.68', 'port': 52381, 'viscaAddr': 1},
  ];

  // ============================================================
  // 五、页面显示开关配置
  // ============================================================

  /// [开发者修改处] 是否显示"时序电源控制"页面及其底部导航按钮
  static const bool showPowerControl = true;

  /// [开发者修改处] 是否显示"大屏控制"页面及其底部导航按钮
  static const bool showBigScreen = true;

  /// [开发者修改处] 是否显示"视频矩阵控制"页面及其底部导航按钮
  static const bool showVideoMatrix = true;

  /// [开发者修改处] 是否显示"摄像头控制"页面及其底部导航按钮
  static const bool showCameraControl = true;

  // ============================================================
  // 六、大屏分屏按钮显示开关配置
  // ============================================================

  static const bool showBigScreenFull = true;
  static const bool showBigScreenFull169 = true;
  static const bool showBigScreenSplit2 = true;
  static const bool showBigScreenSplit3 = true;
  static const bool showBigScreenSplit4 = true;
  static const bool showBigScreenSplit5 = true;

  // ============================================================
  // 七、网络连接通用配置
  // ============================================================

  /// [开发者修改处] 连接超时时间（秒）
  static const int connectionTimeoutSeconds = 5;

  /// [开发者修改处] 心跳包发送间隔（秒）
  static const int heartbeatIntervalSeconds = 60;

  /// [开发者修改处] 心跳超时判定倍数
  /// 当超过 heartbeatIntervalSeconds * heartbeatTimeoutMultiplier 秒未收到响应时判定超时
  static const int heartbeatTimeoutMultiplier = 3;

  /// [开发者修改处] 自动重连间隔（秒）
  static const int reconnectIntervalSeconds = 5;

  /// [开发者修改处] 通信协议类型：true = TCP, false = UDP
  static const bool useTcp = true;

  // ============================================================
  // 八、指令发送模式配置（每种设备独立控制）
  // ============================================================

  /// [开发者修改处] 时序电源设备 - false=ASCII模式, true=16进制模式
  static const bool powerSendAsHex = false;

  /// [开发者修改处] 视频矩阵设备 - false=ASCII模式, true=16进制模式
  static const bool matrixSendAsHex = false;

  /// [开发者修改处] 大屏拼接器设备 - false=ASCII模式, true=16进制模式
  static const bool bigScreenSendAsHex = false;

  /// [开发者修改处] 摄像头设备 - VISCA协议必须使用16进制模式，请勿修改
  static const bool cameraSendAsHex = true;

  // ============================================================
  // 九、视频矩阵通道配置
  // ============================================================

  /// [开发者修改处] 视频矩阵输入通道数量
  static const int matrixInputCount = 16;

  /// [开发者修改处] 视频矩阵输出通道数量
  static const int matrixOutputCount = 16;

  // ============================================================
  // 十、大屏分屏输出通道映射
  // ============================================================

  /// [开发者修改处] 大屏分屏区域对应的矩阵输出通道（1-based，按分屏区域顺序）
  /// 索引对应：0=分屏区域1, 1=分屏区域2, ...
  static const List<int> bigScreenOutputChannels = [4, 5, 6, 7, 8];

  // ============================================================
  // 十一、ASCII 指令模板配置（仅 sendAsHex=false 时生效）
  // ============================================================

  static const String powerOnAsciiCmd = 'POWER_ON\r\n';
  static const String powerOffAsciiCmd = 'POWER_OFF\r\n';
  static const String matrixSwitchAsciiCmd = 'MATRIX:IN{input}->OUT{output}\r\n';
  static const String bigScreenLayoutAsciiCmd = 'LAYOUT:{layout}\r\n';

  // ============================================================
  // 十二、16进制指令模板配置（仅 sendAsHex=true 时生效）
  // ============================================================

  static const String hexPowerOnCmd = '01 05 00 00 FF 00';
  static const String hexPowerOffCmd = '01 05 00 00 00 00';
  static const String hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';
  static const String hexBigScreenLayoutCmd = '03 01 {layout02X} FF';

  // ============================================================
  // 十三、摄像头参数配置
  // ============================================================

  static const int cameraCount = 5;
  static const int cameraSpeedLow = 1;
  static const int cameraSpeedHigh = 15;
  static const int cameraPresetCount = 8;

  // ============================================================
  // 十四、按钮网格布局配置
  // ============================================================

  /// [开发者修改处] 多页模式下每页显示的按钮数量（2行×8列）
  static const int gridItemsPerPage = 16;

  /// [开发者修改处] 按钮网格固定显示行数
  static const int gridRowCount = 2;

  /// [开发者修改处] 按钮高度系数（<1.0 表示按钮高度不占满全部可用空间）
  static const double gridBtnHeightFactor = 0.80;

  /// [开发者修改处] 单页模式（≤8按钮/4列）的横向间距（cross axis）
  static const double gridSpacing4Cross = 10.0;

  /// [开发者修改处] 单页模式（≤8按钮/4列）的纵向间距（main axis）
  static const double gridSpacing4Main = 8.0;

  /// [开发者修改处] 多页模式（>8按钮/8列）的横向间距（cross axis）
  static const double gridSpacing8Cross = 6.0;

  /// [开发者修改处] 多页模式（>8按钮/8列）的纵向间距（main axis）
  static const double gridSpacing8Main = 6.0;

  /// [开发者修改处] 按钮网格整体水平内边距
  static const double gridHorizontalPadding = 24.0;

  /// [开发者修改处] 按钮网格整体垂直内边距
  static const double gridVerticalPadding = 16.0;

  // ============================================================
  // 十五、按钮交互配置
  // ============================================================

  /// [开发者修改处] 长按触发改名的时间（毫秒）
  static const int longPressDurationMs = 2000;

  /// [开发者修改处] 长按进度条更新间隔（毫秒）
  static const int longPressTickIntervalMs = 50;

  /// [开发者修改处] 通道名称最大长度
  static const int channelNameMaxLength = 10;

  // ============================================================
  // 十六、UI 主题颜色配置
  // ============================================================

  /// 分区卡片背景色
  static const Color colorCardBg = Color(0xFF0D1117);

  /// 分区卡片边框色
  static const Color colorCardBorder = Color(0xFF1E2228);

  /// 默认按钮背景色
  static const Color colorButtonBg = Color(0xFF2A2A3E);

  /// 按钮默认边框色
  static const Color colorButtonBorder = Color(0xFF3A3F48);

  /// 输入按钮选中高亮色
  static const Color colorHighlightInput = Color(0xFF1F4068);

  /// 输出按钮选中高亮色
  static const Color colorHighlightOutput = Color(0xFF3E6B48);

  /// 主题强调色（边框高亮、提示文字等）
  static const Color colorAccent = Color(0xFF6B9BD2);

  /// 长按按下时的边框色
  static const Color colorPressing = Color(0xFFFFA726);

  /// 连接状态-已连接
  static const Color colorStatusConnected = Color(0xFF4CAF50);

  /// 连接状态-连接中
  static const Color colorStatusConnecting = Color(0xFFFFA726);

  /// 连接状态-错误
  static const Color colorStatusError = Color(0xFFE53935);

  /// 连接状态-未连接
  static const Color colorStatusDisconnected = Color(0xFF9E9E9E);

  /// SnackBar 背景色
  static const Color colorSnackBarBg = Color(0xFF3A5A8C);

  /// 重命名对话框背景色
  static const Color colorDialogBg = Color(0xFF161B22);

  /// 重命名对话框输入框背景色
  static const Color colorDialogFieldBg = Color(0xFF21262D);

  /// 分屏预览区域默认背景色
  static const Color colorSplitAreaBg = Color(0xFF1E2228);

  /// 分屏预览区域默认边框色
  static const Color colorSplitAreaBorder = Color(0xFF2A3038);

  // ============================================================
  // 十七、UI 动画与尺寸配置
  // ============================================================

  /// [开发者修改处] 通用动画过渡时长（毫秒）
  static const int animationDurationMs = 250;

  /// [开发者修改处] 提示文字切换动画时长（毫秒）
  static const int hintAnimationDurationMs = 300;

  /// [开发者修改处] 按钮圆角比例（相对于按钮宽度）
  static const double buttonBorderRadiusRatio = 0.12;

  /// [开发者修改处] 按钮阴影模糊比例（高亮状态，相对于按钮宽度）
  static const double buttonShadowBlurRatio = 0.12;

  /// [开发者修改处] 按钮阴影模糊比例（普通状态，相对于按钮宽度）
  static const double buttonShadowBlurSmallRatio = 0.05;

  /// [开发者修改处] 按钮文字大小比例（相对于按钮高度）
  static const double buttonFontSizeRatio = 0.35;

  /// [开发者修改处] 按钮水平内边距比例（相对于按钮宽度）
  static const double buttonPaddingHorizontalRatio = 0.08;

  /// [开发者修改处] 按钮垂直内边距比例（相对于按钮高度）
  static const double buttonPaddingVerticalRatio = 0.10;

  /// [开发者修改处] 长按进度条高度（像素）
  static const double longPressIndicatorHeight = 3.0;

  /// [开发者修改处] 分区卡片圆角（像素）
  static const double cardBorderRadius = 10.0;

  /// [开发者修改处] 状态指示器圆角（像素）
  static const double statusChipBorderRadius = 12.0;

  /// [开发者修改处] 提示横幅圆角（像素）
  static const double bannerBorderRadius = 10.0;

  /// [开发者修改处] 分屏预览区域间距（像素）
  static const double splitAreaGap = 4.0;
}
