import 'dart:math' as math;

/// Measurements in whole centimetres that satisfy a² + b² = c² exactly.
class WholeCentimeterTriangle {
  const WholeCentimeterTriangle(this.firstCm, this.secondCm, this.diagonalCm);
  final int firstCm;
  final int secondCm;
  final int diagonalCm;
}

int _gcd(int a, int b) {
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return a;
}

/// Finds a nearby **exact** integer Pythagorean triple by minimising the
/// squared displacement of the two measured legs, not by rounding the
/// diagonal. The returned integers can be physically marked in centimetres.
///
/// Euclid's formula generates every primitive triple within the selected
/// search range. For each orientation, only the nearest integer scale factor
/// (and its two neighbours) need checking. The search is user-triggered.
WholeCentimeterTriangle nearestWholeCentimeterTriangle(
    double firstCm, double secondCm) {
  if (!firstCm.isFinite || !secondCm.isFinite ||
      firstCm <= 0 || secondCm <= 0 ||
      firstCm > 1000000 || secondCm > 1000000) {
    throw const FormatException('اندازه ضلع‌ها معتبر نیست.');
  }

  final expectedDiagonal = math.sqrt(firstCm * firstCm + secondCm * secondCm);
  final maxPrimitiveC = math.max(5, (expectedDiagonal * 1.5).ceil());
  WholeCentimeterTriangle? closest;
  double? bestError;
  double? bestLargestChange;

  void consider(int a, int b, int c) {
    if (a <= 0 || b <= 0 || a > 1000000 || b > 1000000) return;
    final da = a - firstCm, db = b - secondCm;
    final error = da * da + db * db;
    final largestChange = math.max(da.abs(), db.abs());
    if (bestError == null ||
        error < bestError! - 0.0000001 ||
        ((error - bestError!).abs() <= 0.0000001 &&
            largestChange < bestLargestChange!)) {
      closest = WholeCentimeterTriangle(a, b, c);
      bestError = error;
      bestLargestChange = largestChange;
    }
  }

  void considerOrientation(int leg1, int leg2, int hypotenuse) {
    final projection = ((firstCm * leg1 + secondCm * leg2) /
            (leg1 * leg1 + leg2 * leg2))
        .round();
    for (final scale in [projection - 1, projection, projection + 1]) {
      if (scale < 1) continue;
      consider(leg1 * scale, leg2 * scale, hypotenuse * scale);
    }
  }

  for (var m = 2; m * m + 1 <= maxPrimitiveC; m++) {
    for (var n = 1; n < m; n++) {
      final c = m * m + n * n;
      if (c > maxPrimitiveC || (m - n).isEven || _gcd(m, n) != 1) continue;
      final a = m * m - n * n, b = 2 * m * n;
      considerOrientation(a, b, c);
      considerOrientation(b, a, c);
    }
  }
  if (closest == null) {
    throw const FormatException('ترکیب صحیح نزدیک پیدا نشد.');
  }
  return closest!;
}
