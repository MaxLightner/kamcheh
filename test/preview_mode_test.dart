import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/main.dart';

void main() {
  group('Kamcheh preview mode selection', () {
    test('preview keeps sample accounts even when backend is configured', () {
      expect(
        shouldUseCloudMode(
          backendReady: true,
          previewBuild: true,
          requestedDemo: false,
          requestedCloud: false,
        ),
        isFalse,
      );
    });

    test('explicit online switch reaches the shared backend', () {
      expect(
        shouldUseCloudMode(
          backendReady: true,
          previewBuild: true,
          requestedDemo: false,
          requestedCloud: true,
        ),
        isTrue,
      );
    });

    test('explicit demo wins over live on a production-first build', () {
      expect(
        shouldUseCloudMode(
          backendReady: true,
          previewBuild: false,
          requestedDemo: true,
          requestedCloud: true,
        ),
        isFalse,
      );
    });

    test('backend is never selected without configuration', () {
      expect(
        shouldUseCloudMode(
          backendReady: false,
          previewBuild: false,
          requestedDemo: false,
          requestedCloud: true,
        ),
        isFalse,
      );
    });
  });
  testWidgets('tools are separate from profile settings on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const SakhtyarApp(startWithDemoAccount: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ابزارها').last);
    await tester.pumpAndSettle();
    expect(find.text('گونیا'), findsOneWidget);
    expect(find.text('متر دیجیتال'), findsOneWidget);
    expect(find.text('حسابداری'), findsOneWidget);
    expect(find.text('پروفایل عمومی من'), findsNothing);

    await tester.tap(find.text('پروفایل‌ها').last);
    await tester.pumpAndSettle();
    expect(find.text('پروفایل من'), findsWidgets);
    expect(find.text('پیش‌نمایش'), findsOneWidget);
    expect(find.text('تنظیمات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public tools and header login work without an account',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SakhtyarApp());
    await tester.pumpAndSettle();
    expect(find.text('ورود / ثبت‌نام'), findsOneWidget);
    await tester.tap(find.text('ابزارها').last);
    await tester.pumpAndSettle();
    expect(find.text('گونیا'), findsOneWidget);
    expect(find.text('ورود / ثبت‌نام'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
