import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';

final _recipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) {
  return ref.read(recipesRepositoryProvider).getAllRecipes();
});

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(_recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recipes/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (recipes) => recipes.isEmpty
            ? const _EmptyState()
            : _RecipeGrid(
                recipes: recipes,
                onRefresh: () => ref.invalidate(_recipesProvider),
              ),
      ),
    );
  }
}

class _RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final VoidCallback onRefresh;
  const _RecipeGrid({required this.recipes, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, i) =>
          _RecipeCard(recipe: recipes[i], onRefresh: onRefresh),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onRefresh;
  const _RecipeCard({required this.recipe, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/recipes/${recipe.id}'),
      onLongPress: () => _showContextMenu(context, ref),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _RecipePhoto(path: recipe.photoPath)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipe.kcalPer100g.round()} kcal/100g · ${recipe.yieldG.round()} g',
                    style: const TextStyle(fontSize: 11, color: AppColors.subtle),
                  ),
                ],
              ),
            ),
          ],
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () => Navigator.pop(context, 'duplicate'),
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

    switch (action) {
      case 'edit':
        context.push('/recipes/${recipe.id}/edit');
      case 'duplicate':
        final repo = ref.read(recipesRepositoryProvider);
        final now = DateTime.now();
        final copy = recipe.copyWith(
          id: null,
          name: '${recipe.name} (copy)',
          createdAt: now,
          updatedAt: now,
          items: recipe.items
              .map((i) => i.copyWith(id: null, recipeId: null))
              .toList(),
        );
        await repo.insertRecipe(copy);
        onRefresh();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete recipe?'),
            content: Text('Delete "${recipe.name}"?'),
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
        if (confirmed == true && context.mounted) {
          await ref.read(recipesRepositoryProvider).deleteRecipe(recipe.id!);
          onRefresh();
        }
    }
  }
}

class _RecipePhoto extends StatelessWidget {
  final String? path;
  const _RecipePhoto({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      final f = File(path!);
      if (f.existsSync()) {
        return Image.file(f, fit: BoxFit.cover);
      }
    }
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Text('🍳', style: TextStyle(fontSize: 40)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍳', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No recipes yet',
              style: TextStyle(fontSize: 16, color: AppColors.subtle)),
          const SizedBox(height: 8),
          const Text('Tap + to build your first recipe',
              style: TextStyle(fontSize: 13, color: AppColors.subtle)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/recipes/new'),
            icon: const Icon(Icons.add),
            label: const Text('New recipe'),
          ),
        ],
      ),
    );
  }
}
