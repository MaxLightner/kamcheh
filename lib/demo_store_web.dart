import 'package:sembast_web/sembast_web.dart';

Future<Database> openDemoDatabase() =>
    databaseFactoryWeb.openDatabase('kamcheh-demo-v1');
