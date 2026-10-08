import 'dart:typed_data';
import 'marketplace.dart';

class CityArea {
  const CityArea(this.province, this.name, this.lat, this.lon, this.districts,
      {this.nearby = const []});
  final String province, name;
  final double lat, lon;
  final List<String> districts, nearby;
}

const cities = [
  CityArea('خراسان رضوی', 'مشهد', 36.30, 59.58,
      ['قاسم‌آباد', 'الهیه', 'سجاد', 'احمدآباد', 'وکیل‌آباد', 'طبرسی'],
      nearby: ['طرقبه', 'شاندیز', 'گلبهار', 'چناران']),
  CityArea(
      'خراسان رضوی', 'طرقبه', 36.31, 59.37, ['مرکز طرقبه', 'جاغرق', 'عنبران'],
      nearby: ['مشهد', 'شاندیز']),
  CityArea('خراسان رضوی', 'شاندیز', 36.39, 59.30, ['مرکز شاندیز', 'ابرده'],
      nearby: ['مشهد', 'طرقبه']),
  CityArea('خراسان رضوی', 'گلبهار', 36.57, 59.18, ['مرکز گلبهار', 'بهارستان'],
      nearby: ['چناران', 'مشهد']),
  CityArea('خراسان رضوی', 'چناران', 36.64, 59.12, ['مرکز چناران'],
      nearby: ['گلبهار']),
  CityArea('البرز', 'کرج', 35.84, 50.97,
      ['گوهردشت', 'عظیمیه', 'مهرشهر', 'جهانشهر', 'حصارک'],
      nearby: ['فردیس', 'ماهدشت']),
  CityArea(
      'البرز', 'فردیس', 35.73, 50.99, ['فلکه اول', 'فلکه پنجم', 'مشکین‌دشت'],
      nearby: ['کرج']),
  CityArea('البرز', 'ماهدشت', 35.73, 50.81, ['مرکز ماهدشت'], nearby: ['کرج']),
  CityArea('تهران', 'تهران', 35.72, 51.39,
      ['صادقیه', 'تهرانپارس', 'پونک', 'سعادت‌آباد', 'شهرری'],
      nearby: ['قدس', 'شهریار']),
  CityArea('تهران', 'قدس', 35.72, 51.11, ['مرکز شهر قدس'],
      nearby: ['شهریار', 'تهران']),
  CityArea('تهران', 'شهریار', 35.66, 51.06, ['مرکز شهریار', 'اندیشه'],
      nearby: ['قدس', 'تهران']),
  CityArea(
      'فارس', 'شیراز', 29.61, 52.53, ['معالی‌آباد', 'قصرالدشت', 'فرهنگ‌شهر']),
  CityArea('اصفهان', 'اصفهان', 32.65, 51.67,
      ['مرداویج', 'سپاهان‌شهر', 'خانه اصفهان']),
  CityArea(
      'آذربایجان شرقی', 'تبریز', 38.07, 46.30, ['ولیعصر', 'رشدیه', 'باغمیشه']),
  CityArea('گیلان', 'رشت', 37.28, 49.59, ['گلسار', 'معلم', 'منظریه']),
  CityArea('آذربایجان غربی', 'ارومیه', 37.55, 45.07, ['مرکز شهر']),
  CityArea('اردبیل', 'اردبیل', 38.25, 48.30, ['مرکز شهر']),
  CityArea('ایلام', 'ایلام', 33.64, 46.42, ['مرکز شهر']),
  CityArea('بوشهر', 'بوشهر', 28.92, 50.84, ['مرکز شهر']),
  CityArea('چهارمحال و بختیاری', 'شهرکرد', 32.33, 50.86, ['مرکز شهر']),
  CityArea('خراسان جنوبی', 'بیرجند', 32.86, 59.22, ['مرکز شهر']),
  CityArea('خراسان شمالی', 'بجنورد', 37.47, 57.33, ['مرکز شهر']),
  CityArea('خوزستان', 'اهواز', 31.32, 48.67, ['کیانپارس', 'زیتون کارمندی']),
  CityArea('زنجان', 'زنجان', 36.67, 48.49, ['مرکز شهر']),
  CityArea('سمنان', 'سمنان', 35.57, 53.40, ['مرکز شهر']),
  CityArea('سیستان و بلوچستان', 'زاهدان', 29.50, 60.86, ['مرکز شهر']),
  CityArea('قزوین', 'قزوین', 36.28, 50.00, ['مرکز شهر']),
  CityArea('قم', 'قم', 34.64, 50.88, ['پردیسان', 'سالاریه']),
  CityArea('کردستان', 'سنندج', 35.31, 46.99, ['مرکز شهر']),
  CityArea('کرمان', 'کرمان', 30.28, 57.08, ['مرکز شهر']),
  CityArea('کرمانشاه', 'کرمانشاه', 34.31, 47.07, ['مرکز شهر']),
  CityArea('کهگیلویه و بویراحمد', 'یاسوج', 30.67, 51.59, ['مرکز شهر']),
  CityArea('گلستان', 'گرگان', 36.84, 54.43, ['مرکز شهر']),
  CityArea('لرستان', 'خرم‌آباد', 33.48, 48.35, ['مرکز شهر']),
  CityArea('مازندران', 'ساری', 36.57, 53.06, ['مرکز شهر']),
  CityArea('مرکزی', 'اراک', 34.09, 49.69, ['مرکز شهر']),
  CityArea('هرمزگان', 'بندرعباس', 27.19, 56.28, ['مرکز شهر']),
  CityArea('همدان', 'همدان', 34.80, 48.52, ['مرکز شهر']),
  CityArea('یزد', 'یزد', 31.90, 54.37, ['صفائیه', 'مرکز شهر']),
];
CityArea cityByName(String name) => cities.firstWhere((c) => c.name == name);
final demoCities = cities.where((c) => c.province == 'خراسان رضوی').toList();

