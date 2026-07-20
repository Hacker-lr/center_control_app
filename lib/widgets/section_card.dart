import 'package:flutter/material.dart';
import '../services/device_config.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 通用分区卡片组件
/// 用于页面内的分区容器，带标题和内容区域
/// [isExpandable] = true 时内容区域占满剩余空间（用于 Expanded 父容器）
/// 所有颜色与尺寸参数取自 DeviceConfig 全局配置
/// ============================================================
class SectionCard extends StatelessWidget {
  /// 分区标题文本
  final String label;

  /// 分区内容 Widget
  final Widget child;

  /// 是否可扩展填充剩余空间
  /// true 时内容区域使用 Expanded 包裹，占满父容器剩余空间
  /// false 时内容区域仅占用自身所需空间
  final bool isExpandable;

  /// 构造函数
  /// [label] 分区标题，必填
  /// [child] 分区内容，必填
  /// [isExpandable] 是否可扩展，默认 false
  const SectionCard({
    super.key,
    required this.label,
    required this.child,
    this.isExpandable = false,
  });

  @override
  Widget build(BuildContext context) {
    // 外层容器 - 提供卡片背景、边框和圆角
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 4)),
      decoration: BoxDecoration(
        color: DeviceConfig.colorCardBg,
        borderRadius:
            BorderRadius.circular(DeviceConfig.cardBorderRadius),
        border: Border.all(
            color: DeviceConfig.colorCardBorder, width: 1),
      ),
      // 垂直布局 - 标题在上，内容在下
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题区域 - 带左内边距和底内边距
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getSpacing(context, 4),
              bottom: ResponsiveUtils.getSpacing(context, 3),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 11),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.0,
              ),
            ),
          ),
          // 内容区域 - 根据 isExpandable 决定是否扩展填充
          isExpandable ? Expanded(child: child) : child,
        ],
      ),
    );
  }
}
