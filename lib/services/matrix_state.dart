import 'package:flutter/foundation.dart';

/// ============================================================
/// 视频矩阵 - 共享映射状态（单例模式）
/// 用于在大屏控制页和视频矩阵页之间同步输入/输出通道绑定关系
/// 确保两个页面看到的通道映射状态完全一致、实时联动
/// ============================================================
class MatrixState extends ChangeNotifier {
  // ---------- 单例模式 ----------
  static final MatrixState _instance = MatrixState._internal();

  /// 工厂构造函数：返回全局唯一的单例实例
  factory MatrixState() => _instance;

  MatrixState._internal();

  // ---------- 通道映射状态 ----------

  /// 当前被选中的输入通道索引（1-based，0表示未选中）
  /// 同一时刻只能有一个输入通道处于选中状态
  int _selectedInputIndex = 0;

  /// 输出通道→输入通道 的映射关系表
  /// key: 输出通道索引 (1-based)
  /// value: 该输出通道当前绑定的输入通道索引 (1-based)
  /// 一个输出通道只能绑定一个输入通道（写入时直接覆盖旧值）
  final Map<int, int> _outputToInputMap = {};

  // ---------- 公开属性 ----------

  /// 获取当前选中的输入通道索引（0表示未选中）
  int get selectedInputIndex => _selectedInputIndex;

  // ---------- 公开方法 ----------

  /// ============================================================
  /// 获取绑定到指定输入通道的所有输出通道编号列表
  /// [inputIndex] 输入通道编号 (1-based)
  /// 返回该输入通道下所有输出通道的编号列表（已排序）
  /// ============================================================
  List<int> getOutputsForInput(int inputIndex) {
    final List<int> outputs = [];
    _outputToInputMap.forEach((output, input) {
      if (input == inputIndex) {
        outputs.add(output);
      }
    });
    outputs.sort();
    return outputs;
  }

  /// ============================================================
  /// 获取指定输出通道当前绑定的输入通道编号
  /// [outputChannel] 输出通道编号 (1-based)
  /// 返回绑定的输入通道编号，null 表示该输出通道未绑定任何输入
  /// ============================================================
  int? getBoundInput(int outputChannel) {
    return _outputToInputMap[outputChannel];
  }

  /// ============================================================
  /// 选择/取消选择输入通道
  /// 1. 如果 channelNumber 等于当前选中的输入 → 取消选中
  /// 2. 否则切换到 channelNumber 对应的输入通道
  /// [channelNumber] 输入通道编号 (1-based)
  /// ============================================================
  void selectInput(int channelNumber) {
    if (_selectedInputIndex == channelNumber) {
      // 再次点击已选中的输入通道：取消选中
      _selectedInputIndex = 0;
    } else {
      // 切换到新的输入通道
      _selectedInputIndex = channelNumber;
    }
    notifyListeners();
  }

  /// ============================================================
  /// 将输出通道绑定到输入通道
  /// 直接赋值自动覆盖旧绑定（一个输出通道只能对应一个输入通道）
  /// [outputChannel] 输出通道编号 (1-based)
  /// [inputChannel]  输入通道编号 (1-based)
  /// ============================================================
  void bindOutput(int outputChannel, int inputChannel) {
    _outputToInputMap[outputChannel] = inputChannel;
    notifyListeners();
  }
}
