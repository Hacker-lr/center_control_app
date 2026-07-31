import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/base_connection.dart';
import '../services/crestron_cip_connection.dart';
import '../services/device_config.dart';
import '../utils/responsive_utils.dart';

/// ============================================================
/// Crestron 中控控制页面
/// 通过 CIP/SCIP 协议直接对接 Crestron 3 系列（明文）与 4 系列（安全）处理器
/// 提供：数字 join 置高/置低/脉冲/按下/释放、模拟 join、串口 join、实时反馈日志
/// ============================================================
class CrestronPage extends StatefulWidget {
  const CrestronPage({super.key});

  @override
  State<CrestronPage> createState() => _CrestronPageState();
}

class _CrestronPageState extends State<CrestronPage> {
  final CrestronCipConnection _cip = CrestronCipConnection();
  final DeviceConfig _config = DeviceConfig();

  // 控制输入控制器
  final TextEditingController _digitalJoinController = TextEditingController(
    text: '1',
  );
  final TextEditingController _analogJoinController = TextEditingController(
    text: '1',
  );
  final TextEditingController _analogValueController = TextEditingController(
    text: '32768',
  );
  final TextEditingController _serialJoinController = TextEditingController(
    text: '1',
  );
  final TextEditingController _serialValueController = TextEditingController(
    text: 'Hello Crestron',
  );

  // 订阅 token 列表（离开页面时取消）
  final List<String> _subTokens = [];

  @override
  void initState() {
    super.initState();
    // 订阅常用 join 演示：数字1、模拟1、串口1；实际可按需在页面动态订阅
    _subscribeDemo();
  }

  void _subscribeDemo() {
    _subTokens.add(_cip.subscribe('d', 1, _onJoinEvent));
    _subTokens.add(_cip.subscribe('a', 1, _onJoinEvent));
    _subTokens.add(_cip.subscribe('s', 1, _onJoinEvent));
  }

  void _onJoinEvent(String sigtype, int join, dynamic value) {
    // 反馈已通过 eventLog 记录；这里仅触发 UI 刷新（eventLog 变化 notifyListeners）
    setState(() {});
  }

  @override
  void dispose() {
    for (final token in _subTokens) {
      _cip.unsubscribe(token);
    }
    _digitalJoinController.dispose();
    _analogJoinController.dispose();
    _analogValueController.dispose();
    _serialJoinController.dispose();
    _serialValueController.dispose();
    super.dispose();
  }

