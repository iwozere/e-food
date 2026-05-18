import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/analysis_result.dart';
import '../../models/meal.dart';
import '../../models/recipe.dart';

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
    final gemini = ref.read(geminiServiceProvider);
    if (gemini == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gemini API key missing.'),
          action: SnackBarAction(
            label: 'Settings',
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
      final lengthCm = lengths[meal.utensil] ?? 18.5;
      final apiBytes = await imageService.resizeForApi(File(meal.photoPath));

      final result = await gemini.analyzeImage(
        imageBytes: apiBytes,
        utensil: meal.utensil,
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
          utensil: meal.utensil,
          pendingMealId: meal.id,
          capturedAt: meal.createdAt,
        ),
      );
    } on GeminiRateLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate limit reached — try again in a minute.')),
        );
      }
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      final msg = (e.statusCode == 503)
          ? 'Gemini is overloaded — try again in a moment.'
          : (e.statusCode == 401 || e.statusCode == 403)
              ? 'API key invalid — check Settings.'
              : 'API error (${e.statusCode}).';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(meal?.pending == true ? 'Pending Meal' : 'Meal Detail'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (meal != null && !meal.pending) ...[
            if (meal.source == 'camera')
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit meal',
                onPressed: () async {
                  await context.push('/history/${widget.mealId}/edit');
                  if (mounted) ref.invalidate(_mealProvider(widget.mealId));
                },
              ),
            IconButton(
              tooltip: meal.starred ? 'Unstar' : 'Star',
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (meal) => meal == null
            ? const Center(child: Text('Meal not found'))
            : meal.pending
                ? _PendingBody(
                    meal: meal,
                    analyzing: _analyzing,
                    onAnalyze: () => _analyzeNow(meal),
                  )
                : meal.source == 'recipe_portion'
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
                  DateFormat('EEEE, MMMM d, y · h:mm a').format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                if (meal.mealType != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    children: [
                      _InfoChip(
                        label: _mealTypeLabel(meal.mealType),
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'This photo was saved but not yet analyzed.',
                  style: TextStyle(color: AppColors.subtle),
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
                  label: Text(analyzing ? 'Analyzing…' : 'Analyze now'),
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
                  meal.name ?? _autoName(meal),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, y · h:mm a').format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      label: '${meal.totalKcal.round()} kcal',
                      color: AppColors.accent,
                    ),
                    if (meal.source == 'barcode')
                      const _InfoChip(label: '🔖 Barcode', color: AppColors.primary)
                    else
                      _InfoChip(
                        label: switch (meal.utensil) {
                          'fork' => '🍴 Fork',
                          'knife' => '🔪 Knife',
                          'spoon' => '🥄 Spoon',
                          _ => meal.utensil,
                        },
                        color: AppColors.primary,
                      ),
                    if (meal.scaleConf != null)
                      _InfoChip(
                        label: 'Conf: ${meal.scaleConf}',
                        color: _confColor(meal.scaleConf!),
                      ),
                    if (meal.mealType != null)
                      _InfoChip(
                        label: _mealTypeLabel(meal.mealType),
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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Ingredients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: meal.items.length,
          itemBuilder: (context, i) {
            final item = meal.items[i];
            return ListTile(
              title: Text(item.name),
              subtitle: Text(
                  '${item.weightG.round()} g · ${item.kcalPer100g.round()} kcal/100g'),
              trailing: Text(
                '${item.totalKcal.round()} kcal',
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
              label: const Text('Copy to today'),
            ),
          ),
        ),
      ],
    );
  }

  String _autoName(Meal meal) {
    if (meal.items.isEmpty) return 'Meal';
    final names = meal.items.take(2).map((i) => i.name).join(', ');
    return meal.items.length > 2 ? '$names…' : names;
  }

  Color _confColor(String conf) => switch (conf) {
        'high' => Colors.green,
        'medium' => Colors.orange,
        _ => Colors.red,
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
                  meal.name ?? 'Recipe meal',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, y · h:mm a').format(meal.createdAt),
                  style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _InfoChip(
                    label: '${meal.totalKcal.round()} kcal',
                    color: AppColors.accent,
                  ),
                  if (meal.portionG != null)
                    _InfoChip(
                      label: '${meal.portionG!.round()} g portion',
                      color: AppColors.primary,
                    ),
                  const _InfoChip(label: '🍳 Recipe', color: AppColors.primary),
                  if (meal.mealType != null)
                    _InfoChip(
                      label: _mealTypeLabel(meal.mealType),
                      color: AppColors.accent,
                    ),
                ]),
              ],
            ),
          ),
        ),
        if (recipe != null) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Ingredients (from recipe)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SliverList.builder(
            itemCount: recipe.items.length,
            itemBuilder: (context, i) {
              final item = recipe.items[i];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(
                    '${item.weightG.round()} g · ${item.kcalPer100g.round()} kcal/100g'),
                trailing: Text('${item.totalKcal.round()} kcal',
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
                  label: const Text('Go to recipe'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.push('/recipes/${recipe.id}/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit recipe'),
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
              label: const Text('Copy to today'),
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
      child: file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : Container(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.restaurant, size: 64, color: AppColors.primary),
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

String _mealTypeLabel(String? type) => switch (type) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      _ => '',
    };
