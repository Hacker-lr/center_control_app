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

  // ==================== 页面显示开关配置 ====================

  /// [开发者修改处] 是否显示"时序电源控制"页面及其底部导航按钮
  /// true  = 显示电源控制页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏电源控制页面，底部菜单栏不显示按钮，不可跳转
  /// 后续新增页面均按此模式添加对应的布尔开关
  static const bool showPowerControl = true;

  /// [开发者修改处] 是否显示"视频矩阵控制"页面及其底部导航按钮
  /// true  = 显示视频矩阵页面，底部菜单栏显示对应按钮，可跳转
  /// false = 隐藏视频矩阵页面，底部菜单栏不显示按钮，不可跳转
  static const bool showVideoMatrix = false;

  // [开发者扩展处] 新增设备页面时在此添加布尔开关
  // 示例:
  // static const bool showAudioControl = true;

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

  // ==================== 视频矩阵通道配置 ====================

  /// [开发者修改处] 视频矩阵输入通道数量
  /// 可根据实际矩阵规模调整
  static const int matrixInputCount = 8;

  /// [开发者修改处] 视频矩阵输出通道数量
  /// 可根据实际矩阵规模调整
  static const int matrixOutputCount = 8;

  // ==================== 16进制指令示例 ====================
  // 以下为16进制模式下的指令模板，供开发者参考和修改
  // 时序电源指令仅当 powerSendAsHex = true 时生效
  // 视频矩阵指令仅当 matrixSendAsHex = true 时生效

  /// [开发者可修改] 电源开 - 16进制指令
  /// 示例: "01 01 00 00 00 01" (前导码 + 命令码 + 参数 + 校验)
  static const String hexPowerOnCmd = '01 05 00 00 FF 00';

  /// [开发者可修改] 电源关 - 16进制指令
  /// 示例: "01 01 00 00 00 00" (前导码 + 命令码 + 参数 + 校验)
  static const String hexPowerOffCmd = '01 05 00 00 00 00';

  /// [开发者可修改] 视频矩阵切换 - 16进制指令模板
  /// 使用 {input} 和 {output} 占位符，运行时会替换为实际通道编号的16进制值
  /// 示例: "02 03 {input02X} {output02X} FF" → "02 03 01 03 FF" (输入1→输出3)
  static const String hexMatrixSwitchCmd = '02 03 {input02X} {output02X} FF';
}
