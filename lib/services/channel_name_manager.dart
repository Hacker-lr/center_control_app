import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// 通道名称管理器（单例模式）
/// 管理矩阵输入/输出通道的自定义名称，持久化存储到 SharedPreferences
/// 默认使用数字编号，用户可通过长按按钮自定义名称
/// ============================================================
class ChannelNameManager extends ChangeNotifier {
  static final ChannelNameManager _instance = ChannelNameManager._internal();
  factory ChannelNameManager() => _instance;
  ChannelNameManager._internal() {
    init();
  }

  /// SharedPreferences 实例
  SharedPreferences? _prefs;

  /// 存储键前缀
  static const String _inputPrefix = 'matrix_input_name_';
  static const String _outputPrefix = 'matrix_output_name_';

  /// 初始化 SharedPreferences（单例构造时自动调用）
  Future<void> init() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
        debugPrint('[ChannelNameManager] SharedPreferences 初始化成功');
      }
    } catch (e) {
      debugPrint('[ChannelNameManager] SharedPreferences 初始化失败: $e');
    }
  }

  /// 获取输入通道名称
  /// channelNumber: 通道编号（1-based）
  /// defaultValue: 默认值（通常是数字字符串）
  String getInputName(int channelNumber, {String? defaultValue}) {
    final String? saved = _prefs?.getString('$_inputPrefix$channelNumber');
    return saved ?? defaultValue ?? '$channelNumber';
  }

  /// 获取输出通道名称
  /// channelNumber: 通道编号（1-based）
  /// defaultValue: 默认值（通常是数字字符串）
  String getOutputName(int channelNumber, {String? defaultValue}) {
    final String? saved = _prefs?.getString('$_outputPrefix$channelNumber');
    return saved ?? defaultValue ?? '$channelNumber';
  }

  /// 保存输入通道名称
  /// channelNumber: 通道编号（1-based）
  /// name: 自定义名称，为空则恢复默认值
  Future<void> saveInputName(int channelNumber, String name) async {
    await init();
    if (name.isEmpty) {
      await _prefs?.remove('$_inputPrefix$channelNumber');
    } else {
      await _prefs?.setString('$_inputPrefix$channelNumber', name);
    }
    notifyListeners();
  }

  /// 保存输出通道名称
  /// channelNumber: 通道编号（1-based）
  /// name: 自定义名称，为空则恢复默认值
  Future<void> saveOutputName(int channelNumber, String name) async {
    await init();
    if (name.isEmpty) {
      await _prefs?.remove('$_outputPrefix$channelNumber');
    } else {
      await _prefs?.setString('$_outputPrefix$channelNumber', name);
    }
    notifyListeners();
  }

  /// 重置所有输入通道名称为默认值
  Future<void> resetAllInputNames() async {
    await init();
    final Set<String> keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_inputPrefix)) {
        await _prefs?.remove(key);
      }
    }
    notifyListeners();
  }

  Future<void> resetAllOutputNames() async {
    await init();
    final Set<String> keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (key.startsWith(_outputPrefix)) {
        await _prefs?.remove(key);
      }
    }
    notifyListeners();
  }

  /// 重置指定输入通道名称为默认值
  Future<void> resetInputName(int channelNumber) async {
    await init();
    await _prefs?.remove('$_inputPrefix$channelNumber');
    notifyListeners();
  }

  /// 重置指定输出通道名称为默认值
  Future<void> resetOutputName(int channelNumber) async {
    await init();
    await _prefs?.remove('$_outputPrefix$channelNumber');
    notifyListeners();
  }
}
