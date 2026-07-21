import 'package:flutter/material.dart';
import '../services/big_screen_connection.dart';
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

/// ============================================================
/// 大屏控制页面
/// 布局：上方分屏预览 → 中间分屏模式按钮 → 下方输入按钮阵列
/// 分屏按钮→拼接器发指令，输入/输出绑定→矩阵发指令（通过 MatrixState 共享状态）
/// ============================================================
class BigScreenPage extends StatefulWidget {
  /// 大屏控制页面，用于控制拼接器分屏模式和矩阵输入输出绑定
  ///
  /// 页面主要功能：
  /// - 显示拼接器和矩阵的连接状态
  /// - 展示当前分屏模式的可视化预览
  /// - 提供分屏模式切换按钮（全屏、二分屏、三分屏、四分屏、五分屏等）
  /// - 展示矩阵输入通道按钮，支持选择和重命名
  /// - 支持将选中的输入通道绑定到指定的分屏区域
  ///
  /// 布局结构：
  /// - 顶部：连接状态指示器
  /// - 中上：分屏预览区域（3份高度）
  /// - 中部：分屏模式选择按钮
  /// - 中下：操作提示横幅
  /// - 底部：输入通道按钮网格（5份高度）
  const BigScreenPage({super.key});

  @override
  State<BigScreenPage> createState() => _BigScreenPageState();
}

class _BigScreenPageState extends State<BigScreenPage> {
  /// 当前选中的分屏模式索引，对应 [_layoutButtonEntries] 列表的位置
  int _currentLayoutIndex = 0;

  /// 当前选中的分屏区域索引，-1 表示未选中任何区域
  int _selectedAreaIndex = -1;

  /// 矩阵状态管理器，用于管理输入输出绑定关系和选中状态
  final MatrixState _matrixState = MatrixState();

  /// 拼接器连接管理，负责与拼接器设备的通信
  final BigScreenConnection _bigScreenConnection = BigScreenConnection();

  /// 矩阵连接管理，负责与矩阵设备的通信
  final MatrixConnection _matrixConnection = MatrixConnection();

  /// 通道名称管理器，负责输入/输出通道的自定义命名
  final ChannelNameManager _nameManager = ChannelNameManager();

  /// 设备配置实例，提供运行时配置参数
  final DeviceConfig _config = DeviceConfig();

  /// 获取矩阵输入通道总数，从设备配置中读取
  int get _inputCount => _config.matrixInputCount;

  /// 获取大屏输出通道列表，从设备配置中读取
  List<int> get _outputChannels => _config.bigScreenOutputChannels;

  /// 分屏模式对应的区域数量映射表
  /// 索引对应布局类型：0-全屏, 1-全屏16:9, 2-二分屏, 3-三分屏, 4-四分屏, 5-五分屏
  static const List<int> _layoutAreaCounts = [1, 1, 2, 3, 4, 5];

