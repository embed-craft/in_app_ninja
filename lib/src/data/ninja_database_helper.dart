import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class NinjaDatabaseHelper {
  static final NinjaDatabaseHelper _instance = NinjaDatabaseHelper._internal();
  static Database? _database;

  factory NinjaDatabaseHelper() => _instance;

  NinjaDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ninja_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Campaigns Table (Cache)
    await db.execute('''
      CREATE TABLE campaigns (
        id TEXT PRIMARY KEY,
        config TEXT,
        triggers TEXT,
        priority INTEGER DEFAULT 0,
        start_date TEXT,
        end_date TEXT,
        created_at TEXT,
        updated_at TEXT,
        status TEXT
      )
    ''');
    
    // 2. Events/Impressions Table (Offline Queue)
    await db.execute('''
      CREATE TABLE offline_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_name TEXT,
        properties TEXT,
        timestamp TEXT
      )
    ''');
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('campaigns');
    await db.delete('offline_events');
  }
}
