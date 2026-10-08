import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/marketplace.dart';
import 'package:sakhtyar/work_repository.dart';

void main() {
  DemoWorkRepository repository() => DemoWorkRepository()
    ..saveNeed(
        WorkNeed(
            id: 'r',
            ownerId: 'owner',
            title: 'داربست',
            details: 'نصب داربست نمای ساختمان',
            city: 'کرج',
            privateAddress: 'نشانی خصوصی',
            latitude: 35.8,
            longitude: 50.9),
        'owner');
  test('private address and map never enter the public request', () {
    final r = repository();
    final j = r.need('r').publicJson();
    expect(j.containsKey('privateAddress'), false);
    expect(j.containsKey('latitude'), false);
    expect(r.privateAddress('r', 'guest'), isNull);
    r.propose('r', 'bidder', 100, PriceUnit.project, 'فردا', '');
    r.select('r', r.bids.values.single.id, 'owner');
    expect(r.privateAddress('r', 'bidder'), isNull);
    expect(r.privateAddress('r', 'owner'), 'نشانی خصوصی');
  });
  test('proposal submission cannot open chat and updates charge once', () {
    final r = repository();
    expect(() => r.propose('r', 'owner', 100, PriceUnit.project, 'فردا', ''),
        throwsStateError);
    final b = r.propose('r', 'a', 100, PriceUnit.project, 'فردا', '');
    r.propose('r', 'a', 120, PriceUnit.project, 'شنبه', 'حمل شامل است');
    expect(r.bids.length, 1);
    expect(r.mine('r', 'a')!.id, b.id);
    expect(r.balance('a'), 9);
    expect(() => r.chat('r::a', 'a'), throwsStateError);
    expect(r.visibleBids('r', 'guest'), isEmpty);
    expect(r.visibleBids('r', 'a').length, 1);
    expect(() => r.select('r', b.id, 'a'), throwsStateError);
    final c = r.select('r', b.id, 'owner');
    r.select('r', b.id, 'owner');
    expect(r.conversations.length, 1);
    expect(c.contains('a'), true);
    expect(() => r.chat(c.id, 'stranger'), throwsStateError);
    expect(() => r.propose('r', 'a', 200, PriceUnit.project, 'شنبه', ''),
        throwsStateError);
  });
  test('visit works before any bid and only recipient accepts', () {
    final r = repository();
    final v = r.proposeVisit(
        'r', 'a', 'a', DateTime.now().add(const Duration(days: 1)));
    expect(r.bids, isEmpty);
    expect(r.privateAddress('r', 'a'), isNull);
    expect(() => r.respondVisit(v.id, 'a', 'accepted'), throwsStateError);
    expect(
        () => r.respondVisit(v.id, 'stranger', 'accepted'), throwsStateError);
    r.respondVisit(v.id, 'owner', 'accepted');
    expect(r.privateAddress('r', 'a'), 'نشانی خصوصی');
    expect(r.chat('r::a', 'owner').contains('a'), true);
    expect(() => r.respondVisit(v.id, 'owner', 'accepted'), throwsStateError);
  });
  test('closing preserves history but prevents new visits and bids', () {
    final r = repository();
    final b = r.propose('r', 'a', 100, PriceUnit.personDay, 'شنبه', '');
    final c = r.select('r', b.id, 'owner');
    expect(() => r.changeStatus('r', 'a', closed: true), throwsStateError);
    r.changeStatus('r', 'owner', archive: true);
    expect(() => r.propose('r', 'b', 100, PriceUnit.project, 'شنبه', ''),
        throwsStateError);
    expect(
        () => r.proposeVisit(
            'r', 'b', 'b', DateTime.now().add(const Duration(days: 1))),
        throwsStateError);
    r.send(c.id, 'a', 'پیام بعد از بایگانی');
    expect(c.messages.length, 1);
  });
  test(
      'messages, attachments, unread, visits and credit survive snapshot roundtrip',
      () {
    final r = repository(), bytes = Uint8List.fromList([1, 2, 3]);
    final v = r.proposeVisit(
        'r', 'a', 'a', DateTime.now().add(const Duration(days: 1)));
    r.respondVisit(v.id, 'owner', 'accepted');
    r.propose('r', 'a', 100, PriceUnit.project, 'شنبه', '');
    r.send('r::a', 'a', 'پیوست',
        fileName: 'drawing.pdf', mime: 'application/pdf', bytes: bytes);
    bytes[0] = 9;
    final restored = DemoWorkRepository()
      ..restore(Map<String, dynamic>.from(jsonDecode(jsonEncode(r.toJson()))));
    final c = restored.chat('r::a', 'owner');
    expect(c.messages.single.bytes, [1, 2, 3]);
    expect(c.unread('owner'), 1);
    restored.read(c.id, 'owner');
    expect(c.unread('owner'), 0);
    expect(restored.balance('a'), 9);
    expect(restored.privateAddress('r', 'a'), 'نشانی خصوصی');
    expect(() => restored.send(c.id, 'stranger', 'مزاحمت'), throwsStateError);
    expect(
        () => restored.send(c.id, 'a', '',
            bytes: Uint8List(10 * 1024 * 1024 + 1)),
        throwsStateError);
  });
  testWidgets('compact unified form and inbox show the new workflow',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await t.pumpAndSettle();
    await t.tap(find.text('ثبت نیاز'));
    await t.pumpAndSettle();
    await t.tap(find.text('ثبت درخواست جدید'));
    await t.pumpAndSettle();
    expect(find.text('عنوان درخواست'), findsOneWidget);
    expect(find.text('اکیپ می‌خواهم'), findsOneWidget);
    expect(find.text('مقدار یا تعداد (اختیاری)'), findsOneWidget);
    expect(find.text('تعداد کارگر'), findsNothing);
    await t.tap(find.text('پیام‌ها'));
    await t.pumpAndSettle();
    expect(find.text('داربست رضایی'), findsOneWidget);
    await t.tap(find.text('داربست رضایی'));
    await t.pumpAndSettle();
    expect(find.byTooltip('ارسال عکس یا فایل'), findsOneWidget);
    expect(find.text('سلام، برای بازدید داربست در ساعت توافق‌شده می‌آیم.'),
        findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'پیام آزمایشی');
    await t.tap(find.byTooltip('ارسال پیام'));
    await t.pumpAndSettle();
    expect(find.text('پیام آزمایشی'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
