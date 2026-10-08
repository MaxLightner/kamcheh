part of 'main.dart';

extension HomeUi on _AppShellState {
  String priceText(Ad ad) => ad.pricing == null
      ? ad.price
      : '${money(ad.pricing!.amount)} / ${ad.pricing!.unit.label}';

  IconData categoryIcon(String id) => switch (id) {
        'نیرو' => Icons.engineering_outlined,
        'خدمات' => Icons.handyman_outlined,
        'مصالح' => Icons.layers_outlined,
        'ابزار' => Icons.construction_outlined,
        'اجاره' => Icons.local_shipping_outlined,
        'مهندسی' => Icons.architecture_outlined,
        'انشعابات' => Icons.electrical_services_outlined,
        _ => Icons.apartment_outlined,
      };

  Widget profileBadges(Ad ad, {bool compact = false}) {
    final profile = visibleBadge(ad);
    Widget badge(String text, IconData icon, Color color, String tooltip) =>
        Tooltip(
            message: tooltip,
            child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 5 : 7, vertical: compact ? 3 : 5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: compact ? 12 : 14, color: color),
                  if (text.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(text,
                        style:
                            TextStyle(fontSize: compact ? 9 : 11, color: color))
                  ]
                ])));
    return Wrap(spacing: 4, runSpacing: 4, children: [
      badge(profile.specialty, categoryIcon(ad.category), ink,
          'گروه تخصص: ${profile.specialty}'),
      badge(
          profile.activity.label,
          profile.activity == ActivityType.crew
              ? Icons.groups_outlined
              : profile.activity == ActivityType.individual
                  ? Icons.person_outline
                  : Icons.storefront_outlined,
          muted,
          'نوع فعالیت: ${profile.activity.label}'),
      badge(
          compact
              ? ''
              : profile.verified
                  ? 'شماره تأییدشده · دمو'
                  : 'شماره تأییدنشده',
          profile.verified ? Icons.verified_outlined : Icons.shield_outlined,
          profile.verified ? const Color(0xFF287F65) : muted,
          profile.verified
              ? 'تأیید شماره نمایشی است و به معنی تأیید هویت یا تخصص نیست'
              : 'شماره این حساب هنوز تأیید نشده است'),
    ]);
  }

  Future<void> chooseFilters() async {
    var draft = feedFilter;
    final minInput =
            TextEditingController(text: draft.minPrice?.toString() ?? ''),
        maxInput =
            TextEditingController(text: draft.maxPrice?.toString() ?? '');
    String? error;
    final result = await showModalBottomSheet<FeedFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
              final cat = draft.category == 'همه'
                  ? null
                  : marketCategory(draft.category);
              final kinds = [AdKind.offer];
              final units = cat?.priceUnits ?? PriceUnit.values;
              final activityOptions =
                  ['مصالح', 'ابزار'].contains(draft.category)
                      ? [
                          ActivityType.shop,
                          ActivityType.wholesale,
                          ActivityType.producer
                        ]
                      : draft.category == 'همه'
                          ? ActivityType.values
                          : [
                              ActivityType.individual,
                              ActivityType.crew,
                              if (draft.category == 'اجاره') ActivityType.shop
                            ];
              final parsedDraft = draft.copyWith(
                  minPrice: parsePriceInput(minInput.text),
                  maxPrice: parsePriceInput(maxInput.text));
              final count = parsedDraft
                  .apply(allAds,
                      area: selectedArea, query: search, isClosed: isClosed)
                  .length;
              void changeCategory(String id) => setSheet(() {
                    draft = draft.selectCategory(id);
                    minInput.clear();
                    maxInput.clear();
                    error = null;
                    if (draft.activity != null &&
                        !(['مصالح', 'ابزار'].contains(id)
                                ? [
                                    ActivityType.shop,
                                    ActivityType.wholesale,
                                    ActivityType.producer
                                  ]
                                : id == 'همه'
                                    ? ActivityType.values
                                    : [
                                        ActivityType.individual,
                                        ActivityType.crew,
                                        if (id == 'اجاره') ActivityType.shop
                                      ])
                            .contains(draft.activity))
                      draft = draft.copyWith(activity: null);
                  });
              return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(sheet).bottom),
                  child: SizedBox(
                      height: (MediaQuery.sizeOf(sheet).height -
                              MediaQuery.viewInsetsOf(sheet).bottom -
                              30)
                          .clamp(180.0, MediaQuery.sizeOf(sheet).height * .88)
                          .toDouble(),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                                child: Row(children: [
                                  const Expanded(
                                      child: Text('فیلتر آگهی‌ها',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold))),
                                  TextButton(
                                      onPressed: () => setSheet(() {
                                            draft = const FeedFilter();
                                            minInput.clear();
                                            maxInput.clear();
                                            error = null;
                                          }),
                                      child: const Text('پاک کردن')),
                                  IconButton(
                                      onPressed: () => Navigator.pop(sheet),
                                      icon: const Icon(Icons.close, size: 20))
                                ])),
                            Expanded(
                                child: SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          section('دسته‌بندی'),
                                          Wrap(
                                              spacing: 5,
                                              runSpacing: 2,
                                              children: [
                                                ChoiceChip(
                                                    label: const Text('همه',
                                                        style: TextStyle(
                                                            fontSize: 11)),
                                                    selected:
                                                        draft.category == 'همه',
                                                    showCheckmark: false,
                                                    onSelected: (_) =>
                                                        changeCategory('همه')),
                                                ...marketCategories.map((c) =>
                                                    ChoiceChip(
                                                        key: ValueKey(
                                                            'filter-category-${c.id}'),
                                                        label: Text(
                                                            c.shortLabel,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        11)),
                                                        selected:
                                                            draft.category ==
                                                                c.id,
                                                        showCheckmark: false,
                                                        onSelected: (_) =>
                                                            changeCategory(
                                                                c.id))),
                                              ]),
                                          section('نوع آگهی'),
                                          Wrap(spacing: 5, children: [
                                            ChoiceChip(
                                                label: const Text('همه',
                                                    style: TextStyle(
                                                        fontSize: 11)),
                                                selected: draft.kind == null,
                                                showCheckmark: false,
                                                onSelected: (_) => setSheet(
                                                    () => draft = draft
                                                        .copyWith(kind: null))),
                                            ...kinds.map((kind) => ChoiceChip(
                                                key: ValueKey(
                                                    'filter-kind-${kind.name}'),
                                                label: Text(kind.label,
                                                    style: const TextStyle(
                                                        fontSize: 11)),
                                                selected: draft.kind == kind,
                                                showCheckmark: false,
                                                onSelected: (_) => setSheet(
                                                    () => draft =
                                                        draft.copyWith(
                                                            kind: kind)))),
                                          ]),
                                          if (cat != null) ...[
                                            section('مهارت، کالا یا تجهیز'),
                                            Wrap(
                                                spacing: 5,
                                                runSpacing: 2,
                                                children: cat.skills
                                                    .map((skill) => FilterChip(
                                                        label: Text(skill,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        11)),
                                                        selected: draft.skill ==
                                                            skill,
                                                        onSelected: (checked) =>
                                                            setSheet(() => draft =
                                                                draft.copyWith(
                                                                    skill: checked
                                                                        ? skill
                                                                        : ''))))
                                                    .toList())
                                          ],
                                          section('نوع فعالیت'),
                                          Wrap(spacing: 5, children: [
                                            ChoiceChip(
                                                label: const Text('همه',
                                                    style: TextStyle(
                                                        fontSize: 11)),
                                                selected:
                                                    draft.activity == null,
                                                showCheckmark: false,
                                                onSelected: (_) => setSheet(
                                                    () => draft =
                                                        draft.copyWith(
                                                            activity: null))),
                                            ...activityOptions
                                                .map((type) => ChoiceChip(
                                                    label: Text(
                                                        type.label,
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 11)),
                                                    selected:
                                                        draft.activity == type,
                                                    showCheckmark: false,
                                                    onSelected: (_) => setSheet(
                                                        () => draft =
                                                            draft.copyWith(
                                                                activity:
                                                                    type)))),
                                          ]),
                                          CheckboxListTile(
                                              key: const ValueKey(
                                                  'filter-verified'),
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text(
                                                  'فقط هویت‌های تأییدشده در دمو',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                              value: draft.verifiedOnly,
                                              onChanged: (v) => setSheet(() =>
                                                  draft = draft.copyWith(
                                                      verifiedOnly: v!))),
                                          section('قیمت'),
                                          DropdownButtonFormField<PriceUnit>(
                                              key: ValueKey(
                                                  'unit-${draft.category}-${draft.unit}'),
                                              initialValue: draft.unit,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                  labelText: 'واحد قیمت'),
                                              hint: const Text('همه واحدها',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                              items: [
                                                const DropdownMenuItem<
                                                        PriceUnit>(
                                                    value: null,
                                                    child: Text('همه واحدها',
                                                        style: TextStyle(
                                                            fontSize: 12))),
                                                ...units.map((unit) =>
                                                    DropdownMenuItem(
                                                        value: unit,
                                                        child: Text(unit.label,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12))))
                                              ],
                                              onChanged: (unit) => setSheet(() {
                                                    draft = draft.copyWith(
                                                        unit: unit,
                                                        sort: FeedSort.newest);
                                                    error = null;
                                                    if (unit == null) {
                                                      minInput.clear();
                                                      maxInput.clear();
                                                      draft = draft.copyWith(
                                                          minPrice: null,
                                                          maxPrice: null);
                                                    }
                                                  })),
                                          if (draft.unit != null) ...[
                                            const SizedBox(height: 12),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                      key: const ValueKey(
                                                          'filter-min-price'),
                                                      controller: minInput,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'از · تومان'),
                                                      onChanged: (_) =>
                                                          setSheet(() =>
                                                              error = null))),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: TextField(
                                                      key: const ValueKey(
                                                          'filter-max-price'),
                                                      controller: maxInput,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      style: const TextStyle(
                                                          fontSize: 12),
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'تا · تومان'),
                                                      onChanged: (_) =>
                                                          setSheet(() =>
                                                              error = null)))
                                            ]),
                                            const SizedBox(height: 12),
                                            DropdownButtonFormField<FeedSort>(
                                                key: ValueKey(
                                                    'sort-${draft.sort}'),
                                                initialValue: draft.sort,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: 'مرتب‌سازی'),
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: FeedSort.newest,
                                                      child: Text('جدیدترین',
                                                          style: TextStyle(
                                                              fontSize: 12))),
                                                  DropdownMenuItem(
                                                      value: FeedSort.cheapest,
                                                      child: Text('کمترین قیمت',
                                                          style: TextStyle(
                                                              fontSize: 12))),
                                                  DropdownMenuItem(
                                                      value: FeedSort
                                                          .mostExpensive,
                                                      child: Text(
                                                          'بیشترین قیمت',
                                                          style: TextStyle(
                                                              fontSize: 12)))
                                                ],
                                                onChanged: (v) => setSheet(() =>
                                                    draft = draft.copyWith(
                                                        sort: v!))),
                                            const SizedBox(height: 8),
                                            small(
                                                'مقایسه فقط بین آگهی‌های دارای قیمت ${draft.unit!.label} انجام می‌شود.'),
                                          ] else ...[
                                            const SizedBox(height: 8),
                                            small(
                                                'برای بازه قیمت و مرتب‌سازی مبلغ، واحد قیمت را انتخاب کن.')
                                          ],
                                          if (error != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: Text(error!,
                                                    style: const TextStyle(
                                                        color: red,
                                                        fontSize: 12))),
                                          const SizedBox(height: 8),
                                        ]))),
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: FilledButton(
                                    onPressed: () {
                                      final min =
                                              parsePriceInput(minInput.text),
                                          max = parsePriceInput(maxInput.text);
                                      if ((minInput.text.trim().isNotEmpty &&
                                              min == null) ||
                                          (maxInput.text.trim().isNotEmpty &&
                                              max == null)) {
                                        setSheet(() =>
                                            error = 'قیمت را با عدد وارد کن');
                                        return;
                                      }
                                      if (min != null &&
                                          max != null &&
                                          min > max) {
                                        setSheet(() => error =
                                            'قیمت «از» باید کمتر یا برابر «تا» باشد');
                                        return;
                                      }
                                      Navigator.pop(
                                          sheet,
                                          draft.copyWith(
                                              minPrice: min, maxPrice: max));
                                    },
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('نمایش نتیجه'),
                                          Text('${fa(count)} آگهی',
                                              style:
                                                  const TextStyle(fontSize: 12))
                                        ]))),
                          ])));
            }));
    if (result != null && mounted) update(() => feedFilter = result);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    minInput.dispose();
    maxInput.dispose();
  }

  Widget categoryGrid() => Column(children: [
        for (var row = 0; row < 2; row++)
          Row(children: [
            for (final cat in marketCategories.skip(row * 4).take(4))
              Expanded(
                  child: InkWell(
                      key: ValueKey('home-category-${cat.id}'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => update(
                          () => feedFilter = feedFilter.selectCategory(cat.id)),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Column(children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF9F3F3),
                                    borderRadius: BorderRadius.circular(11)),
                                child: Icon(categoryIcon(cat.id),
                                    size: 22, color: ink)),
                            const SizedBox(height: 4),
                            SizedBox(
                                height: 30,
                                child: Text(cat.shortLabel,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    style: const TextStyle(
                                        fontSize: 10.5, height: 1.3))),
                          ]))))
          ])
      ]);

  List<Widget> networkHome() => focusedHome();

  Widget networkAdRow(Ad ad) => InkWell(
      key: ValueKey('ad-row-${ad.id}'),
      onTap: () => openAd(ad),
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(ad.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.4)),
                  const SizedBox(height: 5),
                  Text(priceText(ad),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 3),
                  Text('${ad.time} · ${ad.area}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: muted)),
                  const SizedBox(height: 4),
                  Text(isClosed(ad) ? 'بسته‌شده' : ad.kind.label,
                      style: const TextStyle(fontSize: 10, color: red)),
                  const SizedBox(height: 4),
                  if (!ad.need)
                    profileBadges(ad, compact: true)
                  else
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      if (workStore.needs[ad.id]?.crew ?? false)
                        label('اکیپ موردنیاز'),
                      ...ad.skills.map((s) => label(s)),
                    ]),
                ])),
            const SizedBox(width: 8),
            Stack(children: [
              adPhoto(ad, width: 88, height: 88),
              Positioned(
                  top: 2,
                  left: 2,
                  child: SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                          tooltip: savedIds.contains(ad.id)
                              ? 'حذف نشان آگهی'
                              : 'نشان کردن بدون باز کردن',
                          onPressed: () => toggleAdBookmark(ad),
                          style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: .94),
                              padding: EdgeInsets.zero),
                          icon: Icon(
                              savedIds.contains(ad.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 17,
                              color: savedIds.contains(ad.id) ? red : muted)))),
              if (ad.photos.length > 1)
                Positioned(
                    bottom: 3,
                    left: 3,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        color: Colors.black54,
                        child: Text('${fa(ad.photos.length)} عکس',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)))),
            ])
          ])));
}
