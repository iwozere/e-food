import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/analysis_result.dart';
import '../../models/enums.dart';
import '../../models/meal.dart';
import '../../models/recipe.dart';
import '../../widgets/meal_type_label.dart';

final _mealProvider = FutureProvider.autoDispose.family<Meal?, int>(
  (ref, id) => ref.read(mealsRepositoryProvider).getMeal(id),
);

final _recipeForMealProvider =
    FutureProvider.autoDispose.family<Recipe?, int>((ref, recipeId) {
  return ref.read(recipesRepositoryProvider).getRecipe(recipeId);
});

class MealDetailScreen extends ConsumerStatefulWidget {
  final int mealId;
  const MealDetailScreen({super.key, required this.mealId});

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  bool _analyzing = false;

  Future<void> _analyzeNow(Meal meal) async {
    final l = AppLocalizations.of(context);
    final gemini = ref.read(geminiServiceProvider);
    if (gemini == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.mealDetailApiKeyMissing),
          action: SnackBarAction(
            label: l.navSettings,
            onPressed: () => context.go('/settings'),
          ),
        ),
      );
      return;
    }

    setState(() => _analyzing = true);
    try {
      final imageService = ref.read(imageServiceProvider);
      final lengths = await ref.read(utensilLengthsProvider.future);
      final lengthCm = lengths[meal.utensil.name] ?? 18.5;
      final apiBytes = await imageService.resizeForApi(File(meal.photoPath));

      final result = await gemini.analyzeImage(
        imageBytes: apiBytes,
        utensil: meal.utensil.name,
        utensilLengthCm: lengthCm,
      );

      if (!mounted) return;
      await context.push(
        '/results',
        extra: AnalysisResult(
          utensilDetected: result.utensilDetected,
          scaleConfidence: result.scaleConfidence,
          items: result.items,
          totalKcal: result.totalKcal,
          notes: result.notes,
          photoPath: meal.photoPath,
          utensil: meal.utensil.name,
          pendingMealId: meal.id,
          capturedAt: meal.createdAt,
        ),
      );
    } on GeminiRateLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.mealDetailRateLimit)),
        );
      }
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      final msg = (e.statusCode == 503)
          ? l.mealDetailOverloaded
          : (e.statusCode == 401 || e.statusCode == 403)
              ? l.mealDetailKeyInvalid
              : l.captureApiError(e.statusCode);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.mealDetailAnalysisFailed('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
        // Refresh meal data — covers both the "saved" path (pending→analyzed)
        // and the "back without saving" path (re-fetches same pending meal).
        ref.invalidate(_mealProvider(widget.mealId));
      }
    }
  }

  Future<void> _copyToToday(Meal original) async {
    final repo = ref.read(mealsRepositoryProvider);
    final newId = await repo.copyMealToToday(original);
    if (!mounted) return;
    context.go('/history');
    context.push('/history/$newId');
  }

  @override
  Widget build(BuildContext context) {
    final mealAsync = ref.watch(_mealProvider(widget.mealId));
    final meal = mealAsync.valueOrNull;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(meal?.pending == true ? l.mealDetailPendingTitle : l.mealDetailTitle),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (meal != null && !meal.pending) ...[
            if (meal.source != MealSource.recipePortion)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l.mealDetailEditMeal,
                onPressed: () async {
                  await context.push('/history/${widget.mealId}/edit');
                  if (mounted) ref.invalidate(_mealProvider(widget.mealId));
                },
              ),
            IconButton(
              tooltip: meal.starred ? l.historyUnstar : l.historyStar,
              icon: Icon(meal.starred ? Icons.star : Icons.star_border),
              color: meal.starred ? AppColors.accent : null,
              onPressed: () async {
                await ref
                    .read(mealsRepositoryProvider)
                    .starMeal(meal.id!, starred: !meal.starred);
                ref.invalidate(_mealProvider(widget.mealId));
              },
            ),
          ],
        ],
      ),
      body: mealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.commonError('$e'))),
        data: (meal) => meal == null
            ? Center(child: Text(l.mealDetailNotFound))
            : meal.pending
                ? _PendingBody(
                    meal: meal,
                    analyzing: _analyzing,
                    onAnalyze: () => _analyzeNow(meal),
                  )
                : meal.source == MealSource.recipePortion
                    ? _RecipePortionDetail(
                        meal: meal,
                        onCopy: () => _copyToToday(meal),
                      )
                    : _MealDetail(
                        meal: meal,
                        onCopy: () => _copyToToday(meal),
                      ),
      ),
    );
  }
}

