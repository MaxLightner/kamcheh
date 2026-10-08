import 'demo_data.dart';
import 'marketplace.dart';

final skillCatalog = <String, List<String>>{
  for (final c in marketCategories) c.id: c.skills
};

List<String> adSkills(Ad ad) {
  if (ad.skills.isNotEmpty) return ad.skills;
  final text = '${ad.title} ${ad.description}';
  final candidates = {
    'کارگر عمومی': ['کارگر', 'کمک‌کار'],
    'بتن‌ریزی': ['بتن‌ریزی', 'اسکلت بتنی'],
    'دیوارچینی': ['دیوارچینی', 'بنایی'],
    'کمک‌کار بنایی': ['کمک‌کار'],
    'آرماتوربندی': ['آرماتور'],
    'داربست': ['داربست'],
    'اجرای ارت': ['ارت'],
    'برق ساختمان': ['برق'],
    'خاک‌برداری': ['خاک', 'گودبرداری'],
    'لوله‌کشی': ['لوله', 'تأسیسات'],
    'کاشی‌کاری': ['کاشی‌کاری'],
    'گچ و کناف': ['گچ', 'کناف'],
    'عایق‌کاری': ['عایق', 'ایزوگام'],
    'نقشه‌برداری': ['نقشه‌بردار'],
    'شن و ماسه': ['شن', 'ماسه'],
    'کاشی و سرامیک': ['کاشی', 'سرامیک'],
    'آجر و بلوک': ['آجر', 'بلوک'],
    'بتن آماده': ['بتن آماده'],
    'درب و پنجره': ['پنجره'],
    'دوربین نقشه‌برداری': ['دوربین'],
    'بالابر': ['بالابر'],
    'ابزار دستی': ['ابزار دستی', 'دریل'],
    'دستگاه جوش': ['جوش'],
    'موتور برق': ['موتور برق'],
    'تخته و قالب': ['قالب', 'تخته'],
    'تجهیزات قالب‌بندی': ['قالب'],
    'فرقون': ['فرقون'],
    'سنگ ساختمانی': ['سنگ'],
    'سنگ‌کاری': ['سنگ‌کاری', 'اجرای نما'],
    'حمل نخاله': ['نخاله'],
    'طراحی معماری': ['معماری'],
    'محاسبات سازه': ['محاسبات'],
    'نظارت ساختمان': ['نظارت'],
    'آزمایش خاک': ['آزمایش خاک'],
    'انشعاب برق': ['انشعاب برق'],
    'انشعاب آب': ['انشعاب آب'],
    'انشعاب گاز': ['انشعاب گاز'],
    'مشاوره مجوز ساخت': ['مجوز'],
    'مشارکت در ساخت': ['مشارکت', 'زمین'],
    'سهم پروژه': ['سهم'],
    'خرید و فروش ملک': ['واحد', 'ملک'],
    'پیش‌فروش': ['پیش‌فروش'],
    'ویبراتور بتن': ['ویبراتور'],
    'اجاره داربست': ['اجاره داربست'],
  };
  final allowed = skillCatalog[ad.category] ?? [];
  final result = candidates.entries
      .where((e) => allowed.contains(e.key) && e.value.any(text.contains))
      .map((e) => e.key)
      .toList();
  return result.isEmpty ? [allowed.first] : result;
}

const initialOwnAds = [
  Ad('own-labor', '۳ کارگر برای بتن‌ریزی', 'نیرو', true, 'کرج', 'گوهردشت',
      'concrete', 'روزانه با توافق', 'مهدی احمدی',
      people: 3,
      listingKind: AdKind.tender,
      startsAt: 'شنبه ساعت ۷ صبح',
      duration: '۲ روز',
      skills: ['بتن‌ریزی'],
      description:
          'برای بتن‌ریزی سقف به سه نیروی دارای تجربه نیاز داریم. ساعت و دستمزد پیش از شروع هماهنگ می‌شود.'),
  Ad('own-tile', 'خرید ۸۰ متر سرامیک کف', 'مصالح', true, 'کرج', 'گوهردشت',
      'tiles', 'دریافت پیشنهاد قیمت', 'مهدی احمدی',
      quantity: '۸۰ متر مربع',
      skills: ['کاشی و سرامیک'],
      description:
          'سرامیک کف طرح سنگ؛ پیشنهاد شامل قیمت، موجودی و هزینه حمل باشد.'),
  Ad('own-scaffold', 'داربست برای نمای ساختمان', 'خدمات', true, 'کرج',
      'گوهردشت', 'scaffold', 'برآورد پس از بازدید', 'مهدی احمدی',
      listingKind: AdKind.tender, skills: ['داربست'], duration: '۳۰ روز'),
  Ad('own-build', 'ساخت و اجرای ساختمان مسکونی', 'خدمات', false, 'کرج',
      'گوهردشت', 'concrete', 'با توافق', 'مهدی احمدی',
      skills: ['ساخت‌وساز', 'مدیریت پروژه']),
];

