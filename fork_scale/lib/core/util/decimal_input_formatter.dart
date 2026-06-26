import 'package:flutter/services.dart';

/// Allows only a non-negative decimal number: digits with at most one decimal
/// point (e.g. `12`, `12.5`, `.5`). Rejects a second point so `1.2.3` can never
/// be entered, unlike the looser `FilteringTextInputFormatter.allow([\d.])`.
class DecimalInputFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d*\.?\d*$');

  const DecimalInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    return _pattern.hasMatch(text) ? newValue : oldValue;
  }
}
