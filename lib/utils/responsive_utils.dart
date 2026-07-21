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

  /// 获取屏幕最短边长度
  /// 
  /// [context] - BuildContext上下文，用于获取MediaQuery信息
  /// 返回屏幕宽度和高度中的较小值，用于判断设备类型
  static double getShortestSide(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide;
  }

  /// 根据屏幕最短边判断设备类型
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕尺寸信息
  /// 返回对应的DeviceType枚举值：mobile/tablet/desktop
  /// 判断逻辑：
  ///   - shortestSide >= 1024 → desktop（桌面设备）
  ///   - shortestSide >= 600 → tablet（平板设备）
  ///   - 其他 → mobile（移动设备）
  static DeviceType getDeviceType(BuildContext context) {
    final double shortestSide = getShortestSide(context);
    // 桌面设备：最短边 >= 1024px
    if (shortestSide >= 1024) return DeviceType.desktop;
    // 平板设备：最短边 >= 600px
    if (shortestSide >= 600) return DeviceType.tablet;
    // 移动设备：最短边 < 600px
    return DeviceType.mobile;
  }

  /// 根据设备类型返回对应的缩放值
  /// 
  /// [context] - BuildContext上下文，用于获取设备类型
  /// [mobile] - 移动端使用的值
  /// [tablet] - 平板端使用的值
  /// [desktop] - 桌面端使用的值
  /// 返回与当前设备类型匹配的值
  static double scaleByDevice(BuildContext context, double mobile, double tablet, double desktop) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  /// 根据屏幕宽度进行线性缩放
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕宽度
  /// [baseValue] - 基准值（基于320px宽度的设计值）
  /// [minWidth] - 最小屏幕宽度（默认320px），低于此值按最小比例计算
  /// [maxWidth] - 最大屏幕宽度（默认1920px），高于此值按最大比例计算
  /// 返回缩放后的值，缩放范围为基准值的80%~140%
  static double scaleByScreenWidth(BuildContext context, double baseValue, {double minWidth = 320, double maxWidth = 1920}) {
    final double width = getScreenWidth(context);
    // 计算当前宽度相对于最小宽度的比例
    final double ratio = (width - minWidth) / (maxWidth - minWidth);
    // 将比例限制在0.0~1.0之间，防止超出边界
    final double clampedRatio = ratio.clamp(0.0, 1.0);
    // 根据比例线性插值：基准值的80% + 比例 * 基准值的60%
    return baseValue * (0.8 + clampedRatio * 0.6);
  }

  /// 根据屏幕高度进行线性缩放
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕高度
  /// [baseValue] - 基准值（基于480px高度的设计值）
  /// [minHeight] - 最小屏幕高度（默认480px），低于此值按最小比例计算
  /// [maxHeight] - 最大屏幕高度（默认1080px），高于此值按最大比例计算
  /// 返回缩放后的值，缩放范围为基准值的80%~140%
  static double scaleByScreenHeight(BuildContext context, double baseValue, {double minHeight = 480, double maxHeight = 1080}) {
    final double height = getScreenHeight(context);
    // 计算当前高度相对于最小高度的比例
    final double ratio = (height - minHeight) / (maxHeight - minHeight);
    // 将比例限制在0.0~1.0之间，防止超出边界
    final double clampedRatio = ratio.clamp(0.0, 1.0);
    // 根据比例线性插值：基准值的80% + 比例 * 基准值的60%
    return baseValue * (0.8 + clampedRatio * 0.6);
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

  /// 获取分屏预览区域的高度
  /// 
  /// [context] - BuildContext上下文，用于获取屏幕高度
  /// 返回分屏预览区域的高度，为屏幕高度的28%
  static double getSplitScreenPreviewHeight(BuildContext context) {
    final double screenHeight = getScreenHeight(context);
    // 分屏预览区域占屏幕高度的28%
    return screenHeight * 0.28;
  }
}

/// 设备类型枚举
/// 
/// 用于区分不同屏幕尺寸的设备，以便应用不同的UI布局策略
enum DeviceType {
  /// 移动设备：屏幕最短边 < 600px
  mobile,
  /// 平板设备：屏幕最短边 >= 600px 且 < 1024px
  tablet,
  /// 桌面设备：屏幕最短边 >= 1024px
  desktop,
}
