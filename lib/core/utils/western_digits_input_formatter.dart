import 'package:flutter/services.dart';

import 'phone_utils.dart';

/// يقبل الأرقام العربية والفارسية ويحوّلها فوراً إلى أرقام لاتينية.
class WesternDigitsInputFormatter extends TextInputFormatter {
  final int? maxLength;

  const WesternDigitsInputFormatter({this.maxLength});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = PhoneUtils.digitsOnly(newValue.text);
    if (maxLength != null && text.length > maxLength!) {
      text = text.substring(0, maxLength!);
    }

    if (text == newValue.text) {
      return newValue;
    }

    final removed = newValue.text.length - text.length;
    var offset = newValue.selection.baseOffset - removed;
    if (offset < 0) offset = 0;
    if (offset > text.length) offset = text.length;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
