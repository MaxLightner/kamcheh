part of 'main.dart';

class AccountWorkspace {
  UserProfile profile = UserProfile();
  final createdAds = <Ad>[], adDrafts = <AdDraft>[];
  final deletedAds = <String>{},
      closedAds = <String>{},
      savedIds = <String>{},
      likedIds = <String>{};
  final savedPeople = <String, Ad>{};
  final workRequests = <String, WorkRequest>{};
  final myOffers = <BidOffer>[],
      visits = <VisitRecord>[],
      workReviews = <WorkReview>[];
  final threadAdIds = <String, String>{};
  final threads = <ChatThread>[];
  final drafts = <ContractDraft>[];
  final expenses = <Expense>[];
  AccountWorkspace();
  factory AccountWorkspace.sample() {
    final w = AccountWorkspace()..profile = UserProfile.sample();
    w.createdAds.addAll(initialOwnAds
        .where(
            (a) => a.need && ['نیرو', 'خدمات', 'مهندسی'].contains(a.category))
        .map((a) => a.copyWith(kind: AdKind.need)));
    w.workRequests.addAll(initialWorkRequests()
      ..removeWhere((id, r) => !w.createdAds.any((a) => a.id == id)));
    w.threads.addAll(sampleThreads());
    w.expenses.addAll([
      Expense('خرید شن', 'مصالح', 18000000, true),
      Expense('اجاره دوربین', 'تجهیزات', 3500000, true),
      Expense('دستمزد داربست', 'اجرا', 24500000, false)
    ]);
    w.drafts.add(ContractDraft('اجرای داربست', {
      'طرفین': 'مهدی احمدی · داربست رضایی',
      'موضوع و محل': 'نصب و اجاره داربست — مشهد، الهیه',
      'مبلغ و مدت': '۱۲٬۰۰۰٬۰۰۰ تومان · ۳۰ روز',
      'شرایط توافق': 'حمل، نصب و جمع‌آوری در مبلغ لحاظ شده است.'
    }));
    return w;
  }
}

extension ProfileUi on _AppShellState {
  void toggleAdBookmark(Ad ad) {
    if (!signedIn) {
      ensureAccess(() => toggleAdBookmark(ad), activity: false);
      return;
    }
    update(() => savedIds.contains(ad.id)
        ? savedIds.remove(ad.id)
        : savedIds.add(ad.id));
  }

  void togglePersonBookmark(Ad ad) {
    if (!signedIn) {
      ensureAccess(() => togglePersonBookmark(ad), activity: false);
      return;
    }
    update(() => savedPeople.containsKey(findProfile(ad)?.id ?? ad.owner)
        ? savedPeople.remove(findProfile(ad)?.id ?? ad.owner)
        : savedPeople[findProfile(ad)?.id ?? ad.owner] = ad);
  }