/// Keep the full city catalogue available for later expansion.
Ad localDemoAd(Ad ad) {
  if (ad.province == 'خراسان رضوی') return ad;
  return ad.copyWith(
      city: 'مشهد',
      district: switch (ad.district) {
        'گوهردشت' => 'الهیه',
        'عظیمیه' => 'سجاد',
        'مهرشهر' => 'وکیل‌آباد',
        _ => 'قاسم‌آباد'
      },
      serviceArea: const AreaFilter(
          province: 'خراسان رضوی', city: 'مشهد', surroundings: true),
      point: ad.point == null ? null : const MapPoint(36.30, 59.58),
      title: ad.title.replaceAll('کرج', 'مشهد').replaceAll('گوهردشت', 'الهیه'),
      description: ad.description
          .replaceAll('کرج', 'مشهد')
          .replaceAll('گوهردشت', 'الهیه'));
}

class MapPoint {
  const MapPoint(this.latitude, this.longitude);
  final double latitude, longitude;
}

class AdLocation {
  const AdLocation(this.area, this.point);
  final AreaFilter area;
  final MapPoint? point;
}

class AreaFilter {
  const AreaFilter(
      {this.province,
      this.city,
      this.districts = const {},
      this.surroundings = false});
  final String? province, city;
  final Set<String> districts;
  final bool surroundings;
  String get label => city != null
      ? '$city${districts.isNotEmpty ? ' · ${districts.length == 1 ? districts.first : '${districts.length} محله'}' : ''}${surroundings ? ' و حومه' : ''}'
      : province ?? 'همه مناطق';
  bool matches(Ad ad) {
    if (_matchesPlace(ad.city, ad.district)) return true;
    // A request is tied to its project site. Offers may serve another area.
    if (ad.need || ad.serviceArea == null) return false;
    final service = ad.serviceArea!;
    final serviceProvince = service.province ??
        (service.city == null ? null : cityByName(service.city!).province);
    if (province != null &&
        serviceProvince != null &&
        province != serviceProvince) return false;
    if (city == null || service.city == null) return true;
    final searchCities = {city!, if (surroundings) ...cityByName(city!).nearby};
    final serviceCities = {
      service.city!,
      if (service.surroundings) ...cityByName(service.city!).nearby
    };
    if (searchCities.intersection(serviceCities).isEmpty) return false;
    if (city != service.city || districts.isEmpty || service.districts.isEmpty)
      return true;
    return districts.intersection(service.districts).isNotEmpty;
  }

  bool _matchesPlace(String adCity, String adDistrict) {
    if (province != null && cityByName(adCity).province != province)
      return false;
    if (city == null) return true;
    if (adCity != city)
      return surroundings && cityByName(city!).nearby.contains(adCity);
    return districts.isEmpty ||
        adDistrict.isEmpty ||
        adDistrict == 'تمام شهر' ||
        districts.contains(adDistrict);
  }
}

