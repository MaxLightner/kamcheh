part of 'main.dart';

extension MessageDetailsUi on _AppShellState {
  String inboxMessagePreview(WorkConversation c) {
    final query = normalizeMarketText(inboxQuery);
    final matches = query.isEmpty
        ? c.messages
        : c.messages.where((m) =>
            normalizeMarketText('${m.text} ${m.fileName ?? ''}')
                .contains(query));
    final m = matches.lastOrNull ?? c.messages.lastOrNull;
    return m?.fileName ?? m?.text ?? 'برای هماهنگی پیام بده';
  }

  int get unreadMessages => !signedIn
      ? 0
      : workStore.conversations.values
          .where((c) => c.contains(actorId))
          .fold(0, (sum, c) => sum + c.unread(actorId));
  Widget messageNavigationIcon(bool selected) => Semantics(
      label: unreadMessages == 0
          ? 'پیام‌ها'
          : '${fa(unreadMessages)} پیام خوانده‌نشده',
      child: Badge(
          isLabelVisible: unreadMessages > 0,
          label: Text(unreadMessages > 99 ? '۹۹+' : fa(unreadMessages)),
          child: Icon(
              selected ? Icons.chat_bubble : Icons.chat_bubble_outline_rounded,
              color: selected ? red : null)));
  void scrollToLastMessage() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            page == 'chat' &&
            chatScroll.hasClients &&
            chatSearch.isEmpty)
          chatScroll.jumpTo(chatScroll.position.maxScrollExtent);
      });
  List<Widget> messageVisits() {
    final now = DateTime.now();
    bool past(WorkVisit v) =>
        !v.at.isAfter(now) || ['declined', 'cancelled'].contains(v.status);
    final visits = workStore.visits.values
        .where((v) =>
            v.bidderId == actorId ||
            workStore.contextInfo(v.contextId, v.contextType).ownerId ==
                actorId)
        .where((v) => visitMessageTab == 0 ? !past(v) : past(v))
        .toList()
      ..sort((a, b) =>
          visitMessageTab == 0 ? a.at.compareTo(b.at) : b.at.compareTo(a.at));
    return [
      miniTabs(['پیش رو', 'گذشته و لغوشده'], visitMessageTab,
          (i) => update(() => visitMessageTab = i)),
      const SizedBox(height: 8),
      ...visits.map((v) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextButton(
                onPressed: () => openAd(v.contextType == 'service'
                    ? serviceAd(workStore.service(v.contextId))
                    : workAd(workStore.need(v.contextId))),
                child: Text(
                    'مشاهده ${v.contextType == 'service' ? 'آگهی' : 'درخواست'} مرتبط')),
            workVisitCard(v),
          ])),
      if (visits.isEmpty)
        emptyState(
            visitMessageTab == 0
                ? 'بازدید پیش رو نداری'
                : 'بازدید گذشته‌ای نداری',
            'قرارها از آگهی، درخواست یا گفتگوی مرتبط ثبت می‌شوند.'),
    ];
  }

  Future<String?> previewAttachment(
      String name, String mime, Uint8List bytes) async {
    final caption = TextEditingController();
    final result = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (ctx) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('پیش‌نمایش پیوست',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(
                      '${fa((bytes.length / 1024).ceil())} کیلوبایت · حداکثر ۱۰ مگابایت',
                      style: const TextStyle(fontSize: 11, color: muted)),
                  if (mime.startsWith('image/'))
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Image.memory(bytes,
                            height: 170,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('تصویر قابل نمایش نیست.'))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: caption,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'توضیح پیوست (اختیاری)')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, caption.text.trim()),
                            child: const Text('ارسال پیوست'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('انصراف')))
                  ]),
                ])));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    caption.dispose();
    return result;
  }
}
