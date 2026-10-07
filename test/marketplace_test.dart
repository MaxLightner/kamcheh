import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/demo_data.dart';
import 'package:sakhtyar/marketplace.dart';
import 'package:sakhtyar/network_data.dart';
import 'package:sakhtyar/feed_filter.dart';

void main() {
  final corpus = [...initialOwnAds, ...demoAds, ...marketDemoAds];
  test(
      'catalog covers all eight categories without mixing tool sales and rentals',
      () {
    expect(marketCategories.length, 8);
    expect(marketCategories.map((c) => c.id).toSet().length, 8);
    for (final category in marketCategories) {
      final ads = corpus.where((ad) => ad.category == category.id);
      expect(ads, isNotEmpty, reason: category.label);
      for (final ad in ads) {
        expect(category.kinds, contains(ad.kind), reason: ad.title);
        expect(adSkills(ad).every(category.skills.contains), isTrue,
            reason: ad.title);
        if (ad.pricing != null)
          expect(category.priceUnits, contains(ad.pricing!.unit));
      }
    }
    expect(
        corpus
            .where((a) => a.category == 'ابزار')
            .every((a) => a.kind == AdKind.sale || a.kind == AdKind.need),
        isTrue);
    expect(
        corpus
            .where((a) => a.category == 'اجاره')
            .every((a) => a.kind == AdKind.rental || a.kind == AdKind.need),
        isTrue);
  });
  test('filters combine category, kind, skill, activity and sample identity',
      () {
    const filter = FeedFilter(
        category: 'مصالح',
        kind: AdKind.sale,
        skill: 'سنگ ساختمانی',
        activity: ActivityType.wholesale,
        verifiedOnly: true);
    final result = filter.apply(corpus, area: const AreaFilter());
    expect(result.map((a) => a.id), ['m01']);
    expect(profileFor(result.single).specialty, 'تأمین سنگ');
    expect(filter.apply(corpus, area: const AreaFilter(city: 'مشهد')), isEmpty);
    expect(
        filter.apply(corpus,
            area: const AreaFilter(), isClosed: (a) => a.id == 'm01'),
        isEmpty);
  });
  test('price sorting and bounds compare only the selected price unit', () {
    const filter = FeedFilter(
        category: 'اجاره',
        unit: PriceUnit.day,
        minPrice: 600000,
        maxPrice: 900000,
        sort: FeedSort.cheapest);
    final result = filter.apply(corpus, area: const AreaFilter());
    expect(result.map((a) => a.id), ['m05', 'a03', 'm04']);
    expect(result.every((a) => a.pricing?.unit == PriceUnit.day), isTrue);
    expect(
        filter
            .copyWith(sort: FeedSort.mostExpensive)
            .apply(corpus, area: const AreaFilter())
            .map((a) => a.id),
        ['m04', 'a03', 'm05']);
    final cleared = filter.selectCategory('نیرو');
    expect(cleared.unit, isNull);
    expect(cleared.minPrice, isNull);
    expect(cleared.sort, FeedSort.newest);
  });
  test('search normalizes Persian letters, spaces and matches supplier type',
      () {
    final filter = const FeedFilter();
    expect(
        filter
            .apply(corpus, area: const AreaFilter(), query: 'عمده فروش سنگ')
            .map((a) => a.id),
        ['m01']);
    expect(
        filter
            .apply(corpus, area: const AreaFilter(), query: 'نقشه برداري')
            .any((a) => a.id == 'a34'),
        isTrue);
    expect(parsePriceInput('۱٬۲۰۰٬۰۰۰'), 1200000);
    expect(parsePriceInput('١٢٠٠٠٠٠'), 1200000);
    expect(parsePriceInput('-100'), isNull);
    expect(parsePriceInput('abc100'), isNull);
  });
  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('all eight shortcuts open matching listings on a narrow phone',
      (tester) async {
    await start(tester);
    for (final c in marketCategories) {
      await tap(tester, find.byKey(ValueKey('home-category-${c.id}')));
      final rows = find.byWidgetPredicate((w) =>
          w is InkWell &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('ad-row-'));
      expect(rows, findsWidgets, reason: c.label);
      await tap(tester, find.byTooltip('حذف فیلتر ${c.shortLabel}'));
      expect(find.byKey(ValueKey('home-category-${c.id}')), findsOneWidget);
    }
  });
  testWidgets('inline bookmark does not open the ad and survives in messages',
      (tester) async {
    await start(tester);
    await tap(tester, find.byKey(const ValueKey('home-category-ابزار')));
    await tap(tester, find.byTooltip('نشان کردن بدون باز کردن').first);
    expect(find.text('جزئیات آگهی'), findsNothing);
    await tap(tester, find.text('پیام‌ها').last);
    await tap(tester, find.text('نشان‌ها'));
    expect(find.text('فروش دستگاه جوش اینورتر'), findsOneWidget);
  });
  testWidgets(
      'filters show only relevant kinds and validate reversed price bounds',
      (tester) async {
    await start(tester);
    await tap(tester, find.byKey(const ValueKey('feed-filter')));
    await tap(tester, find.byKey(const ValueKey('filter-category-اجاره')));
    expect(find.byKey(const ValueKey('filter-kind-rental')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-kind-sale')), findsNothing);
    final unit = find.byType(DropdownButtonFormField<PriceUnit>);
    await tap(tester, unit);
    await tap(tester, find.text('روز').last);
    await tester.enterText(
        find.byKey(const ValueKey('filter-min-price')), '۹۰۰۰۰۰');
    await tester.enterText(
        find.byKey(const ValueKey('filter-max-price')), '۶۰۰۰۰۰');
    await tap(tester, find.text('نمایش نتیجه'));
    expect(find.text('قیمت «از» باید کمتر یا برابر «تا» باشد'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('filter-min-price')), '۶۰۰۰۰۰');
    await tester.enterText(
        find.byKey(const ValueKey('filter-max-price')), '۹۰۰۰۰۰');
    await tap(tester, find.text('نمایش نتیجه'));
    expect(find.text('اجاره موتور برق برای پروژه'), findsOneWidget);
    expect(find.text('فروش دستگاه جوش اینورتر'), findsNothing);
  });
}
