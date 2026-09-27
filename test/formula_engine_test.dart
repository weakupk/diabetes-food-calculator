import 'package:diabetes_food_calculator/core/formula_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormulaEvaluator', () {
    test('supports basic arithmetic', () {
      expect(FormulaEvaluator.evaluate('1 + 2 * 3 - 4 / 2', const {}), 5);
    });

    test('respects parentheses precedence', () {
      expect(FormulaEvaluator.evaluate('(1 + 2) * (3 + 4)', const {}), 21);
    });

    test('throws on division by zero', () {
      expect(
        () => FormulaEvaluator.evaluate('10 / (5 - 5)', const {}),
        throwsA(
          isA<FormulaEvaluationException>().having(
            (error) => error.message,
            'message',
            contains('除数不能为 0'),
          ),
        ),
      );
    });

    test('throws on invalid expressions', () {
      expect(
        () => FormulaEvaluator.evaluate('1 + )', const {}),
        throwsA(
          isA<FormulaEvaluationException>().having(
            (error) => error.message,
            'message',
            contains('非法表达式'),
          ),
        ),
      );
      expect(
        () => FormulaEvaluator.evaluate('(1 + 2', const {}),
        throwsA(
          isA<FormulaEvaluationException>().having(
            (error) => error.message,
            'message',
            contains('括号不匹配'),
          ),
        ),
      );
      expect(
        () => FormulaEvaluator.evaluate('1 + a$', {'a': 1}),
        throwsA(
          isA<FormulaEvaluationException>().having(
            (error) => error.message,
            'message',
            contains('包含非法字符'),
          ),
        ),
      );
    });

    test('throws when variables are missing', () {
      expect(
        () => FormulaEvaluator.evaluate('carbs / cir', const {'carbs': 12}),
        throwsA(
          isA<FormulaEvaluationException>().having(
            (error) => error.message,
            'message',
            contains('缺少变量：cir'),
          ),
        ),
      );
    });

    test('replaces variables correctly', () {
      final result = FormulaEvaluator.evaluate(
        'carbs / cir + protein_fat_base',
        const {
          'carbs': 24,
          'cir': 12,
          'protein_fat_base': 3,
        },
      );

      expect(result, 5);
    });
  });
}
