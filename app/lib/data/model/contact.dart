import '../sqlite_database.dart';

class Contact {
  Contact(this.name, this.fingerprint);

  int? _id;
  final String name;
  final String fingerprint;

  static final SqliteDatabase _db = SqliteDatabase();

  factory Contact.fromDatabase(Map<String, Object?> row) {
    var contact = Contact(row['name'] as String, row['fingerprint'] as String);
    contact._id = row['id'] as int;

    return contact;
  }

  static Future<Iterable<Contact>> getContacts() async {
    final database = await _db.getDb();
    final rows = await database.query('Contact');
    return rows.map((row) => Contact.fromDatabase(row));
  }

  static Future<bool> hasFingerprint(String fingerprint) async {
    final database = await _db.getDb();
    final rows = await database.query(
      'Contact',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<Contact> insert() async {
    if (_id == null) {
      final database = await _db.getDb();
      final insertedId = await database.insert('Contact', {
        'name': name,
        'fingerprint': fingerprint,
      });
      _id = insertedId;
    }

    return this;
  }

  Future<void> delete() async {
    if (_id != null) {
      final database = await _db.getDb();
      database.delete('Contact', where: 'id = ?', whereArgs: [_id]);
      _id = null;
    }
  }

  Future<void> update() async {
    if (_id != null) {
      final database = await _db.getDb();
      database.update(
        'Contact',
        {'name': name, 'fingerprint': fingerprint},
        where: 'id = ?',
        whereArgs: [_id],
      );
    }
  }
}
