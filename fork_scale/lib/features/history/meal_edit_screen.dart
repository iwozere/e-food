import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/meal.dart';
import '../../models/meal_item.dart';
import '../results/ingredient_card.dart';

class MealEditScreen extends ConsumerStatefulWidget {
  final Meal meal;
  const MealEditScreen({super.key, required this.meal});

  @override
  ConsumerState<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends ConsumerState<MealEditScreen> {
  late List<MealItem> _items;
  late List<double> _originalKcal; // per-item baseline for "edited" badge
  late Set<int> _editedIndices;
  late String _mealType;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.meal.items);
    _originalKcal = _items.map((i) => i.kcalPer100g).toList();
    _editedIndices = {};
    _mealType = widget.meal.mealType ?? Meal.detectTypeFromTime();
    _notesCtrl = TextEditingController(text: widget.meal.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalKcal => _items.fold(0.0, (s, i) => s + i.computedKcal);

  void _updateItem(int index, MealItem updated) {
    setState(() {
      _items[index] = updated.copyWith(totalKcal: updated.computedKcal);
      if (index < _originalKcal.length &&
          updated.kcalPer100g != _originalKcal[index]) {
        _editedIndices = {..._editedIndices, index};
      } else {
        _editedIndices = ({..._editedIndices}..remove(index));
      }
    });
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      _originalKcal.removeAt(index);
      _editedIndices = _editedIndices
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toSet();
    });
  }

  void _addItem() {
    setState(() {
      _items.add(MealItem(
        name: 'New item',
        weightG: 100,
        kcalPer100g: 0,
        totalKcal: 0,
        sortOrder: _items.length,
      ));
      _originalKcal.add(0);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notes = _notesCtrl.text.trim();
      await ref.read(mealsRepositoryProvider).updateMeal(
            widget.meal.copyWith(
              items: _items,
              totalKcal: _totalKcal,
              mealType: _mealType,
              notes: notes.isEmpty ? null : notes,
            ),
          );
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit meal'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TotalBanner(totalKcal: _totalKcal)),
          SliverList.builder(
            itemCount: _items.length,
            itemBuilder: (context, i) => IngredientCard(
              key: ValueKey('edit_$i'),
              item: _items[i],
              isEdited: _editedIndices.contains(i),
              onChanged: (updated) => _updateItem(i, updated),
              onDelete: () => _deleteItem(i),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _MealTypeRow(
              selected: _mealType,
              onChanged: (t) => setState(() => _mealType = t),
            ),
          ),
          SliverToBoxAdapter(child: _NotesField(controller: _notesCtrl)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _SaveBar(saving: _saving, onSave: _save),
    );
  }
}

// ── Total kcal banner ─────────────────────────────────────────────────────────

class _TotalBanner extends StatelessWidget {
  final double totalKcal;
  const _TotalBanner({required this.totalKcal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            '${totalKcal.round()}',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text('kcal', style: TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }
}

// ── Meal type chips ───────────────────────────────────────────────────────────

class _MealTypeRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _MealTypeRow({required this.selected, required this.onChanged});

  static const _types = ['breakfast', 'lunch', 'snack', 'dinner'];
  static const _labels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'snack': 'Snack',
    'dinner': 'Dinner',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEAL TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.subtle,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _types.map((type) {
              final isSelected = type == selected;
              return ChoiceChip(
                label: Text(_labels[type]!),
                selected: isSelected,
                onSelected: (_) => onChanged(type),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Notes field ───────────────────────────────────────────────────────────────

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Notes (optional)',
          hintText: 'e.g. post-run, cheat day',
        ),
        maxLines: 2,
      ),
    );
  }
}

// ── Save bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
      ),
    );
  }
}
