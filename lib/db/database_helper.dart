import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/template_model.dart';
import '../models/transaction_model.dart';

/// مسؤول عن كل التعامل مع قاعدة بيانات SQLite المحلية.
/// كل الجداول تستخدم مفاتيح UUID نصية (وليست أرقام متسلسلة تلقائية)
/// لأن هذا ضروري جداً عند دمج قاعدتي بيانات من جهازين مختلفين:
/// الأرقام المتسلسلة (AUTOINCREMENT) ستتعارض، أما UUID فلا يتعارض أبداً.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<String> getDbPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'transaction_tracker.db');
  }

  Future<Database> _initDb() async {
    final path = await getDbPath();
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE template_steps (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        title TEXT NOT NULL,
        entity TEXT,
        stepOrder INTEGER NOT NULL,
        FOREIGN KEY (templateId) REFERENCES templates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        templateName TEXT NOT NULL,
        title TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        completedAt INTEGER,
        status TEXT NOT NULL,
        currentStepIndex INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_steps (
        id TEXT PRIMARY KEY,
        transactionId TEXT NOT NULL,
        title TEXT NOT NULL,
        entity TEXT,
        stepOrder INTEGER NOT NULL,
        kind TEXT NOT NULL,
        status TEXT NOT NULL,
        startedAt INTEGER,
        completedAt INTEGER,
        note TEXT,
        referenceNumber TEXT,
        blockReason TEXT,
        attachmentPaths TEXT,
        FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
      )
    ''');

    // جدول لتسجيل الأنماط المكتشفة (للاقتراح الذكي المحلي)
    await db.execute('''
      CREATE TABLE pattern_suggestions (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        exceptionTitle TEXT NOT NULL,
        exceptionEntity TEXT,
        occurrenceCount INTEGER NOT NULL DEFAULT 1,
        lastSeenAt INTEGER NOT NULL,
        dismissed INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ---------------------- القوالب (Templates) ----------------------

  Future<void> insertTemplate(TemplateModel t) async {
    final db = await database;
    await db.insert('templates', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTemplateStep(TemplateStepModel s) async {
    final db = await database;
    await db.insert('template_steps', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TemplateModel>> getAllTemplates() async {
    final db = await database;
    final rows = await db.query('templates', orderBy: 'createdAt DESC');
    return rows.map((r) => TemplateModel.fromMap(r)).toList();
  }

  Future<List<TemplateStepModel>> getTemplateSteps(String templateId) async {
    final db = await database;
    final rows = await db.query(
      'template_steps',
      where: 'templateId = ?',
      whereArgs: [templateId],
      orderBy: 'stepOrder ASC',
    );
    return rows.map((r) => TemplateStepModel.fromMap(r)).toList();
  }

  Future<void> deleteTemplate(String templateId) async {
    final db = await database;
    await db
        .delete('template_steps', where: 'templateId = ?', whereArgs: [templateId]);
    await db.delete('templates', where: 'id = ?', whereArgs: [templateId]);
  }

  // ---------------------- المعاملات (Transactions) ----------------------

  Future<void> insertTransaction(TransactionModel t) async {
    final db = await database;
    await db.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTransactionStep(TransactionStepInstance s) async {
    final db = await database;
    await db.insert('transaction_steps', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(TransactionModel t) async {
    final db = await database;
    await db.update('transactions', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> updateTransactionStep(TransactionStepInstance s) async {
    final db = await database;
    await db.update('transaction_steps', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<List<TransactionModel>> getActiveTransactions() async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'startedAt DESC',
    );
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  Future<List<TransactionModel>> getArchivedTransactions() async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'status != ?',
      whereArgs: ['active'],
      orderBy: 'completedAt DESC',
    );
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  Future<List<TransactionStepInstance>> getTransactionSteps(
      String transactionId) async {
    final db = await database;
    final rows = await db.query(
      'transaction_steps',
      where: 'transactionId = ?',
      whereArgs: [transactionId],
      orderBy: 'stepOrder ASC',
    );
    return rows.map((r) => TransactionStepInstance.fromMap(r)).toList();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await database;
    await db.delete('transaction_steps',
        where: 'transactionId = ?', whereArgs: [transactionId]);
    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
  }

  // ---------------------- الأنماط الذكية (Pattern Suggestions) ----------------------

  /// يسجّل حدوث "خطوة استثنائية" معينة ضمن قالب معين، ويزيد عداد التكرار
  /// إن كانت موجودة مسبقاً بنفس العنوان والجهة لنفس القالب.
  Future<void> recordExceptionOccurrence({
    required String templateId,
    required String exceptionTitle,
    String? exceptionEntity,
  }) async {
    final db = await database;
    final existing = await db.query(
      'pattern_suggestions',
      where: 'templateId = ? AND exceptionTitle = ? AND IFNULL(exceptionEntity,"") = ?',
      whereArgs: [templateId, exceptionTitle, exceptionEntity ?? ''],
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      final newCount = (row['occurrenceCount'] as int) + 1;
      await db.update(
        'pattern_suggestions',
        {
          'occurrenceCount': newCount,
          'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
          'dismissed': 0, // نعيد تفعيله إن كان قد رُفض سابقاً، لأنه تكرر مجدداً
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    } else {
      await db.insert('pattern_suggestions', {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'templateId': templateId,
        'exceptionTitle': exceptionTitle,
        'exceptionEntity': exceptionEntity,
        'occurrenceCount': 1,
        'lastSeenAt': DateTime.now().millisecondsSinceEpoch,
        'dismissed': 0,
      });
    }
  }

  /// يرجع كل الاقتراحات التي تكررت مرتين أو أكثر لقالب معين ولم تُرفض
  Future<List<Map<String, dynamic>>> getSuggestionsForTemplate(
      String templateId) async {
    final db = await database;
    return db.query(
      'pattern_suggestions',
      where: 'templateId = ? AND occurrenceCount >= 2 AND dismissed = 0',
      whereArgs: [templateId],
      orderBy: 'occurrenceCount DESC',
    );
  }

  Future<void> dismissSuggestion(String suggestionId) async {
    final db = await database;
    await db.update(
      'pattern_suggestions',
      {'dismissed': 1},
      where: 'id = ?',
      whereArgs: [suggestionId],
    );
  }

  // ---------------------- الدمج (Merge) من نسخة احتياطية خارجية ----------------------

  /// يدمج بيانات من قاعدة بيانات أخرى (تم استيرادها من جهاز آخر) ضمن القاعدة الحالية.
  /// بما أن كل المعرفات UUID، الدمج آمن: أي صف بنفس الـ id موجود مسبقاً يُتجاهل
  /// (نفترض أنه نفس السجل)، وأي صف جديد يُضاف دون حذف أي شيء محلي.
  Future<MergeResult> mergeFromExternalDb(Database externalDb) async {
    final db = await database;
    int templatesAdded = 0;
    int transactionsAdded = 0;
    int stepsAdded = 0;

    await db.transaction((txn) async {
      // دمج القوالب
      final extTemplates = await externalDb.query('templates');
      for (final row in extTemplates) {
        final exists = await txn
            .query('templates', where: 'id = ?', whereArgs: [row['id']]);
        if (exists.isEmpty) {
          await txn.insert('templates', row);
          templatesAdded++;
        }
      }

      // دمج خطوات القوالب
      final extTemplateSteps = await externalDb.query('template_steps');
      for (final row in extTemplateSteps) {
        final exists = await txn.query('template_steps',
            where: 'id = ?', whereArgs: [row['id']]);
        if (exists.isEmpty) {
          await txn.insert('template_steps', row);
        }
      }

      // دمج المعاملات
      final extTransactions = await externalDb.query('transactions');
      for (final row in extTransactions) {
        final exists = await txn
            .query('transactions', where: 'id = ?', whereArgs: [row['id']]);
        if (exists.isEmpty) {
          await txn.insert('transactions', row);
          transactionsAdded++;
        }
      }

      // دمج خطوات المعاملات
      final extSteps = await externalDb.query('transaction_steps');
      for (final row in extSteps) {
        final exists = await txn.query('transaction_steps',
            where: 'id = ?', whereArgs: [row['id']]);
        if (exists.isEmpty) {
          await txn.insert('transaction_steps', row);
          stepsAdded++;
        }
      }

      // دمج اقتراحات الأنماط (اختياري لكنه مفيد لنقل الخبرة بين الأجهزة)
      final extPatterns = await externalDb.query('pattern_suggestions');
      for (final row in extPatterns) {
        final exists = await txn.query('pattern_suggestions',
            where: 'id = ?', whereArgs: [row['id']]);
        if (exists.isEmpty) {
          await txn.insert('pattern_suggestions', row);
        }
      }
    });

    return MergeResult(
      templatesAdded: templatesAdded,
      transactionsAdded: transactionsAdded,
      stepsAdded: stepsAdded,
    );
  }
}

class MergeResult {
  final int templatesAdded;
  final int transactionsAdded;
  final int stepsAdded;

  MergeResult({
    required this.templatesAdded,
    required this.transactionsAdded,
    required this.stepsAdded,
  });
}
