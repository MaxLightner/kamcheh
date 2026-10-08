part of 'main.dart';

extension WorkUi on _AppShellState {
  List<Widget> myAdsView() => [
        ...workStore.needs.values
            .where((n) => n.ownerId == actorId && !n.archived)
            .map((n) => panel([
                  Text(n.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  small(
                      '${n.city} · ${n.district} · ${n.closed ? 'بسته' : 'فعال'}'),
                  Wrap(spacing: 6, children: [
                    TextButton(
                        onPressed: () => startWorkRequest(n),
                        child: const Text('ویرایش')),
                    TextButton(
                        onPressed: () => openRequest(n.id),
                        child: const Text('پیشنهادها و بازدیدها')),
                    TextButton(
                        onPressed: () => workAction(() => workStore
                            .changeStatus(n.id, actorId, closed: !n.closed)),
                        child: Text(n.closed ? 'فعال کردن' : 'بستن'))
                  ]),
                ])),
        if (!workStore.needs.values
            .any((n) => n.ownerId == actorId && !n.archived))
          emptyState('درخواستی نداری', 'نیازت را ثبت کن.'),
        button('ثبت درخواست جدید', () => startWorkRequest()),
      ];
  Future<void> shareInWorkChat(Ad ad, {bool profile = false}) async {
    if (!canAct) {
      await ensureAccess(() => shareInWorkChat(ad, profile: profile));
      return;
    }
    final actor = actorId;
    final list =
        workStore.conversations.values.where((c) => c.contains(actor)).toList();
    if (list.isEmpty) {
      notice(
          'هنوز گفت‌وگویی باز نشده است؛ می‌توانی لینک را کپی یا اشتراک‌گذاری کنی.');
      return;
    }
    final id = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (ctx) => ListView(shrinkWrap: true, children: [
              const ListTile(title: Text('ارسال در گفت‌وگو')),
              ...list.map((c) => ListTile(
                  title: Text(workName(c.peer(actor))),
                  subtitle: Text(workStore.need(c.requestId).title),
                  onTap: () => Navigator.pop(ctx, c.id))),
            ]));
    if (id == null || !mounted || actorId != actor) return;
    final p = profile ? findProfile(ad) : null;
    final text = p != null
        ? 'پروفایل ${p.name}\n${publicProfileUrl(p.id)}'
        : 'درخواست: ${ad.title}\n${ad.area}';
    workAction(() => workStore.send(id, actor, text));
    openCanonicalChat(id);
  }

  String get actorId => signedIn ? myProfile.id : '';
  WorkConversation? get currentWorkChat => workStore.conversations[workChatId];
  String workName(String id) =>
      profileRepository.profile(id)?.name ?? 'پروفایل در دسترس نیست';
  String get chatPeerName => currentWorkChat == null
      ? 'گفت‌وگو'
      : workName(currentWorkChat!.peer(actorId));
  String get chatSubject => currentWorkChat == null
      ? ''
      : workStore.need(currentWorkChat!.requestId).title;
  bool workAction(VoidCallback fn) {
    try {
      update(fn);
      return true;
    } on StateError catch (e) {
      notice(e.message.toString());
      return false;
    }
  }

  DemoWorkRepository seedWorkStore() {
    final repo = DemoWorkRepository();
    final seen = <String>{};
    for (final ad in archivedAds.where(activeListing)) {
      if (!seen.add(ad.id)) continue;
      var owner = profileRepository.profiles
          .where((p) => p.name == ad.owner)
          .firstOrNull;
      if (owner == null) {
        owner = UserProfile(
            id: 'owner-${ad.id}',
            name: ad.owner,
            city: ad.city,
            specialty: 'سازنده',
            complete: true,
            phoneVerified: true,
            coverage: AreaFilter(province: ad.province, city: ad.city),
            bio: 'پروفایل نمونه درخواست‌دهنده');
        profileRepository.save(owner);
      }
      final n = WorkNeed(
          id: ad.id,
          ownerId: owner.id,
          title: ad.title,
          details: ad.description.isEmpty
              ? 'شرح و شرایط ${ad.title}؛ پیش از توافق هماهنگ کنید.'
              : ad.description,
          city: ad.city,
          district: ad.district,
          category: ad.category,
          quantity: ad.people > 0 ? '${fa(ad.people)} نفر' : ad.quantity,
          when: ad.startsAt,
          budget: ad.pricing?.amount,
          unit: ad.pricing?.unit ?? PriceUnit.project,
          image: ad.image,
          photos: ad.photos,
          crew: ad.title.contains('اکیپ'));
      repo.needs[n.id] = n;
    }
    final people = profileRepository.profiles
        .where((p) =>
            p.name == 'علی رضایی' ||
            p.name == 'حسین موسوی' ||
            p.name == 'محمد کریمی')
        .toList();
    for (final e in people.asMap().entries) {
      repo.propose(
          'own-labor',
          e.value.id,
          1200000 + e.key * 100000,
          PriceUnit.personDay,
          'شنبه ساعت ۷ صبح',
          'تجربه بتن‌ریزی؛ مبلغ برای هر نفر در یک روز است.');
    }
    repo.needs['own-scaffold']!.privateAddress =
        'نشانی نمونه: کرج، گوهردشت، محل پروژه';
    final scaffold =
        profileRepository.profiles.firstWhere((p) => p.name == 'داربست رضایی');
    final v = repo.proposeVisit('own-scaffold', scaffold.id, scaffold.id,
        DateTime.now().add(const Duration(days: 1)));
    repo.respondVisit(v.id, 'profile-sample', 'accepted');
    repo.send('own-scaffold::${scaffold.id}', scaffold.id,
        'سلام، برای بازدید داربست در ساعت توافق‌شده می‌آیم.');
    return repo;
  }

