import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

const dbVersion = 1;

class SqliteDatabase {
  void _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE Contact (id INTEGER PRIMARY KEY AUTOINCREMENT, name STRING NOT NULL, fingerprint STRING NOT NULL)',
    );
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) {}

  Future<Database> getDb() async {
    final dir = await getApplicationSupportDirectory();
    await databaseFactory.setDatabasesPath(join(dir.path, 'databases'));

    return await openDatabase(
      'ios_ptp.db',
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  void closeDb() async {
    final db = await getDb();
    db.close();
  }
}
