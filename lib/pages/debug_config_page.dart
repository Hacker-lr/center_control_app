import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/device_config.dart';

/// ============================================================
/// 调试配置页面
/// 供开发者和调试人员修改所有受控设备的配置参数
/// 包括：设备IP、端口号、通道数量等
/// 通过长按顶部标题"欢迎使用中控"进入本页面
/// ============================================================
class DebugConfigPage extends StatefulWidget {
  const DebugConfigPage({super.key});

  @override
  State<DebugConfigPage> createState() => _DebugConfigPageState();
}

class _DebugConfigPageState extends State<DebugConfigPage> {
  /// 配置实例
  final DeviceConfig _config = DeviceConfig();

  /// 提示文字颜色（_hintColor 的常量等价，用于 const 声明）
  static const Color _hintColor = Color(0xFF757575);

  /// 表单控制器
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
  final TextEditingController _cameraPresetCountController =
      TextEditingController();

  /// 摄像头配置控制器列表
  final List<Map<String, TextEditingController>> _cameraControllers = [];

  /// 当前展开的配置分组
  String? _expandedGroup;

  /// 通信协议选择状态
  bool _powerUseTcp = true;
  bool _matrixUseTcp = true;
  bool _bigScreenUseTcp = true;

  /// 指令发送模式选择状态（每个品牌独立）
  /// true=16进制模式, false=ASCII模式
  bool _powerSendAsHex = false;
  bool _matrixSendAsHex = false;
  bool _bigScreenSendAsHex = false;

  /// 品牌选择状态
  String _powerBrand = '默认品牌';
  String _matrixBrand = '默认品牌';
  String _bigScreenBrand = '默认品牌';

  /// 页面显示开关状态
  bool _showPowerControl = true;
  bool _showBigScreen = true;
  bool _showVideoMatrix = true;
  bool _showCameraControl = true;

  /// 页面初始化时加载当前配置到控制器
  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 释放控制器资源
  @override
  void dispose() {
    _powerIpController.dispose();
    _powerPortController.dispose();
    _matrixIpController.dispose();
    _matrixPortController.dispose();
    _matrixInputCountController.dispose();
    _matrixOutputCountController.dispose();
    _bigScreenIpController.dispose();
    _bigScreenPortController.dispose();
    _cameraPresetCountController.dispose();
    for (var ctrl in _cameraControllers) {
      ctrl['ip']?.dispose();
      ctrl['port']?.dispose();
      ctrl['viscaAddr']?.dispose();
    }
    super.dispose();
  }

  /// 加载当前配置到表单控制器
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
    _bigScreenSendAsHex = _config.bigScreenSendAsHex;
    _bigScreenBrand = _config.bigScreenBrand;
    _cameraPresetCountController.text = '${_config.cameraPresetCount}';
    _showPowerControl = _config.showPowerControl;
    _showBigScreen = _config.showBigScreen;
    _showVideoMatrix = _config.showVideoMatrix;
    _showCameraControl = _config.showCameraControl;

