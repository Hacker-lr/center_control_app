import 'dart:async';
import 'package:flutter/material.dart';
import '../services/device_config.dart';

/// ============================================================
/// 通用方形按钮组件
/// 用于摄像头控制页的摄像头选择和预置位按钮
/// 支持自定义长按触发改名对话框（时长由 DeviceConfig 控制）
/// 文字使用FittedBox自适应缩放，确保完全显示
/// 所有颜色与交互参数取自 DeviceConfig 全局配置
/// ============================================================
class SquareButton extends StatefulWidget {
  /// 按钮显示的标签文字
  final String label;

  /// 是否高亮显示（选中状态）
  final bool isActive;

  /// 激活颜色（选中状态的颜色）
  final Color activeColor;

  /// 按钮尺寸（正方形）
  final double size;

  /// 点击回调函数
  final VoidCallback onTap;

  /// 长按回调函数，可选；若为空则禁用长按功能
  final VoidCallback? onLongPress;

  /// 构造函数
  const SquareButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.size,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<SquareButton> createState() => _SquareButtonState();
}

class _SquareButtonState extends State<SquareButton> {
  /// 长按计时器，用于控制长按进度和触发时机
  Timer? _longPressTimer;

  /// 当前是否处于按下状态
  bool _isPressing = false;

  /// 长按是否已触发（防止重复触发）
  bool _longPressTriggered = false;

  /// 长按进度值（0.0 ~ 1.0）
  double _pressProgress = 0.0;

  /// DeviceConfig 实例，用于访问配置参数
  final DeviceConfig _config = DeviceConfig();

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  /// ============================================================
  /// 开始按下，启动长按计时器
  /// 仅在设置了 onLongPress 回调时生效
  /// ============================================================
  void _onTapDown(TapDownDetails details) {
    if (widget.onLongPress == null) return;

    setState(() {
      _isPressing = true;
      _longPressTriggered = false;
      _pressProgress = 0.0;
    });

    _longPressTimer = Timer.periodic(
      Duration(milliseconds: _config.longPressTickIntervalMs),
      (timer) {
        setState(() {
          _pressProgress = timer.tick *
              _config.longPressTickIntervalMs /
              _config.longPressDurationMs;
        });
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

  /// ============================================================
  /// 释放时取消计时器，仅在未触发长按的情况下调用点击事件
  /// ============================================================
  void _onTapUp(TapUpDetails details) {
    _cancelLongPress();
    if (!_longPressTriggered) {
      widget.onTap();
    }
  }

  /// ============================================================
  /// 取消时取消计时器（如手指移出按钮区域）
  /// ============================================================
  void _onTapCancel() {
    _cancelLongPress();
  }

  /// ============================================================
  /// 取消长按计时器并重置状态
  /// ============================================================
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
    final double borderRadius = widget.size * 0.2;
    final double shadowBlur = widget.size * 0.18;
    final double smallShadowBlur = widget.size * 0.08;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: Duration(milliseconds: DeviceConfig.animationDurationMs),
        curve: Curves.easeInOut,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: widget.isActive
              ? widget.activeColor.withAlpha(230)
              : const Color(0xFF2A2A3E),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: widget.activeColor.withAlpha(100),
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
            color: _isPressing
                ? DeviceConfig.colorPressing
                : (widget.isActive
                    ? widget.activeColor
                    : const Color(0xFF3A3F48)),
            width: _isPressing ? 2.0 : (widget.isActive ? 2.0 : 1.0),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isPressing)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(borderRadius),
                    bottomRight: Radius.circular(borderRadius),
                  ),
                  child: LinearProgressIndicator(
                    value: _pressProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        DeviceConfig.colorPressing),
                    minHeight: DeviceConfig.longPressIndicatorHeight,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(widget.size * 0.1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.size * 0.45,
                    fontWeight: FontWeight.w700,
                    color: widget.isActive ? Colors.white : Colors.grey[400],
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
