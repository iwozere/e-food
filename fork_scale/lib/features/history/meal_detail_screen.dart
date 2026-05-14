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

final _mealProvider = FutureProvider.autoDispose.family<Meal?, int>(
  (ref, id) => ref.read(mealsRepositoryProvider).getMeal(id),
);

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
            onPressed: () => context.push('/settings'),
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
      context.push(
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
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _reLog(Meal original) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Re-log this meal?'),
        content: Text(
          'A copy will be saved with today\'s date as '
          '${_mealTypeLabel(Meal.detectTypeFromTime())}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Re-log')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(mealsRepositoryProvider);
    final newMeal = Meal(
      createdAt: DateTime.now(),
      photoPath: original.photoPath,
      notes: original.notes,
      totalKcal: original.totalKcal,
      utensil: original.utensil,
      scaleConf: original.scaleConf,
      modelUsed: original.modelUsed,
      items: original.items,
      mealType: Meal.detectTypeFromTime(),
    );
    final newId = await repo.insertMeal(newMeal);
    if (!mounted) return;
    context.go('/history/$newId');
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
                : _MealDetail(meal: meal, onReLog: () => _reLog(meal)),
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

// ── Analyzed state ─────────────────────────────────────────────────────────────

class _MealDetail extends StatelessWidget {
  final Meal meal;
  final VoidCallback onReLog;
  const _MealDetail({required this.meal, required this.onReLog});

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
              onPressed: onReLog,
              icon: const Icon(Icons.replay),
              label: const Text('Re-log today'),
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
