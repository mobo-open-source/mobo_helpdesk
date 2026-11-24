import 'package:odoo_rpc/odoo_rpc.dart';

/// Extracts a user-friendly title and description from an OdooException.
///
/// Returns a Map with 'title' and 'description' for easy display to the user.
Map<String, String> extractOdooError(OdooException e) {
  final text = e.toString();

  // ignore: deprecated_member_use
  final validationMatch = RegExp(
    r'ValidationError:\s*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
  ).firstMatch(text);

  if (validationMatch != null) {
    return {
      'title': 'Validation Error',
      'description': validationMatch.group(1)!.trim(),
    };
  }

  // ignore: deprecated_member_use
  final accessMatch = RegExp(
    r'name:\s*odoo\.exceptions\.AccessError,\s*message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (accessMatch != null) {
    return {
      'title': 'Access Denied',
      'description': accessMatch.group(1)!.trim(),
    };
  }

  // ignore: deprecated_member_use
  final userMatch = RegExp(
    r'name:\s*odoo\.exceptions\.UserError,[\s\S]*?message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (userMatch != null) {
    return {'title': 'User Error', 'description': userMatch.group(1)!.trim()};
  }

  // ignore: deprecated_member_use
  final valueMatch = RegExp(
    r'name:\s*odoo\.exceptions\.ValueError,[\s\S]*?message:\s*([\s\S]*?)(?=, arguments:|, context:|\}$)',
    caseSensitive: false,
  ).firstMatch(text);

  if (valueMatch != null) {
    return {'title': 'Value Error', 'description': valueMatch.group(1)!.trim()};
  }

  // ignore: deprecated_member_use
  final stateMatch = RegExp(
    r'state\.message\s*:?\s*([^\n\r]*)',
    caseSensitive: false,
  ).firstMatch(text);

  if (stateMatch != null) {
    final msg = stateMatch.group(1)?.trim();
    if (msg != null && msg.isNotEmpty) {
      return {'title': 'Error', 'description': msg};
    }
  }

  // ignore: deprecated_member_use
  final keyErrorMatch = RegExp(r"KeyError:\s*'([^']*)'").firstMatch(text);

  if (keyErrorMatch != null) {
    final field = keyErrorMatch.group(1);
    if (field != null && field.isNotEmpty) {
      return {'title': 'KeyError', 'description': field};
    }
  }

  // ignore: deprecated_member_use
  final pythonErrorMatch = RegExp(
    r'([A-Za-z]+Error):\s*([^\n\r]*)',
  ).firstMatch(text);

  if (pythonErrorMatch != null) {
    return {
      'title': pythonErrorMatch.group(1) ?? 'Error',
      'description': pythonErrorMatch.group(2) ?? 'Unexpected error',
    };
  }

  return {
    'title': 'Unexpected Error',
    'description': 'Something went wrong. Please try again later.',
  };
}
