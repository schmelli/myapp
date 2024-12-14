import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/document.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'legal_ide.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        // Create tables
        await db.execute('''
          CREATE TABLE documents (
            uuid TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            content TEXT NOT NULL,
            userId TEXT NOT NULL,
            created TEXT NOT NULL,
            lastEdited TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE document_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            documentId TEXT NOT NULL,
            userId TEXT NOT NULL,
            action TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            details TEXT,
            FOREIGN KEY (documentId) REFERENCES documents (uuid)
          )
        ''');
      },
    );
  }

  // Document operations
  Future<List<Document>> getDocuments(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'lastEdited DESC',
    );

    return List.generate(maps.length, (i) => Document.fromJson(maps[i]));
  }

  Future<Document> getDocument(String uuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (maps.isEmpty) {
      throw Exception('Document not found');
    }

    return Document.fromJson(maps.first);
  }

  Future<void> insertDocument(Document document) async {
    final db = await database;
    await db.insert(
      'documents',
      document.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Log the creation
    await _logDocumentAction(
      document.uuid,
      document.userId,
      'CREATE',
      'Document created',
    );
  }

  Future<void> updateDocument(Document document) async {
    final db = await database;
    await db.update(
      'documents',
      document.toJson(),
      where: 'uuid = ?',
      whereArgs: [document.uuid],
    );

    // Log the update
    await _logDocumentAction(
      document.uuid,
      document.userId,
      'UPDATE',
      'Document updated',
    );
  }

  Future<void> deleteDocument(String uuid, String userId) async {
    final db = await database;
    await db.delete(
      'documents',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    // Log the deletion
    await _logDocumentAction(
      uuid,
      userId,
      'DELETE',
      'Document deleted',
    );
  }

  // Logging operations
  Future<void> _logDocumentAction(
    String documentId,
    String userId,
    String action,
    String details,
  ) async {
    final db = await database;
    await db.insert(
      'document_logs',
      {
        'documentId': documentId,
        'userId': userId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'details': details,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDocumentLogs(String documentId) async {
    final db = await database;
    return db.query(
      'document_logs',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'timestamp DESC',
    );
  }

  // Offline support
  Future<void> saveOfflineChanges(Document document) async {
    final db = await database;
    await db.insert(
      'offline_changes',
      {
        ...document.toJson(),
        'syncStatus': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineChanges() async {
    final db = await database;
    return db.query(
      'offline_changes',
      where: 'syncStatus = ?',
      whereArgs: ['pending'],
    );
  }
}
