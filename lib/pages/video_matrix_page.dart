import 'package:flutter/material.dart';
import '../services/matrix_connection.dart';
import '../services/device_config.dart';
import '../services/base_connection.dart';
import '../services/matrix_state.dart';
import '../widgets/channel_button.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 视频矩阵控制页面
/// 布局：上方为信号输出按钮阵列，下方为信号输入按钮阵列
/// 功能逻辑：先选输入 → 再点输出绑定，通道映射通过 MatrixState 共享
/// ============================================================
class VideoMatrixPage extends StatefulWidget {
  const VideoMatrixPage({super.key});

  @override
  State<VideoMatrixPage> createState() => _VideoMatrixPageState();
}

class _VideoMatrixPageState extends State<VideoMatrixPage> {
  final MatrixState _matrixState = MatrixState();
  final MatrixConnection _matrixConnection = MatrixConnection();

  int get _inputCount => DeviceConfig.matrixInputCount;
  int get _outputCount => DeviceConfig.matrixOutputCount;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_matrixConnection, _matrixState]),
      builder: (context, child) {
        return SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 8)),
                  _buildConnectionStatusIndicator(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 10)),
                  Expanded(
                    child: _buildSectionCard(
                      label: '信号输出',
                      child: Center(child: _buildOutputButtonsGrid()),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 8)),
                  _buildInstructionBanner(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 8)),
                  Expanded(
                    child: _buildSectionCard(
                      label: '信号输入',
                      child: Center(child: _buildInputButtonsGrid()),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  _buildOperationHintText(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({required String label, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 8)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: ResponsiveUtils.getSpacing(context, 4), bottom: ResponsiveUtils.getSpacing(context, 6)),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildOutputButtonsGrid() {
    final double spacing = ResponsiveUtils.getSpacing(context, 8);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(_outputCount, (index) {
        final int channelNumber = index + 1;
        final int? boundInput = _matrixState.getBoundInput(channelNumber);
        final int selectedInput = _matrixState.selectedInputIndex;
        final bool isHighlighted =
            selectedInput > 0 && boundInput == selectedInput;

        return ChannelButton(
          label: '$channelNumber',
          channelType: '输出',
          channelNumber: channelNumber,
          isHighlighted: isHighlighted,
          hasBinding: boundInput != null,
          highlightColor: isHighlighted ? const Color(0xFF3E6B48) : null,
          onTap: () => _onOutputChannelTapped(channelNumber),
        );
      }),
      ),
    );
  }

  Widget _buildInputButtonsGrid() {
    final double spacing = ResponsiveUtils.getSpacing(context, 8);
    return Center(
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: spacing,
        runSpacing: spacing,
        children: List.generate(_inputCount, (index) {
        final int channelNumber = index + 1;
        final bool isSelected =
            _matrixState.selectedInputIndex == channelNumber;

        return ChannelButton(
          label: '$channelNumber',
          channelType: '输入',
          channelNumber: channelNumber,
          isHighlighted: isSelected,
          hasBinding: false,
          highlightColor: isSelected ? const Color(0xFF1F4068) : null,
          onTap: () => _onInputChannelTapped(channelNumber),
        );
      }),
      ),
    );
  }

  Widget _buildConnectionStatusIndicator() {
    final status = _matrixConnection.status;

    String statusText = '矩阵设备未连接';
    Color statusColor = Colors.grey[500]!;
    IconData statusIcon = Icons.link_off;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '矩阵设备已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '正在连接矩阵设备...';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '矩阵连接失败，自动重连中...';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
        break;
      case ConnectionStatus.disconnected:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
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
          if (status == ConnectionStatus.connected) ...[
            const SizedBox(width: 8),
            Text(
              '心跳 #${_matrixConnection.heartbeatCount}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getSpacing(context, 12), vertical: ResponsiveUtils.getSpacing(context, 6)),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4068).withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F4068).withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: const Color(0xFF6B9BD2)),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          Flexible(
            child: Text(
              '先点击下方信号输入  再点击上方信号输出',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 11),
                color: const Color(0xFF6B9BD2),
                letterSpacing: 1.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationHintText() {
    final int selectedInput = _matrixState.selectedInputIndex;
    String hintText;

    if (selectedInput == 0) {
      hintText = '请先点击下方输入通道，再点击上方输出通道进行绑定';
    } else {
      final outputs = _matrixState.getOutputsForInput(selectedInput);
      hintText = outputs.isEmpty
          ? '已选中：输入 $selectedInput — 请点击上方输出通道绑定'
          : '选中：输入 $selectedInput | 已绑定输出：${outputs.join('、')}';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        hintText,
        key: ValueKey(hintText),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context, 10), color: Colors.grey[600], letterSpacing: 0.5),
      ),
    );
  }

  void _onInputChannelTapped(int channelNumber) {
    _matrixState.selectInput(channelNumber);
  }

  void _onOutputChannelTapped(int channelNumber) {
    final int selectedInput = _matrixState.selectedInputIndex;

    if (selectedInput == 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先点击下方的信号输入通道'),
          backgroundColor: const Color(0xFF3A5A8C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final int? previousInput = _matrixState.getBoundInput(channelNumber);
    _matrixState.bindOutput(channelNumber, selectedInput);

    final String command;
    if (DeviceConfig.matrixSendAsHex) {
      command = DeviceConfig.hexMatrixSwitchCmd
          .replaceAll('{input02X}', selectedInput.toRadixString(16).padLeft(2, '0').toUpperCase())
          .replaceAll('{output02X}', channelNumber.toRadixString(16).padLeft(2, '0').toUpperCase());
    } else {
      command = DeviceConfig.matrixSwitchAsciiCmd
          .replaceAll('{input}', '$selectedInput')
          .replaceAll('{output}', '$channelNumber');
    }
    _matrixConnection.sendCommand(command);

    if (previousInput != null && previousInput != selectedInput) {
      debugPrint('[矩阵控制] 输出$channelNumber 已从输入$previousInput 切换到输入$selectedInput');
    }
  }
}
