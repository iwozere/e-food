import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _meals;
  static Database? _usda;
  static Database? _sfcd;

  /// False when running under sqflite_common_ffi (unit tests), which lacks FTS4.
  static bool hasFts = true;

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
      version: 8,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db, withFts: true),
      onUpgrade: _upgradeMealsSchema,
    );
  }

  // ── Canonical table DDL (single source of truth) ────────────────────────
  // These constants define the *current* schema and are used both for a fresh
  // install (_createSchema) and, where the historical migration DDL is
  // identical, by the upgrade path — so the two cannot silently drift.

  static const String _ddlMeals = '''
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
        price_chf   REAL, -- deprecated (Pepesto pricing, removed); kept: SQLite < 3.35 can't DROP COLUMN cheaply
        recipe_id   INTEGER REFERENCES recipes(id) ON DELETE SET NULL,
        portion_g   REAL,
        total_protein_g REAL,
        total_carbs_g   REAL,
        total_fat_g     REAL
      )
    ''';

  static const String _ddlMealItems = '''
      CREATE TABLE meal_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_id       INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
        name          TEXT NOT NULL,
        weight_g      REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        total_kcal    REAL NOT NULL,
        sort_order    INTEGER NOT NULL DEFAULT 0,
        usda_matched  INTEGER NOT NULL DEFAULT 0,
        protein_per_100g REAL,
        carbs_per_100g   REAL,
        fat_per_100g     REAL
      )
    ''';

  static const String _ddlCachedProducts = '''
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
    ''';

  static const String _ddlRecipes = '''
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
    ''';

  static const String _ddlRecipeItems = '''
      CREATE TABLE recipe_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id     INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        name          TEXT NOT NULL,
        weight_g      REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        total_kcal    REAL NOT NULL,
        source        TEXT NOT NULL DEFAULT 'manual',
        barcode       TEXT,
        sort_order    INTEGER NOT NULL DEFAULT 0,
        protein_per_100g REAL,
        carbs_per_100g   REAL,
        fat_per_100g     REAL
      )
    ''';

  static const List<String> _ddlIndexes = [
    'CREATE INDEX idx_meals_created ON meals(created_at DESC)',
    'CREATE INDEX idx_cached_products_fetched ON cached_products(fetched_at)',
    'CREATE INDEX idx_recipe_items_recipe ON recipe_items(recipe_id)',
    'CREATE INDEX idx_meals_recipe ON meals(recipe_id)',
    'CREATE INDEX idx_meals_source ON meals(source)',
  ];

  /// Builds the full meals schema from scratch. [withFts] adds the FTS4 virtual
  /// table; it is false under sqflite_common_ffi (unit tests), whose SQLite
  /// build rarely includes FTS4.
  static Future<void> _createSchema(Database db, {required bool withFts}) async {
    await db.execute(_ddlMeals);
    await db.execute(_ddlMealItems);
    await db.execute(_ddlCachedProducts);
    await db.execute(_ddlRecipes);
    await db.execute(_ddlRecipeItems);
    for (final idx in _ddlIndexes) {
      await db.execute(idx);
    }
    if (withFts) {
      await db.execute('CREATE VIRTUAL TABLE meals_fts USING fts4(name, notes)');
    }
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
      // cached_products and recipes DDL are unchanged since v4 — reuse the
      // canonical constants so they can't drift from a fresh install.
      await db.execute(_ddlCachedProducts);
      await db.execute(_ddlRecipes);
      // v4 recipe_items intentionally omits the macro columns added in v5;
      // the v5 migration appends them via ALTER TABLE on existing installs.
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
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE recipe_items ADD COLUMN protein_per_100g REAL");
      await db.execute("ALTER TABLE recipe_items ADD COLUMN carbs_per_100g REAL");
      await db.execute("ALTER TABLE recipe_items ADD COLUMN fat_per_100g REAL");
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE meal_items ADD COLUMN protein_per_100g REAL");
      await db.execute("ALTER TABLE meal_items ADD COLUMN carbs_per_100g REAL");
      await db.execute("ALTER TABLE meal_items ADD COLUMN fat_per_100g REAL");
      await db.execute("ALTER TABLE meals ADD COLUMN total_protein_g REAL");
      await db.execute("ALTER TABLE meals ADD COLUMN total_carbs_g REAL");
      await db.execute("ALTER TABLE meals ADD COLUMN total_fat_g REAL");
    }
    if (oldVersion < 7) {
      // Remove orphan rows that accumulated while FK enforcement was off.
      await db.execute(
        'DELETE FROM meal_items WHERE meal_id NOT IN (SELECT id FROM meals)',
      );
      await db.execute(
        'DELETE FROM recipe_items WHERE recipe_id NOT IN (SELECT id FROM recipes)',
      );
      await db.execute(
        'UPDATE meals SET recipe_id = NULL '
        'WHERE recipe_id IS NOT NULL '
        'AND recipe_id NOT IN (SELECT id FROM recipes)',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE meal_items ADD COLUMN usda_matched INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Opens an in-memory meals DB and wires it as the active singleton.
  /// Only for use in unit tests (sqflite_common_ffi must be initialised first).
  ///
  /// FTS4 is skipped because the FFI SQLite build rarely includes it; tests
  /// that exercise full-text search should run against a real device.
  @visibleForTesting
  static Future<Database> openTestDb() async {
    hasFts = false;
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 8,
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => _createSchema(db, withFts: false),
      onUpgrade: _upgradeMealsSchema,
    );
    _meals = db;
    return db;
  }

  static Future<void> closeAll() async {
    await _meals?.close();
    _meals = null;
    await _usda?.close();
    _usda = null;
    await _sfcd?.close();
    _sfcd = null;
    hasFts = true;
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

  /// Returns the cached SFCD connection, opening and copying the bundled asset
  /// on first call. Returns null if the asset does not exist yet.
  static Future<Database?> openSfcdDb() async {
    if (_sfcd != null) return _sfcd;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'sfcd.db');
      if (!File(dest).existsSync()) {
        final data = await rootBundle.load('assets/db/sfcd.db');
        final bytes = data.buffer.asUint8List();
        await File(dest).writeAsBytes(bytes, flush: true);
      }
      _sfcd = await openDatabase(dest, readOnly: true);
      return _sfcd;
    } catch (_) {
      return null;
    }
  }
}
