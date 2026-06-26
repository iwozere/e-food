import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/services/usda_service.dart';

void main() {
  group('UsdaService.scoreMatch', () {
    test('identical phrase scores 1.0', () {
      expect(UsdaService.scoreMatch('chicken breast', 'chicken breast'), 1.0);
    });

    test('full coverage with extra description words scores high but < 1', () {
      // "chicken breast, grilled" covers both query words.
      final s = UsdaService.scoreMatch('grilled chicken', 'chicken breast, grilled');
      expect(s, greaterThanOrEqualTo(UsdaService.matchThreshold));
      expect(s, lessThan(1.0));
    });

    test('single coincidental word does not clear the threshold', () {
      // Only "chicken" overlaps; "grilled" is absent and the description adds
      // unrelated qualifiers. Must NOT be accepted as authoritative.
      final s = UsdaService.scoreMatch('grilled chicken', 'chicken, skin only, raw');
      expect(s, lessThan(UsdaService.matchThreshold));
    });

    test('over-qualified long description is penalised below threshold', () {
      final s = UsdaService.scoreMatch(
        'chicken rice',
        'chicken and rice casserole with mushrooms, cream and herbs, baked',
      );
      expect(s, lessThan(UsdaService.matchThreshold));
    });

    test('no overlap scores 0', () {
      expect(UsdaService.scoreMatch('banana', 'grilled salmon fillet'), 0);
    });

    test('queries of only short tokens score 0 (no significant tokens)', () {
      expect(UsdaService.scoreMatch('an of', 'chicken breast'), 0);
    });
  });
}
