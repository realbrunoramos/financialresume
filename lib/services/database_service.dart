import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/section.dart';
import '../models/transaction.dart' as trns;
import '../models/reserved_amount.dart';

class DatabaseService {
  static Database? _database;
  static const String dbName = 'financialresume.db';
  static const String sectionTable = 'sections';
  static const String transactionTable = 'transactions';
  static const String paidMonthsTable = 'paid_months';
  static const String emailsSentTable = 'emails_sent';
  static const String reservedAmountsTable = 'reserved_amounts';
  static const String settingsTable = 'settings';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: 13,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {

        if (oldVersion < 10) {
          await _recreateTransactionsTable(db);
        } else {
          await _addMissingColumns(db);
        }

        if (oldVersion < 12) {
          await _upgradeToVersion12(db);
        }
        if (oldVersion < 13) {
          await _upgradeToVersion13(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $sectionTable (
        id TEXT PRIMARY KEY,
        name TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $transactionTable (
        id TEXT PRIMARY KEY,
        amount REAL,
        entity TEXT,
        description TEXT,
        isCredit INTEGER,
        date TEXT,
        receiptPaths TEXT,
        sectionId TEXT,
        docType TEXT,
        monthRef TEXT,
        dueDate TEXT,
        paid INTEGER DEFAULT 0,
        numeroSerie TEXT,
        metodoPagamento TEXT,
        FOREIGN KEY (sectionId) REFERENCES $sectionTable(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $paidMonthsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        monthRef TEXT UNIQUE,
        addedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $emailsSentTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT,
        recipient TEXT,
        subject TEXT,
        body TEXT,
        sentAt TEXT,
        emission_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $reservedAmountsTable (
        id TEXT PRIMARY KEY,
        sectionId TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (sectionId) REFERENCES $sectionTable(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE $settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _upgradeToVersion12(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $settingsTable (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    } catch (e) {
      debugPrint("Settings table already exists: $e");
    }
  }

  Future<void> _upgradeToVersion13(Database db) async {
    // Version 13: schema finalised in _createTables — no migration needed.
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      settingsTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    final value = result.first['value'] as String?;
    return value;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final result = await db.query(settingsTable);
    final settings = <String, String>{};
    for (final row in result) {
      settings[row['key'] as String] = row['value'] as String;
    }
    return settings;
  }

  Future<void> initializeDefaultSettings() async {

    final language = await getSetting('language');
    if (language == null) {
      await saveSetting('language', 'pt');
    }

  }

  Future<void> _recreateTransactionsTable(Database db) async {

    final oldData = await db.rawQuery('SELECT * FROM $transactionTable');

    await db.execute('DROP TABLE IF EXISTS $transactionTable');

    await db.execute('''
      CREATE TABLE $transactionTable (
        id TEXT PRIMARY KEY,
        amount REAL,
        entity TEXT,
        description TEXT,
        isCredit INTEGER,
        date TEXT,
        receiptPaths TEXT,
        sectionId TEXT,
        docType TEXT,
        monthRef TEXT,
        dueDate TEXT,
        paid INTEGER DEFAULT 0,
        numeroSerie TEXT,
        metodoPagamento TEXT,
        FOREIGN KEY (sectionId) REFERENCES $sectionTable(id)
      )
    ''');

    if (oldData.isNotEmpty) {
      final batch = db.batch();
      for (final row in oldData) {
        final newRow = Map<String, dynamic>.from(row);
        newRow['numeroSerie'] = row['numeroSerie'] ?? '';
        newRow['metodoPagamento'] = row['metodoPagamento'] ?? '';

        batch.insert(transactionTable, newRow, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit();
    }

  }

  Future<void> _addMissingColumns(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($transactionTable)');
    final existingColumns = tableInfo.map((col) => col['name'] as String).toList();


    if (!existingColumns.contains('numeroSerie')) {
      await db.execute('ALTER TABLE $transactionTable ADD COLUMN numeroSerie TEXT');
    }

    if (!existingColumns.contains('metodoPagamento')) {
      await db.execute('ALTER TABLE $transactionTable ADD COLUMN metodoPagamento TEXT');
    }
  }

Future<void> addTransaction(trns.Transaction transaction) async {
    final db = await database;
    await db.insert(
      transactionTable,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(trns.Transaction transaction) async {
    final db = await database;
    await db.update(
      transactionTable,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete(transactionTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<trns.Transaction>> getAllTransactions(String sectionId) async {
    final db = await database;
    final maps = await db.query(
      transactionTable,
      where: 'sectionId = ? AND NOT (docType = ? AND paid = 0)',
      whereArgs: [sectionId, '2'],
      orderBy: 'date DESC',
    );
    return maps.map((map) => trns.Transaction.fromMap(map)).toList();
  }

  /// Paginated variant — pass [limit] and [offset] for cursor-based loading.
  Future<List<trns.Transaction>> getTransactionsPaged(
    String sectionId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await database;
    final maps = await db.query(
      transactionTable,
      where: 'sectionId = ? AND NOT (docType = ? AND paid = 0)',
      whereArgs: [sectionId, '2'],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => trns.Transaction.fromMap(map)).toList();
  }

  /// Total balance across ALL sections (excludes unpaid invoices, same rule
  /// as [getAllTransactions]).  Single SQL query — O(1) instead of O(N).
  Future<double> getTotalBalance() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(CASE WHEN isCredit = 1 THEN amount ELSE -amount END), 0
      ) AS total
      FROM $transactionTable
      WHERE NOT (docType = '2' AND paid = 0)
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Count + balance for a single section in one query.
  Future<({int count, double balance})> getSectionStats(String sectionId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) AS cnt,
        COALESCE(
          SUM(CASE WHEN isCredit = 1 THEN amount ELSE -amount END), 0
        ) AS balance
      FROM $transactionTable
      WHERE sectionId = ?
        AND NOT (docType = '2' AND paid = 0)
    ''', [sectionId]);
    return (
      count:   (result.first['cnt']     as num?)?.toInt()    ?? 0,
      balance: (result.first['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Future<bool> existReserve(String reverseDescrip) async {
    final db = await database;
    final maps = await db.query(
      reservedAmountsTable,
      where: 'description = ?',
      whereArgs: [reverseDescrip],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<List<trns.Transaction>> getNoPaidInvoices(String sectionId) async {
    final db = await database;

    final maps = await db.rawQuery('''
    SELECT t2.*
    FROM $transactionTable t2
    WHERE 
      t2.docType = '2'
      AND t2.paid = 0
      AND t2.sectionId = ?
    ORDER BY date DESC
  ''', [sectionId]);

    return maps.map((map) => trns.Transaction.fromMap(map)).toList();
  }

  Future<trns.Transaction?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query(transactionTable, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return trns.Transaction.fromMap(maps.first);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(reservedAmountsTable);
    await db.delete(transactionTable);
    await db.delete(sectionTable);
    await db.delete(paidMonthsTable);
    await db.delete(emailsSentTable);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Note: _upgradeToVersion2 … _upgradeToVersion8 were removed.
  // DB is now created fresh from v13 schema in _createDatabase — see git history.

  Future<void> addSection(Section section) async {
    final db = await database;
    await db.insert(sectionTable, section.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSection(Section section) async {
    final db = await database;
    await db.update(
      sectionTable,
      section.toMap(),
      where: 'id = ?',
      whereArgs: [section.id],
    );
  }

  Future<void> deleteSection(String id) async {
    final db = await database;
    await db.delete(transactionTable, where: 'sectionId = ?', whereArgs: [id]);
    await db
        .delete(reservedAmountsTable, where: 'sectionId = ?', whereArgs: [id]);
    await db.delete(sectionTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Section>> getAllSections() async {
    final db = await database;
    final maps = await db.query(sectionTable, orderBy: 'createdAt DESC');
    return maps.map((map) => Section.fromMap(map)).toList();
  }

  Future<List<trns.Transaction>> getPayProof(String sectionId) async {
    final db = await database;
    final maps = await db.rawQuery('''
    SELECT t3.*
    FROM $transactionTable t3
    WHERE 
      t3.docType = '3'
      AND t3.sectionId = ?
  ''', [sectionId]);
    return maps.map((map) => trns.Transaction.fromMap(map)).toList();
  }

  Future<List<String>> getPaidMonths() async {
    final db = await database;
    final maps = await db.query(paidMonthsTable, orderBy: 'addedAt DESC');
    return maps.map((map) => map['monthRef'] as String).toList();
  }

  Future<void> addPaidMonth(String monthRef) async {
    final db = await database;
    await db.insert(
      paidMonthsTable,
      {'monthRef': monthRef, 'addedAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> addSentEmail(Map<String, dynamic> emailData) async {
    final db = await database;
    await db.insert(
      emailsSentTable,
      emailData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPreviousEmailsForEntity(String entity) async {
    final db = await database;
    return await db.query(
      emailsSentTable,
      where: 'entity = ?',
      whereArgs: [entity],
      orderBy: 'sentAt DESC',
      limit: 5,
    );
  }

  Future<void> insertReservedAmount(ReservedAmount reservedAmount) async {
    final db = await database;
    await db.insert(reservedAmountsTable, reservedAmount.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReservedAmount>> getReservedAmounts(String sectionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      reservedAmountsTable,
      where: 'sectionId = ?',
      whereArgs: [sectionId],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => ReservedAmount.fromMap(maps[i]));
  }

  Future<void> updateReservedAmount(ReservedAmount reservedAmount) async {
    final db = await database;
    await db.update(
      reservedAmountsTable,
      reservedAmount.toMap(),
      where: 'id = ?',
      whereArgs: [reservedAmount.id],
    );
  }

  Future<void> deleteReservedAmount(String id) async {
    final db = await database;
    await db.delete(
      reservedAmountsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalReservedAmount(String sectionId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total 
      FROM $reservedAmountsTable 
      WHERE sectionId = ?
    ''', [sectionId]);

    final total = result.first['total'] as double?;
    return total ?? 0.0;
  }

}