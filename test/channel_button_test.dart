// Widget 测试：验证 _AdaptiveChannelLabel
//   - 始终 maxLines:2（"最多两行"硬需求）
//   - 15 字内（channelNameMaxLength）名字：二分字号保证 2 行内完整显示（"显示全"）
//   - 上下两行字号一致（单 Text + 单一 style，天然保证）
//   - 超限旧数据（>15 字）：保持 2 行，clip 裁切兜底（输入已限制，正常不可达）
//   - 短名保持基准字号不放大
// 测量样式继承主题字体（测试环境为默认字体，与渲染一致）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:center_control_app/widgets/channel_button.dart';
import 'package:center_control_app/services/device_config.dart';

void main() {
  const double baseRatio = DeviceConfig.buttonFontSizeRatio; // 0.25
  const double padH = DeviceConfig.buttonPaddingHorizontalRatio; // 0.08
  const double padV = DeviceConfig.buttonPaddingVerticalRatio; // 0.10
  const int maxLen = 15; // 与 ConfigDefaults.channelNameMaxLength 一致（两行+全的字数上限）

  Future<void> pumpButton(
    WidgetTester tester,
    String label,
    double w,
    double h,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: w,
              height: h,
              child: ChannelButton(
                label: label,
                width: w,
                height: h,
                channelType: 'input',
                channelNumber: 1,
                isHighlighted: false,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 断言：maxLines==2；若名字在字数上限内，则所选字号下 2 行内完整显示。
  Future<Text> expectTwoLineCap(
    WidgetTester tester,
    String label,
    double w,
    double h,
  ) async {
    await pumpButton(tester, label, w, h);
    final Text t = tester.widget(find.byType(Text).first);
    expect(t.maxLines, 2, reason: '$label @ ${w}x$h: 必须最多两行');

    final double maxW = w * (1 - 2 * padH);
    final double maxH = h * (1 - 2 * padV);
    final double baseFont = h * baseRatio;

    // 字号必须 ≤ baseFont（不放大）
    expect(
      t.style!.fontSize!,
      lessThanOrEqualTo(baseFont + 1e-6),
      reason: '$label @ ${w}x$h: 字号不应超过基准',
    );

    // 若名字未超字数上限（输入层已保证），必须 2 行内完整显示
    if (label.length <= maxLen) {
      final TextPainter tp = TextPainter(
        text: TextSpan(text: label, style: t.style),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: maxW);
      expect(
        tp.didExceedMaxLines,
        isFalse,
        reason: '$label @ ${w}x$h: 字数≤上限($maxLen)却未能 2 行内完整显示（字号${t.style!.fontSize}）',
      );
      expect(
        tp.height,
        lessThanOrEqualTo(maxH + 0.001),
        reason: '$label @ ${w}x$h: 2 行总高超过可用高度',
      );
    }
    return t;
  }

  testWidgets('窗口化 4 列按钮（宽）：2 行 + 完整显示', (tester) async {
    // w=95,h=60 → maxW=79.8, maxH=48, baseFont=15
    for (final n in [
      '1',
      '国网',
      '国网输入2',
      '电视剧环啊',
      '国网行政3.0主流', // 9 字符 >8？"国网行政3.0主流"=8中文+3数字+点=12字符，超限
    ]) {
      await expectTwoLineCap(tester, n, 95.0, 60.0);
    }
  });

  testWidgets('全屏 8 列最窄按钮：15 字内完整两行', (tester) async {
    // w=45,h=60 → maxW=37.8, maxH=48, baseFont=15
    // 全部 ≤15 字：必须 2 行内完整显示（含 15 字临界）
    for (final n in [
      '1',
      '国网',
      '国网输入',
      '国网行政3.0', // 7 字符
      '一二三四五六七八', // 8 中文
      '测试通道一二三四五六七八九十一', // 15 字符（临界）
    ]) {
      final t = await expectTwoLineCap(tester, n, 45.0, 60.0);
      // 15 字内名字字号应 ≥ 最小字号×保险系数
      expect(t.style!.fontSize!, greaterThanOrEqualTo(4.0 * 0.95 - 1e-6));
      // 上下两行字号一致：整个标签只渲染一个 Text（单一 style）
      expect(find.byType(Text), findsOneWidget,
          reason: '$n: 两行应共用同一 Text/style，字号一致');
    }
  });

  testWidgets('超限旧数据（>15 字）：保持两行裁切兜底，不报错', (tester) async {
    // 输入已限制 ≤15 字；旧数据超限时保持 maxLines:2（裁切兜底）
    final t = await expectTwoLineCap(tester, '一二三四五六七八九十十一十二十三十四十五十六十七十八十九二十', 45.0, 60.0);
    expect(t.maxLines, 2);
  });

  testWidgets('短名保持基准字号不放大', (tester) async {
    final t = await expectTwoLineCap(tester, '1', 95.0, 60.0);
    expect(t.style!.fontSize, 60.0 * baseRatio);
  });
}
