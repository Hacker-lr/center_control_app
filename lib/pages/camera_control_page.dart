import 'package:flutter/material.dart';
import '../services/camera_connection.dart';
import '../services/device_config.dart';
import '../services/base_connection.dart';
import '../services/crestron_cip_connection.dart';
import '../services/channel_name_manager.dart';
import '../utils/responsive_utils.dart';
import '../utils/channel_rename_dialog.dart';
import '../widgets/square_button.dart';
import '../widgets/crestron_status_chip.dart';

/// ============================================================
/// 摄像头控制页面
/// 基于 Sony VISCA over IP 协议实现云台、变焦、预置位控制
/// 竖屏布局：连接状态 → 摄像头选择 → 云台控制 → 变焦/速度 → 预置位
/// 横屏布局：顶部(连接状态+摄像头选择) → 左侧(云台控制) + 右侧(变焦/速度/预置位)
/// 交互：方向键和变焦键支持按压持续移动、松开停止
/// ============================================================
class CameraControlPage extends StatefulWidget {
  const CameraControlPage({super.key});

  @override
  State<CameraControlPage> createState() => _CameraControlPageState();
}

class _CameraControlPageState extends State<CameraControlPage>
    with SingleTickerProviderStateMixin {
  /// 当前选中的摄像头编号（1-based）
  int _selectedCamera = 1;

  /// 当前速度模式：0=低速，1=高速
  int _speedMode = 1;

  /// 当前激活的方向键（用于云台控制，null 表示未激活）
  /// 可选值：'up'、'down'、'left'、'right'
  String? _activeDirection;

  /// 当前激活的变焦操作（null 表示未激活）
  /// 可选值：'tele'（放大）、'wide'（缩小）
  String? _activeZoom;

  /// 保存待命状态：点击「保存」按钮后为 true（按钮呼吸闪烁），
  /// 此时点击数字按键 = 保存该预置位并退出待命；
  /// 未待命时点击数字按键 = 直接调用该预置位
  bool _savePending = false;

  /// 保存按钮呼吸闪烁动画控制器
  late final AnimationController _saveBlinkController;

  /// 当前激活的预置位编号（用于显示选中状态，null 表示未激活）
  int? _activePreset;

  @override
  void initState() {
    super.initState();
    // 呼吸闪烁：0.9 秒一个来回，进入保存待命时循环播放
    _saveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _saveBlinkController.dispose();
    super.dispose();
  }

  /// 摄像头连接管理器（单例），管理所有摄像头的互斥连接
  final CameraConnectionManager _cameraManager = CameraConnectionManager();

  /// 预置位名称管理器（单例）
  final ChannelNameManager _nameManager = ChannelNameManager();

  final DeviceConfig _config = DeviceConfig();

  /// Crestron CIP 连接（单例，Crestron 模式下按钮发 join 给中控）
  final CrestronCipConnection _cip = CrestronCipConnection();

  /// 根据当前速度模式获取实际速度值
  /// 速度值范围：1-24（VISCA协议标准）
  int get _currentSpeed =>
      _speedMode == 0 ? _config.cameraSpeedLow : _config.cameraSpeedHigh;

  @override
  Widget build(BuildContext context) {
    // 使用 ListenableBuilder 监听摄像头连接管理器的状态变化
    // 当连接状态、选中摄像头等变化时自动刷新 UI
    return ListenableBuilder(
      // 监听 _config 以在配置页修改预置位个数/摄像头列表后即时刷新本页
      listenable: Listenable.merge([_cameraManager, _config, _cip]),
      builder: (context, child) {
        // SafeArea：确保内容不被系统状态栏遮挡
        return SafeArea(
          // SizedBox.expand：占满整个屏幕可用空间
          child: SizedBox.expand(
            // Padding：页面整体内边距，使用响应式工具计算
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              // LayoutBuilder：根据父容器约束动态选择布局
              // 通过判断宽高比决定使用竖屏还是横屏布局
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 判断是否横屏：宽度大于高度即为横屏
                  final bool isLandscape = constraints.maxWidth > constraints.maxHeight;
                  // 根据屏幕方向返回对应的布局
                  return isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== 竖屏布局 ====================

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        _buildConnectionStatus(),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        _buildCameraSelection(),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        Expanded(
          flex: 5,
          child: _buildSectionCardExpandable(
            label: '云台控制',
            child: _buildDirectionPad(),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        Expanded(
          flex: 2,
          child: _buildSectionCardExpandable(
            label: '变焦 / 速度',
            child: _buildZoomAndSpeed(),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        Expanded(
          flex: 2,
          child: _buildSectionCardExpandable(
            label: '预置位',
            child: _buildPresetSection(),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 8)),
      ],
    );
  }

  // ==================== 横屏布局 ====================

  Widget _buildLandscapeLayout() {
    return Column(
      children: [
        SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
        // 顶部：连接状态居中
        Center(child: _buildConnectionStatus()),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 4)),
        // 顶部：摄像头选择居中
        Center(child: _buildCameraSelectionLandscape()),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
        // 主体：左侧云台控制 + 右侧变焦/速度/预置位
        Expanded(
          child: Row(
            children: [
              // 左侧：云台控制（缩小占比）
              Expanded(
                flex: 2,
                child: _buildSectionCardExpandable(
                  label: '云台控制',
                  child: _buildDirectionPad(),
                ),
              ),
              SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
              // 右侧：变焦+速度 + 预置位（增大占比）
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildSectionCardExpandable(
                        label: '变焦 / 速度',
                        child: _buildZoomAndSpeed(),
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
                    Expanded(
                      flex: 3,
                      child: _buildSectionCardExpandable(
                        label: '预置位',
                        child: _buildPresetSection(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, 6)),
      ],
    );
  }

  // ==================== 通用卡片组件 ====================

  Widget _buildSectionCardExpandable({required String label, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 8)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getSpacing(context, 4),
              bottom: ResponsiveUtils.getSpacing(context, 6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ==================== 连接状态 ====================

  Widget _buildConnectionStatus() {
    // Crestron 模式下统一使用全局 Crestron 状态芯片
    if (_config.crestronMode) {
      return const CrestronStatusChip();
    }
    final ConnectionStatus status = _cameraManager.status;
    final int activeCam = _cameraManager.activeCameraNumber;
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '摄像头$activeCam已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
      case ConnectionStatus.connecting:
        statusText = '正在连接摄像头$activeCam...';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
      case ConnectionStatus.error:
        statusText = '摄像头$activeCam连接失败';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
      case ConnectionStatus.disconnected:
        statusText = '摄像头未连接';
        statusColor = Colors.grey[500]!;
        statusIcon = Icons.link_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 4),
          Text(statusText,
              style: TextStyle(
                  fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==================== 摄像头选择 ====================

  /// 竖屏摄像头选择（水平居中排列）
  /// 点击时互斥切换连接：选中新摄像头，断开旧摄像头
  /// 支持长按改名，文字自适应缩放
  Widget _buildCameraSelection() {
    final double btnSize = ResponsiveUtils.getChannelButtonSize(context);
    final double spacing = ResponsiveUtils.getSpacing(context, 8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_config.cameraDevices.length, (index) {
        final int camNum = index + 1;
        final bool isSelected = _selectedCamera == camNum;
        final String label = _nameManager.getCameraName(camNum);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: SquareButton(
            label: label,
            size: btnSize,
            isActive: isSelected,
            activeColor: const Color(0xFF1F4068),
            onTap: () => _onCameraSelected(camNum),
            onLongPress: () => _showCameraRenameDialog(camNum),
          ),
        );
      }),
    );
  }

  /// 横屏摄像头选择（紧凑排列）
  /// 支持长按改名，文字自适应缩放
  Widget _buildCameraSelectionLandscape() {
    final double btnSize = ResponsiveUtils.getChannelButtonSize(context) * 0.85;
    final double spacing = ResponsiveUtils.getSpacing(context, 6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_config.cameraDevices.length, (index) {
        final int camNum = index + 1;
        final bool isSelected = _selectedCamera == camNum;
        final String label = _nameManager.getCameraName(camNum);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: SquareButton(
            label: label,
            size: btnSize,
            isActive: isSelected,
            activeColor: const Color(0xFF1F4068),
            onTap: () => _onCameraSelected(camNum),
            onLongPress: () => _showCameraRenameDialog(camNum),
          ),
        );
      }),
    );
  }

  /// 摄像头选择事件：
  /// - Crestron 模式：脉冲「摄像机选择基址+X」数字 join，由中控切换目标摄像机
  /// - 直连模式：互斥切换本地 VISCA 连接目标
  void _onCameraSelected(int cameraNumber) {
    setState(() => _selectedCamera = cameraNumber);
    if (_config.crestronMode) {
      _cip.pulse(_config.joinCamSelectBase + cameraNumber);
      return;
    }
    _cameraManager.connectCamera(cameraNumber);
  }

  // ==================== 云台方向控制 ====================

  Widget _buildDirectionPad() {
    final double btnSize = _getPtzButtonSize(context);
    final double gap = ResponsiveUtils.getSpacing(context, 4);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: btnSize + gap),
              _buildDirBtn(Icons.arrow_upward, 'up', btnSize),
              SizedBox(width: btnSize + gap),
            ],
          ),
          SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirBtn(Icons.arrow_back, 'left', btnSize),
              SizedBox(width: gap),
              SizedBox(width: btnSize, height: btnSize),
              SizedBox(width: gap),
              _buildDirBtn(Icons.arrow_forward, 'right', btnSize),
            ],
          ),
          SizedBox(height: gap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: btnSize + gap),
              _buildDirBtn(Icons.arrow_downward, 'down', btnSize),
              SizedBox(width: btnSize + gap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirBtn(IconData icon, String direction, double size) {
    final isActive = _activeDirection == direction;
    return GestureDetector(
      onTapDown: (_) => _onDirectionDown(direction),
      onTapUp: (_) => _onDirectionUp(),
      onTapCancel: () => _onDirectionUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          color: isActive ? const Color(0xFF3E6B48).withAlpha(220) : const Color(0xFF2A2A3E),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0xFF3E6B48).withAlpha(80), blurRadius: 8)]
              : [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
          border: Border.all(color: isActive ? const Color(0xFF3E6B48) : const Color(0xFF3A3F48), width: isActive ? 2.0 : 1.0),
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.grey[400], size: size * 0.45),
      ),
    );
  }

  double _getPtzButtonSize(BuildContext context) {
    final double screenWidth = ResponsiveUtils.getScreenWidth(context);
    final double screenHeight = ResponsiveUtils.getScreenHeight(context);
    final bool isLandscape = screenWidth > screenHeight;
    final double referenceDimension = isLandscape ? screenHeight : screenWidth;
    return (referenceDimension * 0.18).clamp(50.0, 90.0);
  }

  // ==================== 变焦控制 ====================

  Widget _buildZoomButtons() {
    final double btnSize = _getPtzButtonSize(context) * 0.55;
    final double gap = ResponsiveUtils.getSpacing(context, 8);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomBtn(Icons.add, '放大', 'tele', btnSize),
          SizedBox(height: gap),
          _buildZoomBtn(Icons.remove, '缩小', 'wide', btnSize),
        ],
      ),
    );
  }

  Widget _buildZoomBtn(IconData icon, String label, String action, double btnSize) {
    final isActive = _activeZoom == action;
    return GestureDetector(
      onTapDown: (_) => _onZoomDown(action),
      onTapUp: (_) => _onZoomUp(),
      onTapCancel: () => _onZoomUp(),
      child: _buildZoomBtnBody(icon, label, isActive, btnSize),
    );
  }

  Widget _buildZoomBtnBody(IconData icon, String label, bool isActive, double btnSize) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: btnSize * 2.2,
      height: btnSize * 0.9,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(btnSize * 0.2),
        color: isActive ? const Color(0xFF3E6B48).withAlpha(220) : const Color(0xFF2A2A3E),
        boxShadow: isActive
            ? [BoxShadow(color: const Color(0xFF3E6B48).withAlpha(80), blurRadius: 8)]
            : [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
        border: Border.all(color: isActive ? const Color(0xFF3E6B48) : const Color(0xFF3A3F48), width: isActive ? 2.0 : 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? Colors.white : Colors.grey[400], size: btnSize * 0.4),
          SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: btnSize * 0.28, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.grey[400])),
        ],
      ),
    );
  }

  // ==================== 变焦 + 速度（合并） ====================

  Widget _buildZoomAndSpeed() {
    return Row(
      children: [
        // 左：变焦控制
        Expanded(child: _buildZoomButtons()),
        SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
        // 右：速度选择
        Expanded(child: _buildSpeedToggle()),
      ],
    );
  }

  // ==================== 速度选择 ====================

  Widget _buildSpeedToggle() {
    final double btnSize = _getPtzButtonSize(context) * 0.55;
    final double gap = ResponsiveUtils.getSpacing(context, 8);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSpeedBtn('低速', _speedMode == 0, () => _onSpeedModeChanged(0), btnSize),
          SizedBox(height: gap),
          _buildSpeedBtn('高速', _speedMode == 1, () => _onSpeedModeChanged(1), btnSize),
        ],
      ),
    );
  }

  Widget _buildSpeedBtn(String label, bool isActive, VoidCallback onTap, double btnSize) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: btnSize * 2.2,
        height: btnSize * 0.9,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(btnSize * 0.2),
          color: isActive ? const Color(0xFF3E6B48).withAlpha(220) : const Color(0xFF2A2A3E),
          boxShadow: isActive
              ? [BoxShadow(color: const Color(0xFF3E6B48).withAlpha(80), blurRadius: 8)]
              : [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
          border: Border.all(color: isActive ? const Color(0xFF3E6B48) : const Color(0xFF3A3F48), width: isActive ? 2.0 : 1.0),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontSize: btnSize * 0.28, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.grey[400])),
        ),
      ),
    );
  }

  // ==================== 预置位 ====================

  Widget _buildPresetSection() {
    final double spacing = ResponsiveUtils.getSpacing(context, 4);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSaveToggleBtn(),
          ],
        ),
        SizedBox(height: spacing),
        Expanded(
          child: _buildPresetRow(spacing),
        ),
      ],
    );
  }

  /// 每行预置位数量：不超过 8 个时单行排列；超过 8 个（最多 16）时自动分两行，
  /// 每行最多 8 个
  int get _presetsPerRow =>
      _config.cameraPresetCount > 8 ? 8 : _config.cameraPresetCount;

  /// 根据屏幕宽度计算预置位按钮尺寸
  /// 尺寸以「每行数量」为基准计算，保证单行(≤8)或两行(>8)都能完整放下
  double _getPresetButtonSize(BuildContext context) {
    final double screenWidth = ResponsiveUtils.getScreenWidth(context);
    final int perRow = _presetsPerRow;
    // 每个按钮之间留4的间距，留出页面内边距余量
    final double availableWidth = screenWidth * 0.90;
    final double spacing = 4;
    final double size = (availableWidth - (perRow - 1) * spacing) / perRow;
    return size.clamp(28.0, 55.0);
  }

  /// 构建预置位按钮区域（横屏/竖屏共用同一布局，仅外层容器不同）
  /// 预置位个数 ≤8 时单行排列；>8 时按每行 8 个分成多行排列
  /// [spacing] 按钮之间的水平/垂直间距
  Widget _buildPresetRow(double spacing) {
    final double btnSize = _getPresetButtonSize(context);
    final int count = _config.cameraPresetCount;
    final int perRow = _presetsPerRow;
    // 计算总行数（向上取整）
    final int rowCount = (count / perRow).ceil();

    // 逐行构建预置位按钮
    final List<Widget> rows = [];
    for (int r = 0; r < rowCount; r++) {
      final int start = r * perRow;
      final int end = (start + perRow) < count ? (start + perRow) : count;
      final List<Widget> buttons = [];
      for (int i = start; i < end; i++) {
        final int presetNum = i + 1;
        final bool isActive = _activePreset == presetNum;
        final String label = _nameManager.getCameraPresetName(presetNum);
        buttons.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: SquareButton(
              label: label,
              size: btnSize,
              isActive: isActive,
              activeColor: const Color(0xFF3E6B48),
              onTap: () => _onPresetTapped(presetNum),
              onLongPress: () => _showPresetRenameDialog(presetNum),
            ),
          ),
        );
      }
      rows.add(
        SizedBox(
          // 行宽固定为「整行容量」(每行满 8 个时的总宽)，使非满行(如第 2 行)
          // 从左侧开始排列；整块由外层 Center 在容器中水平居中
          width: perRow * (btnSize + spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: buttons,
          ),
        ),
      );
    }

    // 多行垂直排列（行之间留水平方向的同款间距），外层允许垂直滚动
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: spacing),
              rows[r],
            ],
          ],
        ),
      ),
    );
  }

  /// 保存按钮：
  /// - 未待命：常规样式，点击进入保存待命（开始呼吸闪烁）
  /// - 待命中：仅呼吸闪烁提示（颜色/发光随动画脉动），
  ///   按钮尺寸与文案保持不变；再次点击可取消待命
  Widget _buildSaveToggleBtn() {
    return GestureDetector(
      onTap: _onSaveBtnTapped,
      child: AnimatedBuilder(
        animation: _saveBlinkController,
        builder: (context, child) {
          // 呼吸系数 0.0~1.0（正弦式来回），仅在待命时有效
          final double t = _savePending ? _saveBlinkController.value : 0.0;
          // 颜色在暗橙与亮橙之间脉动，未待命时为常规灰蓝
          final Color baseColor = _savePending
              ? Color.lerp(
                  const Color(0xFF7A4A12), const Color(0xFFFFA726), t)!
              : const Color(0xFF1E2228);
          final Color borderColor = _savePending
              ? Color.lerp(
                  const Color(0xFFB37728), const Color(0xFFFFC46B), t)!
              : const Color(0xFF3A3F48);
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getSpacing(context, 20),
              vertical: ResponsiveUtils.getSpacing(context, 10),
            ),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
              // 边框宽度固定，避免待命/常态切换时按钮尺寸发生变化
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: _savePending
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFA726)
                            .withAlpha((40 + 120 * t).round()),
                        blurRadius: 6 + 10 * t,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.save_outlined,
                  size: ResponsiveUtils.getFontSize(context, 15),
                  color: _savePending ? Colors.white : Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  // 文案固定为「保存」，待命状态仅靠呼吸闪烁提示，
                  // 避免文字变化导致按钮宽度改变
                  '保存',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: _savePending ? Colors.white : Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 保存按钮点击：切换保存待命状态，并启动/停止呼吸动画
  /// Crestron 模式下同时脉冲「保存按钮」数字 join，向中控上报按键事件
  void _onSaveBtnTapped() {
    if (_config.crestronMode) {
      _cip.pulse(_config.joinCamSaveBtn);
    }
    setState(() {
      _savePending = !_savePending;
      _activePreset = null;
    });
    if (_savePending) {
      _saveBlinkController.repeat(reverse: true);
    } else {
      _saveBlinkController.stop();
      _saveBlinkController.value = 0;
    }
  }

  // ==================== 事件处理 ====================

  /// 方向键 → 数字 join 映射（Crestron VTP 模式用）
  int _camDirJoin(String direction) {
    switch (direction) {
      case 'up': return _config.joinCamUp;
      case 'down': return _config.joinCamDown;
      case 'left': return _config.joinCamLeft;
      case 'right': return _config.joinCamRight;
    }
    return _config.joinCamUp;
  }

  void _onDirectionDown(String direction) {
    // Crestron VTP 模式：按住 = press 数字 join
    if (_config.crestronMode) {
      _cip.press(_camDirJoin(direction));
      setState(() => _activeDirection = direction);
      return;
    }
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    int panDir = 3;
    int tiltDir = 3;
    switch (direction) {
      case 'up':    tiltDir = 1; break;
      case 'down':  tiltDir = 2; break;
      case 'left':  panDir = 1; break;
      case 'right': panDir = 2; break;
    }
    conn.panTiltMove(_currentSpeed, _currentSpeed, panDir, tiltDir);
    setState(() => _activeDirection = direction);
  }

  void _onDirectionUp() {
    // Crestron VTP 模式：松开 = release 对应的数字 join
    if (_config.crestronMode) {
      final String? dir = _activeDirection;
      if (dir != null) _cip.release(_camDirJoin(dir));
      setState(() => _activeDirection = null);
      return;
    }
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    conn.panTiltStop();
    setState(() => _activeDirection = null);
  }

  void _onZoomDown(String action) {
    // Crestron VTP 模式：按住 = press 对应变焦数字 join
    if (_config.crestronMode) {
      _cip.press(
        action == 'tele' ? _config.joinCamTele : _config.joinCamWide,
      );
      setState(() => _activeZoom = action);
      return;
    }
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    if (action == 'tele') {
      conn.zoomTele();
    } else {
      conn.zoomWide();
    }
    setState(() => _activeZoom = action);
  }

  void _onZoomUp() {
    // Crestron VTP 模式：松开 = release 对应变焦数字 join
    if (_config.crestronMode) {
      if (_activeZoom == 'tele') {
        _cip.release(_config.joinCamTele);
      } else if (_activeZoom == 'wide') {
        _cip.release(_config.joinCamWide);
      }
      setState(() => _activeZoom = null);
      return;
    }
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    conn.zoomStop();
    setState(() => _activeZoom = null);
  }

  /// 速度切换：
  /// - Crestron 模式：低速/高速各自脉冲独立的数字 join
  /// - 直连模式：仅更新本地速度值（发云台命令时生效）
  void _onSpeedModeChanged(int mode) {
    setState(() => _speedMode = mode);
    if (_config.crestronMode) {
      _cip.pulse(
        mode == 0 ? _config.joinCamSpeedLow : _config.joinCamSpeedHigh,
      );
    }
  }

  /// 数字按键点击：
  /// - 保存待命中 → 保存该预置位，退出待命（保存按钮熄灭）
  /// - 未待命 → 直接调用该预置位
  void _onPresetTapped(int presetNum) {
    final bool isSave = _savePending;

    // 执行发送（Crestron VTP 模式发 join 脉冲，否则走 VISCA 直连）
    // Crestron 模式下调用/保存发同一个预置位 join（基址+N）；
    // 保存语义由中控根据"保存按钮"join 的待命状态自行区分
    if (_config.crestronMode) {
      _cip.pulse(_config.joinCamPresetRecallBase + presetNum);
    } else {
      final conn = _cameraManager.activeConnection;
      if (conn == null) return;
      if (isSave) {
        conn.presetSave(presetNum);
      } else {
        conn.presetRecall(presetNum);
      }
    }

    if (isSave) {
      // 完成保存：退出待命，保存按钮熄灭；数字键短暂高亮后恢复
      _saveBlinkController.stop();
      _saveBlinkController.value = 0;
      setState(() {
        _savePending = false;
        _activePreset = presetNum;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _activePreset = null);
      });
    } else {
      // 调用：保持高亮标记当前调用的预置位
      setState(() => _activePreset = presetNum);
    }
  }

  /// ============================================================
  /// 显示摄像头重命名对话框
  /// 使用 showRenameDialog 函数，保存后更新到 ChannelNameManager
  /// ============================================================
  Future<void> _showCameraRenameDialog(int cameraNum) async {
    final String currentName = _nameManager.getCameraName(cameraNum);
    await showRenameDialog(
      context,
      typeName: '摄像头',
      channelNumber: cameraNum,
      currentName: currentName,
      onConfirm: (newName) async {
        await _nameManager.saveCameraName(cameraNum, newName);
        if (mounted) setState(() {});
      },
    );
  }

  /// ============================================================
  /// 显示预置位重命名对话框
  /// 使用 showRenameDialog 函数，保存后更新到 ChannelNameManager
  /// ============================================================
  Future<void> _showPresetRenameDialog(int presetNum) async {
    final String currentName = _nameManager.getCameraPresetName(presetNum);
    await showRenameDialog(
      context,
      typeName: '预置位',
      channelNumber: presetNum,
      currentName: currentName,
      onConfirm: (newName) async {
        await _nameManager.saveCameraPresetName(presetNum, newName);
        if (mounted) setState(() {});
      },
    );
  }
}
