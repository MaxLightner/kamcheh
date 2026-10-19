import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centimetres are the only input unit. Persian and Arabic digits are accepted.
double parseSquaringCentimeters(String raw) {
  final normalized = raw.trim()
      .replaceAllMapped(RegExp(r'[۰-۹]'),
          (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
      .replaceAllMapped(RegExp(r'[٠-٩]'),
          (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString())
      .replaceAll('٬', '')
      .replaceAll('٫', '.')
      .replaceAll(',', '.');
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite || value <= 0 || value > 1000000) {
    throw const FormatException('طول هر دو ضلع باید عدد مثبت و معتبر به سانتی‌متر باشد.');
  }
  return value;
}

/// The expected diagonal of a *right* triangle, in centimetres.
double rightAngleDiagonalCm(double firstCm, double secondCm) {
  if (!firstCm.isFinite || !secondCm.isFinite ||
      firstCm <= 0 || secondCm <= 0 ||
      firstCm > 1000000 || secondCm > 1000000) {
    throw const FormatException('اندازه ضلع‌ها معتبر نیست.');
  }
  return math.sqrt(firstCm * firstCm + secondCm * secondCm);
}

String formatDiagonalCm(double value, {required bool roundToWholeCm}) {
  if (roundToWholeCm) return value.round().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _faDigits(String value) =>
    value.replaceAllMapped(RegExp('[0-9]'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);

/// A local construction-site tool. It neither requires nor writes backend data.
class SquaringTool extends StatefulWidget {
  const SquaringTool({super.key});

  @override
  State<SquaringTool> createState() => _SquaringToolState();
}

class _SquaringToolState extends State<SquaringTool> {
  final _first = TextEditingController(text: '300');
  final _second = TextEditingController(text: '400');
  bool _roundToWholeCm = true;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double? diagonal;
    String? error;
    try {
      diagonal = rightAngleDiagonalCm(
        parseSquaringCentimeters(_first.text),
        parseSquaringCentimeters(_second.text),
      );
    } on FormatException catch (e) {
      error = e.message;
    }

    final diagonalText = diagonal == null
        ? '—'
        : _faDigits(formatDiagonalCm(
            diagonal, roundToWholeCm: _roundToWholeCm));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('روش گونیا کردن', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'از گوشه موردنظر، روی دو امتداد ضلع‌ها فاصله‌هایی را علامت بزن. '
          'سپس فاصله بین دو علامت را با متر اندازه بگیر. '
          'اگر آن فاصله با وتر محاسبه‌شده برابر باشد، زاویه ۹۰ درجه است.',
          style: TextStyle(fontSize: 13, height: 1.9),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text('وتر = √(ضلع اول² + ضلع دوم²)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('طول ضلع‌ها را روی شکل وارد کن',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SizedBox(
                height: 278,
                child: LayoutBuilder(builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return CustomPaint(
                    painter: const _RightTrianglePainter(),
                    child: Stack(children: [
                      Positioned(
                        left: w * .17,
                        top: 100,
                        child: _SideInput(
                          label: 'ضلع اول',
                          controller: _first,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      Positioned(
                        left: w * .54,
                        top: 194,
                        child: _SideInput(
                          label: 'ضلع دوم',
                          controller: _second,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      Positioned(
                        left: w * .52,
                        top: 34,
                        child: Container(
                          width: w * .43,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECF5FF),
                            border: Border.all(
                                color: const Color(0xFFBBD8FB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            const Text('وتر', style: TextStyle(
                                fontSize: 11, color: Color(0xFF24518A))),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('$diagonalText سانتی‌متر',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF174579))),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  );
                }),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(error, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('رند کردن وتر به سانتی‌متر',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('بدون نیاز به خواندن میلی‌متر',
                    style: TextStyle(fontSize: 11)),
                value: _roundToWholeCm,
                onChanged: (v) => setState(() => _roundToWholeCm = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'نکته: این عدد، وتر مورد انتظار است؛ برای اطمینان از گونیا بودن '
          'باید وتر واقعی را هم روی کار اندازه بگیری. '
          'رند کردن می‌تواند تا نیم سانتی‌متر اختلاف ایجاد کند.',
          style: TextStyle(fontSize: 12, color: Color(0xFF667085), height: 1.8),
        ),
      ],
    );
  }
}

class _SideInput extends StatelessWidget {
  const _SideInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 108,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                textAlign: TextAlign.center,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      vertical: 10, horizontal: 5),
                  suffixText: 'cm',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
}

class _RightTrianglePainter extends CustomPainter {
  const _RightTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(size.width * .12, size.height * .13);
    final corner = Offset(size.width * .12, size.height * .91);
    final b = Offset(size.width * .90, size.height * .91);
    final sidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB34143);
    final hypotenuse = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2866A5);
    canvas.drawLine(a, corner, sidePaint);
    canvas.drawLine(corner, b, sidePaint);
    canvas.drawLine(a, b, hypotenuse);

    // Mark the right angle at the shared end of the two measured sides.
    const marker = 18.0;
    final square = Path()
      ..moveTo(corner.dx, corner.dy - marker)
      ..lineTo(corner.dx + marker, corner.dy - marker)
      ..lineTo(corner.dx + marker, corner.dy);
    canvas.drawPath(square, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB34143));
  }

  @override
  bool shouldRepaint(covariant _RightTrianglePainter oldDelegate) => false;
}