  /// 构建分屏模式按钮条目列表
  /// 根据配置页面中的开关设置动态决定显示哪些分屏模式
  /// 使用 getter 确保每次 build 时都能获取最新配置
  List<MapEntry<int, String>> get _layoutButtonEntries {
    final List<MapEntry<int, String>> entries = [];
    if (_config.showBigScreenFull) {
      entries.add(const MapEntry(0, '全屏'));
    }
    if (_config.showBigScreenFull169) {
      entries.add(const MapEntry(1, '全屏16:9'));
    }
    if (_config.showBigScreenSplit2) {
      entries.add(const MapEntry(2, '二分屏'));
    }
    if (_config.showBigScreenSplit3) {
      entries.add(const MapEntry(3, '三分屏'));
    }
    if (_config.showBigScreenSplit4) {
      entries.add(const MapEntry(4, '四分屏'));
    }
    if (_config.showBigScreenSplit5) {
      entries.add(const MapEntry(5, '五分屏'));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    /// 使用 ListenableBuilder 监听多个数据源变化，实现响应式更新
    /// 监听的数据源包括：拼接器连接状态、矩阵连接状态、矩阵绑定状态、通道名称
    return ListenableBuilder(
      listenable: Listenable.merge([
        _bigScreenConnection,
        _matrixConnection,
        _matrixState,
        _nameManager,
      ]),
      builder: (context, child) {
        /// 页面根布局结构：
        /// SafeArea → SizedBox.expand → Padding → Column
        /// Column 内按垂直方向排列各功能区域
        return SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                children: [
                  /// 顶部间距
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域1：连接状态指示器（拼接器和矩阵）
                  _buildConnectionStatusIndicator(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域2：分屏预览（占3份高度），可展开
                  Expanded(
                    flex: 3,
                    child: SectionCard(
                      label: '分屏预览',
                      isExpandable: true,
                      child: _buildSplitScreenPreview(),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域3：分屏模式选择按钮
                  SectionCard(
                    label: '分屏模式',
                    child: _buildLayoutButtonsRow(),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域4：操作提示横幅
                  _buildInstructionBanner(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域5：输入通道按钮网格（占5份高度），可展开
                  Expanded(
                    flex: 5,
                    child: SectionCard(
                      label: '信号输入',
                      isExpandable: true,
                      child: _buildInputButtonsGrid(),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
                  /// 区域6：底部操作提示文字
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

  /// 构建连接状态指示器，显示拼接器和矩阵的连接状态
  ///
  /// 在页面顶部居中显示两个状态芯片：左侧显示拼接器状态，右侧显示矩阵状态
  /// 状态变化时会自动更新显示内容
  Widget _buildConnectionStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        /// 拼接器连接状态芯片
        _buildSingleStatusChip('拼接器', _bigScreenConnection.status),
        SizedBox(width: ResponsiveUtils.getSpacing(context, 10)),
        /// 矩阵连接状态芯片
        _buildSingleStatusChip('矩阵', _matrixConnection.status),
      ],
    );
  }

  /// 构建单个设备的连接状态芯片
  ///
  /// 根据连接状态 [status] 显示不同的文本、颜色和图标：
  /// - connected：显示"已连接"，绿色，链接图标
  /// - connecting：显示"连接中"，黄色，同步图标
  /// - error：显示"连接失败"，红色，错误图标
  /// - 其他：显示"未连接"，灰色，断开链接图标
  ///
  /// 参数：
  /// - [label]：设备名称标签（如"拼接器"、"矩阵"）
  /// - [status]：连接状态枚举值
  Widget _buildSingleStatusChip(String label, ConnectionStatus status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    /// 根据连接状态确定显示内容
    switch (status) {
      case ConnectionStatus.connected:
        statusText = '$label已连接';
        statusColor = DeviceConfig.colorStatusConnected;
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '$label连接中';
        statusColor = DeviceConfig.colorStatusConnecting;
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '$label连接失败';
        statusColor = DeviceConfig.colorStatusError;
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = '$label未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
    }

    /// 状态芯片的外观样式：带边框的圆角矩形，内包含图标和文本
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(DeviceConfig.statusChipBorderRadius),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 13),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分屏预览区域，可视化展示当前分屏模式下的各个区域
  ///
  /// 根据当前选中的分屏模式，动态生成对应的分屏区域预览
  /// 每个区域显示其绑定状态，支持点击选中进行输入绑定操作
  ///
  /// 布局结构：
  /// - Container：外层容器，设置内边距
  /// - LayoutBuilder：获取父容器约束，用于计算各区域位置
  /// - Stack：堆叠布局，放置多个分屏区域
  /// - Positioned + AnimatedContainer：每个分屏区域，带有动画效果
  Widget _buildSplitScreenPreview() {
    /// 获取当前分屏模式对应的区域数量
    final int areaCount =
        _layoutAreaCounts[_layoutButtonEntries[_currentLayoutIndex].key];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          /// 使用 Stack 堆叠所有分屏区域
          return Stack(
            children: List.generate(areaCount, (areaIndex) {
              /// 根据区域索引获取对应的输出通道号
              /// 如果区域数量超过配置的输出通道数，自动顺延编号
              final int outputChannel = areaIndex < _outputChannels.length
                  ? _outputChannels[areaIndex]
                  : _outputChannels.last + areaIndex;

              /// 计算当前区域在预览区域中的位置和大小
              final Rect rect = _calculateAreaRect(
                  areaIndex, areaCount, constraints.maxWidth, constraints.maxHeight);

              /// 获取该输出通道已绑定的输入通道号
              final int? boundInput = _matrixState.getBoundInput(outputChannel);

              /// 获取当前选中的输入通道号
              final int selectedInput = _matrixState.selectedInputIndex;

              /// 判断当前区域是否需要高亮显示：
              /// 1. 区域被直接选中（_selectedAreaIndex == areaIndex）
              /// 2. 当前选中的输入已绑定到该区域（boundInput == selectedInput）
              final bool isHighlighted = (_selectedAreaIndex == areaIndex) ||
                  (selectedInput > 0 && boundInput == selectedInput);

              /// 使用 Positioned 定位每个分屏区域
              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: GestureDetector(
                  /// 点击分屏区域时触发绑定操作
                  onTap: () => _onSplitAreaTapped(areaIndex, outputChannel),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: DeviceConfig.animationDurationMs),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      /// 高亮时使用高亮背景色，否则使用默认背景色
                      color: isHighlighted
                          ? DeviceConfig.colorHighlightOutput.withAlpha(220)
                          : DeviceConfig.colorSplitAreaBg,
                      borderRadius: BorderRadius.circular(DeviceConfig.cardBorderRadius),
                      border: Border.all(
                        /// 高亮时使用强调色边框，否则使用默认边框色
                        color: isHighlighted
                            ? DeviceConfig.colorAccent
                            : DeviceConfig.colorSplitAreaBorder,
                        width: isHighlighted ? 2 : 1,
                      ),
                      /// 高亮时添加阴影效果，增强视觉反馈
                      boxShadow: isHighlighted
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3E6B48).withAlpha(80),
                                blurRadius: 6,
                              )
                            ]
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

  /// 分屏区域位置计算算法，根据区域索引和分屏数量计算每个区域的位置和大小
  ///
  /// 支持多种分屏模式：全屏(1区)、二分屏(2区)、三分屏(3区)、四分屏(4区)、五分屏(5区)
  /// 每种模式采用不同的布局策略，确保区域均匀分布且间距一致
  ///
  /// 参数：
  /// - [areaIndex]：当前区域的索引（从0开始）
  /// - [areaCount]：分屏区域总数
  /// - [totalW]：父容器总宽度
  /// - [totalH]：父容器总高度
  ///
  /// 返回值：Rect 对象，表示区域的左上角坐标和宽高
  Rect _calculateAreaRect(
      int areaIndex, int areaCount, double totalW, double totalH) {
    /// 分屏区域之间的间距，从配置中读取
    const double gap = DeviceConfig.splitAreaGap;

    /// 根据分屏区域总数选择对应的布局算法
    switch (areaCount) {
      /// ============ 全屏模式（1个区域） ============
      /// 单个区域占满整个容器，无需计算间距
      case 1:
        return Rect.fromLTWH(0, 0, totalW, totalH);

      /// ============ 二分屏模式（2个区域） ============
      /// 两个区域水平排列，各占一半宽度，中间有一个间距
      /// 布局示意图：[ 区域0 | 区域1 ]
      case 2:
        /// 每个区域的宽度 = (总宽度 - 1个间距) / 2
        final double w = (totalW - gap) / 2;
        /// 区域0从x=0开始，区域1从x=w+gap开始，高度均为全屏高度
        return Rect.fromLTWH(areaIndex * (w + gap), 0, w, totalH);

      /// ============ 三分屏模式（3个区域） ============
      /// 三个区域水平排列，各占三分之一宽度，中间有两个间距
      /// 布局示意图：[ 区域0 | 区域1 | 区域2 ]
      case 3:
        /// 每个区域的宽度 = (总宽度 - 2个间距) / 3
        final double w = (totalW - gap * 2) / 3;
        /// 区域0从x=0开始，区域1从x=w+gap开始，区域2从x=2*(w+gap)开始
        return Rect.fromLTWH(areaIndex * (w + gap), 0, w, totalH);

      /// ============ 四分屏模式（4个区域） ============
      /// 四个区域呈2x2网格排列，每行两列，每列两行
      /// 布局示意图：
      /// [ 区域0 | 区域1 ]
      /// [ 区域2 | 区域3 ]
      case 4:
        /// 每个区域的宽度 = (总宽度 - 1个间距) / 2
        final double w = (totalW - gap) / 2;
        /// 每个区域的高度 = (总高度 - 1个间距) / 2
        final double h = (totalH - gap) / 2;
        /// 使用取模运算确定列位置（0或1），使用整除运算确定行位置（0或1）
        /// x = (areaIndex % 2) * (w + gap)
        /// y = (areaIndex ~/ 2) * (h + gap)
        return Rect.fromLTWH(
            (areaIndex % 2) * (w + gap), (areaIndex ~/ 2) * (h + gap), w, h);

      /// ============ 五分屏模式（5个区域） ============
      /// 特殊的"品"字形布局：中间一个大区域，左右各两个小区域
      /// 布局示意图：
      /// [ 区域1 ] [ 区域0 ] [ 区域3 ]
      /// [ 区域2 ] [      ] [ 区域4 ]
      /// 其中区域0占据中间全部高度，区域1/2占据左侧上下两部分，区域3/4占据右侧上下两部分
      case 5:
        /// 左右两侧区域宽度 = 总宽度 * 20%
        final double sideW = totalW * 0.2;
        /// 中间区域宽度 = 总宽度 - 左侧宽度 - 右侧宽度 - 2个间距
        final double centerW = totalW - sideW * 2 - gap * 2;
        /// 左右区域的高度 = (总高度 - 1个间距) / 2（上下各一半）
        final double halfH = (totalH - gap) / 2;

        /// 根据区域索引返回对应的位置：
        /// - areaIndex=0：中间区域，横跨整个高度
        /// - areaIndex=1：左上角区域
        /// - areaIndex=2：左下角区域
        /// - areaIndex=3：右上角区域
        /// - areaIndex=4：右下角区域
        switch (areaIndex) {
          case 0: // 中间区域
            return Rect.fromLTWH(sideW + gap, 0, centerW, totalH);
          case 1: // 左上角区域
            return Rect.fromLTWH(0, 0, sideW, halfH);
          case 2: // 左下角区域
            return Rect.fromLTWH(0, halfH + gap, sideW, halfH);
          case 3: // 右上角区域
            return Rect.fromLTWH(centerW + sideW + gap * 2, 0, sideW, halfH);
          default: // 右下角区域（areaIndex=4）
            return Rect.fromLTWH(
                centerW + sideW + gap * 2, halfH + gap, sideW, halfH);
        }

      /// 默认情况：返回全屏区域
      default:
        return Rect.fromLTWH(0, 0, totalW, totalH);
    }
  }

  /// 构建分屏模式选择按钮行
  ///
  /// 根据设备配置动态生成可用的分屏模式按钮，支持水平滚动
  /// 如果没有可用的分屏模式，则返回一个空容器
  Widget _buildLayoutButtonsRow() {
    /// 如果没有配置任何分屏模式，返回空容器
    if (_layoutButtonEntries.isEmpty) return const SizedBox.shrink();

    return Center(
      child: SingleChildScrollView(
        /// 设置水平滚动，当按钮数量过多时可以左右滑动
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          /// 根据配置的分屏模式数量生成对应的按钮
          children: List.generate(_layoutButtonEntries.length, (index) {
            final entry = _layoutButtonEntries[index];
            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getSpacing(context, 5)),
              child: _buildLayoutButton(
                  /// 按钮显示文本（如"全屏"、"二分屏"等）
                  entry.value,
                  /// 是否为当前选中的模式
                  _currentLayoutIndex == index,
                  /// 点击回调，传递按钮索引和布局键值
                  () => _onLayoutButtonTapped(index, entry.key)),
            );
          }),
        ),
      ),
    );
  }

  /// 构建单个分屏模式选择按钮
  ///
  /// 根据选中状态显示不同的样式，选中时有高亮背景、强调色边框和阴影效果
  ///
  /// 参数：
  /// - [label]：按钮显示文本（如"全屏"、"二分屏"等）
  /// - [isSelected]：是否为当前选中状态
  /// - [onTap]：点击回调函数
  Widget _buildLayoutButton(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        /// 添加状态切换动画效果，提升用户体验
        duration: Duration(milliseconds: DeviceConfig.animationDurationMs),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, 12),
          vertical: ResponsiveUtils.getSpacing(context, 6),
        ),
        decoration: BoxDecoration(
          /// 选中时使用高亮背景色，未选中时使用默认背景色
          color: isSelected
              ? DeviceConfig.colorHighlightInput.withAlpha(220)
              : DeviceConfig.colorSplitAreaBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            /// 选中时使用强调色边框，未选中时使用默认边框色
            color: isSelected
                ? DeviceConfig.colorAccent
                : DeviceConfig.colorButtonBorder,
            /// 选中时边框更粗（2px），未选中时较细（1px）
            width: isSelected ? 2 : 1,
          ),
          /// 选中时添加阴影效果，增强视觉层次感
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DeviceConfig.colorHighlightInput.withAlpha(60),
                    blurRadius: 6,
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, 12),
            fontWeight: FontWeight.w600,
            /// 选中时文字为白色，未选中时为灰色
            color: isSelected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  /// 构建输入通道按钮网格区域
  ///
  /// 使用 ChannelButtonGrid 组件动态生成所有输入通道按钮
  /// 每个按钮显示自定义名称（通过 ChannelNameManager 获取），支持点击选中和长按重命名
  ///
  /// 按钮交互：
  /// - 单击：选中该输入通道，准备进行绑定操作
  /// - 长按：弹出重命名对话框，修改通道显示名称
  Widget _buildInputButtonsGrid() {
    return ChannelButtonGrid(
      /// 输入通道总数，从设备配置中读取
      totalCount: _inputCount,
      /// 按钮构建器，为每个通道生成对应的 ChannelButton
      buttonBuilder: (channelNumber, width, height) {
        /// 判断当前通道是否为选中状态
        final bool isSelected =
            _matrixState.selectedInputIndex == channelNumber;
        return ChannelButton(
          /// 显示通道的自定义名称，如果未设置则显示默认名称
          label: _nameManager.getInputName(channelNumber),
          channelType: '输入',
          channelNumber: channelNumber,
          /// 选中状态高亮显示
          isHighlighted: isSelected,
          /// 选中时使用深蓝色高亮
          highlightColor:
              isSelected ? const Color(0xFF1F4068) : null,
          /// 单击事件：选中该输入通道
          onTap: () => _onInputChannelTapped(channelNumber),
          /// 长按事件：弹出重命名对话框
          onLongPress: () => _showRenameDialog('输入', channelNumber, false),
          width: width,
          height: height,
        );
      },
    );
  }

  /// 构建操作提示横幅，引导用户正确操作流程
  ///
  /// 在分屏模式按钮下方显示一条提示信息，告知用户操作步骤：
  /// 先选择输入通道，再点击分屏区域进行绑定
  Widget _buildInstructionBanner() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, 12),
        vertical: ResponsiveUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        /// 使用半透明高亮色作为背景
        color: DeviceConfig.colorHighlightInput.withAlpha(25),
        borderRadius: BorderRadius.circular(DeviceConfig.bannerBorderRadius),
        border:
            Border.all(color: DeviceConfig.colorHighlightInput.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// 信息图标，强调这是提示内容
          const Icon(Icons.info_outline, size: 16, color: DeviceConfig.colorAccent),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          /// 提示文本，使用 Flexible 确保文本过长时能自动换行
          const Flexible(
            child: Text(
              '先点击下方信号输入  再点击上方分屏区域',
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

  /// 构建底部操作提示文本，根据当前选中状态动态显示不同内容
  ///
  /// 提示文本分为三种状态：
  /// 1. 未选中任何输入：提示用户先选择输入通道
  /// 2. 已选中输入但未绑定：提示用户点击分屏区域进行绑定
  /// 3. 已选中输入且已绑定：显示已绑定的输出通道列表
  Widget _buildOperationHintText() {
    /// 获取当前选中的输入通道号，0 表示未选中
    final int selectedInput = _matrixState.selectedInputIndex;
    String hintText;

    /// 根据选中状态生成不同的提示文本
    if (selectedInput == 0) {
      /// 状态1：未选中任何输入通道
      hintText = '请先点击下方输入通道，再点击上方分屏区域进行绑定';
    } else {
      /// 获取当前选中输入已绑定的所有输出通道
      final outputs = _matrixState.getOutputsForInput(selectedInput);
      /// 状态2或3：根据是否有绑定输出显示不同提示
      hintText = outputs.isEmpty
          ? '已选中：输入 $selectedInput — 请点击上方分屏区域绑定'
          : '选中：输入 $selectedInput | 已绑定输出：${outputs.join('、')}';
    }

    /// 使用 AnimatedSwitcher 实现提示文本切换时的动画效果
    return AnimatedSwitcher(
      duration: Duration(milliseconds: DeviceConfig.hintAnimationDurationMs),
      child: Text(
        hintText,
        /// 使用提示文本作为 key，确保内容变化时触发动画
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

  /// 分屏模式按钮点击事件处理
  ///
  /// 当用户点击分屏模式按钮时触发，执行以下操作：
  /// 1. 更新当前选中的分屏模式索引
  /// 2. 清除之前选中的分屏区域
  /// 3. 生成对应的分屏命令并发送给拼接器
  ///
  /// 参数：
  /// - [buttonIndex]：按钮在列表中的索引位置
  /// - [layoutKey]：分屏模式的键值（0-5，对应不同的分屏模式）
  void _onLayoutButtonTapped(int buttonIndex, int layoutKey) {
    /// 更新状态：切换分屏模式，清除选中区域
    setState(() {
      _currentLayoutIndex = buttonIndex;
      _selectedAreaIndex = -1;
    });

    /// 计算分屏模式代码（键值+1，因为拼接器协议通常从1开始）
    final int layoutCode = layoutKey + 1;

    /// 根据配置选择命令格式（十六进制或ASCII），替换命令模板中的占位符
    final String command = _config.bigScreenSendAsHex
        /// 十六进制模式：将布局代码转换为两位十六进制字符串
        ? _config.hexBigScreenLayoutCmd.replaceAll(
            '{layout02X}',
            layoutCode.toRadixString(16).padLeft(2, '0').toUpperCase(),
          )
        /// ASCII模式：直接使用十进制数字
        : _config.bigScreenLayoutAsciiCmd
            .replaceAll('{layout}', '$layoutCode');

    /// 发送分屏命令给拼接器
    _bigScreenConnection.sendCommand(command);
  }

  /// 分屏区域点击事件处理
  ///
  /// 当用户点击分屏预览区域时触发，执行以下操作：
  /// 1. 切换该区域的选中状态（点击已选中区域则取消选中）
  /// 2. 如果已选中某个输入通道，则执行绑定操作
  ///
  /// 参数：
  /// - [areaIndex]：分屏区域的索引（从0开始）
  /// - [outputChannel]：该区域对应的输出通道号
  void _onSplitAreaTapped(int areaIndex, int outputChannel) {
    /// 切换区域选中状态：如果已选中则取消，否则选中该区域
    setState(() {
      _selectedAreaIndex =
          _selectedAreaIndex == areaIndex ? -1 : areaIndex;
    });

    /// 如果当前已选中输入通道（selectedInputIndex > 0），则执行绑定
    if (_matrixState.selectedInputIndex > 0) {
      _bindInputToOutput(outputChannel);
    }
  }

  /// 将选中的输入通道绑定到指定的输出通道
  ///
  /// 执行输入输出绑定操作，更新本地状态并向矩阵发送切换命令
  /// 如果未选中任何输入通道（selectedInput == 0），则不执行任何操作
  ///
  /// 参数：
  /// - [outputChannel]：目标输出通道号
  void _bindInputToOutput(int outputChannel) {
    /// 获取当前选中的输入通道号
    final int selectedInput = _matrixState.selectedInputIndex;
    /// 安全检查：如果未选中输入通道，则直接返回
    if (selectedInput == 0) return;

    /// 更新本地矩阵状态：记录输入输出绑定关系
    _matrixState.bindOutput(outputChannel, selectedInput);

    /// 根据配置选择命令格式（十六进制或ASCII），替换命令模板中的占位符
    final String command = _config.matrixSendAsHex
        /// 十六进制模式：将输入和输出通道号转换为两位十六进制字符串
        ? _config.hexMatrixSwitchCmd
            .replaceAll(
                '{input02X}',
                selectedInput
                    .toRadixString(16)
                    .padLeft(2, '0')
                    .toUpperCase())
            .replaceAll(
                '{output02X}',
                outputChannel
                    .toRadixString(16)
                    .padLeft(2, '0')
                    .toUpperCase())
        /// ASCII模式：直接使用十进制数字
        : _config.matrixSwitchAsciiCmd
            .replaceAll('{input}', '$selectedInput')
            .replaceAll('{output}', '$outputChannel');

    /// 发送矩阵切换命令给矩阵设备
    _matrixConnection.sendCommand(command);
  }

  /// 输入通道按钮点击事件处理
  ///
  /// 当用户点击输入通道按钮时触发，执行以下操作：
  /// 1. 清除之前选中的分屏区域（重置选中状态）
  /// 2. 更新矩阵状态，选中当前输入通道
  ///
  /// 参数：
  /// - [channelNumber]：被点击的输入通道号
  void _onInputChannelTapped(int channelNumber) {
    /// 清除分屏区域选中状态，避免视觉混淆
    setState(() => _selectedAreaIndex = -1);
    /// 更新矩阵状态，选中该输入通道
    _matrixState.selectInput(channelNumber);
  }

  /// 显示通道重命名对话框
  ///
  /// 当用户长按输入/输出通道按钮时触发，弹出重命名对话框
  /// 用户输入新名称后，保存到 ChannelNameManager 中
  ///
  /// 参数：
  /// - [typeName]：通道类型名称（如"输入"、"输出"）
  /// - [channelNumber]：通道号
  /// - [isOutput]：是否为输出通道（true为输出，false为输入）
  void _showRenameDialog(
      String typeName, int channelNumber, bool isOutput) {
    showRenameDialog(
      context,
      typeName: typeName,
      channelNumber: channelNumber,
      /// 根据通道类型获取当前名称
      currentName: isOutput
          ? _nameManager.getOutputName(channelNumber)
          : _nameManager.getInputName(channelNumber),
      /// 确认回调：保存新名称到名称管理器
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
