import 'package:focus_quest/core/database/database_helper_stub.dart'
    if (dart.library.io) 'package:focus_quest/core/database/database_helper_io.dart'
    if (dart.library.html) 'package:focus_quest/core/database/database_helper_web.dart';
import 'package:sembast/sembast.dart';

Future<Database> openAppDatabase(String dbName) => openDatabase(dbName);

Future<void> deleteAppDatabase(String dbName) => deleteAppDatabase(dbName);
