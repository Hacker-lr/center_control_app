import 'package:flutter/material.dart';
import '../services/device_config.dart';

/// ============================================================
/// 显示通道重命名对话框
/// [typeName] - 通道类型名称（如"输入"、"输出"）
/// [channelNumber] - 通道编号
/// [currentName] - 当前名称
/// [onConfirm] - 确认回调，传入新名称
/// 所有颜色与尺寸参数取自 DeviceConfig 全局配置
/// ============================================================
/// 
/// 弹出一个Material风格的AlertDialog，用于修改通道的名称。
/// 用户可以输入新名称，点击确定后通过回调函数返回新名称。
/// 对话框会自动聚焦到输入框，并预置当前名称供用户编辑。
/// 
/// [context] - BuildContext上下文，用于显示对话框
/// [typeName] - 通道类型的中文名称，用于构建对话框标题（如"输入"、"输出"）
/// [channelNumber] - 通道的编号，从1开始，用于构建对话框标题
/// [currentName] - 通道的当前名称，会预置在输入框中
/// [onConfirm] - 确认重命名时的回调函数，接收用户输入的新名称（已去除首尾空格）
Future<void> showRenameDialog(
  BuildContext context, {
  required String typeName,
  required int channelNumber,
  required String currentName,
  required ValueChanged<String> onConfirm,
}) async {
  // 创建文本编辑控制器，并预置当前通道名称
  // 这样用户打开对话框时可以直接编辑，无需重新输入
  final TextEditingController controller = TextEditingController(
    text: currentName,
  );

  // 显示Material风格的对话框
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      // 对话框背景色取自全局配置
      backgroundColor: DeviceConfig.colorDialogBg,
      // 对话框标题：格式为"重命名 {typeName}{channelNumber}"（如"重命名 输入1"）
      title: Text(
        '重命名 $typeName$channelNumber',
        style: TextStyle(color: Colors.grey[200]),
      ),
      // 对话框内容：单行文本输入框
      content: TextField(
        // 绑定之前创建的文本编辑控制器
        controller: controller,
        // 打开对话框后自动聚焦到输入框，方便用户直接输入
        autofocus: true,
        // 限制输入长度，最大值取自全局配置
        maxLength: DeviceConfig().channelNameMaxLength,
        // 输入框装饰配置
        decoration: InputDecoration(
          // 输入框提示文字
          hintText: '请输入新名称',
          hintStyle: TextStyle(color: Colors.grey[500]),
          // 输入框未聚焦时的边框样式
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[700]!),
            borderRadius: BorderRadius.circular(8),
          ),
          // 输入框聚焦时的边框样式，使用主题强调色
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: DeviceConfig.colorAccent),
            borderRadius: BorderRadius.circular(8),
          ),
          // 输入框背景色取自全局配置
          fillColor: DeviceConfig.colorDialogFieldBg,
          filled: true,
        ),
        // 输入文字颜色为白色，适配深色主题
        style: const TextStyle(color: Colors.white),
      ),
      // 对话框底部操作按钮
      actions: [
        // 取消按钮：关闭对话框，不执行任何操作
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: Colors.grey[400])),
        ),
        // 确定按钮：获取输入内容并执行回调
        TextButton(
          onPressed: () {
            // 获取输入框内容并去除首尾空格
            final String newName = controller.text.trim();
            // 通过回调函数将新名称传递给调用方
            onConfirm(newName);
            // 关闭对话框
            Navigator.pop(context);
          },
          child: const Text('确定',
              style: TextStyle(color: DeviceConfig.colorAccent)),
        ),
      ],
    ),
  );
}