  Ad workAd(WorkNeed n) => Ad(
      n.id,
      n.title,
      n.category,
      true,
      n.city,
      n.district,
      n.image,
      n.budget == null ? 'دریافت پیشنهاد' : money(n.budget!),
      workName(n.ownerId),
      description: n.details,
      quantity: n.quantity,
      startsAt: n.when,
      photos: n.photos,
      pricing: n.budget == null ? null : MarketPrice(n.budget!, n.unit),
      listingKind: AdKind.need,
      skills: const []);
  List<Ad> get workFeedAds => workStore.needs.values
      .where((n) => !n.archived && !n.closed)
      .map(workAd)
      .toList()
      .reversed
      .toList();
  void startWorkRequest([WorkNeed? n]) {
    clearAdComposer();
    workEditingId = n?.id;
    workPrivate.text = n?.privateAddress ?? '';
    workCrew = n?.crew ?? false;
    if (n != null) {
      description.text = n.title;
      adNotes.text = n.details;
      quantityInput.text = n.quantity;
      start.text = n.when;
      wage.text = n.budget?.toString() ?? '';
      draftPriceUnit = n.unit;
      postCategory = n.category;
      draftPhotos.addAll(n.photos);
      adArea = AreaFilter(
          province: cityByName(n.city).province,
          city: n.city,
          districts: n.district.isEmpty ? {} : {n.district});
      adPoint = n.latitude == null ? null : MapPoint(n.latitude!, n.longitude!);
    } else {
      postCategory = 'خدمات';
      draftPriceUnit = PriceUnit.project;
    }
    go('request');
  }

