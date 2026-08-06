import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/device_config.dart';

/// ============================================================
/// 系统配置页通用表单构件
/// 普通模式配置页（SystemConfigPage）与中控 VTP 配置页（VtpConfigPage）
/// 共用，避免重复实现。所有构件均为无状态纯 UI，所需状态通过回调上抛。
/// ============================================================

/// 提示文字颜色
const Color _hintColor = Color(0xFF757575);

/// 构建配置分组卡片（可展开/收起）
Widget buildGroupCard({
  required String title,
  required IconData icon,
  required bool isExpanded,
  required VoidCallback onToggle,
  required List<Widget> children,
}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    margin: const EdgeInsets.symmetric(vertical: 6.0),
    decoration: BoxDecoration(
      color: DeviceConfig.colorDialogBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isExpanded
            ? DeviceConfig.colorAccent.withAlpha(110)
            : DeviceConfig.colorCardBorder,
      ),
      boxShadow: isExpanded
          ? [
              BoxShadow(
                color: DeviceConfig.colorAccent.withAlpha(18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: DeviceConfig.colorAccent.withAlpha(
                        isExpanded ? 45 : 25,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: DeviceConfig.colorAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isExpanded
                            ? DeviceConfig.colorAccent
                            : Colors.white,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.expand_more,
                      color: isExpanded
                          ? DeviceConfig.colorAccent
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 4),
                  color: DeviceConfig.colorCardBorder,
                ),
                ...children,
              ],
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
        ),
      ],
    ),
  );
}

/// 分组内小节标题（强调色竖条 + 文字）
Widget buildSectionLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: DeviceConfig.colorAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    ),
  );
}

/// 并排双数字输入框（用于成对的 join 配置，节省纵向空间）
Widget buildDualInputRow({
  required String labelA,
  required TextEditingController controllerA,
  String? hintA,
  required String labelB,
  required TextEditingController controllerB,
  String? hintB,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: buildInputRow(
          label: labelA,
          controller: controllerA,
          isNumber: true,
          hintText: hintA,
          maxLength: 4,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: buildInputRow(
          label: labelB,
          controller: controllerB,
          isNumber: true,
          hintText: hintB,
          maxLength: 4,
        ),
      ),
    ],
  );
}