class WorkRequest {
  WorkRequest(this.adId);
  final String adId;
  String status = 'دریافت پیشنهاد';
  String? selectedBid;
  final bids = <BidOffer>[];
}

class BidOffer {
  BidOffer(this.id, this.adId, this.peer, this.price, this.time, this.terms,
      {this.mine = false});
  final String id, adId, peer, price, time, terms;
  final bool mine;
  String status = 'ارسال‌شده';
}

Map<String, WorkRequest> initialWorkRequests() {
  final result = {
    for (final a in initialOwnAds.where((a) => a.need)) a.id: WorkRequest(a.id)
  };
  for (final entry
      in ['علی رضایی', 'محمد کریمی', 'حسین موسوی'].asMap().entries) {
    result['own-labor']!.bids.add(BidOffer(
        'labor-${entry.key}',
        'own-labor',
        entry.value,
        ['۱٬۲۰۰٬۰۰۰', '۱٬۳۰۰٬۰۰۰', '۱٬۴۰۰٬۰۰۰'][entry.key] +
            ' تومان / نفر / روز',
        'شنبه ساعت ۷',
        'تجربه بتن‌ریزی سقف؛ دستمزد برای هر نفر در یک روز است.'));
  }
  result['own-tile']!.bids.addAll([
    BidOffer('tile-1', 'own-tile', 'نمایشگاه کاشی آریا', 'متری ۴۲۰٬۰۰۰ تومان',
        'تحویل یکشنبه', '۸۰ متر موجود؛ هزینه حمل جداگانه هماهنگ می‌شود.'),
    BidOffer('tile-2', 'own-tile', 'سرامیک پونک', 'متری ۴۵۰٬۰۰۰ تومان',
        'تحویل دوشنبه', 'پرسلان طرح سنگ؛ ارسال از تهران با هماهنگی.'),
  ]);
  result['own-scaffold']!.bids.add(BidOffer(
      'scaffold-1',
      'own-scaffold',
      'داربست رضایی',
      'پس از بازدید',
      'فردا صبح',
      'حمل، نصب و جمع‌آوری در پیشنهاد نهایی مشخص می‌شود.'));
  return result;
}

class VisitRecord {
  VisitRecord(
      this.id, this.threadId, this.peer, this.subject, this.time, this.location,
      {this.adId});
  final String id, threadId, peer, subject, time, location;
  final String? adId;
  String status = 'منتظر مراجعه';
}

class WorkReview {
  WorkReview(this.peer, this.contextId, this.subject, this.outcome, this.text,
      this.punctuality, this.quality,
      {this.subjectProfileId, this.authorProfileId, DateTime? at})
      : createdAt = at ?? DateTime.now();
  final String? subjectProfileId, authorProfileId;
  final DateTime createdAt;
  final String peer, contextId, subject, outcome, text;
  final int punctuality;
  final int? quality;
  String reply = '';
}

const demoProfiles = <String, ProviderProfile>{
  'مهدی احمدی': ProviderProfile('سازنده', ActivityType.individual),
  'علی رضایی': ProviderProfile('استاکار بتن', ActivityType.individual,
      identity: IdentityStatus.demoVerified),
  'محمد کریمی': ProviderProfile('کارگر عمومی', ActivityType.individual),
  'حسین موسوی': ProviderProfile('کارگر عمومی', ActivityType.individual),
  'داربست رضایی': ProviderProfile('پیمانکار داربست', ActivityType.crew,
      identity: IdentityStatus.demoVerified),
  'اکیپ محمدی': ProviderProfile('بنایی', ActivityType.crew),
  'بنایی محمدی': ProviderProfile('بنایی', ActivityType.crew,
      identity: IdentityStatus.demoVerified),
  'گروه سفید': ProviderProfile('گچ و کناف', ActivityType.crew),
  'نمایشگاه کاشی آریا': ProviderProfile('کاشی و سرامیک', ActivityType.shop,
      identity: IdentityStatus.demoVerified),
  'سرامیک پونک': ProviderProfile('کاشی و سرامیک', ActivityType.shop),
  'مصالح احمدی': ProviderProfile('تأمین مصالح', ActivityType.wholesale),
  'بلوک شرق': ProviderProfile('آجر و بلوک', ActivityType.producer),
  'بتن پارس': ProviderProfile('بتن آماده', ActivityType.producer),
  'معدن سنگ پارس': ProviderProfile('تأمین سنگ', ActivityType.wholesale,
      identity: IdentityStatus.demoVerified),
  'ابزار مرکزی': ProviderProfile('فروش ابزار', ActivityType.shop,
      identity: IdentityStatus.demoVerified),
  'تجهیزات سازه': ProviderProfile('فروش تجهیزات', ActivityType.wholesale),
  'تجهیزات دقیق شرق': ProviderProfile('اجاره تجهیزات', ActivityType.shop),
  'تجهیزات البرز': ProviderProfile('اجاره تجهیزات', ActivityType.individual),
  'مهندس کریمی': ProviderProfile('نقشه‌برداری', ActivityType.individual,
      identity: IdentityStatus.demoVerified),
  'دفتر مهندسی آبان': ProviderProfile('طراحی معماری', ActivityType.crew,
      identity: IdentityStatus.demoVerified),
  'برق ایمن البرز': ProviderProfile('اجرای ارت', ActivityType.crew),
  'خدمات انشعاب توس': ProviderProfile('انشعابات', ActivityType.crew),
  'مالک زمین گوهردشت': ProviderProfile('مالک زمین', ActivityType.individual),
  'سازنده آفتاب': ProviderProfile('سازنده', ActivityType.crew,
      identity: IdentityStatus.demoVerified),
};

