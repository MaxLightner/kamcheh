enum AdKind {
  need('نیاز دارم'),
  offer('ارائه می‌کنم'),
  tender('مناقصه'),
  sale('فروش'),
  rental('اجاره'),
  partnership('مشارکت'),
  buy('خرید');

  const AdKind(this.label);
  final String label;
}

enum ActivityType {
  individual('فرد'),
  crew('اکیپ'),
  shop('فروشگاه'),
  wholesale('عمده‌فروش'),
  producer('تولیدکننده'),
  company('شرکت');

  const ActivityType(this.label);
  final String label;
}

enum IdentityStatus { unverified, demoVerified }

class ProviderProfile {
  const ProviderProfile(this.specialty, this.activity,
      {this.identity = IdentityStatus.unverified});
  final String specialty;
  final ActivityType activity;
  final IdentityStatus identity;
  bool get verified => identity == IdentityStatus.demoVerified;
}

enum PriceUnit {
  project('کل کار'),
  personDay('نفر / روز'),
  meter('متر'),
  squareMeter('متر مربع'),
  cubicMeter('متر مکعب'),
  ton('تن'),
  piece('عدد'),
  set('دستگاه / ست'),
  day('روز'),
  week('هفته'),
  month('ماه');

  const PriceUnit(this.label);
  final String label;
}

class MarketPrice {
  const MarketPrice(this.amount, this.unit) : assert(amount > 0);
  final int amount;
  final PriceUnit unit;
}

class MarketCategory {
  const MarketCategory(this.id, this.label, this.shortLabel, this.skills,
      this.kinds, this.priceUnits, this.asset);
  final String id, label, shortLabel, asset;
  final List<String> skills;
  final List<AdKind> kinds;
  final List<PriceUnit> priceUnits;
}

const allMarketCategories = <MarketCategory>[
  MarketCategory(
      'نیرو',
      'کارگر و اکیپ',
      'کارگر و اکیپ',
      ['کارگر عمومی', 'بتن‌ریزی', 'دیوارچینی', 'کمک‌کار بنایی', 'آرماتوربندی'],
      [AdKind.need, AdKind.offer, AdKind.tender],
      [PriceUnit.personDay, PriceUnit.project, PriceUnit.squareMeter],
      'worker'),
  MarketCategory(
      'خدمات',
      'پیمانکاری و اجرا',
      'پیمانکاری',
      [
        'ساخت‌وساز',
        'مدیریت پروژه',
        'داربست',
        'برق ساختمان',
        'خاک‌برداری',
        'لوله‌کشی',
        'کاشی‌کاری',
        'گچ و کناف',
        'عایق‌کاری',
        'سنگ‌کاری',
        'حمل نخاله'
      ],
      [AdKind.need, AdKind.offer, AdKind.tender],
      [
        PriceUnit.project,
        PriceUnit.squareMeter,
        PriceUnit.meter,
        PriceUnit.cubicMeter
      ],
      'scaffold'),
  MarketCategory(
      'مصالح',
      'تأمین مصالح',
      'تأمین مصالح',
      [
        'شن و ماسه',
        'کاشی و سرامیک',
        'آجر و بلوک',
        'بتن آماده',
        'درب و پنجره',
        'سنگ ساختمانی'
      ],
      [AdKind.need, AdKind.sale, AdKind.tender],
      [
        PriceUnit.squareMeter,
        PriceUnit.cubicMeter,
        PriceUnit.ton,
        PriceUnit.piece,
        PriceUnit.meter
      ],
      'tiles'),
  MarketCategory(
      'ابزار',
      'تأمین ابزار و تجهیزات',
      'فروش ابزار',
      [
        'دستگاه جوش',
        'موتور برق',
        'بالابر',
        'تجهیزات قالب‌بندی',
        'ابزار دستی',
        'دوربین نقشه‌برداری'
      ],
      [AdKind.need, AdKind.sale, AdKind.tender],
      [PriceUnit.piece, PriceUnit.set],
      'survey'),
  MarketCategory(
      'اجاره',
      'اجاره تجهیزات ساختمانی',
      'اجاره تجهیزات',
      [
        'تخته و قالب',
        'اجاره داربست',
        'فرقون',
        'بالابر',
        'دستگاه جوش',
        'موتور برق',
        'ویبراتور بتن',
        'دوربین نقشه‌برداری'
      ],
      [AdKind.need, AdKind.rental, AdKind.tender],
      [PriceUnit.day, PriceUnit.week, PriceUnit.month],
      'scaffold'),
  MarketCategory(
      'مهندسی',
      'خدمات مهندسی',
      'خدمات مهندسی',
      [
        'نقشه‌برداری',
        'طراحی معماری',
        'محاسبات سازه',
        'نظارت ساختمان',
        'آزمایش خاک'
      ],
      [AdKind.need, AdKind.offer, AdKind.tender],
      [PriceUnit.project, PriceUnit.squareMeter],
      'survey'),
  MarketCategory(
      'انشعابات',
      'مجوزها و انشعابات',
      'مجوز و انشعاب',
      [
        'اجرای ارت',
        'انشعاب برق',
        'انشعاب آب',
        'انشعاب گاز',
        'مشاوره مجوز ساخت'
      ],
      [AdKind.need, AdKind.offer, AdKind.tender],
      [PriceUnit.project],
      'survey'),
  MarketCategory(
      'سرمایه‌گذاری',
      'سرمایه‌گذاری و مشارکت',
      'سرمایه‌گذاری',
      ['مشارکت در ساخت', 'سهم پروژه', 'خرید و فروش ملک', 'پیش‌فروش'],
      [AdKind.partnership, AdKind.buy, AdKind.sale],
      [PriceUnit.project, PriceUnit.squareMeter],
      'concrete'),
];

final marketCategories = allMarketCategories
    .where((c) => ['نیرو', 'خدمات', 'مهندسی'].contains(c.id))
    .map((c) => c.id == 'مهندسی'
        ? const MarketCategory(
            'مهندسی',
            'طراحی ساختمان',
            'طراحی',
            ['طراحی معماری', 'محاسبات سازه', 'طراحی داخلی'],
            [AdKind.need, AdKind.offer],
            [PriceUnit.project, PriceUnit.squareMeter],
            'survey')
        : MarketCategory(c.id, c.label, c.shortLabel, c.skills,
            [AdKind.need, AdKind.offer], c.priceUnits, c.asset))
    .toList();

MarketCategory marketCategory(String id) =>
    marketCategories.where((c) => c.id == id).firstOrNull ??
    allMarketCategories.firstWhere((c) => c.id == id);

AdKind defaultAdKind(String category, bool need) {
  if (category == 'سرمایه‌گذاری') return AdKind.partnership;
  if (need) return AdKind.need;
  if (category == 'مصالح' || category == 'ابزار') return AdKind.sale;
  if (category == 'اجاره') return AdKind.rental;
  if (category == 'سرمایه‌گذاری') return AdKind.partnership;
  return AdKind.offer;
}

String normalizeMarketText(String value) => value
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('‌', ' ')
    .replaceAllMapped(
        RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
    .replaceAllMapped(
        RegExp(r'[٠-٩]'), (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString())
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

int? parsePriceInput(String value) {
  final normalized =
      normalizeMarketText(value).replaceAll(RegExp(r'[,٬ ]'), '');
  if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
  return int.tryParse(normalized);
}
