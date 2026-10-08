import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ContractRevision {
  ContractRevision(
      {required this.number,
      required this.title,
      required this.template,
      required Map<String, String> values,
      required List<Uint8List> photos,
      required this.createdAt,
      this.parentId})
      : values = Map.unmodifiable(values),
        photos = List.unmodifiable(
            photos.map((p) => Uint8List.fromList(p).asUnmodifiableView()));
  final int number;
  final String title, template;
  final String? parentId;
  final DateTime createdAt;
  final Map<String, String> values;
  final List<Uint8List> photos;
}

class ContractDraft {
  ContractDraft(this.title, this.values,
      {this.template = 'اجرای کار', this.parentId, String? restoredId})
      : id = restoredId ??
            'contract-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;
  final String id, title, template;
  final String? parentId;
  final Map<String, String> values;
  String status = 'پیش‌نویس';
  String? threadId;
  final photos = <Uint8List>[];
  final revisions = <ContractRevision>[];
  String? get validationError {
    for (final key in ['طرفین', 'موضوع و محل', 'مبلغ و مدت', 'شرایط توافق']) {
      final text = values[key]?.trim() ?? '';
      if (text.isEmpty ||
          [
            'نام و مشخصات طرفین را وارد کن',
            'مبلغ، زمان شروع و مدت همکاری',
            'تعهدات طرفین و شرایط توافق'
          ].contains(text)) return '«$key» را تکمیل کن.';
    }
    return null;
  }

  ContractRevision saveRevision() {
    final error = validationError;
    if (error != null) throw FormatException(error);
    final revision = ContractRevision(
        number: revisions.length + 1,
        title: title,
        template: template,
        values: values,
        photos: photos,
        createdAt: DateTime.now(),
        parentId: parentId);
    revisions.add(revision);
    status = 'نسخه ${revision.number} ذخیره شد';
    return revision;
  }
}

/// Demo layout only. Production templates are supplied and reviewed separately.
String pdfFa(Object value) => value
    .toString()
    .replaceAllMapped(RegExp(r'[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);

Future<Uint8List> buildContractPdf(ContractRevision revision) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'));
  final document = pw.Document();
  document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (ctx) => pw.Text(
          'کمچه · نسخه آزمایشی · صفحه ${pdfFa(ctx.pageNumber)} از ${pdfFa(ctx.pagesCount)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      build: (_) => [
            pw.Text(
                revision.parentId == null
                    ? 'پیش‌نویس قرارداد ${revision.template}'
                    : 'پیش‌نویس الحاقیه قرارداد',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(revision.title),
            pw.Text(
                'نسخه ${pdfFa(revision.number)} · تاریخ: ${pdfFa('${revision.createdAt.year}/${revision.createdAt.month}/${revision.createdAt.day}')}',
                style: const pw.TextStyle(fontSize: 9)),
            if (revision.parentId != null)
              pw.Text('ارجاع به قرارداد: ${revision.parentId}',
                  style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 14),
            ...revision.values.entries.expand((e) => [
                  pw.Text(e.key,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Text(e.value,
                      style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)),
                  pw.SizedBox(height: 14),
                ]),
            pw.Text(
                'این فایل پیش‌نویس نسخه آزمایشی است. ثبت در اپ یا دریافت فایل، امضای طرفین محسوب نمی‌شود.',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 18),
            pw.Text(
                'محل امضای طرف اول:                       محل امضای طرف دوم:'),
            ...revision.photos.asMap().entries.expand((e) => [
                  pw.NewPage(),
                  pw.Text('پیوست ${e.key + 1} · نسخه ${revision.number}'),
                  pw.SizedBox(height: 12),
                  pw.Center(
                      child: pw.Image(pw.MemoryImage(e.value),
                          height: 500, fit: pw.BoxFit.contain)),
                ])
          ]));
  return document.save();
}

Uri? publicProfileUrl(String id, {Uri? current, String configuredBase = ''}) {
  final base = Uri.tryParse(configuredBase.isNotEmpty
      ? configuredBase
      : (current ?? Uri.base).toString());
  if (base == null ||
      !['http', 'https'].contains(base.scheme) ||
      base.host.isEmpty) return null;
  return base.replace(queryParameters: {'profile': id}, fragment: '');
}