/// 构建输入框行（标签 + 输入框）
Widget buildInputRow({
  required String label,
  required TextEditingController controller,
  bool isNumber = false,
  String? hintText,
  int maxLength = 50,
  TextInputType? keyboardType,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 5),
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
Widget buildIpPortRow({
  required String label,
  required TextEditingController ipController,
  required TextEditingController portController,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 5),
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
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
/// - [hideConnection]：为 true 时（中控 VTP 模式）隐藏 IP/端口等直连字段，
///   仅保留序号与删除按钮（摄像头个数仍用于 Crestron 选择基址映射）
Widget buildCameraItem({
  required int index,
  required Map<String, TextEditingController> ctrl,
  required VoidCallback onRemove,
  required bool canRemove,
  bool hideConnection = false,
  Animation<double>? connectionFade,
  bool useTcp = true,
  ValueChanged<bool>? onUseTcpChanged,
}) {
  // VTP 开时（hideConnection=true）：随动画先淡出、过半后才收起空间；
  // VTP 关时：空间先展开、随后淡入。与时序电源等直连字段过渡保持一致。
  final bool showConn = !hideConnection || (connectionFade?.value ?? 0) > 0.5;
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: canRemove ? onRemove : null,
              disabledColor: _hintColor,
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 380),
          curve: Curves.easeInOut,
          child: FadeTransition(
            opacity: connectionFade ?? const AlwaysStoppedAnimation(1.0),
            child: showConn
                ? Column(
                    children: [
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
                                border: Border.all(
                                  color: DeviceConfig.colorButtonBorder,
                                ),
                              ),
                              child: TextField(
                                controller: ctrl['ip'],
                                maxLength: 15,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'IP',
                                  hintStyle: TextStyle(
                                    color: _hintColor,
                                    fontSize: 12,
                                  ),
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
                                border: Border.all(
                                  color: DeviceConfig.colorButtonBorder,
                                ),
                              ),
                              child: TextField(
                                controller: ctrl['port'],
                                maxLength: 5,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  hintText: '端口',
                                  hintStyle: TextStyle(
                                    color: _hintColor,
                                    fontSize: 12,
                                  ),
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            '协议',
                            style: TextStyle(fontSize: 13, color: _hintColor),
                          ),
                          const SizedBox(width: 10),
                          ToggleButtons(
                            isSelected: [useTcp, !useTcp],
                            onPressed: (int idx) {
                              onUseTcpChanged?.call(idx == 0);
                            },
                            borderRadius: BorderRadius.circular(6),
                            selectedColor: Colors.white,
                            color: _hintColor,
                            fillColor: DeviceConfig.colorAccent.withAlpha(180),
                            borderColor: DeviceConfig.colorButtonBorder,
                            selectedBorderColor: DeviceConfig.colorAccent,
                            constraints: const BoxConstraints(
                              minHeight: 32,
                              minWidth: 56,
                            ),
                            children: const [
                              Text('TCP', style: TextStyle(fontSize: 13)),
                              Text('UDP', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}

/// 构建双列数字输入框（输入通道 + 输出通道）
Widget buildChannelCountRow({
  required TextEditingController inputController,
  required TextEditingController outputController,
}) {
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
                  controller: inputController,
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
                  controller: outputController,
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
Widget buildProtocolSwitch({
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
              buildProtocolOption('TCP', true, value, onChanged),
              Container(
                width: 1,
                height: 32,
                color: DeviceConfig.colorButtonBorder,
              ),
              buildProtocolOption('UDP', false, value, onChanged),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 构建品牌选择下拉框
Widget buildBrandDropdown({
  required String label,
  required String currentValue,
  required List<String> brandNames,
  required ValueChanged<String> onChanged,
}) {
  // 防御：品牌列表可能不含当前存储值（如默认品牌未纳入某设备列表），
  // 或存在重复项。这里去重并把 value 钳制到列表中的有效项，
  // 避免 DropdownButton 断言（value 必须在选项中恰好出现一次）导致整页崩溃。
  final List<String> uniqueBrands = brandNames.toSet().toList();
  final String effectiveValue = uniqueBrands.contains(currentValue)
      ? currentValue
      : (uniqueBrands.isNotEmpty ? uniqueBrands.first : currentValue);
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
              value: effectiveValue,
              isExpanded: true,
              items: uniqueBrands.map((brand) {
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
Widget buildProtocolOption(
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
Widget buildPageVisibilitySwitch({
  required String title,
  String? subtitle,
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
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
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

/// 构建分屏模式按钮配置行：左侧复选框(是否显示) + 标签 + 可选右侧 join 输入框
///
/// 用于大屏分屏模式的"可勾选显隐 + 独立 join"配置。
/// - [label]：分屏模式名称（如"全屏"、"二分屏"）
/// - [show]：当前是否显示该按钮
/// - [onShowChanged]：勾选状态变化回调（直接写 DeviceConfig）
/// - [joinController]：为 null 时仅显示开关（普通模式页）；非 null 时显示 join 输入框（VTP 页）
/// - [joinHint]：join 输入框占位提示
Widget buildLayoutButtonConfigRow({
  required String label,
  required bool show,
  required ValueChanged<bool> onShowChanged,
  TextEditingController? joinController,
  String? joinHint,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: DeviceConfig.colorDialogFieldBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: DeviceConfig.colorButtonBorder),
    ),
    child: Row(
      children: [
        Checkbox(
          value: show,
          activeColor: DeviceConfig.colorAccent,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (v) => onShowChanged(v ?? true),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ),
        if (joinController != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: joinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              decoration: InputDecoration(
                hintText: joinHint ?? 'join',
                hintStyle: const TextStyle(color: _hintColor, fontSize: 13),
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: DeviceConfig.colorButtonBorder),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 构建大屏分屏输出通道映射配置（区域 N → 矩阵输出通道）
///
/// 用于把大屏每个分屏区域（按顺序 区域1、区域2…）自由绑定到任意矩阵输出通道。
/// - [outputControllers]：长度需与 [areaCount] 一致，索引 i 对应"区域 i+1"的输出通道
/// - [areaCount]：需要配置的区域数量（一般取 DeviceConfig.bigScreenMaxAreaCount）
Widget buildBigScreenOutputMapping({
  required List<TextEditingController> outputControllers,
  required int areaCount,
}) {
  return Column(
    children: List.generate(areaCount, (i) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: buildInputRow(
          label: '区域${i + 1} 输出通道',
          controller: outputControllers[i],
          isNumber: true,
          hintText: '${i + 4}',
          maxLength: 3,
        ),
      );
    }),
  );
}
