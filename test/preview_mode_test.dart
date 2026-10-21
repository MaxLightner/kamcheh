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
}
