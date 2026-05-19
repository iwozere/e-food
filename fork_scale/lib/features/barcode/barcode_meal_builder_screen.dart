import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meal.dart';
import '../../models/meal_item.dart';
import '../history/history_providers.dart';

class _Item {
  String name;
  double weightG;
  double kcalPer100g;
  final String? barcode;

  _Item({
    required this.name,
    required this.weightG,
    required this.kcalPer100g,
    this.barcode,
  });

  double get totalKcal => weightG / 100 * kcalPer100g;
}

class BarcodeMealBuilderScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialItem;
  const BarcodeMealBuilderScreen({super.key, this.initialItem});

  @override
  ConsumerState<BarcodeMealBuilderScreen> createState() =>
      _BarcodeMealBuilderScreenState();
}

class _BarcodeMealBuilderScreenState
    extends ConsumerState<BarcodeMealBuilderScreen> {
  late final List<_Item> _items;
  final _notesCtrl = TextEditingController();
  String? _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = Meal.detectTypeFromTime();
    final init = widget.initialItem;
    _items = init != null
        ? [
            _Item(
              name: init['name'] as String? ?? '',
              weightG: (init['weightG'] as double?) ?? 100.0,
              kcalPer100g: (init['kcalPer100g'] as double?) ?? 0.0,
              barcode: init['barcode'] as String?,
            ),
          ]
        : [];
    if (init?['mealType'] is String) {
      _mealType = init!['mealType'] as String;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalKcal => _items.fold(0.0, (s, i) => s + i.totalKcal);

  Future<void> _scanItem() async {
    final result = await context.push<Map<String, dynamic>?>(
      '/scan',
      extra: {'forRecipe': true},
    );
    if (result != null && mounted) {
      setState(() {
        _items.add(_Item(
          name: result['name'] as String? ?? '',
          weightG: (result['weightG'] as double?) ?? 100.0,
          kcalPer100g: (result['kcalPer100g'] as double?) ?? 0.0,
          barcode: result['barcode'] as String?,
        ));
      });
    }
  }

  Future<void> _addManually() async {
    final result = await showModalBottomSheet<_Item>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ManualItemSheet(),
    );
    if (result != null && mounted) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _logMeal() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item first')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final names = _items.take(2).map((i) => i.name).join(', ');
      final mealName = _items.length > 2 ? '$names…' : names;

      final meal = Meal(
        createdAt: DateTime.now(),
        photoPath: '',
        name: mealName,
        totalKcal: _totalKcal,
        utensil: 'fork',
        modelUsed: 'barcode',
        mealType: _mealType,
        source: 'barcode',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        items: _items
            .map((i) => MealItem(
                  name: i.name,
                  weightG: i.weightG,
                  kcalPer100g: i.kcalPer100g,
                  totalKcal: i.totalKcal,
                ))
            .toList(),
      );
      await ref.read(mealsRepositoryProvider).insertMeal(meal);
      if (!mounted) return;
      ref.invalidate(historyMealsProvider);
      ref.invalidate(historyDayTotalProvider);
      ref.invalidate(historyWeeklyKcalProvider);
      context.go('/history');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build meal'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._items.asMap().entries.map(
                      (e) => _ItemCard(
                        item: e.value,
                        onAmountChanged: (v) =>
                            setState(() => e.value.weightG = v),
                        onDelete: () =>
                            setState(() => _items.removeAt(e.key)),
                      ),
                    ),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No items yet — scan a barcode or add manually',
                        style: TextStyle(color: AppColors.subtle),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanItem,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan barcode'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addManually,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Add manually'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _MealTypeChips(
                  current: _mealType,
                  onChanged: (t) => setState(() => _mealType = t),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_items.length} item${_items.length == 1 ? '' : 's'}',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${_totalKcal.round()} kcal total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _logMeal,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Log meal'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  final _Item item;
  final ValueChanged<double> onAmountChanged;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.onAmountChanged,
    required this.onDelete,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.item.weightG.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final v = (widget.item.weightG + delta).clamp(1, 9999).toDouble();
    _ctrl.text = v.toStringAsFixed(0);
    widget.onAmountChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _step(-10),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _ctrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            suffixText: 'g',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                          ),
                          onChanged: (v) {
                            final val = double.tryParse(v);
                            if (val != null && val > 0) {
                              widget.onAmountChanged(val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _step(10),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.item.totalKcal.round()} kcal',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manual item entry sheet ───────────────────────────────────────────────────

class _ManualItemSheet extends StatefulWidget {
  const _ManualItemSheet();

  @override
  State<_ManualItemSheet> createState() => _ManualItemSheetState();
}

class _ManualItemSheetState extends State<_ManualItemSheet> {
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '100');
  double _amount = 100;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final v = (_amount + delta).clamp(1, 9999).toDouble();
    setState(() {
      _amount = v;
      _amountCtrl.text = v.toStringAsFixed(0);
    });
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final kcal = double.tryParse(_kcalCtrl.text) ?? 0;
    Navigator.pop(
      context,
      _Item(name: name, weightG: _amount, kcalPer100g: kcal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Product name *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kcalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'kcal / 100 g',
                    suffixText: 'kcal',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _step(-10),
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primary,
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _amountCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(suffixText: 'g'),
                  onChanged: (v) =>
                      setState(() => _amount = double.tryParse(v) ?? _amount),
                ),
              ),
              IconButton(
                onPressed: () => _step(10),
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nameCtrl.text.trim().isEmpty ? null : _submit,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meal type chips ───────────────────────────────────────────────────────────

class _MealTypeChips extends StatelessWidget {
  final String? current;
  final ValueChanged<String> onChanged;
  const _MealTypeChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = ['breakfast', 'lunch', 'snack', 'dinner'];
    const labels = {
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'snack': 'Snack',
      'dinner': 'Dinner',
    };
    return Wrap(
      spacing: 8,
      children: types
          .map((t) => ChoiceChip(
                label: Text(labels[t]!),
                selected: current == t,
                onSelected: (_) => onChanged(t),
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
              ))
          .toList(),
    );
  }
}
