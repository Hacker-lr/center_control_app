import 'package:flutter/material.dart';
import '../services/base_connection.dart';
import '../services/crestron_cip_connection.dart';
import '../services/device_config.dart';

/// ============================================================
/// Crestron 中控连接状态芯片（全局统一样式）
///
/// 在 Crestron VTP 模式下，所有设备控制页顶部的连接状态提示
/// 统一使用本组件，保证文案、颜色、字号、图标完全一致：
///   - 已连接：绿色 + 心跳计数
///   - 连接中：橙色
///   - 连接失败：红色（自动重连中）
///   - 未连接：灰色
///
/// 组件内部自行监听 CrestronCipConnection 单例，状态变化时自动刷新，
/// 页面无需额外把 CrestronCipConnection 加入自己的 ListenableBuilder。
/// ============================================================
class CrestronStatusChip extends StatelessWidget {
  const CrestronStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final CrestronCipConnection cip = CrestronCipConnection();
    return ListenableBuilder(
      listenable: cip,
      builder: (context, child) {
        final ConnectionStatus status = cip.status;
        String statusText;
        Color statusColor;
        IconData statusIcon;

        switch (status) {
          case ConnectionStatus.connected:
            statusText = 'Crestron 中控已连接';
            statusColor = DeviceConfig.colorStatusConnected;
            statusIcon = Icons.link;
            break;
          case ConnectionStatus.connecting:
            statusText = '正在连接 Crestron 中控...';
            statusColor = DeviceConfig.colorStatusConnecting;
            statusIcon = Icons.sync;
            break;
          case ConnectionStatus.error:
            statusText = 'Crestron 中控连接失败，自动重连中...';
            statusColor = DeviceConfig.colorStatusError;
            statusIcon = Icons.error_outline;
            break;
          case ConnectionStatus.disconnected:
            statusText = 'Crestron 中控未连接';
            statusColor = Colors.grey[500]!;
            statusIcon = Icons.link_off;
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(20),
            borderRadius: BorderRadius.circular(
              DeviceConfig.statusChipBorderRadius,
            ),
            border: Border.all(color: statusColor.withAlpha(60), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 14),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // 已连接时显示心跳计数
              if (status == ConnectionStatus.connected) ...[
                const SizedBox(width: 8),
                Text(
                  '心跳 #${cip.heartbeatCount}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
