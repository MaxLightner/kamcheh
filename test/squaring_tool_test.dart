import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/squaring_tool.dart';
import 'package:sakhtyar/pythagorean_whole.dart';
import 'package:sakhtyar/main.dart';

void main() {
  test('classic 3-4-5 triangle produces expected hypotenuse', () {
    expect(rightAngleDiagonalCm(300, 400), closeTo(500, 0.000001));
  });

  test('display does not fake a rounded hypotenuse', () {
    final diagonal = rightAngleDiagonalCm(300, 450);
    expect(formatDiagonalCm(diagonal), '540.83');
    expect(rightAngleDiagonalCm(300, 400), 500);
  });

  test('prefers both legs ending in zero when the adjustment is modest', () {
    final adjusted = nearestWholeCentimeterTriangle(300, 450);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [280, 450, 530]);
    expect(adjusted.firstCm % 10, 0);
    expect(adjusted.secondCm % 10, 0);
    expect(adjusted.diagonalCm % 10, 0);
    expect(adjusted.firstCm * adjusted.firstCm +
        adjusted.secondCm * adjusted.secondCm,
        adjusted.diagonalCm * adjusted.diagonalCm);
  });

  test('rounds even when previous triple was exact but not easy to mark', () {
    final adjusted = nearestWholeCentimeterTriangle(33, 44);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [30, 40, 50]);
  });

  test('prefers one trailing zero if both would change too much', () {
    final adjusted = nearestWholeCentimeterTriangle(44, 66);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [45, 60, 75]);
    expect(adjusted.firstCm * adjusted.firstCm +
        adjusted.secondCm * adjusted.secondCm,
        adjusted.diagonalCm * adjusted.diagonalCm);
  });

  test('rounds worksite measurements 200 and 300 within 10 percent', () {
    final adjusted = nearestWholeCentimeterTriangle(200, 300);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [210, 280, 350]);
  });

  test('avoids large changes just to add a trailing zero', () {
    final adjusted = nearestWholeCentimeterTriangle(1, 1);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [3, 4, 5]);
  });

  test('keeps an already exact triangle unchanged', () {
    final adjusted = nearestWholeCentimeterTriangle(300, 400);
    expect([adjusted.firstCm, adjusted.secondCm, adjusted.diagonalCm],
        [300, 400, 500]);
  });

  test('a non-integer input yields integer Pythagorean measurements', () {
    final adjusted = nearestWholeCentimeterTriangle(300.5, 400.25);
    expect(adjusted.firstCm * adjusted.firstCm +
        adjusted.secondCm * adjusted.secondCm,
        adjusted.diagonalCm * adjusted.diagonalCm);
    expect(adjusted.firstCm, 300);
    expect(adjusted.secondCm, 400);
    expect(adjusted.diagonalCm, 500);
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

  testWidgets('button adjusts sides instead of truncating the hypotenuse',
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
    expect(find.text('۵۴۰.۸۳ سانتی‌متر'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.byKey(const Key('squaring-adjust-whole')));
    await tester.pumpAndSettle();
    expect(find.text('۵۳۰ سانتی‌متر'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, '280');
    expect(fields[1].controller!.text, '450');
    expect(find.textContaining('علامت‌های کار را با ابعاد جدید بزن'), findsOneWidget);
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
  testWidgets('squaring and digital meter are in guest and signed-in tools',
      (tester) async {
    await tester.pumpWidget(const SakhtyarApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابزارها').last);
    await tester.pumpAndSettle();
    expect(find.text('گونیا'), findsOneWidget);
    expect(find.text('متر دیجیتال'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Recreate AppShell: initial demo account is read only in initState.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابزارها').last);
    await tester.pumpAndSettle();
    expect(find.text('گونیا'), findsOneWidget);
    expect(find.text('ماشین‌حساب'), findsOneWidget);
    expect(find.text('متر دیجیتال'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('حسابداری'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('حسابداری'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
