import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/recipe.dart';

final _recipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) {
  // Refetch automatically after any recipe write.
  ref.watch(recipesChangesProvider);
  return ref.read(recipesRepositoryProvider).getAllRecipes();
});

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(_recipesProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.recipesTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recipes/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.commonError('$e'))),
        data: (recipes) => recipes.isEmpty
            ? _EmptyState(onNewRecipe: () => context.push('/recipes/new'))
            : _RecipeGrid(recipes: recipes),
      ),
    );
  }
}

class _RecipeGrid extends StatelessWidget {
  final List<Recipe> recipes;
  const _RecipeGrid({required this.recipes});

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
      itemBuilder: (context, i) => _RecipeCard(recipe: recipes[i]),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
                    l.recipesCardSubtitle(
                        recipe.kcalPer100g.round(), recipe.yieldG.round()),
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
    final l = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.actionEdit),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(l.recipesDuplicate),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l.actionDelete, style: const TextStyle(color: AppColors.error)),
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
          name: l.recipesCopySuffix(recipe.name),
          createdAt: now,
          updatedAt: now,
          items: recipe.items
              .map((i) => i.copyWith(id: null, recipeId: null))
              .toList(),
        );
        await repo.insertRecipe(copy);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l.recipesDeleteTitle),
            content: Text(l.recipesDeleteBody(recipe.name)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l.actionCancel)),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l.actionDelete,
                    style: const TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await ref.read(recipesRepositoryProvider).deleteRecipe(recipe.id!);
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
      return Image.file(
        File(path!),
        fit: BoxFit.cover,
        cacheWidth: 200,
        errorBuilder: (_, _, _) => _placeholder,
      );
    }
    return _placeholder;
  }

  static final _placeholder = Container(
    color: AppColors.primary.withValues(alpha: 0.08),
    child: const Center(child: Text('🍳', style: TextStyle(fontSize: 40))),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNewRecipe;
  const _EmptyState({required this.onNewRecipe});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍳', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(l.recipesEmptyTitle,
              style: const TextStyle(fontSize: 16, color: AppColors.subtle)),
          const SizedBox(height: 8),
          Text(l.recipesEmptySubtitle,
              style: const TextStyle(fontSize: 13, color: AppColors.subtle)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onNewRecipe,
            icon: const Icon(Icons.add),
            label: Text(l.recipesNew),
          ),
        ],
      ),
    );
  }
}
