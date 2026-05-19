import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';

final _streakProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(mealsRepositoryProvider).getCurrentStreak(),
);

final _avgKcal7Provider = FutureProvider.autoDispose<double>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyKcal(days: 7),
);

final _avgKcal30Provider = FutureProvider.autoDispose<double>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyKcal(days: 30),
);

final _topMealsProvider =
    FutureProvider.autoDispose<List<({String name, int count, double avgKcal})>>(
  (ref) => ref.read(mealsRepositoryProvider).getTopMeals(limit: 5),
);

final _daysOverGoalProvider = FutureProvider.autoDispose<int>((ref) async {
  final goal = (await ref.watch(dailyGoalProvider.future)).toDouble();
  return ref.read(mealsRepositoryProvider).getDaysOverGoal(goalKcal: goal, days: 7);
});

final _daysWithMealsProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(mealsRepositoryProvider).getDaysWithMeals(days: 7),
);

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(_streakProvider).valueOrNull ?? 0;
    final avg7 = ref.watch(_avgKcal7Provider).valueOrNull;
    final avg30 = ref.watch(_avgKcal30Provider).valueOrNull;
    final topMeals = ref.watch(_topMealsProvider).valueOrNull ?? [];
    final daysOver = ref.watch(_daysOverGoalProvider).valueOrNull;
    final daysLogged = ref.watch(_daysWithMealsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Streak
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current streak',
                        style: TextStyle(color: AppColors.subtle, fontSize: 12),
                      ),
                      Text(
                        streak == 0
                            ? 'No streak yet'
                            : '$streak day${streak == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Averages
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('AVERAGE DAILY INTAKE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Last 7 days',
                          value: avg7 != null ? '${avg7.round()} kcal' : '—',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: 'Last 30 days',
                          value: avg30 != null ? '${avg30.round()} kcal' : '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // This week
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('THIS WEEK'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'Days logged',
                          value: daysLogged != null ? '$daysLogged / 7' : '—',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: 'Over goal',
                          value: daysOver != null ? '$daysOver / 7' : '—',
                          color: (daysOver ?? 0) > 3
                              ? AppColors.error
                              : AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top meals
          if (topMeals.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('MOST LOGGED MEALS'),
                    const SizedBox(height: 8),
                    ...topMeals.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Text(
                                    '${e.key + 1}.',
                                    style: const TextStyle(
                                      color: AppColors.subtle,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.value.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${e.value.count}×',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '~${e.value.avgKcal.round()} kcal',
                                  style: const TextStyle(
                                    color: AppColors.subtle,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.subtle,
        letterSpacing: 1,
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
