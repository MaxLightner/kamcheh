part of 'main.dart';

extension AdProfileUi on _AppShellState {
  List<ProfilePhoto> servicePictures(ServiceListing s) => [
        ...s.photos.map(ProfilePhoto.bytes),
        ...s.galleryAssets.map(ProfilePhoto.asset),
        if (s.photos.isEmpty && s.galleryAssets.isEmpty)
          ProfilePhoto.asset(s.image),
      ];
  String serviceStatus(ServiceListing s) => s.archived
      ? 'حذف‌شده'
      : s.enabled
          ? 'فعال'
          : 'متوقف';
  Future<void> deleteService(ServiceListing s) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('حذف آگهی؟'),
                content: const Text(
                    'آگهی از فهرست عمومی حذف می‌شود. گفتگوها باقی می‌مانند و از آگهی‌های حذف‌شده می‌توانی آن را برگردانی.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف آگهی'))
                ]));
    if (yes == true && mounted)
      workAction(
          () => workStore.changeServiceStatus(s.id, actorId, archived: true));
  }

  List<Widget> serviceOwnerActions(ServiceListing s) => [
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          OutlinedButton.icon(
              onPressed: s.archived ? null : () => editService(s),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('ویرایش')),
          if (!s.archived)
            OutlinedButton.icon(
                onPressed: () => workAction(() => workStore.changeServiceStatus(
                    s.id, actorId, enabled: !s.enabled)),
                icon: Icon(
                    s.enabled
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 17),
                label: Text(s.enabled ? 'توقف نمایش' : 'فعال کردن')),
          if (!s.archived)
            TextButton.icon(
                onPressed: () => deleteService(s),
                icon: const Icon(Icons.delete_outline, size: 17),
                label: const Text('حذف')),
          if (s.archived)
            OutlinedButton.icon(
                onPressed: () => workAction(() => workStore
                    .changeServiceStatus(s.id, actorId, archived: false)),
                icon: const Icon(Icons.restore, size: 17),
                label: const Text('بازگرداندن')),
        ]),
      ];
  String connectionStatus(String s) => switch (s) {
        'accepted' => 'پذیرفته‌شده',
        'declined' => 'پذیرفته نشد',
        'cancelled' => 'لغوشده',
        _ => 'در انتظار پاسخ'
      };
  Iterable<ServiceContact> contactsFor(String id) => workStore.contacts.values
      .where((c) =>
          c.serviceId == id &&
          (c.fromId == actorId || workStore.service(id).ownerId == actorId))
      .toList()
      .reversed;
  Widget serviceContactCard(ServiceContact c) {
    final s = workStore.service(c.serviceId), owner = s.ownerId == actorId;
    return panel([
      Row(children: [
        Expanded(
            child: Text(c.kind.label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13))),
        label(connectionStatus(c.status),
            color: c.status == 'pending' ? red : muted)
      ]),
      small('${s.title} · ${shortDate(c.createdAt)}'),
      TextButton.icon(
          onPressed: () => showWorkProfile(owner ? c.fromId : s.ownerId),
          icon: const Icon(Icons.person_outline, size: 17),
          label: Text(workName(owner ? c.fromId : s.ownerId))),
      Text(c.details, style: const TextStyle(fontSize: 12)),
      if (c.amount != null)
        pair('مبلغ پیشنهادی', '${money(c.amount!)} / ${c.unit.label}'),
      if (c.visitAt != null) pair('زمان بازدید', shortDate(c.visitAt!)),
      if (c.status == 'pending' && owner)
        Row(children: [
          Expanded(
              child: button(
                  'پذیرش و گفتگو',
                  () => workAction(() => workStore.respondServiceContact(
                      c.id, actorId, 'accepted')))),
          const SizedBox(width: 8),
          Expanded(
              child: button(
                  'رد درخواست',
                  () => workAction(() => workStore.respondServiceContact(
                      c.id, actorId, 'declined')),
                  outlined: true)),
        ]),
      if (c.status == 'pending' && !owner)
        TextButton(
            onPressed: () => workAction(() =>
                workStore.respondServiceContact(c.id, actorId, 'cancelled')),
            child: const Text('لغو درخواست')),
      if (c.status == 'accepted')
        button(
            'باز کردن گفتگو',
            () => openCanonicalChat(
                workStore.conversationKey(s.id, c.fromId, 'service')),
            outlined: true),
    ]);
  }

  List<Widget> serviceConnectionsView() {
    final contacts = workStore.contacts.values
        .where((c) =>
            c.fromId == actorId ||
            workStore.service(c.serviceId).ownerId == actorId)
        .toList()
      ..sort((a, b) => (a.status == 'pending' ? 0 : 1)
                  .compareTo(b.status == 'pending' ? 0 : 1) !=
              0
          ? (a.status == 'pending' ? 0 : 1)
              .compareTo(b.status == 'pending' ? 0 : 1)
          : b.createdAt.compareTo(a.createdAt));
    return [
      small(
          'درخواست‌های ارتباط با آگهی‌ها و درخواست‌ها؛ گفتگو پس از پذیرش صاحب آن باز می‌شود.'),
      const SizedBox(height: 8),
      ...contacts.map(serviceContactCard),
      ...workStore.chatRequests.values
          .where((c) =>
              c.fromId == actorId ||
              workStore.need(c.requestId).ownerId == actorId)
          .map((c) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextButton(
                    onPressed: () =>
                        openAd(workAd(workStore.need(c.requestId))),
                    child: Text(workStore.need(c.requestId).title)),
                requestConnectionCard(workStore.need(c.requestId), c),
              ])),
      if (contacts.isEmpty &&
          !workStore.chatRequests.values.any((c) =>
              c.fromId == actorId ||
              workStore.need(c.requestId).ownerId == actorId))
        emptyState('درخواست ارتباطی نداری',
            'از آگهی خدمات، درخواست پیش‌فاکتور، همکاری یا بازدید ثبت کن.')
    ];
  }

  Future<void> requestServiceConnection(
      ServiceListing s, ServiceContactKind kind) async {
    if (!canAct) {
      await ensureAccess(() => requestServiceConnection(s, kind));
      return;
    }
    final actor = actorId;
    final result = await Navigator.of(context).push<ServiceContact>(
        MaterialPageRoute(
            builder: (_) =>
                _ServiceConnectionForm(service: s, actor: actor, kind: kind)));
    if (!mounted || result == null || actor != actorId) return;
    if (workAction(() => workStore.requestServiceContact(
        s.id, actor, result.kind, result.details,
        amount: result.amount, unit: result.unit, visitAt: result.visitAt)))
      notice('درخواست ارتباط ثبت شد؛ صاحب آگهی آن را بررسی می‌کند.');
  }

  Future<void> chooseServiceConnection(ServiceListing s) =>
      showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
                const ListTile(title: Text('ارتباط با صاحب آگهی')),
                for (final kind in [
                  ServiceContactKind.cooperation,
                  ServiceContactKind.visit,
                  ServiceContactKind.conversation
                ])
                  ListTile(
                      title: Text(kind.label),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.pop(ctx);
                        requestServiceConnection(s, kind);
                      }),
              ]));
  Future<void> requestServiceChatVisit(WorkConversation c) async {
    final actor = actorId;
    final date = await pickPersianDate(context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)));
    if (!mounted || date == null || actor != actorId) return;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (!mounted || time == null || actor != actorId) return;
    workAction(() => workStore.proposeServiceVisit(
        c.contextId,
        c.bidderId,
        actor,
        DateTime(date.year, date.month, date.day, time.hour, time.minute)));
  }

  void recordProfileView(UserProfile p) {
    if (profileRepository.recordView(p.id, actorId.isEmpty ? 'guest' : actorId))
      persistWork();
  }

  Future<void> changeAvatar() async {
    if (!signedIn) return;
    final phone = activePhone;
    final action = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.add_a_photo_outlined),
                  title: const Text('انتخاب عکس پروفایل'),
                  onTap: () => Navigator.pop(ctx, 'choose')),
              if (myProfile.avatar != null)
                ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('حذف عکس پروفایل'),
                    onTap: () => Navigator.pop(ctx, 'remove')),
            ]));
    if (!mounted || phone != activePhone) return;
    if (action == 'remove') {
      update(() => myProfile.avatar = null);
      return;
    }
    if (action != 'choose') return;
    final photos = await selectPhotos(1);
    if (!mounted || phone != activePhone || photos.isEmpty) return;
    update(() => myProfile.avatar = photos.first);
  }

  Widget editableAvatar({double radius = 24}) => Semantics(
      button: true,
      label: 'تنظیم عکس پروفایل',
      child: InkWell(
          onTap: changeAvatar,
          borderRadius: BorderRadius.circular(40),
          child: Stack(children: [
            myAvatar(radius: radius),
            Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration:
                        const BoxDecoration(color: red, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 12, color: Colors.white))),
          ])));
  List<Widget> profileStatsView() {
    final views =
        profileRepository.profileViews[myProfile.id]?.values.toList() ??
            <DateTime>[];
    final now = DateTime.now(),
        today = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return [
      panel([
        pair('کل بازدیدهای ثبت‌شده', fa(views.length)),
        pair('امروز', fa(views.where((v) => !v.isBefore(today)).length)),
        pair(
            '۷ روز اخیر',
            fa(views
                .where((v) => v.isAfter(now.subtract(const Duration(days: 7))))
                .length))
      ]),
      small(
          'در دمو، فقط بازدیدهای همین دستگاه ثبت می‌شوند. بازدید خودت محاسبه نمی‌شود؛ هر بازدیدکننده در روز یک بار شمرده می‌شود.'),
      button('پیش‌نمایش پروفایل عمومی', () => go('profilePreview'),
          outlined: true)
    ];
  }

  Widget profileTile(UserProfile p) {
    final picture = p.coverPhoto ??
        (p.avatar == null ? null : ProfilePhoto.bytes(p.avatar!));
    final foreground = picture == null ? ink : Colors.white;
    return Semantics(
        button: true,
        label: 'پروفایل ${p.name}',
        child: InkWell(
            key: ValueKey('profile-tile-${p.id}'),
            onTap: () => viewPerson(p),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(fit: StackFit.expand, children: [
                  if (picture != null)
                    profilePicture(picture)
                  else
                    Container(
                        color: const Color(0xFFF8EFEF),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 22),
                        child: const Icon(Icons.person_outline,
                            size: 62, color: Color(0xFFD6B7B7))),
                  if (picture != null)
                    const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0xDA111820)],
                                stops: [.15, .9]))),
                  Positioned(
                      top: 6,
                      left: 6,
                      child: IconButton.filledTonal(
                          tooltip: 'نشان کردن ${p.name}',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => togglePersonBookmark(profileCard(p)),
                          icon: Icon(
                              savedPeople.containsKey(p.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              size: 18))),
                  Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: foreground,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            profileBadges(profileCard(p), compact: true),
                            const SizedBox(height: 5),
                            Text(
                                p.skills.isEmpty
                                    ? p.bio
                                    : p.skills.take(2).join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: foreground)),
                            const SizedBox(height: 5),
                            Text(
                                p.coverage?.label ??
                                    p.city ??
                                    'محدوده مشخص نشده',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 10, color: foreground)),
                            Text(
                                p.available
                                    ? '● آماده کار'
                                    : 'فعلاً در دسترس نیست',
                                maxLines: 1,
                                style:
                                    TextStyle(fontSize: 10, color: foreground)),
                          ])),
                ]))));
  }
}

