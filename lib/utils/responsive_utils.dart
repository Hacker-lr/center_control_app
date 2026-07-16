import 'package:flutter/widgets.dart';

class ResponsiveUtils {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getShortestSide(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide;
  }

  static DeviceType getDeviceType(BuildContext context) {
    final double shortestSide = getShortestSide(context);
    if (shortestSide >= 600) return DeviceType.tablet;
    if (shortestSide >= 1024) return DeviceType.desktop;
    return DeviceType.mobile;
  }

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

  static double scaleByScreenWidth(BuildContext context, double baseValue, {double minWidth = 320, double maxWidth = 1920}) {
    final double width = getScreenWidth(context);
    final double ratio = (width - minWidth) / (maxWidth - minWidth);
    final double clampedRatio = ratio.clamp(0.0, 1.0);
    return baseValue * (0.8 + clampedRatio * 0.6);
  }

  static double scaleByScreenHeight(BuildContext context, double baseValue, {double minHeight = 480, double maxHeight = 1080}) {
    final double height = getScreenHeight(context);
    final double ratio = (height - minHeight) / (maxHeight - minHeight);
    final double clampedRatio = ratio.clamp(0.0, 1.0);
    return baseValue * (0.8 + clampedRatio * 0.6);
  }

  static double getPowerButtonSize(BuildContext context) {
    final double screenWidth = getScreenWidth(context);
    final double screenHeight = getScreenHeight(context);
    final double minDimension = screenWidth < screenHeight ? screenWidth : screenHeight;
    return (minDimension * 0.35).clamp(100.0, 180.0);
  }

  static double getChannelButtonSize(BuildContext context) {
    final double screenWidth = getScreenWidth(context);
    const double maxButtonsPerRow = 8;
    final double availableWidth = screenWidth - 48;
    final double widthBasedSize = (availableWidth - (maxButtonsPerRow - 1) * 6) / maxButtonsPerRow;
    return widthBasedSize.clamp(38.0, 68.0);
  }

  static double getFontSize(BuildContext context, double baseSize) {
    final double screenWidth = getScreenWidth(context);
    final double ratio = screenWidth / 375;
    return (baseSize * ratio).clamp(baseSize * 0.7, baseSize * 1.2);
  }

  static double getSpacing(BuildContext context, double baseSpacing) {
    final double screenWidth = getScreenWidth(context);
    final double ratio = screenWidth / 375;
    return (baseSpacing * ratio).clamp(baseSpacing * 0.6, baseSpacing * 1.2);
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    final double screenWidth = getScreenWidth(context);
    if (screenWidth > 1024) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.15);
    } else if (screenWidth > 600) {
      return EdgeInsets.symmetric(horizontal: screenWidth * 0.1);
    }
    return const EdgeInsets.symmetric(horizontal: 16);
  }

  static double getSplitScreenPreviewHeight(BuildContext context) {
    final double screenHeight = getScreenHeight(context);
    return screenHeight * 0.28;
  }
}

enum DeviceType {
  mobile,
  tablet,
  desktop,
}