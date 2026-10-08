part of 'main.dart';

extension NetworkUi on _AppShellState {
  double peerScore(Ad ad, {bool quality = false}) {
    final values = workReviews
        .where((r) => r.peer == ad.owner && (!quality || r.quality != null))
        .map((r) => (quality ? r.quality! : r.punctuality).toDouble())
        .toList();
    final base = double.tryParse(ad.rating
            .replaceAllMapped(
                RegExp(r'[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
            .replaceAll('٫', '.')) ??
        4.7;
    values.insert(0, quality ? base : 4.6);
    return values.reduce((a, b) => a + b) / values.length;
  }

  String ratingText(Ad ad) => fa(
      ((peerScore(ad) + peerScore(ad, quality: true)) / 2).toStringAsFixed(1));
  Widget scores() => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: line), bottom: BorderSide(color: line))),
      child: Row(children: [
        Expanded(
            child: Text(
                'خوش‌قولی  ${fa(peerScore(selectedAd).toStringAsFixed(1))} ★',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12))),
        Expanded(
            child: Text(
                'کیفیت کار  ${fa(peerScore(selectedAd, quality: true).toStringAsFixed(1))} ★',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))
      ]));

  List<Ad> get archivedAds => [
        for (final space in accountSpaces.values)
          ...space.createdAds.map(localDemoAd).map((a) =>
              a.kind == AdKind.tender ? a.copyWith(kind: AdKind.need) : a),
        ...demoAds.map(localDemoAd).map(
            (a) => a.kind == AdKind.tender ? a.copyWith(kind: AdKind.need) : a),
        ...marketDemoAds.map(localDemoAd).map(
            (a) => a.kind == AdKind.tender ? a.copyWith(kind: AdKind.need) : a)
      ];
  List<Ad> get allAds => serviceFeedAds;
  bool ownAd(Ad ad) =>
      signedIn &&
      (ad.need
              ? workStore.needs[ad.id]?.ownerId
              : workStore.services[ad.id]?.ownerId) ==
          actorId;
  Ad adFor(String id) => workStore.needs.containsKey(id)
      ? workAd(workStore.need(id))
      : workStore.services.containsKey(id)
          ? serviceAd(workStore.services[id]!)
          : archivedAds.firstWhere((a) => a.id == id);
  bool isClosed(Ad ad) => workStore.needs[ad.id]?.closed ?? false;
  List<String> profileSkills(Ad ad) =>
      ownAd(ad) ? mySkills.toList() : adSkills(ad);
  void openProfile(Ad ad) {
    selectedAd = ad;
    go(ownAd(ad)
        ? 'ownProfile'
        : ad.category == 'نیرو'
            ? 'worker'
            : ad.category == 'مصالح' || ad.category == 'ابزار'
                ? 'supplier'
                : 'pro');
  }

  void selectTab(int index) {
    if (index == 3 && !signedIn) {
      ensureAccess(() => selectTab(index), activity: false);
      return;
    }
    update(() {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      FocusManager.instance.primaryFocus?.unfocus();
      tab = index;
      history.clear();
      page = ['home', 'professionals', 'requests', 'inbox', 'me'][index];
      if (index == 2) changingAdCategory = false;
      if (index == 3) {
        messageTab = 0;
        inboxQuery = '';
        inboxInput.clear();
      }
    });
  }

  Widget miniTabs(List<String> names, int selected, ValueChanged<int> action) =>
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: names
                  .asMap()
                  .entries
                  .map((e) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          label: Text(e.value,
                              style: const TextStyle(fontSize: 12)),
                          selected: selected == e.key,
                          onSelected: (_) => action(e.key))))
                  .toList()));
  Widget emptyState(String title, String text,
          {String? action, VoidCallback? onTap}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
          child: Column(children: [
            const Icon(Icons.inbox_outlined, size: 32, color: muted),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            small(text),
            if (action != null)
              TextButton(onPressed: onTap, child: Text(action))
          ]));
  Widget adPhoto(Ad ad, {double width = 92, double height = 92}) =>
      ad.photos.isEmpty
          ? image(ad.image, w: width, h: height)
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(ad.photos.first,
                  width: width, height: height, fit: BoxFit.cover));
  Widget skillCards(Iterable<String> skills, {VoidCallback? editAction}) =>
      Wrap(spacing: 7, runSpacing: 7, children: [
        ...skills.map((skill) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_outline, size: 15, color: red),
              const SizedBox(width: 5),
              Text(skill, style: const TextStyle(fontSize: 12))
            ]))),
        if (editAction != null)
          ActionChip(
              onPressed: editAction,
              avatar: const Icon(Icons.add, size: 17),
              label:
                  const Text('افزودن / ویرایش', style: TextStyle(fontSize: 11)))
      ]);

  Future<void> editSkills() async {
    final selected = Set<String>.from(mySkills);
    final result = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => StatefulBuilder(
            builder: (sheet, setSheet) => SafeArea(
                child: SizedBox(
                    height: MediaQuery.sizeOf(sheet).height * .8,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            const Expanded(
                                child: Text('مهارت‌ها و زمینه فعالیت',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                onPressed: () => Navigator.pop(sheet),
                                icon: const Icon(Icons.close, size: 20))
                          ])),
                      Expanded(
                          child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: skillCatalog.entries
                                      .expand((e) => [
                                            section(
                                                marketCategory(e.key).label),
                                            Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: e.value
                                                    .map((skill) => FilterChip(
                                                        label: Text(skill,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12)),
                                                        selected: selected
                                                            .contains(skill),
                                                        onSelected: (v) =>
                                                            setSheet(() => v
                                                                ? selected
                                                                    .add(skill)
                                                                : selected
                                                                    .remove(
                                                                        skill))))
                                                    .toList())
                                          ])
                                      .toList()))),
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton(
                              onPressed: () => Navigator.pop(sheet, selected),
                              child: const Text('ذخیره کارت‌ها')))
                    ])))));
    if (result != null && mounted)
      update(() {
        mySkills
          ..clear()
          ..addAll(result);
      });
  }

  Widget profileActions(Ad ad) => Row(children: [
        Expanded(child: button('پیام', () => openThread(ad: ad))),
        const SizedBox(width: 6),
        IconButton(
            tooltip: savedPeople.containsKey(ad.owner)
                ? 'حذف نشان فرد'
                : 'نشان کردن فرد',
            onPressed: () => togglePersonBookmark(ad),
            icon: Icon(
                savedPeople.containsKey(ad.owner)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: red)),
        IconButton(
            tooltip: 'ارسال پروفایل برای دوست',
            onPressed: () => shareItem(ad, profile: true),
            icon: const Icon(Icons.share_outlined, size: 20))
      ]);
  List<Widget> profileView(
      {bool workerMode = false, bool supplierMode = false}) {
    final ad = selectedAd;
    final linkedProfile = findProfile(ad);
    if (linkedProfile != null) return publicProfileView(linkedProfile);
    return [
      Row(children: [
        adPhoto(ad, width: 72, height: 72),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad.owner,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          small(ad.title),
          small('محدوده فعالیت: ${ad.serviceArea?.label ?? ad.area}'),
          small('${ratingText(ad)} ★ · بازخورد همکاری')
        ]))
      ]),
      const SizedBox(height: 12),
      profileBadges(ad),
      const SizedBox(height: 8),
      skillCards(profileSkills(ad)),
      const SizedBox(height: 12),
      scores(),
      if (workerMode) ...[
        pair('سابقه کار', '۴ سال · بتن‌ریزی و کار ساختمان'),
        pair('زمان آمادگی', 'شنبه تا پنجشنبه، با هماهنگی'),
        pair('سن · اعلام‌شده توسط فرد', '۲۹ سال')
      ],
      section(supplierMode ? 'کالاها و خدمات' : 'معرفی و تخصص'),
      small(ad.description.isNotEmpty
          ? ad.description
          : '${ad.title}؛ زمان، محدوده و شرایط همکاری را پیش از شروع هماهنگ کنید.'),
      pair('قیمت / دستمزد', priceText(ad)),
      if (supplierMode && adSkills(ad).contains('کاشی و سرامیک')) ...[
        section('نمونه متریال'),
        Row(
            children: List.generate(
                3,
                (i) => Expanded(
                    child: InkWell(
                        onTap: () => update(() => material = i),
                        child: Container(
                            margin: const EdgeInsets.only(left: 5),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: material == i ? red : line),
                                borderRadius: BorderRadius.circular(8)),
                            child: Column(children: [
                              image('material$i', w: 110, h: 85),
                              const SizedBox(height: 5),
                              Text(
                                  [
                                    'پرسلان کرم',
                                    'طرح سنگ طوسی',
                                    'دیوار سفید'
                                  ][i],
                                  style: const TextStyle(fontSize: 11))
                            ])))))),
        section([
          'سرامیک پرسلان کرم',
          'سرامیک طرح سنگ طوسی',
          'کاشی سفید براق'
        ][material]),
        image('material$material', w: 400, h: 160),
        pair('ابعاد موجود', '۶۰×۱۲۰ و ۸۰×۸۰'),
        button('درخواست قیمت', () async {
          final value = await edit('مقدار و محل تحویل', '',
              hint: 'مثلاً ۸۰ متر مربع، الهیه');
          if (value != null && value.isNotEmpty && mounted) {
            openThread(ad: ad);
            update(() => sent.add('درخواست قیمت: $value'));
          }
        }),
      ] else ...[
        section(workerMode ? 'سابقه کار' : 'نمونه‌کارها'),
        gallery([ad.image, 'concrete', 'scaffold']),
        if (workerMode)
          small('همکاری در بتن‌ریزی سقف و جابه‌جایی مصالح در پروژه مسکونی.')
      ],
      if (linkedProfile != null) ...memberSection(linkedProfile),
      section('بازخورد همکاری‌ها'),
      panel([
        const Text('مهدی احمدی · همکاری ثبت‌شده',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        small('طبق قرار مراجعه کردند و همکاری مطابق توافق انجام شد.')
      ]),
      ...workReviews.where((r) => r.peer == ad.owner).map(reviewCard),
      profileActions(ad),
      TextButton(
          onPressed: () => recordReviewForPeer(ad.owner),
          child: const Text('ثبت تجربه همکاری')),
    ];
  }

  List<Widget> directoryView() => profileDirectory();

  Widget personRow(Ad ad) => InkWell(
      onTap: () => openProfile(ad),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line))),
          child: Row(children: [
            adPhoto(ad, width: 52, height: 52),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ad.owner,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  profileBadges(ad, compact: true),
                  const SizedBox(height: 4),
                  small(profileSkills(ad).join(' · ')),
                  small('${ad.area} · ${ratingText(ad)} ★')
                ])),
            IconButton(
                tooltip: 'پیام به ${ad.owner}',
                onPressed: () => openThread(ad: ad),
                icon: const Icon(Icons.chat_bubble_outline, size: 20))
          ])));

  List<Widget> messageHub() => [
        miniTabs(['گفت‌وگوها', 'نشان‌ها'], messageTab,
            (i) => update(() => messageTab = i)),
        const SizedBox(height: 5),
        if (messageTab == 0) ...inbox() else ...bookmarkView()
      ];
  List<Widget> bookmarkView() {
    final ads = [...allAds, ...workFeedAds]
        .where((ad) => savedIds.contains(ad.id))
        .toList();
    final people = savedPeople.values
        .where((a) => bookmarkTab == 2
            ? ['مصالح', 'ابزار'].contains(a.category)
            : !['مصالح', 'ابزار'].contains(a.category))
        .toList();
    return [
      miniTabs(['آگهی‌ها و درخواست‌ها', 'پروفایل‌ها'], bookmarkTab,
          (i) => update(() => bookmarkTab = i)),
      if (bookmarkTab == 0)
        ...ads.map(networkAdRow)
      else
        ...people.map(personRow),
      if (bookmarkTab == 0 ? ads.isEmpty : people.isEmpty)
        emptyState('هنوز نشانی نداری', 'در آگهی یا پروفایل روی علامت نشان بزن.')
    ];
  }

  Future<void> shareItem(Ad ad, {bool profile = false}) async {
    final title = profile ? 'پروفایل ${ad.owner}' : ad.title;
    final linkedProfile = profile ? findProfile(ad) : null;
    final profileLink = linkedProfile == null
        ? null
        : publicProfileUrl(linkedProfile.id,
            configuredBase: const String.fromEnvironment('PUBLIC_WEB_URL'));
    final text =
        '$title\n${ad.area}\n${profile ? profileSkills(ad).join('، ') : ad.price}\nکمچه${profileLink == null ? '' : '\n$profileLink'}';
    await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('ارسال برای دوست',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      small(title),
                      menuRow('ارسال در گفت‌وگو', 'انتخاب یکی از گفت‌وگوها',
                          Icons.chat_bubble_outline, () {
                        Navigator.pop(sheet);
                        chooseShareRecipient(ad, profile: profile);
                      }),
                      menuRow('اشتراک‌گذاری', 'ارسال با برنامه‌های دیگر',
                          Icons.share_outlined, () async {
                        Navigator.pop(sheet);
                        try {
                          await SharePlus.instance
                              .share(ShareParams(text: text, title: title));
                        } catch (_) {
                          if (mounted)
                            notice(
                                'اشتراک‌گذاری در این مرورگر پشتیبانی نشد؛ از کپی متن استفاده کن.');
                        }
                      }),
                      menuRow(
                          profileLink == null ? 'کپی متن' : 'کپی لینک پروفایل',
                          profileLink == null
                              ? 'عنوان، محدوده و شرایط'
                              : profileLink.toString(),
                          Icons.copy_outlined, () async {
                        await Clipboard.setData(ClipboardData(
                            text: profileLink?.toString() ?? text));
                        if (sheet.mounted) Navigator.pop(sheet);
                        if (mounted)
                          notice(profileLink == null
                              ? 'متن کپی شد'
                              : ['localhost', '127.0.0.1']
                                      .contains(profileLink.host)
                                  ? 'لینک کپی شد؛ لینک محلی فقط روی همین کامپیوتر باز می‌شود.'
                                  : 'لینک پروفایل کپی شد.');
                      })
                    ]))));
  }

  Future<void> chooseShareRecipient(Ad ad, {bool profile = false}) =>
      shareInWorkChat(ad, profile: profile);

  Future<void> legacyChooseShareRecipient(Ad ad, {bool profile = false}) async {
    if (!canAct) {
      await ensureAccess(() => chooseShareRecipient(ad, profile: profile));
      return;
    }
    final recipient = await showModalBottomSheet<int>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .6,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const Expanded(
                            child: Text('انتخاب گفت‌وگو',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close, size: 20))
                      ])),
                  Expanded(
                      child: ListView(
                          children: threads
                              .asMap()
                              .entries
                              .map((e) => ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFF5F5F6),
                                      child: Text(e.value.peer.characters.first,
                                          style: const TextStyle(color: ink))),
                                  title: Text(e.value.peer,
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(e.value.subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11)),
                                  onTap: () => Navigator.pop(sheet, e.key)))
                              .toList()))
                ]))));
    if (recipient == null || !mounted) return;
    update(() {
      threadIndex = recipient;
      final t = threads[recipient];
      t.references[t.outgoing.length] = SharedReference(ad, profile: profile);
      t.outgoing.add(profile ? 'پروفایل ${ad.owner}' : ad.title);
      t.time = 'اکنون';
    });
    openThread();
  }

  Widget sharedMessage(SharedReference ref) => Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
          onTap: () => ref.profile ? openProfile(ref.ad) : openAd(ref.ad),
          child: Container(
              width: 280,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  border: Border.all(color: const Color(0xFFEED9D9)),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                adPhoto(ref.ad, width: 48, height: 48),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      small(
                          ref.profile ? 'پروفایل ارسال‌شده' : 'آگهی ارسال‌شده'),
                      Text(ref.profile ? ref.ad.owner : ref.ad.title,
                          maxLines: 2,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      small('مشاهده جزئیات')
                    ]))
              ]))));

  Widget formField(String title, TextEditingController controller,
          {bool required = false, bool number = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextFormField(
                controller: controller,
                minLines: lines,
                maxLines: lines,
                keyboardType: number
                    ? TextInputType.number
                    : lines > 1
                        ? TextInputType.multiline
                        : TextInputType.text,
                style: const TextStyle(fontSize: 13),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return required ? 'این قسمت را تکمیل کن' : null;
                  if (number &&
                      (parsePriceInput(v) == null || parsePriceInput(v)! <= 0))
                    return 'یک عدد بیشتر از صفر وارد کن';
                  return null;
                })
          ]));
  Future<List<Uint8List>> selectPhotos(int available) async {
    if (available <= 0) return [];
    try {
      final files = await ImagePicker().pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
          limit: available > 1 ? available : null);
      final photos = <Uint8List>[];
      for (final file in files.take(available)) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 12 * 1024 * 1024) {
          if (mounted) notice('عکس باید کمتر از ۱۲ مگابایت باشد');
          continue;
        }
        if (!['png', 'jpg', 'jpeg', 'webp', 'gif']
            .contains(file.name.split('.').last.toLowerCase())) {
          if (mounted) notice('عکس با فرمت JPG، PNG یا WebP انتخاب کن');
          continue;
        }
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
          photos.add(bytes);
        } catch (_) {
          if (mounted) notice('این فایل عکس معتبر نیست');
        }
      }
      return photos;
    } catch (_) {
      if (mounted) notice('عکس انتخاب نشد؛ دوباره امتحان کن.');
      return [];
    }
  }

  Widget photoChooser(
          List<Uint8List> photos, VoidCallback add, ValueChanged<int> remove) =>
      SizedBox(
          height: 88,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (photos.length < 6)
              Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton(
                      onPressed: add,
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: line),
                          padding: const EdgeInsets.all(10)),
                      child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 23),
                            SizedBox(height: 5),
                            Text('افزودن عکس', style: TextStyle(fontSize: 11))
                          ]))),
            ...photos.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(e.value,
                          width: 84, height: 84, fit: BoxFit.cover)),
                  Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                          tooltip: 'حذف عکس ${fa(e.key + 1)}',
                          onPressed: () => remove(e.key),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size(25, 25),
                              padding: EdgeInsets.zero),
                          icon: const Icon(Icons.close, size: 15)))
                ])))
          ]));
  List<Widget> settingsView() => [
        section('نمایش اطلاعات'),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('نمایش سابقه فعالیت',
                style: TextStyle(fontSize: 13)),
            value: showExperience,
            onChanged: (v) => update(() => showExperience = v)),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title:
                const Text('نمایش زمان آمادگی', style: TextStyle(fontSize: 13)),
            value: showAvailability,
            onChanged: (v) => update(() => showAvailability = v)),
        small(
            'محدوده فعالیت در پروفایل نمایش داده می‌شود؛ آدرس دقیق سکونت در پروفایل عمومی نداریم.'),
        section('اطلاعات حساب'),
        pair('نام', myName.isEmpty ? 'تکمیل نشده' : myName),
        pair('تم', 'روشن')
      ];

  void openRequest(String id) {
    selectedRequest = id;
    bidSortUnit = null;
    selectedAd = adFor(id);
    go('applicants');
  }

  List<Widget> requestBoard() => workBoard();
  List<Widget> requestDetails() => workRequestDetails();
  Future<void> sendOffer(Ad ad) => proposeWork(ad);
  Future<void> createVisit() async {
    final c = currentWorkChat;
    if (c != null)
      await requestWorkVisit(workStore.need(c.requestId), bidderId: c.bidderId);
  }

  List<Widget> legacyRequestBoard() => [
        miniTabs(['درخواست‌های من', 'پیشنهادهای من', 'قرارها'], requestTab,
            (i) => update(() => requestTab = i)),
        const SizedBox(height: 8),
        if (requestTab == 0)
          ...workRequests.values
              .where((job) => !deletedAds.contains(job.adId))
              .map((job) {
            final ad = adFor(job.adId);
            return InkWell(
                onTap: () => openRequest(job.adId),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: line))),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(ad.title,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            small(ad.area),
                            const SizedBox(height: 6),
                            Wrap(spacing: 7, children: [
                              label(job.status, color: red),
                              label('${fa(job.bids.length)} پیشنهاد')
                            ])
                          ])),
                      const SizedBox(width: 10),
                      adPhoto(ad, width: 70, height: 70)
                    ])));
          }),
        if (requestTab == 1)
          ...myOffers.map((offer) => panel([
                Text(adFor(offer.adId).title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                small('برای ${adFor(offer.adId).owner}'),
                pair('پیشنهاد شما', offer.price),
                pair('زمان', offer.time),
                label(offer.status, color: red),
                button(
                    'گفت‌وگو',
                    () => openWorkThread(
                        adFor(offer.adId).owner, adFor(offer.adId)),
                    outlined: true)
              ])),
        if (requestTab == 1 && myOffers.isEmpty)
          emptyState(
              'هنوز پیشنهادی نفرستادی', 'از آگهی‌های نیاز، کار مناسب پیدا کن.',
              action: 'دیدن آگهی‌ها', onTap: () => selectTab(0)),
        if (requestTab == 2) ...visits.map(visitCard),
        if (requestTab == 2 && visits.isEmpty)
          emptyState(
              'قراری ثبت نشده', 'در گفت‌وگوی مربوط به کار، قرار بازدید ثبت کن.')
      ];
  void openWorkThread(String peer, Ad ad) {
    final p =
        profileRepository.profiles.where((p) => p.name == peer).firstOrNull;
    final n = workStore.needs[ad.id];
    if (p == null || n == null) {
      notice('درخواست مرتبط پیدا نشد.');
      return;
    }
    openCanonicalChat('${n.id}::${n.ownerId == actorId ? p.id : actorId}');
  }

  List<Widget> legacyRequestDetails() {
    final job = workRequests[selectedRequest]!;
    final ad = adFor(job.adId);
    return [
      Text(ad.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      small(ad.area),
      const SizedBox(height: 8),
      skillCards(adSkills(ad)),
      pair('وضعیت', job.status),
      DropdownButtonFormField<String>(
          key: ValueKey('status-${job.status}'),
          initialValue: job.status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'تغییر وضعیت'),
          items: ['دریافت پیشنهاد', 'در حال هماهنگی', 'توافق‌شده', 'بسته‌شده']
              .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 12))))
              .toList(),
          onChanged: (v) => update(() => job.status = v!)),
      section('پیشنهادهای دریافتی'),
      small('قیمت، زمان حضور، شرایط و سابقه را کنار هم مقایسه کن.'),
      ...job.bids.map((bid) => panel([
            Row(children: [
              Expanded(
                  child: Text(bid.peer,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              if (job.selectedBid == bid.id) label('انتخاب‌شده', color: red)
            ]),
            small(
                '${ratingText(peerAd(bid.peer))} ★ · مشاهده سابقه در پروفایل'),
            pair('قیمت پیشنهادی', bid.price),
            pair('زمان حضور / تحویل', bid.time),
            small(bid.terms),
            Row(children: [
              Expanded(
                  child: button('پروفایل', () => openProfile(peerAd(bid.peer)),
                      outlined: true)),
              const SizedBox(width: 7),
              Expanded(
                  child: button('پیام', () => openWorkThread(bid.peer, ad)))
            ]),
            TextButton(
                onPressed: () => update(() {
                      job.selectedBid = bid.id;
                      job.status = 'در حال هماهنگی';
                    }),
                child: Text(job.selectedBid == bid.id
                    ? 'برای هماهنگی انتخاب شده'
                    : 'انتخاب برای هماهنگی'))
          ])),
      if (job.bids.isEmpty)
        emptyState(
            'هنوز پیشنهادی نرسیده', 'درخواست در آگهی‌ها قابل مشاهده است.'),
      TextButton(
          onPressed: () => openAd(ad), child: const Text('مشاهده آگهی درخواست'))
    ];
  }

  Future<void> legacySendOffer(Ad ad) async {
    if (!canAct) {
      await ensureAccess(() => sendOffer(ad));
      return;
    }
    final price = TextEditingController(),
        time = TextEditingController(),
        terms = TextEditingController();
    final key = GlobalKey<FormState>();
    final result = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('پیشنهاد همکاری',
                    style: TextStyle(fontSize: 16)),
                content: SizedBox(
                    width: 340,
                    child: SingleChildScrollView(
                        child: Form(
                            key: key,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  formField('قیمت و مبنای محاسبه', price,
                                      required: true),
                                  formField('زمان حضور یا تحویل', time,
                                      required: true),
                                  formField('شرایط پیشنهاد', terms, lines: 2)
                                ])))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 40)),
                      onPressed: () {
                        if (key.currentState!.validate())
                          Navigator.pop(dialog, true);
                      },
                      child: const Text('ارسال پیشنهاد'))
                ]));
    if (result == true && mounted) {
      final offer = BidOffer('offer-${DateTime.now().microsecondsSinceEpoch}',
          ad.id, myName, price.text.trim(), time.text.trim(), terms.text.trim(),
          mine: true);
      update(() => myOffers.add(offer));
      openWorkThread(ad.owner, ad);
      update(() => sent.add(
          'پیشنهاد همکاری\n${offer.price}\n${offer.time}\n${offer.terms}'));
    }
    // Controllers outlive the closing dialog animation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    price.dispose();
    time.dispose();
    terms.dispose();
  }

  Future<void> legacyCreateVisit() async {
    if (!canAct) {
      await ensureAccess(createVisit);
      return;
    }
    final t = threads[threadIndex],
        time = TextEditingController(),
        place = TextEditingController();
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                backgroundColor: Colors.white,
                title: const Text('ثبت قرار بازدید / حضور',
                    style: TextStyle(fontSize: 16)),
                content: SizedBox(
                    width: 340,
                    child: SingleChildScrollView(
                        child: Form(
                            key: key,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  small('با ${t.peer} · ${t.subject}'),
                                  const SizedBox(height: 10),
                                  formField('روز و ساعت', time, required: true),
                                  formField('محل قرار', place, required: true)
                                ])))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 40)),
                      onPressed: () {
                        if (key.currentState!.validate())
                          Navigator.pop(dialog, true);
                      },
                      child: const Text('ثبت قرار'))
                ]));
    if (accepted == true && mounted)
      update(() {
        visits.add(VisitRecord('visit-${DateTime.now().microsecondsSinceEpoch}',
            t.id, t.peer, t.subject, time.text.trim(), place.text.trim(),
            adId: threadAdIds[t.id]));
        t.appointment = '${time.text.trim()} · ${place.text.trim()}';
      });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    time.dispose();
    place.dispose();
  }

  Widget visitCard(VisitRecord visit) => panel([
        Text(visit.peer, style: const TextStyle(fontWeight: FontWeight.bold)),
        small(visit.subject),
        pair('زمان', visit.time),
        pair('محل', visit.location),
        label(visit.status, color: red),
        Row(children: [
          Expanded(
              child: button('گفت‌وگو', () {
            threadIndex = threads.indexWhere((t) => t.id == visit.threadId);
            openThread();
          }, outlined: true)),
          const SizedBox(width: 7),
          Expanded(child: button('ثبت نتیجه', () => recordVisit(visit)))
        ])
      ]);
  Future<void> recordReviewForPeer(String peer) async {
    if (!canAct) {
      await ensureAccess(() => recordReviewForPeer(peer));
      return;
    }
    if (peer == myName) {
      notice('ثبت نظر برای خودت ممکن نیست.');
      return;
    }
    final canonical = workStore.visits.values.where((v) =>
        v.status == 'accepted' &&
        !v.at.isAfter(DateTime.now()) &&
        (v.bidderId == actorId ||
            workStore.need(v.requestId).ownerId == actorId) &&
        workName(v.bidderId == actorId
                ? workStore.need(v.requestId).ownerId
                : v.bidderId) ==
            peer);
    final eligible = canonical
        .map((v) => VisitRecord(
            v.id,
            '${v.requestId}::${v.bidderId}',
            peer,
            workStore.need(v.requestId).title,
            shortDate(v.at),
            workStore.need(v.requestId).city,
            adId: v.requestId))
        .toList();
    if (eligible.isEmpty) {
      notice(
          'برای ثبت تجربه، ابتدا قرار یا همکاری مربوط را در گفت‌وگو ثبت کن.');
      return;
    }
    if (eligible.length == 1) {
      await recordVisit(eligible.first);
      return;
    }
    final chosen = await showDialog<VisitRecord>(
        context: context,
        builder: (dialog) => SimpleDialog(
            title:
                const Text('انتخاب قرار مربوط', style: TextStyle(fontSize: 16)),
            children: eligible
                .map((v) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(dialog, v),
                    child: Text('${v.subject} · ${v.time}')))
                .toList()));
    if (chosen != null && mounted) await recordVisit(chosen);
  }

  Future<void> recordVisit(VisitRecord visit) async {
    final previous =
        workReviews.where((r) => r.contextId == visit.id).firstOrNull;
    var outcome = visit.status == 'منتظر مراجعه'
            ? 'طبق قرار مراجعه کرد'
            : visit.status,
        punctuality = previous?.punctuality ?? 5,
        quality = previous?.quality ?? 0;
    final notes = TextEditingController(text: previous?.text ?? '');
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, setDialog) => AlertDialog(
                    backgroundColor: Colors.white,
                    title: const Text('نتیجه این قرار',
                        style: TextStyle(fontSize: 16)),
                    content: SizedBox(
                        width: 340,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              small('${visit.peer} · ${visit.time}'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                  initialValue: outcome,
                                  isExpanded: true,
                                  items: [
                                    'طبق قرار مراجعه کرد',
                                    'با تأخیر مراجعه کرد',
                                    'طبق قرار نیامد',
                                    'قرار با هماهنگی لغو شد'
                                  ]
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s,
                                              style: const TextStyle(
                                                  fontSize: 11))))
                                      .toList(),
                                  onChanged: (v) => setDialog(() {
                                        outcome = v!;
                                        punctuality = outcome ==
                                                'طبق قرار نیامد'
                                            ? 1
                                            : outcome == 'با تأخیر مراجعه کرد'
                                                ? 3
                                                : 5;
                                      })),
                              section('خوش‌قولی'),
                              ratingStars(punctuality,
                                  (v) => setDialog(() => punctuality = v)),
                              if (outcome.contains('مراجعه کرد')) ...[
                                section('کیفیت همکاری · اگر کار انجام شد'),
                                ratingStars(quality,
                                    (v) => setDialog(() => quality = v))
                              ],
                              const SizedBox(height: 10),
                              formField('توضیح تجربه', notes, lines: 3),
                              small(
                                  'این بازخورد به همین قرار متصل است؛ در این نسخه تجربه در همین نشست ثبت می‌شود.')
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('انصراف')),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(80, 40)),
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('ذخیره نتیجه'))
                    ])));
    if (accepted == true && mounted)
      update(() {
        visit.status = outcome;
        workReviews.removeWhere((r) => r.contextId == visit.id);
        if (outcome != 'قرار با هماهنگی لغو شد')
          workReviews.add(WorkReview(
              visit.peer,
              visit.id,
              visit.subject,
              outcome,
              notes.text.trim(),
              punctuality,
              outcome.contains('مراجعه کرد') && quality > 0 ? quality : null,
              subjectProfileId: profileRepository.profiles
                  .where((p) => p.name == visit.peer)
                  .firstOrNull
                  ?.id,
              authorProfileId: myProfile.id));
      });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    notes.dispose();
  }

  Widget ratingStars(int value, ValueChanged<int> changed) => Row(
      children: List.generate(
          5,
          (i) => Expanded(
              child: IconButton(
                  tooltip: '${fa(i + 1)} ستاره',
                  onPressed: () => changed(i + 1),
                  icon: Icon(i < value ? Icons.star : Icons.star_border,
                      color: red, size: 23)))));
  Widget reviewCard(WorkReview r) => panel([
        Text(r.outcome,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        small('قرار ثبت‌شده · ${r.subject}'),
        small(
            'خوش‌قولی ${fa(r.punctuality)} از ۵${r.quality == null ? '' : ' · کیفیت ${fa(r.quality!)} از ۵'}'),
        if (r.text.isNotEmpty)
          Text(r.text, style: const TextStyle(fontSize: 12)),
        if (r.reply.isNotEmpty) small('پاسخ ${r.peer}: ${r.reply}')
      ]);

  List<Widget> adDetailView() {
    final ad = selectedAd;
    if (deletedAds.contains(ad.id))
      return [
        emptyState('آگهی حذف شده', 'این آگهی دیگر برای همکاری در دسترس نیست.')
      ];
    return [
      AdGallery(ad: ad),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () => reportTarget('ad:${ad.id}'),
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('گزارش آگهی'))),
      section(ad.title),
      Row(children: [
        label(
            isClosed(ad)
                ? 'بسته‌شده'
                : ad.need
                    ? 'نیاز دارد'
                    : 'ارائه می‌کند',
            color: red),
        const SizedBox(width: 8),
        Expanded(child: small(ad.area))
      ]),
      if (ad.kind != AdKind.need && ad.kind != AdKind.offer)
        small(ad.kind.label),
      small('${marketCategory(ad.category).label} · ${ad.time}'),
      const SizedBox(height: 10),
      skillCards(adSkills(ad)),
      pair('قیمت / شرایط', priceText(ad)),
      if (ad.people > 0) pair('تعداد نیرو', fa(ad.people)),
      if (ad.quantity.isNotEmpty) pair('مقدار', ad.quantity),
      if (ad.startsAt.isNotEmpty) pair('زمان', ad.startsAt),
      if (ad.duration.isNotEmpty) pair('مدت', ad.duration),
      section('توضیحات'),
      Text(
          ad.description.isNotEmpty
              ? ad.description
              : 'زمان، هزینه و شرایط ${ad.title} را پیش از شروع هماهنگ کنید.',
          style: const TextStyle(fontSize: 13, height: 1.7)),
      profileBadges(ad),
      const SizedBox(height: 6),
      menuRow(ad.owner, '${ratingText(ad)} ★ · پروفایل و سابقه همکاری',
          Icons.person_outline, () => openProfile(ad)),
      if (ad.category == 'مصالح' &&
          !ad.need &&
          adSkills(ad).contains('کاشی و سرامیک'))
        menuRow('نمونه متریال و مشخصات', 'گالری تأمین‌کننده',
            Icons.grid_view_outlined, () => go('supplier')),
      Row(children: [
        Expanded(
            child: button(
                ownAd(ad)
                    ? 'ویرایش آگهی'
                    : ad.need
                        ? 'ارسال پیشنهاد'
                        : 'پیام',
                () => ownAd(ad)
                    ? editAd(ad)
                    : isClosed(ad)
                        ? notice('این آگهی بسته شده است')
                        : ad.need
                            ? sendOffer(ad)
                            : openThread(ad: ad))),
        IconButton(
            tooltip: saved ? 'حذف از نشان‌ها' : 'نشان کردن آگهی',
            onPressed: () => toggleAdBookmark(ad),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border,
                color: red)),
        IconButton(
            tooltip: likedIds.contains(ad.id) ? 'حذف پسند' : 'پسندیدن آگهی',
            onPressed: () => update(() => likedIds.contains(ad.id)
                ? likedIds.remove(ad.id)
                : likedIds.add(ad.id)),
            icon: Icon(
                likedIds.contains(ad.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: red,
                size: 20)),
        IconButton(
            tooltip: 'ارسال آگهی برای دوست',
            onPressed: () => shareItem(ad),
            icon: const Icon(Icons.share_outlined, size: 20))
      ]),
      ...adLocationSection(ad),
      if (ownAd(ad) && ad.need && !isClosed(ad))
        button('دیدن پیشنهادهای این درخواست', () => openRequest(ad.id),
            outlined: true)
    ];
  }
}
