import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';

Future<Database> openDemoDatabase() async {
  final directory = await getApplicationSupportDirectory();
  return databaseFactoryIo.openDatabase('${directory.path}/kamcheh-demo-v1.db');
}
