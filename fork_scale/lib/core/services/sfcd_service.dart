import '../database/app_database.dart';

class SfcdItem {
  final String name;
  final double kcalPer100g;
  const SfcdItem({required this.name, required this.kcalPer100g});
}

/// Searches the bundled Swiss Food Composition Database (SFCD) asset.
/// Returns an empty list if the asset does not exist yet
/// (run tool/build_sfcd.py and add assets/db/sfcd.db to pubspec.yaml first).
class SfcdService {
  Future<List<SfcdItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await AppDatabase.openSfcdDb();
    if (db == null) return [];
    try {
      final like = '%${query.trim()}%';
      final rows = await db.rawQuery(
        '''SELECT name_en, name_de, name_fr, energy_kcal_100g
           FROM swiss_fcd_items
           WHERE name_en LIKE ? OR name_de LIKE ? OR name_fr LIKE ?
           LIMIT 20''',
        [like, like, like],
      );
      return rows.map((r) {
        final name = (r['name_en'] as String?)?.isNotEmpty == true
            ? r['name_en'] as String
            : (r['name_de'] as String?) ?? '';
        final kcal = (r['energy_kcal_100g'] as num?)?.toDouble() ?? 0.0;
        return SfcdItem(name: name, kcalPer100g: kcal);
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
