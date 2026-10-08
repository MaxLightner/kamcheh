part of 'main.dart';

extension AdUi on _AppShellState {
  AdKind get composingKind =>
      draftAdKind ?? defaultAdKind(postCategory, postKind == 'نیاز دارم');
  bool get composingNeed =>
      composingKind == AdKind.need ||
      composingKind == AdKind.buy ||
      composingKind == AdKind.tender;
  Map<String, String> get composerValues => {
        'title': description.text,
        'notes': adNotes.text,
        'people': people.text,
        'start': start.text,
        'price': wage.text,
        'quantity': quantityInput.text,
        'duration': durationInput.text,
      };
  bool get hasAdDraftContent =>
      activeAdDraftId != null ||
      editingAdId != null ||
      [
        description.text,
        adNotes.text,
        wage.text,
        start.text,
        quantityInput.text,
        durationInput.text
      ].any((value) => value.trim().isNotEmpty) ||
      draftPhotos.isNotEmpty ||
      adPoint != null ||
      draftServiceArea != null ||
      draftSkills.any((skill) => skill != 'کارگر عمومی');

  void rememberAdDraft() {
    if (!hasAdDraftContent) return;
    final id =
        activeAdDraftId ?? 'draft-${DateTime.now().microsecondsSinceEpoch}';
    final draft = AdDraft(
        id: id,
        editingId: editingAdId,
        category: postCategory,
        kind: composingKind,
        values: Map.from(composerValues),
        area: adArea,
        point: adPoint,
        serviceArea: draftServiceArea,
        priceUnit: draftPriceUnit,
        skills: List.from(draftSkills),
        photos: List.from(draftPhotos));
    adDrafts.removeWhere((d) => d.id == id);
    adDrafts.insert(0, draft);
    activeAdDraftId = id;
  }

  void clearAdComposer() {
    composerGeneration++;
    changingAdCategory = false;
    activeAdDraftId = null;
    editingAdId = null;
    draftAdKind = null;
    draftPriceUnit = null;
    adPoint = null;
    draftServiceArea = null;
    description.clear();
    adNotes.clear();
    wage.clear();
    start.clear();
    quantityInput.clear();
    durationInput.clear();
    people.text = '3';
    draftPhotos.clear();
    draftSkills.clear();
    adArea = const AreaFilter(
        province: 'البرز', city: 'کرج', districts: {'گوهردشت'});
  }

  void resumeAdDraft(AdDraft draft) {
    clearAdComposer();
    activeAdDraftId = draft.id;
    editingAdId = draft.editingId;
    postCategory = draft.category;
    draftAdKind = draft.kind;
    postKind = composingNeed ? 'نیاز دارم' : 'ارائه می‌کنم';
    description.text = draft.values['title'] ?? '';
    adNotes.text = draft.values['notes'] ?? '';
    people.text = draft.values['people'] ?? '3';
    start.text = draft.values['start'] ?? '';
    wage.text = draft.values['price'] ?? '';
    quantityInput.text = draft.values['quantity'] ?? '';
    durationInput.text = draft.values['duration'] ?? '';
    adArea = draft.area;
    adPoint = draft.point;
    draftServiceArea = draft.serviceArea;
    draftPriceUnit = draft.priceUnit;
    draftPhotos.addAll(draft.photos);
    draftSkills.addAll(draft.skills);
    go('request');
  }

  List<Widget> postChooser() => [
        if (adDrafts.isNotEmpty)
          menuRow('پیش‌نویس‌ها', '${fa(adDrafts.length)} آگهی آماده ادامه',
              Icons.drafts_outlined, () {
            myAdsTab = 1;
            go('myAds');
          }),
        small('۱ از ۲ · نوع آگهی'),
        section('چه چیزی ثبت می‌کنی؟'),
        small(
            'نیاز اجرایی یا طراحی را ثبت کن؛ برای معرفی خدمات، پروفایلت را کامل کن.'),
        ...marketCategories.map((c) => option(
                c.id == 'خدمات'
                    ? 'پیمانکاری و خدمات'
                    : c.id == 'مصالح'
                        ? 'مصالح و متریال'
                        : c.id == 'ابزار'
                            ? 'ابزار و تجهیزات'
                            : c.label,
                postKind == 'نیاز دارم' ? 'ثبت نیاز' : 'معرفی برای همکاری',
                categoryIcon(c.id), () {
              const need = true;
              if (changingAdCategory) {
                draftSkills.clear();
                quantityInput.clear();
                durationInput.clear();
                draftServiceArea = null;
                changingAdCategory = false;
              } else {
                clearAdComposer();
              }
              postKind = 'نیاز دارم';
              postCategory = c.id;
              draftAdKind = defaultAdKind(c.id, need);
              draftPriceUnit = c.priceUnits.first;
              if (c.id == 'نیرو') draftSkills.add('کارگر عمومی');
              go('request');
            })),
      ];

