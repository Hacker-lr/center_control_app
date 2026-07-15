import 'package:flutter/material.dart';
import '../services/device_connection.dart';
import '../services/device_config.dart';

/// ============================================================
/// 时序电源控制页面
/// 包含电源开/关两个核心控制按钮
/// 按钮按下时高亮显示，并向设备发送对应控制指令
/// ============================================================
class PowerControlPage extends StatefulWidget {
  const PowerControlPage({super.key});

  @override
  State<PowerControlPage> createState() => _PowerControlPageState();
}

class _PowerControlPageState extends State<PowerControlPage> {
  // ---------- 按钮高亮状态 ----------

  /// 电源开按钮是否处于高亮（激活）状态
  bool _isPowerOnActive = false;

  /// 电源关按钮是否处于高亮（激活）状态
  bool _isPowerOffActive = false;

  // ---------- 设备连接服务 ----------
  final DeviceConnection _deviceConnection = DeviceConnection();

  /// ============================================================
  /// 构建页面主体布局
  /// 采用居中垂直排列：页面标题 + 两个圆形控制按钮
  /// ============================================================
  @override
  Widget build(BuildContext context) {
    // 监听设备连接状态变化，及时刷新UI
    return ListenableBuilder(
      listenable: _deviceConnection,
      builder: (context, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ---- 页面副标题 ----
                Text(
                  '时序电源控制',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: 16),

                // ---- 连接状态指示器 ----
                _buildConnectionStatusIndicator(),

                const Spacer(flex: 1),

                // ---- 两个圆形控制按钮：电源开 / 电源关 ----
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 电源开按钮
                    _buildPowerButton(
                      label: '电源开',
                      icon: Icons.power_settings_new,
                      isActive: _isPowerOnActive,
                      activeColor: const Color(0xFF1B5E20), // 深绿色 - 沉稳不刺眼
                      onPressed: () => _handlePowerOn(),
                    ),

                    // 电源关按钮
                    _buildPowerButton(
                      label: '电源关',
                      icon: Icons.power_off,
                      isActive: _isPowerOffActive,
                      activeColor: const Color(0xFF8B0000), // 暗红色 - 沉稳警示
                      onPressed: () => _handlePowerOff(),
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // ---- 指令状态提示文字 ----
                _buildStatusText(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 构建连接状态指示器组件
  /// 显示当前与设备的连接状态（已连接/未连接/连接中）
  /// ============================================================
  Widget _buildConnectionStatusIndicator() {
    final status = _deviceConnection.status;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '设备已连接';
        statusColor = const Color(0xFF4CAF50); // 沉稳绿
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '正在连接设备...';
        statusColor = const Color(0xFFFFA726); // 沉稳橙
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '连接失败，自动重连中...';
        statusColor = const Color(0xFFE53935); // 沉稳红
        statusIcon = Icons.error_outline;
        break;
      case ConnectionStatus.disconnected:
        statusText = '设备未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 14,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 连接状态下显示心跳计数
          if (status == ConnectionStatus.connected) ...[
            const SizedBox(width: 12),
            Text(
              '心跳 #${_deviceConnection.heartbeatCount}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建单个电源控制按钮
  /// [label] 按钮文字标签
  /// [icon] 按钮图标
  /// [isActive] 是否处于激活高亮状态
  /// [activeColor] 激活状态下的颜色
  /// [onPressed] 点击回调
  /// ============================================================
  Widget _buildPowerButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    // 按钮直径
    const double buttonSize = 140.0;

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- 圆形按钮主体 ----
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 激活状态：填充颜色 + 外发光阴影；非激活：深色背景 + 边框
              color: isActive
                  ? activeColor.withAlpha(200)
                  : const Color(0xFF2A2A3E),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withAlpha(100),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
              border: isActive
                  ? Border.all(color: activeColor, width: 2)
                  : Border.all(
                      color: Colors.grey[700]!,
                      width: 1.5,
                    ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标
                  Icon(
                    icon,
                    size: 48,
                    color: isActive ? Colors.white : Colors.grey[500],
                  ),
                  const SizedBox(height: 8),
                  // 文字标签
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : Colors.grey[500],
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建指令状态提示文字
  /// 显示最后一次发送指令的结果
  /// ============================================================
  Widget _buildStatusText() {
    String tipText;
    if (_isPowerOnActive) {
      tipText = '电源已开启 — 指令已发送';
    } else if (_isPowerOffActive) {
      tipText = '电源已关闭 — 指令已发送';
    } else {
      tipText = '请点击按钮发送控制指令';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        tipText,
        key: ValueKey(tipText),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// ============================================================
  /// 处理"电源开"按钮点击
  /// 1. 设置按钮高亮状态（开：高亮，关：取消高亮）
  /// 2. 根据 [DeviceConfig.powerSendAsHex] 配置自动选择发送格式：
  ///    ASCII模式 → 发送 "POWER_ON\r\n"
  ///    16进制模式 → 发送 DeviceConfig.hexPowerOnCmd (默认 "01 05 00 00 FF 00")
  /// [开发者可修改] 指令内容：修改下方 command 的值
  /// ============================================================
  void _handlePowerOn() {
    setState(() {
      _isPowerOnActive = true;
      _isPowerOffActive = false;
    });

    // 根据配置选择ASCII指令或16进制指令
    // [开发者可修改] ASCII格式：修改 powerOnAsciiCmd 的值
    // [开发者可修改] 16进制格式：在 device_config.dart 中修改 hexPowerOnCmd 的值
    const String powerOnAsciiCmd = 'POWER_ON\r\n';
    final String command = DeviceConfig.powerSendAsHex
        ? DeviceConfig.hexPowerOnCmd
        : powerOnAsciiCmd;
    _deviceConnection.sendCommand(command);
  }

  /// ============================================================
  /// 处理"电源关"按钮点击
  /// 1. 设置按钮高亮状态（关：高亮，开：取消高亮）
  /// 2. 根据 [DeviceConfig.powerSendAsHex] 配置自动选择发送格式：
  ///    ASCII模式 → 发送 "POWER_OFF\r\n"
  ///    16进制模式 → 发送 DeviceConfig.hexPowerOffCmd (默认 "01 05 00 00 00 00")
  /// [开发者可修改] 指令内容：修改下方 command 的值
  /// ============================================================
  void _handlePowerOff() {
    setState(() {
      _isPowerOffActive = true;
      _isPowerOnActive = false;
    });

    // 根据配置选择ASCII指令或16进制指令
    // [开发者可修改] ASCII格式：修改 powerOffAsciiCmd 的值
    // [开发者可修改] 16进制格式：在 device_config.dart 中修改 hexPowerOffCmd 的值
    const String powerOffAsciiCmd = 'POWER_OFF\r\n';
    final String command = DeviceConfig.powerSendAsHex
        ? DeviceConfig.hexPowerOffCmd
        : powerOffAsciiCmd;
    _deviceConnection.sendCommand(command);
  }
}
