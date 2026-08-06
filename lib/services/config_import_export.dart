import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:toml/toml.dart';

import 'device_config.dart';
import 'channel_name_manager.dart';

/// ============================================================
/// 配置导入 / 导出服务
/// ============================================================
/// 将当前 App 的完整可配置项（DeviceConfig 运行时字段 + 通道名称）
/// 序列化为一个带元信息的 TOML 文件；反之从文件解析并应用。
///
/// TOML 比 JSON 更通俗易懂：key = value 风格，字符串可不加引号、
/// 不依赖缩进、支持分区 [section] 与列表，便于现场人员直接手改。
///
/// 文件结构示例：
///   app = 'center_control_app'
///   schemaVersion = 1
///   exportedAt = '2026-08-06T...'
///
///   [config]
///   powerDeviceIp = '192.168.0.200'
///   ...
///   [[config.cameraDevices]]
///   name = '主摄像机'
///   ...
///
///   [channelNames.matrixInputs]
///   '1' = '摄像机A'
///
/// 安全提示：CIP 密码（config.cipPassword）以明文写入文件。导出/导入时
/// 调用方应提示用户“文件含明文密码，注意保管”。
class ConfigImportExport {
  static const String _fileName = 'cip_config.toml';
  static const List<XTypeGroup> _tomlTypeGroup = [
    XTypeGroup(extensions: ['toml'], label: 'TOML 配置文件'),
  ];

  /// 导出当前完整配置到用户选择的文件。
  /// 返回导出文件的绝对路径；用户取消选择则返回 null。
  static Future<String?> exportConfig() async {
    final DeviceConfig config = DeviceConfig();
    final ChannelNameManager names = ChannelNameManager();

    final Map<String, dynamic> payload = <String, dynamic>{
      'app': 'center_control_app',
      'schemaVersion': DeviceConfig.configSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'config': config.toExportMap(),
      'channelNames': names.exportNames(),
    };

    // 自定义 TOML 序列化：统一使用双引号基本字符串（"..."），
    // 避免值中含单引号时编码器自动切换为三单引号 '''...''' 导致难读。
    final String body = _serializeToml(payload);

    // 顶部加通俗说明注释（TOML 用 # 注释，导入时自动忽略）
    final String tomlOut = '''
# 中控 App 设备配置导出文件
# 可直接用记事本手改后，通过「系统配置」页的「导入配置」按钮载入。
# 注意：cipPassword 以明文保存，请妥善保管本文件。
# 字段说明见各段；修改后保存即可，无需引号 / 逗号等额外符号。

$body''';

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: _fileName,
      acceptedTypeGroups: _tomlTypeGroup,
    );
    if (location == null) return null;

    // file_selector 在部分平台上文件名不带扩展名，这里确保以 .toml 结尾
    String path = location.path;
    if (!path.toLowerCase().endsWith('.toml')) path = '$path.toml';