  Future<void> ensureAccess(VoidCallback action, {bool activity = true}) async {
    if (!signedIn) {
      final phone = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          constraints: const BoxConstraints(maxWidth: 460),
          builder: (_) => DemoLogin(
              acceptedPhones: accountSpaces.keys
                  .where((phone) => profileRepository.acceptances.any(
                      (a) => a.profileId == accountSpaces[phone]!.profile.id))
                  .toSet()));
      if (phone == null || !mounted) return;
      update(() {
        activePhone = phone;
        workspace = accountSpaces.putIfAbsent(
            phone,
            () => AccountWorkspace()
              ..profile = UserProfile(
                  id: 'profile-${DateTime.now().microsecondsSinceEpoch}'));
        workspace.profile.phoneVerified = true;
        profileRepository.save(workspace.profile);
        profileRepository.acceptRules(workspace.profile.id);
        clearAdComposer();
        threadIndex = 0;
        contractIndex = 0;
        selectedContractId = null;
      });
    }
    if (activity && !myProfile.complete) {
      if (!await editMyProfile(completing: true) || !mounted) return;
    }
    if (mounted) action();
  }

  void enterSampleAccount() {
    update(() {
      activePhone = samplePhone;
      workspace = accountSpaces[samplePhone]!;
      clearAdComposer();
      history.clear();
      threadIndex = 0;
      contractIndex = 0;
      selectedContractId = null;
      page = 'me';
      tab = 4;
    });
  }

  void logout() {
    update(() {
      activePhone = null;
      workspace = AccountWorkspace();
      clearAdComposer();
      chat.clear();
      inboxInput.clear();
      inboxQuery = '';
      history.clear();
      threadIndex = 0;
      contractIndex = 0;
      selectedContractId = null;
      messageTab = 0;
      bookmarkTab = 0;
      page = 'me';
      tab = 4;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<bool> editMyProfile({bool completing = false}) async {
    if (!signedIn) return false;
    final phone = activePhone;
    final result = await showModalBottomSheet<UserProfile>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (_) => ProfileEditor(
            profile: myProfile.copy(),
            completing: completing,
            selectPhotos: selectPhotos));
    if (result == null || !mounted || phone != activePhone) return false;
    update(() {
      workspace.profile = result;
      profileRepository.save(result);
      for (var i = 0; i < createdAds.length; i++)
        createdAds[i] = createdAds[i]
            .copyWith(owner: result.name, providerProfile: result.badge);
      if (ownAd(selectedAd)) selectedAd = adFor(selectedAd.id);
    });
    return true;
  }

  Widget myAvatar({double radius = 25}) => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF8EFEF),
      backgroundImage:
          myProfile.avatar == null ? null : MemoryImage(myProfile.avatar!),
      child: myProfile.avatar == null
          ? Icon(Icons.person_outline, color: red, size: radius)
          : null);
  Ad get myProfileAd => Ad('profile-self', myProfile.specialty, 'خدمات', false,
      myProfile.city ?? 'مشهد', '', 'concrete', '', myName,
      providerProfile: myProfile.badge);

  List<Widget> accountView() {
    if (!signedIn)
      return [
        section('به کمچه خوش آمدی'),
        small(
            'آگهی‌ها و پروفایل‌ها را ببین؛ برای ذخیره نشان‌ها و فعالیت، وارد حساب شو.'),
        button('ورود با شماره موبایل',
            () => ensureAccess(() => selectTab(4), activity: false),
            icon: Icons.login),
        TextButton(
            onPressed: enterSampleAccount,
            child: const Text('مشاهده حساب نمونه')),
        small('ورود این نسخه نمایشی است؛ پیامک واقعی ارسال نمی‌شود.'),
        menuRow('قوانین کمچه', '', Icons.policy_outlined, () => go('rules'))
      ];
    return [
      Row(children: [
        editableAvatar(),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(myName.isEmpty ? 'حساب من' : myName,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          small(myProfile.complete
              ? '${myProfile.specialty} · ${myProfile.city}'
              : 'برای شروع فعالیت، مشخصاتت را تکمیل کن.'),
        ]))
      ]),
      const SizedBox(height: 10),
      if (!myProfile.complete)
        button('تکمیل پروفایل', () => editMyProfile(completing: true)),
      menuRow('پروفایل عمومی من', 'معرفی، مهارت‌ها و نمونه‌کارها',
          Icons.person_outline, () => go('ownProfile')),
      menuRow(
          'بازدید پروفایل من',
          '${fa(profileRepository.profileViews[myProfile.id]?.length ?? 0)} بازدید ثبت‌شده',
          Icons.bar_chart_outlined,
          () => go('profileStats')),
      menuRow('حساب‌های نمونه', 'آزمایش دعوت و تأیید با دو حساب',
          Icons.switch_account_outlined, switchDemoAccount),
      menuRow('برآورد مصالح', 'بتن، ملات و کاشی', Icons.calculate_outlined,
          () => go('estimate')),
      menuRow('گزارش‌های من', 'گزارش‌های همین حساب', Icons.flag_outlined,
          () => go('reports')),
      menuRow('قراردادهای من', 'آرشیو خصوصی و قرارداد مستقل',
          Icons.description_outlined, () => go('contracts')),
      menuRow('تنظیمات', 'نمایش اطلاعات پروفایل', Icons.settings_outlined,
          () => go('settings')),
      menuRow('قوانین کمچه', 'قوانین نسخه آزمایشی', Icons.policy_outlined,
          () => go('rules')),
      menuRow('خروج از حساب', '', Icons.logout, logout),
    ];
  }

  List<Widget> ownProfileView() => [
        Row(children: [
          editableAvatar(radius: 30),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(myName.isEmpty ? 'پروفایل من' : myName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                small(
                    '${myProfile.specialty} · ${myProfile.city ?? 'شهر مشخص نشده'}'),
              ]))
        ]),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: () => editMyProfile(completing: !myProfile.complete),
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('ویرایش پروفایل'))),
        button('پیش‌نمایش پروفایل عمومی', () => go('profilePreview'),
            outlined: true, icon: Icons.visibility_outlined),
        profileBadges(myProfileAd),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('آماده کار هستم', style: TextStyle(fontSize: 13)),
            value: myProfile.available,
            onChanged: (v) => update(() {
                  myProfile.available = v;
                  profileRepository.save(myProfile);
                })),
        ...memberSection(myProfile),
        TextButton.icon(
            onPressed: () => go('team'),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('مدیریت اعضا و دعوت‌ها')),
        coverSettings(),
        section('مهارت‌ها و زمینه فعالیت'),
        skillCards(mySkills, editAction: editSkills),
        section('معرفی'),
        small(myBio.isEmpty ? 'معرفی کوتاهی از فعالیتت بنویس.' : myBio),
        TextButton(
            onPressed: () async {
              final value = await edit('معرفی من', myBio);
              if (value != null && mounted) update(() => myBio = value);
            },
            child: const Text('ویرایش معرفی')),
        if (showExperience && myProfile.experience.isNotEmpty)
          pair('سابقه فعالیت', myProfile.experience),
        if (showAvailability && myProfile.availability.isNotEmpty)
          pair('زمان آمادگی', myProfile.availability),
        if (myProfile.coverage != null)
          menuRow('محدوده فعالیت', myProfile.coverage!.label,
              Icons.map_outlined, () => editMyProfile()),
        Row(children: [
          Expanded(child: section('نمونه‌کارها')),
          TextButton(
              onPressed: () => showProfileGallery(),
              child: Text('دیدن همه (${fa(myProfile.photos.length)})'))
        ]),
        if (myProfile.photos.isEmpty)
          small('هنوز عکسی اضافه نکرده‌ای.')
        else
          Row(
              children: myProfile.photos
                  .take(3)
                  .map((photo) => Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: InkWell(
                              onTap: () => showProfileGallery(),
                              child: SizedBox(
                                  height: 95, child: profilePicture(photo))))))
                  .toList()),
        TextButton.icon(
            onPressed: addProfilePhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
            label: const Text('افزودن عکس')),
        section('بازخورد همکاری‌ها'),
        ...profileFeedback(myProfile),
        button('اشتراک پروفایل من',
            () => shareItem(profileCard(myProfile), profile: true),
            outlined: true, icon: Icons.share_outlined),
      ];

  Future<void> addProfilePhotos() async {
    final phone = activePhone;
    if (myProfile.photos.length >= 24) {
      notice('گالری تا ۲۴ عکس جا دارد');
      return;
    }
    final result = await selectPhotos(24 - myProfile.photos.length);
    if (mounted && activePhone == phone)
      update(() => myProfile.photos.addAll(result.map(ProfilePhoto.bytes)));
  }

  Future<void> showProfileGallery() async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (sheet) => StatefulBuilder(
            builder: (sheet, refresh) => SizedBox(
                height: MediaQuery.sizeOf(sheet).height * .85,
                child: Column(children: [
                  ListTile(
                      title: Text(
                          'نمونه‌کارها · ${fa(myProfile.photos.length)} عکس'),
                      trailing: IconButton(
                          tooltip: 'بستن گالری',
                          onPressed: () => Navigator.pop(sheet),
                          icon: const Icon(Icons.close))),
                  Expanded(
                      child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: myProfile.photos.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8),
                          itemBuilder: (_, i) => Stack(children: [
                                Positioned.fill(
                                    child: InkWell(
                                        onTap: () => openProfilePhoto(
                                            myProfile.photos[i]),
                                        child: profilePicture(
                                            myProfile.photos[i]))),
                                Positioned(
                                    top: 3,
                                    left: 3,
                                    child: IconButton(
                                        tooltip: 'حذف عکس پروفایل ${fa(i + 1)}',
                                        style: IconButton.styleFrom(
                                            backgroundColor: Colors.white),
                                        icon: const Icon(Icons.delete_outline,
                                            color: red, size: 19),
                                        onPressed: () {
                                          update(() =>
                                              myProfile.photos.removeAt(i));
                                          refresh(() {});
                                        })),
                              ]))),
                  Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton.icon(
                          onPressed: () async {
                            await addProfilePhotos();
                            if (sheet.mounted) refresh(() {});
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('افزودن عکس'))),
                ]))));
  }

  Future<void> openProfilePhoto(ProfilePhoto photo) => showDialog<void>(
      context: context,
      builder: (dialog) => Dialog.fullscreen(
              child: SafeArea(
                  child: Column(children: [
            Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                    tooltip: 'بستن عکس پروفایل',
                    onPressed: () => Navigator.pop(dialog),
                    icon: const Icon(Icons.close))),
            Expanded(
                child: InteractiveViewer(
                    child: SizedBox.expand(
                        child: profilePicture(photo, fit: BoxFit.contain)))),
          ]))));
}

