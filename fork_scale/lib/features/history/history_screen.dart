import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meal.dart';

final _mealsProvider = FutureProvider.autoDispose.family<List<Meal>, String?>(
  (ref, query) => ref.read(mealsRepositoryProvider).getMeals(searchQuery: query),
);

final _dayTotalProvider = FutureProvider.autoDispose<double>((ref) {
  return ref.read(mealsRepositoryProvider).getDayTotalKcal(DateTime.now());
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() => _query = v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(_mealsProvider(_query));
    final dayTotalAsync = ref.watch(_dayTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.camera_alt),
      ),
      body: Column(
        children: [
          _DaySummaryBar(dayTotalAsync: dayTotalAsync),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search meals…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: mealsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (meals) => meals.isEmpty
                  ? const _EmptyState()
                  : _MealList(meals: meals, onDeleted: () => ref.invalidate(_mealsProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySummaryBar extends ConsumerWidget {
  final AsyncValue<double> dayTotalAsync;
  const _DaySummaryBar({required this.dayTotalAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = (ref.watch(dailyGoalProvider).valueOrNull ?? 2000).toDouble();
    final total = dayTotalAsync.valueOrNull ?? 0.0;
    final fraction = (total / goal).clamp(0.0, 1.0);
    final overGoal = total > goal;

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '${total.round()} / ${goal.round()} kcal',
                style: TextStyle(
                  color: overGoal ? AppColors.error : AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: overGoal ? AppColors.error : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealList extends StatelessWidget {
  final List<Meal> meals;
  final VoidCallback onDeleted;
  const _MealList({required this.meals, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: meals.length,
      itemBuilder: (context, i) => _MealTile(meal: meals[i], onDeleted: onDeleted),
    );
  }
}

class _MealTile extends ConsumerWidget {
  final Meal meal;
  final VoidCallback onDeleted;
  const _MealTile({required this.meal, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete meal?'),
            content: const Text('This will permanently delete the meal and its photo.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) async {
        final repo = ref.read(mealsRepositoryProvider);
        await repo.deleteMeal(meal.id!);
        onDeleted();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal deleted')),
          );
        }
      },
      child: ListTile(
        onTap: () => context.push('/history/${meal.id}'),
        leading: _Thumbnail(path: meal.photoPath),
        title: Text(
          meal.name ?? _autoName(meal),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateFormat('MMM d, h:mm a').format(meal.createdAt)),
        trailing: Text(
          '${meal.totalKcal.round()} kcal',
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _autoName(Meal meal) {
    if (meal.items.isEmpty) return 'Meal';
    final names = meal.items.take(2).map((i) => i.name).join(', ');
    return meal.items.length > 2 ? '$names…' : names;
  }
}

class _Thumbnail extends StatelessWidget {
  final String path;
  const _Thumbnail({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: file.existsSync()
          ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover)
          : Container(
              width: 56,
              height: 56,
              color: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.restaurant, color: AppColors.primary),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: AppColors.subtle),
          SizedBox(height: 16),
          Text('No meals yet', style: TextStyle(color: AppColors.subtle, fontSize: 16)),
          SizedBox(height: 8),
          Text('Take a photo to log your first meal',
              style: TextStyle(color: AppColors.subtle, fontSize: 13)),
        ],
      ),
    );
  }
}
