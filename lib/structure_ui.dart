part of 'main.dart';

extension StructureUi on _AppShellState {
  Ad serviceAd(ServiceListing s) {
    final p = profileRepository.profile(s.ownerId);
    return Ad(s.id, s.title, s.category, false, s.city, s.district, s.image,
        s.price, p?.name ?? 'پروفایل در دسترس نیست',
        description: s.details,
        photos: s.photos,
        galleryAssets: s.galleryAssets,
        listingKind: AdKind.offer,
        skills: s.skills,
        providerProfile: p == null ? null : visibleBadge(profileCard(p)),
        serviceArea: p?.coverage,
        pricing: s.amount == null ? null : MarketPrice(s.amount!, s.unit));
  }

  List<Ad> get serviceFeedAds => workStore.services.values
      .where((s) => !s.archived && s.enabled)
      .map(serviceAd)
      .toList()
    ..sort((a, b) => workStore
        .service(b.id)
        .updatedAt
        .compareTo(workStore.service(a.id).updatedAt));

  List<Widget> requestFeed() {
    final requests = requestFilter.apply(workStore.needs.values,
        area: selectedArea, query: requestQuery);
    final skills = requestFilter.category == 'همه'
        ? marketCategories.expand((c) => c.skills).toSet().toList()
        : marketCategory(requestFilter.category).skills;
    return [
      Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: chooseRegion,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(region,
                    maxLines: 1, overflow: TextOverflow.ellipsis))),
        Expanded(
            flex: 2,
            child: TextButton(
                onPressed: () => go('activities'),
                child: const Text('درخواست‌ها و پیشنهادهای من',
                    maxLines: 1, overflow: TextOverflow.ellipsis)))
      ]),
      small(
          'کسی به نیرو یا خدمات نیاز دارد؛ پیشنهاد بده یا بازدید درخواست کن.'),
      const SizedBox(height: 8),
      TextField(
          key: const ValueKey('request-search'),
          controller: requestInput,
          onChanged: (v) => update(() => requestQuery = v),
          decoration: const InputDecoration(
              hintText: 'جست‌وجو در درخواست‌ها',
              prefixIcon: Icon(Icons.search),
              isDense: true)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: [
        for (final id in ['همه', ...marketCategories.map((c) => c.id)])
          ChoiceChip(
              label: Text(id == 'همه' ? id : marketCategory(id).shortLabel),
              selected: requestFilter.category == id,
              onSelected: (_) => update(() => requestFilter = RequestFilter(
                  category: id, crewOnly: requestFilter.crewOnly))),
        FilterChip(
            label: const Text('اکیپ موردنیاز'),
            selected: requestFilter.crewOnly,
            onSelected: (v) => update(() => requestFilter = RequestFilter(
                category: requestFilter.category,
                skill: requestFilter.skill,
                crewOnly: v))),
      ]),
      DropdownButtonFormField<String>(
          key: ValueKey(
              'request-skill-${requestFilter.category}-${requestFilter.skill}'),
          initialValue: requestFilter.skill,
          decoration:
              const InputDecoration(labelText: 'تخصص موردنیاز', isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('همه تخصص‌ها')),
            ...skills.map((s) => DropdownMenuItem(value: s, child: Text(s)))
          ],
          onChanged: (s) => update(() => requestFilter = RequestFilter(
              category: requestFilter.category,
              skill: s,
              crewOnly: requestFilter.crewOnly))),
      const SizedBox(height: 10),
      button('ثبت درخواست جدید', () => startWorkRequest(), icon: Icons.add),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: small('${fa(requests.length)} درخواست · داده نمونه')),
      ...requests.map((n) => networkAdRow(workAd(n))),
      if (requests.isEmpty)
        emptyState('درخواستی پیدا نشد', 'محدوده یا تخصص موردنیاز را تغییر بده.',
            action: 'پاک کردن فیلترها',
            onTap: () => update(() {
                  requestFilter = const RequestFilter();
                  selectedArea = const AreaFilter();
                  requestQuery = '';
                  requestInput.clear();
                })),
    ];
  }

  List<Widget> serviceDetails() {
    final s = workStore.services[selectedAd.id];
    if (s == null)
      return [emptyState('آگهی پیدا نشد', 'این آگهی در دسترس نیست.')];
    final p = profileRepository.profile(s.ownerId);
    return [
      ListingGallery(
          key: ValueKey('service-gallery-${s.id}'),
          photos: s.photos,
          assets: s.galleryAssets.isEmpty && s.photos.isEmpty
              ? [s.image]
              : s.galleryAssets),
      section(s.title),
      label('معرفی خدمات'),
      if (s.archived || !s.enabled) label(serviceStatus(s)),
      const SizedBox(height: 8),
      small('${s.city} · ${s.district}'),
      section('شرح خدمات'),
      Text(s.details),
      const SizedBox(height: 12),
      skillCards(s.skills),
      pair('قیمت اعلام‌شده', priceText(serviceAd(s))),
      if (p != null) ...[
        section('ارائه‌دهنده'),
        profileBadges(profileCard(p)),
        button('دیدن پروفایل ${p.name}', () => viewPerson(p), outlined: true),
      ],
      Row(children: [
        Expanded(
            child: button(savedIds.contains(s.id) ? 'حذف نشان' : 'نشان کردن',
                () => toggleAdBookmark(serviceAd(s)),
                outlined: true)),
        IconButton(
            tooltip: 'اشتراک آگهی',
            onPressed: () => shareItem(serviceAd(s)),
            icon: const Icon(Icons.share_outlined))
      ]),
      if (s.ownerId == actorId) ...[
        ...serviceOwnerActions(s),
        section('درخواست‌های ارتباط این آگهی'),
        ...contactsFor(s.id).map(serviceContactCard),
        if (contactsFor(s.id).isEmpty)
          small('درخواست ارتباطی دریافت نکرده‌ای.'),
      ] else ...[
        if (s.enabled && !s.archived)
          Row(children: [
            Expanded(
                child: button(
                    'درخواست پیش‌فاکتور',
                    () =>
                        requestServiceConnection(s, ServiceContactKind.quote))),
            const SizedBox(width: 8),
            Expanded(
                child: button(
                    'همکاری و ارتباط', () => chooseServiceConnection(s),
                    outlined: true))
          ]),
        ...contactsFor(s.id).map(serviceContactCard),
      ],
      section('محدوده آگهی'),
      small(
          '${s.city}${s.district.isEmpty ? '' : ' · ${s.district}'} · نمایش تقریبی محدوده'),
      LocationMap(
          city: cityByName(s.city),
          districts: s.district.isEmpty ? {} : s.district.split('، ').toSet(),
          height: 160,
          districtPreview: true),
      TextButton.icon(
          onPressed: () => reportTarget('ad:${s.id}'),
          icon: const Icon(Icons.flag_outlined, size: 17),
          label: const Text('گزارش آگهی')),
    ];
  }

  List<Widget> ownServices() => [
        small(
            'آگهی برای معرفی خدمات توست؛ برای پیدا کردن نیرو از درخواست‌ها استفاده کن.'),
        const SizedBox(height: 10),
        ...workStore.services.values
            .where((s) => s.ownerId == actorId && !s.archived)
            .map((s) => panel([
                  Text(s.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  small('${s.city} · ${s.district} · ${serviceStatus(s)}'),
                  Row(children: [
                    TextButton(
                        onPressed: () => openAd(serviceAd(s)),
                        child: const Text('پیش‌نمایش')),
                    TextButton(
                        onPressed: () => openAd(serviceAd(s)),
                        child: Text(
                            '${fa(contactsFor(s.id).where((c) => c.status == 'pending').length)} درخواست ارتباط'))
                  ]),
                  ...serviceOwnerActions(s),
                ])),
        if (!workStore.services.values
            .any((s) => s.ownerId == actorId && !s.archived))
          emptyState('آگهی نداری', 'خدمات و توانایی خودت را معرفی کن.'),
        button('ثبت آگهی جدید', () => editService()),
        if (workStore.services.values
            .any((s) => s.ownerId == actorId && s.archived))
          ExpansionTile(
              title: const Text('آگهی‌های حذف‌شده',
                  style: TextStyle(fontSize: 13)),
              children: workStore.services.values
                  .where((s) => s.ownerId == actorId && s.archived)
                  .map((s) => panel([Text(s.title), ...serviceOwnerActions(s)]))
                  .toList()),
      ];

  Future<void> editService([ServiceListing? listing]) async {
    if (!canAct) {
      await ensureAccess(() => editService(listing));
      return;
    }
    final actor = actorId;
    final result = await Navigator.of(context).push<ServiceListing>(
        MaterialPageRoute(
            builder: (_) => _ServiceEditor(
                owner: myProfile,
                listing: listing,
                choosePhotos: selectPhotos)));
    if (!mounted || result == null || actor != actorId) return;
    if (workAction(() => workStore.saveService(result, actor)))
      notice('آگهی خدمات ذخیره شد.');
  }
}

