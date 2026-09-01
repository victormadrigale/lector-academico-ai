import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/bookmark.dart';
import '../models/document_item.dart';

class PageTextRow {
  final int page;
  final String text;
  const PageTextRow(this.page, this.text);
}


class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'lector_academico.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE documents(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          local_path TEXT NOT NULL UNIQUE,
          extension TEXT NOT NULL,
          total_pages INTEGER NOT NULL,
          current_page INTEGER NOT NULL DEFAULT 1,
          current_sentence INTEGER NOT NULL DEFAULT 0,
          current_char_offset INTEGER NOT NULL DEFAULT 0,
          progress REAL NOT NULL DEFAULT 0,
          speech_rate REAL NOT NULL DEFAULT 1,
          prepared_offline INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE page_texts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id INTEGER NOT NULL,
          page INTEGER NOT NULL,
          text TEXT NOT NULL,
          UNIQUE(document_id, page),
          FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE bookmarks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id INTEGER NOT NULL,
          page INTEGER NOT NULL,
          sentence_index INTEGER NOT NULL,
          excerpt TEXT NOT NULL,
          note TEXT NOT NULL,
          category TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');
    });
  }

  Future<List<DocumentItem>> documents() async {
    final db = await database;
    final rows = await db.query('documents', orderBy: 'updated_at DESC');
    return rows.map(DocumentItem.fromMap).toList();
  }

  Future<int> insertDocument(DocumentItem item) async {
    final db = await database;
    final map = item.toMap()..remove('id');
    return db.insert('documents', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> savePageText(int documentId, int page, String text) async {
    final db = await database;
    await db.insert(
      'page_texts',
      {'document_id': documentId, 'page': page, 'text': text},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PageTextRow>> documentPageTexts(int documentId) async {
    final db = await database;
    final rows = await db.query(
      'page_texts',
      columns: ['page', 'text'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page ASC',
    );
    return rows
        .map((r) => PageTextRow(r['page'] as int, r['text'] as String))
        .toList();
  }

  Future<int> pageTextCount(int documentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM page_texts WHERE document_id = ?',
      [documentId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<String> pageText(int documentId, int page) async {
    final db = await database;
    final rows = await db.query(
      'page_texts',
      columns: ['text'],
      where: 'document_id = ? AND page = ?',
      whereArgs: [documentId, page],
      limit: 1,
    );
    return rows.isEmpty ? '' : rows.first['text'] as String;
  }

  Future<void> updateProgress(DocumentItem item) async {
    if (item.id == null) return;
    final db = await database;
    await db.update('documents', item.toMap()..remove('id'), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> setOfflinePrepared(int documentId, bool value) async {
    final db = await database;
    await db.update(
      'documents',
      {'prepared_offline': value ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  Future<int> addBookmark(ReaderBookmark bookmark) async {
    final db = await database;
    final map = bookmark.toMap()..remove('id');
    return db.insert('bookmarks', map);
  }

  Future<List<ReaderBookmark>> bookmarks(int documentId) async {
    final db = await database;
    final rows = await db.query(
      'bookmarks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page ASC, sentence_index ASC',
    );
    return rows.map(ReaderBookmark.fromMap).toList();
  }

  Future<void> deleteDocument(int id) async {
    final db = await database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }
}
