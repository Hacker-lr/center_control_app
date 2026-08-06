import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toml/toml.dart';

import 'package:center_control_app/services/device_config.dart';
import 'package:center_control_app/services/channel_name_manager.dart';
import 'package:center_control_app/services/config_import_export.dart';

void main() {
  // 在任意单例首次访问前注册内存版 SharedPreferences，保证持久化路径可测
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DeviceConfig 导出/导入', () {
    test('toExportMap 收集字段且可 round-trip', () {
      final DeviceConfig config = DeviceConfig();
      config.resetAll(); // 干净起点

      // 修改若干字段后导出
      config.setPowerDeviceIp('10.0.0.5');
      config.setMatrixInputCount(8);
      config.setCrestronMode(true);
      final Map<String, dynamic> exported = config.toExportMap();
      expect(exported['powerDeviceIp'], '10.0.0.5');
      expect(exported['matrixInputCount'], 8);
      expect(exported['crestronMode'], isTrue);

      // 改回原值，再导入 exported，应恢复为新值
      config.setPowerDeviceIp('1.2.3.4');
      config.setMatrixInputCount(16);
      config.setCrestronMode(false);
      config.applyImportMap(exported);
      expect(config.powerDeviceIp, '10.0.0.5');
      expect(config.matrixInputCount, 8);
      expect(config.crestronMode, isTrue);
    });

    test('导入仅覆盖出现的键，未出现键保留原值', () {
      final DeviceConfig config = DeviceConfig();
      config.resetAll();
      final int originalPort = config.powerDevicePort;

      config.applyImportMap(<String, dynamic>{'cipHost': '9.9.9.9'});
      expect(config.cipHost, '9.9.9.9');
      expect(config.powerDevicePort, originalPort); // 未被覆盖
    });

    test('导入类型错误不崩溃，保留原值', () {
      final DeviceConfig config = DeviceConfig();
      config.resetAll();
      final int originalCount = config.matrixInputCount;

      config.applyImportMap(<String, dynamic>{
        'matrixInputCount': 'not-an-int', // 错误类型
        'cipSecure': 1, // 1 不是 bool
      });
      expect(config.matrixInputCount, originalCount);
      expect(config.cipSecure, isFalse); // 类型不符，被忽略
    });

    test('导入对越界值做 clamp', () {
      final DeviceConfig config = DeviceConfig();
      config.resetAll();
      config.applyImportMap(<String, dynamic>{
        'cipIpId': 9999,
        'cameraPresetCount': 999,
      });
      expect(config.cipIpId, 0xFF);
      expect(config.cameraPresetCount, 16);
    });
  });

  group('ChannelNameManager 导出/导入', () {
    test('矩阵/摄像头/预置位名称 round-trip', () async {
      final ChannelNameManager m = ChannelNameManager();
      await m.saveInputName(1, '摄像机A');
      await m.saveOutputName(2, '投影B');
      await m.saveCameraName(1, '主位');
      await m.saveCameraPresetName(3, '全景');

      final Map<String, dynamic> exported = m.exportNames();
      expect(exported['matrixInputs']['1'], '摄像机A');
      expect(exported['matrixOutputs']['2'], '投影B');
      expect(exported['cameras']['1'], '主位');
      expect(exported['cameraPresets']['3'], '全景');

      // 清空后导入应恢复
      await m.resetAllInputNames();
      await m.resetAllOutputNames();
      await m.resetAllCameraNames();
      await m.resetAllCameraPresetNames();
      expect(m.getInputName(1), '1');

      await m.importNames(exported);
      expect(m.getInputName(1), '摄像机A');
      expect(m.getOutputName(2), '投影B');
      expect(m.getCameraName(1), '主位');
      expect(m.getCameraPresetName(3), '全景');
    });

    test('导入仅写入出现的键，不清除其它名称', () async {
      final ChannelNameManager m = ChannelNameManager();
      await m.saveInputName(1, '保留A');
      await m.saveInputName(2, '保留B');

      // 只导入通道2的新名字
      await m.importNames(<String, dynamic>{
        'matrixInputs': <String, dynamic>{'2': '改B'},
      });
      expect(m.getInputName(1), '保留A'); // 未被清除
      expect(m.getInputName(2), '改B');
    });
  });

  group('TOML 编解码往返', () {
    test('payload 经 TOML 编码再解码可还原嵌套结构', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'app': 'center_control_app',
        'schemaVersion': 1,
        'config': <String, dynamic>{
          'cipHost': '9.9.9.9',
          'cameraDevices': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': '主摄像机',
              'ip': '192.168.0.222',
              'port': 1259,
              'useTcp': false,
            },
          ],
        },
        'channelNames': <String, dynamic>{
          'matrixInputs': <String, dynamic>{'1': '摄像机A'},
        },
      };

      final TomlDocument doc = TomlDocument.fromMap(payload);
      final TomlPrettyPrinter printer = TomlPrettyPrinter();
      doc.acceptVisitor(printer);
      final String toml = printer.toString();

      final Map<String, dynamic> back = TomlDocument.parse(toml).toMap();
      expect(back['app'], 'center_control_app');
      expect((back['config'] as Map)['cipHost'], '9.9.9.9');

      final Object? cam = (back['config'] as Map)['cameraDevices'];
      expect(cam, isA<List>());
      expect((cam as List).first['name'], '主摄像机');
      expect((cam.first)['useTcp'], isFalse);

      final Object? mi = (back['channelNames'] as Map)['matrixInputs'];
      expect(mi, isA<Map>());
      expect((mi as Map)['1'], '摄像机A');
    });

    test('含单引号的通道名导出为双引号字符串（无三引号）', () {
      final Map<String, dynamic> payload = <String, dynamic>{
        'app': 'center_control_app',
        'schemaVersion': 1,
        'config': <String, dynamic>{'powerDeviceIp': '10.0.0.1'},
        'channelNames': <String, dynamic>{
          'matrixInputs': <String, dynamic>{
            "1": "主席团地插1#2'",
            "2": "主流'",
            "3": "视频采集卡'",
            "4": "'",
          },
        },
      };

      final String toml = ConfigImportExport.serializeToml(payload);

      // 绝不能出现三单引号
      expect(toml, isNot(contains("'''")));
      // 含单引号的值必须用双引号包裹
      expect(toml, contains('"主席团地插1#2\'"'));
      expect(toml, contains('"主流\'"'));
      expect(toml, contains('"视频采集卡\'"'));
      // 纯单引号值也用双引号包裹
      expect(toml, contains('"\'"'));

      // 输出必须是合法 TOML，可被 toml 包解析且值完整还原
      final Map<String, dynamic> back = TomlDocument.parse(toml).toMap();
      final Object? cnRaw = back['channelNames'];
      expect(cnRaw, isNotNull);
      expect(cnRaw, isA<Map>());
      final Map<dynamic, dynamic> cn = cnRaw as Map<dynamic, dynamic>;
      final Object? miRaw = cn['matrixInputs'];
      expect(miRaw, isNotNull);
      expect(miRaw, isA<Map>());
      final Map<dynamic, dynamic> mi = miRaw as Map<dynamic, dynamic>;
      expect(mi['1'], "主席团地插1#2'");
      expect(mi['2'], "主流'");
      expect(mi['3'], "视频采集卡'");
      expect(mi['4'], "'");
    });
  });
}
