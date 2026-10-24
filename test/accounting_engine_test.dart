import 'package:flutter_test/flutter_test.dart';
import 'package:sakhtyar/accounting_engine.dart';

void main() {
  final old = AccountingDebt('old', DateTime(2026, 1, 1), 100);
  final recent = AccountingDebt('recent', DateTime(2026, 1, 8), 200);

  test('auto settlement pays the oldest debt then part of the next', () {
    final outstanding = remainingDebts([old, recent], []);
    final payment = allocateOldestFirst(
      debts: [recent, old], remaining: outstanding, amount: 150);
    expect(payment, {'old': 100, 'recent': 50});
    expect(remainingDebts([old, recent], [payment]),
      {'old': 0, 'recent': 150});
  });

  test('manual settlement targets selected invoice', () {
    final payment = allocateOldestFirst(debts: [old, recent],
      remaining: remainingDebts([old, recent], []), amount: 120,
      prioritizedIds: ['recent']);
    expect(payment, {'recent': 120});
  });

  test('recorded allocations are stable after a backdated debt', () {
    final payment = {'old': 100};
    final backdated = AccountingDebt('backdated', DateTime(2025, 12, 1), 90);
    expect(remainingDebts([old, recent, backdated], [payment]),
      {'old': 0, 'recent': 200, 'backdated': 90});
  });

  test('penalty reduces due without being a cash payment', () {
    final remaining = remainingDebts([old], [{'old': 25}]);
    expect(remaining['old'], 75);
  });

  test('overpayment remains unallocated rather than double settling', () {
    final allocation = allocateOldestFirst(debts: [old],
      remaining: {'old': 30}, amount: 90);
    expect(allocation, {'old': 30});
    expect(90 - allocation.values.reduce((a, b) => a + b), 60);
  });
}