  List<Widget> adComposer() {
    final category = marketCategory(postCategory);
    return [
      Row(children: [
        Expanded(child: small('۲ از ۲ · ${category.shortLabel}')),
        TextButton(
            onPressed: () {
              rememberAdDraft();
              changingAdCategory = true;
              go('post');
            },
            child: const Text('تغییر دسته', style: TextStyle(fontSize: 11)))
      ]),
      Wrap(
          spacing: 5,
          children: category.kinds
              .map((kind) => ChoiceChip(
                  key: ValueKey('post-kind-${kind.name}'),
                  label: Text(kind.label, style: const TextStyle(fontSize: 11)),
                  selected: composingKind == kind,
                  onSelected: (_) => update(() {
                        draftAdKind = kind;
                        postKind = composingNeed ? 'نیاز دارم' : 'ارائه می‌کنم';
                        if (composingNeed) draftServiceArea = null;
                      })))
              .toList()),
      Form(
          key: requestForm,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            section('عکس آگهی · اختیاری'),
            small('تا ۶ عکس؛ عکس اصلی در فهرست آگهی‌ها نمایش داده می‌شود.'),
            const SizedBox(height: 8),
            adPhotoEditor(),
            const SizedBox(height: 12),
            formField('عنوان آگهی', description, required: true),
            formField('توضیحات و شرایط', adNotes, lines: 3),
            menuRow('محل آگهی', adArea.label, Icons.location_on_outlined,
                chooseAdArea),
            if (!composingNeed && postCategory != 'سرمایه‌گذاری') ...[
              menuRow(
                  'محدوده فعالیت',
                  draftServiceArea?.label ?? 'همان محل آگهی',
                  Icons.map_outlined,
                  chooseServiceArea),
              if (draftServiceArea != null)
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => update(() => draftServiceArea = null),
                        child: const Text('بازگشت به همان محل آگهی',
                            style: TextStyle(fontSize: 11)))),
            ],
            section(
                ['نیرو', 'خدمات', 'مهندسی', 'انشعابات'].contains(postCategory)
                    ? 'مهارت مورد نظر'
                    : postCategory == 'سرمایه‌گذاری'
                        ? 'زمینه فعالیت'
                        : 'نوع کالا یا تجهیز'),
            Wrap(
                spacing: 5,
                runSpacing: 2,
                children: category.skills
                    .map((s) => FilterChip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        selected: draftSkills.contains(s),
                        onSelected: (v) => update(() =>
                            v ? draftSkills.add(s) : draftSkills.remove(s))))
                    .toList()),
            const SizedBox(height: 12),
            if (postCategory == 'نیرو' && composingNeed)
              formField('تعداد نیرو', people, number: true, required: true),
            if (postCategory == 'مصالح')
              formField('مقدار و واحد', quantityInput, required: composingNeed),
            formField(composingNeed ? 'روز و ساعت شروع / تحویل' : 'زمان دسترسی',
                start),
            if (postCategory != 'مصالح')
              formField(postCategory == 'اجاره' ? 'مدت اجاره' : 'مدت همکاری',
                  durationInput,
                  required: postCategory == 'اجاره' && composingNeed),
            formField('قیمت یا دستمزد · اختیاری', wage, number: true),
            DropdownButtonFormField<PriceUnit>(
                key: ValueKey('post-price-unit-$postCategory-$draftPriceUnit'),
                initialValue: draftPriceUnit ?? category.priceUnits.first,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'واحد قیمت'),
                items: category.priceUnits
                    .map((unit) => DropdownMenuItem(
                        value: unit,
                        child: Text(unit.label,
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (unit) => update(() => draftPriceUnit = unit)),
            const SizedBox(height: 10),
            small('قیمت و شرایط را خود کاربران پیشنهاد می‌دهند.'),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                      onPressed: saveComposerDraft,
                      icon: const Icon(Icons.drafts_outlined, size: 17),
                      label: const Text('ذخیره پیش‌نویس',
                          style: TextStyle(fontSize: 11)))),
              Expanded(
                  child: TextButton.icon(
                      onPressed: previewComposedAd,
                      icon: const Icon(Icons.visibility_outlined, size: 17),
                      label: const Text('پیش‌نمایش آگهی',
                          style: TextStyle(fontSize: 11))))
            ]),
            button(editingAdId == null ? 'انتشار آگهی' : 'ذخیره تغییرات',
                publishAd),
          ])),
    ];
  }

  Widget adPhotoEditor() => SizedBox(
      height: 112,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        if (draftPhotos.length < 6)
          Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                  width: 88,
                  child: OutlinedButton(
                      onPressed: selectingAdPhotos ? null : addAdPhotos,
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: line),
                          padding: const EdgeInsets.all(8)),
                      child: selectingAdPhotos
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.add_a_photo_outlined, size: 24),
                                  SizedBox(height: 5),
                                  Text('افزودن عکس',
                                      style: TextStyle(fontSize: 11))
                                ])))),
        ...draftPhotos.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(
                width: 88,
                child: Column(children: [
                  Expanded(
                      child: Stack(children: [
                    Positioned.fill(
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(e.value, fit: BoxFit.cover))),
                    Positioned(
                        top: 0,
                        left: 0,
                        child: SizedBox(
                            width: 28,
                            height: 28,
                            child: IconButton(
                                tooltip: 'حذف عکس ${fa(e.key + 1)}',
                                onPressed: () =>
                                    update(() => draftPhotos.removeAt(e.key)),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.zero),
                                icon: const Icon(Icons.close, size: 16)))),
                  ])),
                  SizedBox(
                      height: 30,
                      child: TextButton(
                          key: ValueKey('cover-photo-${e.key}'),
                          onPressed: e.key == 0
                              ? null
                              : () => update(() {
                                    final photo = draftPhotos.removeAt(e.key);
                                    draftPhotos.insert(0, photo);
                                  }),
                          child: Text(e.key == 0 ? 'عکس اصلی' : 'انتخاب اصلی',
                              style: const TextStyle(fontSize: 10)))),
                ])))),
      ]));

  Future<void> addAdPhotos() async {
    update(() => selectingAdPhotos = true);
    final generation = composerGeneration;
    final result = await selectPhotos(6 - draftPhotos.length);
    if (!mounted) return;
    update(() {
      selectingAdPhotos = false;
      if (page == 'request' && generation == composerGeneration)
        draftPhotos.addAll(result.take(6 - draftPhotos.length));
    });
  }

  void saveComposerDraft() {
    if (!hasAdDraftContent) {
      notice('عنوان، توضیح یا عکس اضافه کن');
      return;
    }
    update(() {
      rememberAdDraft();
      clearAdComposer();
      myAdsTab = 1;
      tab = 4;
      history
        ..clear()
        ..add(('me', 4));
      page = 'myAds';
    });
    notice('پیش‌نویس در این پیش‌نمایش ذخیره شد');
  }

  bool validateComposer() {
    if (!(requestForm.currentState?.validate() ?? false)) return false;
    if (adArea.city == null) {
      notice('شهر محل آگهی را انتخاب کن');
      return false;
    }
    if (draftSkills.isEmpty) {
      notice('یک مهارت، کالا یا تجهیز انتخاب کن');
      return false;
    }
    if (selectingAdPhotos) {
      notice('منتظر تکمیل انتخاب عکس بمان');
      return false;
    }
    return true;
  }

  Ad composedAd() => Ad(
      editingAdId ?? 'mine-${DateTime.now().microsecondsSinceEpoch}',
      description.text.trim(),
      postCategory,
      composingNeed,
      adArea.city!,
      adArea.districts.isEmpty ? 'تمام شهر' : adArea.districts.first,
      marketCategory(postCategory).asset,
      wage.text.trim().isEmpty
          ? 'با توافق'
          : money(parsePriceInput(wage.text)!),
      myName,
      providerProfile: myProfile.badge,
      time: 'اکنون',
      listingKind: composingKind,
      pricing: wage.text.trim().isEmpty
          ? null
          : MarketPrice(parsePriceInput(wage.text)!,
              draftPriceUnit ?? marketCategory(postCategory).priceUnits.first),
      description: adNotes.text.trim(),
      startsAt: start.text.trim(),
      people: postCategory == 'نیرو' && composingNeed
          ? parsePriceInput(people.text)!
          : 0,
      quantity: postCategory == 'مصالح' ? quantityInput.text.trim() : '',
      duration: postCategory == 'مصالح' ? '' : durationInput.text.trim(),
      point: adPoint,
      serviceArea: composingNeed || postCategory == 'سرمایه‌گذاری'
          ? null
          : draftServiceArea,
      skills: List.from(draftSkills),
      photos: List.from(draftPhotos));

  Future<void> previewComposedAd() async {
    if (!validateComposer()) return;
    final ad = composedAd();
    final publish = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .88,
            child: Column(children: [
              ListTile(
                  title: const Text('پیش‌نمایش آگهی',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  trailing: IconButton(
                      tooltip: 'بازگشت به ویرایش',
                      onPressed: () => Navigator.pop(sheet),
                      icon: const Icon(Icons.close))),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AdGallery(ad: ad),
                            section(ad.title),
                            small('${ad.kind.label} · ${ad.area}'),
                            pair('قیمت', priceText(ad)),
                            skillCards(ad.skills),
                            const SizedBox(height: 10),
                            Text(ad.description),
                            ...adLocationSection(ad)
                          ]))),
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: Text(editingAdId == null
                          ? 'تأیید و انتشار'
                          : 'تأیید و ذخیره تغییرات'))),
            ])));
    if (publish == true && mounted) publishAd();
  }

  void publishAd() {
    if (!validateComposer()) return;
    final ad = composedAd();
    update(() {
      final index = createdAds.indexWhere((a) => a.id == ad.id);
      if (index < 0) {
        createdAds.insert(0, ad);
      } else {
        createdAds[index] = ad;
      }
      if (ad.need) {
        workRequests.putIfAbsent(ad.id, () => WorkRequest(ad.id));
      } else {
        workRequests.remove(ad.id);
      }
      if (selectedAd.id == ad.id) selectedAd = ad;
      adDrafts
          .removeWhere((d) => d.id == activeAdDraftId || d.editingId == ad.id);
      clearAdComposer();
      myAdsTab = 0;
      tab = 4;
      history
        ..clear()
        ..add(('me', 4));
      page = 'myAds';
    });
    notice('آگهی در پیش‌نمایش ذخیره شد');
  }

  void editAd(Ad ad) {
    final pending = adDrafts.where((d) => d.editingId == ad.id).firstOrNull;
    if (pending != null) {
      resumeAdDraft(pending);
      return;
    }
    clearAdComposer();
    editingAdId = ad.id;
    postCategory = ad.category;
    draftAdKind = ad.kind;
    postKind = ad.need ? 'نیاز دارم' : 'ارائه می‌کنم';
    description.text = ad.title;
    adNotes.text = ad.description;
    people.text = ad.people == 0 ? '3' : ad.people.toString();
    start.text = ad.startsAt;
    quantityInput.text = ad.quantity;
    durationInput.text = ad.duration;
    draftPriceUnit =
        ad.pricing?.unit ?? marketCategory(ad.category).priceUnits.first;
    wage.text = ad.pricing != null
        ? ad.pricing!.amount.toString()
        : ad.price.contains('تومان')
            ? (parseAmount(ad.price.replaceAll('تومان', ''))?.toString() ?? '')
            : '';
    draftSkills.addAll(adSkills(ad));
    draftPhotos.addAll(ad.photos);
    adArea = AreaFilter(
        province: ad.province,
        city: ad.city,
        districts: cityByName(ad.city).districts.contains(ad.district)
            ? {ad.district}
            : {});
    adPoint = ad.point;
    draftServiceArea = ad.serviceArea;
    go('request');
  }

  Future<bool> confirmRemoval(String title, String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: Text(title, style: const TextStyle(fontSize: 16)),
                  content: Text(text),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('انصراف')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('حذف', style: TextStyle(color: red))),
                  ])) ??
      false;

  Future<void> removeOwnAd(Ad ad) async {
    if (!await confirmRemoval('حذف آگهی؟', ad.title) || !mounted) return;
    update(() {
      deletedAds.add(ad.id);
      savedIds.remove(ad.id);
      adDrafts.removeWhere((d) => d.editingId == ad.id);
      if (editingAdId == ad.id) clearAdComposer();
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: const Text('آگهی حذف شد'),
          action: SnackBarAction(
              label: 'بازگرداندن',
              onPressed: () => update(() => deletedAds.remove(ad.id)))));
  }

  List<Widget> legacyMyAdsView() {
    final own = createdAds.where((ad) => !deletedAds.contains(ad.id)).toList();
    return [
      miniTabs([
        'آگهی‌ها (${fa(own.length)})',
        'پیش‌نویس‌ها (${fa(adDrafts.length)})'
      ], myAdsTab, (i) => update(() => myAdsTab = i)),
      if (myAdsTab == 0) ...[
        ...own.map((ad) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              networkAdRow(ad),
              Wrap(spacing: 2, children: [
                TextButton.icon(
                    onPressed: () => editAd(ad),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label:
                        const Text('ویرایش', style: TextStyle(fontSize: 11))),
                TextButton(
                    onPressed: () => update(() {
                          if (isClosed(ad)) {
                            closedAds.remove(ad.id);
                            if (workRequests.containsKey(ad.id))
                              workRequests[ad.id]!.status = 'دریافت پیشنهاد';
                          } else {
                            closedAds.add(ad.id);
                            if (workRequests.containsKey(ad.id))
                              workRequests[ad.id]!.status = 'بسته‌شده';
                          }
                        }),
                    child: Text(isClosed(ad) ? 'فعال‌کردن' : 'بستن آگهی',
                        style: const TextStyle(fontSize: 11))),
                if (ad.need)
                  TextButton(
                      onPressed: () => openRequest(ad.id),
                      child: const Text('پیشنهادها',
                          style: TextStyle(fontSize: 11))),
                IconButton(
                    tooltip: 'حذف آگهی',
                    onPressed: () => removeOwnAd(ad),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: muted)),
              ]),
              const Divider(height: 1),
            ])),
        if (own.isEmpty)
          emptyState('آگهی نداری', 'اولین نیاز یا خدمتت را ثبت کن.'),
      ] else ...[
        small('پیش‌نویس‌ها منتشر نشده‌اند و فقط خودت آن‌ها را می‌بینی.'),
        ...adDrafts.map((d) => ListTile(
            key: ValueKey('draft-row-${d.id}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.drafts_outlined, color: red),
            title: Text(d.title, style: const TextStyle(fontSize: 13)),
            subtitle: Text(
                '${marketCategory(d.category).shortLabel} · ${d.kind.label}${d.editingId == null ? '' : ' · ویرایش آگهی'}',
                style: const TextStyle(fontSize: 11)),
            onTap: () => resumeAdDraft(d),
            trailing: IconButton(
                tooltip: 'حذف پیش‌نویس',
                onPressed: () async {
                  if (await confirmRemoval('حذف پیش‌نویس؟', d.title) && mounted)
                    update(() {
                      adDrafts.removeWhere((item) => item.id == d.id);
                      if (activeAdDraftId == d.id) clearAdComposer();
                    });
                },
                icon: const Icon(Icons.delete_outline, size: 18)))),
        if (adDrafts.isEmpty)
          emptyState('پیش‌نویسی نداری',
              'آگهی نیمه‌کاره را ذخیره کن و بعداً ادامه بده.'),
      ],
      button('ثبت آگهی جدید', () {
        clearAdComposer();
        selectTab(2);
      }, icon: Icons.add),
    ];
  }

  Future<void> chooseServiceArea() async {
    final result = await showModalBottomSheet<AreaFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (_) => AreaPicker(
            initial: draftServiceArea ??
                AreaFilter(province: adArea.province, city: adArea.city),
            coverage: true));
    if (result != null && mounted) update(() => draftServiceArea = result);
  }

  List<Widget> adLocationSection(Ad ad) => [
        section('محل آگهی'),
        small(ad.area),
        const SizedBox(height: 8),
        LocationMap(
            key: ValueKey('ad-location-${ad.id}'),
            city: cityByName(ad.city),
            point: ad.point,
            height: 180),
        if (!ad.need && ad.serviceArea != null) ...[
          section('محدوده فعالیت'),
          small(ad.serviceArea!.label),
          if (ad.serviceArea!.city != null) ...[
            const SizedBox(height: 8),
            LocationMap(
                key: ValueKey('ad-service-${ad.id}'),
                city: cityByName(ad.serviceArea!.city!),
                districts: ad.serviceArea!.districts,
                districtPreview: true,
                height: 160),
          ],
        ],
      ];
}

