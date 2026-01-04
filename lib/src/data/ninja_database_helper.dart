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
      version: 2, // Bump version for migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for interfaces support
      await db.execute('ALTER TABLE campaigns ADD COLUMN interfaces TEXT');
      await db.execute('ALTER TABLE campaigns ADD COLUMN layers TEXT');
      await db.execute('ALTER TABLE campaigns ADD COLUMN title TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Campaigns Table (Cache) - Updated schema
    await db.execute('''
      CREATE TABLE campaigns (
        id TEXT PRIMARY KEY,
        title TEXT,
        config TEXT,
        triggers TEXT,
        layers TEXT,
        interfaces TEXT,
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
