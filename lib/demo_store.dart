import 'package:sembast/sembast.dart';
import 'demo_store_native.dart'
    if (dart.library.js_interop) 'demo_store_web.dart';

class DemoStore {
  Database? _database;
  Future<void> _queue = Future.value();
  final _record =
      StoreRef<String, Map<String, Object?>>('demo').record('stage13');
  Future<Map<String, Object?>?> load() async {
    _database = await openDemoDatabase();
    return _record.get(_database!);
  }

  Future<void> save(Map<String, Object?> value) {
    final result = _queue.catchError((_) {}).then((_) async {
      await _record.put(_database!, value);
    });
    _queue = result;
    return result;
  }

  Future<void> close() async {
    await _queue.catchError((_) {});
    await _database?.close();
  }
}
