import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fork_scale/features/results/results_notifier.dart';
import 'package:fork_scale/models/analysis_result.dart';
import 'package:fork_scale/models/meal_item.dart';

MealItem _item(String name) => MealItem(
      name: name,
      weightG: 100,
      kcalPer100g: 200,
      totalKcal: 200,
    );

AnalysisResult _result(List<MealItem> items) => AnalysisResult(
      utensilDetected: true,
      items: items,
      totalKcal: 0,
      photoPath: '',
      utensil: 'fork',
    );

void main() {
  // A Notifier can't be driven directly (its `state` is protected and `build`
  // is framework-driven), so each test spins up a ProviderContainer with the
  // provider overridden to seed the given items, reads the notifier to call
  // methods, and reads the provider to observe the resulting state.
  ResultsNotifier notifierFor(ProviderContainer c) =>
      c.read(resultsNotifierProvider.notifier);
  ResultsState stateOf(ProviderContainer c) => c.read(resultsNotifierProvider);

  ProviderContainer containerWith(List<MealItem> items) {
    final container = ProviderContainer(overrides: [
      resultsNotifierProvider.overrideWith(() => ResultsNotifier(_result(items))),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('ResultsNotifier.deleteItem — editedIndices remapping', () {
    test('deleting item 0 remaps higher indices down by 1', () {
      final c = containerWith([_item('A'), _item('B'), _item('C')]);
      final notifier = notifierFor(c);
      // Mark items 1 and 2 as edited.
      notifier.updateItem(1, _item('B2'));
      notifier.updateItem(2, _item('C2'));
      expect(stateOf(c).editedIndices, {1, 2});

      notifier.deleteItem(0); // remove A

      // After deletion: B is at 0, C is at 1 → previously {1,2} → now {0,1}
      expect(stateOf(c).items.length, 2);
      expect(stateOf(c).editedIndices, {0, 1});
    });

    test('deleting an edited item removes it from editedIndices', () {
      final c = containerWith([_item('A'), _item('B'), _item('C')]);
      final notifier = notifierFor(c);
      notifier.updateItem(0, _item('A2'));
      notifier.updateItem(1, _item('B2'));
      expect(stateOf(c).editedIndices, {0, 1});

      notifier.deleteItem(1); // remove B (which is edited)

      // A stays at 0 (edited), C moves to 1 (not edited).
      expect(stateOf(c).items.length, 2);
      expect(stateOf(c).editedIndices, {0});
    });

    test('deleting last item leaves lower editedIndices unchanged', () {
      final c = containerWith([_item('A'), _item('B'), _item('C')]);
      final notifier = notifierFor(c);
      notifier.updateItem(0, _item('A2'));
      expect(stateOf(c).editedIndices, {0});

      notifier.deleteItem(2); // remove C (not edited)

      expect(stateOf(c).items.length, 2);
      expect(stateOf(c).editedIndices, {0});
    });

    test('deleting from empty list is a no-op (guard)', () {
      // This tests the boundary: a single-item list.
      final c = containerWith([_item('A')]);
      final notifier = notifierFor(c);
      notifier.updateItem(0, _item('A2'));
      notifier.deleteItem(0);

      expect(stateOf(c).items, isEmpty);
      expect(stateOf(c).editedIndices, isEmpty);
    });
  });
}
