import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/demo_data.dart';
import 'package:sakhtyar/demo_migration.dart';
import 'package:sakhtyar/marketplace.dart';
import 'package:sakhtyar/persian_calendar.dart';
import 'package:sakhtyar/request_filter.dart';
import 'package:sakhtyar/service_listing.dart';
import 'package:sakhtyar/user_profile.dart';
import 'package:sakhtyar/work_repository.dart';
import 'package:sakhtyar/network_data.dart';

void main() {
  test('an unrecognized requirement is not assigned the first category skill',
      () {
    const ad = Ad('unknown', 'نیاز به نقشه‌بردار', 'مهندسی', true, 'مشهد', '',
        'survey', '', 'کارفرما');
    expect(adSkills(ad), isEmpty);
  });
  WorkNeed need(String id, {bool crew = false, String city = 'مشهد'}) =>
      WorkNeed(
          id: id,
          ownerId: 'customer',
          title: 'دیوارچینی',
          details: 'اجرای دیوار',
          city: city,
          crew: crew,
          skills: ['دیوارچینی']);
  ServiceListing service() => ServiceListing(
      id: 'service',
      ownerId: 'provider',
      title: 'اجرای بنایی',
      details: 'معرفی خدمات',
      city: 'مشهد');

  test(
      'service promotions cannot accept request proposals, persistence preserves both',
      () {
    final r = DemoWorkRepository()
      ..saveService(service(), 'provider')
      ..saveNeed(need('request'), 'customer');
    expect(() => r.propose('service', 'worker', 10, PriceUnit.project, '', ''),
        throwsStateError);
    expect(() => r.saveService(service(), 'stranger'), throwsStateError);
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.services.keys, ['service']);
    expect(restored.needs.keys, ['request']);
    expect(restored.need('request').skills, ['دیوارچینی']);
  });
  test(
      'request filtering uses required crew and skills rather than owner identity',
      () {
    final needs = [
      need('solo'),
      need('crew', crew: true),
      need('outside', crew: true, city: 'کرج')
    ];
    final found = const RequestFilter(crewOnly: true, skill: 'دیوارچینی')
        .apply(needs, area: const AreaFilter(city: 'مشهد'), query: 'دیوار');
    expect(found.map((n) => n.id), ['crew']);
    expect(
        const RequestFilter(skill: 'داربست')
            .apply(needs, area: const AreaFilter()),
        isEmpty);
  });
  test('legacy migration retains messages, proposal IDs and custom locations',
      () {
    final r = DemoWorkRepository()
      ..needs['own-labor'] = need('own-labor', city: 'کرج')
      ..needs['custom'] = need('custom', city: 'کرج');
    final b =
        r.propose('own-labor', 'worker', 100, PriceUnit.project, 'شنبه', '');
    final c = r.select('own-labor', b.id, 'customer');
    r.send(c.id, 'worker', 'پیام قبلی');
    final old = r.toJson()..remove('services');
    final restored = DemoWorkRepository()..restore(jsonDecode(jsonEncode(old)));
    final p = UserProfile(id: 'demo-person-1', city: 'کرج');
    migrateStructureDemo(restored, [p], [service()]);
    expect(restored.need('own-labor').city, 'مشهد');
    expect(restored.need('custom').city, 'کرج');
    expect(restored.chat(c.id, 'worker').messages.single.text, 'پیام قبلی');
    expect(restored.need('own-labor').chosenId, b.id);
    expect(restored.services.length, 1);
    expect(p.city, 'مشهد');
    restored.services['service']!.title = 'ویرایش ذخیره‌شده';
    migrateStructureDemo(restored, [p], [service()]);
    expect(restored.services['service']!.title, 'ویرایش ذخیره‌شده');
  });
  test('calendar handles Nowruz and leap Esfand', () {
    expect(jalaliDate(DateTime(2025, 3, 20)), '۱۴۰۳/۱۲/۳۰');
    expect(jalaliDate(DateTime(2025, 3, 21)), '۱۴۰۴/۰۱/۰۱');
    expect(jalaliDate(DateTime(2025, 3, 21, 9, 5), withTime: true),
        '۱۴۰۴/۰۱/۰۱ · ۹:۰۵');
  });
  testWidgets('all discovery tabs are public and show distinct record types',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const SakhtyarApp());
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad-row-a05')), findsNothing);
    expect(find.byKey(const ValueKey('ad-row-a01')), findsOneWidget);
    await t.tap(find.text('پروفایل‌ها').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-search')), findsOneWidget);
    expect(find.byType(DemoLogin), findsNothing);
    await t.tap(find.text('درخواست‌ها').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad-row-a05')), findsOneWidget);
    expect(find.byKey(const ValueKey('ad-row-a01')), findsNothing);
    expect(find.text('تخصص موردنیاز'), findsOneWidget);
    expect(find.byType(DemoLogin), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Shamsi picker returns the selected Gregorian storage date',
      (t) async {
    DateTime? selected;
    await t.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () async => selected = await pickPersianDate(context,
                    initialDate: DateTime(2025, 3, 21),
                    firstDate: DateTime(2025, 3, 20),
                    lastDate: DateTime(2025, 4, 20)),
                child: const Text('بازدید')))));
    await t.tap(find.text('بازدید'));
    await t.pumpAndSettle();
    expect(find.text('انتخاب تاریخ · شمسی'), findsOneWidget);
    expect(find.text('فروردین ۱۴۰۴'), findsOneWidget);
    await t.tap(find.text('انتخاب تاریخ'));
    await t.pumpAndSettle();
    expect(selected, DateTime(2025, 3, 21));
    expect(t.takeException(), isNull);
  });
}
