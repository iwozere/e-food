import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meal.dart';

final _mealProvider = FutureProvider.autoDispose.family<Meal?, int>(
  (ref, id) => ref.read(mealsRepositoryProvider).getMeal(id),
);

class MealDetailScreen extends ConsumerWidget {
  final int mealId;
  const MealDetailScreen({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealAsync = ref.watch(_mealProvider(mealId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Detail'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: mealAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (meal) => meal == null
            ? const Center(child: Text('Meal not found'))
            : _MealDetail(meal: meal),
      ),
    );
  }
}

class _MealDetail extends StatelessWidget {
  final Meal meal;
  const _MealDetail({required this.meal});

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
                Row(
                  children: [
                    _InfoChip(
                      label: '${meal.totalKcal.round()} kcal',
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      label: meal.utensil == 'fork' ? '🍴 Fork' : '🔪 Knife',
                      color: AppColors.primary,
                    ),
                    if (meal.scaleConf != null) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        label: 'Conf: ${meal.scaleConf}',
                        color: _confColor(meal.scaleConf!),
                      ),
                    ],
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
              subtitle: Text('${item.weightG.round()} g · ${item.kcalPer100g.round()} kcal/100g'),
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
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
              color: AppColors.primary.withValues(alpha:0.1),
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
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
