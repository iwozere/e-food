import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../models/meal_item.dart';

class IngredientCard extends StatefulWidget {
  final MealItem item;
  final ValueChanged<MealItem> onChanged;
  final VoidCallback onDelete;

  const IngredientCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<IngredientCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _kcalCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _weightCtrl = TextEditingController(text: widget.item.weightG.toStringAsFixed(0));
    _kcalCtrl = TextEditingController(text: widget.item.kcalPer100g.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _kcalCtrl.dispose();
    super.dispose();
  }

  MealItem get _current => widget.item;

  void _onNameChanged(String v) =>
      widget.onChanged(_current.copyWith(name: v));

  void _onWeightChanged(String v) {
    final w = double.tryParse(v) ?? _current.weightG;
    widget.onChanged(_current.copyWith(weightG: w, totalKcal: w / 100 * _current.kcalPer100g));
  }

  void _onKcalChanged(String v) {
    final k = double.tryParse(v) ?? _current.kcalPer100g;
    widget.onChanged(
        _current.copyWith(kcalPer100g: k, totalKcal: _current.weightG / 100 * k));
  }

  void _stepWeight(int delta) {
    final newWeight = (_current.weightG + delta).clamp(0, 9999).toDouble();
    _weightCtrl.text = newWeight.toStringAsFixed(0);
    widget.onChanged(
        _current.copyWith(weightG: newWeight, totalKcal: newWeight / 100 * _current.kcalPer100g));
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _current.computedKcal;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    onChanged: _onNameChanged,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: const InputDecoration(
                      labelText: 'Food item',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (!_current.usdaMatched)
                  Tooltip(
                    message: 'Calorie value from AI (not USDA database)',
                    child: Icon(Icons.science_outlined, size: 16, color: AppColors.subtle),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onDelete,
                  tooltip: 'Remove item',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'Weight (g)',
                    controller: _weightCtrl,
                    onChanged: _onWeightChanged,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepButton(icon: Icons.remove, onTap: () => _stepWeight(-10)),
                        _StepButton(icon: Icons.add, onTap: () => _stepWeight(10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabeledField(
                    label: 'kcal / 100g',
                    controller: _kcalCtrl,
                    onChanged: _onKcalChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${totalKcal.round()} kcal',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget? suffix;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.subtle)),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(suffixIcon: suffix),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}
