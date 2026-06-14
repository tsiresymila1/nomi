import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/tools/calculator.dart';

void main() {
  group('evaluateExpression', () {
    test('basic arithmetic with precedence', () {
      expect(evaluateExpression('2 + 3 * 4'), 14);
      expect(evaluateExpression('(2 + 3) * 4'), 20);
      expect(evaluateExpression('10 - 4 - 3'), 3); // left-associative
    });

    test('division, modulo, decimals', () {
      expect(evaluateExpression('7 / 2'), 3.5);
      expect(evaluateExpression('10 % 3'), 1);
      expect(evaluateExpression('0.1 + 0.2'), closeTo(0.3, 1e-9));
    });

    test('power is right-associative', () {
      expect(evaluateExpression('2 ^ 3'), 8);
      expect(evaluateExpression('2 ^ 3 ^ 2'), 512); // 2^(3^2)
    });

    test('unary minus and parentheses', () {
      expect(evaluateExpression('-5 + 3'), -2);
      expect(evaluateExpression('-(2 + 3)'), -5);
      expect(evaluateExpression('3 * -2'), -6);
    });

    test('scientific notation', () {
      expect(evaluateExpression('1.5e3'), 1500);
      expect(evaluateExpression('2e-2'), closeTo(0.02, 1e-12));
    });

    test('division by zero throws', () {
      expect(
        () => evaluateExpression('1 / 0'),
        throwsA(isA<CalculatorException>()),
      );
      expect(
        () => evaluateExpression('5 % 0'),
        throwsA(isA<CalculatorException>()),
      );
    });

    test('malformed input throws, never executes code', () {
      for (final bad in ['2 +', '(1 + 2', 'abc', '', '1 2', '* 3']) {
        expect(
          () => evaluateExpression(bad),
          throwsA(isA<CalculatorException>()),
          reason: bad,
        );
      }
    });
  });
}
