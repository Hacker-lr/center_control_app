import 'package:flutter/material.dart';
import '../services/matrix_connection.dart';
import '../services/device_config.dart';
import '../services/base_connection.dart';
import '../services/matrix_state.dart';
import '../services/channel_name_manager.dart';
import '../widgets/channel_button.dart';
import '../widgets/channel_button_grid.dart';
import '../widgets/section_card.dart';
import '../utils/responsive_utils.dart';
import '../utils/rename_dialog.dart';

/// 视频矩阵控制页面
///
/// 该页面用于控制视频矩阵设备的信号切换，包含以下主要功能：
/// - 显示矩阵设备的连接状态
/// - 展示信号输出通道网格（上方区域）
/// - 展示信号输入通道网格（下方区域）
/// - 支持点击输入通道后再点击输出通道进行信号绑定
/// - 支持长按通道按钮进行重命名
///
/// 布局结构：
/// - 顶部：连接状态指示器
/// - 中上：信号输出通道卡片（可展开/折叠）
/// - 中部：操作指引横幅
/// - 中下：信号输入通道卡片（可展开/折叠）
/// - 底部：操作提示文字
class VideoMatrixPage extends StatefulWidget {
  const VideoMatrixPage({super.key});

  @override
  State<VideoMatrixPage> createState() => _VideoMatrixPageState();
}

class _VideoMatrixPageState extends State<VideoMatrixPage> {
  /// 矩阵状态管理，用于存储输入输出通道的绑定关系和选中状态
  final MatrixState _matrixState = MatrixState();

  /// 矩阵设备连接管理，负责与硬件设备的通信和连接状态监控
  final MatrixConnection _matrixConnection = MatrixConnection();

  /// 通道名称管理器，负责管理输入输出通道的自定义名称
  final ChannelNameManager _nameManager = ChannelNameManager();

  /// 设备配置实例，提供矩阵通道数量、命令格式等配置
  final DeviceConfig _config = DeviceConfig();

  /// 获取矩阵输入通道数量，从设备配置中读取
  int get _inputCount => _config.matrixInputCount;

  /// 获取矩阵输出通道数量，从设备配置中读取
  int get _outputCount => _config.matrixOutputCount;
  /// 通道名称管理器，负责管理输入输出通道的自定义名称
  final ChannelNameManager _nameManager = ChannelNameManager();

  /// 设备配置实例，提供矩阵通道数量、命令格式等配置
  final DeviceConfig _config = DeviceConfig();

  /// 获取矩阵输入通道数量，从设备配置中读取
  int get _inputCount => _config.matrixInputCount;

  /// 获取矩阵输出通道数量，从设备配置中读取
  int get _outputCount => _config.matrixOutputCount;

