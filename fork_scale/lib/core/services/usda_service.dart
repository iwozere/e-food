import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// A USDA `foods` row chosen by [UsdaService.lookup], with the [score] that won
/// it. [kcalPer100g] is always present; the macro fields are nullable because a
/// matched food may not carry every macronutrient.
@immutable
class UsdaMatch {
  final double kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final String matchedName;
  final double score;

  const UsdaMatch({
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.matchedName,
    required this.score,
  });
}

class UsdaService {
  /// Below this score a candidate is considered too weak to override the LLM's
  /// own kcal estimate, so [lookup] returns null and the caller keeps the LLM
  /// value (with `usdaMatched = false`). Tuned so a full-coverage, reasonably
  /// specific match clears it while a single-word coincidental hit does not.
  static const double matchThreshold = 0.5;

  /// Returns kcal and macros (per 100g) for the best-matching food name, or null
  /// if no match clears [matchThreshold]. A weak match is deliberately *not*
  /// returned so a coincidental USDA row never silently overrides a better LLM
  /// estimate. Macro fields are nullable — a matched food may lack a given macro.
  Future<UsdaMatch?> lookup(String foodName) async {
    final db = await AppDatabase.usdaDb;
    final lower = foodName.toLowerCase().trim();
    const cols =
        'description, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g';

    // Exact description match is authoritative (score 1.0).
    final exact = await db.rawQuery(
      'SELECT $cols FROM foods WHERE LOWER(description) = ? LIMIT 1',
      [lower],
    );
    if (exact.isNotEmpty) {
      return _rowToMatch(exact.first, 1.0);
    }

    // Candidate set: descriptions containing every significant query word.
    final words = _significantTokens(lower);
    if (words.isEmpty) return null;
    final likeClause = words.map((_) => 'LOWER(description) LIKE ?').join(' AND ');
    final likeArgs = words.map((w) => '%$w%').toList();
    final rows = await db.rawQuery(
      'SELECT $cols FROM foods WHERE $likeClause LIMIT 25',
      likeArgs,
    );
    if (rows.isEmpty) return null;

    // Rank by match score, not raw description length, and reject weak winners.
    UsdaMatch? best;
    for (final row in rows) {
      final score = scoreMatch(lower, row['description'] as String);
      if (best == null || score > best.score) {
        best = _rowToMatch(row, score);
      }
    }
    if (best == null || best.score < matchThreshold) return null;
    return best;
  }

  static UsdaMatch _rowToMatch(Map<String, Object?> row, double score) =>
      UsdaMatch(
        kcalPer100g: (row['kcal_per_100g'] as num).toDouble(),
        proteinPer100g: (row['protein_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (row['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (row['fat_per_100g'] as num?)?.toDouble(),
        matchedName: row['description'] as String,
        score: score,
      );

  /// Similarity of a USDA [description] to a [query], in [0, 1].
  ///
  /// `coverage` = fraction of query tokens found in the description (1.0 when
  /// every query word is present). `specificity` = fraction of the
  /// description's tokens that the query accounts for (penalises long,
  /// over-qualified descriptions like "chicken and rice casserole with cream").
  ///
  ///   score = coverage * specificity
  ///
  /// so an exact-length full match scores 1.0, "grilled chicken" vs "chicken
  /// breast, grilled" scores ~0.67 (clears the threshold), and a fully-covered
  /// but much longer/over-qualified description falls below it — so a
  /// calorically-different dish never silently overrides the LLM estimate.
  /// Pure and side-effect free for unit testing.
  @visibleForTesting
  static double scoreMatch(String query, String description) {
    final q = _significantTokens(query).toSet();
    final d = _significantTokens(description).toSet();
    if (q.isEmpty || d.isEmpty) return 0;
    final overlap = q.intersection(d).length;
    if (overlap == 0) return 0;
    final coverage = overlap / q.length;
    final specificity = overlap / d.length;
    return coverage * specificity;
  }

  /// Lowercased word tokens of length > 2 (drops punctuation and stopword-ish
  /// short words such as "of"/"in"/"&").
  static List<String> _significantTokens(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 2)
        .toList();
  }
}
