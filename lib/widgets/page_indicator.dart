import 'package:flutter/material.dart';
import '../services/device_config.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 分页圆点指示器组件
/// 用于 PageView 的页码指示，带动画效果
/// 当前页圆点宽度会动态扩展以突出显示
/// 所有颜色与动画参数取自 DeviceConfig 全局配置
/// ============================================================
class PageIndicator extends StatelessWidget {
  /// 当前页码（从0开始）
  final int currentPage;

  /// 总页数
  final int totalPages;

  /// 构造函数
  /// [currentPage] 当前页码，必填，从0开始
  /// [totalPages] 总页数，必填，必须大于0
  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    // 外层 Padding - 提供顶部间距
    return Padding(
      padding: EdgeInsets.only(
          top: ResponsiveUtils.getSpacing(context, 6)),
      // 水平布局 - 圆点居中排列
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        // 动态生成圆点列表
        children: List.generate(totalPages, (index) {
          // 判断当前圆点是否为激活状态（当前页）
          final bool isActive = index == currentPage;
          // 带动画的圆点容器
          return AnimatedContainer(
            // 动画时长取自全局配置
            duration: Duration(
                milliseconds: DeviceConfig.animationDurationMs),
            // 圆点之间的水平间距
            margin: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getSpacing(context, 3),
            ),
            // 激活状态宽度扩展为普通状态的2倍
            width: isActive
                ? ResponsiveUtils.getSpacing(context, 12)
                : ResponsiveUtils.getSpacing(context, 6),
            height: ResponsiveUtils.getSpacing(context, 6),
            decoration: BoxDecoration(
              // 激活状态使用主题强调色，非激活状态使用深色
              color: isActive
                  ? DeviceConfig.colorAccent
                  : const Color(0xFF3A3F48),
              // 圆角半径为高度的一半，使圆点呈胶囊状
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getSpacing(context, 3),
              ),
            ),
          );
        }),
      ),
    );
  }
}
