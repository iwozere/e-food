import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/util/decimal_input_formatter.dart';

void main() {
  const f = DecimalInputFormatter();

  TextEditingValue v(String s) => TextEditingValue(text: s);

  String apply(String oldText, String newText) =>
      f.formatEditUpdate(v(oldText), v(newText)).text;

  test('accepts digits and a single decimal point', () {
    expect(apply('12', '12.'), '12.');
    expect(apply('12.', '12.5'), '12.5');
    expect(apply('', '.'), '.');
    expect(apply('.', '.5'), '.5');
  });

  test('rejects a second decimal point (1.2.3 is unenterable)', () {
    expect(apply('1.2', '1.2.'), '1.2');
    expect(apply('1.2', '1.2.3'), '1.2');
  });

  test('rejects letters and symbols', () {
    expect(apply('12', '12a'), '12');
    expect(apply('12', '12-'), '12');
  });

  test('allows clearing the field', () {
    expect(apply('12.5', ''), '');
  });
}