class Ad {
  const Ad(this.id, this.title, this.category, this.need, this.city,
      this.district, this.image, this.price, this.owner,
      {this.time = 'امروز',
      this.description = '',
      this.rating = '۴٫۷',
      this.startsAt = '',
      this.quantity = '',
      this.duration = '',
      this.listingKind,
      this.pricing,
      this.point,
      this.serviceArea,
      this.providerProfile,
      this.skills = const [],
      this.photos = const [],
      this.people = 0});
  final String id,
      title,
      category,
      city,
      district,
      image,
      price,
      owner,
      time,
      description,
      startsAt,
      quantity,
      duration,
      rating;
  final List<String> skills;
  final AdKind? listingKind;
  final MarketPrice? pricing;
  final MapPoint? point;
  final AreaFilter? serviceArea;
  final ProviderProfile? providerProfile;
  AdKind get kind => listingKind ?? defaultAdKind(category, need);
  final List<Uint8List> photos;
  final bool need;
  final int people;
  String get province => cityByName(city).province;
  String get area =>
      district.isEmpty || district == 'تمام شهر' ? city : '$city · $district';
  Ad copyWith(
          {String? title,
          String? city,
          String? district,
          AreaFilter? serviceArea,
          MapPoint? point,
          String? description,
          String? owner,
          ProviderProfile? providerProfile,
          AdKind? kind}) =>
      Ad(id, title ?? this.title, category, need, city ?? this.city,
          district ?? this.district, image, price, owner ?? this.owner,
          time: time,
          description: description ?? this.description,
          rating: rating,
          people: people,
          startsAt: startsAt,
          quantity: quantity,
          duration: duration,
          listingKind: kind ?? listingKind,
          pricing: pricing,
          point: point ?? this.point,
          serviceArea: serviceArea ?? this.serviceArea,
          providerProfile: providerProfile ?? this.providerProfile,
          skills: skills,
          photos: photos);
}

