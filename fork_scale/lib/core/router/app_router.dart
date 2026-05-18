import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../features/barcode/barcode_result_screen.dart';
import '../../features/barcode/barcode_scanner_screen.dart';
import '../../features/capture/capture_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/history/meal_detail_screen.dart';
import '../../features/history/meal_edit_screen.dart';
import '../../features/recipes/recipe_detail_screen.dart';
import '../../features/recipes/recipe_editor_screen.dart';
import '../../features/recipes/recipes_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../models/analysis_result.dart';
import '../../models/meal.dart';
import '../../models/recipe.dart';
import '../theme/app_theme.dart';

// Scoped provider used by _MealEditLoader; family keeps it per-id.
final _editMealProvider =
    FutureProvider.autoDispose.family<Meal?, int>((ref, id) {
  return ref.read(mealsRepositoryProvider).getMeal(id);
});

// Scoped provider used by _RecipeEditorLoader; family keeps it per-id.
final _editRecipeProvider =
    FutureProvider.autoDispose.family<Recipe?, int>((ref, id) {
  return ref.read(recipesRepositoryProvider).getRecipe(id);
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ── Full-screen routes (no bottom nav) ────────────────────────────────
      GoRoute(
        path: '/results',
        builder: (context, state) {
          final result = state.extra as AnalysisResult;
          return ResultsScreen(result: result);
        },
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final forRecipe = extra?['forRecipe'] as bool? ?? false;
          return BarcodeScannerScreen(forRecipe: forRecipe);
        },
      ),
      GoRoute(
        path: '/barcode-result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final barcode = extra['barcode'] as String;
          final forRecipe = extra['forRecipe'] as bool? ?? false;
          return BarcodeResultScreen(barcode: barcode, forRecipe: forRecipe);
        },
      ),
      GoRoute(
        path: '/history/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _MealEditLoader(mealId: id);
        },
      ),
      GoRoute(
        path: '/history/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return MealDetailScreen(mealId: id);
        },
      ),
      // /recipes/new must come before /recipes/:id to avoid id='new'
      GoRoute(
        path: '/recipes/new',
        builder: (context, state) {
          final prefill = state.extra as Map<String, dynamic>?;
          return RecipeEditorScreen(prefill: prefill);
        },
      ),
      GoRoute(
        path: '/recipes/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return _RecipeEditorLoader(recipeId: id);
        },
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeDetailScreen(recipeId: id);
        },
      ),
      // ── Shell route (bottom nav) ──────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _ScaffoldWithNav(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const CaptureScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/recipes',
              builder: (_, _) => const RecipesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
              builder: (_, _) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

// ── Shell scaffold with bottom navigation bar ─────────────────────────────────

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        backgroundColor: _navBgColor(shell.currentIndex),
        indicatorColor: AppColors.accent.withValues(alpha: 0.25),
        destinations: _destinations(shell.currentIndex),
      ),
    );
  }

  Color _navBgColor(int index) =>
      index == 0 ? Colors.black : AppColors.surface;

  List<NavigationDestination> _destinations(int activeIndex) {
    final iconColor = activeIndex == 0 ? Colors.white70 : null;
    return [
      NavigationDestination(
        icon: Icon(Icons.camera_alt_outlined, color: iconColor),
        selectedIcon: Icon(Icons.camera_alt,
            color: activeIndex == 0 ? AppColors.accent : null),
        label: 'Log',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_book_outlined, color: iconColor),
        selectedIcon: Icon(Icons.menu_book,
            color: activeIndex == 1 ? AppColors.primary : null),
        label: 'Recipes',
      ),
      NavigationDestination(
        icon: Icon(Icons.history, color: iconColor),
        selectedIcon: Icon(Icons.history,
            color: activeIndex == 2 ? AppColors.primary : null),
        label: 'History',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined, color: iconColor),
        selectedIcon: Icon(Icons.settings,
            color: activeIndex == 3 ? AppColors.primary : null),
        label: 'Settings',
      ),
    ];
  }
}

// ── Loader for meal edit route ────────────────────────────────────────────────

class _MealEditLoader extends ConsumerWidget {
  final int mealId;
  const _MealEditLoader({required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealAsync = ref.watch(_editMealProvider(mealId));
    return mealAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (meal) => meal == null
          ? const Scaffold(body: Center(child: Text('Meal not found')))
          : MealEditScreen(meal: meal),
    );
  }
}

// ── Loader for recipe edit route ──────────────────────────────────────────────

class _RecipeEditorLoader extends ConsumerWidget {
  final int recipeId;
  const _RecipeEditorLoader({required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_editRecipeProvider(recipeId));
    return recipeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (recipe) => recipe == null
          ? const Scaffold(body: Center(child: Text('Recipe not found')))
          : RecipeEditorScreen(existing: recipe),
    );
  }
}
