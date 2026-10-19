part of 'main.dart';

class ContractSetupPage extends StatefulWidget {
  const ContractSetupPage(
      {required this.profiles,
      required this.actor,
      required this.subject,
      this.peerId,
      this.parent});
  final List<UserProfile> profiles;
  final UserProfile actor;
  final String subject;
  final String? peerId;
  final ContractDraft? parent;
  @override
  State<ContractSetupPage> createState() => _ContractSetupPageState();
}

class _ContractSetupPageState extends State<ContractSetupPage> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.subject);
  late String template = widget.parent?.template ?? 'اجرای کار';
  late String? peer = widget.peerId;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.parent == null ? 'قرارداد جدید' : 'الحاقیه جدید')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text(widget.parent == null
                        ? 'بدون نیاز به آگهی یا درخواست هم می‌توانید قرارداد ببندید.'
                        : 'ارجاع به ${widget.parent!.title} · نسخه ${fa(widget.parent!.revisions.last.number)}'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: template,
                        decoration:
                            const InputDecoration(labelText: 'قالب قرارداد'),
                        items: ['اجرای کار', 'خدمات طراحی', 'توافق عمومی']
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: widget.parent == null
                            ? (v) => setState(() => template = v!)
                            : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: title,
                        decoration: InputDecoration(
                            labelText: widget.parent == null
                                ? 'موضوع قرارداد'
                                : 'موضوع تغییرات'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'موضوع را بنویس.'
                            : null),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: peer,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'طرف مقابل'),
                        items: widget.profiles
                            .where((p) => p.id != widget.actor.id)
                            .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} · ${p.specialty}',
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        validator: (v) =>
                            v == null ? 'طرف مقابل را انتخاب کن.' : null,
                        onChanged: widget.peerId == null
                            ? (v) => setState(() => peer = v)
                            : null),
                    const SizedBox(height: 14),
                    const Text(
                        'هر طرف اطلاعات خودش را وارد می‌کند. مدارک خصوصی‌اند و فقط برای طرفین همین قرارداد نمایش داده می‌شوند.',
                        style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('ساخت پیش‌نویس'),
                        onPressed: () {
                          if (!form.currentState!.validate()) return;
                          final other =
                              widget.profiles.firstWhere((p) => p.id == peer);
                          final parent = widget.parent;
                          final d = ContractDraft(
                              '${parent == null ? '' : 'الحاقیه: '}${title.text.trim()}',
                              {
                                'موضوع و محل': title.text.trim(),
                                'مبلغ (تومان)': '',
                                'زمان شروع و مدت': '',
                                'شیوه پرداخت': '',
                                'شرایط توافق': '',
                                'شرایط آماده قالب': parent == null
                                    ? preparedContractTerms(template)
                                    : 'این الحاقیه فقط بندهای صریحاً نوشته‌شده را تغییر می‌دهد؛ سایر شرایط قرارداد مرجع برقرار می‌ماند.',
                                'شرایط تکمیلی': '',
                                if (parent != null)
                                  'ارجاع':
                                      '${parent.id} · نسخه ${parent.revisions.last.number}'
                              },
                              template: template,
                              parentId: parent?.id);
                          for (final p in [widget.actor, other]) {
                            d.parties[p.id] = parent == null
                                ? {
                                    'نام': p.name,
                                    'شماره تماس': '',
                                    'شناسه هویتی': '',
                                    'نشانی': '',
                                    'خواسته‌ها و تعهدات من': ''
                                  }
                                : Map<String, String>.from(
                                    parent.parties[p.id]!);
                            if (parent != null)
                              d.partyDocuments[p.id] = [
                                ...?parent.partyDocuments[p.id]
                              ];
                          }
                          d.status = 'در انتظار تکمیل و تأیید طرفین';
                          Navigator.pop(context, d);
                        }),
                    const Text(
                        'در دمو طرف مقابل از اعضای نمونه انتخاب می‌شود. دعوت با شماره موبایل برای نسخه متصل به سرور است.',
                        style: TextStyle(fontSize: 11, color: muted)),
                  ])))));
}

class ContractEditor extends StatefulWidget {
  const ContractEditor(
      {super.key,
      required this.draft,
      required this.actor,
      required this.onChanged,
      required this.choosePhotos,
      required this.export,
      required this.addendum,
      required this.upgrade});
  final ContractDraft draft;
  final UserProfile actor;
  final VoidCallback onChanged, addendum, upgrade;
  final Future<List<Uint8List>> Function(int) choosePhotos;
  final Future<void> Function(ContractRevision) export;
  @override
  State<ContractEditor> createState() => _ContractEditorState();
}

class _ContractEditorState extends State<ContractEditor> {
  int tab = 0;
  bool consent = false, busy = false;
  late final signature = TextEditingController();
  ContractDraft get d => widget.draft;
  String get actor => widget.actor.id;
  bool get isParty => d.parties.containsKey(actor);
  @override
  void dispose() {
    signature.dispose();
    super.dispose();
  }