class _ServiceEditor extends StatefulWidget {
  const _ServiceEditor(
      {required this.owner, this.listing, required this.choosePhotos});
  final Future<List<Uint8List>> Function(int) choosePhotos;
  final UserProfile owner;
  final ServiceListing? listing;
  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.listing?.title);
  late final details = TextEditingController(text: widget.listing?.details);
  late final amount =
      TextEditingController(text: widget.listing?.amount?.toString());
  late final priceNote =
      TextEditingController(text: widget.listing?.price ?? 'با توافق');
  late String category = widget.listing?.category ?? 'خدمات';
  late PriceUnit unit = widget.listing?.unit ?? PriceUnit.project;
  late AreaFilter area = AreaFilter(
      city: widget.listing?.city ?? widget.owner.city ?? 'مشهد',
      province: cityByName(widget.listing?.city ?? widget.owner.city ?? 'مشهد')
          .province,
      districts: widget.listing?.district.isNotEmpty == true
          ? widget.listing!.district.split('، ').toSet()
          : {});
  late final photos = List<Uint8List>.from(widget.listing?.photos ?? []);
  late final assets = List<String>.from(widget.listing?.galleryAssets ?? []);
  late final skills = Set<String>.from(widget.listing?.skills ??
      widget.owner.skills.where(marketCategory(category).skills.contains));
  bool picking = false;
  @override
  void dispose() {
    title.dispose();
    details.dispose();
    amount.dispose();
    priceNote.dispose();
    super.dispose();
  }

  Future<void> chooseArea() async {
    final next = await showModalBottomSheet<AreaFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (_) => AreaPicker(initial: area, requireCity: true));
    if (mounted && next != null) setState(() => area = next);
  }

  Future<void> addPhotos() async {
    if (picking || photos.length + assets.length >= 6) return;
    setState(() => picking = true);
    final next = await widget.choosePhotos(6 - photos.length - assets.length);
    if (mounted)
      setState(() {
        picking = false;
        photos.addAll(next);
      });
  }

  ServiceListing draft() => ServiceListing(
      id: widget.listing?.id ?? workId('service'),
      ownerId: widget.owner.id,
      title: title.text.trim(),
      details: details.text.trim(),
      city: area.city!,
      district: area.districts.join('، '),
      category: category,
      image: widget.listing?.image ?? marketCategory(category).asset,
      price: priceNote.text.trim().isEmpty ? 'با توافق' : priceNote.text.trim(),
      amount: amount.text.trim().isEmpty ? null : parsePriceInput(amount.text),
      unit: unit,
      skills: skills.toList(),
      photos: List.from(photos),
      galleryAssets: List.from(assets),
      createdAt: widget.listing?.createdAt);
  Future<void> preview() async {
    if (!form.currentState!.validate() || area.city == null) return;
    final value = draft();
    final save = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('پیش‌نمایش آگهی')),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListingGallery(
                          photos: value.photos,
                          assets: value.galleryAssets.isEmpty &&
                                  value.photos.isEmpty
                              ? [value.image]
                              : value.galleryAssets),
                      const SizedBox(height: 12),
                      Text(value.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 8),
                      Text(area.label, style: const TextStyle(color: muted)),
                      const SizedBox(height: 12),
                      Text(value.details),
                      const SizedBox(height: 12),
                      Text(value.amount == null
                          ? value.price
                          : '${money(value.amount!)} / ${value.unit.label}'),
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('تأیید و انتشار آگهی')),
                    ])))));
    if (mounted && save == true) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.listing == null
                ? 'ثبت آگهی خدمات'
                : 'ویرایش آگهی خدمات')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
                key: form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('خدماتی که ارائه می‌دهی را معرفی کن.',
                          style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: title,
                          decoration:
                              const InputDecoration(labelText: 'عنوان آگهی'),
                          validator: (s) => s?.trim().isNotEmpty == true
                              ? null
                              : 'عنوان را بنویس.'),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: details,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'شرح خدمات'),
                          validator: (s) => s?.trim().isNotEmpty == true
                              ? null
                              : 'شرح خدمات را بنویس.'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration:
                              const InputDecoration(labelText: 'زمینه خدمات'),
                          items: marketCategories
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.label)))
                              .toList(),
                          onChanged: (v) => setState(() {
                                category = v!;
                                skills.clear();
                                if (!marketCategory(category)
                                    .priceUnits
                                    .contains(unit))
                                  unit =
                                      marketCategory(category).priceUnits.first;
                              })),
                      const SizedBox(height: 8),
                      Text('تخصص‌های این آگهی',
                          style: Theme.of(context).textTheme.bodySmall),
                      Wrap(
                          spacing: 5,
                          children: marketCategory(category)
                              .skills
                              .map((skill) => FilterChip(
                                  label: Text(skill,
                                      style: const TextStyle(fontSize: 11)),
                                  selected: skills.contains(skill),
                                  onSelected: (v) => setState(() => v
                                      ? skills.add(skill)
                                      : skills.remove(skill))))
                              .toList()),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: chooseArea,
                          icon:
                              const Icon(Icons.location_on_outlined, size: 18),
                          label: Text(area.label)),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          initiallyExpanded: widget.listing?.amount != null,
                          title: const Text('قیمت (اختیاری)',
                              style: TextStyle(fontSize: 13)),
                          children: [
                            TextFormField(
                                controller: amount,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'مبلغ به تومان'),
                                validator: (s) =>
                                    s?.trim().isNotEmpty == true &&
                                            (parsePriceInput(s!) ?? 0) <= 0
                                        ? 'مبلغ مثبت و معتبر بنویس.'
                                        : null),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<PriceUnit>(
                                key: ValueKey('service-price-unit-$category'),
                                initialValue: unit,
                                decoration: const InputDecoration(
                                    labelText: 'واحد قیمت'),
                                items: {
                                  ...marketCategory(category).priceUnits,
                                  unit
                                }
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => unit = v!)),
                            const SizedBox(height: 10),
                            TextFormField(
                                controller: priceNote,
                                decoration: const InputDecoration(
                                    labelText: 'توضیح قیمت')),
                          ]),
                      const SizedBox(height: 10),
                      Text(
                          'عکس‌های آگهی (${fa(photos.length + assets.length)}/۶)',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (var i = 0; i < photos.length + assets.length; i++)
                          Stack(children: [
                            SizedBox(
                                width: 85,
                                height: 85,
                                child: profilePicture(i < photos.length
                                    ? ProfilePhoto.bytes(photos[i])
                                    : ProfilePhoto.asset(
                                        assets[i - photos.length]))),
                            Positioned(
                                left: 0,
                                top: 0,
                                child: IconButton(
                                    tooltip: 'حذف عکس آگهی ${i + 1}',
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.white),
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() {
                                          if (i < photos.length)
                                            photos.removeAt(i);
                                          else
                                            assets.removeAt(i - photos.length);
                                        }))),
                          ]),
                      ]),
                      if (photos.length + assets.length < 6)
                        TextButton.icon(
                            onPressed: picking ? null : addPhotos,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text(picking
                                ? 'در حال انتخاب…'
                                : 'افزودن عکس آگهی')),
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: preview,
                          child: const Text('پیش‌نمایش و ذخیره آگهی')),
                    ]))),
      );
}