ProviderProfile profileFor(Ad ad) =>
    ad.providerProfile ??
    demoProfiles[ad.owner] ??
    ProviderProfile(
        ad.category == 'نیرو'
            ? 'کارگر عمومی'
            : marketCategory(ad.category).shortLabel,
        ['مصالح', 'ابزار'].contains(ad.category)
            ? ActivityType.shop
            : ActivityType.individual);

const marketDemoAds = <Ad>[
  Ad('m01', 'سنگ تراورتن مستقیم از معدن', 'مصالح', false, 'کرج', 'مهرشهر',
      'tiles', 'قیمت عمده', 'معدن سنگ پارس',
      skills: ['سنگ ساختمانی'],
      pricing: MarketPrice(680000, PriceUnit.squareMeter),
      description:
          'تأمین عمده سنگ نما؛ هزینه حمل با توجه به محل پروژه اعلام می‌شود.'),
  Ad('m02', 'فروش دستگاه جوش اینورتر', 'ابزار', false, 'کرج', 'گوهردشت',
      'survey', 'قیمت دستگاه', 'ابزار مرکزی',
      skills: ['دستگاه جوش'], pricing: MarketPrice(14500000, PriceUnit.piece)),
  Ad('m03', 'تأمین عمده تجهیزات قالب‌بندی', 'ابزار', false, 'تهران', 'پونک',
      'scaffold', 'قیمت هر ست', 'تجهیزات سازه',
      skills: ['تجهیزات قالب‌بندی'],
      pricing: MarketPrice(22000000, PriceUnit.set)),
  Ad('m04', 'اجاره موتور برق برای پروژه', 'اجاره', false, 'کرج', 'گوهردشت',
      'survey', 'روزانه', 'تجهیزات البرز',
      skills: ['موتور برق'], pricing: MarketPrice(900000, PriceUnit.day)),
  Ad('m05', 'اجاره بالابر ساختمانی', 'اجاره', false, 'کرج', 'عظیمیه',
      'scaffold', 'روزانه', 'تجهیزات البرز',
      skills: ['بالابر'], pricing: MarketPrice(650000, PriceUnit.day)),
  Ad('m06', 'تخته و قالب برای اجاره', 'اجاره', false, 'مشهد', 'الهیه',
      'scaffold', 'ماهانه با توافق', 'تجهیزات توس',
      skills: ['تخته و قالب']),
  Ad('m07', 'طراحی معماری ساختمان مسکونی', 'مهندسی', false, 'کرج', 'جهانشهر',
      'concrete', 'بر اساس متراژ', 'دفتر مهندسی آبان',
      skills: ['طراحی معماری'],
      pricing: MarketPrice(180000, PriceUnit.squareMeter)),
  Ad('m08', 'پیمانکار انشعاب آب و برق', 'انشعابات', false, 'مشهد', 'سجاد',
      'survey', 'پس از بررسی محل', 'خدمات انشعاب توس',
      skills: ['انشعاب آب', 'انشعاب برق']),
  Ad('m09', 'زمین دارم؛ سازنده برای مشارکت می‌خواهم', 'سرمایه‌گذاری', true,
      'کرج', 'گوهردشت', 'concrete', 'شرایط با توافق', 'مالک زمین گوهردشت',
      listingKind: AdKind.partnership, skills: ['مشارکت در ساخت']),
  Ad('m10', 'فرصت مشارکت در سهم پروژه مسکونی', 'سرمایه‌گذاری', false, 'مشهد',
      'سجاد', 'concrete', 'جزئیات در گفت‌وگو', 'سازنده آفتاب',
      listingKind: AdKind.partnership, skills: ['سهم پروژه']),
  Ad('m11', 'فروش واحد در حال ساخت', 'سرمایه‌گذاری', false, 'کرج', 'عظیمیه',
      'concrete', 'قیمت هر متر', 'سازنده آفتاب',
      listingKind: AdKind.sale,
      skills: ['خرید و فروش ملک'],
      pricing: MarketPrice(65000000, PriceUnit.squareMeter)),
  Ad('m12', 'خریدار واحد مسکونی در حال ساخت', 'سرمایه‌گذاری', true, 'تهران',
      'پونک', 'concrete', 'بودجه با توافق', 'خریدار پونک',
      listingKind: AdKind.buy, skills: ['خرید و فروش ملک']),
];
