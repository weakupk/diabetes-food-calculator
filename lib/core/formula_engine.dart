class FormulaEvaluationException implements Exception {
  const FormulaEvaluationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FormulaEvaluator {
  const FormulaEvaluator._();

  static double evaluate(String expression, Map<String, double> variables) {
    final parser = _FormulaParser(
      expression: expression,
      variables: variables,
    );
    return parser.parse();
  }

  static Set<String> variableNames(String expression) {
    return _FormulaTokenizer(expression).tokenize().where((token) {
      return token.type == _FormulaTokenType.variable;
    }).map((token) => token.text).toSet();
  }

  static String explain(
    String expression,
    Map<String, double> variables, {
    required String Function(double value) formatter,
  }) {
    final buffer = StringBuffer();
    for (final token in _FormulaTokenizer(expression).tokenize()) {
      switch (token.type) {
        case _FormulaTokenType.number:
          buffer.write(token.text);
          break;
        case _FormulaTokenType.variable:
          buffer.write(
            variables.containsKey(token.text)
                ? formatter(variables[token.text]!)
                : token.text,
          );
          break;
        case _FormulaTokenType.plus:
          buffer.write(' + ');
          break;
        case _FormulaTokenType.minus:
          buffer.write(' - ');
          break;
        case _FormulaTokenType.multiply:
          buffer.write(' × ');
          break;
        case _FormulaTokenType.divide:
          buffer.write(' ÷ ');
          break;
        case _FormulaTokenType.leftParen:
          buffer.write('(');
          break;
        case _FormulaTokenType.rightParen:
          buffer.write(')');
          break;
        case _FormulaTokenType.end:
          break;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

enum _FormulaTokenType {
  number,
  variable,
  plus,
  minus,
  multiply,
  divide,
  leftParen,
  rightParen,
  end,
}

class _FormulaToken {
  const _FormulaToken(this.type, this.text);

  final _FormulaTokenType type;
  final String text;
}

class _FormulaTokenizer {
  const _FormulaTokenizer(this.expression);

  final String expression;

  List<_FormulaToken> tokenize() {
    if (expression.trim().isEmpty) {
      throw const FormulaEvaluationException('公式不能为空');
    }

    final tokens = <_FormulaToken>[];
    var index = 0;
    while (index < expression.length) {
      final char = expression[index];
      if (_isWhitespace(char)) {
        index++;
        continue;
      }
      if (_isDigit(char) || char == '.') {
        final start = index;
        var dotCount = char == '.' ? 1 : 0;
        index++;
        while (index < expression.length) {
          final next = expression[index];
          if (_isDigit(next)) {
            index++;
            continue;
          }
          if (next == '.') {
            dotCount++;
            if (dotCount > 1) {
              throw FormulaEvaluationException(
                '非法数字格式：${expression.substring(start, index + 1)}',
              );
            }
            index++;
            continue;
          }
          break;
        }
        final tokenText = expression.substring(start, index);
        if (tokenText == '.') {
          throw const FormulaEvaluationException('非法数字格式：.');
        }
        tokens.add(_FormulaToken(_FormulaTokenType.number, tokenText));
        continue;
      }
      if (_isVariableStart(char)) {
        final start = index;
        index++;
        while (index < expression.length && _isVariablePart(expression[index])) {
          index++;
        }
        tokens.add(
          _FormulaToken(
            _FormulaTokenType.variable,
            expression.substring(start, index),
          ),
        );
        continue;
      }
      switch (char) {
        case '+':
          tokens.add(const _FormulaToken(_FormulaTokenType.plus, '+'));
          index++;
          break;
        case '-':
          tokens.add(const _FormulaToken(_FormulaTokenType.minus, '-'));
          index++;
          break;
        case '*':
          tokens.add(const _FormulaToken(_FormulaTokenType.multiply, '*'));
          index++;
          break;
        case '/':
          tokens.add(const _FormulaToken(_FormulaTokenType.divide, '/'));
          index++;
          break;
        case '(':
          tokens.add(const _FormulaToken(_FormulaTokenType.leftParen, '('));
          index++;
          break;
        case ')':
          tokens.add(const _FormulaToken(_FormulaTokenType.rightParen, ')'));
          index++;
          break;
        default:
          throw FormulaEvaluationException('包含非法字符：$char');
      }
    }
    tokens.add(const _FormulaToken(_FormulaTokenType.end, ''));
    return tokens;
  }

  bool _isWhitespace(String char) => RegExp(r'\s').hasMatch(char);

  bool _isDigit(String char) => RegExp(r'\d').hasMatch(char);

  bool _isVariableStart(String char) => RegExp(r'[A-Za-z_]').hasMatch(char);

  bool _isVariablePart(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);
}

class _FormulaParser {
  _FormulaParser({
    required String expression,
    required Map<String, double> variables,
  }) : _tokens = _FormulaTokenizer(expression).tokenize(),
       _variables = variables;

  final List<_FormulaToken> _tokens;
  final Map<String, double> _variables;
  var _index = 0;

  double parse() {
    final result = _parseExpression();
    if (_current.type != _FormulaTokenType.end) {
      throw FormulaEvaluationException('非法表达式：${_current.text}');
    }
    return result;
  }

  _FormulaToken get _current => _tokens[_index];

  double _parseExpression() {
    var value = _parseTerm();
    while (_current.type == _FormulaTokenType.plus ||
        _current.type == _FormulaTokenType.minus) {
      final operator = _current.type;
      _index++;
      final other = _parseTerm();
      value = operator == _FormulaTokenType.plus ? value + other : value - other;
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (_current.type == _FormulaTokenType.multiply ||
        _current.type == _FormulaTokenType.divide) {
      final operator = _current.type;
      _index++;
      final other = _parseFactor();
      if (operator == _FormulaTokenType.multiply) {
        value *= other;
      } else {
        if (other == 0) {
          throw const FormulaEvaluationException('除数不能为 0');
        }
        value /= other;
      }
    }
    return value;
  }

  double _parseFactor() {
    switch (_current.type) {
      case _FormulaTokenType.plus:
        _index++;
        return _parseFactor();
      case _FormulaTokenType.minus:
        _index++;
        return -_parseFactor();
      case _FormulaTokenType.number:
        final value = double.parse(_current.text);
        _index++;
        return value;
      case _FormulaTokenType.variable:
        final name = _current.text;
        _index++;
        if (!_variables.containsKey(name)) {
          throw FormulaEvaluationException('缺少变量：$name');
        }
        return _variables[name]!;
      case _FormulaTokenType.leftParen:
        _index++;
        final value = _parseExpression();
        if (_current.type != _FormulaTokenType.rightParen) {
          throw const FormulaEvaluationException('括号不匹配');
        }
        _index++;
        return value;
      case _FormulaTokenType.rightParen:
      case _FormulaTokenType.multiply:
      case _FormulaTokenType.divide:
        throw FormulaEvaluationException('非法表达式：${_current.text}');
      case _FormulaTokenType.end:
        throw const FormulaEvaluationException('非法表达式');
    }
  }
}