class _ServiceConnectionForm extends StatefulWidget {
  const _ServiceConnectionForm(
      {required this.service, required this.actor, required this.kind});
  final ServiceListing service;
  final String actor;
  final ServiceContactKind kind;
  @override
  State<_ServiceConnectionForm> createState() => _ServiceConnectionFormState();
}

class _ServiceConnectionFormState extends State<_ServiceConnectionForm> {
  final form = GlobalKey<FormState>();
  final details = TextEditingController(), amount = TextEditingController();
  DateTime? visitAt;
  PriceUnit unit = PriceUnit.project;
  @override
  void dispose() {
    details.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final day = await pickPersianDate(context,
        initialDate: visitAt ?? DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)));
    if (!mounted || day == null) return;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (mounted && time != null)
      setState(() => visitAt =
          DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.kind.label)),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.service.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'پس از پذیرش صاحب آگهی، گفتگوی مرتبط باز می‌شود.',
                        style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: details,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'شرح نیاز و شرایط'),
                        validator: (s) => s?.trim().isNotEmpty == true
                            ? null
                            : 'شرح نیاز را بنویس.'),
                    if (widget.kind == ServiceContactKind.cooperation) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'مبلغ پیشنهادی به تومان (اختیاری)'),
                          validator: (v) => v?.trim().isNotEmpty == true &&
                                  (parsePriceInput(v!) ?? 0) <= 0
                              ? 'مبلغ مثبت و معتبر بنویس.'
                              : null),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<PriceUnit>(
                          initialValue: unit,
                          decoration:
                              const InputDecoration(labelText: 'واحد مبلغ'),
                          items: PriceUnit.values
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u.label)))
                              .toList(),
                          onChanged: (v) => setState(() => unit = v!)),
                    ],
                    if (widget.kind == ServiceContactKind.visit) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: chooseDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(visitAt == null
                              ? 'انتخاب روز و ساعت بازدید'
                              : jalaliDate(visitAt!, withTime: true)))
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                        onPressed: () {
                          if (!form.currentState!.validate()) return;
                          if (widget.kind == ServiceContactKind.visit &&
                              (visitAt == null ||
                                  !visitAt!.isAfter(DateTime.now()))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'زمان بازدید را در آینده انتخاب کن.')));
                            return;
                          }
                          Navigator.pop(
                              context,
                              ServiceContact(
                                  '',
                                  widget.service.id,
                                  widget.actor,
                                  widget.kind,
                                  details.text.trim(),
                                  amount: parsePriceInput(amount.text),
                                  unit: unit,
                                  visitAt: visitAt));
                        },
                        child: const Text('ارسال درخواست ارتباط')),
                  ]))));
}
