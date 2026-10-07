part of 'main.dart';

extension KamchehUi on _AppShellState {
  List<Widget> publicProfileView(UserProfile p) => [
        Row(children: [
          CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFF8EFEF),
              backgroundImage: p.avatar == null ? null : MemoryImage(p.avatar!),
              child: p.avatar == null
                  ? const Icon(Icons.person_outline, color: red)
                  : null),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                small(p.coverage?.label ?? p.city ?? 'محدوده مشخص نشده')
              ]))
        ]),
        const SizedBox(height: 12),
        profileBadges(profileCard(p)),
        const SizedBox(height: 8),
        label(p.available ? 'آماده کار' : 'فعلاً در دسترس نیست',
            color: p.available ? const Color(0xFF287F65) : muted),
        section('مهارت‌ها و زمینه فعالیت'),
        skillCards(p.skills),
        section('معرفی'),
        small(p.bio.isEmpty ? 'معرفی ثبت نشده است.' : p.bio),
        if (p.experience.isNotEmpty) pair('سابقه اعلام‌شده', p.experience),
        ...memberSection(p),
        section('نمونه‌کارها'),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.photos
                .map((photo) => InkWell(
                    onTap: () => openProfilePhoto(photo),
                    child: SizedBox(
                        width: 120, height: 100, child: profilePicture(photo))))
                .toList()),
        if (p.photos.isEmpty) small('نمونه‌کاری ثبت نشده است.'),
        section('بازخورد'),
        small('هنوز نظری ثبت نشده است.'),
        Row(children: [
          Expanded(
              child: button(
                  savedPeople.containsKey(p.name) ? 'حذف نشان' : 'نشان کردن',
                  () => togglePersonBookmark(profileCard(p)),
                  outlined: true)),
          IconButton(
              tooltip: 'اشتراک پروفایل',
              onPressed: () => shareItem(profileCard(p), profile: true),
              icon: const Icon(Icons.share_outlined))
        ]),
        small('گفت‌وگو از مسیر پیشنهاد یا بازدید مرتبط آغاز می‌شود.'),
      ];
  bool activeListing(Ad ad) =>
      ['نیرو', 'خدمات', 'مهندسی'].contains(ad.category) &&
      !ad.title.contains('نظارت') &&
      ad.need;
  DemoProfileRepository createDemoProfiles() {
    final repo = DemoProfileRepository()
      ..save(accountSpaces[samplePhone]!.profile);
    repo.acceptRules('profile-sample');
    final seen = repo.profiles.map((p) => p.name).toSet();
    var index = 0;
    for (final ad in [...demoAds, ...marketDemoAds]) {
      if (!['نیرو', 'خدمات', 'مهندسی'].contains(ad.category) ||
          ad.need ||
          ad.title.contains('نظارت') ||
          !seen.add(ad.owner)) continue;
      repo.save(UserProfile(
          id: 'demo-person-${++index}',
          name: ad.owner,
          specialty: marketCategory(ad.category).label,
          city: ad.city,
          coverage: ad.serviceArea ??
              AreaFilter(province: cityByName(ad.city).province, city: ad.city),
          bio: ad.description.isEmpty ? ad.title : ad.description,
          complete: true,
          experience: '۵ سال · اعلام‌شده',
          phoneVerified: true,
          available: index % 4 != 0,
          skills: adSkills(ad),
          photos: [
            ProfilePhoto.asset(ad.image),
            const ProfilePhoto.asset('concrete'),
            const ProfilePhoto.asset('scaffold')
          ]));
    }
    for (final entry in [
      'طراح معماری الهیه',
      'گروه طراحی نما',
      'طراحی داخلی آبان'
    ].asMap().entries) {
      repo.save(UserProfile(
          id: 'demo-design-${entry.key}',
          name: entry.value,
          specialty: 'طراحی ساختمان',
          city: 'مشهد',
          complete: true,
          phoneVerified: true,
          activity:
              entry.key == 1 ? ActivityType.company : ActivityType.individual,
          coverage: const AreaFilter(
              province: 'خراسان رضوی', city: 'مشهد', surroundings: true),
          bio: 'طراحی معماری، نما و فضای داخلی؛ هماهنگی بر اساس نیاز پروژه.',
          skills: ['طراحی معماری', 'طراحی داخلی'],
          photos: [const ProfilePhoto.asset('concrete')]));
    }
    final people =
        repo.profiles.where((p) => p.id != 'profile-sample').toList();
    if (people.length > 2) {
      repo.invite('profile-sample', people[0].id);
      repo.accept(repo.links.last.id, people[0].id);
      repo.invite('profile-sample', people[1].id);
    }
    return repo;
  }

  UserProfile? findProfile(Ad ad) =>
      profileRepository
          .profile(ad.id.startsWith('profile:') ? ad.id.substring(8) : '') ??
      profileRepository.profiles.where((p) => p.name == ad.owner).firstOrNull;
  ProviderProfile visibleBadge(Ad ad) {
    final p = findProfile(ad);
    if (p == null) return profileFor(ad);
    return ProviderProfile(
        p.specialty,
        profileRepository.members(p.id).isNotEmpty
            ? ActivityType.crew
            : p.activity,
        identity: p.phoneVerified
            ? IdentityStatus.demoVerified
            : IdentityStatus.unverified);
  }

  Ad profileCard(UserProfile p) {
    final category =
        marketCategories.where((c) => c.label == p.specialty).firstOrNull ??
            marketCategory('خدمات');
    return Ad(
        'profile:${p.id}',
        p.skills.isEmpty ? p.specialty : p.skills.join(' · '),
        category.id,
        false,
        p.city ?? 'مشهد',
        '',
        p.photos.where((f) => f.asset != null).firstOrNull?.asset ?? 'worker',
        '',
        p.name,
        description: p.bio,
        skills: p.skills.toList(),
        serviceArea: p.coverage,
        providerProfile: p.badge);
  }

  void viewPerson(UserProfile p) {
    if (signedIn && p.id == myProfile.id) {
      go('ownProfile');
      return;
    }
    selectedAd = profileCard(p);
    go('pro');
  }

  List<Widget> rulesView() => [
        small('نسخه $rulesVersion'),
        const Text(rulesText, style: TextStyle(fontSize: 13, height: 1.9))
      ];

  List<Widget> focusedHome() {
    final ads = feedFilter.apply(allAds,
        area: selectedArea, query: search, isClosed: isClosed);
    return [
      Row(children: [
        Expanded(
            child: TextButton.icon(
                onPressed: chooseRegion,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(region,
                    maxLines: 1, overflow: TextOverflow.ellipsis))),
        if (!showProfileFeed)
          OutlinedButton.icon(
              key: const ValueKey('feed-filter'),
              onPressed: chooseFilters,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('فیلتر'))
      ]),
      miniTabs(
          ['درخواست‌ها', 'افراد و اکیپ‌ها'],
          showProfileFeed ? 1 : 0,
          (i) => update(() {
                showProfileFeed = i == 1;
                search = '';
                searchInput.clear();
              })),
      const SizedBox(height: 8),
      TextField(
          key: const ValueKey('feed-search'),
          controller: searchInput,
          onChanged: (v) => update(() => search = v),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
              hintText: showProfileFeed
                  ? 'نام یا تخصص فرد و اکیپ'
                  : 'جست‌وجو در درخواست‌ها',
              prefixIcon: const Icon(Icons.search),
              isDense: true)),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 4, children: [
        ChoiceChip(
            label: const Text('همه'),
            selected: feedFilter.category == 'همه',
            onSelected: (_) =>
                update(() => feedFilter = feedFilter.selectCategory('همه'))),
        ...marketCategories.map((c) => ChoiceChip(
            key: ValueKey('home-category-${c.id}'),
            avatar: Icon(categoryIcon(c.id), size: 17),
            label: Text(c.shortLabel, style: const TextStyle(fontSize: 11)),
            selected: feedFilter.category == c.id,
            onSelected: (_) =>
                update(() => feedFilter = feedFilter.selectCategory(c.id))))
      ]),
      if (showProfileFeed)
        ...profileDirectory(embedded: true)
      else ...[
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: small('${fa(ads.length)} درخواست · داده نمونه')),
        ...ads.map(networkAdRow),
        if (ads.isEmpty)
          emptyState('درخواستی پیدا نشد',
              'عبارت جست‌وجو یا محدوده و فیلترها را تغییر بده.',
              action: 'پاک کردن فیلترها',
              onTap: () => update(() {
                    feedFilter = const FeedFilter();
                    selectedArea = const AreaFilter();
                    search = '';
                    searchInput.clear();
                  }))
      ],
    ];
  }

  List<Widget> profileDirectory({bool embedded = false}) {
    final query = normalizeMarketText(embedded ? search : profileQuery);
    final people = profileRepository.profiles.where((p) {
      if (!p.complete) return false;
      final ad = profileCard(p);
      if (!selectedArea.matches(ad)) return false;
      if (embedded &&
          feedFilter.category != 'همه' &&
          ad.category != feedFilter.category) return false;
      if (onlyAvailable && !p.available) return false;
      final crew = profileRepository.members(p.id).isNotEmpty;
      if (profileType == 'اکیپ' && !crew ||
          profileType == 'فرد' && (crew || p.activity == ActivityType.company))
        return false;
      return query.isEmpty ||
          normalizeMarketText('${p.name} ${p.specialty} ${p.skills.join(' ')}')
              .contains(query);
    }).toList();
    return [
      if (!embedded)
        TextField(
            onChanged: (v) => update(() => profileQuery = v),
            decoration: const InputDecoration(
                hintText: 'جست‌وجوی نام یا تخصص',
                prefixIcon: Icon(Icons.search))),
      Wrap(spacing: 6, children: [
        for (final type in ['همه', 'فرد', 'اکیپ'])
          ChoiceChip(
              label: Text(type),
              selected: profileType == type,
              onSelected: (_) => update(() => profileType = type)),
        FilterChip(
            label: const Text('آماده کار'),
            selected: onlyAvailable,
            onSelected: (v) => update(() => onlyAvailable = v)),
      ]),
      small('${fa(people.length)} پروفایل · نمونه'),
      ...people.map((p) => InkWell(
          onTap: () => viewPerson(p),
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line))),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: const Color(0xFFF8EFEF),
                    backgroundImage:
                        p.avatar == null ? null : MemoryImage(p.avatar!),
                    child: p.avatar == null
                        ? const Icon(Icons.person_outline, color: red)
                        : null),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 5),
                      profileBadges(profileCard(p), compact: true),
                      const SizedBox(height: 5),
                      small(p.skills.join(' · ')),
                      small(
                          '${p.coverage?.label ?? p.city ?? 'محدوده تعیین نشده'} · ${p.available ? 'آماده کار' : 'فعلاً در دسترس نیست'}')
                    ])),
                const Icon(Icons.chevron_left, size: 18, color: muted),
              ])))),
      if (people.isEmpty)
        emptyState('پروفایلی پیدا نشد', 'محدوده یا عبارت و فیلتر را تغییر بده.')
    ];
  }

  List<Widget> memberSection(UserProfile p) => [
        section('اعضای اکیپ'),
        ...profileRepository.members(p.id).map((l) {
          final m = profileRepository.profile(l.memberId)!;
          return menuRow(m.name, m.skills.join(' · '), Icons.person_outline,
              () => viewPerson(m));
        }),
        if (profileRepository.members(p.id).isEmpty)
          small('عضو تأییدشده‌ای ثبت نشده است.'),
      ];

  List<Widget> teamView() {
    final own = profileRepository.links.where((l) =>
        l.ownerId == myProfile.id &&
        [TeamLinkStatus.active, TeamLinkStatus.invited].contains(l.status));
    final incoming = profileRepository.invitations(myProfile.id);
    return [
      small(
          'اعضا به پروفایل خودشان لینک می‌شوند. افزودن نیاز به تأیید دارد؛ حذف فقط اعلام می‌شود.'),
      button('افزودن عضو', chooseTeamMember, icon: Icons.person_add_alt_1),
      section('اعضای من و دعوت‌های ارسالی'),
      ...own.map((l) {
        final member = profileRepository.profile(l.memberId)!;
        return panel([
          menuRow(member.name, member.skills.join(' · '), Icons.person_outline,
              () => viewPerson(member)),
          Row(children: [
            Expanded(
                child: small(l.status == TeamLinkStatus.active
                    ? 'عضو تأییدشده'
                    : 'منتظر تأیید عضو')),
            TextButton(
                onPressed: () =>
                    update(() => profileRepository.remove(l.id, myProfile.id)),
                child: const Text('حذف لینک'))
          ]),
        ]);
      }),
      if (own.isEmpty) small('هنوز عضوی اضافه نکرده‌ای.'),
      section('دعوت‌های دریافتی'),
      ...incoming.map((l) {
        final owner = profileRepository.profile(l.ownerId)!;
        return panel([
          menuRow(owner.name, 'درخواست افزودن به اکیپ', Icons.groups_outlined,
              () => viewPerson(owner)),
          Row(children: [
            Expanded(
                child: button('پذیرش', () {
              final error = profileRepository.accept(l.id, myProfile.id);
              update(() {});
              if (error != null) notice(error);
            })),
            TextButton(
                onPressed: () =>
                    update(() => profileRepository.decline(l.id, myProfile.id)),
                child: const Text('نمی‌پذیرم'))
          ]),
        ]);
      }),
      if (incoming.isEmpty) small('دعوت تازه‌ای نداری.'),
      section('عضویت‌های من'),
      ...profileRepository.links
          .where((l) =>
              l.memberId == myProfile.id && l.status == TeamLinkStatus.active)
          .map((l) {
        final p = profileRepository.profile(l.ownerId)!;
        return menuRow(
            p.name, 'عضو اکیپ', Icons.groups_outlined, () => viewPerson(p));
      }),
      section('اعلان‌های عضویت'),
      ...profileRepository.notices
          .where((n) => n.profileId == myProfile.id)
          .toList()
          .reversed
          .take(12)
          .map((n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: small(n.text))),
      TextButton.icon(
          onPressed: switchDemoAccount,
          icon: const Icon(Icons.switch_account_outlined),
          label: const Text('تغییر حساب نمونه برای امتحان تأیید')),
    ];
  }

  Future<void> chooseTeamMember() async {
    final query = TextEditingController();
    String term = '';
    final chosen = await showModalBottomSheet<UserProfile>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 460),
        backgroundColor: Colors.white,
        builder: (sheet) => StatefulBuilder(
            builder: (sheet, setSheet) => SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .75,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Row(children: [
                        const Expanded(child: Text('انتخاب عضو')),
                        IconButton(
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close))
                      ]),
                      TextField(
                          controller: query,
                          onChanged: (v) =>
                              setSheet(() => term = normalizeMarketText(v)),
                          decoration: const InputDecoration(
                              hintText: 'نام یا تخصص',
                              prefixIcon: Icon(Icons.search))),
                      Expanded(
                          child: ListView(
                              children: profileRepository.profiles
                                  .where((p) =>
                                      p.complete &&
                                      p.id != myProfile.id &&
                                      normalizeMarketText(
                                              '${p.name} ${p.skills.join(' ')}')
                                          .contains(term))
                                  .map((p) => ListTile(
                                      title: Text(p.name,
                                          style: const TextStyle(fontSize: 13)),
                                      subtitle: Text(p.skills.join(' · '),
                                          style: const TextStyle(fontSize: 11)),
                                      trailing: const Icon(
                                          Icons.person_add_alt_1,
                                          size: 18),
                                      onTap: () => Navigator.pop(sheet, p)))
                                  .toList())),
                    ])))));
    if (chosen != null && mounted) {
      final error = profileRepository.invite(myProfile.id, chosen.id);
      update(() {});
      notice(error ?? 'دعوت ارسال شد؛ عضو باید در حساب خودش تأیید کند.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    query.dispose();
  }

  Future<void> switchDemoAccount() async {
    final chosen = await showDialog<UserProfile>(
        context: context,
        builder: (dialog) =>
            SimpleDialog(title: const Text('حساب‌های نمونه'), children: [
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text('صرفاً برای آزمایش دعوت و تأیید در همین دمو.',
                      style: TextStyle(fontSize: 11))),
              ...profileRepository.profiles.where((p) => p.complete).map((p) =>
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialog, p),
                      child: Text(p.name))),
            ]));
    if (chosen == null || !mounted) return;
    update(() {
      final key =
          chosen.id == 'profile-sample' ? samplePhone : 'demo:${chosen.id}';
      activePhone = key;
      workspace = accountSpaces.putIfAbsent(
          key, () => AccountWorkspace()..profile = chosen);
      workspace.profile = chosen;
      profileRepository.acceptRules(chosen.id);
      clearAdComposer();
      history.clear();
      chat.clear();
      threadIndex = 0;
      contractIndex = 0;
      page = 'me';
      tab = 4;
    });
  }
}
