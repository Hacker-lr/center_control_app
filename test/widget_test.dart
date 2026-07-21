import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:center_control_app/main.dart';

void main() {
  testWidgets('应用可正常启动', (WidgetTester tester) async {
    await tester.pumpWidget(const CenterControlApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
