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
  static const String reservedAmountsTable = 'reserved_amounts'; // Nova tabela

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
      version: 7, // Incrementado para nova tabela de reservas
      onCreate: (db, version) async {
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE $sectionTable (
              id TEXT PRIMARY KEY,
              name TEXT,
              createdAt TEXT
            )
          ''');
          await db.execute('ALTER TABLE $transactionTable ADD sectionId TEXT');
          final defaultSection = Section(
            id: 'default_section',
            name: 'Transações Padrão',
            createdAt: DateTime.now(),
          );
          await db.insert(sectionTable, defaultSection.toMap());
          await db.execute('UPDATE $transactionTable SET sectionId = ?', ['default_section']);
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $transactionTable ADD docType TEXT');
          await db.execute('ALTER TABLE $transactionTable ADD monthRef TEXT');
          await db.execute('ALTER TABLE $transactionTable ADD dueDate TEXT');
          await db.execute('ALTER TABLE $transactionTable ADD paid INTEGER DEFAULT 0');
          await db.execute('''
            CREATE TABLE $paidMonthsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              monthRef TEXT UNIQUE,
              addedAt TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $emailsSentTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              entity TEXT,
              recipient TEXT,
              subject TEXT,
              body TEXT,
              sentAt TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE $emailsSentTable ADD COLUMN emission_date TEXT');
          await db.execute('ALTER TABLE $transactionTable ADD COLUMN entity TEXT DEFAULT ""');
        }
        if (oldVersion < 7) {
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
        }
      },
    );
  }

  // Métodos para Sections
  Future<void> addSection(Section section) async {
    final db = await database;
    await db.insert(sectionTable, section.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.delete(reservedAmountsTable, where: 'sectionId = ?', whereArgs: [id]);
    await db.delete(sectionTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Section>> getAllSections() async {
    final db = await database;
    final maps = await db.query(sectionTable, orderBy: 'createdAt DESC');
    return maps.map((map) => Section.fromMap(map)).toList();
  }

  // Métodos para Transactions
  Future<void> addTransaction(trns.Transaction transaction) async {
    final db = await database;
    await db.insert(transactionTable, transaction.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<trns.Transaction?> getTransactionById(String id) async {
    final db = await database;
    final maps = await db.query(transactionTable, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return trns.Transaction.fromMap(maps.first);
  }

  // Métodos para Paid Months
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

  // Métodos para Emails
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

  // NOVOS MÉTODOS PARA RESERVED AMOUNTS
  Future<void> insertReservedAmount(ReservedAmount reservedAmount) async {
    final db = await database;
    await db.insert(
        reservedAmountsTable,
        reservedAmount.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
    );
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

  // Método auxiliar para obter o total reservado
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

  // Método para limpar todas as tabelas (útil para desenvolvimento)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(reservedAmountsTable);
    await db.delete(transactionTable);
    await db.delete(sectionTable);
    await db.delete(paidMonthsTable);
    await db.delete(emailsSentTable);
  }

  // Método para fechar a base de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}