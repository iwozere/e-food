import '../database/app_database.dart';

class SfcdItem {
  final String name;
  final double kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  const SfcdItem({
    required this.name,
    required this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });
}

/// Searches the bundled Swiss Food Composition Database (SFCD) asset.
/// Returns an empty list if the asset does not exist yet
/// (run tool/build_sfcd.py and add assets/db/sfcd.db to pubspec.yaml first).
class SfcdService {
  Future<List<SfcdItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await AppDatabase.openSfcdDb();
    if (db == null) return [];
    final like = '%${query.trim()}%';
    // Prefer the query with macro columns; fall back to kcal-only for older
    // sfcd.db assets that predate the protein/carbs/fat columns.
    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''SELECT name_en, name_de, name_fr, energy_kcal_100g,
                  protein_g, carbs_g, fat_g
           FROM swiss_fcd_items
           WHERE name_en LIKE ? OR name_de LIKE ? OR name_fr LIKE ?
           LIMIT 20''',
        [like, like, like],
      );
    } catch (_) {
      try {
        rows = await db.rawQuery(
          '''SELECT name_en, name_de, name_fr, energy_kcal_100g
             FROM swiss_fcd_items
             WHERE name_en LIKE ? OR name_de LIKE ? OR name_fr LIKE ?
             LIMIT 20''',
          [like, like, like],
        );
      } catch (_) {
        return [];
      }
    }
    return rows.map((r) {
      final name = (r['name_en'] as String?)?.isNotEmpty == true
          ? r['name_en'] as String
          : (r['name_de'] as String?) ?? '';
      final kcal = (r['energy_kcal_100g'] as num?)?.toDouble() ?? 0.0;
      return SfcdItem(
        name: name,
        kcalPer100g: kcal,
        proteinPer100g: (r['protein_g'] as num?)?.toDouble(),
        carbsPer100g: (r['carbs_g'] as num?)?.toDouble(),
        fatPer100g: (r['fat_g'] as num?)?.toDouble(),
      );
    }).toList();
  }
}