  /// 构建页面主布局
  ///
  /// 使用 ListenableBuilder 监听三个核心状态管理器的变化：
  /// - _matrixConnection：连接状态变化时刷新UI
  /// - _matrixState：通道绑定关系或选中状态变化时刷新UI
  /// - _nameManager：通道名称变化时刷新UI
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // 合并多个 Listenable，任一状态变化都会触发重建
      listenable:
          Listenable.merge([_matrixConnection, _matrixState, _nameManager]),
      builder: (context, child) {
        return SafeArea(
          // 安全区域，避免内容被系统状态栏遮挡
          child: SizedBox.expand(
            // 充满整个父容器
            child: Padding(
              // 响应式页面边距
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                // 垂直布局，从上到下依次排列各组件
                children: [
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  // 1. 连接状态指示器
                  _buildConnectionStatusIndicator(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                  // 2. 信号输出通道区域（可滚动）
                  Expanded(
                    child: SectionCard(
                      label: '信号输出',
                      isExpandable: true,
                      child: _buildOutputSection(),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  // 3. 操作指引横幅
                  _buildInstructionBanner(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  // 4. 信号输入通道区域（可滚动）
                  Expanded(
                    child: SectionCard(
                      label: '信号输入',
                      isExpandable: true,
                      child: _buildInputSection(),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  // 5. 底部操作提示文字
                  _buildOperationHintText(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建信号输出通道区域
  ///
  /// 创建一个通道按钮网格，展示所有输出通道。每个按钮显示其绑定的输入通道，
  /// 当用户选中某个输入通道时，已绑定该输入的输出通道会高亮显示。
  Widget _buildOutputSection() {
    return ChannelButtonGrid(
      totalCount: _outputCount,
      buttonBuilder: (channelNumber, width, height) {
        // 获取当前输出通道已绑定的输入通道编号
        final int? boundInput = _matrixState.getBoundInput(channelNumber);
        // 获取当前选中的输入通道编号
        final int selectedInput = _matrixState.selectedInputIndex;
        // 判断是否需要高亮：已选中输入通道，且该输出通道绑定了此输入
        final bool isHighlighted =
            selectedInput > 0 && boundInput == selectedInput;
        return ChannelButton(
          // 获取输出通道的自定义名称
          label: _nameManager.getOutputName(channelNumber),
          channelType: '输出',
          channelNumber: channelNumber,
          isHighlighted: isHighlighted,
          // 高亮颜色：输出通道使用配置的输出高亮色
          highlightColor: isHighlighted ? DeviceConfig.colorHighlightOutput : null,
          // 点击事件：触发输出通道绑定逻辑
          onTap: () => _onOutputChannelTapped(channelNumber),
          // 长按事件：弹出重命名对话框
          onLongPress: () => _showRenameDialog('输出', channelNumber, true),
          width: width,
          height: height,
        );
      },
    );
  }

  /// 构建信号输入通道区域
  ///
  /// 创建一个通道按钮网格，展示所有输入通道。当前选中的输入通道会高亮显示，
  /// 方便用户识别已选择的源信号。
  Widget _buildInputSection() {
    return ChannelButtonGrid(
      totalCount: _inputCount,
      buttonBuilder: (channelNumber, width, height) {
        // 判断当前输入通道是否被选中
        final bool isSelected =
            _matrixState.selectedInputIndex == channelNumber;
        return ChannelButton(
          // 获取输入通道的自定义名称
          label: _nameManager.getInputName(channelNumber),
          channelType: '输入',
          channelNumber: channelNumber,
          isHighlighted: isSelected,
          // 高亮颜色：输入通道使用配置的输入高亮色
          highlightColor: isSelected ? DeviceConfig.colorHighlightInput : null,
          // 点击事件：选中该输入通道
          onTap: () => _onInputChannelTapped(channelNumber),
          // 长按事件：弹出重命名对话框
          onLongPress: () => _showRenameDialog('输入', channelNumber, false),
          width: width,
          height: height,
        );
      },
    );
  }

  /// 构建连接状态指示器
  ///
  /// 根据矩阵设备的连接状态显示不同的图标、文字和颜色，
  /// 包括：已连接、连接中、连接失败、未连接四种状态。
  /// 当设备连接成功时，还会显示心跳计数。
  Widget _buildConnectionStatusIndicator() {
    // 获取当前连接状态
    final status = _matrixConnection.status;

    // 默认状态：未连接
    String statusText = '矩阵设备未连接';
    Color statusColor = Colors.grey[500]!;
    IconData statusIcon = Icons.link_off;

    // 根据连接状态更新显示内容
    switch (status) {
      case ConnectionStatus.connected:
        // 已连接状态：绿色主题
        statusText = '矩阵设备已连接';
        statusColor = DeviceConfig.colorStatusConnected;
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        // 连接中状态：黄色主题
        statusText = '正在连接矩阵设备...';
        statusColor = DeviceConfig.colorStatusConnecting;
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        // 连接失败状态：红色主题
        statusText = '矩阵连接失败，自动重连中...';
        statusColor = DeviceConfig.colorStatusError;
        statusIcon = Icons.error_outline;
        break;
      case ConnectionStatus.disconnected:
        // 未连接状态：使用默认值
        break;
    }

    // 返回状态指示器容器
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        // 背景色：状态色的低透明度版本
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(DeviceConfig.statusChipBorderRadius),
        // 边框：状态色的中等透明度版本
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态图标
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          // 状态文字
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 连接成功时显示心跳计数
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

  /// 构建操作指引横幅
  ///
  /// 在输出区域和输入区域之间显示操作提示，指导用户如何进行信号切换操作：
  /// 先选择输入通道，再选择输出通道。
  Widget _buildInstructionBanner() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, 12),
        vertical: ResponsiveUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        // 背景色：输入高亮色的低透明度版本
        color: DeviceConfig.colorHighlightInput.withAlpha(25),
        borderRadius: BorderRadius.circular(DeviceConfig.bannerBorderRadius),
        // 边框：输入高亮色的中等透明度版本
        border:
            Border.all(color: DeviceConfig.colorHighlightInput.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 信息图标
          const Icon(Icons.info_outline, size: 16, color: DeviceConfig.colorAccent),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          // 操作指引文字，使用 Flexible 防止文字溢出
          const Flexible(
            child: Text(
              '先点击下方信号输入  再点击上方信号输出',
              style: TextStyle(
                fontSize: 11,
                color: DeviceConfig.colorAccent,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部操作提示文字
  ///
  /// 根据当前选中状态动态显示不同的提示信息：
  /// - 未选中输入时：提示用户先选择输入通道
  /// - 已选中输入但未绑定输出时：显示已选中的输入编号
  /// - 已选中输入且已绑定输出时：显示已选中的输入编号和已绑定的输出列表
  /// 使用 AnimatedSwitcher 实现文字切换动画。
  Widget _buildOperationHintText() {
    // 获取当前选中的输入通道编号
    final int selectedInput = _matrixState.selectedInputIndex;
    String hintText;

    // 根据选中状态生成不同的提示文字
    if (selectedInput == 0) {
      // 未选中任何输入通道
      hintText = '请先点击下方输入通道，再点击上方输出通道进行绑定';
    } else {
      // 获取当前输入通道已绑定的所有输出通道列表
      final outputs = _matrixState.getOutputsForInput(selectedInput);
      // 根据是否有绑定输出显示不同提示
      hintText = outputs.isEmpty
          ? '已选中：输入 $selectedInput — 请点击上方输出通道绑定'
          : '选中：输入 $selectedInput | 已绑定输出：${outputs.join('、')}';
    }

    // 使用 AnimatedSwitcher 实现平滑的文字切换动画
    return AnimatedSwitcher(
      duration: Duration(milliseconds: DeviceConfig.hintAnimationDurationMs),
      child: Text(
        hintText,
        key: ValueKey(hintText),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(context, 10),
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 输入通道点击事件处理
  ///
  /// 当用户点击某个输入通道时，更新矩阵状态管理器中的选中输入索引。
  /// 调用时机：用户点击输入区域的任意通道按钮。
  ///
  /// 参数：
  /// - [channelNumber]：被点击的输入通道编号
  void _onInputChannelTapped(int channelNumber) {
    // 更新选中的输入通道，触发 UI 刷新以高亮显示选中状态
    _matrixState.selectInput(channelNumber);
  }

  /// 输出通道点击事件处理
  ///
  /// 当用户点击某个输出通道时，执行信号绑定操作：
  /// 1. 检查是否已选中输入通道，未选中则显示提示
  /// 2. 更新矩阵状态中的绑定关系
  /// 3. 生成并发送控制命令到硬件设备
  /// 调用时机：用户点击输出区域的任意通道按钮。
  ///
  /// 参数：
  /// - [channelNumber]：被点击的输出通道编号
  void _onOutputChannelTapped(int channelNumber) {
    // 获取当前选中的输入通道编号
    final int selectedInput = _matrixState.selectedInputIndex;

    // 检查是否已选中输入通道
    if (selectedInput == 0) {
      // 未选中输入通道，显示提示信息
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先点击下方的信号输入通道'),
          backgroundColor: DeviceConfig.colorSnackBarBg,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    // 记录切换前绑定的输入通道，用于日志输出
    final int? previousInput = _matrixState.getBoundInput(channelNumber);
    // 更新矩阵状态：将该输出通道绑定到当前选中的输入通道
    _matrixState.bindOutput(channelNumber, selectedInput);

    // 根据配置生成控制命令（支持十六进制和 ASCII 两种格式）
    final String command;
    if (_config.matrixSendAsHex) {
      // 十六进制格式：将输入输出编号转换为两位十六进制字符串
      command = _config.hexMatrixSwitchCmd
          .replaceAll(
              '{input02X}',
              selectedInput
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase())
          .replaceAll(
              '{output02X}',
              channelNumber
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase());
    if (_config.matrixSendAsHex) {
      // 十六进制格式：将输入输出编号转换为两位十六进制字符串
      command = _config.hexMatrixSwitchCmd
          .replaceAll(
              '{input02X}',
              selectedInput
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase())
          .replaceAll(
              '{output02X}',
              channelNumber
                  .toRadixString(16)
                  .padLeft(2, '0')
                  .toUpperCase());
    } else {
      // ASCII 格式：直接替换占位符为十进制数字
      command = _config.matrixSwitchAsciiCmd
      // ASCII 格式：直接替换占位符为十进制数字
      command = _config.matrixSwitchAsciiCmd
          .replaceAll('{input}', '$selectedInput')
          .replaceAll('{output}', '$channelNumber');
    }
    // 发送控制命令到矩阵设备
    _matrixConnection.sendCommand(command);

    // 输出调试日志：仅在切换了不同输入源时记录
    if (previousInput != null && previousInput != selectedInput) {
      debugPrint(
          '[矩阵控制] 输出$channelNumber 已从输入$previousInput 切换到输入$selectedInput');
    }
  }

  /// 显示通道重命名对话框
  ///
  /// 调用通用的重命名对话框组件，支持输入和输出通道的重命名操作。
  /// 调用时机：用户长按任意通道按钮。
  ///
  /// 参数：
  /// - [typeName]：通道类型名称（'输入' 或 '输出'），用于对话框标题
  /// - [channelNumber]：通道编号
  /// - [isOutput]：是否为输出通道
  void _showRenameDialog(
      String typeName, int channelNumber, bool isOutput) {
    showRenameDialog(
      context,
      typeName: typeName,
      channelNumber: channelNumber,
      // 根据通道类型获取当前名称
      currentName: isOutput
          ? _nameManager.getOutputName(channelNumber)
          : _nameManager.getInputName(channelNumber),
      // 确认按钮回调：保存新名称
      onConfirm: (newName) {
        if (isOutput) {
          _nameManager.saveOutputName(channelNumber, newName);
        } else {
          _nameManager.saveInputName(channelNumber, newName);
        }
      },
    );
  }
}
