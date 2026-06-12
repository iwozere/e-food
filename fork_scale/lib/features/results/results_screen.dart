import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/analysis_result.dart';
import '../../models/meal.dart';
import '../../widgets/meal_type_selector.dart';
import 'results_notifier.dart';
import 'ingredient_card.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final AnalysisResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late final AutoDisposeStateNotifierProvider<ResultsNotifier, ResultsState> _provider;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _provider = StateNotifierProvider.autoDispose<ResultsNotifier, ResultsState>(
      (ref) => ResultsNotifier(widget.result),
    );
  }

  Future<void> _saveMeal(ResultsState state) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(mealsRepositoryProvider);
      final pendingId = widget.result.pendingMealId;

      if (pendingId != null) {
        final existing = await repo.getMeal(pendingId);
        if (existing != null) {
          await repo.updateMeal(existing.copyWith(
            totalKcal: state.totalKcal,
            items: state.items,
            scaleConf: state.scaleConfidence,
            mealType: state.mealType,
            notes: state.notes,
            pending: false,
          ));
          if (!mounted) return;
          context.pop();
          return;
        }
      }

      final meal = Meal(
        createdAt: DateTime.now(),
        photoPath: state.photoPath,
        notes: state.notes,
        totalKcal: state.totalKcal,
        utensil: state.utensil,
        scaleConf: state.scaleConfidence,
        modelUsed: 'gemini',
        items: state.items,
        mealType: state.mealType,
      );
      final id = await repo.insertMeal(meal);
      if (!mounted) return;
      context.go('/history');
      context.push('/history/$id');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ResultsBody(
      provider: _provider,
      onSave: _saveMeal,
      saving: _saving,
    );
  }
}

class _ResultsBody extends ConsumerWidget {
  final AutoDisposeStateNotifierProvider<ResultsNotifier, ResultsState> provider;
  final Future<void> Function(ResultsState) onSave;
  final bool saving;

  const _ResultsBody({
    required this.provider,
    required this.onSave,
    required this.saving,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TotalBanner(totalKcal: state.totalKcal)),
          if (!state.utensilDetected)
            const SliverToBoxAdapter(child: _UtensilWarning()),
          if (state.scaleConfidence != null)
            SliverToBoxAdapter(
              child: _ConfidenceBadge(confidence: state.scaleConfidence!),
            ),
          SliverList.builder(
            itemCount: state.items.length,
            itemBuilder: (context, i) {
              final item = state.items[i];
              return IngredientCard(
                key: ValueKey(item.id ?? identityHashCode(item)),
                item: item,
                isEdited: state.editedIndices.contains(i),
                onChanged: (updated) => notifier.updateItem(i, updated),
                onDelete: () => notifier.deleteItem(i),
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: notifier.addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MealTypeSelector(
              value: state.mealType,
              onChanged: notifier.updateMealType,
              showLabel: true,
            ),
          ),
          SliverToBoxAdapter(
            child: _NotesField(
              initial: state.notes ?? '',
              onChanged: notifier.updateNotes,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _SaveBar(
        saving: saving,
        onSave: () => onSave(state),
      ),
    );
  }
}


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
          const Text(
            'kcal',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _UtensilWarning extends StatelessWidget {
  const _UtensilWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Utensil not clearly visible — estimates may be less accurate.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  Color get _color => switch (confidence) {
        'high' => Colors.green,
        'medium' => Colors.orange,
        _ => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Scale confidence'),
            content: const Text(
              'High: utensil clearly visible and unobstructed.\n'
              'Medium: utensil partially visible or at an angle.\n'
              'Low: utensil barely visible — portion sizes may be inaccurate.',
            ),
            actions: [
              TextButton(
                onPressed: Navigator.of(context).pop,
                child: const Text('OK'),
              ),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'Scale confidence: ${confidence[0].toUpperCase()}${confidence.substring(1)}',
              style: TextStyle(color: _color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 14, color: _color),
          ],
        ),
      ),
    );
  }
}

class _NotesField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _NotesField({required this.initial, required this.onChanged});

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        decoration: const InputDecoration(
          labelText: 'Notes (optional)',
          hintText: 'e.g. post-run, cheat day',
        ),
        maxLines: 2,
      ),
    );
  }
}

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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save meal'),
        ),
      ),
    );
  }
}
