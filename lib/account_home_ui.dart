part of 'main.dart';

extension AccountHomeUi on _AppShellState {
  Widget accountHome() => ListView(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
    children: [
      const Text('ابزارهای کمچه',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      small('ابزارهای عمومی بدون ورود فعال هستند.'),
      section('اندازه‌گیری و محاسبه'),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          toolCard(Icons.square_foot_outlined, 'گونیا',
              'محاسبه و رند کردن اضلاع', 'squaring'),
          toolCard(Icons.straighten_outlined, 'متر دیجیتال',
              'اندازه‌گیری با دوربین AR', 'digitalMeter'),
          toolCard(Icons.calculate_outlined, 'ماشین‌حساب',
              'متره و برآورد مصالح', 'estimate'),
        ],
      ),
      section('مدیریت پروژه'),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          toolCard(Icons.account_balance_wallet_outlined, 'حسابداری',
              'دفتر کل، هزینه‌ها و پیش‌بینی', 'ledger'),
          toolCard(Icons.description_outlined, 'قراردادها',
              'تنظیم و آرشیو قرارداد', 'contracts'),
          toolCard(Icons.flag_outlined, 'گزارش‌ها',
              'گزارش‌های حساب کاربری', 'reports'),
        ],
      ),
      const Divider(height: 28),
      TextButton.icon(
        onPressed: () => go('rules'),
        icon: const Icon(Icons.policy_outlined, size: 18),
        label: const Text('قوانین کمچه'),
      ),
    ],
  );

  Widget toolCard(IconData icon, String title, String subtitle, String route) =>
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => go(route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: red, size: 26),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ),
      );

  Widget profileManagementCard() {
    if (!signedIn) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: const Color(0xFFFFF7F6),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('پروفایل من',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              small('برای ساخت و مدیریت پروفایل خود وارد شو.'),
              button('ورود / ثبت‌نام',
                  () => ensureAccess(() {}, activity: false),
                  icon: Icons.login),
              if (kamchehPreviewBuild)
                TextButton(
                    onPressed: () {
                      enterSampleAccount();
                      selectTab(1);
                    },
                    child: const Text('مشاهده حساب نمونه')),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFFFF7F6),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              editableAvatar(radius: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(myName.trim().isEmpty ? 'پروفایل من' : myName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    small(myProfile.complete
                        ? myProfile.specialty + ' · ' + (myProfile.city ?? '')
                        : 'پروفایل کامل نشده است'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 2, children: [
              TextButton.icon(
                  onPressed: () => editMyProfile(
                      completing: !myProfile.complete),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(myProfile.complete ? 'ویرایش' : 'تکمیل پروفایل')),
              TextButton.icon(
                  onPressed: () => go('ownProfile'),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('پروفایل من')),
              TextButton.icon(
                  onPressed: () => go('profilePreview'),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('پیش‌نمایش')),
              TextButton.icon(
                  onPressed: () => go('settings'),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('تنظیمات')),
            ]),
          ],
        ),
      ),
    );
  }

  Widget accountHeaderAction() {
    if (!signedIn) {
      return TextButton(
        onPressed: () => ensureAccess(() {}, activity: false),
        child: const Text('ورود / ثبت‌نام',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'حساب کاربری',
      onSelected: (value) {
        if (value == 'profile') selectTab(1);
        if (value == 'settings') go('settings');
        if (value == 'logout') logout();
        if (value == 'switch') switchDemoAccount();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'profile', child: Text('پروفایل من')),
        const PopupMenuItem(value: 'settings', child: Text('تنظیمات پروفایل')),
        if (widget.persistDemo)
          const PopupMenuItem(value: 'switch', child: Text('تغییر حساب نمونه')),
        const PopupMenuItem(value: 'logout', child: Text('خروج')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_circle_outlined, size: 20),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 105),
            child: Text(myName.trim().isEmpty ? 'حساب من' : myName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const Icon(Icons.arrow_drop_down, size: 17),
        ]),
      ),
    );
  }

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
