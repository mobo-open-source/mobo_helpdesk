import 'package:flutter/services.dart';

/// Validators for free-text contact fields.
///
/// Each returns the message to show under the field, or null when the value is
/// valid. An empty value is valid: the fields these check are optional, and a
/// required one is enforced where it is declared.
class InputValidators {
  InputValidators._();

  /// Keeps letters and stray symbols out of a phone field as they are typed.
  static final TextInputFormatter phoneInputFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s().]'));

  static const int _minPhoneDigits = 7;
  static const int _maxPhoneDigits = 15; // E.164's longest number.

  static final RegExp _phoneChars = RegExp(r'^[0-9+\-\s().]+$');

  /// A phone number: digits with optional spaces, `-`, `(`, `)` and `.`, and a
  /// `+` for the country code at the very start only.
  static String? phone(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    if (!_phoneChars.hasMatch(text)) {
      return 'Phone can only contain digits, spaces and + - ( ) .';
    }
    if (text.lastIndexOf('+') > 0) {
      return 'The + sign is only allowed at the start of the number';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    if (digits < _minPhoneDigits) {
      return 'Phone number is too short (at least $_minPhoneDigits digits)';
    }
    if (digits > _maxPhoneDigits) {
      return 'Phone number is too long (at most $_maxPhoneDigits digits)';
    }
    return null;
  }

  static final RegExp _emailLocal = RegExp(
    r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*$",
  );
  static final RegExp _emailDomain = RegExp(
    r'^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
    r'([A-Za-z]{2,63}|xn--[A-Za-z0-9-]{1,59})$',
  );
  static final RegExp _namedAddress = RegExp(r'^[^<>]*<([^<>]+)>$');

  /// One or more email addresses separated by `,` or `;`, as Odoo's "Email cc"
  /// takes them. `Name <name@example.com>` is accepted too.
  static String? emailList(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final entries = text
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (entries.isEmpty) return 'Enter a valid email address';

    for (final entry in entries) {
      final address =
          _namedAddress.firstMatch(entry)?.group(1)?.trim() ?? entry;
      if (!_isEmail(address)) {
        return '"$entry" is not a valid email address';
      }
    }
    return null;
  }

  static bool _isEmail(String address) {
    if (address.length > 254) return false;
    final at = address.indexOf('@');
    if (at <= 0 || at != address.lastIndexOf('@')) return false;

    final local = address.substring(0, at);
    final domain = address.substring(at + 1);
    return local.length <= 64 &&
        _emailLocal.hasMatch(local) &&
        _emailDomain.hasMatch(domain);
  }
}
