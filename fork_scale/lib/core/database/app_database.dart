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
      version: 4,
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
        starred     INTEGER NOT NULL DEFAULT 0,
        source      TEXT NOT NULL DEFAULT 'camera',
        barcode     TEXT REFERENCES cached_products(barcode),
        price_chf   REAL,
        recipe_id   INTEGER REFERENCES recipes(id) ON DELETE SET NULL,
        portion_g   REAL
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
    await db.execute('''
      CREATE TABLE cached_products (
        barcode       TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        brand         TEXT,
        pack_size_g   REAL,
        kcal_per_100g REAL NOT NULL,
        protein_g     REAL,
        carbs_g       REAL,
        fat_g         REAL,
        image_url     TEXT,
        source        TEXT NOT NULL,
        fetched_at    INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recipes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL,
        yield_g       REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        photo_path    TEXT,
        notes         TEXT,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recipe_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id     INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        name          TEXT NOT NULL,
        weight_g      REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        total_kcal    REAL NOT NULL,
        source        TEXT NOT NULL DEFAULT 'manual',
        barcode       TEXT,
        sort_order    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_meals_created ON meals(created_at DESC)');
    await db.execute('CREATE INDEX idx_cached_products_fetched ON cached_products(fetched_at)');
    await db.execute('CREATE INDEX idx_recipe_items_recipe ON recipe_items(recipe_id)');
    await db.execute('CREATE INDEX idx_meals_recipe ON meals(recipe_id)');
    await db.execute('CREATE INDEX idx_meals_source ON meals(source)');
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
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE cached_products (
          barcode       TEXT PRIMARY KEY,
          name          TEXT NOT NULL,
          brand         TEXT,
          pack_size_g   REAL,
          kcal_per_100g REAL NOT NULL,
          protein_g     REAL,
          carbs_g       REAL,
          fat_g         REAL,
          image_url     TEXT,
          source        TEXT NOT NULL,
          fetched_at    INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE recipes (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          name          TEXT NOT NULL,
          yield_g       REAL NOT NULL,
          kcal_per_100g REAL NOT NULL,
          photo_path    TEXT,
          notes         TEXT,
          created_at    INTEGER NOT NULL,
          updated_at    INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE recipe_items (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          recipe_id     INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
          name          TEXT NOT NULL,
          weight_g      REAL NOT NULL,
          kcal_per_100g REAL NOT NULL,
          total_kcal    REAL NOT NULL,
          source        TEXT NOT NULL DEFAULT 'manual',
          barcode       TEXT,
          sort_order    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute("ALTER TABLE meals ADD COLUMN source TEXT NOT NULL DEFAULT 'camera'");
      await db.execute("ALTER TABLE meals ADD COLUMN barcode TEXT REFERENCES cached_products(barcode)");
      await db.execute("ALTER TABLE meals ADD COLUMN price_chf REAL");
      await db.execute("ALTER TABLE meals ADD COLUMN recipe_id INTEGER REFERENCES recipes(id) ON DELETE SET NULL");
      await db.execute("ALTER TABLE meals ADD COLUMN portion_g REAL");
      await db.execute('CREATE INDEX idx_cached_products_fetched ON cached_products(fetched_at)');
      await db.execute('CREATE INDEX idx_recipe_items_recipe ON recipe_items(recipe_id)');
      await db.execute('CREATE INDEX idx_meals_recipe ON meals(recipe_id)');
      await db.execute('CREATE INDEX idx_meals_source ON meals(source)');
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

  /// Opens the bundled SFCD SQLite asset, copying to documents if needed.
  /// Returns null if the asset does not exist yet (before build_sfcd.py is run).
  static Future<Database?> openSfcdDb() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'sfcd.db');
      if (!File(dest).existsSync()) {
        final data = await rootBundle.load('assets/db/sfcd.db');
        final bytes = data.buffer.asUint8List();
        await File(dest).writeAsBytes(bytes, flush: true);
      }
      return openDatabase(dest, readOnly: true);
    } catch (_) {
      return null;
    }
  }
}
