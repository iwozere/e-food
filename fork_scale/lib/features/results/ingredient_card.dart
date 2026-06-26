import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/decimal_input_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/meal_item.dart';

class IngredientCard extends StatefulWidget {
  final MealItem item;
  final ValueChanged<MealItem> onChanged;
  final VoidCallback onDelete;
  final bool isEdited;

  const IngredientCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
    this.isEdited = false,
  });

  @override
  State<IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<IngredientCard> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;
  late bool _macrosExpanded;

  static String _fmt(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _weightCtrl = TextEditingController(text: widget.item.weightG.toStringAsFixed(0));
    _kcalCtrl = TextEditingController(text: widget.item.kcalPer100g.toStringAsFixed(0));
    _proteinCtrl = TextEditingController(text: _fmt(widget.item.proteinPer100g));
    _carbsCtrl = TextEditingController(text: _fmt(widget.item.carbsPer100g));
    _fatCtrl = TextEditingController(text: _fmt(widget.item.fatPer100g));
    _macrosExpanded = widget.item.proteinPer100g != null ||
        widget.item.carbsPer100g != null ||
        widget.item.fatPer100g != null;
  }

  @override
  void didUpdateWidget(IngredientCard old) {
    super.didUpdateWidget(old);
    final n = widget.item;
    if (n.name != old.item.name) _nameCtrl.text = n.name;
    if (n.weightG != old.item.weightG) _weightCtrl.text = n.weightG.toStringAsFixed(0);
    if (n.kcalPer100g != old.item.kcalPer100g) _kcalCtrl.text = n.kcalPer100g.toStringAsFixed(0);
    if (n.proteinPer100g != old.item.proteinPer100g) _proteinCtrl.text = _fmt(n.proteinPer100g);
    if (n.carbsPer100g != old.item.carbsPer100g) _carbsCtrl.text = _fmt(n.carbsPer100g);
    if (n.fatPer100g != old.item.fatPer100g) _fatCtrl.text = _fmt(n.fatPer100g);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  MealItem get _current => widget.item;

  // Rebuilds the item from the macro controllers. Built explicitly (not via
  // copyWith) so a cleared field becomes null ("unknown") rather than sticking.
  void _emitMacros() {
    widget.onChanged(MealItem(
      id: _current.id,
      mealId: _current.mealId,
      name: _current.name,
      weightG: _current.weightG,
      kcalPer100g: _current.kcalPer100g,
      totalKcal: _current.totalKcal,
      sortOrder: _current.sortOrder,
      usdaMatched: _current.usdaMatched,
      proteinPer100g: double.tryParse(_proteinCtrl.text),
      carbsPer100g: double.tryParse(_carbsCtrl.text),
      fatPer100g: double.tryParse(_fatCtrl.text),
    ));
  }

  void _onNameChanged(String v) =>
      widget.onChanged(_current.copyWith(name: v));

  void _onWeightChanged(String v) {
    final w = double.tryParse(v) ?? _current.weightG;
    widget.onChanged(_current.copyWith(weightG: w, totalKcal: w / 100 * _current.kcalPer100g));
  }

  void _onKcalChanged(String v) {
    final k = double.tryParse(v) ?? _current.kcalPer100g;
    widget.onChanged(
      _current.copyWith(
        kcalPer100g: k,
        totalKcal: _current.weightG / 100 * k,
        usdaMatched: false,
      ),
    );
  }

  void _stepWeight(int delta) {
    final newWeight = (_current.weightG + delta).clamp(0, 9999).toDouble();
    _weightCtrl.text = newWeight.toStringAsFixed(0);
    widget.onChanged(
        _current.copyWith(weightG: newWeight, totalKcal: newWeight / 100 * _current.kcalPer100g));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                    decoration: InputDecoration(
                      labelText: l.ingredientNameLabel,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.isEdited)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, size: 10, color: AppColors.accent),
                        const SizedBox(width: 2),
                        Text(l.ingredientEdited,
                            style: const TextStyle(fontSize: 10, color: AppColors.accent)),
                      ],
                    ),
                  ),
                if (!_current.usdaMatched && !widget.isEdited)
                  Tooltip(
                    message: l.ingredientAiValueTooltip,
                    child: const Icon(Icons.science_outlined, size: 16, color: AppColors.subtle),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onDelete,
                  tooltip: l.ingredientRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: l.ingredientWeight,
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
                    label: l.ingredientKcalPer100g,
                    controller: _kcalCtrl,
                    onChanged: _onKcalChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Macros (per 100g) — collapsible, optional
            InkWell(
              onTap: () => setState(() => _macrosExpanded = !_macrosExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _macrosExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18,
                      color: AppColors.subtle,
                    ),
                    const SizedBox(width: 2),
                    Text(l.ingredientMacros,
                        style: const TextStyle(fontSize: 12, color: AppColors.subtle)),
                  ],
                ),
              ),
            ),
            if (_macrosExpanded)
              Row(children: [
                Expanded(
                  child: _LabeledField(
                    label: l.ingredientProtein,
                    controller: _proteinCtrl,
                    onChanged: (_) => _emitMacros(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabeledField(
                    label: l.ingredientCarbs,
                    controller: _carbsCtrl,
                    onChanged: (_) => _emitMacros(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabeledField(
                    label: l.ingredientFat,
                    controller: _fatCtrl,
                    onChanged: (_) => _emitMacros(),
                  ),
                ),
              ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                l.ingredientKcalTotal(totalKcal.round()),
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
          inputFormatters: const [DecimalInputFormatter()],
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
    final l = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(icon, size: 18, color: AppColors.primary),
      onPressed: onTap,
      tooltip: icon == Icons.add ? l.ingredientIncrease : l.ingredientDecrease,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
