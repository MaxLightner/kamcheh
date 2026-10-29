import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/contract_document.dart';
import 'package:sakhtyar/estimate.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/network_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ContractDraft draft() => ContractDraft('اجرای داربست', {
        'طرفین': 'مهدی احمدی · داربست رضایی',
        'موضوع و محل': 'نصب داربست در کرج، گوهردشت',
        'مبلغ و مدت': '۱۲٬۰۰۰٬۰۰۰ تومان · ۳۰ روز',
        'شرایط توافق': 'حمل، نصب و جمع‌آوری در مبلغ لحاظ شده است.',
      });
  test('saved contract revisions preserve text and attachment bytes', () {
    final d = draft()..photos.add(Uint8List.fromList([1, 2, 3]));
    final first = d.saveRevision();
    d.values['شرایط توافق'] = 'تغییر جدید';
    d.photos.first[0] = 8;
    final second = d.saveRevision();
    expect(first.values['شرایط توافق'], contains('جمع‌آوری'));
    expect(first.photos.first.first, 1);
    expect(second.photos.first.first, 8);
    expect(() => first.values['طرفین'] = 'دیگری', throwsUnsupportedError);
    expect(() => first.photos.first[0] = 9, throwsUnsupportedError);
    expect(second.number, 2);
    final addendum =
        ContractDraft('الحاقیه مبلغ', Map.of(second.values), parentId: d.id);
    expect(addendum.saveRevision().parentId, d.id);
    expect(d.revisions.length, 2);
  });
  test('incomplete contract cannot produce a saved revision', () {
    final d = draft();
    d.values['طرفین'] = '';
    expect(d.saveRevision, throwsFormatException);
    expect(d.revisions, isEmpty);
  });
  test('Persian contract generates an actual PDF file', () async {
    final d = draft();
    final image = await rootBundle.load('assets/images/scaffold.jpg');
    d.photos.add(image.buffer.asUint8List());
    final bytes = await buildContractPdf(d.saveRevision());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(5000));
    // QA artifact is outside the app source and never uploaded with the repo.
    final path = Platform.environment['KAMCHEH_PDF_QA'];
    if (path != null) await File(path).writeAsBytes(bytes);
  });
  test('profile link carries only stable id and opens at configured web base',
      () {
    final link = publicProfileUrl('demo-person-1',
        current: Uri.parse('http://127.0.0.1:8080/?v=old'))!;
    expect(link.queryParameters, {'profile': 'demo-person-1'});
    expect(link.host, '127.0.0.1');
    expect(link.port, 8080);
    expect(publicProfileUrl('a', current: Uri.parse('file:///demo')), isNull);
    expect(
        publicProfileUrl('a', configuredBase: 'https://example.com/demo/')
            .toString(),
        contains('/demo/?profile=a'));
  });
  test('estimates convert centimetres and round purchases upward', () {
    final r = MaterialEstimate.calculate(
        area: 20,
        thicknessCm: 10,
        dosageKgPerM3: 250,
        bagWeightKg: 50,
        wastePercent: 5);
    expect(r.volume, closeTo(2.1, .001));
    expect(r.cementKg, closeTo(525, .001));
    expect(r.bags, 11);
    expect(
        MaterialEstimate.tiles(
            area: 10, widthCm: 60, heightCm: 60, wastePercent: 10),
        31);
    expect(positiveNumber('۱۲٫۵'), 12.5);
    expect(() => positiveNumber('NaN'), throwsFormatException);
    expect(
        () => MaterialEstimate.calculate(
            area: 20, thicknessCm: 10, dosageKgPerM3: 250, bagWeightKg: 0),
        throwsFormatException);
  });
  testWidgets('estimator reports invalid input instead of stale totals',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home:
            Scaffold(body: SingleChildScrollView(child: MaterialEstimator()))));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20');
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), '250');
    await tester.tap(find.text('محاسبه'));
    await tester.pump();
    expect(find.textContaining('تعداد کیسه: 10'), findsOneWidget);
    await tester.enterText(fields.at(3), '0');
    await tester.tap(find.text('محاسبه'));
    await tester.pump();
    expect(find.textContaining('تعداد کیسه:'), findsNothing);
    expect(find.text('عدد مثبت و معتبر وارد کن.'), findsOneWidget);
  });
  testWidgets('tools stay in the dedicated tools tab', (tester) async {
    await tester.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابزارها').last);
    await tester.pumpAndSettle();
    expect(find.text('حسابداری'), findsOneWidget);
    expect(find.text('گزارش‌ها'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.text('حسابداری')),
        alignment: 0.25);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابداری'));
    await tester.pumpAndSettle();
    expect(find.text('هزینه‌ها'), findsOneWidget);
    expect(find.text('دفتر کل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'public feedback reflects a linked visit and reports stay private',
      (tester) async {
    await tester.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(AppShell));
    state.workspace.workReviews.add(WorkReview(
        'داربست رضایی',
        'visit-proof',
        'بازدید داربست',
        'طبق قرار نیامد',
        'در ساعت توافق‌شده مراجعه نکرد.',
        1,
        null,
        subjectProfileId: 'demo-person-1',
        authorProfileId: 'profile-sample'));
    await tester.tap(find.text('پروفایل‌ها'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
        tester.element(find.text('داربست رضایی').first),
        alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('داربست رضایی').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('گزارش پروفایل'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('در ساعت توافق‌شده مراجعه نکرد.'), findsOneWidget);
    expect(find.text('ثبت پاسخ'), findsNothing);
    await tester.tap(find.text('گزارش پروفایل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ثبت گزارش'));
    await tester.pumpAndSettle();
    expect(state.reports.length, 1);
    expect(state.reports.first.authorId, 'profile-sample');
    expect(state.reports.first.targetId, 'profile:demo-person-1');
    expect(tester.takeException(), isNull);
  });
}
