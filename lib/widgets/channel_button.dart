import 'dart:async';
import 'package:flutter/material.dart';
import '../services/device_config.dart';

/// ============================================================
/// 通用通道按钮组件
/// 用于视频矩阵页和大屏控制页的输入/输出通道按钮
/// 支持自定义长按触发改名对话框（时长由 DeviceConfig 控制）
/// 文字使用统一字号（由按钮高度决定，不随内容长度缩放），过长自动换行/省略，
/// 确保所有通道名称字号一致
/// 所有颜色与交互参数取自 DeviceConfig 全局配置
/// ============================================================
class ChannelButton extends StatefulWidget {
  /// 按钮显示的标签文字
  final String label;

  /// 通道类型标识（如 'input' / 'output'）
  final String channelType;

  /// 通道编号（1-based）
  final int channelNumber;

  /// 是否高亮显示（选中状态）
  final bool isHighlighted;

  /// 高亮颜色，可选；若为空则使用 DeviceConfig.colorHighlightInput
  final Color? highlightColor;

  /// 点击回调函数
  final VoidCallback onTap;

  /// 长按回调函数，可选；若为空则禁用长按功能
  final VoidCallback? onLongPress;

  /// 按钮固定宽度，由父组件根据可用空间计算传入
  final double width;

  /// 按钮固定高度，由父组件根据可用空间计算传入
  final double height;

  /// 构造函数
  const ChannelButton({
    super.key,
    required this.label,
    required this.channelType,
    required this.channelNumber,
    required this.isHighlighted,
    this.highlightColor,
    required this.onTap,
    this.onLongPress,
    required this.width,
    required this.height,
  });

  @override
  State<ChannelButton> createState() => _ChannelButtonState();
}

class _ChannelButtonState extends State<ChannelButton> {
  /// 长按计时器，用于控制长按进度和触发时机
  Timer? _longPressTimer;

  /// 当前是否处于按下状态
  bool _isPressing = false;

  /// 长按是否已触发（防止重复触发）
  bool _longPressTriggered = false;

  /// 长按进度值（0.0 ~ 1.0）
  double _pressProgress = 0.0;

  /// DeviceConfig 实例，用于访问实例属性
  final DeviceConfig _config = DeviceConfig();

