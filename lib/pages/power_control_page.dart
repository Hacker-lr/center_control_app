import 'package:flutter/material.dart';
import '../services/base_connection.dart';
import '../services/device_connection.dart';
import '../services/device_config.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 时序电源控制页面
/// 页面功能：提供电源开/关两个圆形控制按钮，点击后发送对应指令到时序电源设备
/// 布局结构：顶部连接状态指示器 → 中部电源控制卡片（包含开/关两个圆形按钮）→ 底部状态提示文字
/// 连接管理：通过 DeviceConnection 单例管理时序电源设备的 TCP 连接、心跳检测和自动重连
/// ============================================================
class PowerControlPage extends StatefulWidget {
  const PowerControlPage({super.key});

  @override
  State<PowerControlPage> createState() => _PowerControlPageState();
}

class _PowerControlPageState extends State<PowerControlPage> {
  /// 电源开按钮的激活状态标志
  /// true 表示该按钮被点击激活，会显示高亮效果
  bool _isPowerOnActive = false;

  /// 电源关按钮的激活状态标志
  /// true 表示该按钮被点击激活，会显示高亮效果
  bool _isPowerOffActive = false;

  /// 时序电源设备连接管理（单例）
  /// 负责与时序电源设备的 TCP 通信、连接状态管理、心跳检测和自动重连
  final DeviceConnection _deviceConnection = DeviceConnection();

  /// 设备配置实例
  /// 包含电源控制相关的配置项（指令格式、指令内容等）
  final DeviceConfig _config = DeviceConfig();

  /// 设备配置实例
  /// 包含电源控制相关的配置项（指令格式、指令内容等）
  final DeviceConfig _config = DeviceConfig();

