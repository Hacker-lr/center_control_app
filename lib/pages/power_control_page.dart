import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/base_connection.dart';
import '../services/device_connection.dart';
import '../services/device_config.dart';
import '../services/crestron_cip_connection.dart';
import '../utils/responsive_utils.dart';
import '../widgets/crestron_status_chip.dart';

/// ============================================================
/// 电源控制页面
/// 页面功能：
///   - 时序电源控制区块（原有）：提供电源开/关两个圆形按钮
///   - 大屏电源控制区块（新增）：提供大屏开/大屏关两个圆形按钮，
///     真正受控设备为大屏电箱内的 PLC（参考 LED_Leyard_PWR.usp）
/// 两个区块的显隐由 DeviceConfig 的 showTimingPowerControl /
/// showLedPowerControl 控制（在系统配置页"电源页区块显示"中勾选）。
/// 连接管理：时序电源经 DeviceConnection，大屏 PLC 经 DeviceConnection
/// ============================================================
class PowerControlPage extends StatefulWidget {
  const PowerControlPage({super.key});

  @override
  State<PowerControlPage> createState() => _PowerControlPageState();
}

class _PowerControlPageState extends State<PowerControlPage> {
  /// 时序电源开按钮的激活状态标志
  bool _isPowerOnActive = false;

  /// 时序电源关按钮的激活状态标志
  bool _isPowerOffActive = false;

  /// 大屏电源（PLC）开按钮的激活状态标志
  bool _isLedOnActive = false;

  /// 大屏电源（PLC）关按钮的激活状态标志
  bool _isLedOffActive = false;

  /// 时序电源设备连接管理（单例，DeviceProfile.timingPower）
  final DeviceConnection _deviceConnection = DeviceConnection.timingPower;

  /// 大屏电箱 PLC（LED 电源）连接管理（单例，DeviceProfile.ledPower）
  final DeviceConnection _ledConnection = DeviceConnection.ledPower;

  /// 设备配置实例
  final DeviceConfig _config = DeviceConfig();

  /// Crestron CIP 连接（单例，Crestron 模式下按钮发 join 给中控）
  final CrestronCipConnection _cip = CrestronCipConnection();

