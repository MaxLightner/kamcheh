part of 'main.dart';

extension AccountHomeUi on _AppShellState {
  Widget accountHome() => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 570;
        if (!signedIn)
          return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Icon(Icons.person_outline, size: 74, color: red),
                    const SizedBox(height: 16),
                    const Text('به کمچه خوش آمدی',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'آگهی‌ها و افراد را ببین؛ برای فعالیت وارد حساب شو.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    button('ورود با شماره موبایل',
                        () => ensureAccess(() => selectTab(4), activity: false),
                        icon: Icons.login),
                    TextButton(
                        onPressed: enterSampleAccount,
                        child: const Text('مشاهده حساب نمونه')),
                    const Spacer(),
                    TextButton.icon(
                        onPressed: () => go('rules'),
                        icon: const Icon(Icons.policy_outlined),
                        label: const Text('قوانین کمچه')),
                    small(
                        'ورود در این نسخه نمایشی است؛ پیامک واقعی ارسال نمی‌شود.'),
                  ]));
        final views =
            profileRepository.profileViews[myProfile.id]?.values.toList() ??
                <DateTime>[];
        final today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
        Widget stat(String value, String title) => Expanded(
                child: Column(children: [
              Text(value,
                  style: TextStyle(
                      fontSize: compact ? 17 : 21,
                      fontWeight: FontWeight.bold,
                      color: red)),
              Text(title, style: const TextStyle(fontSize: 10, color: muted))
            ]));
        Widget action(IconData icon, String title, VoidCallback tap) =>
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: tap,
                    style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            vertical: compact ? 8 : 14, horizontal: 6),
                        side: const BorderSide(color: line),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: Icon(icon, size: 18),
                    label: Text(title, style: const TextStyle(fontSize: 12))));
        return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                      padding: EdgeInsets.all(compact ? 12 : 18),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F3),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF6E5E3))),
                      child: Column(children: [
                        Row(children: [
                          editableAvatar(radius: compact ? 35 : 46),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(myName.isEmpty ? 'حساب من' : myName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: compact ? 17 : 20,
                                        fontWeight: FontWeight.bold)),
                                Text(myProfile.specialty,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                                Text(
                                    myProfile.coverage?.label ??
                                        myProfile.city ??
                                        'محدوده مشخص نشده',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: muted)),
                                Text(
                                    myProfile.available
                                        ? '● آماده همکاری'
                                        : '● فعلاً در دسترس نیست',
                                    style: const TextStyle(
                                        fontSize: 10, color: muted)),
                              ]))
                        ]),
                        SizedBox(height: compact ? 12 : 18),
                        InkWell(
                            onTap: () => go('profileStats'),
                            borderRadius: BorderRadius.circular(10),
                            child: Row(children: [
                              stat(fa(views.length), 'بازدید پروفایل'),
                              stat(
                                  fa(views
                                      .where((v) => !v.isBefore(today))
                                      .length),
                                  'بازدید امروز'),
                              stat(fa(myProfile.photos.length), 'نمونه‌کار')
                            ]))
                      ])),
                  const SizedBox(height: 8),
                  if (!myProfile.complete)
                    button(
                        'تکمیل پروفایل', () => editMyProfile(completing: true)),
                  Row(children: [
                    action(Icons.person_outline, 'پروفایل عمومی من',
                        () => go('ownProfile')),
                    const SizedBox(width: 8),
                    action(Icons.visibility_outlined, 'پیش‌نمایش پروفایل',
                        () => go('profilePreview'))
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    action(Icons.description_outlined, 'قراردادهای من',
                        () => go('contracts')),
                    const SizedBox(width: 8),
                    action(Icons.calculate_outlined, 'برآورد مصالح',
                        () => go('estimate'))
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    action(Icons.flag_outlined, 'گزارش‌های من',
                        () => go('reports')),
                    const SizedBox(width: 8),
                    action(Icons.switch_account_outlined, 'حساب‌های نمونه',
                        switchDemoAccount)
                  ]),
                  const Spacer(),
                  const Divider(height: 12),
                  Row(children: [
                    Expanded(
                        child: TextButton.icon(
                            onPressed: () => go('settings'),
                            icon: const Icon(Icons.settings_outlined, size: 17),
                            label: const Text('تنظیمات',
                                style: TextStyle(fontSize: 11)))),
                    Expanded(
                        child: TextButton.icon(
                            onPressed: () => go('rules'),
                            icon: const Icon(Icons.policy_outlined, size: 17),
                            label: const Text('قوانین کمچه',
                                style: TextStyle(fontSize: 11)))),
                    Expanded(
                        child: TextButton.icon(
                            onPressed: logout,
                            icon: const Icon(Icons.logout, size: 17),
                            label: const Text('خروج',
                                style: TextStyle(fontSize: 11)))),
                  ]),
                ]));
      });

  Future<void> chooseProfileCover() async {
    final owner = actorId;
    final photos = await selectPhotos(1);
    if (!mounted || owner != actorId || photos.isEmpty) return;
    update(() {
      myProfile.coverPhoto = ProfilePhoto.bytes(photos.first);
      profileRepository.save(myProfile);
    });
  }

  Widget coverSettings() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        section('عکس کارت پروفایل'),
        if (myProfile.coverPhoto != null)
          SizedBox(height: 120, child: profilePicture(myProfile.coverPhoto!)),
        Row(children: [
          Expanded(
              child: TextButton.icon(
                  onPressed: chooseProfileCover,
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(myProfile.coverPhoto == null
                      ? 'انتخاب عکس کارت'
                      : 'تغییر عکس کارت'))),
          if (myProfile.coverPhoto != null)
            TextButton(
                onPressed: () => update(() {
                      myProfile.coverPhoto = null;
                      profileRepository.save(myProfile);
                    }),
                child: const Text('حذف عکس'))
        ]),
        small('اگر عکس کارت انتخاب نکنی، آواتارت نمایش داده می‌شود.'),
      ]);
}
