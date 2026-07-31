// Widget 测试：验证 _AdaptiveChannelLabel 二分算法在窗口化 / 全屏（含窄按钮）
// 场景下，任意长度命名都能在 2 行内完整显示（不裁切）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:center_control_app/widgets/channel_button.dart';

void main() {
  const double base = 15.0;

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

  // 验证命名在给定按钮尺寸下，最终渲染字号能让 2 行完整装下（不裁切）
  Future<void> expectFitsTwoLines(
    WidgetTester tester,
    String label,
    double w,
    double h,
  ) async {
    await pumpButton(tester, label, w, h);
    final textFinder = find.byType(Text);
    final Text t = tester.widget(textFinder.first);
    // 必须用 TextPainter 复核：此字号下 2 行真装得下（didExceedMaxLines=false）
    final double maxW = w * 0.84; // (1 - 2*0.08)
    final double maxH = h * 0.80; // (1 - 2*0.10)
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: t.style!.fontSize,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: maxW);
    expect(
      tp.didExceedMaxLines,
      false,
      reason: '$label @ ${w}x$h: 字号 ${t.style!.fontSize} 下 2 行仍装不下',
    );
    expect(
      tp.height,
      lessThanOrEqualTo(maxH + 0.5),
      reason: '$label @ ${w}x$h: 2 行总高超可用区',
    );
  }

  testWidgets('窗口化 4 列按钮（宽）', (tester) async {
    // w=95,h=60 → maxW=79.8, maxH=48
    for (final n in [
      '1',
      '国网',
      '国网输入2',
      '电视剧环啊2341234',
      '一二三四五六七八九十十一十二十三十四十五十六十七十八十九二十', // 20 中文
    ]) {
      await expectFitsTwoLines(tester, n, 95.0, 60.0);
    }
  });

  testWidgets('全屏 8 列窄按钮（关键回归场景）', (tester) async {
    // 全屏时通道>8 变 8 列，按钮变窄：w≈45,h=60 → maxW≈37.8, maxH=48
    // 之前 FittedBox 方案在此场景下 2 行总高≤maxH 不缩放 → 字保持 baseFont
    // 但 maxLines:2 只渲染前几字 → 裁切。二分算法应压字号到 2 行装下。
    for (final n in [
      '1',
      '国网',
      '国网输入2',
      '电视剧环啊2341234',
      '一二三四五六七八九十十一十二十三十四十五十六十七十八十九二十', // 20 中文
      '一二三四五六七八九十十一十二十三十四十五十六十七十八十九二十二十一二十二十二', // 24 中文
    ]) {
      await expectFitsTwoLines(tester, n, 45.0, 60.0);
    }
  });

  testWidgets('超长命名窄按钮（合理边界）', (tester) async {
    // 20 中文 + 极窄按钮 w=35,h=50 → maxW≈29.4, maxH=40
    // 1px 字号下 29.4px 宽约装 26 字/行，2 行 52 字 > 20 字，能完整显示
    final names = [
      '超级长的通道名称测试一下完整显示效果', // 16 字
      '一二三四五六七八九十十一十二十三十四十五十六十七十八十九二十', // 20 中文
    ];
    for (final n in names) {
      await expectFitsTwoLines(tester, n, 35.0, 50.0);
    }
  });

  testWidgets('短名保持基准字号不缩小', (tester) async {
    await pumpButton(tester, '1', 95.0, 60.0);
    final Text t = tester.widget(find.byType(Text).first);
    expect(t.style!.fontSize, base);
  });
}