  @override
  Widget build(BuildContext context) {
    // 使用 ListenableBuilder 监听两个设备连接状态与 CIP 状态变化，自动刷新 UI
    return ListenableBuilder(
      listenable: Listenable.merge([_deviceConnection, _ledConnection, _cip]),
      builder: (context, child) {
        // 是否显示某个区块（由配置页勾选决定）
        final bool showTiming = _config.showTimingPowerControl;
        final bool showLed = _config.showLedPowerControl;

        // SafeArea：确保内容不被系统状态栏遮挡
        return SafeArea(
          // SizedBox.expand：占满整个屏幕可用空间
          child: SizedBox.expand(
            // Padding：页面整体内边距，使用响应式工具计算
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              // Column：垂直布局，从上到下依次排列各区域
              child: Column(
                children: [
                  // 顶部间距；其余内容（chip行+卡片+状态文字）整页放进
                  // Expanded 内的 SCV，resize 动画的极矮中间帧下整页可滚动，
                  // 不会因固定项总和溢出 Column 而闪现黄黑条。
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 12)),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 卡片最大宽度：可用宽度的 90%，上限 1000
                        // 桌面窗口下封顶 1000，左右留白让卡片在容器中居中
                        final double cardMaxW = math.min(
                          constraints.maxWidth * 0.9,
                          1000.0,
                        );
                        // 当前可见的卡片数量（两个都未启用时按 1 算，给 _buildEmptyHint 留位置）
                        int cardCount =
                            (showTiming ? 1 : 0) + (showLed ? 1 : 0);
                        if (cardCount == 0) cardCount = 1;
                        // 区块间垂直间隔
                        final double blockGap = ResponsiveUtils.getSpacing(
                          context,
                          16,
                        );
                        // 卡片内边距
                        final double cardPad = ResponsiveUtils.getSpacing(
                          context,
                          16,
                        );
                        // 标题块高度：Text 实际占位 = fontSize × lineHeight（默认 ~1.4），
                        // 之前只算 fontSize+spacing 偏小，导致卡片底部溢出 3~10px。
                        // 这里用 1.4 倍行高系数校正，并给标题下方间距也乘 1.2 倍。
                        final double titleFontSize =
                            ResponsiveUtils.getFontSize(context, 14);
                        final double titleSpacing = ResponsiveUtils.getSpacing(
                          context,
                          12,
                        );
                        final double titleBlock =
                            titleFontSize * 1.4 + titleSpacing * 1.2;
                        // 按钮区域可用尺寸
                        final double contentW = cardMaxW - 2 * cardPad;
                        final double btnGap = ResponsiveUtils.getSpacing(
                          context,
                          12,
                        );
                        final double btnFromW = (contentW - btnGap) / 2;
                        // 按钮最小尺寸（与下方 clamp 下限一致）：矮窗时按钮不再缩小，
                        // 因此卡片内容存在最小高度。若卡片预算高度均分出的 perCardH
                        // 小于该最小高度，卡片内容会超出显式 height 而溢出（黄黑条）。
                        // 这里给 perCardH 设下限，保证卡片内部内容永不溢出。
                        const double minBtnSize = 56.0;
                        final double minContentH =
                            2 * cardPad + titleBlock + minBtnSize + 6;
                        // 整页 SCV 内固定项（chip行+状态文字+间距）高度估算。
                        // chipRow 是 Container(padding 5×2 + Icon 14 + Text 11)，
                        // statusText 是 Text fontSize ~14.4 × lineHeight ~1.3。
                        // 矮视口下预算可能为负，钳制到 0，由 perCardH 下限保证内容装得下，
                        // 整页 Column 交给 SCV 滚动，永不溢出。
                        const double chipRowEstH = 26.0;
                        const double statusEstH = 22.0;
                        const double midGap = 12.0;
                        const double bottomGap = 24.0;
                        final double fixedEstH =
                            chipRowEstH + statusEstH + midGap * 2 + bottomGap;
                        final double cardsBudgetH =
                            math.max(constraints.maxHeight - fixedEstH, 0.0);
                        // 高度方向按卡片区预算高度均分；不低于最小内容高度。
                        final double perCardH = math.max(
                          (cardsBudgetH - blockGap * (cardCount - 1)) /
                              cardCount,
                          minContentH,
                        );
                        // btnFromH 再减 6px 安全余量，防 Text 行高波动、图标字形
                        // ascent/descent 差异导致卡片底部溢出（实测大屏电源卡片
                        // 因 cast_connected 图标垂直对齐问题会多溢出 ~7px）
                        final double btnFromH =
                            perCardH - 2 * cardPad - titleBlock - 6;
                        // 按钮尺寸：取宽/高上限的较小值，桌面下封顶 180
                        // （用户要求"开/关按钮像原来那样"），窄窗自动缩小，下限 56
                        final double btnSize = math
                            .min(btnFromW, btnFromH)
                            .clamp(minBtnSize, 180.0);

                        // 卡片组：固定宽度 cardMaxW，内部 Column 居中
                        // 每张卡片显式传 height=perCardH，避免依赖
                        // IntrinsicHeight 隐式高度时 Container 底部 1px 边框
                        // 因布局精度被裁掉的问题
                        Widget cardsWidget = Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 两个区块都未启用时显示提示
                            if (!showTiming && !showLed)
                              _buildEmptyHint()
                            else ...[
                              if (showTiming)
                                _buildPowerControlsCard(
                                  btnSize: btnSize,
                                  height: perCardH,
                                ),
                              if (showTiming && showLed)
                                SizedBox(height: blockGap),
                              if (showLed)
                                _buildLedPowerControlsCard(
                                  btnSize: btnSize,
                                  height: perCardH,
                                ),
                            ],
                          ],
                        );

                        // 整页内容（chip行+卡片+状态文字）放进 SCV + Column：
                        // 任何高度下 SCV 内 Column 永无界，固定项总和不再溢出
                        // 闪现黄黑条（与矩阵页/大屏页"整体可滚动"机制一致）。
                        // ConstrainedBox(minHeight=视口) 让内容不足时填满居中。
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildConnectionStatusIndicator(),
                                const SizedBox(height: midGap),
                                Center(
                                  child: SizedBox(
                                    width: cardMaxW,
                                    child: cardsWidget,
                                  ),
                                ),
                                const SizedBox(height: midGap),
                                _buildStatusText(),
                                const SizedBox(height: bottomGap),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 构建无可用区块时的占位提示
  /// 当两个控制区块都被关闭时显示，引导用户前往系统配置开启
  /// ============================================================
  Widget _buildEmptyHint() {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Text(
        '当前电源页未启用任何控制区块\n请前往「系统配置 → 电源页区块显示」开启',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(context, 13),
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建电源控制卡片（时序电源控制区块）
  /// 返回一个带标题和两个圆形按钮的卡片容器
  /// [btnSize] 由外层 LayoutBuilder 根据实际可用空间反算，确保整体跟随窗口缩放
  /// [height] 显式卡片高度（=perCardH），避免 Container 隐式高度在
  /// IntrinsicHeight 嵌套下少算 1-2px 导致底部边框被裁
  /// ============================================================
  Widget _buildPowerControlsCard({
    required double btnSize,
    required double height,
  }) {
    return Container(
      height: height,
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 卡片标题："时序电源控制"
          Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.getSpacing(context, 12),
            ),
            child: Text(
              '时序电源控制',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 2.0,
              ),
            ),
          ),
          // 按钮行：水平排列电源开和电源关两个圆形按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 电源开按钮：绿色主题，点击发送电源开启指令
              _buildPowerButton(
                '电源开',
                Icons.power_settings_new,
                _isPowerOnActive,
                const Color(0xFF1B5E20),
                () => _handlePowerOn(),
                btnSize: btnSize,
              ),
              // 电源关按钮：红色主题，点击发送电源关闭指令
              _buildPowerButton(
                '电源关',
                Icons.power_off,
                _isPowerOffActive,
                const Color(0xFF8B0000),
                () => _handlePowerOff(),
                btnSize: btnSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建大屏电源控制卡片（大屏电箱 PLC 控制区块）
  /// 标题"大屏电源控制"，含大屏开/大屏关两个圆形按钮
  /// [btnSize] 由外层 LayoutBuilder 根据实际可用空间反算
  /// [height] 显式卡片高度（=perCardH），避免底部边框被裁
  /// ============================================================
  Widget _buildLedPowerControlsCard({
    required double btnSize,
    required double height,
  }) {
    return Container(
      height: height,
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 卡片标题："大屏电源控制"
          Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.getSpacing(context, 12),
            ),
            child: Text(
              '大屏电源控制',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 2.0,
              ),
            ),
          ),
          // 按钮行：水平排列大屏开和大屏关两个圆形按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 大屏开按钮：绿色主题，点击发送大屏电源开启指令
              _buildPowerButton(
                '大屏开',
                Icons.cast_connected,
                _isLedOnActive,
                const Color(0xFF1B5E20),
                () => _handleLedOn(),
                btnSize: btnSize,
              ),
              // 大屏关按钮：红色主题，点击发送大屏电源关闭指令
              _buildPowerButton(
                '大屏关',
                Icons.cast,
                _isLedOffActive,
                const Color(0xFF8B0000),
                () => _handleLedOff(),
                btnSize: btnSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建连接状态指示器
  /// Crestron 模式下统一使用全局 Crestron 状态芯片；
  /// 否则按勾选情况展示时序电源 / 大屏 PLC 各自的连接状态芯片
  /// ============================================================
  Widget _buildConnectionStatusIndicator() {
    // Crestron 模式下统一使用全局 Crestron 状态芯片
    if (_config.crestronMode) {
      return const CrestronStatusChip();
    }
    final List<Widget> chips = [];
    if (_config.showTimingPowerControl) {
      chips.add(_buildSingleStatusChip('时序电源', _deviceConnection.status));
    }
    if (_config.showLedPowerControl) {
      chips.add(_buildSingleStatusChip('大屏电源', _ledConnection.status));
    }
    // 没有任何区块被启用时，给出中性提示
    if (chips.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withAlpha(60), width: 1),
        ),
        child: Text(
          '未启用任何控制区块',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, 12),
            color: Colors.grey[500],
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chips
          .map(
            (c) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getSpacing(context, 5),
              ),
              child: c,
            ),
          )
          .toList(),
    );
  }

  /// ============================================================
  /// 构建单个设备的连接状态芯片
  /// 根据连接状态 [status] 显示不同的文本、颜色和图标
  /// ============================================================
  Widget _buildSingleStatusChip(String label, ConnectionStatus status) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '$label已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '$label连接中';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '$label连接失败';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
        break;
      default:
        statusText = '$label未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(DeviceConfig.statusChipBorderRadius),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建圆形电源控制按钮（时序电源与大屏电源共用）
  /// [label] 按钮文字（如"电源开"、"大屏开"）
  /// [icon] 按钮图标
  /// [isActive] 是否激活状态（激活时显示高亮效果）
  /// [activeColor] 激活时的主题颜色
  /// [onPressed] 点击回调函数
  /// [btnSize] 按钮直径（外层 LayoutBuilder 算好后传入，确保跟随窗口缩放）
  /// ============================================================
  Widget _buildPowerButton(
    String label,
    IconData icon,
    bool isActive,
    Color activeColor,
    VoidCallback onPressed, {
    required double btnSize,
  }) {
    // 图标大小为按钮尺寸的 30%
    final double iconSize = btnSize * 0.3;
    // 文字大小与按钮尺寸成比例（封顶 16、底 12）
    final double fontSize = math.min(16.0, math.max(12.0, btnSize * 0.11));

    return GestureDetector(
      onTap: onPressed,
      // 尺寸用外层 SizedBox 固定（resize 时立即到位，不做动画）——
      // 若把 width/height 放在 AnimatedContainer，窗口 resize 时按钮会播放
      // 300ms 尺寸插值动画，中间帧按钮尺寸偏大而卡片高度已按新尺寸重算，
      // 导致卡片内容瞬时溢出黄黑条（"全屏切窗口瞬间闪现"的根因）。
      // AnimatedContainer 仅保留 decoration（颜色/阴影/边框）平滑过渡。
      child: SizedBox(
        width: btnSize,
        height: btnSize,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // 圆形按钮装饰
          decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 激活时使用主题色，非激活时使用深色背景
          color: isActive
              ? activeColor.withAlpha(220)
              : const Color(0xFF1E2228),
          // 激活时显示发光效果，非激活时显示阴影效果
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(80),
                    blurRadius: btnSize * 0.12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: btnSize * 0.06,
                    offset: const Offset(0, 4),
                  ),
                ],
          // 激活时边框加粗并使用主题色
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFF3A3F48),
            width: isActive ? 2.5 : 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Icon(
                icon,
                size: iconSize,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
              // 文字标签
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建底部状态提示文字
  /// 根据时序电源 / 大屏电源 按钮的激活状态动态显示不同的提示信息
  /// 使用 AnimatedSwitcher 实现文字切换动画
  /// ============================================================
  Widget _buildStatusText() {
    // 优先级：时序电源 > 大屏电源
    String tipText = '请点击按钮发送控制指令';
    if (_isPowerOnActive) {
      tipText = '电源已开启 — 指令已发送';
    } else if (_isPowerOffActive) {
      tipText = '电源已关闭 — 指令已发送';
    } else if (_isLedOnActive) {
      tipText = '大屏电源已开启 — 指令已发送';
    } else if (_isLedOffActive) {
      tipText = '大屏电源已关闭 — 指令已发送';
    }

    // AnimatedSwitcher：文字切换时带淡入淡出动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        tipText,
        // key 必须不同才能触发动画
        key: ValueKey(tipText),
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(context, 12),
          color: Colors.grey[500],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// ============================================================
  /// 处理电源开按钮点击事件（时序电源）
  /// 1. 更新按钮状态：开启开按钮，关闭关按钮
  /// 2. 根据配置选择指令格式（ASCII 或 16进制）
  /// 3. 发送电源开启指令到设备
  /// ============================================================
  void _handlePowerOn() {
    // 更新按钮激活状态
    setState(() {
      _isPowerOnActive = true;
      _isPowerOffActive = false;
    });
    // Crestron VTP 模式：向中控发送"电源开"数字 join 脉冲
    if (_config.crestronMode) {
      _cip.pulse(_config.joinPowerOn);
      return;
    }
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOnCmd
        : _config.powerOnAsciiCmd;
    // 发送指令到设备
    _deviceConnection.sendCommand(command);
  }

  /// ============================================================
  /// 处理电源关按钮点击事件（时序电源）
  /// 1. 更新按钮状态：开启关按钮，关闭开按钮
  /// 2. 根据配置选择指令格式（ASCII 或 16进制）
  /// 3. 发送电源关闭指令到设备
  /// ============================================================
  void _handlePowerOff() {
    // 更新按钮激活状态
    setState(() {
      _isPowerOffActive = true;
      _isPowerOnActive = false;
    });
    // Crestron VTP 模式：向中控发送"电源关"数字 join 脉冲
    if (_config.crestronMode) {
      _cip.pulse(_config.joinPowerOff);
      return;
    }
    // 根据配置选择指令格式
    final String command = _config.powerSendAsHex
        ? _config.hexPowerOffCmd
        : _config.powerOffAsciiCmd;
    // 发送指令到设备
    _deviceConnection.sendCommand(command);
  }

  /// ============================================================
  /// 处理大屏开按钮点击事件（大屏电箱 PLC）
  /// 1. 更新按钮状态：开启大屏开按钮，关闭大屏关按钮
  /// 2. Crestron 模式发送"大屏电源开"join 脉冲，否则发送开指令到 PLC
  /// ============================================================
  void _handleLedOn() {
    // 更新按钮激活状态
    setState(() {
      _isLedOnActive = true;
      _isLedOffActive = false;
    });
    // Crestron VTP 模式：向中控发送"大屏电源开"数字 join 脉冲
    if (_config.crestronMode) {
      _cip.pulse(_config.joinLedPowerOn);
      return;
    }
    // 根据配置选择指令格式（参考 LED_Leyard_PWR.usp）
    final String command = _config.ledPowerSendAsHex
        ? _config.hexLedPowerOnCmd
        : _config.ledPowerOnAsciiCmd;
    // 发送开指令到 PLC
    _ledConnection.sendCommand(command);
  }

  /// ============================================================
  /// 处理大屏关按钮点击事件（大屏电箱 PLC）
  /// 1. 更新按钮状态：开启大屏关按钮，关闭大屏开按钮
  /// 2. Crestron 模式发送"大屏电源关"join 脉冲，否则发送关指令到 PLC
  /// ============================================================
  void _handleLedOff() {
    // 更新按钮激活状态
    setState(() {
      _isLedOffActive = true;
      _isLedOnActive = false;
    });
    // Crestron VTP 模式：向中控发送"大屏电源关"数字 join 脉冲
    if (_config.crestronMode) {
      _cip.pulse(_config.joinLedPowerOff);
      return;
    }
    // 根据配置选择指令格式（参考 LED_Leyard_PWR.usp）
    final String command = _config.ledPowerSendAsHex
        ? _config.hexLedPowerOffCmd
        : _config.ledPowerOffAsciiCmd;
    // 发送关指令到 PLC
    _ledConnection.sendCommand(command);
  }
}
