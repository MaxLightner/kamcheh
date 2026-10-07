import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/demo_data.dart';
import 'package:sakhtyar/area_picker.dart';
import 'package:sakhtyar/location_map.dart';

void main() {
  Future<void> start(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> newLabor(WidgetTester t, String title) async {
    await tap(t, 'ثبت آگهی');
    await tap(t, 'کارگر و اکیپ');
    await t.enterText(find.byType(TextFormField).first, title);
  }

  test(
      'coverage matches service cities and districts but requests stay at their site',
      () {
    const offer = Ad('c1', 'خدمت', 'خدمات', false, 'کرج', 'گوهردشت', 'scaffold',
        'توافق', 'فرد',
        serviceArea:
            AreaFilter(city: 'مشهد', districts: {'سجاد'}, surroundings: true));
    expect(const AreaFilter(city: 'مشهد', districts: {'سجاد'}).matches(offer),
        isTrue);
    expect(const AreaFilter(city: 'مشهد', districts: {'الهیه'}).matches(offer),
        isFalse);
    expect(const AreaFilter(city: 'طرقبه').matches(offer), isTrue);
    expect(const AreaFilter(province: 'فارس').matches(offer), isFalse);
    expect(const AreaFilter(province: 'خراسان رضوی').matches(offer), isTrue);
    const need = Ad('c2', 'نیاز', 'خدمات', true, 'کرج', 'گوهردشت', 'scaffold',
        'توافق', 'فرد',
        serviceArea: AreaFilter(city: 'مشهد', surroundings: true));
    expect(const AreaFilter(city: 'مشهد').matches(need), isFalse);
    expect(const AreaFilter(city: 'کرج').matches(need), isTrue);
    const national = Ad('c3', 'ارسال', 'مصالح', false, 'کرج', 'مهرشهر', 'tiles',
        'توافق', 'فروشگاه',
        serviceArea: AreaFilter());
    expect(const AreaFilter(province: 'فارس', city: 'شیراز').matches(national),
        isTrue);
  });

  testWidgets('unfinished draft survives tabs and publishes once', (t) async {
    await start(t);
    await newLabor(t, 'نیاز ذخیره‌شده');
    await t.enterText(find.byType(TextFormField).at(1), 'شرایط در پیش‌نویس');
    await tap(t, 'پیام‌ها');
    await tap(t, 'ثبت آگهی');
    await tap(t, 'پیش‌نویس‌ها');
    expect(find.text('نیاز ذخیره‌شده'), findsOneWidget);
    await tap(t, 'نیاز ذخیره‌شده');
    expect(find.byType(TextFormField).evaluate().first.widget is TextFormField,
        isTrue);
    expect(find.text('شرایط در پیش‌نویس'), findsOneWidget);
    await tap(t, 'انتشار آگهی');
    expect(find.text('نیاز ذخیره‌شده'), findsOneWidget);
    await tap(t, 'پیش‌نویس‌ها (۰)');
    expect(find.text('پیش‌نویسی نداری'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('editing draft leaves the published listing unchanged until save',
      (t) async {
    await start(t);
    await tap(t, 'صفحه من');
    await tap(t, 'آگهی‌های من');
    await t.tap(find.text('ویرایش').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'عنوان جدید پیش‌نویس');
    await tap(t, 'ذخیره پیش‌نویس');
    await tap(t, 'آگهی‌ها (۴)');
    expect(find.text('۳ کارگر برای بتن‌ریزی'), findsOneWidget);
    expect(find.text('عنوان جدید پیش‌نویس'), findsNothing);
    await t.tap(find.text('ویرایش').first);
    await t.pumpAndSettle();
    expect(find.text('عنوان جدید پیش‌نویس'), findsOneWidget);
    await tap(t, 'ذخیره تغییرات');
    await tap(t, 'صفحه من');
    await tap(t, 'آگهی‌های من');
    expect(find.text('عنوان جدید پیش‌نویس'), findsOneWidget);
    expect(find.text('۳ کارگر برای بتن‌ریزی'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('preview is private and closing it does not publish', (t) async {
    await start(t);
    await newLabor(t, 'پیش‌نمایش خصوصی');
    await tap(t, 'پیش‌نمایش آگهی');
    expect(find.text('تأیید و انتشار'), findsOneWidget);
    await t.tap(find.byTooltip('بازگشت به ویرایش'));
    await t.pumpAndSettle();
    await tap(t, 'آگهی‌ها');
    await t.enterText(find.byType(TextField), 'پیش‌نمایش خصوصی');
    await t.pumpAndSettle();
    expect(find.text('آگهی پیدا نشد'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'changing category preserves the title and edits the same published ad',
      (t) async {
    await start(t);
    await tap(t, 'صفحه من');
    await tap(t, 'آگهی‌های من');
    await t.tap(find.text('ویرایش').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, 'درخواست تغییر دسته');
    await tap(t, 'تغییر دسته');
    await tap(t, 'مصالح و متریال');
    expect(find.text('درخواست تغییر دسته'), findsOneWidget);
    await tap(t, 'شن و ماسه');
    await t.enterText(find.byType(TextFormField).at(2), '۱۰ تن');
    await tap(t, 'ذخیره تغییرات');
    expect(find.text('آگهی‌ها (۴)'), findsOneWidget);
    expect(find.text('درخواست تغییر دسته'), findsOneWidget);
    expect(find.text('۳ کارگر برای بتن‌ریزی'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'price rejects negative input and delete cancellation preserves an ad',
      (t) async {
    await start(t);
    await newLabor(t, 'آگهی قیمت آزمایشی');
    await t.enterText(find.byType(TextFormField).at(5), '-۱۲۰۰');
    await tap(t, 'انتشار آگهی');
    expect(find.text('یک عدد بیشتر از صفر وارد کن'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).at(5), '۱٬۲۰۰٬۰۰۰');
    await tap(t, 'انتشار آگهی');
    await t.tap(find.byTooltip('حذف آگهی').first);
    await t.pumpAndSettle();
    await tap(t, 'انصراف');
    expect(find.text('آگهی قیمت آزمایشی'), findsOneWidget);
    await t.tap(find.byTooltip('حذف آگهی').first);
    await t.pumpAndSettle();
    await tap(t, 'حذف');
    expect(find.text('آگهی قیمت آزمایشی'), findsNothing);
    await tap(t, 'بازگرداندن');
    expect(find.text('آگهی قیمت آزمایشی'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'location picker clears point when city changes and returns optional district',
      (t) async {
    AdLocation? result;
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showModalBottomSheet<AdLocation>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const AreaPicker(
                              initial:
                                  AreaFilter(province: 'البرز', city: 'کرج'),
                              requireCity: true,
                              pickLocation: true,
                              showMap: false,
                              initialPoint: MapPoint(35.84, 50.97)));
                    },
                    child: const Text('باز کن'))))));
    await tap(t, 'باز کن');
    await t.tap(find.byType(DropdownButtonFormField<String>).last);
    await t.pumpAndSettle();
    await tap(t, 'فردیس');
    await tap(t, 'تأیید محل');
    expect(result!.area.city, 'فردیس');
    expect(result!.point, isNull);
    expect(result!.area.districts, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'coverage supports multiple districts, surroundings and unrestricted reset',
      (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: AreaPicker(
                initial: AreaFilter(city: 'مشهد'),
                coverage: true,
                showMap: false))));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('district-chip-سجاد')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('district-chip-الهیه')));
    await t.pumpAndSettle();
    expect(find.text('2 محله انتخاب شده'), findsOneWidget);
    await tap(t, 'مشهد و شهرهای اطراف');
    await tap(t, 'پاک کردن');
    expect(find.text('همه شهرها'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'cover selection and full screen gallery work with attached images',
      (t) async {
    await start(t);
    await newLabor(t, 'آگهی عکس‌دار');
    final photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
    final second = base64Decode(base64Encode(photo));
    final dynamic shell = t.state(find.byType(AppShell));
    shell.update(() {
      shell.draftPhotos.addAll([photo, second]);
    });
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('cover-photo-1')));
    await t.pumpAndSettle();
    expect(identical(shell.draftPhotos.first, second), isTrue);
    await tap(t, 'انتشار آگهی');
    await tap(t, 'آگهی عکس‌دار');
    await t.tap(find.byType(AdGallery));
    await t.pumpAndSettle();
    expect(find.byTooltip('بستن عکس'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    await t.tap(find.byTooltip('بستن عکس'));
    await t.pumpAndSettle();
    expect(find.byType(LocationMap), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
