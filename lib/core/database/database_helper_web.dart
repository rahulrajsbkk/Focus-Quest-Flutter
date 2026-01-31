import 'package:sembast_web/sembast_web.dart';

Future<Database> openDatabase(String dbName) async {
  return databaseFactoryWeb.openDatabase(dbName);
}

Future<void> deleteAppDatabase(String dbName) async {
  await databaseFactoryWeb.deleteDatabase(dbName);
}
