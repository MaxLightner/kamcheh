part of 'main.dart';

extension StructureUi on _AppShellState {
  Ad serviceAd(ServiceListing s) {
    final p = profileRepository.profile(s.ownerId);
    return Ad(s.id, s.title, s.category, false, s.city, s.district, s.image,
        s.price, p?.name ?? 'پروفایل در دسترس نیست',
        description: s.details,
        listingKind: AdKind.offer,
        skills: s.skills,
        providerProfile: p == null ? null : visibleBadge(profileCard(p)),
        serviceArea: p?.coverage,
        pricing: s.amount == null ? null : MarketPrice(s.amount!, s.unit));
  }

  List<Ad> get serviceFeedAds => workStore.services.values
      .where((s) => !s.archived)
      .map(serviceAd)
      .toList()
      .reversed
      .toList();

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
      image(s.image, h: 190, w: double.infinity),
      section(s.title),
      label('معرفی خدمات'),
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
      if (s.ownerId == actorId) button('ویرایش آگهی', () => editService(s)),
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
                  small('${s.city} · ${s.district}'),
                  Row(children: [
                    TextButton(
                        onPressed: () => openAd(serviceAd(s)),
                        child: const Text('پیش‌نمایش')),
                    TextButton(
                        onPressed: () => editService(s),
                        child: const Text('ویرایش'))
                  ]),
                ])),
        if (!workStore.services.values
            .any((s) => s.ownerId == actorId && !s.archived))
          emptyState('آگهی نداری', 'خدمات و توانایی خودت را معرفی کن.'),
        button('ثبت آگهی جدید', () => editService()),
      ];

  Future<void> editService([ServiceListing? listing]) async {
    if (!canAct) {
      await ensureAccess(() => editService(listing));
      return;
    }
    final actor = actorId;
    final result = await Navigator.of(context).push<ServiceListing>(
        MaterialPageRoute(
            builder: (_) =>
                _ServiceEditor(owner: myProfile, listing: listing)));
    if (!mounted || result == null || actor != actorId) return;
    if (workAction(() => workStore.saveService(result, actor)))
      notice('آگهی خدمات ذخیره شد.');
  }
}

class _ServiceEditor extends StatefulWidget {
  const _ServiceEditor({required this.owner, this.listing});
  final UserProfile owner;
  final ServiceListing? listing;
  @override
  State<_ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<_ServiceEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.listing?.title);
  late final details = TextEditingController(text: widget.listing?.details);
  late String category = widget.listing?.category ?? 'خدمات';
  late String city = widget.listing?.city ?? widget.owner.city ?? 'مشهد';
  @override
  void dispose() {
    title.dispose();
    details.dispose();
    super.dispose();
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
                      const Text('خدماتی که ارائه می‌دهی را معرفی کن.'),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: title,
                          decoration:
                              const InputDecoration(labelText: 'عنوان آگهی'),
                          validator: (s) => s == null || s.trim().isEmpty
                              ? 'عنوان را بنویس.'
                              : null),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: details,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'شرح خدمات'),
                          validator: (s) => s == null || s.trim().isEmpty
                              ? 'شرح خدمات را بنویس.'
                              : null),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration:
                              const InputDecoration(labelText: 'زمینه خدمات'),
                          items: marketCategories
                              .map((c) => DropdownMenuItem(
                                  value: c.id, child: Text(c.label)))
                              .toList(),
                          onChanged: (v) => setState(() => category = v!)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue: city,
                          decoration: const InputDecoration(labelText: 'شهر'),
                          items: {...demoCities.map((c) => c.name), city}
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => city = v!)),
                      const SizedBox(height: 18),
                      FilledButton(
                          onPressed: () {
                            if (!form.currentState!.validate()) return;
                            final old = widget.listing;
                            Navigator.pop(
                                context,
                                ServiceListing(
                                    id: old?.id ?? workId('service'),
                                    ownerId: widget.owner.id,
                                    title: title.text.trim(),
                                    details: details.text.trim(),
                                    city: city,
                                    category: category,
                                    district: old?.district ?? '',
                                    image: old?.image ??
                                        marketCategory(category).asset,
                                    price: old?.price ?? 'با توافق',
                                    amount: old?.amount,
                                    unit: old?.unit ?? PriceUnit.project,
                                    skills:
                                        old != null && old.category == category
                                            ? old.skills
                                            : widget.owner.skills
                                                .where(marketCategory(category)
                                                    .skills
                                                    .contains)
                                                .toList()));
                          },
                          child: const Text('ذخیره آگهی')),
                    ]))),
      );
}