const demoAds = <Ad>[
  Ad('a01', 'اجرای داربست ساختمانی', 'خدمات', false, 'کرج', 'گوهردشت',
      'scaffold', 'قیمت با توافق', 'داربست رضایی',
      serviceArea:
          AreaFilter(province: 'البرز', city: 'کرج', surroundings: true)),
  Ad('a02', 'تأمین شن و ماسه با حمل', 'مصالح', false, 'کرج', 'مهرشهر', 'sand',
      'استعلام قیمت و حمل', 'مصالح احمدی'),
  Ad('a03', 'اجاره دوربین نقشه‌برداری', 'اجاره', false, 'مشهد', 'سجاد',
      'survey', 'روزانه، با هماهنگی', 'تجهیزات دقیق شرق',
      pricing: MarketPrice(800000, PriceUnit.day)),
  Ad('a04', 'کاشی و سرامیک', 'مصالح', false, 'کرج', 'گوهردشت', 'tiles',
      'گالری و استعلام قیمت', 'نمایشگاه کاشی آریا',
      pricing: MarketPrice(420000, PriceUnit.squareMeter)),
  Ad('a05', '۳ کارگر برای بتن‌ریزی سقف', 'نیرو', true, 'مشهد', 'الهیه',
      'concrete', 'روزانه با توافق', 'سازنده الهیه',
      people: 3),
  Ad('a06', 'برق ساختمان و اجرای ارت', 'انشعابات', false, 'مشهد', 'قاسم‌آباد',
      'survey', 'پس از بازدید', 'برق ایمن توس'),
  Ad('a07', 'اکیپ بنایی و دیوارچینی', 'نیرو', false, 'طرقبه', 'مرکز طرقبه',
      'worker', 'پروژه‌ای یا روزانه', 'اکیپ محمدی'),
  Ad('a08', 'خاک‌برداری و حمل نخاله', 'خدمات', false, 'شاندیز', 'مرکز شاندیز',
      'sand', 'بازدید و برآورد', 'راه‌سازان شاندیز'),
  Ad('a09', 'پیمانکار اسکلت بتنی می‌خواهم', 'خدمات', true, 'مشهد', 'وکیل‌آباد',
      'concrete', 'دریافت پیشنهاد', 'ساختمان رضوان'),
  Ad('a10', 'فروش آجر و بلوک سبک', 'مصالح', false, 'گلبهار', 'بهارستان', 'sand',
      'قیمت بر اساس مقدار', 'بلوک شرق'),
  Ad('a11', 'اجاره بالابر ساختمانی', 'اجاره', false, 'مشهد', 'طبرسی',
      'scaffold', 'روزانه و ماهانه', 'ابزار طبرسی'),
  Ad('a12', 'خرید ۸۰ متر سرامیک کف', 'مصالح', true, 'مشهد', 'احمدآباد', 'tiles',
      'ارسال پیشنهاد قیمت', 'پروژه احمدآباد'),
  Ad('a13', 'اجرای لوله‌کشی و تأسیسات', 'خدمات', false, 'تهران', 'تهرانپارس',
      'survey', 'با بازدید محل', 'تأسیسات حسینی'),
  Ad('a14', 'کارگر ماهر ساختمان، آماده همکاری', 'نیرو', false, 'کرج', 'عظیمیه',
      'worker', 'دستمزد با توافق', 'علی رضایی',
      pricing: MarketPrice(1200000, PriceUnit.personDay)),
  Ad('a15', 'اجاره داربست برای نمای ساختمان', 'اجاره', true, 'طرقبه', 'جاغرق',
      'scaffold', 'پیشنهاد همراه حمل', 'ویلای جاغرق'),
  Ad('a16', 'ماسه شسته، ارسال به مشهد و حومه', 'مصالح', false, 'چناران',
      'مرکز چناران', 'sand', 'مقدار و حمل توافقی', 'مصالح چناران'),
  Ad('a17', 'کاشی‌کاری سرویس و آشپزخانه', 'خدمات', false, 'مشهد', 'سجاد',
      'tiles', 'مترمربع با توافق', 'کاشی‌کار رحیمی'),
  Ad('a18', 'نیاز به دو کمک‌کار بنایی', 'نیرو', true, 'کرج', 'حصارک', 'worker',
      'روزانه با توافق', 'سازنده حصارک',
      people: 2),
  Ad('a19', 'اجاره دستگاه جوش برای پروژه', 'اجاره', false, 'فردیس', 'فلکه پنجم',
      'survey', 'روزانه', 'ابزار فردیس'),
  Ad('a20', 'اجرای عایق و ایزوگام', 'خدمات', false, 'تهران', 'صادقیه',
      'scaffold', 'بر اساس متراژ', 'عایق‌کاران غرب'),
  Ad('a21', 'فروش سرامیک پرسلان طرح سنگ', 'مصالح', false, 'تهران', 'پونک',
      'material1', 'استعلام موجودی', 'سرامیک پونک'),
  Ad('a22', 'حمل مصالح و نخاله با خاور', 'خدمات', false, 'مشهد', 'الهیه',
      'sand', 'بر اساس مسیر و بار', 'حمل‌ونقل الهیه'),
  Ad('a23', 'تأمین بتن آماده برای پروژه', 'مصالح', false, 'شیراز', 'قصرالدشت',
      'concrete', 'بر اساس حجم', 'بتن پارس'),
  Ad('a24', 'نیاز به نقشه‌بردار برای پیاده‌سازی', 'مهندسی', true, 'مشهد',
      'قاسم‌آباد', 'survey', 'دریافت پیشنهاد', 'پروژه توس'),
  Ad('a25', 'اجرای گچ و کناف', 'خدمات', false, 'اصفهان', 'مرداویج', 'scaffold',
      'برآورد پس از بازدید', 'گروه سفید'),
  Ad('a26', 'درب و پنجره دوجداره', 'مصالح', false, 'تبریز', 'رشدیه', 'shop',
      'بر اساس ابعاد', 'پنجره آذربایجان'),
  Ad('a27', 'اجاره ویبراتور بتن', 'اجاره', false, 'مشهد', 'قاسم‌آباد',
      'concrete', 'روزانه', 'ابزار توس'),
  Ad('a28', 'اجرای نما و سنگ‌کاری', 'خدمات', false, 'کرج', 'جهانشهر', 'tiles',
      'بر اساس طرح و متراژ', 'سنگ‌کار جهانشهر'),
  Ad('a29', 'نیاز به اکیپ آرماتوربندی', 'نیرو', true, 'شاندیز', 'ابرده',
      'concrete', 'دریافت پیشنهاد', 'سازنده ابرده'),
  Ad('a30', 'مصالح ساختمانی، ارسال به حومه', 'مصالح', false, 'ماهدشت',
      'مرکز ماهدشت', 'sand', 'مقدار و حمل توافقی', 'مصالح غرب'),
  Ad('a31', 'کارگر عمومی، سابقه ۵ سال', 'نیرو', false, 'مشهد', 'احمدآباد',
      'worker', 'روزانه', 'حسین موسوی'),
  Ad('a32', 'خرید بلوک برای دیوارچینی', 'مصالح', true, 'مشهد', 'قاسم‌آباد',
      'sand', 'ارسال قیمت همراه حمل', 'ساختمان مهر'),
  Ad('a33', 'فروش کاشی سفید براق', 'مصالح', false, 'رشت', 'گلسار', 'material2',
      'استعلام موجودی', 'کاشی گیلان'),
  Ad('a34', 'نقشه‌برداری و کنترل تراز', 'مهندسی', false, 'طرقبه', 'عنبران',
      'survey', 'بر اساس پروژه', 'مهندس کریمی'),
  Ad('a35', 'نصب و جمع‌آوری داربست', 'خدمات', false, 'مشهد', 'وکیل‌آباد',
      'scaffold', 'قیمت با توافق', 'داربست وکیل‌آباد'),
  Ad('a36', 'اجاره بالابر و ابزار پروژه', 'اجاره', false, 'قدس', 'مرکز شهر قدس',
      'survey', 'روزانه یا ماهانه', 'تجهیزات قدس'),
  Ad('a37', 'خاک‌برداری و گودبرداری', 'خدمات', false, 'کرج', 'مهرشهر', 'sand',
      'برآورد پس از بازدید', 'گودبرداری البرز'),
  Ad('a38', 'برق‌کشی ساختمان و اجرای ارت', 'انشعابات', false, 'کرج', 'گوهردشت',
      'survey', 'قیمت پس از بازدید', 'برق ایمن البرز'),
  Ad('a39', 'بلوک سبک و ملات آماده', 'مصالح', false, 'کرج', 'حصارک', 'sand',
      'استعلام مقدار و حمل', 'مصالح حصارک'),
  Ad('a40', 'اکیپ بنایی و دیوارچینی', 'نیرو', false, 'کرج', 'گوهردشت', 'worker',
      'با توافق', 'بنایی محمدی'),
  Ad('a41', 'کاشی‌کاری و نصب سرامیک', 'خدمات', false, 'کرج', 'عظیمیه', 'tiles',
      'بر اساس متراژ', 'کاشی‌کار نوری'),
  Ad('a42', 'لوله‌کشی و تأسیسات ساختمان', 'خدمات', false, 'کرج', 'جهانشهر',
      'survey', 'پس از بازدید', 'تأسیسات جهانشهر'),
];

