import 'dart:async';
import 'package:flutter/material.dart';
import '../services/device_config.dart';

/// ============================================================
/// 通用通道按钮组件
/// 用于视频矩阵页和大屏控制页的输入/输出通道按钮
/// 支持自定义长按触发改名对话框（时长由 DeviceConfig 控制）
/// 通道名最多 2 行：输入已被 channelNameMaxLength(15) 限制在物理容量内，
/// 渲染端在 [4px, baseFont] 内二分字号，保证两行内完整显示（不裁切）。
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
            // 按钮标签：见 _AdaptiveChannelLabel 文档（最多两行 + 完整显示）。
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
/// 目标："最多两行" + "完整显示" 同时成立，且上下两行字号一致
/// （单 Text + 单一 style 渲染，天然保证所有行同字号）。
/// 前提：改名输入已被 channelNameMaxLength(15) 限制在物理容量内
/// （全屏最窄 45px 按钮，实测 15 中文字 2 行完整显示最大字号 4.73px）。
/// 渲染逻辑：
///   - baseFont 下能 ≤2 行 → 直接用 baseFont，不缩放（短名/中名）
///   - baseFont 装不下 → 在 [4px, baseFont] 内二分找能 2 行的最大字号，
///     结果 ×0.95 保险系数吸收测量/渲染亚像素差异，保证完整显示
///   - 连 4px 都装不下（超限旧数据，输入已限制不应出现）→ 保持 2 行裁切兜底
/// 测量样式从 DefaultTextStyle.of(context) 继承主题字体（全局 SimHei），
/// 与渲染 Text 完全一致。
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

  /// 最小字号（对应 channelNameMaxLength=15 的两行容量下限：实测 15 字在
  /// 45px 按钮最大字号 4.73px，取 4.0 留余量；正常渲染约 4.5px）。
  /// 二分下限，同时是"两行+全"的字号下界。
  static const double _minFont = 4.0;

  /// 保险系数：二分结果 ×0.95，吸收测量/渲染的亚像素/字体回退差异，杜绝裁切。
  static const double _safeRatio = 0.95;

  TextStyle _style(TextStyle inherited, double font) => TextStyle(
    fontSize: font,
    fontWeight: FontWeight.w600,
    color: isHighlighted ? Colors.white : Colors.grey[400],
    height: 1.1,
    fontFamily: inherited.fontFamily,
    fontFamilyFallback: inherited.fontFamilyFallback,
  );

  /// 在给定字号下，文字能否在 maxWidth 内最多 2 行完整显示，
  /// 且 2 行总高不超过 maxHeight。仅做测量，不依赖缩放。
  bool _fits(TextStyle inherited, double font) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: _style(inherited, font)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines && painter.height <= maxHeight;
  }

  /// 二分查找「能在 2 行 + 可用高度内完整显示」的最大字号：
  /// 短名保持 baseFont（不放大），长名逐档缩小，下限 _minFont。
  double _fitFont(TextStyle inherited) {
    if (_fits(inherited, baseFont)) return baseFont;
    double lo = _minFont;
    double hi = baseFont;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (_fits(inherited, mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  Widget build(BuildContext context) {
    // 继承主题默认样式（含全局 SimHei 字体），保证测量与渲染字体一致
    final TextStyle inherited = DefaultTextStyle.of(context).style;
    final double font = _fitFont(inherited);
    // 短名保持 baseFont；长名乘保险系数防亚像素溢出（字号仍 ≥ 4×0.95）
    final double renderFont = (font >= baseFont) ? baseFont : font * _safeRatio;
    final TextStyle style = _style(inherited, renderFont);

    // 始终 2 行：输入已受 channelNameMaxLength 限制在物理容量内，
    // 二分字号保证完整显示；仅超限旧数据触发 clip 裁切兜底。
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.clip,
          style: style,
        ),
      ),
    );
  }
}