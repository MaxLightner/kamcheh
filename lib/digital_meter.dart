import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// WebXR generally requires a full Chrome browser instead of Android WebView.
/// Kept independent of authentication and shared backend configuration.
const digitalMeterUrl = String.fromEnvironment(
  'KAMCHEH_AR_METER_URL',
  defaultValue: 'https://maxlightner.github.io/kamcheh/ar-meter/',
);

Future<void> launchDigitalMeter(BuildContext context) async {
  try {
    final opened = await launchUrl(
      Uri.parse(digitalMeterUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('باز کردن متر دیجیتال ممکن نشد. با Chrome اندروید امتحان کن.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('مرورگر سازگار برای باز کردن متر دیجیتال پیدا نشد.'),
        ),
      );
    }
  }
}