    final File file = File(path);
    await file.writeAsString(tomlOut, flush: true);
    return path;
  }

  /// 从用户选择的文件导入配置。
  ///
  /// 返回三元组：
  ///   (成功?, 文件是否含非空密码, 错误信息)
  /// 用户取消选择时返回 (false, false, null)，视为正常取消、无需提示。
  static Future<(bool, bool, String?)> importConfig() async {
    final XFile? file = await openFile(acceptedTypeGroups: _tomlTypeGroup);
    if (file == null) return (false, false, null);

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      return (false, false, '读取文件失败：$e');
    }

    Map<String, dynamic> root;
    try {
      root = TomlDocument.parse(content).toMap();
    } catch (e) {
      return (false, false, '文件不是合法的 TOML：$e');
    }

    final Object? cfg = root['config'];
    if (cfg is! Map<String, dynamic>) {
      return (false, false, '配置缺少 config 段，无法导入');
    }

    // 应用 DeviceConfig（仅覆盖文件中出现的键）
    DeviceConfig().applyImportMap(cfg);

    // 通道名称可选（旧版文件可能没有该段）
    final Object? names = root['channelNames'];
    if (names is Map<String, dynamic>) {
      await ChannelNameManager().importNames(names);
    }

    final bool hasPassword = cfg['cipPassword'] is String &&
        (cfg['cipPassword'] as String).isNotEmpty;

    return (true, hasPassword, null);
  }

  /// 自定义 TOML 序列化器（统一双引号，避免三单引号）。
  /// 公开仅供单元测试调用；正常导出流程走 [exportConfig]。
  static String serializeToml(Map<String, dynamic> root) => _serializeToml(root);

  /// 将 Map 递归序列化为 TOML 字符串。
  ///
  /// 规则：
  /// - 所有字符串值用双引号基本字符串 `"..."`（内含单引号无需转义）。
  /// - 嵌套 Map → `[section]` 表头；嵌套 List<Map> → `[[array]]` 表数组。
  /// - 键名为纯数字 / 英文字母/下划线/连字符时不加引号，否则加双引号。
  static String _serializeToml(Map<String, dynamic> root) {
    final buf = StringBuffer();
    _writeTomlValue(root, buf, indent: '');
    return buf.toString();
  }

  /// 递归写入一个 TOML 值到 [buf]。
  static void _writeTomlValue(dynamic value, StringBuffer buf,
      {required String indent}) {
    if (value is Map<String, dynamic>) {
      _writeTomlTable(value, buf, indent: indent);
    } else if (value is List) {
      _writeTomlArray(value, buf);
    } else {
      _writeTomlScalar(value, buf);
    }
  }

  /// 写入一个 TOML 表（[section] ... key = value）。
  /// [tablePath] 是当前表的点分路径（如 "channelNames.matrixInputs"），
  /// 用于生成正确的嵌套表头。
  static void _writeTomlTable(
      Map<String, dynamic> table, StringBuffer buf,
      {required String indent, String tablePath = ''}) {
    final keys = table.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final val = table[key];
      if (val is Map<String, dynamic>) {
        // 子表：输出带完整路径的表头 [parent.child]
        if (buf.isNotEmpty && !buf.toString().endsWith('\n\n')) {
          buf.writeln();
        }
        final childPath =
            tablePath.isEmpty ? key : '$tablePath.$key';
        buf.writeln('$indent[$childPath]');
        _writeTomlTable(val, buf, indent: indent, tablePath: childPath);
      } else if (val is List && val.isNotEmpty && val.first is Map) {
        // 表数组：每个元素一个 [[parent.child]]
        final arrayPath =
            tablePath.isEmpty ? key : '$tablePath.$key';
        for (final item in val) {
          if (item is Map<String, dynamic>) {
            if (buf.isNotEmpty && !buf.toString().endsWith('\n\n')) {
              buf.writeln();
            }
            buf.writeln('$indent[[$arrayPath]]');
            _writeTomlTable(item, buf, indent: indent, tablePath: arrayPath);
          }
        }
      } else {
        // 普通键值对
        buf.write('$indent${_tomlKey(key)} = ');
        _writeTomlScalar(val, buf);
        buf.writeln();
      }
    }
  }

  /// 写入标量值（string/int/bool/double/datetime）。
  static void _writeTomlScalar(dynamic value, StringBuffer buf) {
    if (value == null) {
      // 不应出现，防御性处理
      return;
    } else if (value is String) {
      // 双引号基本字符串：仅转义 " \ 和控制字符
      buf.write('"${_escapeTomlBasicString(value)}"');
    } else if (value is bool) {
      buf.write(value ? 'true' : 'false');
    } else if (value is int) {
      buf.write(value.toString());
    } else if (value is double) {
      buf.write(value.toString());
    } else {
      // 兜底：用 JSON 字符串包裹
      buf.write('"${jsonEncode(value.toString())}"');
    }
  }

  /// 写入内联数组（仅用于非表数组的简单列表）。
  static void _writeTomlArray(List list, StringBuffer buf) {
    buf.write('[');
    for (var i = 0; i < list.length; i++) {
      if (i > 0) buf.write(', ');
      _writeTomlScalar(list[i], buf);
    }
    buf.write(']');
  }

  /// 格式化 TOML 键名：纯 bare-key 字符集不加引号，否则加双引号。
  static String _tomlKey(String key) {
    if (_isBareKey(key)) return key;
    return '"${_escapeTomlBasicString(key)}"';
  }

  /// 判断键名是否为合法的 bare key（无需引号）。
  static bool _isBareKey(String key) {
    if (key.isEmpty) return false;
    for (var i = 0; i < key.length; i++) {
      final c = key.codeUnitAt(i);
      final isUpperAtoZ = c >= 0x41 && c <= 0x5A;
      final isLowerAtoZ = c >= 0x61 && c <= 0x7A;
      final isDigit = c >= 0x30 && c <= 0x39;
      final isDash = c == 0x2D; // -
      final isUnderscore = c == 0x5F; // _
      if (!(isUpperAtoZ || isLowerAtoZ || isDigit || isDash || isUnderscore)) return false;
    }
    return true;
  }

  /// 转义 TOML 双引号基本字符串中的特殊字符：
  ///   "  → \"
  ///   \  => \\
  ///   控制字符（\t \n 等）→ \t \n ...
  static String _escapeTomlBasicString(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      switch (c) {
        case '"':
          buf.write('\\"');
          break;
        case '\\':
          buf.write('\\\\');
          break;
        case '\n':
          buf.write('\\n');
          break;
        case '\r':
          buf.write('\\r');
          break;
        case '\t':
          buf.write('\\t');
          break;
        default:
          final code = s.codeUnitAt(i);
          if (code < 0x20) {
            // 其他控制字符：\uXXXX
            buf.write('\\u${code.toRadixString(16).padLeft(4, '0')}');
          } else {
            buf.write(c);
          }
      }
    }
    return buf.toString();
  }
}
