/// Pure settlement rules shared by the accounting UI and unit tests.
/// Stored allocations never change when later invoices are entered.
class AccountingDebt {
  const AccountingDebt(this.id, this.date, this.amount);
  final String id;
  final DateTime date;
  final int amount;
}

Map<String, int> remainingDebts(
    Iterable<AccountingDebt> debts, Iterable<Map<String, int>> allocations) {
  final remaining = <String, int>{for (final d in debts) d.id: d.amount};
  for (final distribution in allocations) {
    for (final item in distribution.entries) {
      if (remaining.containsKey(item.key)) {
        final old = remaining[item.key]!;
        final next = old - item.value;
        remaining[item.key] = next < 0 ? 0 : next;
      }
    }
  }
  return remaining;
}

Map<String, int> allocateOldestFirst({
  required Iterable<AccountingDebt> debts,
  required Map<String, int> remaining,
  required int amount,
  Iterable<String>? prioritizedIds,
}) {
  final ordered = debts.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  if (prioritizedIds != null) {
    final choices = prioritizedIds.toList();
    ordered.sort((a, b) {
      final ai = choices.indexOf(a.id), bi = choices.indexOf(b.id);
      if (ai == -1 && bi == -1) return 0;
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
  }
  var left = amount;
  final allocation = <String, int>{};
  for (final debt in ordered) {
    if (left <= 0) break;
    if (prioritizedIds != null && !prioritizedIds.contains(debt.id)) continue;
    final unpaid = remaining[debt.id] ?? 0;
    final used = unpaid < left ? unpaid : left;
    if (used > 0) allocation[debt.id] = used;
    left -= used;
  }
  return allocation;
}
