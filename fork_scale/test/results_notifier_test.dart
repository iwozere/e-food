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
  group('ResultsNotifier.deleteItem — editedIndices remapping', () {
    test('deleting item 0 remaps higher indices down by 1', () {
      final notifier = ResultsNotifier(
        _result([_item('A'), _item('B'), _item('C')]),
      );
      // Mark items 1 and 2 as edited.
      notifier.updateItem(1, _item('B2'));
      notifier.updateItem(2, _item('C2'));
      expect(notifier.state.editedIndices, {1, 2});

      notifier.deleteItem(0); // remove A

      // After deletion: B is at 0, C is at 1 → previously {1,2} → now {0,1}
      expect(notifier.state.items.length, 2);
      expect(notifier.state.editedIndices, {0, 1});
    });

    test('deleting an edited item removes it from editedIndices', () {
      final notifier = ResultsNotifier(
        _result([_item('A'), _item('B'), _item('C')]),
      );
      notifier.updateItem(0, _item('A2'));
      notifier.updateItem(1, _item('B2'));
      expect(notifier.state.editedIndices, {0, 1});

      notifier.deleteItem(1); // remove B (which is edited)

      // A stays at 0 (edited), C moves to 1 (not edited).
      expect(notifier.state.items.length, 2);
      expect(notifier.state.editedIndices, {0});
    });

    test('deleting last item leaves lower editedIndices unchanged', () {
      final notifier = ResultsNotifier(
        _result([_item('A'), _item('B'), _item('C')]),
      );
      notifier.updateItem(0, _item('A2'));
      expect(notifier.state.editedIndices, {0});

      notifier.deleteItem(2); // remove C (not edited)

      expect(notifier.state.items.length, 2);
      expect(notifier.state.editedIndices, {0});
    });

    test('deleting from empty list is a no-op (guard)', () {
      // This tests the boundary: a single-item list.
      final notifier = ResultsNotifier(
        _result([_item('A')]),
      );
      notifier.updateItem(0, _item('A2'));
      notifier.deleteItem(0);

      expect(notifier.state.items, isEmpty);
      expect(notifier.state.editedIndices, isEmpty);
    });
  });
}
