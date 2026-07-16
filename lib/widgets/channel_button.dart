import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// 通用通道按钮组件
/// 用于视频矩阵页和大屏控制页的输入/输出通道按钮
/// 按钮仅显示通道数字，选中时高亮
/// ============================================================
class ChannelButton extends StatelessWidget {
  final String label;
  final String channelType;
  final int channelNumber;
  final bool isHighlighted;
  final bool hasBinding;
  final int bindingCount;
  final Color? highlightColor;
  final VoidCallback onTap;

  const ChannelButton({
    super.key,
    required this.label,
    required this.channelType,
    required this.channelNumber,
    required this.isHighlighted,
    required this.hasBinding,
    this.bindingCount = 0,
    this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = highlightColor ?? const Color(0xFF1F4068);
    final double buttonSize = ResponsiveUtils.getChannelButtonSize(context);
    final double borderRadius = buttonSize * 0.2;
    final double shadowBlur = buttonSize * 0.18;
    final double smallShadowBlur = buttonSize * 0.08;
    final double labelFontSize = buttonSize * 0.5;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: isHighlighted
              ? activeColor.withAlpha(230)
              : const Color(0xFF2A2A3E),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(100),
                    blurRadius: shadowBlur,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: smallShadowBlur,
                    offset: const Offset(0, 3),
                  ),
                ],
          border: Border.all(
            color: isHighlighted ? activeColor : const Color(0xFF3A3F48),
            width: isHighlighted ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w700,
              color: isHighlighted ? Colors.white : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}