class ChatThread {
  ChatThread(this.id, this.peer, this.subject, this.image, this.incoming,
      {this.unread = 0, this.time = '۱۰:۲۴'});
  final String id, peer, subject, image, incoming;
  int unread;
  String time;
  String appointment = '';
  final outgoing = <String>[];
  final references = <int, SharedReference>{};
  String get last => outgoing.isEmpty ? incoming : outgoing.last;
}

class SharedReference {
  const SharedReference(this.ad, {this.profile = false});
  final Ad ad;
  final bool profile;
}

List<ChatThread> sampleThreads() => [
      ChatThread('c1', 'علی رضایی', '۳ کارگر برای بتن‌ریزی', 'worker',
          'سلام، برای شنبه آماده‌ام. تجربه بتن‌ریزی سقف دارم.',
          unread: 2),
      ChatThread('c2', 'داربست رضایی', 'اجرای داربست ساختمانی', 'scaffold',
          'برای بازدید فردا صبح وقت دارم.',
          unread: 1, time: '۹:۱۰'),
      ChatThread('c3', 'نمایشگاه کاشی آریا', 'سرامیک پرسلان کرم', 'tiles',
          'نمونه کرم موجود است. چند متر نیاز دارید؟',
          time: 'دیروز'),
      ChatThread('c4', 'تجهیزات دقیق شرق', 'اجاره دوربین نقشه‌برداری', 'survey',
          'دوربین از دوشنبه آزاد است.',
          time: 'دیروز'),
      ChatThread('c5', 'مصالح احمدی', 'شن و ماسه با حمل', 'sand',
          'لطفاً مقدار و محل تخلیه را بفرستید.',
          time: 'شنبه'),
    ];
