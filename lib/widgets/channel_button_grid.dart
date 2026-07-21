import 'package:flutter/material.dart';
import '../services/device_config.dart';
import 'page_indicator.dart';

/// ============================================================
/// 通道按钮网格组件
/// 支持单页模式（≤8个按钮，2行×4列）和多页模式（>8个按钮，2行×8列/页）
/// 自动计算按钮尺寸以适应当前可用空间
/// 所有布局参数取自 DeviceConfig 全局配置
/// buttonBuilder 会传入 (channelNumber, buttonWidth, buttonHeight)
/// ============================================================
class ChannelButtonGrid extends StatefulWidget {
  /// 总按钮数量
  final int totalCount;

  /// 按钮构建器，传入通道编号（1-based）、按钮宽度、按钮高度
  /// 由父组件提供，用于创建每个通道按钮的具体实现
  final Widget Function(int channelNumber, double width, double height)
      buttonBuilder;

  /// 构造函数
  /// [totalCount] 总按钮数量，必填，必须大于0
  /// [buttonBuilder] 按钮构建器，必填，用于自定义按钮样式
  const ChannelButtonGrid({
    super.key,
    required this.totalCount,
    required this.buttonBuilder,
  });

  @override
  State<ChannelButtonGrid> createState() => _ChannelButtonGridState();
}

class _ChannelButtonGridState extends State<ChannelButtonGrid> {
  final DeviceConfig _config = DeviceConfig();

  /// 当前页码（从0开始）
  int _currentPage = 0;

  /// 分页控制器，管理 PageView 的翻页行为
  final PageController _pageController = PageController(initialPage: 0);

  /// 计算总页数
  /// 使用向上取整公式：(总数 + 每页数量 - 1) ~/ 每页数量
  int get _totalPages =>
      (widget.totalCount + _config.gridItemsPerPage - 1) ~/
      _config.gridItemsPerPage;

  @override
  void dispose() {
    // 组件销毁时释放 PageController 资源，防止内存泄漏
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 单页模式：按钮数量 ≤ 8 时，使用 2行×4列 布局
    if (widget.totalCount <= 8) {
      // 使用 LayoutBuilder 获取父容器约束，动态计算按钮尺寸
      return LayoutBuilder(
        builder: (context, constraints) {
          // 计算按钮宽度：可用宽度减去3个横向间距，再除以4列
          final double btnW =
              (constraints.maxWidth - 3 * _config.gridSpacing4Cross) / 4;
          // 计算按钮高度：可用高度减去1个纵向间距，除以行数，再乘以高度系数
          final double btnH =
              ((constraints.maxHeight - 1 * _config.gridSpacing4Main) /
                      _config.gridRowCount) *
                  _config.gridBtnHeightFactor;
          return _buildGrid(
            count: widget.totalCount,
            crossAxisCount: 4,
            mainSpacing: _config.gridSpacing4Main,
            crossSpacing: _config.gridSpacing4Cross,
            btnWidth: btnW,
            btnHeight: btnH,
          );
        },
      );
    }

    // 多页模式：按钮数量 > 8 时，使用 PageView + 2行×8列 布局
    return Column(
      children: [
        // 可滚动的内容区域，占满父容器剩余空间
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            // 页面切换时更新当前页码状态
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: _totalPages,
            // 构建每一页的内容
            itemBuilder: (context, pageIndex) {
              // 计算当前页的起始索引
              final int startIndex =
                  pageIndex * _config.gridItemsPerPage;
              // 计算当前页的结束索引
              final int endIndex = startIndex + _config.gridItemsPerPage;
              // 计算当前页实际显示的按钮数量（最后一页可能不足一页）
              final int displayCount = widget.totalCount > endIndex
                  ? _config.gridItemsPerPage
                  : widget.totalCount - startIndex;
              // 使用 LayoutBuilder 获取当前页的约束
              return LayoutBuilder(
                builder: (context, constraints) {
                  // 计算按钮宽度：可用宽度减去7个横向间距，再除以8列
                  final double btnW =
                      (constraints.maxWidth - 7 * _config.gridSpacing8Cross) /
                          8;
                  // 计算按钮高度：可用高度减去1个纵向间距，除以行数，再乘以高度系数
                  final double btnH =
                      ((constraints.maxHeight -
                                  1 * _config.gridSpacing8Main) /
                              _config.gridRowCount) *
                          _config.gridBtnHeightFactor;
                  return _buildGrid(
                    count: displayCount,
                    crossAxisCount: 8,
                    mainSpacing: _config.gridSpacing8Main,
                    crossSpacing: _config.gridSpacing8Cross,
                    btnWidth: btnW,
                    btnHeight: btnH,
                    startIndex: startIndex,
                  );
                },
              );
            },
          ),
        ),
        // 分页指示器：仅在页数 > 1 时显示
        if (_totalPages > 1)
          PageIndicator(currentPage: _currentPage, totalPages: _totalPages),
      ],
    );
  }

  /// 构建网格布局的私有方法
  /// [count] 当前页显示的按钮数量
  /// [crossAxisCount] 列数（4或8）
  /// [mainSpacing] 纵向间距
  /// [crossSpacing] 横向间距
  /// [btnWidth] 按钮宽度
  /// [btnHeight] 按钮高度
  /// [startIndex] 起始索引（用于多页模式，默认为0）
  Widget _buildGrid({
    required int count,
    required int crossAxisCount,
    required double mainSpacing,
    required double crossSpacing,
    required double btnWidth,
    required double btnHeight,
    int startIndex = 0,
  }) {
    return Padding(
      // 网格外部边距
      padding: EdgeInsets.symmetric(
        horizontal: _config.gridHorizontalPadding,
        vertical: _config.gridVerticalPadding,
      ),
      // 居中对齐
      child: Center(
        child: GridView.count(
          padding: EdgeInsets.zero,
          // 收缩包裹内容，不滚动
          shrinkWrap: true,
          // 禁用滚动物理效果
          physics: const NeverScrollableScrollPhysics(),
          // 列数
          crossAxisCount: crossAxisCount,
          // 纵向间距
          mainAxisSpacing: mainSpacing,
          // 横向间距
          crossAxisSpacing: crossSpacing,
          // 宽高比
          childAspectRatio: btnWidth / btnHeight,
          // 动态生成按钮列表
          children: List.generate(count, (index) {
            // 通道编号 = 起始索引 + 当前索引 + 1（1-based）
            final int channelNumber = startIndex + index + 1;
            // 调用按钮构建器创建按钮
            return widget.buttonBuilder(channelNumber, btnWidth, btnHeight);
          }),
        ),
      ),
    );
  }
}
