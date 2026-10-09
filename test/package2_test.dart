import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/core.dart';
import 'package:sakhtyar/main.dart';
import 'package:sakhtyar/listing_gallery.dart';
import 'package:sakhtyar/service_listing.dart';
import 'package:sakhtyar/user_profile.dart';
import 'package:sakhtyar/work_repository.dart';

void main() {
  DemoWorkRepository repository() => DemoWorkRepository()
    ..saveService(
        ServiceListing(
            id: 's',
            ownerId: 'provider',
            title: 'داربست',
            details: 'نصب و اجاره داربست',
            city: 'مشهد'),
        'provider');

  test(
      'service contact requires owner permission; duplicate pending and stranger access are blocked',
      () {
    final r = repository();
    final c = r.requestServiceContact(
        's', 'customer', ServiceContactKind.quote, 'نمای ساختمان');
    final key = r.conversationKey('s', 'customer', 'service');
    expect(() => r.chat(key, 'customer'), throwsStateError);
    expect(
        () => r.requestServiceContact(
            's', 'customer', ServiceContactKind.conversation, 'سلام'),
        throwsStateError);
    expect(() => r.respondServiceContact(c.id, 'customer', 'accepted'),
        throwsStateError);
    expect(() => r.respondServiceContact(c.id, 'stranger', 'declined'),
        throwsStateError);
    r.respondServiceContact(c.id, 'provider', 'accepted');
    expect(r.chat(key, 'customer').contextType, 'service');
    expect(r.needs, isEmpty);
    expect(
        r.chat(key, 'provider').messages.single.text, contains('نمای ساختمان'));
    expect(() => r.chat(key, 'stranger'), throwsStateError);
    expect(() => r.respondServiceContact(c.id, 'provider', 'accepted'),
        throwsStateError);
    expect(r.conversations.length, 1);
  });

  test('pause/delete blocks new contacts but keeps chat and restore rights',
      () {
    final r = repository();
    final c = r.requestServiceContact(
        's', 'customer', ServiceContactKind.conversation, 'هماهنگی');
    r.respondServiceContact(c.id, 'provider', 'accepted');
    expect(() => r.changeServiceStatus('s', 'customer', archived: true),
        throwsStateError);
    r.changeServiceStatus('s', 'provider', enabled: false, archived: true);
    expect(
        () => r.requestServiceContact(
            's', 'other', ServiceContactKind.quote, 'نیاز جدید'),
        throwsStateError);
    r.send(r.conversationKey('s', 'customer', 'service'), 'customer',
        'پیام بعد از حذف');
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.service('s').archived, isTrue);
    expect(restored.conversations.values.single.messages.last.text,
        'پیام بعد از حذف');
    restored.changeServiceStatus('s', 'provider',
        enabled: true, archived: false);
    expect(
        restored
            .requestServiceContact(
                's', 'other', ServiceContactKind.quote, 'نیاز جدید')
            .status,
        'pending');
  });

  test('cancel and decline do not open chat; only sender can cancel', () {
    final r = repository();
    final c = r.requestServiceContact(
        's', 'customer', ServiceContactKind.cooperation, 'همکاری');
    expect(() => r.respondServiceContact(c.id, 'provider', 'cancelled'),
        throwsStateError);
    r.respondServiceContact(c.id, 'customer', 'cancelled');
    final next = r.requestServiceContact(
        's', 'customer', ServiceContactKind.quote, 'استعلام');
    r.respondServiceContact(next.id, 'provider', 'declined');
    expect(r.conversations, isEmpty);
  });

  test(
      'service visit cannot expose private request address with same identifier',
      () {
    final r = repository()
      ..saveNeed(
          WorkNeed(
              id: 's',
              ownerId: 'provider',
              title: 'نیاز خصوصی',
              details: 'کار',
              city: 'مشهد',
              privateAddress: 'نشانی خصوصی'),
          'provider');
    final at = DateTime.now().add(const Duration(days: 1));
    final c = r.requestServiceContact(
        's', 'customer', ServiceContactKind.visit, 'بازدید',
        visitAt: at);
    r.respondServiceContact(c.id, 'provider', 'accepted');
    expect(r.visits.values.single.contextType, 'service');
    expect(r.privateAddress('s', 'customer'), isNull);
    final v = r.proposeServiceVisit(
        's', 'customer', 'provider', at.add(const Duration(days: 1)));
    expect(
        () => r.respondVisit(v.id, 'provider', 'accepted'), throwsStateError);
    r.respondVisit(v.id, 'customer', 'accepted');
    final requestVisit = r.proposeVisit('s', 'customer', 'customer', at);
    r.respondVisit(requestVisit.id, 'provider', 'accepted');
    expect(r.privateAddress('s', 'customer'), 'نشانی خصوصی');
    expect(r.conversations.length, 2);
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.conversations.values.map((c) => c.contextType).toSet(),
        {'service', 'request'});
    expect(restored.contacts.values.single.visitAt, at);
  });

  test('photos survive persistence and are copied; over six images cannot save',
      () {
    final r = repository(), bytes = Uint8List.fromList([1, 2, 3]);
    final s = ServiceListing(
        id: 'new',
        ownerId: 'provider',
        title: 'خدمات',
        details: 'شرح',
        city: 'طرقبه',
        photos: [bytes],
        galleryAssets: ['scaffold']);
    r.saveService(s, 'provider');
    bytes[0] = 9;
    final restored = DemoWorkRepository()
      ..restore(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.service('new').photos.single, [1, 2, 3]);
    expect(restored.service('new').galleryAssets, ['scaffold']);
    expect(
        () => r.saveService(
            ServiceListing(
                id: 'too-many',
                ownerId: 'provider',
                title: 'خدمات',
                details: 'شرح',
                city: 'مشهد',
                galleryAssets: List.filled(7, 'scaffold')),
            'provider'),
        throwsStateError);
    expect(() => r.saveService(s, 'stranger'), throwsStateError);
  });

  test('profile statistics ignore self and repeated visitor on same day', () {
    final r = DemoProfileRepository()..save(UserProfile(id: 'provider'));
    final day = DateTime(2026, 10, 8);
    expect(r.recordView('provider', 'provider', at: day), isFalse);
    expect(r.recordView('missing', 'guest', at: day), isFalse);
    expect(r.recordView('provider', 'guest', at: day), isTrue);
    expect(
        r.recordView('provider', 'guest',
            at: day.add(const Duration(hours: 2))),
        isFalse);
    expect(
        r.recordView('provider', 'guest', at: day.add(const Duration(days: 1))),
        isTrue);
    expect(r.profileViews['provider']!.length, 2);
  });

  testWidgets(
      'profile tiles stay compact at 320 pixels and public profile has service ads',
      (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(const SakhtyarApp());
    await t.pumpAndSettle();
    await t.tap(find.text('پروفایل‌ها').last);
    await t.pumpAndSettle();
    final tiles = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('profile-tile-'));
    expect(tiles, findsWidgets);
    final grid = t.widget<GridView>(find.byType(GridView));
    expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2);
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const ValueKey('profile-tile-demo-person-1')));
    await t.pumpAndSettle();
    expect(find.text('آگهی‌های فعال'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'gallery advances and full screen can close without controller errors',
      (t) async {
    await t.pumpWidget(const MaterialApp(
        home:
            Scaffold(body: ListingGallery(assets: ['concrete', 'scaffold']))));
    await t.tap(find.byTooltip('عکس بعد'));
    await t.pumpAndSettle();
    expect(find.text('۲ / ۲'), findsOneWidget);
    await t.tap(find.byType(Image).last);
    await t.pumpAndSettle();
    expect(find.byTooltip('بستن گالری'), findsOneWidget);
    await t.tap(find.byTooltip('بستن گالری'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
