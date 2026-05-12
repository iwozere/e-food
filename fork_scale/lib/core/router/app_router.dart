import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/capture/capture_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/meal_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../models/analysis_result.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const CaptureScreen(),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final result = state.extra as AnalysisResult;
          return ResultsScreen(result: result);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (_, _) => const HistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return MealDetailScreen(mealId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