class AdGallery extends StatefulWidget {
  const AdGallery({super.key, required this.ad});
  final Ad ad;
  @override
  State<AdGallery> createState() => _AdGalleryState();
}

class _AdGalleryState extends State<AdGallery> {
  int index = 0;
  @override
  void didUpdateWidget(covariant AdGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.ad.photos != widget.ad.photos) index = 0;
  }

  Widget picture(int i, {BoxFit fit = BoxFit.cover}) => widget.ad.photos.isEmpty
      ? Image.asset('assets/images/${widget.ad.image}.jpg', fit: fit)
      : Image.memory(widget.ad.photos[i],
          fit: fit,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: muted)));
  @override
  Widget build(BuildContext context) {
    final count = widget.ad.photos.isEmpty ? 1 : widget.ad.photos.length;
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            height: 190,
            child: Stack(children: [
              Positioned.fill(
                  child: PageView.builder(
                      key: ValueKey('gallery-${widget.ad.id}'),
                      itemCount: count,
                      onPageChanged: (i) => setState(() => index = i),
                      itemBuilder: (_, i) => GestureDetector(
                          onTap: () => showDialog<void>(
                              context: context,
                              builder: (dialog) =>
                                  AdPhotoViewer(ad: widget.ad, initial: i)),
                          child: picture(i)))),
              Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('${fa(index + 1)} / ${fa(count)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)))),
              const Positioned(
                  top: 8,
                  left: 8,
                  child: IgnorePointer(
                      child:
                          Icon(Icons.zoom_in, color: Colors.white, size: 23))),
            ])));
  }
}

