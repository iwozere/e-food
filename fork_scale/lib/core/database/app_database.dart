import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _meals;
  static Database? _usda;

  static Future<Database> get mealsDb async {
    _meals ??= await _openMealsDb();
    return _meals!;
  }

  static Future<Database> get usdaDb async {
    _usda ??= await _openUsdaDb();
    return _usda!;
  }

  static Future<Database> _openMealsDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'fork_scale.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _createMealsSchema,
      onUpgrade: _upgradeMealsSchema,
    );
  }

  static Future<void> _createMealsSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meals (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at  INTEGER NOT NULL,
        photo_path  TEXT NOT NULL,
        name        TEXT,
        notes       TEXT,
        total_kcal  REAL NOT NULL,
        utensil     TEXT NOT NULL DEFAULT 'fork',
        scale_conf  TEXT,
        model_used  TEXT NOT NULL,
        meal_type   TEXT,
        pending     INTEGER NOT NULL DEFAULT 0,
        starred     INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE meal_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id       INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
        name          TEXT NOT NULL,
        weight_g      REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        total_kcal    REAL NOT NULL,
        sort_order    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_meals_created ON meals(created_at DESC)');
    await db.execute(
      "CREATE VIRTUAL TABLE meals_fts USING fts4(name, notes)",
    );
  }

  static Future<void> _upgradeMealsSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE meals ADD COLUMN meal_type TEXT");
      await db.execute(
          "ALTER TABLE meals ADD COLUMN pending INTEGER NOT NULL DEFAULT 0");
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE meals ADD COLUMN starred INTEGER NOT NULL DEFAULT 0");
    }
  }

  static Future<Database> _openUsdaDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'usda_nutrition.db');
    if (!File(dest).existsSync()) {
      final data = await rootBundle.load('assets/db/usda_nutrition.db');
      final bytes = data.buffer.asUint8List();
      await File(dest).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(dest, readOnly: true);
  }
}
