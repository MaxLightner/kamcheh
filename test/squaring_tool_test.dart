import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/squaring_tool.dart';

void main() {
  test('classic 3-4-5 triangle produces expected hypotenuse', () {
    expect(rightAngleDiagonalCm(300, 400), closeTo(500, 0.000001));
  });

  test('rounding to whole centimetres is optional', () {
    final diagonal = rightAngleDiagonalCm(300, 450);
    expect(formatDiagonalCm(diagonal, roundToWholeCm: true), '541');
    expect(formatDiagonalCm(diagonal, roundToWholeCm: false), '540.83');
  });

  test('Persian and Arabic number input works in centimetres', () {
    expect(parseSquaringCentimeters('۳۰۰٫۵'), 300.5);
    expect(parseSquaringCentimeters('٤٠٠'), 400);
    expect(parseSquaringCentimeters('۲٫۵'), 2.5);
    expect(parseSquaringCentimeters('150,5'), 150.5);
  });

  test('invalid sides are rejected before computation', () {
    for (final value in ['', '۰', '-10', 'سلام', '1000001']) {
      expect(() => parseSquaringCentimeters(value), throwsFormatException);
    }
    expect(() => rightAngleDiagonalCm(double.infinity, 10),
        throwsFormatException);
  });

  testWidgets('calculator updates live and changes precision on toggle',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(
            padding: EdgeInsets.all(12), child: SquaringTool())),
      ),
    ));
    expect(find.text('گونیا سازی'), findsNothing);
    expect(find.text('۵۰۰ سانتی‌متر'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '450');
    await tester.pump();
    expect(find.text('۵۴۱ سانتی‌متر'), findsOneWidget);
    await tester.tap(find.text('رند کردن وتر به سانتی‌متر'));
    await tester.pumpAndSettle();
    expect(find.text('۵۴۰.۸۳ سانتی‌متر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow phone layout does not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(
            padding: EdgeInsets.all(12), child: SquaringTool())),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
