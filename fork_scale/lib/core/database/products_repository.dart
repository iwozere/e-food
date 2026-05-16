import 'package:sqflite/sqflite.dart';

import '../../models/cached_product.dart';
import 'app_database.dart';

const _staleDays = 30;

class ProductsRepository {
  Future<CachedProduct?> getByBarcode(String barcode) async {
    final db = await AppDatabase.mealsDb;
    final rows = await db.query('cached_products',
        where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) return null;
    final product = CachedProduct.fromMap(rows.first);
    final staleMs = const Duration(days: _staleDays).inMilliseconds;
    if (DateTime.now().millisecondsSinceEpoch - product.fetchedAt > staleMs) {
      return null; // stale — caller should re-fetch
    }
    return product;
  }

  Future<void> upsert(CachedProduct product) async {
    final db = await AppDatabase.mealsDb;
    await db.insert(
      'cached_products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
