import 'package:flutter/material.dart';
import '../services/device_config.dart';
import '../services/camera_connection.dart';
import '../widgets/config_form_widgets.dart';

/// ============================================================
/// 统一系统配置页面
/// 将"普通模式直连配置"与"中控 VTP 配置"整合到同一页面：
///  - 顶部 Crestron VTP 模式开关：开启后中控主机 / Join 映射分组就地显示（无跳转）
///  - 所有分组默认展开，点击标题可折叠
///  - 设备数量（矩阵通道、摄像头个数、预置位）并入各自设备分组，不再单独成组
/// ============================================================
class SystemConfigPage extends StatefulWidget {
  const SystemConfigPage({super.key});

  @override
  State<SystemConfigPage> createState() => _SystemConfigPageState();
}

class _SystemConfigPageState extends State<SystemConfigPage>
    with SingleTickerProviderStateMixin {
  final DeviceConfig _config = DeviceConfig();

  // ---- 受控设备配置 ----
  final TextEditingController _powerIpController = TextEditingController();
  final TextEditingController _powerPortController = TextEditingController();
  final TextEditingController _matrixIpController = TextEditingController();
  final TextEditingController _matrixPortController = TextEditingController();
  final TextEditingController _matrixInputCountController =
      TextEditingController();
  final TextEditingController _matrixOutputCountController =
      TextEditingController();
  final TextEditingController _bigScreenIpController = TextEditingController();
  final TextEditingController _bigScreenPortController =
      TextEditingController();
  final TextEditingController _ledPowerIpController = TextEditingController();
  final TextEditingController _ledPowerPortController = TextEditingController();
  final TextEditingController _cameraPresetCountController =
      TextEditingController();
  final List<TextEditingController> _bsOutputChannelControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  // ---- 中控主机 (CIP/SCIP) ----
  final TextEditingController _cipHostController = TextEditingController();
  final TextEditingController _cipPortController = TextEditingController();
  final TextEditingController _cipIpIdController = TextEditingController();
  final TextEditingController _cipUsernameController = TextEditingController();
  final TextEditingController _cipPasswordController = TextEditingController();

  // ---- 中控 Join 映射 ----
  final TextEditingController _joinPowerOnController = TextEditingController();
  final TextEditingController _joinPowerOffController = TextEditingController();
  final TextEditingController _joinLayoutFullController =
      TextEditingController();
  final TextEditingController _joinLayoutFull169Controller =
      TextEditingController();
  final TextEditingController _joinLayoutSplit2Controller =
      TextEditingController();
  final TextEditingController _joinLayoutSplit3Controller =
      TextEditingController();
  final TextEditingController _joinLayoutSplit4Controller =
      TextEditingController();
  final TextEditingController _joinLayoutSplit5Controller =
      TextEditingController();
  final TextEditingController _joinMatrixInputBaseController =
      TextEditingController();
  final TextEditingController _joinMatrixOutputBaseController =
      TextEditingController();
  final TextEditingController _joinCamSelectBaseController =
      TextEditingController();
  final TextEditingController _joinCamSpeedLowController =
      TextEditingController();
  final TextEditingController _joinCamSpeedHighController =
      TextEditingController();
  final TextEditingController _joinCamSaveBtnController =
      TextEditingController();
  final TextEditingController _joinCamUpController = TextEditingController();
  final TextEditingController _joinCamDownController = TextEditingController();
  final TextEditingController _joinCamLeftController = TextEditingController();
  final TextEditingController _joinCamRightController = TextEditingController();
  final TextEditingController _joinCamTeleController = TextEditingController();
  final TextEditingController _joinCamWideController = TextEditingController();
  final TextEditingController _joinCamPresetRecallBaseController =
      TextEditingController();
  final TextEditingController _joinLedPowerOnController =
      TextEditingController();
  final TextEditingController _joinLedPowerOffController =
      TextEditingController();

  /// 摄像头设备（直连 VISCA）控制器列表
  final List<Map<String, TextEditingController>> _cameraControllers = [];

  /// 每个摄像头对应的协议标记：true=TCP，false=UDP
  /// 与 _cameraControllers 一一对应
  final List<bool> _cameraUseTcp = [];

  // ---- 状态 ----
  bool _crestronMode = false;

  // ---- VTP 入场/退场动画控制器 ----
  // 打开：空间先展开（下方菜单整体下移），随后菜单缓缓淡入；
  // 关闭：菜单先淡出，控制器过半后空间才收起（下方菜单整体上移），与打开互为镜像。
  late final AnimationController _vtpAnimCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final Animation<double> _vtpFade = Tween<double>(begin: 0, end: 1)
      .animate(
        CurvedAnimation(
          parent: _vtpAnimCtrl,
          curve: const Interval(0.55, 1.0, curve: Curves.easeInOut),
        ),
      );
  // 时序电源分组：与 VTP 菜单反向——VTP 开时它淡出并收起，VTP 关时它展开并淡入
  late final Animation<double> _powerGroupFade = Tween<double>(begin: 1, end: 0)
      .animate(
        CurvedAnimation(
          parent: _vtpAnimCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
        ),
      );
  bool _powerUseTcp = true;
  bool _matrixUseTcp = true;
  bool _bigScreenUseTcp = true;
  bool _powerSendAsHex = false;
  bool _matrixSendAsHex = false;
  bool _bigScreenSendAsHex = false;
  bool _ledPowerUseTcp = true;
  bool _ledPowerSendAsHex = false;
  String _powerBrand = '默认品牌';
  String _matrixBrand = '默认品牌';
  String _bigScreenBrand = '默认品牌';
  String _ledPowerBrand = '利亚德';
  bool _showPowerControl = true;
  bool _showBigScreen = true;
  bool _showVideoMatrix = true;
  bool _showCameraControl = true;
  bool _showTimingPowerControl = true;
  bool _showLedPowerControl = true;
  bool _cipSecure = false;
  bool _showCrestronControl = true;

  /// 已折叠的分组集合；初始包含所有分组 → 默认全部收起，点击标题可展开
  final Set<String> _collapsed = {
    'crestron',
    'vtpJoin',
    'matrix',
    'bigScreen',
    'powerDevices',
    'camera',
    'pageVisibility',
  };
  bool _isExpanded(String name) => !_collapsed.contains(name);
  void _toggleGroup(String name) {
    setState(() {
      if (_collapsed.contains(name)) {
        _collapsed.remove(name);
      } else {
        _collapsed.add(name);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
    // 与当前模式对齐，避免首次进入时播放入场动画
    _vtpAnimCtrl.value = _crestronMode ? 1.0 : 0.0;
  }

  @override
  void dispose() {
    _vtpAnimCtrl.dispose();
    for (final c in [
      _powerIpController,
      _powerPortController,
      _matrixIpController,
      _matrixPortController,
      _matrixInputCountController,
      _matrixOutputCountController,
      _bigScreenIpController,
      _bigScreenPortController,
      _ledPowerIpController,
      _ledPowerPortController,
      _cameraPresetCountController,
      _cipHostController,
      _cipPortController,
      _cipIpIdController,
      _cipUsernameController,
      _cipPasswordController,
      _joinPowerOnController,
      _joinPowerOffController,
      _joinLayoutFullController,
      _joinLayoutFull169Controller,
      _joinLayoutSplit2Controller,
      _joinLayoutSplit3Controller,
      _joinLayoutSplit4Controller,
      _joinLayoutSplit5Controller,
      _joinMatrixInputBaseController,
      _joinMatrixOutputBaseController,
      _joinCamSelectBaseController,
      _joinCamSpeedLowController,
      _joinCamSpeedHighController,
      _joinCamSaveBtnController,
      _joinCamUpController,
      _joinCamDownController,
      _joinCamLeftController,
      _joinCamRightController,
      _joinCamTeleController,
      _joinCamWideController,
      _joinCamPresetRecallBaseController,
      _joinLedPowerOnController,
      _joinLedPowerOffController,
    ]) {
      c.dispose();
    }
    for (final c in _bsOutputChannelControllers) {
      c.dispose();
    }
    for (final ctrl in _cameraControllers) {
      ctrl['ip']?.dispose();
      ctrl['port']?.dispose();
      ctrl['viscaAddr']?.dispose();
    }
    super.dispose();
  }

  void _loadConfig() {
    _powerIpController.text = _config.powerDeviceIp;
    _powerPortController.text = '${_config.powerDevicePort}';
    _powerUseTcp = _config.powerUseTcp;
    _powerSendAsHex = _config.powerSendAsHex;
    _powerBrand = _config.powerBrand;
    _matrixIpController.text = _config.matrixDeviceIp;
    _matrixPortController.text = '${_config.matrixDevicePort}';
    _matrixUseTcp = _config.matrixUseTcp;
    _matrixSendAsHex = _config.matrixSendAsHex;
    _matrixBrand = _config.matrixBrand;
    _matrixInputCountController.text = '${_config.matrixInputCount}';
    _matrixOutputCountController.text = '${_config.matrixOutputCount}';
    _bigScreenIpController.text = _config.bigScreenDeviceIp;
    _bigScreenPortController.text = '${_config.bigScreenDevicePort}';
    _bigScreenUseTcp = _config.bigScreenUseTcp;
    _ledPowerIpController.text = _config.ledPowerDeviceIp;
    _ledPowerPortController.text = '${_config.ledPowerDevicePort}';
    _ledPowerUseTcp = _config.ledPowerUseTcp;
    _ledPowerSendAsHex = _config.ledPowerSendAsHex;
    _bigScreenSendAsHex = _config.bigScreenSendAsHex;
    _bigScreenBrand = _config.bigScreenBrand;
    _ledPowerBrand = _config.ledPowerBrand;
    _cameraPresetCountController.text = '${_config.cameraPresetCount}';
    final List<int> outCh = _config.bigScreenOutputChannels;
    for (int i = 0; i < _bsOutputChannelControllers.length; i++) {
      _bsOutputChannelControllers[i].text =
          '${i < outCh.length ? outCh[i] : (4 + i)}';
    }
    _showPowerControl = _config.showPowerControl;
    _showBigScreen = _config.showBigScreen;
    _showVideoMatrix = _config.showVideoMatrix;
    _showCameraControl = _config.showCameraControl;
    _showTimingPowerControl = _config.showTimingPowerControl;
    _showLedPowerControl = _config.showLedPowerControl;
    _crestronMode = _config.crestronMode;

    _cipHostController.text = _config.cipHost;
    _cipPortController.text = '${_config.cipPort}';
    _cipIpIdController.text = _config.cipIpId
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    _cipUsernameController.text = _config.cipUsername;
    _cipPasswordController.text = _config.cipPassword;
    _cipSecure = _config.cipSecure;
    _showCrestronControl = _config.showCrestronControl;

    _joinPowerOnController.text = '${_config.joinPowerOn}';
    _joinPowerOffController.text = '${_config.joinPowerOff}';
    _joinLayoutFullController.text = '${_config.joinLayoutFull}';
    _joinLayoutFull169Controller.text = '${_config.joinLayoutFull169}';
    _joinLayoutSplit2Controller.text = '${_config.joinLayoutSplit2}';
    _joinLayoutSplit3Controller.text = '${_config.joinLayoutSplit3}';
    _joinLayoutSplit4Controller.text = '${_config.joinLayoutSplit4}';
    _joinLayoutSplit5Controller.text = '${_config.joinLayoutSplit5}';
    _joinMatrixInputBaseController.text = '${_config.joinMatrixInputBase}';
    _joinMatrixOutputBaseController.text = '${_config.joinMatrixOutputBase}';
    _joinCamSelectBaseController.text = '${_config.joinCamSelectBase}';
    _joinCamSpeedLowController.text = '${_config.joinCamSpeedLow}';
    _joinCamSpeedHighController.text = '${_config.joinCamSpeedHigh}';
    _joinCamSaveBtnController.text = '${_config.joinCamSaveBtn}';
    _joinCamUpController.text = '${_config.joinCamUp}';
    _joinCamDownController.text = '${_config.joinCamDown}';
    _joinCamLeftController.text = '${_config.joinCamLeft}';
    _joinCamRightController.text = '${_config.joinCamRight}';
    _joinCamTeleController.text = '${_config.joinCamTele}';
    _joinCamWideController.text = '${_config.joinCamWide}';
    _joinCamPresetRecallBaseController.text =
        '${_config.joinCamPresetRecallBase}';
    _joinLedPowerOnController.text = '${_config.joinLedPowerOn}';
    _joinLedPowerOffController.text = '${_config.joinLedPowerOff}';

    _cameraControllers.clear();
    _cameraUseTcp.clear();
    for (var device in _config.cameraDevices) {
      _cameraControllers.add({
        'ip': TextEditingController(text: device['ip']),
        'port': TextEditingController(text: '${device['port']}'),
        'viscaAddr': TextEditingController(text: '${device['viscaAddr']}'),
      });
      _cameraUseTcp.add(device['useTcp'] == true);
    }
  }

  void _saveAll() {
    _config.setPowerDeviceIp(_powerIpController.text.trim());
    _config.setPowerDevicePort(
      int.tryParse(_powerPortController.text.trim()) ??
          ConfigDefaults.devicePort,
    );
    _config.setPowerUseTcp(_powerUseTcp);
    _config.setPowerSendAsHex(_powerSendAsHex);
    _config.setPowerBrand(_powerBrand);
    _config.setMatrixDeviceIp(_matrixIpController.text.trim());
    _config.setMatrixDevicePort(
      int.tryParse(_matrixPortController.text.trim()) ??
          ConfigDefaults.devicePort,
    );
    _config.setMatrixUseTcp(_matrixUseTcp);
    _config.setMatrixSendAsHex(_matrixSendAsHex);
    _config.setMatrixBrand(_matrixBrand);
    _config.setMatrixInputCount(
      int.tryParse(_matrixInputCountController.text.trim()) ??
          ConfigDefaults.matrixInputCount,
    );
    _config.setMatrixOutputCount(
      int.tryParse(_matrixOutputCountController.text.trim()) ??
          ConfigDefaults.matrixOutputCount,
    );
    _config.setBigScreenDeviceIp(_bigScreenIpController.text.trim());
    _config.setBigScreenDevicePort(
      int.tryParse(_bigScreenPortController.text.trim()) ??
          ConfigDefaults.devicePort,
    );
    _config.setBigScreenUseTcp(_bigScreenUseTcp);
    _config.setLedPowerDeviceIp(_ledPowerIpController.text.trim());
    _config.setLedPowerDevicePort(
      int.tryParse(_ledPowerPortController.text.trim()) ??
          ConfigDefaults.devicePort,
    );
    _config.setLedPowerUseTcp(_ledPowerUseTcp);
    _config.setLedPowerSendAsHex(_ledPowerSendAsHex);
    _config.setBigScreenSendAsHex(_bigScreenSendAsHex);
    _config.setBigScreenBrand(_bigScreenBrand);
    _config.setLedPowerBrand(_ledPowerBrand);
    _config.setCameraPresetCount(
      int.tryParse(_cameraPresetCountController.text.trim()) ??
          ConfigDefaults.cameraPresetCount,
    );
    _config.setShowPowerControl(_showPowerControl);
    _config.setShowBigScreen(_showBigScreen);
    _config.setShowVideoMatrix(_showVideoMatrix);
    _config.setShowCameraControl(_showCameraControl);
    _config.setShowTimingPowerControl(_showTimingPowerControl);
    _config.setShowLedPowerControl(_showLedPowerControl);
    _config.setCrestronMode(_crestronMode);

    _config.setCipHost(_cipHostController.text.trim());
    _config.setCipPort(
      int.tryParse(_cipPortController.text.trim()) ?? ConfigDefaults.cipPort,
    );
    _config.setCipIpId(
      int.tryParse(_cipIpIdController.text.trim(), radix: 16) ??
          ConfigDefaults.cipIpId,
    );
    _config.setCipSecure(_cipSecure);
    _config.setCipUsername(_cipUsernameController.text.trim());
    _config.setCipPassword(_cipPasswordController.text);
    _config.setShowCrestronControl(_showCrestronControl);

    _config.setJoinPowerOn(
      int.tryParse(_joinPowerOnController.text.trim()) ?? 1,
    );
    _config.setJoinPowerOff(
      int.tryParse(_joinPowerOffController.text.trim()) ?? 2,
    );
    _config.setJoinLayoutFull(
      int.tryParse(_joinLayoutFullController.text.trim()) ?? 552,
    );
    _config.setJoinLayoutFull169(
      int.tryParse(_joinLayoutFull169Controller.text.trim()) ?? 553,
    );
    _config.setJoinLayoutSplit2(
      int.tryParse(_joinLayoutSplit2Controller.text.trim()) ?? 554,
    );
    _config.setJoinLayoutSplit3(
      int.tryParse(_joinLayoutSplit3Controller.text.trim()) ?? 555,
    );
    _config.setJoinLayoutSplit4(
      int.tryParse(_joinLayoutSplit4Controller.text.trim()) ?? 556,
    );
    _config.setJoinLayoutSplit5(
      int.tryParse(_joinLayoutSplit5Controller.text.trim()) ?? 557,
    );
    _config.setJoinMatrixInputBase(
      int.tryParse(_joinMatrixInputBaseController.text.trim()) ?? 100,
    );
    _config.setJoinMatrixOutputBase(
      int.tryParse(_joinMatrixOutputBaseController.text.trim()) ?? 150,
    );
    _config.setJoinCamSelectBase(
      int.tryParse(_joinCamSelectBaseController.text.trim()) ?? 80,
    );
    _config.setJoinCamSpeedLow(
      int.tryParse(_joinCamSpeedLowController.text.trim()) ?? 37,
    );
    _config.setJoinCamSpeedHigh(
      int.tryParse(_joinCamSpeedHighController.text.trim()) ?? 38,
    );
    _config.setJoinCamSaveBtn(
      int.tryParse(_joinCamSaveBtnController.text.trim()) ?? 39,
    );
    _config.setJoinCamUp(int.tryParse(_joinCamUpController.text.trim()) ?? 30);
    _config.setJoinCamDown(
      int.tryParse(_joinCamDownController.text.trim()) ?? 31,
    );
    _config.setJoinCamLeft(
      int.tryParse(_joinCamLeftController.text.trim()) ?? 32,
    );
    _config.setJoinCamRight(
      int.tryParse(_joinCamRightController.text.trim()) ?? 33,
    );
    _config.setJoinCamTele(
      int.tryParse(_joinCamTeleController.text.trim()) ?? 34,
    );
    _config.setJoinCamWide(
      int.tryParse(_joinCamWideController.text.trim()) ?? 35,
    );
    _config.setJoinCamPresetRecallBase(
      int.tryParse(_joinCamPresetRecallBaseController.text.trim()) ?? 40,
    );
    _config.setJoinLedPowerOn(
      int.tryParse(_joinLedPowerOnController.text.trim()) ?? 23,
    );
    _config.setJoinLedPowerOff(
      int.tryParse(_joinLedPowerOffController.text.trim()) ?? 24,
    );

    final List<int> outCh = _bsOutputChannelControllers
        .map((c) => int.tryParse(c.text.trim()) ?? 0)
        .toList();
    _config.setBigScreenOutputChannels(outCh);

    List<Map<String, dynamic>> cameraDevices = [];
    for (var i = 0; i < _cameraControllers.length; i++) {
      var ctrl = _cameraControllers[i];
      cameraDevices.add({
        'ip': ctrl['ip']?.text.trim() ?? '192.168.0.${64 + i}',
        'port':
            int.tryParse(
              ctrl['port']?.text.trim() ?? '${ConfigDefaults.viscaPort}',
            ) ??
            ConfigDefaults.viscaPort,
        'viscaAddr': int.tryParse(ctrl['viscaAddr']?.text.trim() ?? '1') ?? 1,
        'useTcp': _cameraUseTcp[i],
      });
    }
    _config.setCameraDevices(cameraDevices);
    // 摄像头配置变更后立即重建连接实例，免去重启 App 才能生效的限制
    CameraConnectionManager().rebuild();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('配置保存成功！'),
          ],
        ),
        backgroundColor: DeviceConfig.colorStatusConnected,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addCamera() {
    setState(() {
      _cameraControllers.add({
        'ip': TextEditingController(
          text: '192.168.0.${64 + _cameraControllers.length}',
        ),
        'port': TextEditingController(text: '${ConfigDefaults.viscaPort}'),
        'viscaAddr': TextEditingController(text: '1'),
      });
      _cameraUseTcp.add(true);
    });
  }

  void _removeCamera(int index) {
    if (_cameraControllers.length <= 1) return;
    setState(() {
      _cameraControllers[index]['ip']?.dispose();
      _cameraControllers[index]['port']?.dispose();
      _cameraControllers[index]['viscaAddr']?.dispose();
      _cameraControllers.removeAt(index);
      _cameraUseTcp.removeAt(index);
    });
  }

  /// VTP 模式切换处理：仅写配置（持久化 + notifyListeners），
  /// 真正的“断开直连/连 CIP”或“重建并连接各直连设备”由 MainPage 的
  /// _onConfigChanged 监听统一执行——因此切换即生效，无需点保存。
  void _onVtpModeChanged(bool v) {
    setState(() => _crestronMode = v);
    _config.setCrestronMode(v);
    if (v) {
      _vtpAnimCtrl.forward();
    } else {
      _vtpAnimCtrl.reverse();
    }
  }

  /// 顶部 VTP 模式开关（美化版）：圆角胶囊背景 + 图标 + 文字 + 定制 Switch。
  /// 开启时胶囊染 accent 浅色描边，关闭时灰阶；切换即生效（无需保存），
  /// 真正的连接切换由 MainPage 的 _onConfigChanged 监听统一处理。
  Widget _buildVtpSwitch() {
    final bool on = _crestronMode;
    final Color accent = DeviceConfig.colorAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: on ? accent.withAlpha(26) : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: on ? accent.withAlpha(130) : Colors.white.withAlpha(28),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.view_quilt : Icons.view_quilt_outlined,
            size: 16,
            color: on ? accent : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            'VTP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? accent : Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: on,
            onChanged: _onVtpModeChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: accent,
            activeTrackColor: accent.withAlpha(120),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white.withAlpha(28),
          ),
        ],
      ),
    );
  }

  /// 顶部“保存”按钮（美化版）：圆角胶囊，accent 浅底 + accent 文字/图标，
  /// 与 VTP 开关同处一行右侧，明显区别于普通文本按钮。
  Widget _buildSaveButton() {
    final Color accent = DeviceConfig.colorAccent;
    return TextButton.icon(
      onPressed: _saveAll,
      icon: Icon(Icons.save_outlined, size: 22, color: accent),
      label: Text(
        '保存',
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: accent.withAlpha(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: Size.zero,
      ),
    );
  }

  /// 分区标题：左侧 accent 竖条 + 图标 + 文字，用于把配置页分成多个视觉分区
  /// （中控配置 / 设备直连配置 / 页面显示控制），使不同区域的菜单栏清晰隔开。
  Widget _buildZoneHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 10),
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: DeviceConfig.colorAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: DeviceConfig.colorAccent),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeviceConfig.colorCardBg,
      appBar: AppBar(
        // 增大工具栏高度，让顶部标题/开关/按钮整体下移、更宽松透气
        toolbarHeight: 66,
        backgroundColor: DeviceConfig.colorCardBg,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: const Text(
          '系统配置',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // VTP 模式开关（美化胶囊样式）：与“保存”同处一行右侧，切换即生效
          _buildVtpSwitch(),
          const SizedBox(width: 6),
          _buildSaveButton(),
          const SizedBox(width: 12),
        ],
        // 顶部与内容区的细分隔线，提升精致感
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withAlpha(14)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ===== 中控相关（仅 VTP 模式显示；打开=空间先展开、菜单后淡入，关闭=菜单先淡出、空间后收起，互为镜像）=====
            AnimatedBuilder(
              animation: _vtpAnimCtrl,
              builder: (context, _) {
                // 关闭时让空间晚一点收起：菜单先随控制器淡出，过半后再切换为 SizedBox
                final bool showColumn =
                    _crestronMode || _vtpAnimCtrl.value > 0.5;
                return AnimatedSize(
                  duration: const Duration(milliseconds: 380),
                  reverseDuration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  child: FadeTransition(
                    opacity: _vtpFade,
                    child: showColumn
                        ? Column(
                            key: const ValueKey('vtp_on'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildZoneHeader('中控配置', Icons.hub),
                              const SizedBox(height: 4),
                              buildGroupCard(
                                title: '中控主机 (CIP/SCIP)',
                                icon: Icons.memory,
                                isExpanded: _isExpanded('crestron'),
                                onToggle: () => _toggleGroup('crestron'),
                                children: [
                                  buildIpPortRow(
                                    label: 'Crestron 处理器',
                                    ipController: _cipHostController,
                                    portController: _cipPortController,
                                  ),
                                  buildInputRow(
                                    label: 'IP-ID（十六进制）',
                                    controller: _cipIpIdController,
                                    maxLength: 2,
                                  ),
                                  buildPageVisibilitySwitch(
                                    title: '安全 CIP (SCIP / 4系列)',
                                    value: _cipSecure,
                                    onChanged: (v) =>
                                        setState(() => _cipSecure = v),
                                  ),
                                  buildInputRow(
                                    label: '认证用户名',
                                    controller: _cipUsernameController,
                                    maxLength: 50,
                                  ),
                                  buildInputRow(
                                    label: '认证密码',
                                    controller: _cipPasswordController,
                                    maxLength: 50,
                                  ),
                                  buildPageVisibilitySwitch(
                                    title: '显示 Crestron 页面',
                                    value: _showCrestronControl,
                                    onChanged: (v) => setState(
                                      () => _showCrestronControl = v,
                                    ),
                                  ),
                                ],
                              ),
                              buildGroupCard(
                                title: '按钮 Join 映射',
                                icon: Icons.view_quilt,
                                isExpanded: _isExpanded('vtpJoin'),
                                onToggle: () => _toggleGroup('vtpJoin'),
                                children: [
                                  buildSectionLabel('电源'),
                                  buildDualInputRow(
                                    labelA: '电源开',
                                    controllerA: _joinPowerOnController,
                                    labelB: '电源关',
                                    controllerB: _joinPowerOffController,
                                  ),
                                  buildSectionLabel('大屏电源(PLC)'),
                                  buildDualInputRow(
                                    labelA: '大屏开',
                                    controllerA: _joinLedPowerOnController,
                                    labelB: '大屏关',
                                    controllerB: _joinLedPowerOffController,
                                  ),
                                  buildSectionLabel('大屏分屏模式'),
                                  buildDualInputRow(
                                    labelA: '全屏',
                                    controllerA: _joinLayoutFullController,
                                    labelB: '全屏16:9',
                                    controllerB: _joinLayoutFull169Controller,
                                  ),
                                  buildDualInputRow(
                                    labelA: '二分屏',
                                    controllerA: _joinLayoutSplit2Controller,
                                    labelB: '三分屏',
                                    controllerB: _joinLayoutSplit3Controller,
                                  ),
                                  buildDualInputRow(
                                    labelA: '四分屏',
                                    controllerA: _joinLayoutSplit4Controller,
                                    labelB: '五分屏',
                                    controllerB: _joinLayoutSplit5Controller,
                                  ),
                                  buildSectionLabel('矩阵'),
                                  buildDualInputRow(
                                    labelA: '矩阵输入基址 (+X)',
                                    controllerA: _joinMatrixInputBaseController,
                                    labelB: '矩阵输出基址 (+Y)',
                                    controllerB:
                                        _joinMatrixOutputBaseController,
                                  ),
                                  buildSectionLabel('摄像机'),
                                  buildInputRow(
                                    label: '摄像机选择基址 (+X)',
                                    controller: _joinCamSelectBaseController,
                                    isNumber: true,
                                    maxLength: 4,
                                  ),
                                  buildDualInputRow(
                                    labelA: '低速',
                                    controllerA: _joinCamSpeedLowController,
                                    labelB: '高速',
                                    controllerB: _joinCamSpeedHighController,
                                  ),
                                  buildDualInputRow(
                                    labelA: '保存',
                                    controllerA: _joinCamSaveBtnController,
                                    labelB: '云台上',
                                    controllerB: _joinCamUpController,
                                  ),
                                  buildDualInputRow(
                                    labelA: '云台下',
                                    controllerA: _joinCamDownController,
                                    labelB: '云台左',
                                    controllerB: _joinCamLeftController,
                                  ),
                                  buildDualInputRow(
                                    labelA: '云台右',
                                    controllerA: _joinCamRightController,
                                    labelB: '变焦放大',
                                    controllerB: _joinCamTeleController,
                                  ),
                                  buildDualInputRow(
                                    labelA: '变焦缩小',
                                    controllerA: _joinCamWideController,
                                    labelB: '预置位基址 (+N)',
                                    controllerB:
                                        _joinCamPresetRecallBaseController,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(key: ValueKey('vtp_off')),
                  ),
                );
              },
            ),

            // ===== 受控设备配置（始终显示，与中控配置分区隔开）=====
            _buildZoneHeader('受控设备配置', Icons.devices),
            const SizedBox(height: 2),
            buildGroupCard(
              title: '电源设备',
              icon: Icons.bolt,
              isExpanded: _isExpanded('powerDevices'),
              onToggle: () => _toggleGroup('powerDevices'),
              children: [
                buildSectionLabel('时序电源设备'),
                // 直连字段：VTP 开时先淡出、过半后收起；VTP 关时先展开再淡入
                AnimatedBuilder(
                  animation: _vtpAnimCtrl,
                  builder: (context, _) {
                    final bool showDirect =
                        !_crestronMode || _vtpAnimCtrl.value < 0.5;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      reverseDuration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                      child: FadeTransition(
                        opacity: _powerGroupFade,
                        child: showDirect
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildIpPortRow(
                                    label: '时序电源设备',
                                    ipController: _powerIpController,
                                    portController: _powerPortController,
                                  ),
                                  buildBrandDropdown(
                                    label: '设备品牌',
                                    currentValue: _powerBrand,
                                    brandNames: DeviceConfig.powerBrandConfigs
                                        .map((b) => b.name)
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _powerBrand = value;
                                        final config = DeviceConfig
                                            .powerBrandConfigs
                                            .firstWhere((b) => b.name == value);
                                        _powerPortController.text =
                                            '${config.port}';
                                        _powerUseTcp = config.useTcp;
                                        _powerSendAsHex = config.sendAsHex;
                                      });
                                    },
                                  ),
                                  buildProtocolSwitch(
                                    label: '通信协议',
                                    value: _powerUseTcp,
                                    onChanged: (value) =>
                                        setState(() => _powerUseTcp = value),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
                buildPageVisibilitySwitch(
                  title: '时序电源控制区块显示',
                  value: _showTimingPowerControl,
                  onChanged: (value) =>
                      setState(() => _showTimingPowerControl = value),
                ),
                buildSectionLabel('大屏电箱 PLC（LED 电源）'),
                // 直连字段：VTP 开时先淡出、过半后收起；VTP 关时先展开再淡入
                AnimatedBuilder(
                  animation: _vtpAnimCtrl,
                  builder: (context, _) {
                    final bool showDirect =
                        !_crestronMode || _vtpAnimCtrl.value < 0.5;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      reverseDuration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                      child: FadeTransition(
                        opacity: _powerGroupFade,
                        child: showDirect
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildIpPortRow(
                                    label: '大屏电箱 PLC',
                                    ipController: _ledPowerIpController,
                                    portController: _ledPowerPortController,
                                  ),
                                  buildBrandDropdown(
                                    label: '设备品牌',
                                    currentValue: _ledPowerBrand,
                                    brandNames: DeviceConfig
                                        .ledPowerBrandConfigs
                                        .map((b) => b.name)
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _ledPowerBrand = value;
                                        final config = DeviceConfig
                                            .ledPowerBrandConfigs
                                            .firstWhere((b) => b.name == value);
                                        _ledPowerPortController.text =
                                            '${config.port}';
                                        _ledPowerUseTcp = config.useTcp;
                                        _ledPowerSendAsHex = config.sendAsHex;
                                      });
                                    },
                                  ),
                                  buildProtocolSwitch(
                                    label: '通信协议',
                                    value: _ledPowerUseTcp,
                                    onChanged: (value) =>
                                        setState(() => _ledPowerUseTcp = value),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
                buildPageVisibilitySwitch(
                  title: '大屏电源控制区块显示',
                  value: _showLedPowerControl,
                  onChanged: (value) =>
                      setState(() => _showLedPowerControl = value),
                ),
              ],
            ),

            // ===== 设备直连配置（始终显示）=====
            buildGroupCard(
              title: '视频矩阵',
              icon: Icons.videocam_outlined,
              isExpanded: _isExpanded('matrix'),
              onToggle: () => _toggleGroup('matrix'),
              children: [
                AnimatedBuilder(
                  animation: _vtpAnimCtrl,
                  builder: (context, _) {
                    // 直连字段：VTP 开时先淡出、过半后收起；VTP 关时先展开再淡入
                    final bool showDirect =
                        !_crestronMode || _vtpAnimCtrl.value < 0.5;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      reverseDuration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                      child: FadeTransition(
                        opacity: _powerGroupFade,
                        child: showDirect
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildIpPortRow(
                                    label: '视频矩阵设备',
                                    ipController: _matrixIpController,
                                    portController: _matrixPortController,
                                  ),
                                  buildBrandDropdown(
                                    label: '设备品牌',
                                    currentValue: _matrixBrand,
                                    brandNames: DeviceConfig.matrixBrandConfigs
                                        .map((b) => b.name)
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _matrixBrand = value;
                                        final config = DeviceConfig
                                            .matrixBrandConfigs
                                            .firstWhere((b) => b.name == value);
                                        _matrixPortController.text =
                                            '${config.port}';
                                        _matrixUseTcp = config.useTcp;
                                        _matrixSendAsHex = config.sendAsHex;
                                      });
                                    },
                                  ),
                                  buildProtocolSwitch(
                                    label: '通信协议',
                                    value: _matrixUseTcp,
                                    onChanged: (value) =>
                                        setState(() => _matrixUseTcp = value),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
                buildChannelCountRow(
                  inputController: _matrixInputCountController,
                  outputController: _matrixOutputCountController,
                ),
              ],
            ),
            buildGroupCard(
              title: '大屏拼接器',
              icon: Icons.tv,
              isExpanded: _isExpanded('bigScreen'),
              onToggle: () => _toggleGroup('bigScreen'),
              children: [
                AnimatedBuilder(
                  animation: _vtpAnimCtrl,
                  builder: (context, _) {
                    // 直连字段：VTP 开时先淡出、过半后收起；VTP 关时先展开再淡入
                    final bool showDirect =
                        !_crestronMode || _vtpAnimCtrl.value < 0.5;
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      reverseDuration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOut,
                      child: FadeTransition(
                        opacity: _powerGroupFade,
                        child: showDirect
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildIpPortRow(
                                    label: '大屏拼接器设备',
                                    ipController: _bigScreenIpController,
                                    portController: _bigScreenPortController,
                                  ),
                                  buildBrandDropdown(
                                    label: '设备品牌',
                                    currentValue: _bigScreenBrand,
                                    brandNames: DeviceConfig
                                        .bigScreenBrandConfigs
                                        .map((b) => b.name)
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _bigScreenBrand = value;
                                        final config = DeviceConfig
                                            .bigScreenBrandConfigs
                                            .firstWhere((b) => b.name == value);
                                        _bigScreenPortController.text =
                                            '${config.port}';
                                        _bigScreenUseTcp = config.useTcp;
                                        _bigScreenSendAsHex = config.sendAsHex;
                                      });
                                    },
                                  ),
                                  buildProtocolSwitch(
                                    label: '通信协议',
                                    value: _bigScreenUseTcp,
                                    onChanged: (value) => setState(
                                      () => _bigScreenUseTcp = value,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
                buildSectionLabel('分屏模式按钮（勾选显示）'),
                buildLayoutButtonConfigRow(
                  label: '全屏',
                  show: _config.showBigScreenFull,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenFull(v)),
                ),
                buildLayoutButtonConfigRow(
                  label: '全屏16:9',
                  show: _config.showBigScreenFull169,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenFull169(v)),
                ),
                buildLayoutButtonConfigRow(
                  label: '二分屏',
                  show: _config.showBigScreenSplit2,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenSplit2(v)),
                ),
                buildLayoutButtonConfigRow(
                  label: '三分屏',
                  show: _config.showBigScreenSplit3,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenSplit3(v)),
                ),
                buildLayoutButtonConfigRow(
                  label: '四分屏',
                  show: _config.showBigScreenSplit4,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenSplit4(v)),
                ),
                buildLayoutButtonConfigRow(
                  label: '五分屏',
                  show: _config.showBigScreenSplit5,
                  onShowChanged: (v) =>
                      setState(() => _config.setShowBigScreenSplit5(v)),
                ),
                buildSectionLabel('分屏输出通道映射'),
                buildBigScreenOutputMapping(
                  outputControllers: _bsOutputChannelControllers,
                  areaCount: _config.bigScreenMaxAreaCount,
                ),
              ],
            ),
            buildGroupCard(
              title: '摄像头',
              icon: Icons.videocam,
              isExpanded: _isExpanded('camera'),
              onToggle: () => _toggleGroup('camera'),
              children: [
                ..._cameraControllers.asMap().entries.map(
                  (entry) => buildCameraItem(
                    index: entry.key,
                    ctrl: entry.value,
                    useTcp: _cameraUseTcp[entry.key],
                    onUseTcpChanged: (v) =>
                        setState(() => _cameraUseTcp[entry.key] = v),
                    onRemove: () => _removeCamera(entry.key),
                    canRemove: _cameraControllers.length > 1,
                    hideConnection: _crestronMode,
                    connectionFade: _powerGroupFade,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _addCamera,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: DeviceConfig.colorAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '添加摄像头',
                      style: TextStyle(color: DeviceConfig.colorAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                buildInputRow(
                  label: '预置位数量',
                  controller: _cameraPresetCountController,
                  isNumber: true,
                  maxLength: 2,
                ),
              ],
            ),
            // ===== 页面显示控制（单独分区，与设备直连区隔开）=====
            _buildZoneHeader('页面显示控制', Icons.view_module),
            const SizedBox(height: 2),
            buildGroupCard(
              title: '页面显示控制',
              icon: Icons.dashboard_customize,
              isExpanded: _isExpanded('pageVisibility'),
              onToggle: () => _toggleGroup('pageVisibility'),
              children: [
                buildPageVisibilitySwitch(
                  title: '时序电源控制',
                  value: _showPowerControl,
                  onChanged: (value) =>
                      setState(() => _showPowerControl = value),
                ),
                buildPageVisibilitySwitch(
                  title: '大屏控制',
                  value: _showBigScreen,
                  onChanged: (value) => setState(() => _showBigScreen = value),
                ),
                buildPageVisibilitySwitch(
                  title: '视频矩阵控制',
                  value: _showVideoMatrix,
                  onChanged: (value) =>
                      setState(() => _showVideoMatrix = value),
                ),
                buildPageVisibilitySwitch(
                  title: '摄像头控制',
                  value: _showCameraControl,
                  onChanged: (value) =>
                      setState(() => _showCameraControl = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveAll,
                icon: const Icon(Icons.save_outlined, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeviceConfig.colorAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: DeviceConfig.colorAccent.withAlpha(120),
                ),
                label: const Text(
                  '保存配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: DeviceConfig.colorDialogBg,
                      title: const Text('确认重置'),
                      content: const Text('确定要重置所有配置为默认值吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            _config.resetAll();
                            _loadConfig();
                            CameraConnectionManager().rebuild();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('配置已重置')),
                            );
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: DeviceConfig.colorStatusError.withAlpha(150),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '重置为默认值',
                  style: TextStyle(color: DeviceConfig.colorStatusError),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
