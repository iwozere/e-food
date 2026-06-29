import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

final _streakProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(mealsRepositoryProvider).getCurrentStreak(),
);

final _avgKcal7Provider = FutureProvider.autoDispose<double>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyKcal(days: 7),
);

final _avgKcal30Provider = FutureProvider.autoDispose<double>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyKcal(days: 30),
);

typedef _Macros = ({double? protein, double? carbs, double? fat});

final _avgMacros7Provider = FutureProvider.autoDispose<_Macros>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyMacros(days: 7),
);

final _avgMacros30Provider = FutureProvider.autoDispose<_Macros>(
  (ref) => ref.read(mealsRepositoryProvider).getAvgDailyMacros(days: 30),
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
    final streak = ref.watch(_streakProvider).value ?? 0;
    final avg7 = ref.watch(_avgKcal7Provider).value;
    final avg30 = ref.watch(_avgKcal30Provider).value;
    final topMeals = ref.watch(_topMealsProvider).value ?? [];
    final daysOver = ref.watch(_daysOverGoalProvider).value;
    final daysLogged = ref.watch(_daysWithMealsProvider).value;
    final macros7 = ref.watch(_avgMacros7Provider).value;
    final macros30 = ref.watch(_avgMacros30Provider).value;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.insightsTitle)),
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
                      Text(
                        l.insightsCurrentStreak,
                        style: const TextStyle(color: AppColors.subtle, fontSize: 12),
                      ),
                      Text(
                        streak == 0
                            ? l.insightsNoStreak
                            : l.insightsStreakDays(streak),
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
                  _SectionLabel(l.insightsAvgIntake),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: l.insightsLast7,
                          value: avg7 != null ? l.kcalValue(avg7.round()) : '—',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: l.insightsLast30,
                          value: avg30 != null ? l.kcalValue(avg30.round()) : '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Average daily macros
          if (_hasAnyMacro(macros7) || _hasAnyMacro(macros30))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(l.insightsAvgMacros),
                    const SizedBox(height: 12),
                    _MacroRow(label: l.insightsLast7, macros: macros7),
                    const SizedBox(height: 10),
                    _MacroRow(label: l.insightsLast30, macros: macros30),
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
                  _SectionLabel(l.insightsThisWeek),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: l.insightsDaysLogged,
                          value: daysLogged != null ? l.insightsOutOf7(daysLogged) : '—',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          label: l.insightsOverGoal,
                          value: daysOver != null ? l.insightsOutOf7(daysOver) : '—',
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
                    _SectionLabel(l.insightsTopMeals),
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
                                  l.insightsCount(e.value.count),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l.insightsApproxKcal(e.value.avgKcal.round()),
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

bool _hasAnyMacro(_Macros? m) =>
    m != null && (m.protein != null || m.carbs != null || m.fat != null);

class _MacroRow extends StatelessWidget {
  final String label;
  final _Macros? macros;
  const _MacroRow({required this.label, required this.macros});

  String _g(AppLocalizations l, double? v) =>
      v != null ? l.gramsValue(v.round()) : '—';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.subtle)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _StatBox(
                  label: l.macroProtein,
                  value: _g(l, macros?.protein),
                  color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(label: l.macroCarbs, value: _g(l, macros?.carbs)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                  label: l.macroFat,
                  value: _g(l, macros?.fat),
                  color: AppColors.error),
            ),
          ],
        ),
      ],
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