class AdPhotoViewer extends StatefulWidget {
  const AdPhotoViewer({super.key, required this.ad, required this.initial});
  final Ad ad;
  final int initial;
  @override
  State<AdPhotoViewer> createState() => _AdPhotoViewerState();
}

class _AdPhotoViewerState extends State<AdPhotoViewer> {
  late final PageController controller =
      PageController(initialPage: widget.initial);
  late int index = widget.initial;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.ad.photos.isEmpty ? 1 : widget.ad.photos.length;
    return Dialog.fullscreen(
        backgroundColor: Colors.white,
        child: SafeArea(
            child: Column(children: [
          Row(children: [
            IconButton(
                tooltip: 'بستن عکس',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            const Expanded(
                child: Text('عکس‌های آگهی', style: TextStyle(fontSize: 14))),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Text('${fa(index + 1)} / ${fa(count)}',
                    style: const TextStyle(fontSize: 12))),
          ]),
          Expanded(
              child: PageView.builder(
                  controller: controller,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => index = i),
                  itemBuilder: (_, i) => InteractiveViewer(
                      child: SizedBox.expand(
                          child: widget.ad.photos.isEmpty
                              ? Image.asset(
                                  'assets/images/${widget.ad.image}.jpg',
                                  fit: BoxFit.contain)
                              : Image.memory(widget.ad.photos[i],
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          color: muted))))))),
        ])));
  }
}
