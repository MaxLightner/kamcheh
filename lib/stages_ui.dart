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
    final actor = actorId;
    final conversation =
        peer != null && currentWorkChat != null && peer == chatPeerName
            ? currentWorkChat
            : null;
    final result = await Navigator.of(context).push<ContractDraft>(
        MaterialPageRoute(
            builder: (_) => ContractSetupPage(
                profiles: profileRepository.profiles
                    .where((p) => p.id != actor && p.complete)
                    .toList(),
                actor: myProfile,
                subject: subject ?? '',
                peerId: conversation?.peer(actor),
                parent: null)));
    if (result == null || !mounted || actor != actorId) return;
    update(() {
      result.threadId = conversation?.id;
      drafts.add(result);
      contractIndex = drafts.length - 1;
      selectedContractId = result.id;
    });
    go('contract');
  }

  ContractDraft? get openedContract {
    if (selectedContractId != null) {
      for (final space in accountSpaces.values) {
        for (final d in space.drafts) {
          if (d.id == selectedContractId &&
              (space.profile.id == actorId || d.parties.containsKey(actorId)))
            return d;
        }
      }
    }
    return contractIndex < drafts.length ? drafts[contractIndex] : null;
  }

  List<Widget> simpleContract() {
    final d = openedContract;
    if (d == null)
      return [
        emptyState('قراردادی انتخاب نشده', 'از قراردادهای من انتخاب کن.')
      ];
    return [
      ContractEditor(
          key: ValueKey('${d.id}:$actorId'),
          draft: d,
          actor: myProfile,
          onChanged: () => update(() {}),
          choosePhotos: selectPhotos,
          export: (v) => exportContract(v, d.id),
          addendum: () => createAddendum(d),
          upgrade: () => createSimpleContract(subject: d.title))
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
    if (parent.revisions.isEmpty || !parent.parties.containsKey(actorId))
      return;
    final actor = actorId;
    final result = await Navigator.of(context).push<ContractDraft>(
        MaterialPageRoute(
            builder: (_) => ContractSetupPage(
                profiles: profileRepository.profiles.toList(),
                actor: myProfile,
                subject: '',
                peerId: parent.parties.keys.firstWhere((id) => id != actor),
                parent: parent)));
    if (result == null || !mounted || actor != actorId) return;
    update(() {
      result.threadId = parent.threadId;
      drafts.add(result);
      selectedContractId = result.id;
      contractIndex = drafts.length - 1;
    });
    go('contract');
  }

  List<Widget> simpleContracts() {
    final all = <String, ContractDraft>{};
    for (final space in accountSpaces.values) {
      for (final d in space.drafts) {
        if (space.profile.id == actorId || d.parties.containsKey(actorId))
          all[d.id] = d;
      }
    }
    return [
      small(
          'قرارداد مستقل یا مرتبط با گفتگو · اطلاعات هر طرف توسط خودش تکمیل می‌شود'),
      if (all.isEmpty)
        emptyState('هنوز قراردادی نداری',
            'با یکی از اعضای کمچه قرارداد مستقل تنظیم کن.'),
      ...all.values.map((d) => menuRow(
              d.title,
              '${d.status}${d.parentId == null ? '' : ' · الحاقیه'}',
              Icons.description_outlined, () {
            selectedContractId = d.id;
            go('contract');
          })),
      button('قرارداد جدید', () => createContract(), icon: Icons.add),
      small(
          'دمو: همکاری دو حساب روی همین دستگاه؛ ارسال دعوت و همگام‌سازی واقعی پس از اتصال سرور.')
    ];
  }

  List<(AccountWorkspace, WorkReview)> reviewsFor(UserProfile p) =>
      accountSpaces.values
          .expand((space) => space.workReviews
              .where((r) => r.subjectProfileId == null
                  ? r.peer == p.name
                  : r.subjectProfileId == p.id)
              .map((r) => (space, r)))
          .toList();
  List<Widget> profileFeedback(UserProfile p, {bool readOnly = false}) {
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
            if (!readOnly && signedIn && myProfile.id == p.id)
              TextButton(
                  onPressed: () async {
                    final reply = await edit('پاسخ به تجربه', entry.$2.reply);
                    if (reply != null && mounted)
                      update(() => entry.$2.reply = reply);
                  },
                  child: Text(
                      entry.$2.reply.isEmpty ? 'ثبت پاسخ' : 'ویرایش پاسخ')),
            if (!readOnly)
              TextButton(
                  onPressed: () => reportTarget(
                      'review:${entry.$1.profile.id}:${entry.$2.contextId}'),
                  child: const Text('گزارش نظر')),
          ])),
      if (!readOnly && signedIn && myProfile.id != p.id)
        button('ثبت تجربه مربوط به قرار', () => recordReviewForPeer(p.name),
            outlined: true),
      if (!readOnly)
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
