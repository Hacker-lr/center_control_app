import 'package:flutter/widgets.dart';

/// 响应式工具类，提供屏幕尺寸、设备类型判断及自适应缩放功能
/// 
/// 用于在不同设备（手机、平板、桌面）上实现UI元素的自适应布局，
/// 确保应用在各种屏幕尺寸下都能良好展示。
class ResponsiveUtils {
  /// 获取屏幕宽度
  /// 
  /// [context] - BuildContext上下文，用于获取MediaQuery信息
  /// 返回屏幕的实际宽度（像素值）
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// 获取屏幕高度
  /// 
  /// [context] - BuildContext上下文，用于获取MediaQuery信息
  /// 返回屏幕的实际高度（像素值）
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// 获取电源按钮的尺寸
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕尺寸
  /// 返回电源按钮的尺寸（正方形边长），范围为100~180px
  /// 计算方式：屏幕最小维度的35%，但限制在100~180px之间
  static double getPowerButtonSize(BuildContext context) {
    final double screenWidth = getScreenWidth(context);
    final double screenHeight = getScreenHeight(context);
    // 获取屏幕宽度和高度中的较小值作为最小维度
    final double minDimension = screenWidth < screenHeight ? screenWidth : screenHeight;
    // 取最小维度的35%，并限制在100~180px范围内
    return (minDimension * 0.35).clamp(100.0, 180.0);
  }

  /// 获取通道按钮的尺寸
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕宽度
  /// [buttonsPerRow] - 每行显示的按钮数量（默认4个），支持4或8
  /// 返回通道按钮的尺寸（正方形边长），范围为35~100px（4列）或35~50px（8列）
  /// 根据每行按钮数量动态调整尺寸和间距：
  ///   - 4列：使用95%屏幕宽度，间距8px，最大尺寸100px
  ///   - 8列：使用92%屏幕宽度，间距6px，最大尺寸50px
  static double getChannelButtonSize(BuildContext context, {int buttonsPerRow = 4}) {
    final double screenWidth = getScreenWidth(context);
    // 根据每行按钮数量调整可用宽度比例：4列使用95%，8列使用92%
    final double widthFactor = buttonsPerRow == 4 ? 0.95 : 0.92;
    // 计算实际可用宽度
    final double availableWidth = screenWidth * widthFactor;
    // 根据每行按钮数量调整间距：4列时间距8px，8列时间距6px
    final double spacing = buttonsPerRow == 4 ? 8 : 6;
    // 计算基于宽度的按钮尺寸：(可用宽度 - 间距总和) / 按钮数量
    final double widthBasedSize = (availableWidth - (buttonsPerRow - 1) * spacing) / buttonsPerRow;
    // 根据每行按钮数量设置最大尺寸：4列最大100px，8列最大50px
    final double maxSize = buttonsPerRow == 4 ? 100.0 : 50.0;
    // 将尺寸限制在最小35px和对应最大尺寸之间
    return widthBasedSize.clamp(35.0, maxSize);
  }

  /// 获取自适应字体大小
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕宽度
  /// [baseSize] - 基准字体大小（基于375px宽度的设计值）
  /// 返回缩放后的字体大小，范围为基准大小的70%~120%
  /// 计算方式：以375px宽度为基准，按比例缩放
  static double getFontSize(BuildContext context, double baseSize) {
    final double screenWidth = getScreenWidth(context);
    // 计算当前宽度相对于375px基准宽度的比例
    final double ratio = screenWidth / 375;
    // 将字体大小限制在基准大小的70%~120%之间
    return (baseSize * ratio).clamp(baseSize * 0.7, baseSize * 1.2);
  }

  /// 获取自适应间距大小
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕宽度
  /// [baseSpacing] - 基准间距大小（基于375px宽度的设计值）
  /// 返回缩放后的间距大小，范围为基准间距的60%~120%
  /// 计算方式：以375px宽度为基准，按比例缩放
  static double getSpacing(BuildContext context, double baseSpacing) {
    final double screenWidth = getScreenWidth(context);
    // 计算当前宽度相对于375px基准宽度的比例
    final double ratio = screenWidth / 375;
    // 将间距大小限制在基准间距的60%~120%之间
    return (baseSpacing * ratio).clamp(baseSpacing * 0.6, baseSpacing * 1.2);
  }

  /// 获取页面边距
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕宽度
  /// 返回针对不同屏幕宽度的水平边距EdgeInsets：
  ///   - 桌面设备（>1024px）：屏幕宽度的15%
  ///   - 平板设备（>600px）：屏幕宽度的10%
  ///   - 移动设备：固定16px
  static EdgeInsets getPagePadding(BuildContext context) {
    final double screenWidth = getScreenWidth(context);
    // 桌面设备：边距为屏幕宽度的15%
    if (screenWidth > 1024) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.15);
    } 
    // 平板设备：边距为屏幕宽度的10%
    else if (screenWidth > 600) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.1);
    }
    // 移动设备：固定16px边距
    return const EdgeInsets.symmetric(horizontal: 16);
  }
}
