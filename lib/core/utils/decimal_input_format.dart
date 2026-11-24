import 'package:flutter/services.dart';

class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    text = text.replaceAll(RegExp(r'[^0-9.]'), '');

    int dotIndex = text.indexOf('.');
    if (dotIndex != -1) {
      String before = text.substring(0, dotIndex + 1);
      String after = text.substring(dotIndex + 1).replaceAll('.', '');
      text = before + after;
    }

    return TextEditingValue(text: text, selection: newValue.selection);
  }
}
