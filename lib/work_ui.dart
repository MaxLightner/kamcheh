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
                  subtitle: Text(
                      workStore.contextInfo(c.contextId, c.contextType).title),
                  onTap: () => Navigator.pop(ctx, c.id))),
            ]));
    if (id == null || !mounted || actorId != actor) return;
    final p = profile ? findProfile(ad) : null;
    final text = p != null
        ? 'پروفایل ${p.name}\n${publicProfileUrl(p.id)}'
        : '${ad.need ? 'درخواست' : 'آگهی خدمات'}: ${ad.title}\n${ad.area}';
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
      : workStore
          .contextInfo(currentWorkChat!.contextId, currentWorkChat!.contextType)
          .title;
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
    for (final ad
        in [...demoAds, ...marketDemoAds, ...initialOwnAds].map(localDemoAd)) {
      if (ad.need ||
          !['نیرو', 'خدمات', 'مهندسی'].contains(ad.category) ||
          ad.title.contains('نظارت')) continue;
      final owner = profileRepository.profiles
          .where((p) => p.name == ad.owner)
          .firstOrNull;
      if (owner == null) continue;
      repo.services[ad.id] = ServiceListing(
          id: ad.id,
          ownerId: owner.id,
          title: ad.title,
          details: ad.description.isEmpty ? ad.title : ad.description,
          city: ad.city,
          district: ad.district,
          category: ad.category,
          image: ad.image,
          price: ad.price,
          amount: ad.pricing?.amount,
          unit: ad.pricing?.unit ?? PriceUnit.project,
          skills: adSkills(ad),
          galleryAssets: [ad.image, 'concrete', 'scaffold'].toSet().toList());
    }
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
          crew: ad.title.contains('اکیپ'),
          skills: adSkills(ad));
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
        'نشانی نمونه: مشهد، الهیه، محل پروژه';
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
      skills: n.skills);
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
    workDeadline = n?.deadline;
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
    workSkills.clear();
    workSkills.addAll(n?.skills ?? []);
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
                  deadlineInput(),
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
                            onChanged: (v) => update(() {
                                  postCategory = v!;
                                  workSkills.clear();
                                })),
                        const SizedBox(height: 10),
                        small('تخصص موردنیاز (اختیاری)'),
                        Wrap(
                            spacing: 6,
                            children: marketCategory(postCategory)
                                .skills
                                .map((skill) => FilterChip(
                                    label: Text(skill),
                                    selected: workSkills.contains(skill),
                                    onSelected: (v) => update(() {
                                          v
                                              ? workSkills.add(skill)
                                              : workSkills.remove(skill);
                                        })))
                                .toList()),
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
        deadline: workDeadline,
        createdAt: workEditingId == null
            ? null
            : workStore.need(workEditingId!).createdAt,
        privateAddress: workPrivate.text.trim(),
        crew: workCrew,
        skills: workSkills.toList(),
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
                  pair(
                      'مهلت پیشنهاد',
                      n.deadline == null
                          ? 'بدون مهلت'
                          : shortDate(n.deadline!)),
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
        miniTabs(['درخواست‌های من', 'پیشنهادهای من'], requestTab,
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
                        '${requestStatus(n)} · ${fa(workStore.proposals(n.id).length)} پیشنهاد'),
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
      visible.sort((a, b) => bidSortDescending
          ? b.amount.compareTo(a.amount)
          : a.amount.compareTo(b.amount));
    return [
      Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      small('${n.city} · ${n.district}'),
      pair('وضعیت', requestStatus(n)),
      pair('مهلت پیشنهاد',
          n.deadline == null ? 'بدون مهلت' : shortDate(n.deadline!)),
      if (n.expiredAt(workStore.now()))
        small(
            'برای دریافت پیشنهاد جدید، مهلت را ویرایش کن. پیشنهادهای قبلی قابل بررسی‌اند.'),
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
      const SizedBox(height: 12),
      DropdownButtonFormField<PriceUnit>(
          key: ValueKey('sort-$selectedRequest-$bidSortUnit'),
          isExpanded: true,
          initialValue: bidSortUnit,
          decoration:
              const InputDecoration(labelText: 'مرتب‌سازی قیمت در یک واحد'),
          items: [
            const DropdownMenuItem<PriceUnit>(
                value: null, child: Text('همه · ترتیب دریافت')),
            ...all
                .map((b) => b.unit)
                .toSet()
                .map((u) => DropdownMenuItem(value: u, child: Text(u.label)))
          ],
          onChanged: (u) => update(() => bidSortUnit = u)),
      if (bidSortUnit != null)
        Wrap(spacing: 6, children: [
          ChoiceChip(
              label: const Text('ارزان‌تر اول'),
              selected: !bidSortDescending,
              onSelected: (_) => update(() => bidSortDescending = false)),
          ChoiceChip(
              label: const Text('گران‌تر اول'),
              selected: bidSortDescending,
              onSelected: (_) => update(() => bidSortDescending = true)),
        ]),
      ...visible.map((b) => bidComparisonCard(n, b)),
      if (all.isEmpty)
        emptyState('هنوز پیشنهادی نرسیده',
            'درخواست‌های فعال در فهرست درخواست‌ها دیده می‌شوند.'),
      section('درخواست‌های گفتگو'),
      ...requestConnections(n).map((c) => requestConnectionCard(n, c)),
      if (requestConnections(n).isEmpty)
        small('درخواست گفتگویی دریافت نکرده‌ای.'),
      section('درخواست‌های بازدید'),
      ...workStore.visits.values
          .where((v) => v.contextType == 'request' && v.requestId == n.id)
          .map(workVisitCard),
      if (!workStore.visits.values
          .any((v) => v.contextType == 'request' && v.requestId == n.id))
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
          if (n.chosenId == b.id || n.selectedBidIds.contains(b.id))
            label('انتخاب‌شده', color: red)
        ]),
        pair('پیشنهاد', '${money(b.amount)} / ${b.unit.label}'),
        pair('زمان', b.when),
        if (b.terms.isNotEmpty) small(b.terms),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: button(
                  'پروفایل و سابقه', () => showWorkProfile(b.bidderId),
                  outlined: true)),
          const SizedBox(width: 8),
          Expanded(
              child: workStore.conversations
                      .containsKey('${n.id}::${b.bidderId}')
                  ? button('گفتگو',
                      () => openCanonicalChat('${n.id}::${b.bidderId}'))
                  : !n.closed && !n.archived
                      ? button(
                          'انتخاب برای هماهنگی', () => selectRequestBid(n, b))
                      : button('درخواست بسته است',
                          () => notice('درخواست را باز کن.'),
                          outlined: true)),
        ]),
      ]);
  void showWorkProfile(String id) {
    final p = profileRepository.profile(id);
    if (p == null) {
      notice('پروفایل پیدا نشد.');
      return;
    }
    viewPerson(p);
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
    if (!n.acceptsAt(workStore.now()) || n.ownerId == actorId) {
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
    final date = await pickPersianDate(context,
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
    final n = workStore.contextInfo(v.contextId, v.contextType),
        owner = n.ownerId;
    final request =
        v.contextType == 'request' ? workStore.needs[v.contextId] : null;
    final mine = v.bidderId == actorId || owner == actorId;
    if (!mine) return const SizedBox.shrink();
    final address = v.contextType == 'request'
        ? workStore.privateAddress(v.contextId, actorId)
        : null;
    return panel([
      Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      small(
          '${workName(owner == actorId ? v.bidderId : owner)} · ${shortDate(v.at)}'),
      label(
          v.status == 'pending' && !v.at.isAfter(DateTime.now())
              ? 'زمان قرار گذشته؛ تأیید ممکن نیست'
              : visitStatus(v.status),
          color: red),
      TextButton.icon(
          onPressed: () =>
              showWorkProfile(owner == actorId ? v.bidderId : owner),
          icon: const Icon(Icons.person_outline, size: 17),
          label: const Text('پروفایل طرف مقابل')),
      small('${n.city} · ${n.district}'),
      if (v.status == 'accepted' && address != null && address.isNotEmpty)
        pair('نشانی بازدید', address),
      if (v.status == 'accepted' &&
          request?.latitude != null &&
          request?.longitude != null)
        LocationMap(
            city: cityByName(n.city),
            point: MapPoint(request!.latitude!, request.longitude!),
            height: 160),
      if (v.status == 'pending' &&
          actorId != v.proposedBy &&
          v.at.isAfter(DateTime.now()))
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
      if (v.status == 'pending' &&
          actorId != v.proposedBy &&
          !v.at.isAfter(DateTime.now()))
        TextButton(
            onPressed: () => workAction(
                () => workStore.respondVisit(v.id, actorId, 'declined')),
            child: const Text('بستن درخواست بازدید')),
      if (v.status == 'accepted')
        button(
            'گفت‌وگو',
            () => openCanonicalChat(workStore.conversationKey(
                v.contextId, v.bidderId, v.contextType)),
            outlined: true),
    ]);
  }

  List<Widget> workDetail() {
    final n = workStore.needs[selectedAd.id];
    if (n == null)
      return [emptyState('درخواست پیدا نشد', 'از فهرست درخواست‌ها انتخاب کن.')];
    final owner = n.ownerId == actorId, bid = workStore.mine(n.id, actorId);
    final address = workStore.privateAddress(n.id, actorId);
    return [
      ListingGallery(
          key: ValueKey('request-gallery-${n.id}'),
          photos: n.photos,
          assets: n.photos.isEmpty ? [n.image] : const []),
      section(n.title),
      small('${n.city} · ${n.district}'),
      label(requestStatus(n), color: red),
      pair('مهلت دریافت پیشنهاد',
          n.deadline == null ? 'بدون مهلت' : shortDate(n.deadline!)),
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
      else if (n.acceptsAt(workStore.now())) ...[
        button(bid == null ? 'ارسال پیشنهاد' : 'ویرایش پیشنهاد من',
            () => proposeWork(workAd(n))),
        button('درخواست بازدید قبل از پیشنهاد', () => requestWorkVisit(n),
            outlined: true),
        if (!workStore.conversations.containsKey('${n.id}::$actorId') &&
            !requestConnections(n).any((c) => c.status == 'pending'))
          button('درخواست گفتگو', () => askRequestConversation(n),
              outlined: true),
      ],
      if (!owner)
        ...requestConnections(n).map((c) => requestConnectionCard(n, c)),
      ...workStore.visits.values
          .where((v) =>
              v.contextType == 'request' &&
              v.requestId == n.id &&
              v.bidderId == actorId)
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
      chatSearchInput.clear();
      showChatSearch = false;
      go('chat');
      scrollToLastMessage();
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
                '${workName(c.peer(actorId))} ${workStore.contextInfo(c.contextId, c.contextType).title} ${c.messages.map((m) => '${m.text} ${m.fileName ?? ''}').join(' ')}')
            .contains(normalizeMarketText(inboxQuery)))
        .toList();
    list.sort((a, b) => (b.messages.lastOrNull?.at ?? b.createdAt)
        .compareTo(a.messages.lastOrNull?.at ?? a.createdAt));
    return [
      TextField(
          controller: inboxInput,
          decoration: InputDecoration(
              hintText: 'نام، موضوع، پیام یا نام فایل',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: inboxQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'پاک کردن جست‌وجو',
                      onPressed: () => update(() {
                            inboxQuery = '';
                            inboxInput.clear();
                          }),
                      icon: const Icon(Icons.close, size: 18))),
          onChanged: (v) => update(() => inboxQuery = v)),
      const SizedBox(height: 8),
      ...list.map((c) => ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => openCanonicalChat(c.id),
          leading: CircleAvatar(
              backgroundImage:
                  profileRepository.profile(c.peer(actorId))?.avatar == null
                      ? null
                      : MemoryImage(
                          profileRepository.profile(c.peer(actorId))!.avatar!),
              backgroundColor: Color(0xFFF8EFEF),
              child: profileRepository.profile(c.peer(actorId))?.avatar == null
                  ? const Icon(Icons.person_outline, color: red)
                  : null),
          title: Text(workName(c.peer(actorId)),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${c.contextType == 'service' ? 'آگهی' : 'درخواست'}: ${workStore.contextInfo(c.contextId, c.contextType).title}\n${inboxMessagePreview(c)}',
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
                ? 'پس از پذیرش ارتباط، تأیید بازدید یا انتخاب پیشنهاد، گفتگو اینجا می‌آید.'
                : 'نام فرد، موضوع، متن پیام یا نام فایل را جست‌وجو کن.'),
    ];
  }

  Future<void> attachWorkFile() async {
    final id = workChatId, actor = actorId;
    if (id == null || sendingAttachment) return;
    update(() => sendingAttachment = true);
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
      if (![
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
      ].contains(ext)) {
        notice('عکس یا سند با فرمت مجاز انتخاب کن.');
        return;
      }
      final mime = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => 'application/octet-stream'
      };
      final caption = await previewAttachment(name, mime, bytes);
      if (!mounted || caption == null || actorId != actor || workChatId != id)
        return;
      if (workAction(() => workStore.send(id, actor, caption,
          fileName: name, mime: mime, bytes: bytes))) scrollToLastMessage();
    } catch (_) {
      if (mounted) notice('پیوست ارسال نشد؛ دوباره امتحان کن.');
    } finally {
      if (mounted) update(() => sendingAttachment = false);
    }
  }

  void sendWorkMessage() {
    if (!canAct || workChatId == null || chat.text.trim().isEmpty) return;
    if (workAction(() => workStore.send(workChatId!, actorId, chat.text))) {
      chat.clear();
      scrollToLastMessage();
    }
  }

  Widget durableConversation() {
    final c = currentWorkChat;
    if (c == null || !c.contains(actorId))
      return emptyState('گفت‌وگو در دسترس نیست', 'از صندوق پیام انتخاب کن.');
    final n = workStore.contextInfo(c.contextId, c.contextType);
    final messages = c.messages
        .where((m) => normalizeMarketText('${m.text} ${m.fileName ?? ''}')
            .contains(normalizeMarketText(chatSearch)))
        .toList();
    return Column(children: [
      ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const Icon(Icons.person_outline, size: 20),
          title: Text('پروفایل $chatPeerName',
              style: const TextStyle(fontSize: 12)),
          onTap: () => showWorkProfile(c.peer(actorId)),
          trailing: const Icon(Icons.chevron_left, size: 18)),
      ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
              '${c.contextType == 'service' ? 'آگهی' : 'درخواست'}: ${n.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
          onTap: () => openAd(adFor(c.contextId)),
          trailing: IconButton(
              tooltip: 'جست‌وجوی پیام',
              onPressed: () => update(() {
                    showChatSearch = !showChatSearch;
                    if (!showChatSearch) {
                      chatSearch = '';
                      chatSearchInput.clear();
                    }
                  }),
              icon: const Icon(Icons.search, size: 20))),
      if (showChatSearch)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
                controller: chatSearchInput,
                onChanged: (v) => update(() => chatSearch = v),
                decoration:
                    const InputDecoration(hintText: 'متن پیام یا نام فایل'))),
      if (showChatSearch && chatSearch.isNotEmpty)
        small('${fa(messages.length)} پیام پیدا شد'),
      Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: () => c.contextType == 'service'
                    ? requestServiceChatVisit(c)
                    : requestWorkVisit(workStore.need(c.contextId),
                        bidderId: c.bidderId),
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
          child: ListView(
              controller: chatScroll,
              padding: const EdgeInsets.all(12),
              children: [
            if (chatSearch.isEmpty)
              ...workStore.visits.values
                  .where((v) =>
                      v.contextId == c.contextId &&
                      v.contextType == c.contextType &&
                      v.bidderId == c.bidderId)
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
                                style:
                                    const TextStyle(fontSize: 13, height: 1.6)),
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
                                    await deliverFile(
                                        m.bytes!,
                                        m.fileName ?? 'attachment.bin',
                                        m.mime ?? 'application/octet-stream');
                                  } catch (_) {
                                    if (mounted)
                                      notice('دریافت پیوست انجام نشد.');
                                  }
                                },
                                icon: const Icon(Icons.download, size: 17),
                                label: Text(m.fileName ?? 'پیوست',
                                    overflow: TextOverflow.ellipsis)),
                          if (m.bytes != null)
                            Text(
                                '${fa((m.bytes!.length / 1024).ceil())} کیلوبایت',
                                style: const TextStyle(
                                    fontSize: 10, color: muted)),
                          Text(
                              '${shortDate(m.at)}${m.senderId == actorId && (c.readCount[c.peer(actorId)] ?? 0) > c.messages.indexOf(m) ? ' · دیده‌شده' : ''}',
                              style:
                                  const TextStyle(fontSize: 9, color: muted)),
                        ])))),
            if (messages.isEmpty)
              small(chatSearch.isEmpty
                  ? 'توافق‌ها و شرایط را اینجا بنویسید.'
                  : 'پیامی با این جست‌وجو پیدا نشد.'),
            if (chatSearch.isEmpty) ...chatContractCards(c),
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
                    onPressed: sendingAttachment ? null : attachWorkFile,
                    icon: sendingAttachment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.attach_file, size: 21)),
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
        if (space.profile.id != actorId &&
            !d.parties.containsKey(actorId) &&
            d.revisions.isEmpty) continue;
        yield panel([
          Text(d.title),
          small(d.status),
          if (space.profile.id == actorId || d.parties.containsKey(actorId))
            TextButton(
                onPressed: () {
                  selectedContractId = d.id;
                  if (space.profile.id == actorId) contractIndex = e.key;
                  go('contract');
                },
                child: const Text('تکمیل، تأیید و نسخه‌ها'))
          else
            TextButton(
                onPressed: () => showContractRevision(d, d.revisions.last),
                child: const Text('مشاهده نسخه ذخیره‌شده')),
        ]);
      }
    }
  }
}
