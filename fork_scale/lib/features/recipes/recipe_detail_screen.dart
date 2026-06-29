import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/recipe.dart';
import '../../models/recipe_item.dart';
import 'log_portion_sheet.dart';

final _recipeProvider = FutureProvider.autoDispose.family<Recipe?, int>(
  (ref, id) {
    // Refetch automatically after any recipe write (e.g. returning from edit).
    ref.watch(recipesChangesProvider);
    return ref.read(recipesRepositoryProvider).getRecipe(id);
  },
);

class RecipeDetailScreen extends ConsumerWidget {
  final int recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_recipeProvider(recipeId));
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: recipeAsync.value != null
            ? Text(recipeAsync.value!.name)
            : Text(l.recipeDetailFallbackTitle),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (recipeAsync.value != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/recipes/$recipeId/edit'),
              tooltip: l.mealDetailEditRecipe,
            ),
        ],
      ),
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.commonError('$e'))),
        data: (recipe) => recipe == null
            ? Center(child: Text(l.recipeDetailNotFound))
            : _RecipeDetail(
                recipe: recipe,
                onLogPortion: () => _showLogSheet(context, recipe),
                onEdit: () => context.push('/recipes/$recipeId/edit'),
              ),
      ),
    );
  }

  void _showLogSheet(BuildContext context, Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LogPortionSheet(recipe: recipe),
    );
  }
}

class _RecipeDetail extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onLogPortion;
  final VoidCallback onEdit;
  const _RecipeDetail({
    required this.recipe,
    required this.onLogPortion,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        if (recipe.photoPath != null)
          SliverToBoxAdapter(child: _PhotoHeader(path: recipe.photoPath!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _Chip(
                    label: l.recipeKcalPer100g(recipe.kcalPer100g.round()),
                    color: AppColors.accent,
                  ),
                  _Chip(
                    label: l.recipeYield(recipe.yieldG.round()),
                    color: AppColors.primary,
                  ),
                  if (recipe.totalProteinG != null)
                    _Chip(
                      label: '${l.macroAbbrevProtein} ${l.gramsValue(recipe.totalProteinG!.round())}',
                      color: AppColors.primary,
                    ),
                  if (recipe.totalCarbsG != null)
                    _Chip(
                      label: '${l.macroAbbrevCarbs} ${l.gramsValue(recipe.totalCarbsG!.round())}',
                      color: AppColors.primary,
                    ),
                  if (recipe.totalFatG != null)
                    _Chip(
                      label: '${l.macroAbbrevFat} ${l.gramsValue(recipe.totalFatG!.round())}',
                      color: AppColors.primary,
                    ),
                ]),
                if (recipe.notes != null && recipe.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(recipe.notes!,
                      style: const TextStyle(color: AppColors.subtle)),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(l.mealDetailIngredients,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        SliverList.builder(
          itemCount: recipe.items.length,
          itemBuilder: (context, i) {
            final item = recipe.items[i];
            final macroLine = _macroLine(l, item);
            return ListTile(
              title: Text(item.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.mealDetailItemSubtitle(
                      item.weightG.round(), item.kcalPer100g.round())),
                  if (macroLine != null)
                    Text(macroLine,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.subtle)),
                ],
              ),
              trailing: Text(
                l.kcalValue(item.totalKcal.round()),
                style: const TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onLogPortion,
                    icon: const Icon(Icons.restaurant),
                    label: Text(l.recipeLogPortion),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.mealDetailEditRecipe),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Compact "P 18 g · C 90 g · F 12 g" line for an ingredient's macro totals.
// Returns null when the item carries no macro data.
String? _macroLine(AppLocalizations l, RecipeItem item) {
  final parts = <String>[];
  if (item.totalProteinG != null) {
    parts.add('${l.macroAbbrevProtein} ${l.gramsValue(item.totalProteinG!.round())}');
  }
  if (item.totalCarbsG != null) {
    parts.add('${l.macroAbbrevCarbs} ${l.gramsValue(item.totalCarbsG!.round())}');
  }
  if (item.totalFatG != null) {
    parts.add('${l.macroAbbrevFat} ${l.gramsValue(item.totalFatG!.round())}');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

class _PhotoHeader extends StatelessWidget {
  final String path;
  const _PhotoHeader({required this.path});

  @override
  Widget build(BuildContext context) {
    final f = File(path);
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Image.file(
        f,
        fit: BoxFit.cover,
        cacheWidth: 800,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.primary.withValues(alpha: 0.1),
          child: const Center(child: Text('🍳', style: TextStyle(fontSize: 64))),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}
