import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/database/meals_repository.dart';

void main() {
  group('MealsRepository.sanitizeFtsQuery', () {
    test('wraps each token in double quotes', () {
      expect(
        MealsRepository.sanitizeFtsQuery('chicken rice'),
        '"chicken" "rice"',
      );
    });

    test('neutralises FTS operators by quoting them as literals', () {
      // OR / NEAR / - would otherwise be interpreted as FTS syntax.
      expect(
        MealsRepository.sanitizeFtsQuery('chicken OR rice'),
        '"chicken" "OR" "rice"',
      );
      expect(
        MealsRepository.sanitizeFtsQuery('-rice'),
        '"-rice"',
      );
    });

    test('escapes embedded double quotes by doubling them', () {
      expect(
        MealsRepository.sanitizeFtsQuery('15" pizza'),
        '"15""" "pizza"',
      );
    });

    test('handles an unbalanced quote without producing a dangling quote', () {
      // A lone quote becomes an escaped, balanced literal.
      expect(MealsRepository.sanitizeFtsQuery('"'), '""""');
    });

    test('empty / whitespace-only input yields empty string', () {
      expect(MealsRepository.sanitizeFtsQuery(''), '');
      expect(MealsRepository.sanitizeFtsQuery('   '), '');
    });

    test('collapses runs of whitespace', () {
      expect(
        MealsRepository.sanitizeFtsQuery('  chicken   rice  '),
        '"chicken" "rice"',
      );
    });
  });
}
