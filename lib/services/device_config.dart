// ignore_for_file: dangling_library_doc_comments
/// ============================================================
/// [开发者注意] 设备通信配置常量
/// 修改以下IP地址与端口号即可适配不同的设备环境
/// ============================================================

class DeviceConfig {
  // ==================== 时序电源设备配置 ====================

  /// [开发者修改处] 时序电源设备的IP地址
  /// 请根据实际设备IP进行修改
  static const String powerDeviceIp = '192.168.0.64';

  /// [开发者修改处] 时序电源设备的TCP端口号
  /// 请根据实际设备端口进行修改
  static const int powerDevicePort = 5000;

  // ==================== 视频矩阵设备配置 ====================

  /// [开发者修改处] 视频矩阵设备的IP地址
  /// 请根据实际设备IP进行修改
  static const String matrixDeviceIp = '192.168.0.64';

  /// [开发者修改处] 视频矩阵设备的TCP端口号
  /// 请根据实际设备端口进行修改
  static const int matrixDevicePort = 5000;

  // ==================== 大屏拼接器设备配置 ====================

  /// [开发者修改处] 大屏拼接器设备的IP地址
  /// 请根据实际设备IP进行修改
  static const String bigScreenDeviceIp = '192.168.0.64';

  /// [开发者修改处] 大屏拼接器设备的TCP端口号
  /// 请根据实际设备端口进行修改
  static const int bigScreenDevicePort = 5000;

  // ==================== 摄像头设备配置 ====================

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

  // ==================== 页面显示开关配置 ====================

  /// [开发者修改处] 是否显示"时序电源控制"页面及其底部导航按钮
  /// true  = 显示电源控制页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏电源控制页面，底部菜单栏不显示按钮，不可跳转
  /// 后续新增页面均按此模式添加对应的布尔开关
  static const bool showPowerControl = true;

  /// [开发者修改处] 是否显示"大屏控制"页面及其底部导航按钮
  /// true  = 显示大屏控制页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏大屏控制页面，底部菜单栏不显示按钮，不可跳转
  static const bool showBigScreen = true;

  /// [开发者修改处] 是否显示"视频矩阵控制"页面及其底部导航按钮
  /// true  = 显示视频矩阵页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏视频矩阵页面，底部菜单栏不显示按钮，不可跳转
  static const bool showVideoMatrix = true;

  /// [开发者修改处] 是否显示"摄像头控制"页面及其底部导航按钮
  /// true  = 显示摄像头控制页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏摄像头控制页面，底部菜单栏不显示按钮，不可跳转
  static const bool showCameraControl = true;

  // [开发者扩展处] 新增设备页面时在此添加布尔开关

  // ==================== 大屏分屏按钮显示开关配置 ====================

  /// [开发者修改处] 大屏页 - 是否显示"全屏"按钮
  static const bool showBigScreenFull = true;

  /// [开发者修改处] 大屏页 - 是否显示"全屏16:9"按钮
  static const bool showBigScreenFull169 = true;

  /// [开发者修改处] 大屏页 - 是否显示"二分屏"按钮
  static const bool showBigScreenSplit2 = true;

  /// [开发者修改处] 大屏页 - 是否显示"三分屏"按钮
  static const bool showBigScreenSplit3 = true;

  /// [开发者修改处] 大屏页 - 是否显示"四分屏"按钮
  static const bool showBigScreenSplit4 = true;

  /// [开发者修改处] 大屏页 - 是否显示"五分屏"按钮
  static const bool showBigScreenSplit5 = true;

  // ==================== 连接通用配置 ====================

  /// [开发者修改处] 心跳包发送间隔（秒）
  /// 默认60秒一次心跳，可根据需要调整
  static const int heartbeatIntervalSeconds = 60;

  /// [开发者修改处] 重连间隔（秒）
  /// 断连后每隔5秒尝试重连一次
  static const int reconnectIntervalSeconds = 5;

  /// [开发者修改处] 连接超时时间（秒）
  static const int connectionTimeoutSeconds = 5;

  /// [开发者修改处] 通信协议类型：true = TCP, false = UDP
  /// 根据实际设备支持的协议进行选择
  static const bool useTcp = true;

  // ==================== 指令发送模式配置（每种设备独立控制） ====================

  /// [开发者修改处] 时序电源设备 - 指令发送模式
  /// false = ASCII字符串模式：直接将指令字符串按字符编码发送
  ///         示例: "POWER_ON\r\n" → 发送 "POWER_ON\r\n" 的 ASCII 字节
  /// true  = 16进制模式：将指令解析为空格分隔的16进制字节发送
  ///         示例: "01 05 00 00 FF 00" → 发送 [0x01,0x05,0x00,0x00,0xFF,0x00]
  /// 根据实际设备支持的协议格式选择
  static const bool powerSendAsHex = false;

