import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/demo_data.dart';
import 'package:sakhtyar/area_picker.dart';

void main() {
  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  test('amounts accept Persian digits and separators', () {
    expect(parseAmount('۱٬۲۰۰٬۰۰۰'), 1200000);
    expect(parseAmount('1,200,000'), 1200000);
    expect(parseAmount(''), isNull);
  });
  testWidgets('home renders and search filters listings', (tester) async {
    await start(tester);
    expect(find.text('آگهی‌های ساختمان'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light);
    expect(find.text('اجرای داربست ساختمانی'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'کاشی');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad-row-a04')), findsOneWidget);
    expect(find.text('اجرای داربست ساختمانی'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('financial entry updates project ledger', (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'حساب پروژه');
    await tap(tester, 'ثبت مورد مالی');
    await tester.enterText(find.byType(TextFormField).at(0), 'حمل مصالح');
    await tester.enterText(find.byType(TextFormField).at(1), '۲۵۰۰۰۰');
    await tap(tester, 'ذخیره در حساب پروژه');
    expect(find.text('حمل مصالح'), findsOneWidget);
    expect(find.text('۲۵۰٬۰۰۰ تومان'), findsOneWidget);
  });
  testWidgets('contract can be edited and saved without an ad', (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'قراردادهای من');
    await tap(tester, 'مشاهده قرارداد');
    await tester.tap(find.text('ویرایش').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'کارفرما و پیمانکار نمونه');
    await tap(tester, 'ذخیره');
    expect(find.text('کارفرما و پیمانکار نمونه'), findsOneWidget);
    await tap(tester, 'ذخیره پیش‌نویس');
    expect(find.text('پیش‌نویس ذخیره‌شده'), findsOneWidget);
  });
  testWidgets('profiles, supplier and project render on a phone', (
    tester,
  ) async {
    await start(tester);
    await tap(tester, 'افراد و تأمین‌کنندگان');
    await tap(tester, 'داربست رضایی');
    expect(find.text('بازخورد همکاری‌ها'), findsOneWidget);
    await tap(tester, 'آگهی‌ها');
    await tester.ensureVisible(find.byKey(const ValueKey('ad-row-a04')));
    await tester.tap(find.byKey(const ValueKey('ad-row-a04')));
    await tester.pumpAndSettle();
    await tap(tester, 'نمونه متریال و مشخصات');
    await tap(tester, 'طرح سنگ طوسی');
    expect(find.text('سرامیک طرح سنگ طوسی'), findsOneWidget);
    await tap(tester, 'مناقصه‌ها');
    await tap(tester, '۳ کارگر برای بتن‌ریزی');
    await tester.ensureVisible(find.text('پروفایل').first);
    await tester.tap(find.text('پروفایل').first);
    await tester.pumpAndSettle();
    expect(find.text('سابقه کار'), findsNWidgets(2));
    await tap(tester, 'صفحه من');
    await tap(tester, 'پروژه‌های من');
    expect(find.text('نیازهای این مرحله'), findsOneWidget);
  });

  test(
      'area filters support unrestricted, province, city, districts and suburbs',
      () {
    const all = AreaFilter();
    expect(demoAds.every(all.matches), isTrue);
    const mashhad = AreaFilter(province: 'خراسان رضوی', city: 'مشهد');
    expect(mashhad.matches(demoAds[2]), isTrue);
    expect(mashhad.matches(demoAds[6]), isFalse);
    const suburbs =
        AreaFilter(province: 'خراسان رضوی', city: 'مشهد', surroundings: true);
    expect(suburbs.matches(demoAds[6]), isTrue);
    expect(suburbs.matches(demoAds[7]), isTrue);
    expect(suburbs.matches(demoAds[0]), isFalse);
    const district = AreaFilter(city: 'مشهد', districts: {'سجاد'});
    expect(district.matches(demoAds[2]), isTrue);
    expect(district.matches(demoAds[4]), isFalse);
    const torghabeh = AreaFilter(city: 'طرقبه');
    expect(torghabeh.matches(demoAds[6]), isTrue);
    expect(torghabeh.matches(demoAds[2]), isFalse);
    const province = AreaFilter(province: 'البرز');
    expect(province.matches(demoAds[18]), isTrue);
    expect(province.matches(demoAds[2]), isFalse);
  });

  testWidgets(
      'messages always open the inbox and each thread keeps its messages',
      (tester) async {
    await start(tester);
    await tap(tester, 'پیام‌ها');
    expect(find.text('جست‌وجو در گفت‌وگوها'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const ValueKey('feed-filter')), findsNothing);
    expect(find.text('همه مناطق'), findsNothing);
    await tap(tester, 'علی رضایی');
    await tester.enterText(find.byType(TextField), 'پیام مخصوص علی');
    await tester.tap(find.byTooltip('ارسال پیام'));
    await tester.pumpAndSettle();
    expect(find.text('پیام مخصوص علی'), findsOneWidget);
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    expect(find.text('نمایشگاه کاشی آریا'), findsOneWidget);
    await tap(tester, 'داربست رضایی');
    expect(find.text('پیام مخصوص علی'), findsNothing);
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    await tap(tester, 'آگهی‌ها');
    await tap(tester, 'پیام‌ها');
    expect(find.text('جست‌وجو در گفت‌وگوها'), findsOneWidget);
    expect(find.text('تجهیزات دقیق شرق'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one ad flow publishes needs and offers with correct details',
      (tester) async {
    await start(tester);
    await tap(tester, 'ثبت آگهی');
    await tap(tester, 'کارگر و اکیپ');
    await tester.enterText(
        find.byType(TextFormField).first, 'نیاز به کارگر آزمایشی');
    await tester.enterText(find.byType(TextFormField).at(2), '۰');
    await tap(tester, 'انتشار آگهی');
    expect(find.text('یک عدد بیشتر از صفر وارد کن'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), '۳');
    await tap(tester, 'انتشار آگهی');
    expect(find.text('نیاز به کارگر آزمایشی'), findsOneWidget);
    await tap(tester, 'نیاز به کارگر آزمایشی');
    expect(find.text('نیاز دارد'), findsOneWidget);
    expect(find.text('ویرایش آگهی'), findsOneWidget);
    await tap(tester, 'آگهی‌ها');
    await tap(tester, 'ثبت آگهی');
    await tap(tester, 'ارائه می‌کنم');
    await tap(tester, 'مصالح و متریال');
    expect(find.text('تعداد نیرو'), findsNothing);
    await tester.enterText(
        find.byType(TextFormField).first, 'عرضه مصالح آزمایشی');
    await tap(tester, 'کاشی و سرامیک');
    await tap(tester, 'انتشار آگهی');
    await tap(tester, 'عرضه مصالح آزمایشی');
    expect(find.text('ارائه می‌کند'), findsOneWidget);
    expect(find.text('ارسال پیشنهاد'), findsNothing);
  });

  testWidgets('own profile does not open a supplier or contractor profile',
      (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'پروفایل عمومی من');
    expect(find.text('مهدی احمدی'), findsOneWidget);
    expect(find.text('داربست رضایی'), findsNothing);
  });

  testWidgets('new contract keeps the existing draft intact', (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'قراردادهای من');
    await tap(tester, 'تنظیم قرارداد جدید');
    await tester.enterText(find.byType(TextField), 'قرارداد خرید مصالح');
    await tap(tester, 'ذخیره');
    await tap(tester, 'ذخیره پیش‌نویس');
    expect(find.text('اجرای داربست'), findsOneWidget);
    expect(find.text('قرارداد خرید مصالح'), findsOneWidget);
    expect(find.text('مهدی احمدی · داربست رضایی'), findsOneWidget);
  });

  testWidgets(
      'ad and supplier bookmarks live under messages and tab resets to chats',
      (tester) async {
    await start(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('ad-row-a04')));
    await tester.tap(find.byKey(const ValueKey('ad-row-a04')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('نشان کردن آگهی'));
    await tester.tap(find.byTooltip('نشان کردن آگهی'));
    await tester.pumpAndSettle();
    await tap(tester, 'نمونه متریال و مشخصات');
    await tester.ensureVisible(find.byTooltip('نشان کردن فرد'));
    await tester.tap(find.byTooltip('نشان کردن فرد'));
    await tester.pumpAndSettle();
    await tap(tester, 'پیام‌ها');
    await tap(tester, 'نشان‌ها');
    expect(find.byKey(const ValueKey('ad-row-a04')), findsOneWidget);
    await tap(tester, 'تأمین‌کنندگان');
    expect(find.text('نمایشگاه کاشی آریا'), findsOneWidget);
    await tap(tester, 'صفحه من');
    await tap(tester, 'پیام‌ها');
    expect(find.text('جست‌وجو در گفت‌وگوها'), findsOneWidget);
  });

  testWidgets('forwarded ad opens details in the chosen chat only',
      (tester) async {
    await start(tester);
    await tap(tester, 'اجرای داربست ساختمانی');
    await tester.ensureVisible(find.byTooltip('ارسال آگهی برای دوست'));
    await tester.tap(find.byTooltip('ارسال آگهی برای دوست'));
    await tester.pumpAndSettle();
    await tap(tester, 'ارسال در گفت‌وگو');
    await tap(tester, 'علی رضایی');
    expect(find.text('آگهی ارسال‌شده'), findsOneWidget);
    await tap(tester, 'مشاهده جزئیات');
    expect(find.text('اجرای داربست ساختمانی'), findsOneWidget);
    await tap(tester, 'پیام‌ها');
    await tap(tester, 'نمایشگاه کاشی آریا');
    expect(find.text('آگهی ارسال‌شده'), findsNothing);
  });

  testWidgets('skills can be edited and filters match the same catalog',
      (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'پروفایل عمومی من');
    await tap(tester, 'افزودن / ویرایش');
    await tap(tester, 'دیوارچینی');
    await tap(tester, 'ذخیره کارت‌ها');
    expect(find.text('دیوارچینی'), findsOneWidget);
    await tap(tester, 'آگهی‌ها');
    await tap(tester, 'فیلتر');
    await tester.tap(find.byKey(const ValueKey('filter-category-نیرو')));
    await tester.pumpAndSettle();
    await tap(tester, 'دیوارچینی');
    await tap(tester, 'نمایش نتیجه');
    expect(find.text('کاشی و سرامیک'), findsNothing);
    expect(find.text('دیوارچینی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visit result is tied to a chat and visible in the peer profile',
      (tester) async {
    await start(tester);
    await tap(tester, 'مناقصه‌ها');
    await tap(tester, '۳ کارگر برای بتن‌ریزی');
    expect(find.text('۱٬۲۰۰٬۰۰۰ تومان / نفر / روز'), findsOneWidget);
    await tester.ensureVisible(find.text('پیام').first);
    await tester.tap(find.text('پیام').first);
    await tester.pumpAndSettle();
    await tap(tester, 'قرار بازدید');
    await tester.enterText(find.byType(TextFormField).at(0), 'شنبه ساعت ۷');
    await tester.enterText(find.byType(TextFormField).at(1), 'گوهردشت');
    await tap(tester, 'ثبت قرار');
    await tap(tester, 'ثبت نتیجه');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tap(tester, 'طبق قرار نیامد');
    await tester.enterText(
        find.byType(TextFormField), 'هماهنگ کردیم اما مراجعه نکرد');
    await tap(tester, 'ذخیره نتیجه');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('بازگشت'));
    await tester.pumpAndSettle();
    await tap(tester, 'مناقصه‌ها');
    await tap(tester, '۳ کارگر برای بتن‌ریزی');
    await tester.ensureVisible(find.text('پروفایل').first);
    await tester.tap(find.text('پروفایل').first);
    await tester.pumpAndSettle();
    expect(find.text('طبق قرار نیامد'), findsOneWidget);
    expect(find.text('خوش‌قولی ۱ از ۵'), findsOneWidget);
    expect(find.text('هماهنگ کردیم اما مراجعه نکرد'), findsOneWidget);
  });

  testWidgets(
      'closing an own ad hides it in the feed and reopening restores it',
      (tester) async {
    await start(tester);
    await tap(tester, 'صفحه من');
    await tap(tester, 'آگهی‌های من');
    await tester.tap(find.text('بستن آگهی').first);
    await tester.pumpAndSettle();
    await tap(tester, 'آگهی‌ها');
    await tester.enterText(find.byType(TextField), '۳ کارگر برای بتن‌ریزی');
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate(
            (w) => w is Text && w.data == '۳ کارگر برای بتن‌ریزی'),
        findsNothing);
    await tap(tester, 'صفحه من');
    await tap(tester, 'آگهی‌های من');
    await tap(tester, 'فعال‌کردن');
    await tap(tester, 'آگهی‌ها');
    expect(
        find.byWidgetPredicate(
            (w) => w is Text && w.data == '۳ کارگر برای بتن‌ریزی'),
        findsOneWidget);
  });

  testWidgets(
      'contract created in chat keeps peer details and appears in its chat',
      (tester) async {
    await start(tester);
    await tap(tester, 'پیام‌ها');
    await tap(tester, 'علی رضایی');
    await tap(tester, 'تنظیم قرارداد');
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'اجرای بتن‌ریزی آزمایشی');
    await tap(tester, 'ذخیره');
    expect(find.text('مهدی احمدی · علی رضایی'), findsOneWidget);
    await tap(tester, 'ذخیره پیش‌نویس');
    await tap(tester, 'پیام‌ها');
    await tap(tester, 'علی رضایی');
    expect(find.text('اجرای بتن‌ریزی آزمایشی'), findsOneWidget);
    await tap(tester, 'مشاهده قرارداد');
    expect(find.text('مهدی احمدی · علی رضایی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('area picker allows no district, multiple districts and reset',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
                body: AreaPicker(
                    initial: AreaFilter(province: 'خراسان رضوی', city: 'مشهد'),
                    showMap: false)))));
    await tester.pumpAndSettle();
    expect(find.text('بدون انتخاب محله، تمام مشهد نمایش داده می‌شود.'),
        findsOneWidget);
    await tap(tester, 'سجاد');
    await tap(tester, 'الهیه');
    expect(find.text('2 محله انتخاب شده'), findsOneWidget);
    await tap(tester, 'پاک کردن');
    expect(find.text('همه استان‌ها'), findsOneWidget);
    expect(find.text('همه شهرها'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
