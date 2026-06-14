import 'dart:math' as math;

/// Safe arithmetic expression evaluator for the `calculator` chat tool.
///
/// Pure Dart recursive-descent parser — never evaluates arbitrary code. Supports
/// `+ - * / %`, `^` (right-associative power), unary +/-, parentheses, decimals,
/// and scientific notation (e.g. `1.5e3`).

/// Raised when an expression cannot be parsed or evaluated.
class CalculatorException implements Exception {
  const CalculatorException(this.message);
  final String message;
  @override
  String toString() => 'CalculatorException: $message';
}

/// Evaluates [expression] and returns the numeric result.
double evaluateExpression(String expression) => _Parser(expression).parse();

class _Parser {
  _Parser(this._input);

  final String _input;
  int _pos = 0;

  double parse() {
    final value = _parseExpr();
    _skipWhitespace();
    if (_pos != _input.length) {
      throw CalculatorException('Unexpected character at position $_pos.');
    }
    if (value.isNaN || value.isInfinite) {
      throw const CalculatorException('Result is not a finite number.');
    }
    return value;
  }

  // expr = term (('+' | '-') term)*
  double _parseExpr() {
    var value = _parseTerm();
    while (true) {
      final op = _peekOperator();
      if (op == '+') {
        _pos++;
        value += _parseTerm();
      } else if (op == '-') {
        _pos++;
        value -= _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  // term = factor (('*' | '/' | '%') factor)*
  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      final op = _peekOperator();
      if (op == '*') {
        _pos++;
        value *= _parseFactor();
      } else if (op == '/') {
        _pos++;
        final divisor = _parseFactor();
        if (divisor == 0) throw const CalculatorException('Division by zero.');
        value /= divisor;
      } else if (op == '%') {
        _pos++;
        final divisor = _parseFactor();
        if (divisor == 0) throw const CalculatorException('Modulo by zero.');
        value %= divisor;
      } else {
        break;
      }
    }
    return value;
  }

  // factor = unary ('^' factor)?   (right-associative)
  double _parseFactor() {
    final base = _parseUnary();
    if (_peekOperator() == '^') {
      _pos++;
      final exponent = _parseFactor();
      return math.pow(base, exponent).toDouble();
    }
    return base;
  }

  // unary = ('+' | '-') unary | primary
  double _parseUnary() {
    final op = _peekOperator();
    if (op == '+') {
      _pos++;
      return _parseUnary();
    }
    if (op == '-') {
      _pos++;
      return -_parseUnary();
    }
    return _parsePrimary();
  }

  // primary = number | '(' expr ')'
  double _parsePrimary() {
    _skipWhitespace();
    if (_pos >= _input.length) {
      throw const CalculatorException('Unexpected end of expression.');
    }
    if (_input[_pos] == '(') {
      _pos++;
      final value = _parseExpr();
      _skipWhitespace();
      if (_pos >= _input.length || _input[_pos] != ')') {
        throw const CalculatorException('Missing closing parenthesis.');
      }
      _pos++;
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipWhitespace();
    final start = _pos;
    var sawDigit = false;
    while (_pos < _input.length) {
      final c = _input.codeUnitAt(_pos);
      final isDigit = c >= 0x30 && c <= 0x39;
      if (isDigit) {
        sawDigit = true;
        _pos++;
      } else if (c == 0x2e) {
        // '.'
        _pos++;
      } else if ((c == 0x65 || c == 0x45) && sawDigit) {
        // 'e' / 'E'
        _pos++;
        if (_pos < _input.length &&
            (_input[_pos] == '+' || _input[_pos] == '-')) {
          _pos++;
        }
      } else {
        break;
      }
    }
    if (!sawDigit) {
      throw CalculatorException('Expected a number at position $start.');
    }
    final token = _input.substring(start, _pos);
    final value = double.tryParse(token);
    if (value == null) {
      throw CalculatorException('Invalid number "$token".');
    }
    return value;
  }

  String? _peekOperator() {
    _skipWhitespace();
    if (_pos >= _input.length) return null;
    return _input[_pos];
  }

  void _skipWhitespace() {
    while (_pos < _input.length && _input[_pos].trim().isEmpty) {
      _pos++;
    }
  }
}
