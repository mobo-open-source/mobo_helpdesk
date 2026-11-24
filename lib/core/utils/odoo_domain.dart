/// Reads and writes the textual form of an Odoo domain.
///
/// Some Odoo fields keep a domain as text - Odoo 20's `helpdesk.sla` stores the
/// tickets a policy applies to in `criteria_domain`, and Odoo evaluates it with
/// `ast.literal_eval`. The text is a Python literal such as
/// `[('priority', '>=', '2'), ('tag_ids', 'in', [1, 2])]`, so it is parsed and
/// printed here as one rather than as JSON (`True`, `None` and single quotes
/// are not JSON).
///
/// A domain is a flat list in prefix notation: leaves are `[field, operator,
/// value]` and the strings `'&'`, `'|'` and `'!'` combine what follows them. Two
/// complete domains placed one after the other are ANDed, which is what lets a
/// caller add clauses to a domain it does not otherwise understand.
class OdooDomain {
  const OdooDomain._();

  /// Parses [text] into nested lists (tuples become lists).
  ///
  /// Returns `null` when [text] is not a literal this reader understands, so a
  /// caller can leave an unfamiliar domain exactly as it found it. Empty text
  /// is the empty domain.
  static List<dynamic>? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    try {
      final parser = _Parser(text);
      final value = parser.parseValue();
      parser.expectEnd();
      return value is List ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Prints [domain] as a Python literal Odoo can evaluate.
  ///
  /// Leaves of a domain are written as tuples, the way Odoo's own domain editor
  /// writes them; every other list stays a list.
  static String format(List<dynamic> domain) {
    final items = domain.map((item) {
      final isLeaf =
          item is List && item.length == 3 && item[1] is String;
      return isLeaf ? _tuple(item) : _value(item);
    });
    return '[${items.join(', ')}]';
  }

  /// Splits [domain] into its top-level expressions.
  ///
  /// `['|', a, b, c]` is two expressions, `['|', a, b]` and `[c]`. Returns
  /// `null` when the prefix notation is malformed, which callers treat the same
  /// as an unparsable domain.
  static List<List<dynamic>>? splitTopLevel(List<dynamic> domain) {
    final expressions = <List<dynamic>>[];
    var index = 0;
    while (index < domain.length) {
      final end = _expressionEnd(domain, index);
      if (end == null) return null;
      expressions.add(domain.sublist(index, end));
      index = end;
    }
    return expressions;
  }

  /// Index just past the expression that starts at [start], or `null` when it
  /// runs off the end of [domain].
  static int? _expressionEnd(List<dynamic> domain, int start) {
    if (start >= domain.length) return null;
    final item = domain[start];
    if (item == '!') return _expressionEnd(domain, start + 1);
    if (item == '&' || item == '|') {
      final left = _expressionEnd(domain, start + 1);
      if (left == null) return null;
      return _expressionEnd(domain, left);
    }
    return start + 1;
  }

  static String _tuple(List<dynamic> leaf) =>
      '(${leaf.map(_value).join(', ')})';

  static String _value(dynamic value) {
    if (value == null) return 'None';
    if (value is bool) return value ? 'True' : 'False';
    if (value is num) return value.toString();
    if (value is String) return _quote(value);
    if (value is List) return '[${value.map(_value).join(', ')}]';
    throw ArgumentError('Cannot write ${value.runtimeType} in a domain');
  }

  static String _quote(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return "'$escaped'";
  }
}

/// A recursive-descent reader for the subset of Python literals a domain uses:
/// lists, tuples, strings, numbers, `True`, `False` and `None`.
class _Parser {
  _Parser(this._text);

  final String _text;
  int _pos = 0;

  void expectEnd() {
    _skipSpace();
    if (_pos != _text.length) throw const FormatException('Trailing text');
  }

  dynamic parseValue() {
    _skipSpace();
    if (_pos >= _text.length) throw const FormatException('Unexpected end');
    final char = _text[_pos];
    if (char == '[') return _sequence('[', ']');
    if (char == '(') return _sequence('(', ')');
    if (char == "'" || char == '"') return _string(char);
    if (char == '-' || _isDigit(char)) return _number();
    return _word();
  }

  List<dynamic> _sequence(String open, String close) {
    _pos++; // opening bracket
    final items = <dynamic>[];
    while (true) {
      _skipSpace();
      if (_pos >= _text.length) throw const FormatException('Unclosed list');
      if (_text[_pos] == close) {
        _pos++;
        return items;
      }
      items.add(parseValue());
      _skipSpace();
      if (_pos < _text.length && _text[_pos] == ',') _pos++;
    }
  }

  String _string(String quote) {
    _pos++; // opening quote
    final buffer = StringBuffer();
    while (_pos < _text.length) {
      final char = _text[_pos++];
      if (char == quote) return buffer.toString();
      if (char != r'\') {
        buffer.write(char);
        continue;
      }
      if (_pos >= _text.length) break;
      final escaped = _text[_pos++];
      switch (escaped) {
        case 'n':
          buffer.write('\n');
        case 'r':
          buffer.write('\r');
        case 't':
          buffer.write('\t');
        default:
          buffer.write(escaped); // \\, \', \" and anything else literally
      }
    }
    throw const FormatException('Unclosed string');
  }

  num _number() {
    final start = _pos;
    if (_text[_pos] == '-') _pos++;
    while (_pos < _text.length &&
        (_isDigit(_text[_pos]) || _text[_pos] == '.')) {
      _pos++;
    }
    final number = num.tryParse(_text.substring(start, _pos));
    if (number == null) throw const FormatException('Bad number');
    return number;
  }

  dynamic _word() {
    final start = _pos;
    while (_pos < _text.length && RegExp(r'[A-Za-z_]').hasMatch(_text[_pos])) {
      _pos++;
    }
    switch (_text.substring(start, _pos)) {
      case 'True' || 'true':
        return true;
      case 'False' || 'false':
        return false;
      case 'None' || 'null':
        return null;
    }
    throw const FormatException('Not a literal');
  }

  void _skipSpace() {
    while (_pos < _text.length && ' \t\r\n'.contains(_text[_pos])) {
      _pos++;
    }
  }

  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
}
