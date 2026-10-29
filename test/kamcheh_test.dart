import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/core.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/user_profile.dart';
import 'package:sakhtyar/marketplace.dart';

void main() {
  DemoProfileRepository repository() {
    final r = DemoProfileRepository();
    for (final id in ['a', 'b', 'c', 'd']) {
      r.save(UserProfile(id: id, name: id, complete: true));
    }
    return r;
  }

  test('invitation needs recipient consent, removal notifies and keeps history',
      () {
    final r = repository();
    expect(r.invite('a', 'b'), isNull);
    expect(r.members('a'), isEmpty);
    final id = r.links.single.id;
    expect(r.accept(id, 'c'), isNotNull);
    expect(r.accept(id, 'b'), isNull);
    expect(r.members('a').length, 1);
    r.remove(id, 'c');
    expect(r.members('a').length, 1);
    r.remove(id, 'a');
    expect(r.members('a'), isEmpty);
    expect(r.links.single.status, TeamLinkStatus.removed);
    expect(r.notices.last.profileId, 'b');
    expect(r.invite('a', 'b'), isNull);
  });
  test(
      'multiple crews and owning a crew are allowed, direct backlinks are blocked',
      () {
    final r = repository();
    r.invite('a', 'b');
    r.accept(r.links.last.id, 'b');
    expect(r.invite('b', 'a'), isNotNull);
    expect(r.invite('c', 'b'), isNull);
    r.accept(r.links.last.id, 'b');
    expect(r.invite('b', 'd'), isNull);
    r.accept(r.links.last.id, 'd');
    expect(
        r.links
            .where(
                (l) => l.memberId == 'b' && l.status == TeamLinkStatus.active)
            .length,
        2);
    expect(r.members('b').length, 1);
    expect(r.invite('a', 'a'), isNotNull);
    expect(r.invite('a', 'b'), isNotNull);
  });
  test('declining and versioned rules acceptance are not duplicate actions',
      () {
    final r = repository();
    r.invite('a', 'b');
    final id = r.links.single.id;
    r.decline(id, 'a');
    expect(r.invitations('b').length, 1);
    r.decline(id, 'b');
    expect(r.invitations('b'), isEmpty);
    r.acceptRules('a');
    r.acceptRules('a');
    expect(r.acceptances.length, 1);
    expect(r.acceptances.single.version, rulesVersion);
    expect(r.accept(id, 'b'), isNotNull);
  });
  test('only execution and design categories are exposed', () {
    expect(marketCategories.map((c) => c.id), ['نیرو', 'خدمات', 'مهندسی']);
    expect(marketCategory('مهندسی').skills, isNot(contains('نظارت ساختمان')));
    expect(marketCategory('مهندسی').skills, contains('طراحی معماری'));
    expect(UserProfile.sample().copy().id, UserProfile.sample().id);
  });

  Future<void> start(WidgetTester t, {bool demo = false}) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(SakhtyarApp(startWithDemoAccount: demo));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets(
      'home discovers independent profiles and availability filters on narrow screen',
      (t) async {
    await start(t);
    t.view.physicalSize = const Size(320, 800);
    expect(find.text('سرمایه‌گذاری'), findsNothing);
    expect(find.text('مجوز و انشعاب'), findsNothing);
    await tap(t, 'پروفایل‌ها');
    await t.enterText(
        find.byKey(const ValueKey('profile-search')), 'طراح معماری الهیه');
    await t.pumpAndSettle();
    await tap(t, 'طراح معماری الهیه');
    expect(find.text('نمونه‌کارها'), findsOneWidget);
    expect(find.text('تنظیم قرارداد'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'new account must accept demo rules and rules stay available when logged out',
      (t) async {
    await start(t);
    await tap(t, 'ابزارها');
    await t.scrollUntilVisible(find.text('قوانین کمچه'), 180,
        scrollable: find.byType(Scrollable).first);
    await tap(t, 'قوانین کمچه');
    expect(find.text(rulesText), findsOneWidget);
    await t.tap(find.byTooltip('بازگشت'));
    await t.pumpAndSettle();
    await tap(t, 'ورود / ثبت‌نام');
    await t.enterText(find.byKey(const ValueKey('login-phone')), '09351234567');
    await tap(t, 'دریافت کد');
    await t.enterText(find.byKey(const ValueKey('login-code')), '123456');
    await tap(t, 'تأیید و ورود');
    expect(find.text('برای ساخت حساب، قوانین نسخه آزمایشی را بپذیر.'),
        findsOneWidget);
    await t.tap(find.byKey(const ValueKey('accept-rules')));
    await t.pumpAndSettle();
    await tap(t, 'تأیید و ورود');
    expect(find.byType(DemoLogin), findsNothing);
    await t.scrollUntilVisible(find.text('قوانین کمچه'), 180,
        scrollable: find.byType(Scrollable).first);
    await tap(t, 'قوانین کمچه');
    expect(find.text(rulesText), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('crew manager can open members and remove without consent',
      (t) async {
    await start(t, demo: true);
    await tap(t, 'ابزارها');
    expect(find.text('حساب پروژه'), findsNothing);
    expect(find.text('پروژه‌های من'), findsNothing);
    await tap(t, 'پروفایل‌ها');
    await tap(t, 'پروفایل من');
    await tap(t, 'مدیریت اعضا و دعوت‌ها');
    expect(find.text('عضو تأییدشده'), findsOneWidget);
    expect(find.text('منتظر تأیید عضو'), findsOneWidget);
    final remove = find.text('حذف لینک').first;
    await t.ensureVisible(remove);
    await t.tap(remove);
    await t.pumpAndSettle();
    expect(find.text('عضو تأییدشده'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
