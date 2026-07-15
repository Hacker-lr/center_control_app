import 'package:flutter/material.dart';
import '../services/matrix_connection.dart';
import '../services/device_config.dart';
import '../services/device_connection.dart';

/// ============================================================
/// 视频矩阵控制页面
/// 布局：上方为信号输出按钮阵列，下方为信号输入按钮阵列
/// 中间为操作说明标语
/// 功能逻辑：
/// 1. 先点击输入按钮选中输入通道（高亮该输入）
/// 2. 再点击输出按钮进行通道绑定（高亮该输出并发送指令）
/// 3. 一个输入通道可绑定多个输出通道
/// 4. 一个输出通道只能绑定一个输入通道
/// 5. 同一时刻只能选中一个输入通道
/// ============================================================
class VideoMatrixPage extends StatefulWidget {
  const VideoMatrixPage({super.key});

  @override
  State<VideoMatrixPage> createState() => _VideoMatrixPageState();
}

class _VideoMatrixPageState extends State<VideoMatrixPage> {
  // ---------- 矩阵映射状态 ----------

  /// 当前被选中（高亮）的输入通道索引（1-based，0表示未选中）
  /// 同一时刻只能有一个输入通道处于选中状态
  int _selectedInputIndex = 0;

  /// 输出通道→输入通道 的映射关系表
  /// key: 输出通道索引 (1-based)
  /// value: 该输出通道当前绑定的输入通道索引 (1-based)
  /// 一个输出通道只能对应一个输入通道（写入时直接覆盖旧值）
  final Map<int, int> _outputToInputMap = {};

  // ---------- 设备连接服务 ----------

  /// 视频矩阵设备连接服务（单例）
  final MatrixConnection _matrixConnection = MatrixConnection();

  /// 时序电源设备连接服务引用（用于保持连接感知）
  final DeviceConnection _deviceConnection = DeviceConnection();

  // ---------- 通道数量常量 ----------

  /// 从配置读取输入通道总数
  int get _inputCount => DeviceConfig.matrixInputCount;

  /// 从配置读取输出通道总数
  int get _outputCount => DeviceConfig.matrixOutputCount;

