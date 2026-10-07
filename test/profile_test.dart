import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/user_profile.dart';

void main() {
  Future<void> start(WidgetTester t, {bool demo = false}) async {
    t.view.physicalSize = const Size(360, 800); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(SakhtyarApp(startWithDemoAccount: demo)); await t.pumpAndSettle();
  }
  Future<void> tap(WidgetTester t, String label) async {
    final target = find.text(label).last; await t.ensureVisible(target); await t.tap(target); await t.pumpAndSettle();
  }
  Future<void> login(WidgetTester t, String mobile) async {
    await t.enterText(find.byKey(const ValueKey('login-phone')), mobile); await tap(t, 'دریافت کد');
    await t.enterText(find.byKey(const ValueKey('login-code')), '۱۲۳۴۵۶'); await tap(t, 'تأیید و ورود');
  }
  test('mobile input normalizes Persian digits and rejects malformed numbers', () {
    expect(validMobile('۰۹۱۲۱۲۳۴۵۶۷'), isTrue); expect(validMobile('۹۱۲۱۲۳۴۵۶۷'), isFalse);
    expect(validMobile('0912123456'), isFalse); expect(validMobile('0912abc4567'), isFalse);
    expect(UserProfile.sample().photos.length, 6); expect(UserProfile.sample().badge.verified, isFalse);
  });
  testWidgets('guest can browse, login is cancelable and invalid codes do not sign in', (t) async {
    await start(t); expect(find.text('۵۸ آگهی'), findsOneWidget);
    await tap(t, 'ثبت آگهی'); expect(find.byType(DemoLogin), findsOneWidget);
    await t.tap(find.byTooltip('بستن ورود')); await t.pumpAndSettle();
    await tap(t, 'صفحه من'); await tap(t, 'ورود با شماره موبایل');
    await t.enterText(find.byKey(const ValueKey('login-phone')), '123'); await tap(t, 'دریافت کد');
    expect(find.text('شماره موبایل ۱۱ رقمی با ۰۹ وارد کن'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('login-phone')), '۰۹۳۵۱۲۳۴۵۶۷'); await tap(t, 'دریافت کد');
    await t.enterText(find.byKey(const ValueKey('login-code')), '000000'); await tap(t, 'تأیید و ورود');
    expect(find.text('کد نمایشی ۱۲۳۴۵۶ است'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('login-code')), '123456'); await tap(t, 'تأیید و ورود');
    expect(find.text('تکمیل پروفایل'), findsOneWidget); expect(find.text('مهدی احمدی'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('activity asks for completion, cancel keeps a basic account, sample data stays private', (t) async {
    await start(t); await tap(t, 'ثبت آگهی'); await login(t, '09351234567');
    expect(find.byType(ProfileEditor), findsOneWidget);
    await t.tap(find.byTooltip('بستن ویرایش پروفایل')); await t.pumpAndSettle();
    await tap(t, 'صفحه من'); expect(find.text('تکمیل پروفایل'), findsOneWidget);
    await tap(t, 'آگهی‌های من'); expect(find.text('۳ کارگر برای بتن‌ریزی'), findsNothing);
    expect(find.text('آگهی نداری'), findsOneWidget);
    await tap(t, 'صفحه من'); await tap(t, 'تکمیل پروفایل');
    await tap(t, 'ذخیره و ادامه فعالیت'); expect(find.text('نام را وارد کن'), findsOneWidget);
    expect(find.text('شهر فعالیت را انتخاب کن'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('editing is atomic, gallery has six samples and logout preserves same-account edits', (t) async {
    await start(t, demo: true); await tap(t, 'صفحه من'); await tap(t, 'پروفایل عمومی من');
    expect(find.text('دیدن همه (۶)'), findsOneWidget); await tap(t, 'ویرایش پروفایل');
    await t.enterText(find.byKey(const ValueKey('profile-name')), 'نام ذخیره‌نشده');
    await t.tap(find.byTooltip('بستن ویرایش پروفایل')); await t.pumpAndSettle();
    expect(find.text('مهدی احمدی'), findsOneWidget); expect(find.text('نام ذخیره‌نشده'), findsNothing);
    await tap(t, 'ویرایش پروفایل'); await t.enterText(find.byKey(const ValueKey('profile-name')), 'مهدی نمونه');
    await tap(t, 'ذخیره پروفایل'); expect(find.text('مهدی نمونه'), findsOneWidget);
    await tap(t, 'دیدن همه (۶)');
    await t.tap(find.byTooltip('حذف عکس پروفایل ۱')); await t.pumpAndSettle();
    await t.tap(find.byTooltip('بستن گالری')); await t.pumpAndSettle();
    expect(find.text('دیدن همه (۵)'), findsOneWidget);
    await tap(t, 'صفحه من'); await tap(t, 'خروج از حساب'); expect(find.text('مهدی نمونه'), findsNothing);
    await tap(t, 'ورود با شماره موبایل'); await login(t, samplePhone);
    expect(find.text('مهدی نمونه'), findsOneWidget);
    await tap(t, 'پروفایل عمومی من'); expect(find.text('دیدن همه (۵)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('registration saves profile then continues the intended ad flow on a narrow phone', (t) async {
    await start(t); t.view.physicalSize = const Size(320, 800);
    await tap(t, 'ثبت آگهی'); await login(t, '09351234567');
    await t.enterText(find.byKey(const ValueKey('profile-name')), 'کاربر تازه');
    await t.tap(find.byKey(const ValueKey('profile-city-null'))); await t.pumpAndSettle(); await tap(t, 'کرج · البرز');
    await tap(t, 'دیوارچینی'); await tap(t, 'ذخیره و ادامه فعالیت');
    expect(find.text('چه چیزی ثبت می‌کنی؟'), findsOneWidget);
    await tap(t, 'صفحه من'); expect(find.text('کاربر تازه'), findsOneWidget); expect(find.text('تکمیل پروفایل'), findsNothing);
    await tap(t, 'پروفایل عمومی من'); expect(find.text('هویت بررسی‌نشده'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
