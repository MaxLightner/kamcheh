import 'package:flutter/material.dart';

double positiveNumber(String input) {
  final normalized = input
      .replaceAllMapped(
          RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
      .replaceAll('٫', '.');
  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite || value <= 0 || value > 1000000) {
    throw const FormatException('عدد مثبت و معتبر وارد کن.');
  }
  return value;
}

class MaterialEstimate {
  const MaterialEstimate(this.volume, this.cementKg, this.bags);
  final double volume, cementKg;
  final int bags;
  static MaterialEstimate calculate(
      {required double area,
      required double thicknessCm,
      required double dosageKgPerM3,
      required double bagWeightKg,
      double wastePercent = 0}) {
    if ([area, thicknessCm, dosageKgPerM3, bagWeightKg]
            .any((v) => !v.isFinite || v <= 0) ||
        !wastePercent.isFinite ||
        wastePercent < 0 ||
        wastePercent > 100) {
      throw const FormatException('مقادیر محاسبه معتبر نیستند.');
    }
    final volume = area * thicknessCm / 100 * (1 + wastePercent / 100);
    final cement = volume * dosageKgPerM3;
    if (!cement.isFinite || cement > 1e12)
      throw const FormatException('مقدار بیش از حد بزرگ است.');
    return MaterialEstimate(volume, cement, (cement / bagWeightKg).ceil());
  }

  static int tiles(
      {required double area,
      required double widthCm,
      required double heightCm,
      double wastePercent = 0}) {
    if ([area, widthCm, heightCm].any((v) => !v.isFinite || v <= 0) ||
        !wastePercent.isFinite ||
        wastePercent < 0 ||
        wastePercent > 100) {
      throw const FormatException('مقادیر محاسبه معتبر نیستند.');
    }
    final count =
        area * (1 + wastePercent / 100) / (widthCm * heightCm / 10000);
    if (!count.isFinite || count > 1e12)
      throw const FormatException('مقدار بیش از حد بزرگ است.');
    return count.ceil();
  }
}

class MaterialEstimator extends StatefulWidget {
  const MaterialEstimator({super.key});
  @override
  State<MaterialEstimator> createState() => _MaterialEstimatorState();
}

class _MaterialEstimatorState extends State<MaterialEstimator> {
  String category = 'بتن', result = '', error = '';
  final area = TextEditingController(),
      thickness = TextEditingController(),
      dosage = TextEditingController(),
      bag = TextEditingController(text: '50'),
      width = TextEditingController(),
      height = TextEditingController(),
      waste = TextEditingController(text: '0');
  @override
  void dispose() {
    for (final c in [area, thickness, dosage, bag, width, height, waste]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(String label, TextEditingController controller) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {
                result = '';
                error = '';
              })));
  void calculate() {
    try {
      final wasteValue = double.tryParse(waste.text
          .replaceAllMapped(
              RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
          .replaceAll('٫', '.'));
      if (wasteValue == null)
        throw const FormatException('درصد پرت معتبر وارد کن.');
      final a = positiveNumber(area.text);
      if (category == 'کاشی') {
        final count = MaterialEstimate.tiles(
            area: a,
            widthCm: positiveNumber(width.text),
            heightCm: positiveNumber(height.text),
            wastePercent: wasteValue);
        setState(() {
          result = '$count عدد کاشی، با گرد کردن رو به بالا';
          error = '';
        });
      } else {
        final r = MaterialEstimate.calculate(
            area: a,
            thicknessCm: positiveNumber(thickness.text),
            dosageKgPerM3: positiveNumber(dosage.text),
            bagWeightKg: positiveNumber(bag.text),
            wastePercent: wasteValue);
        setState(() {
          result =
              'حجم: ${r.volume.toStringAsFixed(2)} مترمکعب\nسیمان: ${r.cementKg.toStringAsFixed(1)} کیلوگرم\nتعداد کیسه: ${r.bags}';
          error = '';
        });
      }
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        result = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('برآورد ساده مصالح؛ مقادیر مصرف را خودت تعیین کن.'),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            children: ['بتن', 'ملات', 'کاشی']
                .map((c) => ChoiceChip(
                    label: Text(c),
                    selected: c == category,
                    onSelected: (_) => setState(() {
                          category = c;
                          result = '';
                          error = '';
                        })))
                .toList()),
        field('مساحت · مترمربع', area),
        if (category == 'کاشی') ...[
          field('عرض کاشی · سانتی‌متر', width),
          field('طول کاشی · سانتی‌متر', height)
        ] else ...[
          field('ضخامت · سانتی‌متر', thickness),
          field('مصرف سیمان در هر مترمکعب · کیلوگرم', dosage),
          field('وزن هر کیسه · کیلوگرم', bag)
        ],
        field('پرت · درصد، از ۰ تا ۱۰۰', waste),
        const SizedBox(height: 8),
        FilledButton(onPressed: calculate, child: const Text('محاسبه')),
        if (error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error, style: const TextStyle(color: Colors.red))),
        if (result.isNotEmpty)
          Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF2F7F5),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(result)),
        const SizedBox(height: 12),
        const Text(
            'این محاسبه برآورد مقدار خرید است. عیار و ترکیب مصالح را از مشخصات پروژه وارد کن.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]);
}
