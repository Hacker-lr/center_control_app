import 'package:flutter/material.dart';
import '../services/camera_connection.dart';
import '../services/device_config.dart';
import '../services/base_connection.dart';
import '../services/channel_name_manager.dart';
import '../utils/responsive_utils.dart';
import '../utils/rename_dialog.dart';
import '../widgets/square_button.dart';

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

class _CameraControlPageState extends State<CameraControlPage> {
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

  /// 当前预置位模式：0=调用模式，1=保存模式
  int _presetMode = 0;

  /// 当前激活的预置位编号（用于显示选中状态，null 表示未激活）
  int? _activePreset;

  /// 摄像头连接管理器（单例），管理所有摄像头的互斥连接
  final CameraConnectionManager _cameraManager = CameraConnectionManager();

  /// 预置位名称管理器（单例）
  final ChannelNameManager _nameManager = ChannelNameManager();

  final DeviceConfig _config = DeviceConfig();

  /// 根据当前速度模式获取实际速度值
  /// 速度值范围：1-24（VISCA协议标准）
  int get _currentSpeed =>
      _speedMode == 0 ? _config.cameraSpeedLow : _config.cameraSpeedHigh;

  @override
  Widget build(BuildContext context) {
    // 使用 ListenableBuilder 监听摄像头连接管理器的状态变化
    // 当连接状态、选中摄像头等变化时自动刷新 UI
    return ListenableBuilder(
      listenable: _cameraManager,
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
    final status = _cameraManager.status;
    final activeCam = _cameraManager.activeCameraNumber;
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

  /// 摄像头选择事件：互斥切换连接目标
  void _onCameraSelected(int cameraNumber) {
    setState(() => _selectedCamera = cameraNumber);
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
          SizedBox(height: gap),
          GestureDetector(
            onTap: () {
              final conn = _cameraManager.activeConnection;
              if (conn != null) conn.zoomStop();
              setState(() => _activeZoom = null);
            },
            child: _buildZoomBtnBody(Icons.stop, '停止', false, btnSize),
          ),
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
          _buildSpeedBtn('低速', _speedMode == 0, () => setState(() => _speedMode = 0), btnSize),
          SizedBox(height: gap),
          _buildSpeedBtn('高速', _speedMode == 1, () => setState(() => _speedMode = 1), btnSize),
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
    final double screenWidth = ResponsiveUtils.getScreenWidth(context);
    final double screenHeight = ResponsiveUtils.getScreenHeight(context);
    final bool isLandscape = screenWidth > screenHeight;
    final double spacing = ResponsiveUtils.getSpacing(context, 4);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLargeToggleBtn('调用', _presetMode == 0, () => setState(() { _presetMode = 0; _activePreset = null; })),
            SizedBox(width: ResponsiveUtils.getSpacing(context, 16)),
            _buildLargeToggleBtn('保存', _presetMode == 1, () => setState(() { _presetMode = 1; _activePreset = null; })),
          ],
        ),
        SizedBox(height: spacing),
        Expanded(
          child: isLandscape
              ? _buildPresetLandscape(spacing)
              : _buildPresetPortrait(spacing),
        ),
      ],
    );
  }

  /// 根据屏幕宽度计算预置位按钮尺寸，确保横屏竖屏都能一行放下8个按钮
  double _getPresetButtonSize(BuildContext context) {
    final double screenWidth = ResponsiveUtils.getScreenWidth(context);
    final int presetCount = _config.cameraPresetCount;
    // 每个按钮之间留4的间距，留出页面内边距余量
    final double availableWidth = screenWidth * 0.90;
    final double spacing = 4;
    final double size = (availableWidth - (presetCount - 1) * spacing) / presetCount;
    return size.clamp(28.0, 55.0);
  }

  Widget _buildPresetPortrait(double spacing) {
    final double btnSize = _getPresetButtonSize(context);
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_config.cameraPresetCount, (index) {
            final int presetNum = index + 1;
            final bool isActive = _activePreset == presetNum;
            final String label = _nameManager.getCameraPresetName(presetNum);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: SquareButton(
                label: label,
                size: btnSize,
                isActive: isActive,
                activeColor: const Color(0xFF3E6B48),
                onTap: () => _onPresetTapped(presetNum),
                onLongPress: () => _showPresetRenameDialog(presetNum),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPresetLandscape(double spacing) {
    final double btnSize = _getPresetButtonSize(context);
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_config.cameraPresetCount, (index) {
            final int presetNum = index + 1;
            final bool isActive = _activePreset == presetNum;
            final String label = _nameManager.getCameraPresetName(presetNum);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: SquareButton(
                label: label,
                size: btnSize,
                isActive: isActive,
                activeColor: const Color(0xFF3E6B48),
                onTap: () => _onPresetTapped(presetNum),
                onLongPress: () => _showPresetRenameDialog(presetNum),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLargeToggleBtn(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getSpacing(context, 20), vertical: ResponsiveUtils.getSpacing(context, 10)),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1F4068).withAlpha(220) : const Color(0xFF1E2228),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? const Color(0xFF6B9BD2) : const Color(0xFF3A3F48), width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF1F4068).withAlpha(60), blurRadius: 8)] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: ResponsiveUtils.getFontSize(context, 14), fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.grey[500])),
      ),
    );
  }

  // ==================== 事件处理 ====================

  void _onDirectionDown(String direction) {
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
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    conn.panTiltStop();
    setState(() => _activeDirection = null);
  }

  void _onZoomDown(String action) {
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
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    conn.zoomStop();
    setState(() => _activeZoom = null);
  }

  void _onPresetTapped(int presetNum) {
    final conn = _cameraManager.activeConnection;
    if (conn == null) return;
    setState(() => _activePreset = presetNum);
    if (_presetMode == 0) {
      conn.presetRecall(presetNum);
    } else {
      conn.presetSave(presetNum);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() => _activePreset = null);
        }
      });
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
