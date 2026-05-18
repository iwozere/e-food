import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meal.dart';

typedef _MealsFilter = ({String? query, DateTime? day, bool starredOnly});

final _mealsProvider =
    FutureProvider.autoDispose.family<List<Meal>, _MealsFilter>(
  (ref, filter) {
    final day = filter.day;
    return ref.read(mealsRepositoryProvider).getMeals(
          searchQuery: filter.query,
          from: day != null ? DateTime(day.year, day.month, day.day) : null,
          to: day != null
              ? DateTime(day.year, day.month, day.day, 23, 59, 59)
              : null,
          starredOnly: filter.starredOnly,
        );
  },
);

final _dayTotalProvider = FutureProvider.autoDispose<double>((ref) {
  return ref.read(mealsRepositoryProvider).getDayTotalKcal(DateTime.now());
});

final _weeklyKcalProvider = FutureProvider.autoDispose<List<double>>((ref) {
  return ref.read(mealsRepositoryProvider).getWeeklyKcal();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  String? _query;
  DateTime? _selectedDay;
  bool _showStarredOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {
      _query = v.isEmpty ? null : v;
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = (
      query: _query,
      day: _selectedDay,
      starredOnly: _showStarredOnly,
    );
    final mealsAsync = ref.watch(_mealsProvider(filter));
    final dayTotalAsync = ref.watch(_dayTotalProvider);
    final weeklyAsync = ref.watch(_weeklyKcalProvider);
    final goal =
        (ref.watch(dailyGoalProvider).valueOrNull ?? 2000).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Meal History')),
      floatingActionButton: null,
      body: Column(
        children: [
          _DaySummaryBar(dayTotalAsync: dayTotalAsync),
          weeklyAsync.when(
            loading: () => const SizedBox(height: 140),
            error: (_, _) => const SizedBox.shrink(),
            data: (weekly) => _WeeklyChart(
              kcals: weekly,
              goal: goal,
              selectedDay: _selectedDay,
              onDaySelected: (day) => setState(() {
                _selectedDay = day;
                _query = null;
                _searchCtrl.clear();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Starred'),
                  avatar: Icon(
                    _showStarredOnly ? Icons.star : Icons.star_border,
                    size: 16,
                    color: _showStarredOnly ? AppColors.accent : null,
                  ),
                  selected: _showStarredOnly,
                  onSelected: (v) => setState(() => _showStarredOnly = v),
                  selectedColor: AppColors.accent.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.accent,
                  showCheckmark: false,
                ),
                if (_selectedDay != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      DateFormat('EEE, MMM d').format(_selectedDay!),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _selectedDay = null),
                  ),
                ],
              ],
            ),
          ),
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (meals) => meals.isEmpty
                  ? const _EmptyState()
                  : _MealList(
                      meals: meals,
                      onRefresh: () {
                        ref.invalidate(_mealsProvider);
                        ref.invalidate(_dayTotalProvider);
                        ref.invalidate(_weeklyKcalProvider);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly bar chart ──────────────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<double> kcals; // index 0 = 6 days ago, index 6 = today
  final double goal;
  final DateTime? selectedDay;
  final ValueChanged<DateTime?> onDaySelected;

  const _WeeklyChart({
    required this.kcals,
    required this.goal,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final maxKcal = kcals.fold(0.0, (m, v) => v > m ? v : m);
    final chartMax = (maxKcal > goal ? maxKcal : goal) * 1.15;

    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        child: BarChart(
          BarChartData(
            maxY: chartMax > 0 ? chartMax : 2500,
            barGroups: List.generate(7, (i) {
              final isToday = i == 6;
              final d = days[i];
              final sel = selectedDay;
              final isSelected = sel != null &&
                  sel.year == d.year &&
                  sel.month == d.month &&
                  sel.day == d.day;
              final color = isSelected
                  ? AppColors.accent
                  : (isToday && sel == null)
                      ? AppColors.accent.withValues(alpha: 0.75)
                      : AppColors.primary.withValues(alpha: 0.5);
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: kcals[i],
                    color: color,
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
            extraLinesData: goal > 0
                ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: goal,
                        color: AppColors.error.withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: [5, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.subtle),
                          labelResolver: (_) => 'Goal',
                        ),
                      ),
                    ],
                  )
                : ExtraLinesData(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i > 6) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        i == 6 ? 'Today' : DateFormat('E').format(days[i]),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.subtle),
                      ),
                    );
                  },
                ),
              ),
              leftTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: false),
            barTouchData: BarTouchData(
              handleBuiltInTouches: false,
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.spot != null) {
                  final i = response!.spot!.touchedBarGroup.x;
                  final tapped = days[i];
                  final sel = selectedDay;
                  final alreadySelected = sel != null &&
                      sel.year == tapped.year &&
                      sel.month == tapped.month &&
                      sel.day == tapped.day;
                  onDaySelected(alreadySelected ? null : tapped);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Day summary bar ───────────────────────────────────────────────────────────

class _DaySummaryBar extends ConsumerWidget {
  final AsyncValue<double> dayTotalAsync;
  const _DaySummaryBar({required this.dayTotalAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal =
        (ref.watch(dailyGoalProvider).valueOrNull ?? 2000).toDouble();
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

// ── Meal list ─────────────────────────────────────────────────────────────────

class _MealList extends StatelessWidget {
  final List<Meal> meals;
  final VoidCallback onRefresh;
  const _MealList({required this.meals, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: meals.length,
      itemBuilder: (context, i) =>
          _MealTile(meal: meals[i], onRefresh: onRefresh),
    );
  }
}

class _MealTile extends ConsumerWidget {
  final Meal meal;
  final VoidCallback onRefresh;
  const _MealTile({required this.meal, required this.onRefresh});

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
            content: const Text(
                'This will permanently delete the meal and its photo.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) async {
        await ref.read(mealsRepositoryProvider).deleteMeal(meal.id!);
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Meal deleted')));
        }
      },
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context, ref),
        child: ListTile(
          onTap: () async {
                await context.push('/history/${meal.id}');
                if (context.mounted) onRefresh();
              },
          leading: _Thumbnail(path: meal.photoPath, source: meal.source),
          title: Text(
            meal.pending
                ? 'Pending — not yet analyzed'
                : (meal.name ?? _autoName(meal)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: meal.pending
                ? const TextStyle(
                    color: AppColors.subtle, fontStyle: FontStyle.italic)
                : null,
          ),
          subtitle: Text(_subtitle(meal)),
          trailing: meal.pending
              ? const Icon(Icons.schedule, color: AppColors.subtle, size: 20)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await ref
                            .read(mealsRepositoryProvider)
                            .starMeal(meal.id!, starred: !meal.starred);
                        ref.invalidate(_mealsProvider);
                      },
                      child: Icon(
                        meal.starred ? Icons.star : Icons.star_border,
                        size: 16,
                        color: meal.starred
                            ? AppColors.accent
                            : AppColors.subtle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meal.totalKcal.round()} kcal',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _SourceBadge(source: meal.source),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy to today'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'copy') {
      final newId = await ref.read(mealsRepositoryProvider).copyMealToToday(meal);
      ref.invalidate(_mealsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied ${meal.name ?? 'meal'} to today'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.push('/history/$newId'),
            ),
          ),
        );
      }
    } else if (action == 'delete') {
      await ref.read(mealsRepositoryProvider).deleteMeal(meal.id!);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Meal deleted')));
      }
    }
  }

  String _autoName(Meal meal) {
    if (meal.items.isEmpty) return 'Meal';
    final names = meal.items.take(2).map((i) => i.name).join(', ');
    return meal.items.length > 2 ? '$names…' : names;
  }

  String _subtitle(Meal meal) {
    final time = DateFormat('MMM d, h:mm a').format(meal.createdAt);
    if (meal.pending) return time;
    final typeLabel = _mealTypeLabel(meal.mealType);
    return typeLabel.isEmpty ? time : '$typeLabel · $time';
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String path;
  final String source;
  const _Thumbnail({required this.path, this.source = 'camera'});

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
              child: Center(
                child: Text(
                  switch (source) {
                    'barcode' => '🔖',
                    'recipe_portion' => '🍳',
                    _ => '',
                  },
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final label = switch (source) {
      'barcode' => '🔖 Barcode',
      'recipe_portion' => '🍳 Recipe',
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Text(label,
        style: const TextStyle(fontSize: 10, color: AppColors.subtle));
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
          Text('No meals yet',
              style: TextStyle(color: AppColors.subtle, fontSize: 16)),
          SizedBox(height: 8),
          Text('Take a photo to log your first meal',
              style: TextStyle(color: AppColors.subtle, fontSize: 13)),
        ],
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
