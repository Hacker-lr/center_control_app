import 'package:flutter/material.dart';
import '../services/base_connection.dart';
import '../services/device_connection.dart';
import '../services/device_config.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 时序电源控制页面
/// 包含电源开/关两个圆形控制按钮，点击发送对应指令
/// ============================================================
class PowerControlPage extends StatefulWidget {
  const PowerControlPage({super.key});

  @override
  State<PowerControlPage> createState() => _PowerControlPageState();
}

class _PowerControlPageState extends State<PowerControlPage> {
  bool _isPowerOnActive = false;
  bool _isPowerOffActive = false;
  final DeviceConnection _deviceConnection = DeviceConnection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _deviceConnection,
      builder: (context, child) {
        return SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 12)),
                  _buildConnectionStatusIndicator(),
                  const Spacer(flex: 1),
                  _buildPowerControlsCard(),
                  const Spacer(flex: 1),
                  _buildStatusText(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 24)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPowerControlsCard() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, 12)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPowerButton('电源开', Icons.power_settings_new, _isPowerOnActive, const Color(0xFF1B5E20), () => _handlePowerOn()),
              _buildPowerButton('电源关', Icons.power_off, _isPowerOffActive, const Color(0xFF8B0000), () => _handlePowerOff()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    final status = _deviceConnection.status;
    String statusText;
    Color statusColor;
    IconData statusIcon;

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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getSpacing(context, 16), vertical: ResponsiveUtils.getSpacing(context, 6)),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          Text(
            statusText,
            style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context, 12), color: statusColor, fontWeight: FontWeight.w500),
          ),
          if (status == ConnectionStatus.connected) ...[
            SizedBox(width: ResponsiveUtils.getSpacing(context, 10)),
            Text(
              '心跳 #${_deviceConnection.heartbeatCount}',
              style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context, 11), color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPowerButton(String label, IconData icon, bool isActive, Color activeColor, VoidCallback onPressed) {
    final double buttonSize = ResponsiveUtils.getPowerButtonSize(context);
    final double iconSize = buttonSize * 0.3;
    final double fontSize = ResponsiveUtils.getFontSize(context, 14);

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? activeColor.withAlpha(220) : const Color(0xFF1E2228),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withAlpha(80), blurRadius: buttonSize * 0.12, spreadRadius: 2)]
              : [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: buttonSize * 0.06, offset: const Offset(0, 4))],
          border: Border.all(color: isActive ? activeColor : const Color(0xFF3A3F48), width: isActive ? 2.5 : 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: isActive ? Colors.white : Colors.grey[500]),
              SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
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

  Widget _buildStatusText() {
    String tipText = '请点击按钮发送控制指令';
    if (_isPowerOnActive) {
      tipText = '电源已开启 — 指令已发送';
    } else if (_isPowerOffActive) {
      tipText = '电源已关闭 — 指令已发送';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        tipText,
        key: ValueKey(tipText),
        style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context, 12), color: Colors.grey[500], letterSpacing: 1.0),
      ),
    );
  }

  void _handlePowerOn() {
    setState(() { _isPowerOnActive = true; _isPowerOffActive = false; });
    final String command = DeviceConfig.powerSendAsHex ? DeviceConfig.hexPowerOnCmd : DeviceConfig.powerOnAsciiCmd;
    _deviceConnection.sendCommand(command);
  }

  void _handlePowerOff() {
    setState(() { _isPowerOffActive = true; _isPowerOnActive = false; });
    final String command = DeviceConfig.powerSendAsHex ? DeviceConfig.hexPowerOffCmd : DeviceConfig.powerOffAsciiCmd;
    _deviceConnection.sendCommand(command);
  }
}