  void changed(VoidCallback fn) {
    setState(() {
      fn();
      d.invalidateApprovals();
      consent = false;
    });
    widget.onChanged();
  }

  Widget field(String key, Map<String, String> values,
          {bool readOnly = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              key: ValueKey('${d.id}:$actor:$tab:$key'),
              initialValue: values[key] ?? '',
              readOnly: readOnly,
              minLines: lines,
              maxLines: lines == 1 ? 3 : null,
              decoration: InputDecoration(
                  labelText: key,
                  hintText: key == 'زمان شروع و مدت'
                      ? 'مثلاً ۱۴۰۵/۰۷/۲۰ · ده روز کاری'
                      : key == 'مبلغ (تومان)'
                          ? 'مبلغ کل و مبنای محاسبه'
                          : key == 'شیوه پرداخت'
                              ? 'پیش‌پرداخت، اقساط و تسویه'
                              : null,
                  alignLabelWithHint: true,
                  isDense: true),
              onChanged:
                  readOnly ? null : (v) => changed(() => values[key] = v)));
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    if (!d.bilateral)
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text(
            'پیش‌نویس قدیمی؛ برای تأیید دوطرفه طرف مقابل را انتخاب و اطلاعات را تکمیل کنید.'),
        ...d.values.entries
            .map((e) => ListTile(title: Text(e.key), subtitle: Text(e.value))),
        FilledButton(
            onPressed: widget.upgrade,
            child: const Text('ساخت قرارداد دوطرفه از این موضوع')),
        ...d.revisions.map((v) => TextButton(
            onPressed: () => widget.export(v),
            child: Text('PDF نسخه قبلی ${fa(v.number)}')))
      ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(d.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      Text('${d.template} · ${d.status}',
          style: const TextStyle(fontSize: 11, color: muted)),
      const SizedBox(height: 8),
      Wrap(
          spacing: 6,
          children: d.parties.entries
              .map((e) => Chip(
                  avatar: Icon(
                      d.signatures.containsKey(e.key)
                          ? Icons.check_circle_outline
                          : Icons.person_outline,
                      size: 17,
                      color: d.signatures.containsKey(e.key)
                          ? Colors.green
                          : muted),
                  label: Text(
                      '${e.value['نام']} ${e.key == actor ? '(من)' : ''}',
                      style: const TextStyle(fontSize: 11))))
              .toList()),
      const SizedBox(height: 8),
      Row(children: [
        for (final t in [(0, 'طرفین'), (1, 'متن قرارداد'), (2, 'تأیید و امضا')])
          Expanded(
              child: TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor:
                          tab == t.$1 ? const Color(0xFFFFEEEE) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 4)),
                  onPressed: () => setState(() => tab = t.$1),
                  child: Text(t.$2, style: const TextStyle(fontSize: 12))))
      ]),
      const SizedBox(height: 14),
      if (tab == 0) ...[
        const Text(
            'مشخصات خودت را تکمیل کن؛ طرف مقابل از حساب خودش اطلاعاتش را وارد می‌کند.',
            style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        for (final entry in d.parties.entries)
          ExpansionTile(
              key: ValueKey('party:${entry.key}'),
              initiallyExpanded: entry.key == actor,
              tilePadding: EdgeInsets.zero,
              title: Text(
                  '${entry.value['نام']} ${entry.key == actor ? '· اطلاعات من' : '· فقط مشاهده'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              children: [
                for (final key in [
                  'نام',
                  'شماره تماس',
                  'شناسه هویتی',
                  'نشانی',
                  'خواسته‌ها و تعهدات من'
                ])
                  field(key, entry.value,
                      readOnly: entry.key != actor,
                      lines: key == 'خواسته‌ها و تعهدات من' ? 2 : 1),
                const Text('تصاویر مدارک · خصوصی برای طرفین این قرارداد',
                    style: TextStyle(fontSize: 11, color: muted)),
                Wrap(
                    spacing: 6,
                    children: (d.partyDocuments[entry.key] ?? <Uint8List>[])
                        .asMap()
                        .entries
                        .map((doc) => SizedBox(
                            width: 82,
                            height: 95,
                            child: Stack(children: [
                              Positioned.fill(
                                  child: InkWell(
                                      onTap: () => showDialog<void>(
                                          context: context,
                                          builder: (ctx) => Dialog(
                                                  child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                    Flexible(
                                                        child: InteractiveViewer(
                                                            child: Image.memory(
                                                                doc.value))),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child:
                                                            const Text('بستن'))
                                                  ]))),
                                      child: Image.memory(doc.value,
                                          fit: BoxFit.cover))),
                              if (entry.key == actor)
                                Positioned(
                                    top: 0,
                                    left: 0,
                                    child: IconButton.filled(
                                        tooltip: 'حذف مدرک',
                                        visualDensity: VisualDensity.compact,
                                        iconSize: 15,
                                        onPressed: () => changed(() => d
                                            .partyDocuments[actor]!
                                            .removeAt(doc.key)),
                                        icon: const Icon(Icons.close)))
                            ])))
                        .toList()),
                if (entry.key == actor)
                  TextButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              final count =
                                  d.partyDocuments[actor]?.length ?? 0;
                              if (count >= 6) {
                                message('حداکثر شش تصویر برای هر طرف.');
                                return;
                              }
                              setState(() => busy = true);
                              try {
                                final photos =
                                    await widget.choosePhotos(6 - count);
                                if (mounted && photos.isNotEmpty)
                                  changed(() => d.partyDocuments
                                      .putIfAbsent(actor, () => [])
                                      .addAll(photos));
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('افزودن تصویر مدرک')),
              ]),
      ],
      if (tab == 1) ...[
        const Text(
            'شرایط نمونه را بخوانید و متناسب با توافق اصلاح کنید. هر تغییر، امضا و تأیید قبلی هر دو طرف را پاک می‌کند.',
            style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 12),
        for (final key in [
          'موضوع و محل',
          'مبلغ (تومان)',
          'زمان شروع و مدت',
          'شیوه پرداخت',
          'شرایط توافق',
          'شرایط آماده قالب',
          'شرایط تکمیلی'
        ])
          field(key, d.values,
              readOnly: !isParty, lines: key == 'شرایط آماده قالب' ? 8 : 2),
        if (d.parentId != null) Text('مرجع: ${d.values['ارجاع']}'),
      ],
      if (tab == 2) ...[
        const Text('متن تجمیع‌شده برای بررسی',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final p in d.parties.values)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(p.entries
                  .map((e) =>
                      '${e.key}: ${e.value.isEmpty ? 'تکمیل نشده' : e.value}')
                  .join('\n'))),
        for (final e in d.values.entries.where((e) => ![
              'طرفین',
              'تأیید و امضای طرفین',
              'فهرست مدارک طرفین'
            ].contains(e.key)))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                  '${e.key}\n${e.value.isEmpty ? 'تکمیل نشده' : e.value}')),
        Text(
            'پیوست‌ها: ${fa(d.partyDocuments.values.fold<int>(0, (n, p) => n + p.length))} تصویر مدارک طرفین',
            style: const TextStyle(fontSize: 11)),
        const Divider(),
        if (d.signatures.containsKey(actor))
          Text('تأیید شما ثبت شد: ${d.signatures[actor]}',
              style: const TextStyle(color: Colors.green))
        else if (isParty) ...[
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consent,
              onChanged: (v) => setState(() => consent = v ?? false),
              title: const Text(
                  'متن، اطلاعات و مدارک هر دو طرف را بررسی و تأیید کردم.',
                  style: TextStyle(fontSize: 12))),
          TextField(
              controller: signature,
              decoration: const InputDecoration(
                  labelText: 'برای امضا نام کامل خودت را بنویس',
                  isDense: true)),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: !consent
                  ? null
                  : () {
                      if (d.signingError != null) {
                        message(d.signingError!);
                        return;
                      }
                      if (signature.text.trim() !=
                          d.parties[actor]!['نام']!.trim()) {
                        message('نام امضا باید با نام مشخصات خودت برابر باشد.');
                        return;
                      }
                      setState(() {
                        d.signatures[actor] =
                            '${signature.text.trim()} · ${jalaliDate(DateTime.now(), withTime: true)}';
                        d.status = d.signatures.length == 2
                            ? 'تأیید هر دو طرف ثبت شد'
                            : 'در انتظار تأیید طرف مقابل';
                      });
                      widget.onChanged();
                    },
              icon: const Icon(Icons.draw_outlined),
              label: const Text('ثبت تأیید و امضای من')),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: d.signatures.length != 2
                ? null
                : () async {
                    try {
                      final v = d.finalize();
                      widget.onChanged();
                      setState(() {});
                      await widget.export(v);
                    } on FormatException catch (e) {
                      message(e.message);
                    }
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('ثبت نسخه نهایی و دریافت PDF')),
        if (d.signatures.length != 2)
          const Text(
              'PDF نهایی پس از تکمیل اطلاعات و تأیید هر دو طرف فعال می‌شود.',
              style: TextStyle(fontSize: 11, color: muted)),
      ],
      if (d.revisions.isNotEmpty) ...[
        const Divider(),
        const Text('نسخه‌های ثبت‌شده · تغییرناپذیر',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...d.revisions.reversed.map((v) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('نسخه ${fa(v.number)}'),
            subtitle: Text(jalaliDate(v.createdAt, withTime: true)),
            trailing: const Icon(Icons.picture_as_pdf_outlined),
            onTap: () => widget.export(v))),
        if (isParty)
          OutlinedButton.icon(
              onPressed: widget.addendum,
              icon: const Icon(Icons.add),
              label: const Text('تنظیم الحاقیه')),
      ],
      const SizedBox(height: 12),
      const Text(
          'پیش‌نویس هنگام ویرایش روی همین دستگاه ذخیره می‌شود. امضای تایپی این دمو احراز نشده است؛ قالب‌ها پیش از انتشار واقعی باید بازبینی شوند.',
          style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }
}