  @override
  void dispose() {
    // 组件销毁时取消计时器，防止内存泄漏
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// 开始按下，启动长按计时器
  /// 仅在设置了 onLongPress 回调时生效
  void _onTapDown(TapDownDetails details) {
    if (widget.onLongPress == null) return;

    setState(() {
      _isPressing = true;
      _longPressTriggered = false;
      _pressProgress = 0.0;
    });

    // 启动周期性计时器，每隔 tickInterval 更新一次进度
    _longPressTimer = Timer.periodic(
      Duration(milliseconds: _config.longPressTickIntervalMs),
      (timer) {
        setState(() {
          // 计算当前长按进度：已触发次数 × 每次间隔 / 总长按时长
          _pressProgress =
              timer.tick *
              _config.longPressTickIntervalMs /
              _config.longPressDurationMs;
        });
        // 进度达到 1.0 时触发长按回调
        if (_pressProgress >= 1.0) {
          timer.cancel();
          _longPressTimer = null;
          _longPressTriggered = true;
          widget.onLongPress?.call();
          setState(() {
            _isPressing = false;
            _pressProgress = 0.0;
          });
        }
      },
    );
  }

  /// 释放时取消计时器，仅在未触发长按的情况下调用点击事件
  void _onTapUp(TapUpDetails details) {
    _cancelLongPress();
    // 只有当长按未触发时才执行点击事件，避免长按和点击同时触发
    if (!_longPressTriggered) {
      widget.onTap();
    }
  }

  /// 取消时取消计时器（如手指移出按钮区域）
  void _onTapCancel() {
    _cancelLongPress();
  }

  /// 取消长按计时器并重置状态
  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isPressing) {
      setState(() {
        _isPressing = false;
        _pressProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算实际高亮颜色：优先使用自定义颜色，否则使用全局配置
    final Color activeColor =
        widget.highlightColor ?? DeviceConfig.colorHighlightInput;
    // 计算圆角半径：根据按钮宽度和全局比例系数
    final double borderRadius =
        widget.width * DeviceConfig.buttonBorderRadiusRatio;
    // 计算高亮状态阴影模糊度
    final double shadowBlur = widget.width * DeviceConfig.buttonShadowBlurRatio;
    // 计算普通状态阴影模糊度
    final double smallShadowBlur =
        widget.width * DeviceConfig.buttonShadowBlurSmallRatio;

    // 手势检测器 - 监听按下、抬起、取消事件
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      // 动画容器 - 状态变化时平滑过渡
      child: AnimatedContainer(
        duration: Duration(milliseconds: DeviceConfig.animationDurationMs),
        curve: Curves.easeInOut,
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          // 背景色：高亮状态使用半透明激活色，普通状态使用按钮背景色
          color: widget.isHighlighted
              ? activeColor.withAlpha(230)
              : DeviceConfig.colorButtonBg,
          // 阴影：高亮状态使用大阴影，普通状态使用小阴影
          boxShadow: widget.isHighlighted
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
          // 边框：按下状态使用按压色，高亮状态使用激活色，普通状态使用边框色
          border: Border.all(
            color: _isPressing
                ? DeviceConfig.colorPressing
                : (widget.isHighlighted
                      ? activeColor
                      : DeviceConfig.colorButtonBorder),
            // 边框宽度：按下状态最粗(2.0)，高亮状态中等(1.5)，普通状态最细(1.0)
            width: _isPressing ? 2.0 : (widget.isHighlighted ? 1.5 : 1.0),
          ),
        ),
        // 堆叠布局：进度条在底部，文字标签在中央
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 长按进度条（底部）- 仅在按下状态显示
            if (_isPressing)
              Positioned(
                bottom: 0,
                left: widget.width * 0.05,
                right: widget.width * 0.05,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(borderRadius),
                    bottomRight: Radius.circular(borderRadius),
                  ),
                  child: LinearProgressIndicator(
                    value: _pressProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      DeviceConfig.colorPressing,
                    ),
                    minHeight: DeviceConfig.longPressIndicatorHeight,
                  ),
                ),
              ),
            // 按钮标签：最多 2 行，超长名称自动缩小字号完整显示，不再截断。
            // 用 TextPainter 二分查找「能在 2 行 + 按钮可用高度内完整显示」的
            // 最大字号（名字越长字越小，最短 8px 兜底，短名字保持原基准字号）。
            // 矩阵页与大屏页通道按钮共用此组件，一处修改同时生效。
            _AdaptiveChannelLabel(
              label: widget.label,
              maxWidth:
                  widget.width *
                  (1 - 2 * DeviceConfig.buttonPaddingHorizontalRatio),
              maxHeight:
                  widget.height *
                  (1 - 2 * DeviceConfig.buttonPaddingVerticalRatio),
              baseFont: widget.height * DeviceConfig.buttonFontSizeRatio,
              isHighlighted: widget.isHighlighted,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================
/// 通道按钮自适应标签
/// 最多显示 2 行；用二分查找「2 行内能完整显示」的最大字号：
///   - 名字短 → 保持 baseFont（1 行）
///   - 名字长 / 按钮窄（全屏 8 列等）→ 字号自动压小，保证 2 行内全部可见
/// 不设 minFont 下限（下限 1.0），确保任意长度命名都能在 2 行内完整显示，
/// 不再出现"FittedBox 因 2 行总高≤maxHeight 误判装得下而不缩放、内容被裁"的问题。
/// 测量约束（maxLines:2 + maxWidth/maxHeight）与渲染约束（Text）保持一致。
/// ============================================================
class _AdaptiveChannelLabel extends StatelessWidget {
  final String label;
  final double maxWidth;
  final double maxHeight;
  final double baseFont;
  final bool isHighlighted;

  const _AdaptiveChannelLabel({
    required this.label,
    required this.maxWidth,
    required this.maxHeight,
    required this.baseFont,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    // 二分查找「2 行内装下且总高 ≤ maxHeight」的最大字号。
    // 关键：TextPainter 与 Text 都设 maxLines:2，且接受条件必须
    //   !tp.didExceedMaxLines（2 行真装得下）&& tp.height ≤ maxHeight
    // 不设 minFont 硬下限（下限 1.0），窄按钮/超长命名也能 2 行完整显示。
    const double minFont = 1.0;
    final TextStyle baseStyle = TextStyle(
      fontSize: baseFont,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    double fitFont = minFont;
    double lo = minFont;
    double hi = baseFont;
    // 先判断 baseFont 本身就能 2 行装下，避免不必要的二分
    final TextPainter tpBase = TextPainter(
      text: TextSpan(text: label, style: baseStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    if (!tpBase.didExceedMaxLines && tpBase.height <= maxHeight + 0.5) {
      fitFont = baseFont;
    } else {
      for (int i = 0; i < 30; i++) {
        final double mid = (lo + hi) / 2;
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: label,
            style: baseStyle.copyWith(fontSize: mid),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 2,
        )..layout(maxWidth: maxWidth);
        // 必须 2 行真装得下 且 总高不超可用区，才接受该字号
        if (!tp.didExceedMaxLines && tp.height <= maxHeight + 0.5) {
          fitFont = mid;
          lo = mid;
        } else {
          hi = mid;
        }
      }
    }

    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          // 最多 2 行；fitFont 已保证 2 行内完整显示，overflow 仅为极端兜底
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fitFont,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? Colors.white : Colors.grey[400],
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
