import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';
import '../../models/meal.dart';
import '../../models/recipe.dart';
import '../../widgets/meal_type_selector.dart';

class LogPortionSheet extends ConsumerStatefulWidget {
  final Recipe recipe;
  const LogPortionSheet({super.key, required this.recipe});

  @override
  ConsumerState<LogPortionSheet> createState() => _LogPortionSheetState();
}

class _LogPortionSheetState extends ConsumerState<LogPortionSheet> {
  late double _portionG;
  late TextEditingController _ctrl;
  MealType? _mealType;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _portionG = (widget.recipe.yieldG / 2).clamp(25, 9999);
    _ctrl = TextEditingController(text: _portionG.toStringAsFixed(0));
    _mealType = Meal.detectTypeFromTime();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalKcal => _portionG / 100 * widget.recipe.kcalPer100g;

  // Scales a recipe-level macro total (absolute grams over the full yield) down
  // to this portion. Null when the recipe has no data for that macro.
  double? _scaleMacro(double? recipeTotal) {
    final y = widget.recipe.yieldG;
    if (recipeTotal == null || y <= 0) return null;
    return _portionG * recipeTotal / y;
  }

  void _step(int delta) {
    final v = (_portionG + delta).clamp(0, 9999).toDouble();
    setState(() {
      _portionG = v;
      _ctrl.text = v.toStringAsFixed(0);
    });
  }

  Future<void> _log() async {
    setState(() => _saving = true);
    try {
      final meal = Meal(
        createdAt: DateTime.now(),
        photoPath: widget.recipe.photoPath ?? '',
        name: widget.recipe.name,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        totalKcal: _totalKcal,
        utensil: Utensil.fork,
        modelUsed: 'recipe',
        mealType: _mealType,
        source: MealSource.recipePortion,
        recipeId: widget.recipe.id,
        portionG: _portionG,
        totalProteinG: _scaleMacro(widget.recipe.totalProteinG),
        totalCarbsG: _scaleMacro(widget.recipe.totalCarbsG),
        totalFatG: _scaleMacro(widget.recipe.totalFatG),
      );
      await ref.read(mealsRepositoryProvider).insertMeal(meal);
      if (!mounted) return;
      Navigator.pop(context);
      context.go('/history');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${r.kcalPer100g.round()} kcal/100g',
                style: const TextStyle(color: AppColors.subtle)),
            const SizedBox(height: 20),
            const Text('How much did you eat?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _step(-25),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _ctrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(suffixText: 'g'),
                    onChanged: (v) {
                      setState(() => _portionG = double.tryParse(v) ?? _portionG);
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => _step(25),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_totalKcal.round()} kcal',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            MealTypeSelector(
              value: _mealType,
              onChanged: (t) => setState(() => _mealType = t),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _log,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Log meal'),
            ),
          ],
        ),
      ),
    );
  }
}

