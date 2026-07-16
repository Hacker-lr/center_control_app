import 'package:flutter/material.dart';
import '../services/big_screen_connection.dart';
import '../services/matrix_connection.dart';
import '../services/device_config.dart';
import '../services/base_connection.dart';
import '../services/matrix_state.dart';
import '../widgets/channel_button.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 大屏控制页面
/// 布局：上方分屏预览 → 中间分屏模式按钮 → 下方输入按钮阵列
/// 分屏按钮→拼接器发指令，输入/输出绑定→矩阵发指令（通过 MatrixState 共享状态）
/// ============================================================
class BigScreenPage extends StatefulWidget {
  const BigScreenPage({super.key});

  @override
  State<BigScreenPage> createState() => _BigScreenPageState();
}

class _BigScreenPageState extends State<BigScreenPage> {
  int _currentLayoutIndex = 0;
  int _selectedAreaIndex = -1;

  final MatrixState _matrixState = MatrixState();
  final BigScreenConnection _bigScreenConnection = BigScreenConnection();
  final MatrixConnection _matrixConnection = MatrixConnection();

  int get _inputCount => DeviceConfig.matrixInputCount;
  List<int> get _outputChannels => DeviceConfig.bigScreenOutputChannels;

  static const List<int> _layoutAreaCounts = [1, 1, 2, 3, 4, 5];

  List<MapEntry<int, String>> _buildLayoutButtonEntries() {
    final List<MapEntry<int, String>> entries = [];
    if (DeviceConfig.showBigScreenFull) entries.add(const MapEntry(0, '全屏'));
    if (DeviceConfig.showBigScreenFull169) entries.add(const MapEntry(1, '全屏16:9'));
    if (DeviceConfig.showBigScreenSplit2) entries.add(const MapEntry(2, '二分屏'));
    if (DeviceConfig.showBigScreenSplit3) entries.add(const MapEntry(3, '三分屏'));
    if (DeviceConfig.showBigScreenSplit4) entries.add(const MapEntry(4, '四分屏'));
    if (DeviceConfig.showBigScreenSplit5) entries.add(const MapEntry(5, '五分屏'));
    return entries;
  }