// ── Pending state ─────────────────────────────────────────────────────────────

class _PendingBody extends StatelessWidget {
  final Meal meal;
  final bool analyzing;
  final VoidCallback onAnalyze;

  const _PendingBody({
    required this.meal,
    required this.analyzing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoHeader(path: meal.photoPath),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, y · h:mm a', locale).format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                if (meal.mealType != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    children: [
                      _InfoChip(
                        label: mealTypeLabel(l, meal.mealType),
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  l.mealDetailPendingBody,
                  style: const TextStyle(color: AppColors.subtle),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: analyzing ? null : onAnalyze,
                  icon: analyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(analyzing ? l.mealDetailAnalyzing : l.mealDetailAnalyzeNow),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Camera / barcode meal detail ──────────────────────────────────────────────

class _MealDetail extends StatelessWidget {
  final Meal meal;
  final VoidCallback onCopy;
  const _MealDetail({required this.meal, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PhotoHeader(path: meal.photoPath)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name ?? _autoName(l, meal),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, y · h:mm a', locale).format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: l.kcalValue(meal.totalKcal.round()),
                      color: AppColors.accent,
                    ),
                    if (meal.source == MealSource.barcode)
                      _InfoChip(label: '🔖 ${l.sourceBarcode}', color: AppColors.primary)
                    else
                      _InfoChip(
                        label: switch (meal.utensil) {
                          Utensil.fork => l.utensilFork,
                          Utensil.knife => '🔪 ${l.utensilKnife}',
                          Utensil.spoon => '🥄 ${l.utensilSpoon}',
                        },
                        color: AppColors.primary,
                      ),
                    if (meal.scaleConf != null)
                      _InfoChip(
                        label: l.mealDetailConf(_confLevel(l, meal.scaleConf!)),
                        color: _confColor(meal.scaleConf!),
                      ),
                    if (meal.mealType != null)
                      _InfoChip(
                        label: mealTypeLabel(l, meal.mealType),
                        color: AppColors.accent,
                      ),
                  ],
                ),
                if (meal.notes != null && meal.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(meal.notes!, style: const TextStyle(color: AppColors.subtle)),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _MacroBreakdown(
            protein: meal.totalProteinG,
            carbs: meal.totalCarbsG,
            fat: meal.totalFatG,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              l.mealDetailIngredients,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: meal.items.length,
          itemBuilder: (context, i) {
            final item = meal.items[i];
            final macroLine = _macroLine(
                l, item.totalProteinG, item.totalCarbsG, item.totalFatG);
            return ListTile(
              title: Text(item.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.mealDetailItemSubtitle(
                      item.weightG.round(), item.kcalPer100g.round())),
                  if (macroLine != null)
                    Text(macroLine,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.subtle)),
                ],
              ),
              trailing: Text(
                l.kcalValue(item.totalKcal.round()),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: Text(l.historyCopyToToday),
            ),
          ),
        ),
      ],
    );
  }

  String _autoName(AppLocalizations l, Meal meal) {
    if (meal.items.isEmpty) return l.historyMealFallback;
    final names = meal.items.take(2).map((i) => i.name).join(', ');
    return meal.items.length > 2 ? '$names…' : names;
  }

  Color _confColor(String conf) => switch (conf) {
        'high' => Colors.green,
        'medium' => Colors.orange,
        _ => Colors.red,
      };

  String _confLevel(AppLocalizations l, String conf) => switch (conf) {
        'high' => l.confHigh,
        'medium' => l.confMedium,
        _ => l.confLow,
      };
}