  /// 解析控制器文本为整数；非法输入返回 null（调用方据此跳过发送）
  int? _parseInt(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _setDigital(int value) async {
    final int? join = _parseInt(_digitalJoinController);
    if (join == null) return;
    await _cip.set('d', join, value);
  }

  Future<void> _setAnalog() async {
    final int? join = _parseInt(_analogJoinController);
    final int? value = _parseInt(_analogValueController);
    if (join == null || value == null) return;
    await _cip.set('a', join, value);
  }

  Future<void> _setSerial() async {
    final int? join = _parseInt(_serialJoinController);
    if (join == null) return;
    await _cip.set('s', join, _serialValueController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cip,
      builder: (context, child) {
        return SafeArea(
          child: SizedBox.expand(
            child: Padding(
              padding: ResponsiveUtils.getPagePadding(context),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 12)),
                  _buildStatusIndicator(),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, 16)),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildDigitalCard(),
                        const SizedBox(height: 12),
                        _buildAnalogCard(),
                        const SizedBox(height: 12),
                        _buildSerialCard(),
                        const SizedBox(height: 12),
                        _buildFeedbackCard(),
                      ],
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

  /// 连接状态指示器
  Widget _buildStatusIndicator() {
    final status = _cip.status;
    final bool cipOk = _cip.isCipConnected;
    String text;
    Color color;
    IconData icon;
    if (!cipOk) {
      switch (status) {
        case ConnectionStatus.connecting:
          text = '正在连接 (${_config.cipSecure ? "SCIP/TLS" : "CIP"})...';
          color = const Color(0xFFFFA726);
          icon = Icons.sync;
          break;
        case ConnectionStatus.error:
          text = '连接失败，自动重连中...';
          color = const Color(0xFFE53935);
          icon = Icons.error_outline;
          break;
        default:
          text = '未连接';
          color = Colors.grey[500]!;
          icon = Icons.link_off;
      }
    } else {
      text = 'CIP 已连接${_config.cipSecure ? " (安全)" : ""}';
      color = const Color(0xFF4CAF50);
      icon = Icons.link;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, 16),
        vertical: ResponsiveUtils.getSpacing(context, 6),
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: ResponsiveUtils.getSpacing(context, 6)),
          Text(
            text,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, 12),
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (cipOk) ...[
            SizedBox(width: ResponsiveUtils.getSpacing(context, 10)),
            Text(
              '心跳 #${_cip.heartbeatCount}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 11),
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 数字 join 控制卡片
  Widget _buildDigitalCard() {
    return _buildCard(
      title: '数字 Join (Digital)',
      children: [
        _buildJoinInput(_digitalJoinController, 'Join 号'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton(
              '置高',
              Icons.radio_button_checked,
              const Color(0xFF1B5E20),
              () => _setDigital(1),
            ),
            _actionButton(
              '置低',
              Icons.radio_button_unchecked,
              const Color(0xFF8B0000),
              () => _setDigital(0),
            ),
            _actionButton(
              '脉冲',
              Icons.flash_on,
              const Color(0xFF1F4068),
              () => _cip.pulse(_parseInt(_digitalJoinController) ?? 1),
            ),
            _actionButton(
              '按下',
              Icons.touch_app,
              const Color(0xFF3A5A8C),
              () => _cip.press(_parseInt(_digitalJoinController) ?? 1),
            ),
            _actionButton(
              '释放',
              Icons.back_hand,
              Colors.grey[700]!,
              () => _cip.release(_parseInt(_digitalJoinController) ?? 1),
            ),
          ],
        ),
      ],
    );
  }

  /// 模拟 join 控制卡片
  Widget _buildAnalogCard() {
    return _buildCard(
      title: '模拟 Join (Analog, 0-65535)',
      children: [
        Row(
          children: [
            Expanded(child: _buildJoinInput(_analogJoinController, 'Join 号')),
            const SizedBox(width: 8),
            Expanded(child: _buildJoinInput(_analogValueController, '数值')),
          ],
        ),
        const SizedBox(height: 10),
        _actionButton(
          '设置模拟值',
          Icons.tune,
          const Color(0xFF1F4068),
          _setAnalog,
          full: true,
        ),
      ],
    );
  }

  /// 串口 join 控制卡片
  Widget _buildSerialCard() {
    return _buildCard(
      title: '串口 Join (Serial)',
      children: [
        _buildJoinInput(_serialJoinController, 'Join 号'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2228), width: 1),
          ),
          child: TextField(
            controller: _serialValueController,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '串口内容',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
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
        const SizedBox(height: 10),
        _actionButton(
          '发送串口',
          Icons.send,
          const Color(0xFF1F4068),
          _setSerial,
          full: true,
        ),
      ],
    );
  }

  /// 实时反馈卡片
  Widget _buildFeedbackCard() {
    final logs = _cip.eventLog;
    return _buildCard(
      title: '实时反馈', // 入站 join 变化
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2228), width: 1),
          ),
          padding: const EdgeInsets.all(8),
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    '暂无事件',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final item = logs[logs.length - 1 - index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CDCFE),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 通用卡片容器
  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2228), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: ResponsiveUtils.getSpacing(context, 12),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 2.0,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  /// join 号输入框
  Widget _buildJoinInput(TextEditingController controller, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E2228), width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
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
      ],
    );
  }

  /// 操作按钮
  Widget _actionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool full = false,
  }) {
    final btn = GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(220),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
    return full ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
