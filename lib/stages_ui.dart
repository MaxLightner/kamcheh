part of 'main.dart';

class DemoReport {
  DemoReport(this.authorId, this.targetId, this.reason, this.note)
      : id = 'report-${DateTime.now().microsecondsSinceEpoch}',
        createdAt = DateTime.now();
  final String id, authorId, targetId, reason, note;
  final DateTime createdAt;
}

extension LaterDemoUi on _AppShellState {
  Future<void> createSimpleContract({String? peer, String? subject}) async {
    if (!canAct) {
      await ensureAccess(
          () => createSimpleContract(peer: peer, subject: subject));
      return;
    }
    final template = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
            title: const Text('نوع قرارداد'),
            children: ['اجرای کار', 'خدمات طراحی', 'توافق عمومی']
                .map((t) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, t), child: Text(t)))
                .toList()));
    if (template == null || !mounted) return;
    final title =
        await edit('موضوع قرارداد', subject ?? '', hint: 'مثلاً اجرای داربست');
    if (title == null || title.isEmpty || !mounted) return;
    update(() {
      final draft = ContractDraft(
          title,
          {
            'طرفین': peer == null ? '' : '$myName · $peer',
            'موضوع و محل': title,
            'مبلغ و مدت': '',
            'شرایط توافق': '',
            'تأمین مصالح و ابزار': '',
            'هزینه حمل و جمع‌آوری': '',
            'تغییر و لغو توافق': '',
            'حل اختلاف': '',
          },
          template: template);
      if (peer != null && currentWorkChat != null && peer == chatPeerName)
        draft.threadId = currentWorkChat!.id;
      drafts.add(draft);
      contractIndex = drafts.length - 1;
    });
    go('contract');
  }

  Widget contractField(ContractDraft draft, String key) => menuRow(
          key,
          (draft.values[key]?.isEmpty ?? true)
              ? 'برای تکمیل بزن'
              : draft.values[key]!,
          Icons.edit_outlined, () async {
        final value = await edit(key, draft.values[key] ?? '',
            hint: switch (key) {
              'طرفین' => 'نام و مشخصات طرف اول و طرف دوم',
              'موضوع و محل' => 'شرح کار، محدوده تعهد و محل اجرای آن',
              'مبلغ و مدت' => 'مبلغ و واحد پول، زمان شروع و پایان',
              'شرایط توافق' => 'پرداخت‌ها، کیفیت و تعهدات هر طرف',
              _ => 'شرایط مورد توافق طرفین',
            });
        if (value != null && mounted) update(() => draft.values[key] = value);
      });

  List<Widget> simpleContract() {
    if (drafts.isEmpty || contractIndex >= drafts.length)
      return [
        emptyState(
            'قراردادی انتخاب نشده', 'از قراردادهای من یک قرارداد انتخاب کن.')
      ];
    final draft = drafts[contractIndex];
    return [
      Text(draft.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      small(
          '${draft.template} · ${draft.status}${draft.parentId == null ? '' : ' · الحاقیه'}'),
      const SizedBox(height: 8),
      for (final key in ['طرفین', 'موضوع و محل', 'مبلغ و مدت', 'شرایط توافق'])
        contractField(draft, key),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('شرایط تکمیلی', style: TextStyle(fontSize: 13)),
          children: [
            for (final key in [
              'تأمین مصالح و ابزار',
              'هزینه حمل و جمع‌آوری',
              'تغییر و لغو توافق',
              'حل اختلاف'
            ])
              contractField(draft, key)
          ]),
      section('پیوست‌ها'),
      photoChooser(draft.photos, () async {
        final files = await selectPhotos(6 - draft.photos.length);
        if (mounted) update(() => draft.photos.addAll(files));
      }, (i) => update(() => draft.photos.removeAt(i))),
      const SizedBox(height: 10),
      button('ذخیره نسخه و دریافت PDF', () async {
        if (draft.validationError != null) {
          notice(draft.validationError!);
          return;
        }
        final snapshot = draft.saveRevision();
        update(() {});
        await exportContract(snapshot, draft.id);
      }, icon: Icons.picture_as_pdf_outlined),
      button('ذخیره پیش‌نویس', () {
        update(() => draft.status = 'پیش‌نویس ذخیره‌شده');
        go('contracts');
      }, outlined: true),
      if (draft.revisions.isNotEmpty) ...[
        section('نسخه‌های ذخیره‌شده'),
        ...draft.revisions.reversed.map((v) => menuRow(
            'نسخه ${fa(v.number)}',
            shortDate(v.createdAt),
            Icons.history,
            () => showContractRevision(draft, v))),
        button('افزودن الحاقیه', () => createAddendum(draft),
            outlined: true, icon: Icons.add),
      ],
      small(
          'نسخه‌های ذخیره‌شده تغییر نمی‌کنند. پیش‌نویس جدید و الحاقیه جدا نگهداری می‌شوند. این نسخه امضای دیجیتال یا ذخیره سرور ندارد.'),
    ];
  }

  String shortDate(DateTime d) => jalaliDate(d, withTime: true);
  Future<void> showContractRevision(ContractDraft draft, ContractRevision v) =>
      showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          constraints: const BoxConstraints(maxWidth: 460),
          builder: (ctx) => SizedBox(
              height: MediaQuery.sizeOf(ctx).height * .8,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text('${v.title} · نسخه ${fa(v.number)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                small(shortDate(v.createdAt)),
                for (final e
                    in v.values.entries.where((e) => e.value.isNotEmpty)) ...[
                  section(e.key),
                  Text(e.value)
                ],
                small('${fa(v.photos.length)} پیوست · فقط خواندنی'),
                button(
                    'دریافت همین نسخه PDF', () => exportContract(v, draft.id)),
                button('بستن', () => Navigator.pop(ctx), outlined: true)
              ])));
  Future<void> exportContract(ContractRevision v, String id) async {
    try {
      final bytes = await buildContractPdf(v);
      final filename = '$id-v${v.number}.pdf';
      await deliverPdf(bytes, filename);
    } catch (_) {
      if (mounted)
        notice('دریافت فایل انجام نشد؛ نسخه ذخیره‌شده را دوباره امتحان کن.');
    }
  }

  Future<void> createAddendum(ContractDraft parent) async {
    final text =
        await edit('موضوع الحاقیه', '', hint: 'مثلاً تغییر مبلغ یا افزودن کار');
    if (text == null || text.isEmpty || !mounted) return;
    final snapshot = parent.revisions.last;
    update(() {
      final draft = ContractDraft(
          'الحاقیه: $text',
          {
            'طرفین': snapshot.values['طرفین'] ?? '',
            'موضوع و محل': text,
            'مبلغ و مدت': '',
            'شرایط توافق': '',
            'ارجاع': '${parent.id} · نسخه ${snapshot.number}'
          },
          template: parent.template,
          parentId: parent.id);
      draft.threadId = parent.threadId;
      drafts.add(draft);
      contractIndex = drafts.length - 1;
    });
    go('contract');
  }

  List<Widget> simpleContracts() => [
        small('مستقل از درخواست یا مرتبط با گفت‌وگو · آرشیو روی همین دستگاه'),
        ...drafts.asMap().entries.map((e) => menuRow(
                e.value.title,
                '${e.value.status}${e.value.parentId == null ? '' : ' · الحاقیه'}',
                Icons.description_outlined, () {
              contractIndex = e.key;
              go('contract');
            })),
        const SizedBox(height: 12),
        button('قرارداد جدید', () => createContract(), icon: Icons.add),
        small(
            'متن فعلی برای نمایش جریان کار است. قالب‌های قراردادی نهایی شما جایگزین متن نمونه می‌شوند.'),
      ];

  List<(AccountWorkspace, WorkReview)> reviewsFor(UserProfile p) =>
      accountSpaces.values
          .expand((space) => space.workReviews
              .where((r) => r.subjectProfileId == null
                  ? r.peer == p.name
                  : r.subjectProfileId == p.id)
              .map((r) => (space, r)))
          .toList();
  List<Widget> profileFeedback(UserProfile p) {
    final records = reviewsFor(p);
    final average = records.isEmpty
        ? null
        : records.map((r) => r.$2.punctuality).reduce((a, b) => a + b) /
            records.length;
    return [
      if (average != null)
        pair('خوش‌قولی · ${fa(records.length)} تجربه',
            '${fa(average.toStringAsFixed(1))} از ۵')
      else
        small('هنوز تجربه‌ای ثبت نشده است.'),
      ...records.map((entry) => panel([
            Text(entry.$1.profile.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            reviewCard(entry.$2),
            if (signedIn && myProfile.id == p.id)
              TextButton(
                  onPressed: () async {
                    final reply = await edit('پاسخ به تجربه', entry.$2.reply);
                    if (reply != null && mounted)
                      update(() => entry.$2.reply = reply);
                  },
                  child: Text(
                      entry.$2.reply.isEmpty ? 'ثبت پاسخ' : 'ویرایش پاسخ')),
            TextButton(
                onPressed: () => reportTarget(
                    'review:${entry.$1.profile.id}:${entry.$2.contextId}'),
                child: const Text('گزارش نظر')),
          ])),
      if (signedIn && myProfile.id != p.id)
        button('ثبت تجربه مربوط به قرار', () => recordReviewForPeer(p.name),
            outlined: true),
      TextButton(
          onPressed: () => reportTarget('profile:${p.id}'),
          child: const Text('گزارش پروفایل')),
    ];
  }

  Future<void> reportTarget(String target) async {
    if (!signedIn) {
      await ensureAccess(() => reportTarget(target), activity: false);
      return;
    }
    var reason = 'اطلاعات نادرست';
    final note = TextEditingController();
    final send = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialog) => AlertDialog(
                    title: const Text('گزارش'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          initialValue: reason,
                          isExpanded: true,
                          items: [
                            'اطلاعات نادرست',
                            'رفتار نامناسب',
                            'هرزنامه',
                            'مورد دیگر'
                          ]
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (r) => setDialog(() => reason = r!)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: note,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'توضیح · اختیاری')),
                      const SizedBox(height: 8),
                      small(
                          'گزارش در این دمو محلی است و برای پشتیبانی واقعی ارسال نمی‌شود.')
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('انصراف')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ثبت گزارش'))
                    ])));
    if (send == true && mounted) {
      update(() => reports
          .add(DemoReport(myProfile.id, target, reason, note.text.trim())));
      notice('گزارش در این نشست ثبت شد.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    note.dispose();
  }

  List<Widget> myReports() => [
        small('فقط گزارش‌های حساب خودت · نسخه آزمایشی'),
        ...reports.where((r) => r.authorId == myProfile.id).map((r) => panel([
              Text(r.reason,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              small(shortDate(r.createdAt)),
              if (r.note.isNotEmpty) Text(r.note),
              small('ثبت محلی · ارسال به پشتیبانی فعال نیست.')
            ])),
        if (!reports.any((r) => r.authorId == myProfile.id))
          emptyState('گزارشی ثبت نشده',
              'از صفحه آگهی، پروفایل یا نظر می‌توانی گزارش ثبت کنی.')
      ];
}
