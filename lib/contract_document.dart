import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'persian_calendar.dart';

String preparedContractTerms(String template) => '''۱. حدود تعهد
${template == 'خدمات طراحی' ? 'خروجی‌های طراحی، فرمت تحویل و تعداد اصلاحات باید در شرح کار مشخص شود. استفاده از طرح خارج از موضوع توافق نیازمند توافق جداگانه است.' : template == 'توافق عمومی' ? 'تعهدات هر طرف محدود به موضوع و شرایط نوشته‌شده در این قرارداد است.' : 'مجری کار را مطابق شرح، مشخصات فنی و کیفیت توافق‌شده انجام می‌دهد؛ کار اضافی بدون توافق جدید تعهد محسوب نمی‌شود.'}

۲. پرداخت و تحویل
مبالغ، واحد پول، زمان‌بندی و مراحل پرداخت مطابق بخش مبلغ و مدت است. دریافت‌ها و تحویل کار با رسید یا تأیید مکتوب طرفین ثبت می‌شود.

۳. مصالح و ابزار
مسئول تهیه مصالح، ابزار، حمل و جمع‌آوری و هزینه هر یک در شرایط تکمیلی مشخص می‌شود. هیچ هزینه خارج از مبلغ توافق بدون پذیرش طرف مقابل اضافه نمی‌شود.

۴. تغییرات و توقف
تغییر دامنه، مبلغ یا زمان با الحاقیه مورد تأیید دو طرف ثبت می‌شود. در صورت توقف یا لغو، کار انجام‌شده و هزینه‌های پذیرفته‌شده صورت‌حساب می‌شود؛ جریمه‌ای خارج از توافق صریح اعمال نمی‌شود.

۵. کیفیت و مسئولیت
طرفین ایراد یا مانع اجرا را به یکدیگر اعلام می‌کنند و شیوه اصلاح و زمان آن را مکتوب مشخص می‌کنند. الزامات ایمنی و مسئولیت‌های مرتبط باید متناسب با موضوع کار در شرایط تکمیلی درج شود.

۶. اختلاف و پیوست‌ها
ابتدا اختلاف با گفتگو و ثبت نتیجه پیگیری می‌شود. روش رسیدگی مورد توافق در شرایط تکمیلی نوشته می‌شود. تصاویر و مدارک ضمیمه، همراه متن نهایی قبل از تأیید بررسی می‌شوند.''';

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
  final parties = <String, Map<String, String>>{};
  final partyDocuments = <String, List<Uint8List>>{};
  final signatures = <String, String>{};
  bool get bilateral => parties.length == 2;
  void invalidateApprovals() {
    signatures.clear();
    status = 'در انتظار تکمیل و تأیید طرفین';
  }

  String? get signingError {
    if (!bilateral) return 'طرفین قرارداد مشخص نشده‌اند.';
    for (final p in parties.values) {
      for (final key in ['نام', 'شماره تماس', 'شناسه هویتی', 'نشانی']) {
        if ((p[key] ?? '').trim().isEmpty)
          return 'اطلاعات هر دو طرف باید تکمیل شود: $key';
      }
    }
    for (final key in [
      'موضوع و محل',
      'مبلغ (تومان)',
      'زمان شروع و مدت',
      'شیوه پرداخت',
      'شرایط توافق'
    ]) {
      if ((values[key] ?? '').trim().isEmpty) return '$key را تکمیل کن.';
    }
    return null;
  }

  ContractRevision finalize() {
    final error = signingError;
    if (error != null) throw FormatException(error);
    if (signatures.length != 2 || !parties.keys.every(signatures.containsKey))
      throw const FormatException('تأیید و امضای هر دو طرف لازم است.');
    values['طرفین'] = parties.values
        .map((p) => p.entries.map((e) => '${e.key}: ${e.value}').join('\n'))
        .join('\n\n');
    values['تأیید و امضای طرفین'] = parties.entries
        .map((e) => '${e.value['نام']} · ${signatures[e.key]}')
        .join('\n');
    values['فهرست مدارک طرفین'] = parties.entries
        .map((e) =>
            '${e.value['نام']}: ${partyDocuments[e.key]?.length ?? 0} تصویر پیوست')
        .join('\n');
    final revision = ContractRevision(
        number: revisions.length + 1,
        title: title,
        template: template,
        values: values,
        photos: [
          ...photos,
          ...parties.keys.expand((id) => partyDocuments[id] ?? <Uint8List>[])
        ],
        createdAt: DateTime.now(),
        parentId: parentId);
    revisions.add(revision);
    status = 'تأیید دوطرفه · نسخه ${revision.number}';
    return revision;
  }

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
                    ? '${revision.values.containsKey('تأیید و امضای طرفین') ? 'قرارداد' : 'پیش‌نویس قرارداد'} ${revision.template}'
                    : 'الحاقیه قرارداد',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(revision.title),
            pw.Text(
                'نسخه ${pdfFa(revision.number)} · تاریخ: ${jalaliDate(revision.createdAt)}',
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
                revision.values.containsKey('تأیید و امضای طرفین')
                    ? 'تأییدهای درج‌شده در نسخه آزمایشی محلی ثبت شده‌اند؛ امضای الکترونیکی احراز‌شده نیستند.'
                    : 'این فایل پیش‌نویس نسخه آزمایشی است. ثبت در اپ یا دریافت فایل، امضای طرفین محسوب نمی‌شود.',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 18),
            if (!revision.values.containsKey('تأیید و امضای طرفین'))
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