  @override
  Widget build(BuildContext context) {
    // 使用 ListenableBuilder 监听设备连接状态变化，自动刷新 UI
    return ListenableBuilder(
      listenable: _deviceConnection,
      builder: (context, child) {
        // SafeArea：确保内容不被系统状态栏遮挡
        return SafeArea(
          // SizedBox.expand：占满整个屏幕可用空间
          child: SizedBox.expand(
            // Padding：页面整体内边距，使用响应式工具计算
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              // Column：垂直布局，从上到下依次排列各区域
              child: Column(
                children: [
                  // 顶部间距
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 12)),
                  // 连接状态指示器：显示设备连接状态（已连接/连接中/失败/未连接）
                  _buildConnectionStatusIndicator(),
                  // 顶部占位：将电源控制卡片推到页面中间位置
                  const Spacer(flex: 1),
                  // 电源控制卡片：包含开/关两个圆形按钮
                  _buildPowerControlsCard(),
                  // 底部占位：将状态提示文字推到页面底部上方
                  const Spacer(flex: 1),
                  // 状态提示文字：根据按钮点击状态动态显示操作反馈
                  _buildStatusText(),
                  // 底部间距
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 24)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 构建电源控制卡片
  /// 返回一个带标题和两个圆形按钮的卡片容器
  /// 卡片内包含"时序电源控制"标题和电源开/关两个圆形按钮
  /// ============================================================
  Widget _buildPowerControlsCard() {
    return Container(
      // 卡片内边距，使用响应式工具计算
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      // 卡片装饰：深色背景、圆角、边框
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      // 卡片内部垂直布局
      child: Column(
        children: [
          // 卡片标题："时序电源控制"
          Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.getSpacing(context, 12),
            ),
            child: Text(
              '时序电源控制',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 2.0,
              ),
            ),
          ),
          // 按钮行：水平排列电源开和电源关两个圆形按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 电源开按钮：绿色主题，点击发送电源开启指令
              _buildPowerButton(
                '电源开',
                Icons.power_settings_new,
                _isPowerOnActive,
                const Color(0xFF1B5E20),
                () => _handlePowerOn(),
              ),
              // 电源关按钮：红色主题，点击发送电源关闭指令
              _buildPowerButton(
                '电源关',
                Icons.power_off,
                _isPowerOffActive,
                const Color(0xFF8B0000),
                () => _handlePowerOff(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建连接状态指示器
  /// 根据设备连接状态显示不同的图标、文字和颜色
  /// 状态包括：已连接（绿色）、连接中（橙色）、连接失败（红色）、未连接（灰色）
  /// ============================================================
  Widget _buildConnectionStatusIndicator() {
    // 获取当前设备连接状态
    final status = _deviceConnection.status;
    String statusText;
    Color statusColor;
    IconData statusIcon;

    // 根据连接状态设置显示内容
    switch (status) {
      case ConnectionStatus.connected:
        statusText = '设备已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '正在连接设备...';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '连接失败，自动重连中...';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = '设备未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
    }

    // 返回状态指示器容器
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, 16),
        vertical: ResponsiveUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态图标
          Icon(statusIcon, color: statusColor, size: 16),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          // 状态文字
          Text(
            statusText,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 12),
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 已连接状态下显示心跳计数
          if (status == ConnectionStatus.connected) ...[
            SizedBox(width: ResponsiveUtils.getSpacing(context, 10)),
            Text(
              '心跳 #${_deviceConnection.heartbeatCount}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 11),
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建圆形电源控制按钮
  /// [label] 按钮文字（如"电源开"、"电源关"）
  /// [icon] 按钮图标
  /// [isActive] 是否激活状态（激活时显示高亮效果）
  /// [activeColor] 激活时的主题颜色
  /// [onPressed] 点击回调函数
  /// ============================================================
  Widget _buildPowerButton(
    String label,
    IconData icon,
    bool isActive,
    Color activeColor,
    VoidCallback onPressed,
  ) {
    // 获取响应式按钮尺寸
    final double buttonSize = ResponsiveUtils.getPowerButtonSize(context);
    // 图标大小为按钮尺寸的 30%
    final double iconSize = buttonSize * 0.3;
    // 获取响应式字体大小
    final double fontSize = ResponsiveUtils.getFontSize(context, 14);

    return GestureDetector(
      onTap: onPressed,
      // AnimatedContainer：按钮状态变化时带平滑过渡动画
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: buttonSize,
        height: buttonSize,
        // 圆形按钮装饰
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 激活时使用主题色，非激活时使用深色背景
          color: isActive
              ? activeColor.withAlpha(220)
              : const Color(0xFF1E2228),
          // 激活时显示发光效果，非激活时显示阴影效果
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(80),
                    blurRadius: buttonSize * 0.12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: buttonSize * 0.06,
                    offset: const Offset(0, 4),
                  ),
                ],
          // 激活时边框加粗并使用主题色
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFF3A3F48),
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Icon(
                icon,
                size: iconSize,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
              // 文字标签
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建底部状态提示文字
  /// 根据电源按钮的激活状态动态显示不同的提示信息
  /// 使用 AnimatedSwitcher 实现文字切换动画
  /// ============================================================
  Widget _buildStatusText() {
    // 根据按钮激活状态确定提示文字
    String tipText = '请点击按钮发送控制指令';
    if (_isPowerOnActive) {
      tipText = '电源已开启 — 指令已发送';
    } else if (_isPowerOffActive) {
      tipText = '电源已关闭 — 指令已发送';
    }

    // AnimatedSwitcher：文字切换时带淡入淡出动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        tipText,
        // key 必须不同才能触发动画
        key: ValueKey(tipText),
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(context, 12),
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// ============================================================
  /// 处理电源开按钮点击事件
  /// 1. 更新按钮状态：开启开按钮，关闭关按钮
  /// 2. 根据配置选择指令格式（ASCII 或 16进制）
  /// 3. 发送电源开启指令到设备
  /// ============================================================
  void _handlePowerOn() {
    // 更新按钮激活状态
    setState(() {
      _isPowerOnActive = true;
      _isPowerOffActive = false;
    });
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOnCmd
        : _config.powerOnAsciiCmd;
    // 发送指令到设备
    // 更新按钮激活状态
    setState(() {
      _isPowerOnActive = true;
      _isPowerOffActive = false;
    });
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOnCmd
        : _config.powerOnAsciiCmd;
    // 发送指令到设备
    _deviceConnection.sendCommand(command);
  }

  /// ============================================================
  /// 处理电源关按钮点击事件
  /// 1. 更新按钮状态：开启关按钮，关闭开按钮
  /// 2. 根据配置选择指令格式（ASCII 或 16进制）
  /// 3. 发送电源关闭指令到设备
  /// ============================================================
  void _handlePowerOff() {
    // 更新按钮激活状态
    setState(() {
      _isPowerOffActive = true;
      _isPowerOnActive = false;
    });
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOffCmd
        : _config.powerOffAsciiCmd;
    // 发送指令到设备
    // 更新按钮激活状态
    setState(() {
      _isPowerOffActive = true;
      _isPowerOnActive = false;
    });
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOffCmd
        : _config.powerOffAsciiCmd;
    // 发送指令到设备
    _deviceConnection.sendCommand(command);
  }
}