Widget profilePicture(ProfilePhoto photo,
        {BoxFit fit = BoxFit.cover}) =>
    ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: photo.bytes == null
            ? Image.asset('assets/images/${photo.asset}.jpg', fit: fit)
            : Image.memory(photo.bytes!,
                fit: fit,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined))));

class DemoLogin extends StatefulWidget {
  const DemoLogin({super.key, this.acceptedPhones = const {}});
  final Set<String> acceptedPhones;
  @override
  State<DemoLogin> createState() => _DemoLoginState();
}

class _DemoLoginState extends State<DemoLogin> {
  final phone = TextEditingController(), code = TextEditingController();
  final form = GlobalKey<FormState>();
  bool sent = false, rulesAccepted = false;
  String? rulesError;
  String? sentPhone;
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
          child: Form(
              key: form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(sent ? 'کد تأیید' : 'ورود به کمچه',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold))),
                      IconButton(
                          tooltip: 'بستن ورود',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close))
                    ]),
                    Text(
                        sent
                            ? 'کد تأیید برای ${fa(sentPhone!)}'
                            : 'با شماره موبایل وارد شو. برای شروع فعالیت، پروفایلت را تکمیل می‌کنی.',
                        style: const TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 12),
                    if (!sent)
                      TextFormField(
                          key: const ValueKey('login-phone'),
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                              labelText: 'شماره موبایل',
                              hintText: '09xxxxxxxxx'),
                          validator: (v) => validMobile(v ?? '')
                              ? null
                              : 'شماره موبایل ۱۱ رقمی با ۰۹ وارد کن'),
                    if (sent)
                      TextFormField(
                          key: const ValueKey('login-code'),
                          controller: code,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration:
                              const InputDecoration(labelText: 'کد شش‌رقمی'),
                          validator: (v) =>
                              normalizeMarketText(v ?? '') == '123456'
                                  ? null
                                  : 'کد نمایشی ۱۲۳۴۵۶ است'),
                    const SizedBox(height: 12),
                    const Text('دمو: پیامک ارسال نمی‌شود؛ کد ورود ۱۲۳۴۵۶ است.',
                        style: TextStyle(fontSize: 11, color: muted)),
                    const SizedBox(height: 12),
                    if (sent && !widget.acceptedPhones.contains(sentPhone)) ...[
                      CheckboxListTile(
                          key: const ValueKey('accept-rules'),
                          contentPadding: EdgeInsets.zero,
                          value: rulesAccepted,
                          onChanged: (v) => setState(() {
                                rulesAccepted = v ?? false;
                                rulesError = null;
                              }),
                          title: const Text(
                              'قوانین نسخه آزمایشی را خواندم و می‌پذیرم',
                              style: TextStyle(fontSize: 12))),
                      TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                      title: const Text('قوانین کمچه'),
                                      content: const SingleChildScrollView(
                                          child: Text(rulesText,
                                              style: TextStyle(
                                                  fontSize: 12, height: 1.8))),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(c),
                                            child: const Text('بستن'))
                                      ])),
                          child: const Text('خواندن قوانین')),
                      if (rulesError != null)
                        Text(rulesError!,
                            style: const TextStyle(color: red, fontSize: 12)),
                    ],
                    FilledButton(
                        onPressed: () {
                          if (!form.currentState!.validate()) return;
                          if (!sent)
                            setState(() {
                              sentPhone = normalizePhone(phone.text);
                              sent = true;
                            });
                          else {
                            if (!widget.acceptedPhones.contains(sentPhone) &&
                                !rulesAccepted) {
                              setState(() => rulesError =
                                  'برای ساخت حساب، قوانین نسخه آزمایشی را بپذیر.');
                              return;
                            }
                            Navigator.pop(context, sentPhone);
                          }
                        },
                        child: Text(sent ? 'تأیید و ورود' : 'دریافت کد')),
                    if (sent)
                      TextButton(
                          onPressed: () => setState(() {
                                sent = false;
                                code.clear();
                              }),
                          child: const Text('تغییر شماره موبایل')),
                  ]))));
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor(
      {super.key,
      required this.profile,
      required this.completing,
      required this.selectPhotos});
  final UserProfile profile;
  final bool completing;
  final Future<List<Uint8List>> Function(int) selectPhotos;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final draft = widget.profile;
  late final name = TextEditingController(text: draft.name),
      bio = TextEditingController(text: draft.bio),
      experience = TextEditingController(text: draft.experience),
      availability = TextEditingController(text: draft.availability);
  final form = GlobalKey<FormState>();
  bool picking = false;
  String? skillsError;
  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    experience.dispose();
    availability.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(children: [
            ListTile(
                title: Text(
                    widget.completing
                        ? 'تکمیل پروفایل برای فعالیت'
                        : 'ویرایش پروفایل',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                    tooltip: 'بستن ویرایش پروفایل',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Form(
                        key: form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    CircleAvatar(
                                        radius: 28,
                                        backgroundColor:
                                            const Color(0xFFF8EFEF),
                                        backgroundImage: draft.avatar == null
                                            ? null
                                            : MemoryImage(draft.avatar!),
                                        child: draft.avatar == null
                                            ? const Icon(Icons.person_outline,
                                                color: red)
                                            : null),
                                    const SizedBox(width: 8),
                                    TextButton(
                                        onPressed: picking
                                            ? null
                                            : () async {
                                                setState(() => picking = true);
                                                final photos = await widget
                                                    .selectPhotos(1);
                                                if (mounted)
                                                  setState(() {
                                                    picking = false;
                                                    if (photos.isNotEmpty)
                                                      draft.avatar =
                                                          photos.first;
                                                  });
                                              },
                                        child:
                                            const Text('انتخاب عکس پروفایل')),
                                    if (draft.avatar != null)
                                      IconButton(
                                          tooltip: 'حذف عکس حساب',
                                          onPressed: () => setState(
                                              () => draft.avatar = null),
                                          icon: const Icon(Icons.close,
                                              size: 18)),
                                  ]),
                              TextFormField(
                                  key: const ValueKey('profile-name'),
                                  controller: name,
                                  decoration: const InputDecoration(
                                      labelText:
                                          'نام و نام خانوادگی / نام مجموعه'),
                                  validator: (v) => (v ?? '').trim().length >= 2
                                      ? null
                                      : 'نام را وارد کن'),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  initialValue: draft.specialty,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'گروه تخصص'),
                                  items: [
                                    'سازنده',
                                    'کارفرما',
                                    ...marketCategories.map((c) => c.label)
                                  ]
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s,
                                              style: const TextStyle(
                                                  fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => draft.specialty = v!)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<ActivityType>(
                                  initialValue: [
                                    ActivityType.individual,
                                    ActivityType.company
                                  ].contains(draft.activity)
                                      ? draft.activity
                                      : ActivityType.individual,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'نوع فعالیت'),
                                  items: [
                                    ActivityType.individual,
                                    ActivityType.company
                                  ]
                                      .map((a) => DropdownMenuItem(
                                          value: a, child: Text(a.label)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => draft.activity = v!)),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  key: ValueKey('profile-city-${draft.city}'),
                                  initialValue: draft.city,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'شهر اصلی فعالیت'),
                                  items: demoCities
                                      .map((c) => DropdownMenuItem(
                                          value: c.name,
                                          child: Text(
                                              '${c.name} · ${c.province}',
                                              style: const TextStyle(
                                                  fontSize: 12))))
                                      .toList(),
                                  validator: (v) => v == null
                                      ? 'شهر فعالیت را انتخاب کن'
                                      : null,
                                  onChanged: (v) => setState(() {
                                        draft.city = v;
                                        draft.coverage = v == null
                                            ? null
                                            : AreaFilter(
                                                province:
                                                    cityByName(v).province,
                                                city: v);
                                      })),
                              TextButton.icon(
                                  onPressed: () async {
                                    final area =
                                        await showModalBottomSheet<AreaFilter>(
                                            context: context,
                                            isScrollControlled: true,
                                            useSafeArea: true,
                                            constraints: const BoxConstraints(
                                                maxWidth: 460),
                                            builder: (_) => AreaPicker(
                                                initial: draft.coverage ??
                                                    const AreaFilter(),
                                                coverage: true));
                                    if (area != null && mounted)
                                      setState(() => draft.coverage = area);
                                  },
                                  icon:
                                      const Icon(Icons.map_outlined, size: 18),
                                  label: Text(
                                      'محدوده فعالیت: ${draft.coverage?.label ?? 'انتخاب محدوده'}',
                                      style: const TextStyle(fontSize: 11))),
                              const Text('مهارت‌ها و زمینه فعالیت',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: {
                                    ...draft.skills,
                                    ...profileSkillOptions(draft.specialty)
                                  }
                                      .map((skill) => FilterChip(
                                          label: Text(skill,
                                              style: const TextStyle(
                                                  fontSize: 10)),
                                          selected:
                                              draft.skills.contains(skill),
                                          onSelected: (v) => setState(() {
                                                v
                                                    ? draft.skills.add(skill)
                                                    : draft.skills
                                                        .remove(skill);
                                                skillsError = null;
                                              })))
                                      .toList()),
                              if (skillsError != null)
                                Text(skillsError!,
                                    style: const TextStyle(
                                        fontSize: 11, color: red)),
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: bio,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'معرفی کوتاه · اختیاری')),
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: experience,
                                  decoration: const InputDecoration(
                                      labelText: 'سابقه فعالیت · اختیاری')),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('آماده کار هستم',
                                      style: TextStyle(fontSize: 13)),
                                  value: draft.available,
                                  onChanged: (v) =>
                                      setState(() => draft.available = v)),
                              const SizedBox(height: 12),
                              const Text(
                                  'عکس نمونه‌کارها از صفحه پروفایل قابل افزودن و حذف است.',
                                  style: TextStyle(fontSize: 11, color: muted)),
                              const SizedBox(height: 12),
                            ])))),
            Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                    onPressed: picking
                        ? null
                        : () {
                            final valid = form.currentState!.validate();
                            if (draft.specialty != 'کارفرما' &&
                                draft.skills.isEmpty)
                              setState(() => skillsError =
                                  'حداقل یک مهارت یا زمینه فعالیت انتخاب کن');
                            if (!valid ||
                                (draft.specialty != 'کارفرما' &&
                                    draft.skills.isEmpty)) return;
                            draft.name = name.text.trim();
                            draft.bio = bio.text.trim();
                            draft.experience = experience.text.trim();
                            draft.availability = availability.text.trim();
                            draft.complete = true;
                            Navigator.pop(context, draft);
                          },
                    child: Text(widget.completing
                        ? 'ذخیره و ادامه فعالیت'
                        : 'ذخیره پروفایل'))),
          ])));
}

List<String> profileSkillOptions(String specialty) {
  final category =
      marketCategories.where((c) => c.label == specialty).firstOrNull;
  return category?.skills ??
      [...skillCatalog['خدمات']!, ...skillCatalog['نیرو']!];
}
