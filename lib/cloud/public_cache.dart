import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend.dart';

/// Read-only public data. Private records and credentials never enter this cache.
class PublicMarketplaceCache {
  String get key => 'kamcheh-public-market:$backendUrl';
  Future<Map<String, dynamic>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(List<BackendRow> services, List<BackendRow> needs,
      List<BackendRow> people) async {
    await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode({
          'services': services,
          'needs': needs,
          'people': people,
          'saved_at': DateTime.now().toUtc().toIso8601String()
        }));
  }
}