  /// ============================================================
  /// 构建页面主体结构
  /// 垂直方向分为三部分：上方输出区 → 中间说明区 → 下方输入区
  /// ============================================================
  @override
  Widget build(BuildContext context) {
    // 同时监听矩阵连接和设备连接的状态变化
    return ListenableBuilder(
      listenable: Listenable.merge([_matrixConnection, _deviceConnection]),
      builder: (context, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ---- 页面副标题 ----
                Text(
                  '视频矩阵控制',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: 10),

                // ---- 矩阵设备连接状态指示器 ----
                _buildConnectionStatusIndicator(),

                const SizedBox(height: 16),

                // ============ 上方：输出通道按钮阵列 ============
                _buildSectionLabel('信号输出'),
                const SizedBox(height: 8),

                // 输出按钮区域（使用Wrap实现自适应的多行布局）
                _buildOutputButtonsGrid(),

                // ============ 中间：操作说明区 ============
                const SizedBox(height: 16),

                // 装饰分割线
                Container(
                  height: 1.0,
                  color: const Color(0xFF30363D),
                ),

                const SizedBox(height: 12),

                // 操作说明标语
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F4068).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1F4068).withAlpha(80),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 说明图标
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: const Color(0xFF6B9BD2),
                      ),
                      const SizedBox(width: 8),
                      // 说明文字
                      Flexible(
                        child: Text(
                          '先点击下面的信号输入  再点击上面的信号输出',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF6B9BD2),
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 装饰分割线
                Container(
                  height: 1.0,
                  color: const Color(0xFF30363D),
                ),

                // ============ 下方：输入通道按钮阵列 ============
                const SizedBox(height: 16),
                _buildSectionLabel('信号输入'),
                const SizedBox(height: 8),

                // 输入按钮区域
                _buildInputButtonsGrid(),

                const SizedBox(height: 12),

                // ---- 当前操作状态提示 ----
                _buildOperationHintText(),

                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ============================================================
  /// 构建区域标签（如"信号输出" / "信号输入"）
  /// ============================================================
  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建输出通道按钮网格
  /// 使用Wrap组件实现自适应换行排列
  /// 每个输出按钮根据是否有绑定输入通道显示不同状态
  /// ============================================================
  Widget _buildOutputButtonsGrid() {
    return Wrap(
      spacing: 10, // 水平间距
      runSpacing: 10, // 垂直间距
      children: List.generate(_outputCount, (index) {
        // 将0-based索引转换为1-based通道编号
        final int channelNumber = index + 1;

        // 获取该输出通道当前绑定的输入通道编号
        final int? boundInput = _outputToInputMap[channelNumber];

        // 判断该输出按钮是否应高亮：
        // 当有选中的输入通道，且该输出通道绑定的输入就是选中的输入时，高亮
        final bool isHighlighted = _selectedInputIndex > 0 &&
            boundInput == _selectedInputIndex;

        return _buildChannelButton(
          label: '$channelNumber',
          channelType: '输出',
          channelNumber: channelNumber,
          isHighlighted: isHighlighted,
          isInput: false,
          hasBinding: boundInput != null,
          highlightColor: _isChannelHighlightedAsInput(channelNumber)
              ? const Color(0xFF3E6B48) // 输出绑定到选中输入：绿色
              : null,
        );
      }),
    );
  }

  /// ============================================================
  /// 构建输入通道按钮网格
  /// 使用Wrap组件实现自适应换行排列
  /// 当前选中的输入通道按钮会高亮显示
  /// ============================================================
  Widget _buildInputButtonsGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_inputCount, (index) {
        // 将0-based索引转换为1-based通道编号
        final int channelNumber = index + 1;

        // 获取该输入通道下绑定的输出通道数量
        final int outputCount = _getOutputsForInput(channelNumber).length;

        // 判断该输入按钮是否为当前选中
        final bool isSelected = _selectedInputIndex == channelNumber;

        return _buildChannelButton(
          label: '$channelNumber',
          channelType: '输入',
          channelNumber: channelNumber,
          isHighlighted: isSelected,
          isInput: true,
          hasBinding: outputCount > 0,
          bindingCount: outputCount,
          highlightColor: isSelected
              ? const Color(0xFF1F4068) // 输入选中：蓝色
              : null,
        );
      }),
    );
  }

  /// ============================================================
  /// 构建单个通道按钮
  /// [label] 按钮显示文字（通道编号）
  /// [channelType] 通道类型："输入"或"输出"
  /// [channelNumber] 通道编号 (1-based)
  /// [isHighlighted] 是否处于高亮状态
  /// [isInput] 是否为输入按钮（true=输入, false=输出）
  /// [hasBinding] 是否有绑定关系
  /// [bindingCount] 绑定数量（仅输入按钮有意义）
  /// [highlightColor] 高亮时的颜色
  /// ============================================================
  Widget _buildChannelButton({
    required String label,
    required String channelType,
    required int channelNumber,
    required bool isHighlighted,
    required bool isInput,
    required bool hasBinding,
    int bindingCount = 0,
    Color? highlightColor,
  }) {
    // 确定按钮的实际高亮颜色
    final Color activeColor = highlightColor ?? const Color(0xFF1F4068);

    // 计算按钮尺寸（根据通道总数动态调整，保证一行至少能放下4个）
    final double screenWidth = MediaQuery.of(context).size.width;
    final double availableWidth = screenWidth - 32; // 减去水平padding
    final int maxPerRow = 4; // 每行最多4个
    final double buttonWidth =
        (availableWidth - (maxPerRow - 1) * 10) / maxPerRow - 12;
    final double buttonSize = buttonWidth.clamp(56.0, 80.0);

    return GestureDetector(
      onTap: () {
        if (isInput) {
          // 点击的是输入按钮：选中/切换输入通道
          _onInputChannelTapped(channelNumber);
        } else {
          // 点击的是输出按钮：尝试绑定到当前选中的输入通道
          _onOutputChannelTapped(channelNumber);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          // 圆角矩形样式
          borderRadius: BorderRadius.circular(12),
          // 高亮状态：填充颜色 + 外发光阴影
          color: isHighlighted
              ? activeColor.withAlpha(220)
              : const Color(0xFF2A2A3E),
          // 阴影效果
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(120),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
          // 边框：高亮时用彩色，否则用深灰色
          border: Border.all(
            color: isHighlighted ? activeColor : Colors.grey[700]!,
            width: isHighlighted ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 通道类型标签
            Text(
              channelType,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isHighlighted
                    ? Colors.white.withAlpha(200)
                    : Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            // 通道编号
            Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? Colors.white : Colors.grey[400],
              ),
            ),
            // 输入按钮如果有绑定输出，显示绑定数量小标记
            if (isInput && bindingCount > 0) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.white.withAlpha(60)
                      : const Color(0xFF1F4068).withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$bindingCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? Colors.white
                        : const Color(0xFF6B9BD2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ============================================================
  /// 构建视频矩阵设备的连接状态指示器
  /// 样式与电源控制页保持一致
  /// ============================================================
  Widget _buildConnectionStatusIndicator() {
    final status = _matrixConnection.status;

    // 初始化变量为默认值（编译器需要所有路径都有赋值）
    String statusText = '矩阵设备未连接';
    Color statusColor = Colors.grey[500]!;
    IconData statusIcon = Icons.link_off;

    switch (status) {
      case ConnectionStatus.connected:
        statusText = '矩阵设备已连接';
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.link;
        break;
      case ConnectionStatus.connecting:
        statusText = '正在连接矩阵设备...';
        statusColor = const Color(0xFFFFA726);
        statusIcon = Icons.sync;
        break;
      case ConnectionStatus.error:
        statusText = '矩阵连接失败，自动重连中...';
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error_outline;
        break;
      case ConnectionStatus.disconnected:
        // 使用默认值，无需额外赋值
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withAlpha(80),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 已连接时显示心跳计数
          if (status == ConnectionStatus.connected) ...[
            const SizedBox(width: 10),
            Text(
              '心跳 #${_matrixConnection.heartbeatCount}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ============================================================
  /// 构建当前操作状态提示文本
  /// 显示选中了哪个输入通道及其绑定的输出通道信息
  /// ============================================================
  Widget _buildOperationHintText() {
    String hintText;

    if (_selectedInputIndex == 0) {
      // 未选中任何输入通道
      hintText = '请先点击下方输入通道，再点击上方输出通道进行绑定';
    } else {
      // 已选中某输入通道
      final outputs = _getOutputsForInput(_selectedInputIndex);
      if (outputs.isEmpty) {
        hintText = '已选中：输入 $_selectedInputIndex — 请点击上方输出通道绑定';
      } else {
        // 显示该输入通道下已绑定的输出通道列表
        final outputList = outputs.join('、');
        hintText = '选中：输入 $_selectedInputIndex | 已绑定输出：$outputList';
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        hintText,
        key: ValueKey(hintText),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// ============================================================
  /// 判断某个输出通道是否因绑定到当前选中的输入而应高亮
  /// [channelNumber] 输出通道编号 (1-based)
  /// ============================================================
  bool _isChannelHighlightedAsInput(int channelNumber) {
    if (_selectedInputIndex == 0) return false;
    return _outputToInputMap[channelNumber] == _selectedInputIndex;
  }

  /// ============================================================
  /// 获取绑定到指定输入通道的所有输出通道编号列表
  /// [inputIndex] 输入通道编号 (1-based)
  /// 返回该输入通道下所有输出通道的编号列表（排序）
  /// ============================================================
  List<int> _getOutputsForInput(int inputIndex) {
    // 遍历映射表，找出所有value等于inputIndex的key（输出通道）
    final List<int> outputs = [];
    _outputToInputMap.forEach((output, input) {
      if (input == inputIndex) {
        outputs.add(output);
      }
    });
    outputs.sort(); // 排序后返回
    return outputs;
  }

  /// ============================================================
  /// 处理输入通道按钮点击
  /// 1. 如果点击的是已选中的输入，取消选中
  /// 2. 如果点击的是其他输入，切换选中到该输入
  /// [channelNumber] 输入通道编号 (1-based)
  /// ============================================================
  void _onInputChannelTapped(int channelNumber) {
    setState(() {
      if (_selectedInputIndex == channelNumber) {
        // 再次点击已选中的输入通道：取消选中
        _selectedInputIndex = 0;
      } else {
        // 切换到新的输入通道
        _selectedInputIndex = channelNumber;
      }
    });
  }

  /// ============================================================
  /// 处理输出通道按钮点击
  /// 1. 如果没有选中输入通道，提示用户先选输入
  /// 2. 如果有选中输入通道，将输出通道绑定到该输入
  /// 3. 如果该输出之前绑定到其他输入，则自动解绑（一个输出只能一个输入）
  /// 4. 向视频矩阵设备发送切换指令
  /// [channelNumber] 输出通道编号 (1-based)
  /// ============================================================
  void _onOutputChannelTapped(int channelNumber) {
    // 前提条件：必须先选中一个输入通道
    if (_selectedInputIndex == 0) {
      // 显示SnackBar提示用户先选择输入
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先点击下方的信号输入通道'),
          backgroundColor: const Color(0xFF3A5A8C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // 检查此输出通道以前是否绑定过其他输入通道
    final int? previousInput = _outputToInputMap[channelNumber];

    setState(() {
      // 建立新的绑定关系（直接赋值，自动覆盖旧绑定）
      _outputToInputMap[channelNumber] = _selectedInputIndex;
    });

    // [开发者可修改] 视频矩阵切换控制指令格式
    // 根据 [DeviceConfig.matrixSendAsHex] 配置自动选择 ASCII 或 16进制 格式
    // ASCII模式示例: "MATRIX:IN3->OUT5\r\n" (输入3切换到输出5)
    // 16进制模式模板: "02 03 {input02X} {output02X} FF"
    //   {input02X} 和 {output02X} 会自动替换为2位16进制通道编号
    final String command;
    if (DeviceConfig.matrixSendAsHex) {
      // 16进制模式：将通道编号格式化为2位16进制大写后替换到模板中
      command = DeviceConfig.hexMatrixSwitchCmd
          .replaceAll(
            '{input02X}',
            _selectedInputIndex.toRadixString(16).padLeft(2, '0').toUpperCase(),
          )
          .replaceAll(
            '{output02X}',
            channelNumber.toRadixString(16).padLeft(2, '0').toUpperCase(),
          );
    } else {
      // ASCII模式：使用可读的文本指令格式
      command = 'MATRIX:IN$_selectedInputIndex->OUT$channelNumber\r\n';
    }

    // 向视频矩阵设备发送切换指令
    _matrixConnection.sendCommand(command);

    // 如果输出通道之前绑定给了另一个输入，在日志中记录解绑信息
    if (previousInput != null && previousInput != _selectedInputIndex) {
      debugPrint('[矩阵控制] 输出$channelNumber 已从输入$previousInput '
          '切换到输入$_selectedInputIndex');
    }
  }
}