  Widget workInput(TextEditingController c, String title,
          {int lines = 1, bool required = false, bool numeric = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
              controller: c,
              maxLines: lines,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(labelText: title),
              validator: (v) {
                if (required && (v?.trim().isEmpty ?? true))
                  return 'این قسمت را تکمیل کن.';
                if (numeric &&
                    (v?.trim().isNotEmpty ?? false) &&
                    (parsePriceInput(v!) ?? 0) <= 0)
                  return 'مبلغ مثبت و معتبر بنویس.';
                return null;
              }));
  List<Widget> unifiedRequestForm() => [
        small('یک درخواست برای هر نیاز اجرایی یا طراحی'),
        Form(
            key: requestForm,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  workInput(description, 'عنوان درخواست', required: true),
                  workInput(adNotes, 'شرح نیاز و شرایط',
                      lines: 4, required: true),
                  menuRow('محدوده عمومی', adArea.label,
                      Icons.location_on_outlined, chooseAdArea),
                  small(
                      'شهر و محله عمومی‌اند؛ نقطه نقشه و نشانی دقیق فقط برای بازدید تأییدشده نمایش داده می‌شوند.'),
                  const SizedBox(height: 10),
                  workInput(workPrivate, 'نشانی دقیق (اختیاری و خصوصی)',
                      lines: 2),
                  workInput(quantityInput, 'مقدار یا تعداد (اختیاری)'),
                  workInput(start, 'زمان موردنظر (اختیاری)'),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('اکیپ می‌خواهم',
                          style: TextStyle(fontSize: 13)),
                      value: workCrew,
                      onChanged: (v) => update(() => workCrew = v ?? false)),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('بودجه، عکس و زمینه مرتبط',
                          style: TextStyle(fontSize: 13)),
                      children: [
                        workInput(wage, 'بودجه پیشنهادی به تومان (اختیاری)',
                            numeric: true),
                        DropdownButtonFormField<PriceUnit>(
                            initialValue: draftPriceUnit ?? PriceUnit.project,
                            decoration:
                                const InputDecoration(labelText: 'واحد بودجه'),
                            items: PriceUnit.values
                                .map((u) => DropdownMenuItem(
                                    value: u, child: Text(u.label)))
                                .toList(),
                            onChanged: (v) => update(() => draftPriceUnit = v)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            initialValue: postCategory,
                            decoration:
                                const InputDecoration(labelText: 'زمینه مرتبط'),
                            items: marketCategories
                                .map((c) => DropdownMenuItem(
                                    value: c.id, child: Text(c.label)))
                                .toList(),
                            onChanged: (v) => update(() => postCategory = v!)),
                        const SizedBox(height: 10),
                        photoChooser(draftPhotos, addAdPhotos,
                            (i) => update(() => draftPhotos.removeAt(i))),
                      ]),
                  const SizedBox(height: 12),
                  button(
                      workEditingId == null
                          ? 'پیش‌نمایش و ثبت درخواست'
                          : 'پیش‌نمایش و ذخیره تغییرات',
                      publishWorkRequest),
                ]))
      ];
  Future<void> publishWorkRequest() async {
    if (!requestForm.currentState!.validate()) return;
    if (adArea.city == null) {
      notice('شهر را انتخاب کن.');
      return;
    }
    if (wage.text.trim().isNotEmpty && (parsePriceInput(wage.text) ?? 0) <= 0) {
      notice('بودجه باید مبلغ مثبت باشد.');
      return;
    }
    final owner = actorId;
    final n = WorkNeed(
        id: workEditingId ?? workId('request'),
        ownerId: owner,
        title: description.text.trim(),
        details: adNotes.text.trim(),
        city: adArea.city!,
        district: adArea.districts.join('، '),
        category: postCategory,
        quantity: quantityInput.text.trim(),
        when: start.text.trim(),
        privateAddress: workPrivate.text.trim(),
        crew: workCrew,
        budget: wage.text.trim().isEmpty ? null : parsePriceInput(wage.text),
        unit: draftPriceUnit ?? PriceUnit.project,
        image: marketCategory(postCategory).asset,
        photos: List.from(draftPhotos),
        latitude: adPoint?.latitude,
        longitude: adPoint?.longitude);
    final yes = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (ctx) => SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  section('پیش‌نمایش درخواست'),
                  Text(n.title),
                  small('${n.city} · ${n.district}'),
                  const SizedBox(height: 10),
                  Text(n.details),
                  if (n.quantity.isNotEmpty) pair('مقدار / تعداد', n.quantity),
                  if (n.when.isNotEmpty) pair('زمان', n.when),
                  if (n.budget != null)
                    pair('بودجه', '${money(n.budget!)} / ${n.unit.label}'),
                  small(n.crew ? 'اکیپ موردنیاز' : 'شرط اکیپ ندارد'),
                  small('نشانی دقیق در آگهی عمومی منتشر نمی‌شود.'),
                  const SizedBox(height: 12),
                  button('تأیید و ثبت', () => Navigator.pop(ctx, true)),
                  button('برگشت به ویرایش', () => Navigator.pop(ctx, false),
                      outlined: true)
                ])));
    if (yes != true || !mounted || actorId != owner) return;
    if (!workAction(() => workStore.saveNeed(n, owner))) return;
    clearAdComposer();
    workEditingId = null;
    selectedRequest = n.id;
    selectedAd = workAd(n);
    go('applicants');
  }

  List<Widget> workBoard() => [
        miniTabs(['درخواست‌های من', 'پیشنهادهای من', 'بازدیدها'], requestTab,
            (i) => update(() => requestTab = i)),
        const SizedBox(height: 10),
        if (requestTab == 0) ...[
          ...workStore.needs.values
              .where((n) => n.ownerId == actorId && !n.archived)
              .map((n) => panel([
                    Text(n.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    small('${n.city} · ${n.district}'),
                    small(
                        '${n.closed ? 'بسته' : 'دریافت پیشنهاد'} · ${fa(workStore.proposals(n.id).length)} پیشنهاد'),
                    Row(children: [
                      Expanded(
                          child: button(
                              'پیشنهادها و بازدیدها', () => openRequest(n.id),
                              outlined: true)),
                      IconButton(
                          tooltip: 'ویرایش درخواست',
                          onPressed: () => startWorkRequest(n),
                          icon: const Icon(Icons.edit_outlined, size: 19))
                    ])
                  ])),
          if (!workStore.needs.values
              .any((n) => n.ownerId == actorId && !n.archived))
            emptyState('درخواستی نداری', 'نیازت را با یک فرم کوتاه ثبت کن.'),
          button('ثبت درخواست', () => startWorkRequest()),
        ],
        if (requestTab == 1) ...[
          small(
              'اعتبار آزمایشی: ${fa(workStore.balance(actorId))} · ثبت پیشنهاد جدید: ۱ اعتبار؛ ویرایش رایگان'),
          ...workStore.bids.values
              .where((b) => b.bidderId == actorId)
              .map((b) => panel([
                    Text(workStore.need(b.requestId).title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    pair('پیشنهاد من', '${money(b.amount)} / ${b.unit.label}'),
                    small(b.when),
                    label(
                        workStore.need(b.requestId).chosenId == b.id
                            ? 'انتخاب برای هماهنگی'
                            : 'ارسال‌شده',
                        color: red),
                    button('مشاهده درخواست',
                        () => openAd(workAd(workStore.need(b.requestId))),
                        outlined: true),
                    if (workStore.conversations
                        .containsKey('${b.requestId}::${b.bidderId}'))
                      button(
                          'گفت‌وگو',
                          () => openCanonicalChat(
                              '${b.requestId}::${b.bidderId}')),
                  ])),
          if (!workStore.bids.values.any((b) => b.bidderId == actorId))
            emptyState(
                'پیشنهادی نفرستاده‌ای', 'از درخواست‌ها کار مناسب پیدا کن.'),
        ],
        if (requestTab == 2) ...[
          ...workStore.visits.values
              .where((v) =>
                  v.bidderId == actorId ||
                  workStore.need(v.requestId).ownerId == actorId)
              .map(workVisitCard),
          if (!workStore.visits.values.any((v) =>
              v.bidderId == actorId ||
              workStore.need(v.requestId).ownerId == actorId))
            emptyState('بازدیدی نداری',
                'می‌توانی پیش از پیشنهاد قیمت درخواست بازدید بدهی.'),
        ],
      ];
  List<Widget> workRequestDetails() {
    final n = workStore.needs[selectedRequest];
    if (n == null || n.ownerId != actorId)
      return [
        emptyState('درخواست در دسترس نیست', 'این بخش مخصوص صاحب درخواست است.')
      ];
    final all = workStore.proposals(n.id).toList();
    final visible =
        all.where((b) => bidSortUnit == null || b.unit == bidSortUnit).toList();
    if (bidSortUnit != null)
      visible.sort((a, b) => a.amount.compareTo(b.amount));
    return [
      Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      small('${n.city} · ${n.district}'),
      pair(
          'وضعیت',
          n.closed
              ? 'بسته‌شده'
              : n.chosenId == null
                  ? 'دریافت پیشنهاد'
                  : 'انتخاب برای هماهنگی'),
      Row(children: [
        Expanded(
            child: button('ویرایش', () => startWorkRequest(n), outlined: true)),
        const SizedBox(width: 8),
        Expanded(
            child: button(
                n.closed ? 'بازکردن درخواست' : 'بستن درخواست',
                () => workAction(() =>
                    workStore.changeStatus(n.id, actorId, closed: !n.closed)),
                outlined: true))
      ]),
      section('پیشنهادهای دریافتی'),
      small('مبلغ‌های با واحد متفاوت قابل مقایسه مستقیم نیستند.'),
      const SizedBox(height:12),
      DropdownButtonFormField<PriceUnit>(
          key: ValueKey('sort-$selectedRequest-$bidSortUnit'),
          initialValue: bidSortUnit,
          decoration:
              const InputDecoration(labelText: 'مرتب‌سازی قیمت در یک واحد'),
          items: [
            const DropdownMenuItem<PriceUnit>(
                value: null, child: Text('همه · ترتیب دریافت')),
            ...all.map((b) => b.unit).toSet().map((u) => DropdownMenuItem(
                value: u, child: Text('${u.label} · ارزان‌تر اول')))
          ],
          onChanged: (u) => update(() => bidSortUnit = u)),
      ...visible.map((b) => bidComparisonCard(n, b)),
      if (all.isEmpty)
        emptyState(
            'هنوز پیشنهادی نرسیده', 'درخواست در صفحه خانه نمایش داده می‌شود.'),
      section('درخواست‌های بازدید'),
      ...workStore.visits.values
          .where((v) => v.requestId == n.id)
          .map(workVisitCard),
      if (!workStore.visits.values.any((v) => v.requestId == n.id))
        small('هنوز درخواست بازدیدی نرسیده است.'),
      TextButton(
          onPressed: () => openAd(workAd(n)),
          child: const Text('مشاهده آگهی عمومی')),
      TextButton(
          onPressed: () async {
            if (await confirmRemoval(
                    'بایگانی درخواست؟', 'پیام‌ها و پیشنهادها باقی می‌مانند.') &&
                mounted) {
              workAction(
                  () => workStore.changeStatus(n.id, actorId, archive: true));
              back();
            }
          },
          child: const Text('بایگانی درخواست')),
    ];
  }

  Widget bidComparisonCard(WorkNeed n, WorkBid b) => panel([
        Row(children: [
          Expanded(
              child: Text(workName(b.bidderId),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          if (n.chosenId == b.id) label('انتخاب‌شده', color: red)
        ]),
        pair('پیشنهاد', '${money(b.amount)} / ${b.unit.label}'),
        pair('زمان', b.when),
        if (b.terms.isNotEmpty) small(b.terms),
        button('پروفایل و سابقه', () => showWorkProfile(b.bidderId),
            outlined: true),
        if (workStore.conversations.containsKey('${n.id}::${b.bidderId}'))
          button('گفت‌وگو', () => openCanonicalChat('${n.id}::${b.bidderId}')),
        if (n.chosenId == null && !n.closed)
          button('انتخاب برای هماهنگی', () async {
            final yes = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                        title: const Text('انتخاب پیشنهاد؟'),
                        content: Text(
                            '${workName(b.bidderId)} · ${money(b.amount)} / ${b.unit.label}\nاین انتخاب فقط گفت‌وگو را باز می‌کند.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('انصراف')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('انتخاب'))
                        ]));
            if (yes == true && mounted) {
              workAction(() => workStore.select(n.id, b.id, actorId));
            }
          }),
      ]);
  void showWorkProfile(String id) {
    final p = profileRepository.profile(id);
    if (p == null) {
      notice('پروفایل پیدا نشد.');
      return;
    }
    selectedAd = profileCard(p);
    go(id == actorId ? 'ownProfile' : 'pro');
  }

  Future<void> proposeWork(Ad ad) async {
    if (!canAct) {
      await ensureAccess(() => proposeWork(ad));
      return;
    }
    final n = workStore.needs[ad.id];
    if (n == null) {
      notice('درخواست مرتبط انتخاب کن.');
      return;
    }
    if (n.closed || n.ownerId == actorId) {
      notice('این درخواست پیشنهاد جدید نمی‌پذیرد.');
      return;
    }
    final actor = actorId, old = workStore.mine(n.id, actor);
    final price = TextEditingController(text: old?.amount.toString() ?? ''),
        time = TextEditingController(text: old?.when ?? ''),
        terms = TextEditingController(text: old?.terms ?? '');
    var unit = old?.unit ?? n.unit;
    final key = GlobalKey<FormState>();
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title:
                        Text(old == null ? 'ارسال پیشنهاد' : 'ویرایش پیشنهاد'),
                    content: SizedBox(
                        width: 340,
                        child: SingleChildScrollView(
                            child: Form(
                                key: key,
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      small(
                                          'اعتبار آزمایشی ${fa(workStore.balance(actor))} · ${old == null ? 'هزینه: ۱ اعتبار' : 'ویرایش بدون کسر اعتبار'}'),
                                      const SizedBox(height: 10),
                                      workInput(price, 'مبلغ به تومان',
                                          numeric: true, required: true),
                                      DropdownButtonFormField<PriceUnit>(
                                          initialValue: unit,
                                          items: PriceUnit.values
                                              .map((u) => DropdownMenuItem(
                                                  value: u,
                                                  child: Text(u.label)))
                                              .toList(),
                                          onChanged: (v) =>
                                              change(() => unit = v!),
                                          decoration: const InputDecoration(
                                              labelText: 'واحد قیمت')),
                                      const SizedBox(height: 10),
                                      workInput(time, 'زمان حضور یا تحویل',
                                          required: true),
                                      workInput(
                                          terms, 'شرایط پیشنهاد (اختیاری)',
                                          lines: 3),
                                      small(
                                          'صاحب درخواست همه پیشنهادها را می‌بیند. شما پس از ثبت پیشنهاد، مبلغ‌های بدون نام دیگران را می‌بینید.'),
                                    ])))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('انصراف')),
                      TextButton(
                          onPressed: () {
                            if (key.currentState!.validate() &&
                                (parsePriceInput(price.text) ?? 0) > 0)
                              Navigator.pop(ctx, true);
                          },
                          child: const Text('ثبت پیشنهاد'))
                    ])));
    if (yes == true && mounted && actorId == actor)
      workAction(() => workStore.propose(n.id, actor,
          parsePriceInput(price.text)!, unit, time.text, terms.text));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    price.dispose();
    time.dispose();
    terms.dispose();
  }

  Future<void> requestWorkVisit(WorkNeed n, {String? bidderId}) async {
    if (!canAct) {
      await ensureAccess(() => requestWorkVisit(n, bidderId: bidderId));
      return;
    }
    final actor = actorId, bidder = bidderId ?? actor;
    if (n.ownerId == actor && bidderId == null) {
      notice('بازدید را برای یک پیشنهاددهنده تنظیم کن.');
      return;
    }
    final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)));
    if (date == null || !mounted || actorId != actor) return;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted || actorId != actor) return;
    if (workAction(() => workStore.proposeVisit(n.id, bidder, actor,
        DateTime(date.year, date.month, date.day, time.hour, time.minute))))
      notice('درخواست بازدید ثبت شد؛ در انتظار پاسخ طرف دیگر.');
  }

  String visitStatus(String s) => switch (s) {
        'accepted' => 'تأییدشده',
        'declined' => 'ردشده',
        'cancelled' => 'لغوشده',
        _ => 'در انتظار پاسخ'
      };
  Widget workVisitCard(WorkVisit v) {
    final n = workStore.need(v.requestId), owner = n.ownerId;
    final mine = v.bidderId == actorId || owner == actorId;
    if (!mine) return const SizedBox.shrink();
    final address = workStore.privateAddress(n.id, actorId);
    return panel([
      Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      small(
          '${workName(owner == actorId ? v.bidderId : owner)} · ${shortDate(v.at)}'),
      label(visitStatus(v.status), color: red),
      small('${n.city} · ${n.district}'),
      if (v.status == 'accepted' && address != null && address.isNotEmpty)
        pair('نشانی بازدید', address),
      if (v.status == 'accepted' && n.latitude != null && n.longitude != null)
        LocationMap(
            city: cityByName(n.city),
            point: MapPoint(n.latitude!, n.longitude!),
            height: 160),
      if (v.status == 'pending' && actorId != v.proposedBy)
        Row(children: [
          Expanded(
              child: button(
                  'تأیید بازدید',
                  () => workAction(() =>
                      workStore.respondVisit(v.id, actorId, 'accepted')))),
          const SizedBox(width: 8),
          Expanded(
              child: button(
                  'رد',
                  () => workAction(
                      () => workStore.respondVisit(v.id, actorId, 'declined')),
                  outlined: true))
        ]),
      if (v.status == 'pending' && actorId == v.proposedBy)
        TextButton(
            onPressed: () => workAction(
                () => workStore.respondVisit(v.id, actorId, 'cancelled')),
            child: const Text('لغو درخواست بازدید')),
      if (v.status == 'accepted')
        button('گفت‌وگو', () => openCanonicalChat('${n.id}::${v.bidderId}'),
            outlined: true),
    ]);
  }

  List<Widget> workDetail() {
    final n = workStore.needs[selectedAd.id];
    if (n == null)
      return [emptyState('درخواست پیدا نشد', 'از صفحه خانه انتخاب کن.')];
    final owner = n.ownerId == actorId, bid = workStore.mine(n.id, actorId);
    final address = workStore.privateAddress(n.id, actorId);
    return [
      if (n.photos.isNotEmpty)
        SizedBox(
            height: 165,
            child: ListView(
                scrollDirection: Axis.horizontal,
                children: n.photos
                    .map((p) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Image.memory(p, width: 210, fit: BoxFit.cover)))
                    .toList()))
      else
        image(n.image, w: 420, h: 150),
      section(n.title),
      small('${n.city} · ${n.district}'),
      label(n.closed || n.archived ? 'بسته‌شده' : 'دریافت پیشنهاد', color: red),
      if (n.crew) label('اکیپ موردنیاز'),
      section('شرح درخواست'),
      Text(n.details, style: const TextStyle(height: 1.7)),
      if (n.quantity.isNotEmpty) pair('مقدار / تعداد', n.quantity),
      if (n.when.isNotEmpty) pair('زمان موردنظر', n.when),
      if (n.budget != null)
        pair('بودجه پیشنهادی', '${money(n.budget!)} / ${n.unit.label}'),
      menuRow(workName(n.ownerId), 'پروفایل درخواست‌دهنده',
          Icons.person_outline, () => showWorkProfile(n.ownerId)),
      Row(children: [
        IconButton(
            tooltip: 'نشان کردن درخواست',
            onPressed: () => toggleAdBookmark(workAd(n)),
            icon: Icon(
                savedIds.contains(n.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: red)),
        IconButton(
            tooltip: 'ارسال برای دوست',
            onPressed: () => shareItem(workAd(n)),
            icon: const Icon(Icons.share_outlined)),
        IconButton(
            tooltip: 'گزارش درخواست',
            onPressed: () => reportTarget('ad:${n.id}'),
            icon: const Icon(Icons.flag_outlined))
      ]),
      if (address != null && address.isNotEmpty) pair('نشانی خصوصی', address),
      if (address != null && n.latitude != null && n.longitude != null)
        LocationMap(
            city: cityByName(n.city),
            point: MapPoint(n.latitude!, n.longitude!),
            height: 170),
      if (owner)
        button('پیشنهادها و مدیریت درخواست', () => openRequest(n.id))
      else if (!n.closed && !n.archived) ...[
        button(bid == null ? 'ارسال پیشنهاد' : 'ویرایش پیشنهاد من',
            () => proposeWork(workAd(n))),
        button('درخواست بازدید قبل از پیشنهاد', () => requestWorkVisit(n),
            outlined: true),
      ],
      ...workStore.visits.values
          .where((v) => v.requestId == n.id && v.bidderId == actorId)
          .map(workVisitCard),
      if (!owner && workStore.conversations.containsKey('${n.id}::$actorId'))
        button('گفت‌وگو', () => openCanonicalChat('${n.id}::$actorId')),
      if (!owner && bid != null) ...[
        section('پیشنهادهای قیمت'),
        small(
            'فقط مبلغ و واحد سایر پیشنهادها؛ اطلاعات اشخاص برای صاحب درخواست است.'),
        ...workStore.visibleBids(n.id, actorId).map((b) => pair(
            b.bidderId == actorId ? 'پیشنهاد من' : 'پیشنهاد دیگر',
            '${money(b.amount)} / ${b.unit.label}')),
      ],
    ];
  }

  void openCanonicalChat(String id) {
    if (!canAct) {
      ensureAccess(() => openCanonicalChat(id));
      return;
    }
    try {
      final c = workStore.chat(id, actorId);
      workStore.read(id, actorId);
      workChatId = c.id;
      chat.clear();
      chatSearch = '';
      showChatSearch = false;
      go('chat');
      persistWork();
    } on StateError catch (e) {
      notice(e.message.toString());
    }
  }

  void gatedOpenThread({Ad? ad}) {
    final n = ad == null ? null : workStore.needs[ad.id];
    if (n != null && n.ownerId != actorId) {
      openCanonicalChat('${n.id}::$actorId');
      return;
    }
    notice(
        'گفت‌وگو را از درخواست مرتبط، پس از انتخاب پیشنهاد یا تأیید بازدید باز کن.');
  }

  List<Widget> workInbox() {
    final list = workStore.conversations.values
        .where((c) => c.contains(actorId))
        .where((c) => normalizeMarketText(
                '${workName(c.peer(actorId))} ${workStore.need(c.requestId).title} ${c.messages.lastOrNull?.text ?? ''}')
            .contains(normalizeMarketText(inboxQuery)))
        .toList();
    list.sort((a, b) =>
        (b.messages.lastOrNull?.at ?? workStore.need(b.requestId).createdAt)
            .compareTo(a.messages.lastOrNull?.at ??
                workStore.need(a.requestId).createdAt));
    return [
      TextField(
          controller: inboxInput,
          decoration: const InputDecoration(
              hintText: 'جست‌وجو در گفت‌وگوها', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => update(() => inboxQuery = v)),
      const SizedBox(height: 8),
      ...list.map((c) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => openCanonicalChat(c.id),
          leading: const CircleAvatar(
              backgroundColor: Color(0xFFF8EFEF),
              child: Icon(Icons.person_outline, color: red)),
          title: Text(workName(c.peer(actorId)),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${workStore.need(c.requestId).title}\n${c.messages.lastOrNull?.fileName ?? c.messages.lastOrNull?.text ?? 'برای هماهنگی پیام بده'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
          trailing: c.unread(actorId) > 0
              ? label(fa(c.unread(actorId)), color: red)
              : small(
                  c.messages.isEmpty ? '' : shortDate(c.messages.last.at)))),
      if (list.isEmpty)
        emptyState(
            inboxQuery.isEmpty ? 'گفت‌وگویی نداری' : 'نتیجه‌ای پیدا نشد',
            inboxQuery.isEmpty
                ? 'پس از تأیید بازدید یا انتخاب پیشنهاد، گفت‌وگو اینجا می‌آید.'
                : 'نام فرد یا عنوان درخواست را جست‌وجو کن.'),
    ];
  }

  Future<void> attachWorkFile() async {
    final id = workChatId, actor = actorId;
    if (id == null) return;
    try {
      final file = await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'تصویر و سند', extensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'txt'
        ], mimeTypes: [
          'image/jpeg',
          'image/png',
          'image/webp',
          'application/pdf',
          'text/plain',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ])
      ]);
      if (file == null || !mounted || actorId != actor || workChatId != id)
        return;
      if (await file.length() > 10 * 1024 * 1024) {
        notice('حداکثر حجم فایل ۱۰ مگابایت است.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted || actorId != actor || workChatId != id) return;
      final name = file.name.replaceAll(RegExp(r'[\\/]'), '_');
      final ext = name.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream'
      };
      workAction(() => workStore.send(id, actor, '',
          fileName: name, mime: mime, bytes: bytes));
    } catch (_) {
      if (mounted) notice('پیوست ارسال نشد؛ دوباره امتحان کن.');
    }
  }

  void sendWorkMessage() {
    if (!canAct || workChatId == null || chat.text.trim().isEmpty) return;
    workAction(() => workStore.send(workChatId!, actorId, chat.text));
    chat.clear();
  }

  Widget durableConversation() {
    final c = currentWorkChat;
    if (c == null || !c.contains(actorId))
      return emptyState('گفت‌وگو در دسترس نیست', 'از صندوق پیام انتخاب کن.');
    final n = workStore.need(c.requestId);
    final messages = c.messages
        .where((m) => normalizeMarketText('${m.text} ${m.fileName ?? ''}')
            .contains(normalizeMarketText(chatSearch)))
        .toList();
    return Column(children: [
      ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(n.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
          onTap: () => openAd(workAd(n)),
          trailing: IconButton(
              tooltip: 'جست‌وجوی پیام',
              onPressed: () => update(() => showChatSearch = !showChatSearch),
              icon: const Icon(Icons.search, size: 20))),
      if (showChatSearch)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
                onChanged: (v) => update(() => chatSearch = v),
                decoration:
                    const InputDecoration(hintText: 'متن پیام یا نام فایل'))),
      Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: () => requestWorkVisit(n, bidderId: c.bidderId),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('قرار بازدید'))),
        Expanded(
            child: TextButton.icon(
                onPressed: () =>
                    createContract(peer: chatPeerName, subject: n.title),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('قرارداد')))
      ]),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
        ...workStore.visits.values
            .where((v) => v.requestId == n.id && v.bidderId == c.bidderId)
            .map(workVisitCard),
        ...messages.map((m) => Align(
            alignment: m.senderId == actorId
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Container(
                constraints: const BoxConstraints(maxWidth: 330),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: m.senderId == actorId
                        ? const Color(0xFFFFEEEE)
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.text.isNotEmpty)
                        SelectableText(m.text,
                            style: const TextStyle(fontSize: 13, height: 1.6)),
                      if (m.bytes != null &&
                          m.mime?.startsWith('image/') == true)
                        InkWell(
                            onTap: () => showDialog<void>(
                                context: context,
                                builder: (ctx) => Dialog(
                                    child: InteractiveViewer(
                                        child: Image.memory(m.bytes!,
                                            errorBuilder: (_, __, ___) =>
                                                const Text(
                                                    'تصویر قابل نمایش نیست.'))))),
                            child: Image.memory(m.bytes!,
                                width: 230,
                                height: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Text('تصویر قابل نمایش نیست.'))),
                      if (m.bytes != null)
                        TextButton.icon(
                            onPressed: () async {
                              try {
                                await deliverFile(m.bytes!, m.fileName!,
                                    m.mime ?? 'application/octet-stream');
                              } catch (_) {
                                if (mounted) notice('دریافت پیوست انجام نشد.');
                              }
                            },
                            icon: const Icon(Icons.download, size: 17),
                            label: Text(m.fileName ?? 'پیوست',
                                overflow: TextOverflow.ellipsis)),
                      Text(
                          '${shortDate(m.at)}${m.senderId == actorId && (c.readCount[c.peer(actorId)] ?? 0) > c.messages.indexOf(m) ? ' · دیده‌شده' : ''}',
                          style: const TextStyle(fontSize: 9, color: muted)),
                    ])))),
        if (messages.isEmpty)
          small(chatSearch.isEmpty
              ? 'توافق‌ها و شرایط را اینجا بنویسید.'
              : 'پیامی با این جست‌وجو پیدا نشد.'),
        ...chatContractCards(c),
      ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
              'پیام‌ها و پیوست‌ها برای مراجعه بعدی نگه داشته می‌شوند؛ این نسخه آزمایشی فقط روی همین دستگاه ذخیره می‌کند.',
              style: const TextStyle(fontSize: 10, color: muted))),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(children: [
                IconButton(
                    tooltip: 'ارسال عکس یا فایل',
                    onPressed: attachWorkFile,
                    icon: const Icon(Icons.attach_file, size: 21)),
                Expanded(
                    child: TextField(
                        controller: chat,
                        minLines: 1,
                        maxLines: 3,
                        onSubmitted: (_) => sendWorkMessage(),
                        decoration: const InputDecoration(
                            hintText: 'پیام بنویس…', isDense: true))),
                IconButton.filled(
                    tooltip: 'ارسال پیام',
                    onPressed: sendWorkMessage,
                    icon: const Icon(Icons.send, size: 19)),
              ]))),
    ]);
  }

  Iterable<Widget> chatContractCards(WorkConversation c) sync* {
    for (final space in accountSpaces.values) {
      for (final e in space.drafts
          .asMap()
          .entries
          .where((e) => e.value.threadId == c.id)) {
        final d = e.value;
        if (space.profile.id != actorId && d.revisions.isEmpty) continue;
        yield panel([
          Text(d.title),
          small(d.status),
          if (space.profile.id == actorId)
            TextButton(
                onPressed: () {
                  contractIndex = e.key;
                  go('contract');
                },
                child: const Text('ویرایش و نسخه‌ها'))
          else
            TextButton(
                onPressed: () => showContractRevision(d, d.revisions.last),
                child: const Text('مشاهده نسخه ذخیره‌شده')),
        ]);
      }
    }
  }
}