  late final List<MapEntry<int, String>> _layoutButtonEntries = _buildLayoutButtonEntries();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_bigScreenConnection, _matrixConnection, _matrixState]),
      builder: (context, child) {
        return SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 8)),
                  _buildConnectionStatusIndicator(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  Expanded(
                    flex: 3,
                    child: _buildSectionCardExpandable(
                      label: '分屏预览',
                      child: _buildSplitScreenPreview(),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  _buildSectionCard(
                    label: '分屏模式',
                    child: _buildLayoutButtonsRow(),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  _buildInstructionBanner(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  Expanded(
                    flex: 5,
                    child: _buildSectionCardExpandable(
                      label: '信号输入',
                      child: Center(child: _buildInputButtonsGrid()),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
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
          child,
        ],
      ),
    );
  }

  Widget _buildSectionCardExpandable({required String label, required Widget child}) {
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

  Widget _buildConnectionStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSingleStatusChip('拼接器', _bigScreenConnection.status),
        SizedBox(width: ResponsiveUtils.getSpacing(context, 10)),
        _buildSingleStatusChip('矩阵', _matrixConnection.status),
      ],
    );
  }

  Widget _buildSingleStatusChip(String label, ConnectionStatus status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '$label已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '$label连接中';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '$label连接失败';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = '$label未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 13),
          const SizedBox(width: 4),
          Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSplitScreenPreview() {
    final int areaCount = _layoutAreaCounts[_layoutButtonEntries[_currentLayoutIndex].key];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: List.generate(areaCount, (areaIndex) {
              final int outputChannel = areaIndex < _outputChannels.length
                  ? _outputChannels[areaIndex]
                  : _outputChannels.last + areaIndex;
              final Rect rect = _calculateAreaRect(areaIndex, areaCount, constraints.maxWidth, constraints.maxHeight);
              final int? boundInput = _matrixState.getBoundInput(outputChannel);
              final int selectedInput = _matrixState.selectedInputIndex;
              final bool isHighlighted = (_selectedAreaIndex == areaIndex) ||
                  (selectedInput > 0 && boundInput == selectedInput);

              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  onTap: () => _onSplitAreaTapped(areaIndex, outputChannel),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isHighlighted ? const Color(0xFF3E6B48).withAlpha(220) : const Color(0xFF1E2228),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isHighlighted ? const Color(0xFF6B9BD2) : const Color(0xFF2A3038),
                        width: isHighlighted ? 2 : 1,
                      ),
                      boxShadow: isHighlighted
                          ? [BoxShadow(color: const Color(0xFF3E6B48).withAlpha(80), blurRadius: 6)]
                          : null,
                    ),
                    child: const Center(),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Rect _calculateAreaRect(int areaIndex, int areaCount, double totalW, double totalH) {
    final double gap = 4.0;

    switch (areaCount) {
      case 1:
        return Rect.fromLTWH(0, 0, totalW, totalH);
      case 2:
        final double w = (totalW - gap) / 2;
        return Rect.fromLTWH(areaIndex * (w + gap), 0, w, totalH);
      case 3:
        final double w = (totalW - gap * 2) / 3;
        return Rect.fromLTWH(areaIndex * (w + gap), 0, w, totalH);
      case 4:
        final double w = (totalW - gap) / 2;
        final double h = (totalH - gap) / 2;
        return Rect.fromLTWH((areaIndex % 2) * (w + gap), (areaIndex ~/ 2) * (h + gap), w, h);
      case 5:
        final double sideW = totalW * 0.2;
        final double centerW = totalW - sideW * 2 - gap * 2;
        final double halfH = (totalH - gap) / 2;
        switch (areaIndex) {
          case 0: return Rect.fromLTWH(sideW + gap, 0, centerW, totalH);
          case 1: return Rect.fromLTWH(0, 0, sideW, halfH);
          case 2: return Rect.fromLTWH(0, halfH + gap, sideW, halfH);
          case 3: return Rect.fromLTWH(centerW + sideW + gap * 2, 0, sideW, halfH);
          default: return Rect.fromLTWH(centerW + sideW + gap * 2, halfH + gap, sideW, halfH);
        }
      default:
        return Rect.fromLTWH(0, 0, totalW, totalH);
    }
  }

  Widget _buildLayoutButtonsRow() {
    if (_layoutButtonEntries.isEmpty) return const SizedBox.shrink();

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_layoutButtonEntries.length, (index) {
            final entry = _layoutButtonEntries[index];
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getSpacing(context, 5)),
              child: _buildLayoutButton(entry.value, _currentLayoutIndex == index, () => _onLayoutButtonTapped(index, entry.key)),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLayoutButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, 12),
          vertical: ResponsiveUtils.getSpacing(context, 6),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1F4068).withAlpha(220) : const Color(0xFF1E2228),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF6B9BD2) : const Color(0xFF3A3F48), width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF1F4068).withAlpha(60), blurRadius: 6)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[500],
          ),
        ),
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
        final bool isSelected = _matrixState.selectedInputIndex == channelNumber;

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
              '先点击下方信号输入  再点击上方分屏区域',
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
      hintText = '请先点击下方输入通道，再点击上方分屏区域进行绑定';
    } else {
      final outputs = _matrixState.getOutputsForInput(selectedInput);
      hintText = outputs.isEmpty
          ? '已选中：输入 $selectedInput — 请点击上方分屏区域绑定'
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

  void _onLayoutButtonTapped(int buttonIndex, int layoutKey) {
    setState(() {
      _currentLayoutIndex = buttonIndex;
      _selectedAreaIndex = -1;
    });

    final int layoutCode = layoutKey + 1;
    final String command = DeviceConfig.bigScreenSendAsHex
        ? DeviceConfig.hexBigScreenLayoutCmd.replaceAll('{layout02X}', layoutCode.toRadixString(16).padLeft(2, '0').toUpperCase())
        : DeviceConfig.bigScreenLayoutAsciiCmd.replaceAll('{layout}', '$layoutCode');
    _bigScreenConnection.sendCommand(command);
  }

  void _onSplitAreaTapped(int areaIndex, int outputChannel) {
    setState(() {
      _selectedAreaIndex = _selectedAreaIndex == areaIndex ? -1 : areaIndex;
    });
    if (_matrixState.selectedInputIndex > 0) {
      _bindInputToOutput(outputChannel);
    }
  }

  void _bindInputToOutput(int outputChannel) {
    final int selectedInput = _matrixState.selectedInputIndex;
    if (selectedInput == 0) return;

    _matrixState.bindOutput(outputChannel, selectedInput);
    final String command = DeviceConfig.matrixSendAsHex
        ? DeviceConfig.hexMatrixSwitchCmd
            .replaceAll('{input02X}', selectedInput.toRadixString(16).padLeft(2, '0').toUpperCase())
            .replaceAll('{output02X}', outputChannel.toRadixString(16).padLeft(2, '0').toUpperCase())
        : DeviceConfig.matrixSwitchAsciiCmd
            .replaceAll('{input}', '$selectedInput')
            .replaceAll('{output}', '$outputChannel');
    _matrixConnection.sendCommand(command);
  }

  void _onInputChannelTapped(int channelNumber) {
    setState(() => _selectedAreaIndex = -1);
    _matrixState.selectInput(channelNumber);
  }
}