// ── Recipe-portion meal detail ────────────────────────────────────────────────

class _RecipePortionDetail extends ConsumerWidget {
  final Meal meal;
  final VoidCallback onCopy;
  const _RecipePortionDetail({required this.meal, required this.onCopy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = meal.recipeId != null
        ? ref.watch(_recipeForMealProvider(meal.recipeId!))
        : const AsyncData<Recipe?>(null);
    final recipe = recipeAsync.valueOrNull;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PhotoHeader(path: meal.photoPath)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name ?? l.mealDetailRecipeMeal,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, y · h:mm a', locale).format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _InfoChip(
                    label: l.kcalValue(meal.totalKcal.round()),
                    color: AppColors.accent,
                  ),
                  if (meal.portionG != null)
                    _InfoChip(
                      label: l.mealDetailPortion(meal.portionG!.round()),
                      color: AppColors.primary,
                    ),
                  _InfoChip(label: '🍳 ${l.sourceRecipe}', color: AppColors.primary),
                  if (meal.mealType != null)
                    _InfoChip(
                      label: mealTypeLabel(l, meal.mealType),
                      color: AppColors.accent,
                    ),
                ]),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _MacroBreakdown(
            protein: meal.totalProteinG,
            carbs: meal.totalCarbsG,
            fat: meal.totalFatG,
          ),
        ),
        if (recipe != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(l.mealDetailIngredientsFromRecipe,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList.builder(
            itemCount: recipe.items.length,
            itemBuilder: (context, i) {
              final item = recipe.items[i];
              final macroLine = _macroLine(
                  l, item.totalProteinG, item.totalCarbsG, item.totalFatG);
              return ListTile(
                title: Text(item.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.mealDetailItemSubtitle(
                        item.weightG.round(), item.kcalPer100g.round())),
                    if (macroLine != null)
                      Text(macroLine,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.subtle)),
                  ],
                ),
                trailing: Text(l.kcalValue(item.totalKcal.round()),
                    style: const TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.bold)),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                TextButton.icon(
                  onPressed: () =>
                      context.push('/recipes/${recipe.id}'),
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: Text(l.mealDetailGoToRecipe),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.push('/recipes/${recipe.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l.mealDetailEditRecipe),
                ),
              ]),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined),
              label: Text(l.historyCopyToToday),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  final String path;
  const _PhotoHeader({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.restaurant, size: 64, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Macro breakdown card shown between the header chips and the ingredient list.
class _MacroBreakdown extends StatelessWidget {
  final double? protein;
  final double? carbs;
  final double? fat;
  const _MacroBreakdown({this.protein, this.carbs, this.fat});

  bool get _hasAny => protein != null || carbs != null || fat != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasAny) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.macros,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _MacroBox(
                    label: l.macroProtein, value: protein, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
                child: _MacroBox(
                    label: l.macroCarbs, value: carbs, color: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(
                child: _MacroBox(
                    label: l.macroFat, value: fat, color: AppColors.error)),
          ]),
        ],
      ),
    );
  }
}

class _MacroBox extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  const _MacroBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 4),
          Text(
            value != null
                ? AppLocalizations.of(context).gramsValue(value!.round())
                : '—',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

// Compact "P 18 g · C 90 g · F 12 g" line for an item's macro totals.
String? _macroLine(
    AppLocalizations l, double? protein, double? carbs, double? fat) {
  final parts = <String>[];
  if (protein != null) {
    parts.add('${l.macroAbbrevProtein} ${l.gramsValue(protein.round())}');
  }
  if (carbs != null) {
    parts.add('${l.macroAbbrevCarbs} ${l.gramsValue(carbs.round())}');
  }
  if (fat != null) {
    parts.add('${l.macroAbbrevFat} ${l.gramsValue(fat.round())}');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
