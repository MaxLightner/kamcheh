import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/marketplace.dart';
import 'package:sakhtyar/work_repository.dart';
import 'package:sakhtyar/request_filter.dart';
import 'package:sakhtyar/demo_data.dart';

void main() {
  final initial = DateTime(2030, 1, 1, 9);
  WorkNeed need({DateTime? deadline}) => WorkNeed(
      id: 'r',
      ownerId: 'owner',
      title: 'نیاز به کارگر',
      details: 'برای بتن‌ریزی',
      city: 'مشهد',
      deadline: deadline,
      privateAddress: 'نشانی خصوصی',
      createdAt: initial);

  test(
      'deadline boundary closes new bids/chat/visits and filter but preserves prior decisions and messages',
      () {
    var now = initial;
    final r = DemoWorkRepository(clock: () => now)
      ..saveNeed(need(deadline: initial.add(const Duration(days: 3))), 'owner');
    final b = r.propose('r', 'a', 100, PriceUnit.personDay, 'شنبه', '');
    final c = r.requestChat('r', 'b', 'درباره شرایط کار');
    now = initial.add(const Duration(days: 3));
    expect(() => r.propose('r', 'new', 100, PriceUnit.personDay, 'شنبه', ''),
        throwsStateError);
    expect(() => r.propose('r', 'a', 200, PriceUnit.personDay, 'شنبه', ''),
        throwsStateError);
    expect(() => r.requestChat('r', 'new', 'سلام'), throwsStateError);
    expect(
        () =>
            r.proposeVisit('r', 'new', 'new', now.add(const Duration(days: 1))),
        throwsStateError);
    expect(
        const RequestFilter()
            .apply(r.needs.values, area: const AreaFilter(), now: now),
        isEmpty);
    final chat = r.select('r', b.id, 'owner');
    r.respondChatRequest(c.id, 'owner', 'accepted');
    r.send(chat.id, 'a', 'هماهنگی بعد از پایان مهلت');
    final visit =
        r.proposeVisit('r', 'a', 'owner', now.add(const Duration(days: 1)));
    r.respondVisit(visit.id, 'a', 'accepted');
    expect(r.chat(chat.id, 'owner').messages.last.text,
        'هماهنگی بعد از پایان مهلت');
    expect(r.privateAddress('r', 'b'), isNull);
  });

  test(
      'no deadline is open; editing extends expired deadline and legacy data defaults safely',
      () {
    var now = initial;
    final r = DemoWorkRepository(clock: () => now)
      ..saveNeed(need(deadline: initial.add(const Duration(days: 1))), 'owner');
    now = initial.add(const Duration(days: 2));
    expect(
        () => r.saveNeed(need(deadline: initial), 'owner'), throwsStateError);
    r.saveNeed(need(deadline: now.add(const Duration(days: 1))), 'owner');
    r.propose('r', 'a', 100, PriceUnit.project, 'شنبه', '');
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.need('r').deadline, now.add(const Duration(days: 1)));
    expect(restored.need('r').createdAt, initial);
    final old = need().toJson()
      ..remove('deadline')
      ..remove('createdAt')
      ..remove('selectedBidIds');
    expect(WorkNeed.fromJson(old).deadline, isNull);
  });

  test(
      'chat request is not a proposal; duplicates and self approval blocked; persisted acceptance keeps address private',
      () {
    final r = DemoWorkRepository()..saveNeed(need(), 'owner');
    final c = r.requestChat('r', 'a', 'سؤال درباره محل عمومی');
    expect(r.bids, isEmpty);
    expect(r.balance('a'), 10);
    expect(() => r.chat('r::a', 'a'), throwsStateError);
    expect(() => r.requestChat('r', 'a', 'دوباره'), throwsStateError);
    expect(() => r.respondChatRequest(c.id, 'a', 'accepted'), throwsStateError);
    expect(() => r.respondChatRequest(c.id, 'stranger', 'accepted'),
        throwsStateError);
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    restored.respondChatRequest(c.id, 'owner', 'accepted');
    expect(restored.chat('r::a', 'owner').messages.single.text,
        contains(c.details));
    expect(restored.privateAddress('r', 'a'), isNull);
    expect(() => restored.respondChatRequest(c.id, 'owner', 'accepted'),
        throwsStateError);
    restored.changeStatus('r', 'owner', closed: true);
    restored.send('r::a', 'a', 'پیام محفوظ');
    expect(restored.chat('r::a', 'owner').messages.length, 2);
  });

  test(
      'decline/cancel never opens chat; pending acceptance blocked for closed request',
      () {
    final r = DemoWorkRepository()..saveNeed(need(), 'owner');
    final c = r.requestChat('r', 'a', 'سلام');
    expect(() => r.respondChatRequest(c.id, 'owner', 'cancelled'),
        throwsStateError);
    r.respondChatRequest(c.id, 'a', 'cancelled');
    final next = r.requestChat('r', 'a', 'دوباره');
    r.changeStatus('r', 'owner', closed: true);
    expect(() => r.respondChatRequest(next.id, 'owner', 'accepted'),
        throwsStateError);
    r.respondChatRequest(next.id, 'owner', 'declined');
    expect(r.conversations, isEmpty);
  });

  test(
      'multiple selections only grant coordination; every selected bid stays immutable',
      () {
    final r = DemoWorkRepository()..saveNeed(need(), 'owner');
    final a = r.propose('r', 'a', 100, PriceUnit.project, 'شنبه', '');
    final b = r.propose('r', 'b', 200, PriceUnit.project, 'شنبه', '');
    r.select('r', a.id, 'owner');
    r.select('r', b.id, 'owner');
    r.select('r', a.id, 'owner');
    expect(r.conversations.length, 2);
    expect(() => r.propose('r', 'a', 300, PriceUnit.project, 'شنبه', ''),
        throwsStateError);
    expect(() => r.propose('r', 'b', 300, PriceUnit.project, 'شنبه', ''),
        throwsStateError);
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.need('r').selectedBidIds, {a.id, b.id});
  });

  test('stale visit cannot be accepted and retains pending status', () {
    var now = initial;
    final r = DemoWorkRepository(clock: () => now)..saveNeed(need(), 'owner');
    final v = r.proposeVisit('r', 'a', 'a', now.add(const Duration(hours: 1)));
    now = now.add(const Duration(hours: 2));
    expect(() => r.respondVisit(v.id, 'owner', 'accepted'), throwsStateError);
    expect(v.status, 'pending');
    r.respondVisit(v.id, 'owner', 'declined');
  });

  testWidgets(
      'deadline chooser is separate from work time and comparisons have side-by-side actions',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await t.pumpAndSettle();
    await t.tap(find.text('درخواست‌ها').last);
    await t.pumpAndSettle();
    await t.tap(find.text('ثبت درخواست جدید'));
    await t.pumpAndSettle();
    expect(find.text('مهلت دریافت پیشنهاد'), findsOneWidget);
    await t.ensureVisible(find.text('۳ روز'));
    await t.tap(find.text('۳ روز'));
    await t.pumpAndSettle();
    expect(find.textContaining('پایان:'), findsOneWidget);
    await t.tap(find.text('درخواست‌ها').last);
    await t.pumpAndSettle();
    await t.tap(find.text('درخواست‌ها و پیشنهادهای من'));
    await t.pumpAndSettle();
    await t.tap(find.text('پیشنهادها و بازدیدها').first);
    await t.pumpAndSettle();
    final left = find.text('پروفایل و سابقه').first;
    final right = find.text('انتخاب برای هماهنگی').first;
    await t.ensureVisible(left);
    await t.pumpAndSettle();
    expect(
        (t.getTopLeft(left).dy - t.getTopLeft(right).dy).abs(), lessThan(16));
    expect(t.takeException(), isNull);
  });
}