    _cameraControllers.clear();
    for (var device in _config.cameraDevices) {
      _cameraControllers.add({
        'ip': TextEditingController(text: device['ip']),
        'port': TextEditingController(text: '${device['port']}'),
        'viscaAddr': TextEditingController(text: '${device['viscaAddr']}'),
      });
    }
  }

  /// 保存所有配置
  void _saveAll() {
    _config.setPowerDeviceIp(_powerIpController.text.trim());
    _config.setPowerDevicePort(
      int.tryParse(_powerPortController.text.trim()) ?? 5000,
    );
    _config.setPowerUseTcp(_powerUseTcp);
    _config.setPowerSendAsHex(_powerSendAsHex);
    _config.setPowerBrand(_powerBrand);
    _config.setMatrixDeviceIp(_matrixIpController.text.trim());
    _config.setMatrixDevicePort(
      int.tryParse(_matrixPortController.text.trim()) ?? 5000,
    );
    _config.setMatrixUseTcp(_matrixUseTcp);
    _config.setMatrixSendAsHex(_matrixSendAsHex);
    _config.setMatrixBrand(_matrixBrand);
    _config.setMatrixInputCount(
      int.tryParse(_matrixInputCountController.text.trim()) ?? 16,
    );
    _config.setMatrixOutputCount(
      int.tryParse(_matrixOutputCountController.text.trim()) ?? 16,
    );
    _config.setBigScreenDeviceIp(_bigScreenIpController.text.trim());
    _config.setBigScreenDevicePort(
      int.tryParse(_bigScreenPortController.text.trim()) ?? 5000,
    );
    _config.setBigScreenUseTcp(_bigScreenUseTcp);
    _config.setBigScreenSendAsHex(_bigScreenSendAsHex);
    _config.setBigScreenBrand(_bigScreenBrand);
    _config.setCameraPresetCount(
      int.tryParse(_cameraPresetCountController.text.trim()) ?? 8,
    );
    _config.setShowPowerControl(_showPowerControl);
    _config.setShowBigScreen(_showBigScreen);
    _config.setShowVideoMatrix(_showVideoMatrix);
    _config.setShowCameraControl(_showCameraControl);

    List<Map<String, dynamic>> cameraDevices = [];
    for (var i = 0; i < _cameraControllers.length; i++) {
      var ctrl = _cameraControllers[i];
      cameraDevices.add({
        'ip': ctrl['ip']?.text.trim() ?? '192.168.0.${64 + i}',
        'port': int.tryParse(ctrl['port']?.text.trim() ?? '52381') ?? 52381,
        'viscaAddr': int.tryParse(ctrl['viscaAddr']?.text.trim() ?? '1') ?? 1,
      });
    }
    _config.setCameraDevices(cameraDevices);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('配置保存成功！'),
        backgroundColor: DeviceConfig.colorStatusConnected,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 添加摄像头配置项
  void _addCamera() {
    setState(() {
      _cameraControllers.add({
        'ip': TextEditingController(
          text: '192.168.0.${64 + _cameraControllers.length}',
        ),
        'port': TextEditingController(text: '52381'),
        'viscaAddr': TextEditingController(text: '1'),
      });
    });
  }

  /// 删除摄像头配置项
  void _removeCamera(int index) {
    setState(() {
      _cameraControllers[index]['ip']?.dispose();
      _cameraControllers[index]['port']?.dispose();
      _cameraControllers[index]['viscaAddr']?.dispose();
      _cameraControllers.removeAt(index);
    });
  }

  /// 切换配置分组展开状态
  void _toggleGroup(String groupName) {
    setState(() {
      _expandedGroup = _expandedGroup == groupName ? null : groupName;
    });
  }

  /// 构建配置分组卡片
  Widget _buildGroupCard({
    required String title,
    required IconData icon,
    required String groupKey,
    required List<Widget> children,
  }) {
    final bool isExpanded = _expandedGroup == groupKey;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: DeviceConfig.colorCardBg,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleGroup(groupKey),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: DeviceConfig.colorAccent),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Column(children: children),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  /// 构建输入框行（标签 + 输入框）
  Widget _buildInputRow({
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
    String? hintText,
    int maxLength = 50,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: DeviceConfig.colorDialogFieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DeviceConfig.colorButtonBorder),
            ),
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              keyboardType:
                  keyboardType ??
                  (isNumber ? TextInputType.number : TextInputType.text),
              inputFormatters: isNumber
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: _hintColor, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                counterText: '',
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建双列输入框（IP + 端口）
  Widget _buildIpPortRow({
    required String label,
    required TextEditingController ipController,
    required TextEditingController portController,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: DeviceConfig.colorDialogFieldBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: ipController,
                    maxLength: 15,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'IP地址',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: DeviceConfig.colorButtonBorder,
              ),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: DeviceConfig.colorDialogFieldBg,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: portController,
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '端口',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建摄像头配置项
  Widget _buildCameraItem(int index) {
    var ctrl = _cameraControllers[index];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DeviceConfig.colorDialogFieldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DeviceConfig.colorButtonBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: DeviceConfig.colorAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: DeviceConfig.colorAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '摄像头 ${index + 1}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _cameraControllers.length > 1
                    ? () => _removeCamera(index)
                    : null,
                disabledColor: _hintColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: ctrl['ip'],
                    maxLength: 15,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'IP',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: DeviceConfig.colorButtonBorder,
              ),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: ctrl['port'],
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '端口',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建双列数字输入框（输入通道 + 输出通道）
  Widget _buildChannelCountRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '矩阵通道数量',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: DeviceConfig.colorDialogFieldBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: _matrixInputCountController,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '输入通道数',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: DeviceConfig.colorButtonBorder,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: DeviceConfig.colorDialogFieldBg,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border.all(color: DeviceConfig.colorButtonBorder),
                  ),
                  child: TextField(
                    controller: _matrixOutputCountController,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '输出通道数',
                      hintStyle: TextStyle(color: _hintColor, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建协议选择开关（TCP/UDP切换）
  Widget _buildProtocolSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: DeviceConfig.colorDialogFieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DeviceConfig.colorButtonBorder),
            ),
            child: Row(
              children: [
                _buildProtocolOption('TCP', true, value, onChanged),
                Container(
                  width: 1,
                  height: 32,
                  color: DeviceConfig.colorButtonBorder,
                ),
                _buildProtocolOption('UDP', false, value, onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建品牌选择下拉框
  Widget _buildBrandDropdown({
    required String label,
    required String currentValue,
    required List<String> brandNames,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Container(
            width: 140,
            decoration: BoxDecoration(
              color: DeviceConfig.colorDialogFieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DeviceConfig.colorButtonBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                isExpanded: true,
                items: brandNames.map((brand) {
                  return DropdownMenuItem<String>(
                    value: brand,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(brand, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
                style: const TextStyle(color: Colors.white, fontSize: 13),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[400],
                  size: 20,
                ),
                dropdownColor: DeviceConfig.colorCardBg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个协议选项按钮
  Widget _buildProtocolOption(
    String text,
    bool isTcp,
    bool currentValue,
    ValueChanged<bool> onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(isTcp),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: currentValue == isTcp
              ? DeviceConfig.colorAccent
              : Colors.transparent,
          borderRadius: isTcp
              ? const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                )
              : const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: currentValue == isTcp
                ? FontWeight.bold
                : FontWeight.normal,
            color: currentValue == isTcp ? Colors.white : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  /// 构建页面显示开关项
  /// 勾选则显示该页面，取消勾选则隐藏
  Widget _buildPageVisibilitySwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: DeviceConfig.colorAccent,
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
        title: const Text(
          '系统配置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: DeviceConfig.colorCardBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            _buildGroupCard(
              title: '视频矩阵配置',
              icon: Icons.videocam_outlined,
              groupKey: 'matrix',
              children: [
                _buildIpPortRow(
                  label: '视频矩阵设备',
                  ipController: _matrixIpController,
                  portController: _matrixPortController,
                ),
                _buildBrandDropdown(
                  label: '设备品牌',
                  currentValue: _matrixBrand,
                  brandNames: DeviceConfig.matrixBrandConfigs
                      .map((b) => b.name)
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _matrixBrand = value;
                      final config = DeviceConfig.matrixBrandConfigs.firstWhere(
                        (b) => b.name == value,
                      );
                      // 切换品牌时自动应用该品牌的端口、协议、发送模式
                      _matrixPortController.text = '${config.port}';
                      _matrixUseTcp = config.useTcp;
                      _matrixSendAsHex = config.sendAsHex;
                    });
                  },
                ),
                _buildProtocolSwitch(
                  label: '通信协议',
                  value: _matrixUseTcp,
                  onChanged: (value) => setState(() => _matrixUseTcp = value),
                ),
                _buildChannelCountRow(),
              ],
            ),
            _buildGroupCard(
              title: '大屏拼接器配置',
              icon: Icons.tv,
              groupKey: 'bigScreen',
              children: [
                _buildIpPortRow(
                  label: '大屏拼接器设备',
                  ipController: _bigScreenIpController,
                  portController: _bigScreenPortController,
                ),
                _buildBrandDropdown(
                  label: '设备品牌',
                  currentValue: _bigScreenBrand,
                  brandNames: DeviceConfig.bigScreenBrandConfigs
                      .map((b) => b.name)
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _bigScreenBrand = value;
                      final config = DeviceConfig.bigScreenBrandConfigs
                          .firstWhere((b) => b.name == value);
                      // 切换品牌时自动应用该品牌的端口、协议、发送模式
                      _bigScreenPortController.text = '${config.port}';
                      _bigScreenUseTcp = config.useTcp;
                      _bigScreenSendAsHex = config.sendAsHex;
                    });
                  },
                ),
                _buildProtocolSwitch(
                  label: '通信协议',
                  value: _bigScreenUseTcp,
                  onChanged: (value) =>
                      setState(() => _bigScreenUseTcp = value),
                ),
              ],
            ),
            _buildGroupCard(
              title: '时序电源配置',
              icon: Icons.bolt,
              groupKey: 'power',
              children: [
                _buildIpPortRow(
                  label: '时序电源设备',
                  ipController: _powerIpController,
                  portController: _powerPortController,
                ),
                _buildBrandDropdown(
                  label: '设备品牌',
                  currentValue: _powerBrand,
                  brandNames: DeviceConfig.powerBrandConfigs
                      .map((b) => b.name)
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _powerBrand = value;
                      final config = DeviceConfig.powerBrandConfigs.firstWhere(
                        (b) => b.name == value,
                      );
                      // 切换品牌时自动应用该品牌的端口、协议、发送模式
                      _powerPortController.text = '${config.port}';
                      _powerUseTcp = config.useTcp;
                      _powerSendAsHex = config.sendAsHex;
                    });
                  },
                ),
                _buildProtocolSwitch(
                  label: '通信协议',
                  value: _powerUseTcp,
                  onChanged: (value) => setState(() => _powerUseTcp = value),
                ),
              ],
            ),
            _buildGroupCard(
              title: '摄像头配置',
              icon: Icons.videocam,
              groupKey: 'camera',
              children: [
                ..._cameraControllers.asMap().entries.map(
                  (entry) => _buildCameraItem(entry.key),
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
                _buildInputRow(
                  label: '预置位数量',
                  controller: _cameraPresetCountController,
                  isNumber: true,
                  hintText: '8',
                  maxLength: 2,
                ),
              ],
            ),
            _buildGroupCard(
              title: '页面显示控制',
              icon: Icons.dashboard_customize,
              groupKey: 'pageVisibility',
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '控制主界面各控制页面的显示与隐藏，关闭后对应的页面及导航栏按钮都不再显示。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                _buildPageVisibilitySwitch(
                  title: '时序电源控制',
                  subtitle: '显示电源开/关控制页面',
                  value: _showPowerControl,
                  onChanged: (value) =>
                      setState(() => _showPowerControl = value),
                ),
                _buildPageVisibilitySwitch(
                  title: '大屏控制',
                  subtitle: '显示大屏分屏布局切换页面',
                  value: _showBigScreen,
                  onChanged: (value) => setState(() => _showBigScreen = value),
                ),
                _buildPageVisibilitySwitch(
                  title: '视频矩阵控制',
                  subtitle: '显示视频矩阵输入/输出切换页面',
                  value: _showVideoMatrix,
                  onChanged: (value) =>
                      setState(() => _showVideoMatrix = value),
                ),
                _buildPageVisibilitySwitch(
                  title: '摄像头控制',
                  subtitle: '显示摄像头云台控制与预置位管理页面',
                  value: _showCameraControl,
                  onChanged: (value) =>
                      setState(() => _showCameraControl = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DeviceConfig.colorAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  '保存配置',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '重置为默认值',
                  style: TextStyle(color: Colors.red),
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
