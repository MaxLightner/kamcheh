part of 'main.dart';

extension RequestDetailsUi on _AppShellState {
  String requestStatus(WorkNeed n) => n.archived
      ? 'بایگانی‌شده'
      : n.closed
          ? 'بسته‌شده'
          : n.expiredAt(workStore.now())
              ? 'مهلت پایان یافته'
              : 'دریافت پیشنهاد';
  Future<void> chooseRequestDeadline() async {
    final now = DateTime.now();
    final day = await pickPersianDate(context,
        initialDate: workDeadline != null && workDeadline!.isAfter(now)
            ? workDeadline!
            : now.add(const Duration(days: 3)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)));
    if (!mounted || day == null) return;
    final time = await showTimePicker(
        context: context,
        initialTime: workDeadline == null
            ? const TimeOfDay(hour: 18, minute: 0)
            : TimeOfDay.fromDateTime(workDeadline!));
    if (!mounted || time == null) return;
    final end = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!end.isAfter(DateTime.now())) {
      notice('مهلت باید در آینده باشد.');
      return;
    }
    update(() => workDeadline = end);
  }

  Widget deadlineInput() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مهلت دریافت پیشنهاد', style: TextStyle(fontSize: 13)),
        Wrap(spacing: 6, children: [
          ChoiceChip(
              label: const Text('بدون مهلت'),
              selected: workDeadline == null,
              onSelected: (_) => update(() => workDeadline = null)),
          for (final days in [1, 3, 7])
            ActionChip(
                label: Text('${fa(days)} روز'),
                onPressed: () => update(() =>
                    workDeadline = DateTime.now().add(Duration(days: days)))),
          ActionChip(
              label: const Text('تاریخ و ساعت'),
              onPressed: chooseRequestDeadline),
        ]),
        if (workDeadline != null) small('پایان: ${shortDate(workDeadline!)}'),
        small('این مهلت برای دریافت پیشنهاد است؛ زمان انجام کار را جدا بنویس.'),
        const SizedBox(height: 10),
      ]);
  Iterable<WorkChatRequest> requestConnections(WorkNeed n) =>
      workStore.chatRequests.values.where((c) =>
          c.requestId == n.id && (n.ownerId == actorId || c.fromId == actorId));
  Widget requestConnectionCard(WorkNeed n, WorkChatRequest c) => panel([
        Row(children: [
          Expanded(
              child: Text('درخواست گفتگو',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          label(connectionStatus(c.status), color: muted)
        ]),
        if (n.ownerId == actorId)
          TextButton.icon(
              onPressed: () => showWorkProfile(c.fromId),
              icon: const Icon(Icons.person_outline, size: 17),
              label: Text(workName(c.fromId))),
        small(shortDate(c.createdAt)),
        Text(c.details, style: const TextStyle(fontSize: 12)),
        if (c.status == 'pending' && n.ownerId == actorId)
          Row(children: [
            Expanded(
                child: button(
                    'اجازه گفتگو',
                    () => workAction(() => workStore.respondChatRequest(
                        c.id, actorId, 'accepted')))),
            const SizedBox(width: 8),
            Expanded(
                child: button(
                    'رد درخواست',
                    () => workAction(() => workStore.respondChatRequest(
                        c.id, actorId, 'declined')),
                    outlined: true)),
          ]),
        if (c.status == 'pending' && c.fromId == actorId)
          TextButton(
              onPressed: () => workAction(() =>
                  workStore.respondChatRequest(c.id, actorId, 'cancelled')),
              child: const Text('لغو درخواست گفتگو')),
        if (c.status == 'accepted')
          button(
              'باز کردن گفتگو', () => openCanonicalChat('${n.id}::${c.fromId}'),
              outlined: true),
      ]);
  Future<void> askRequestConversation(WorkNeed n) async {
    if (!canAct) {
      await ensureAccess(() => askRequestConversation(n));
      return;
    }
    final actor = actorId;
    final details = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => _RequestChatForm(title: n.title)));
    if (!mounted || details == null || actor != actorId) return;
    if (workAction(() => workStore.requestChat(n.id, actor, details)))
      notice('درخواست گفتگو ثبت شد؛ منتظر پذیرش صاحب درخواست باش.');
  }

  Future<void> selectRequestBid(WorkNeed n, WorkBid b) async {
    final actor = actorId;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('انتخاب برای هماهنگی؟'),
                content: Text(
                    '${workName(b.bidderId)} · ${money(b.amount)} / ${b.unit.label}\nگفتگو باز می‌شود؛ این انتخاب قرارداد یا تعهد اجرای کار نیست.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('تأیید'))
                ]));
    if (yes == true && mounted && actor == actorId)
      workAction(() => workStore.select(n.id, b.id, actor));
  }
}

class _RequestChatForm extends StatefulWidget {
  const _RequestChatForm({required this.title});
  final String title;
  @override
  State<_RequestChatForm> createState() => _RequestChatFormState();
}

class _RequestChatFormState extends State<_RequestChatForm> {
  final details = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('درخواست گفتگو')),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
              key: form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.title),
                    const SizedBox(height: 12),
                    const Text(
                        'برای طرح سؤال یا هماهنگی، شرح کوتاهی بنویس. گفتگو فقط پس از پذیرش صاحب درخواست باز می‌شود.',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: details,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            labelText: 'شرح درخواست گفتگو'),
                        validator: (v) => v?.trim().isNotEmpty == true
                            ? null
                            : 'شرح را بنویس.'),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate())
                            Navigator.pop(context, details.text.trim());
                        },
                        child: const Text('ارسال درخواست گفتگو')),
                  ]))));
}