  /// [开发者修改处] 视频矩阵设备 - 指令发送模式
  /// false = ASCII字符串模式：直接将指令字符串按字符编码发送
  ///         示例: "MATRIX:IN3->OUT5\r\n" → 发送文本的 ASCII 字节
  /// true  = 16进制模式：将指令解析为空格分隔的16进制字节发送
  ///         示例: "02 03 01 03 FF" → 发送 [0x02,0x03,0x01,0x03,0xFF]
  /// 根据实际设备支持的协议格式选择
  static const bool matrixSendAsHex = false;

  /// [开发者修改处] 大屏拼接器设备 - 指令发送模式
  /// false = ASCII字符串模式：直接将指令字符串按字符编码发送
  /// true  = 16进制模式：将指令解析为空格分隔的16进制字节发送
  static const bool bigScreenSendAsHex = false;

  /// [开发者修改处] 摄像头设备 - 指令发送模式
  /// VISCA协议必须使用16进制模式，请勿修改
  /// true = 16进制模式：将指令解析为空格分隔的16进制字节发送
  static const bool cameraSendAsHex = true;

  // ==================== 视频矩阵通道配置 ====================

  /// [开发者修改处] 视频矩阵输入通道数量
  /// 可根据实际矩阵规模调整
  static const int matrixInputCount = 8;

  /// [开发者修改处] 视频矩阵输出通道数量
  /// 可根据实际矩阵规模调整
  static const int matrixOutputCount = 8;

  // ==================== 大屏分屏输出通道映射 ====================

  /// [开发者修改处] 大屏分屏区域对应的矩阵输出通道（1-based，按分屏区域顺序）
  /// 默认使用矩阵最后5个输出通道
  /// 索引对应：0=分屏区域1, 1=分屏区域2, 2=分屏区域3, 3=分屏区域4, 4=分屏区域5
  /// 全屏/全屏16:9使用 channels[0]（输出4）
  /// 二分屏使用 channels[0..1]（输出4, 5）
  /// 三分屏使用 channels[0..2]（输出4, 5, 6）
  /// 四分屏使用 channels[0..3]（输出4, 5, 6, 7）
  /// 五分屏使用 channels[0..4]（输出4, 5, 6, 7, 8）
  static const List<int> bigScreenOutputChannels = [4, 5, 6, 7, 8];

  // ==================== ASCII 指令配置 ====================
  // 仅当对应设备的 sendAsHex = false 时生效

  /// [开发者可修改] 电源开 - ASCII 指令
  static const String powerOnAsciiCmd = 'POWER_ON\r\n';

  /// [开发者可修改] 电源关 - ASCII 指令
  static const String powerOffAsciiCmd = 'POWER_OFF\r\n';

  /// [开发者可修改] 视频矩阵通道切换 - ASCII 指令模板
  /// 使用 {input} 和 {output} 占位符，运行时会替换为实际通道编号
  static const String matrixSwitchAsciiCmd = 'MATRIX:IN{input}->OUT{output}\r\n';

  /// [开发者可修改] 大屏分屏布局切换 - ASCII 指令模板
  /// 使用 {layout} 占位符，运行时会替换为分屏模式编号
  static const String bigScreenLayoutAsciiCmd = 'LAYOUT:{layout}\r\n';

  // ==================== 16进制指令配置 ====================
  // 仅当对应设备的 sendAsHex = true 时生效

  /// [开发者可修改] 电源开 - 16进制指令
  static const String hexPowerOnCmd = '01 05 00 00 FF 00';

  /// [开发者可修改] 电源关 - 16进制指令
  static const String hexPowerOffCmd = '01 05 00 00 00 00';

  /// [开发者可修改] 视频矩阵切换 - 16进制指令模板
  /// 使用 {input02X} 和 {output02X} 占位符
  static const String hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';

  /// [开发者可修改] 大屏拼接器分屏切换 - 16进制指令模板
  /// 使用 {layout02X} 占位符
  static const String hexBigScreenLayoutCmd = '03 01 {layout02X} FF';

  // ==================== 摄像头参数配置 ====================

  /// 摄像头数量（由 cameraDevices 列表长度决定，此处仅作备用参考）
  static const int cameraCount = 5;

  /// [开发者修改处] 摄像头云台低速（VISCA协议范围：01-18）
  static const int cameraSpeedLow = 1;

  /// [开发者修改处] 摄像头云台高速（VISCA协议范围：01-18）
  static const int cameraSpeedHigh = 15;

  /// [开发者修改处] 预置位数量（1-12）
  static const int cameraPresetCount = 8;
}
