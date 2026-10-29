import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../persian_calendar.dart';
import '../squaring_tool.dart';
import '../estimate.dart';
import '../digital_meter.dart';
import '../contract_document.dart';
import '../file_delivery.dart';
import 'backend.dart';
import 'public_cache.dart';

const _red = Color(0xFFAF282B);
const cloudRules =
    'هر شماره یک حساب دارد. اطلاعات عمومی پروفایل و آگهی برای دیگران قابل مشاهده است. نشانی دقیق، مدارک قرارداد و حسابداری عمومی نیستند. ارتباط با صاحب درخواست پس از پذیرش او باز می‌شود. توافق اجرا و پرداخت با طرفین است. امضای تایپی به معنی احراز رسمی هویت نیست. محتوای خلاف واقع و انتشار مدارک دیگران مجاز نیست.';

Future<Map<String, String>?> backendForm(
        BuildContext context, String title, List<String> fields,
        {Map<String, String> initial = const {},
        Map<String, List<String>> choices = const {}}) =>
    Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
        builder: (_) => _BackendForm(
            title: title, fields: fields, initial: initial, choices: choices)));

class _BackendForm extends StatefulWidget {
  const _BackendForm(
      {required this.title,
      required this.fields,
      required this.initial,
      required this.choices});
  final String title;
  final List<String> fields;
  final Map<String, String> initial;
  final Map<String, List<String>> choices;
  @override
  State<_BackendForm> createState() => _BackendFormState();
}

class _BackendFormState extends State<_BackendForm> {
  late final controls = {
    for (final f in widget.fields)
      f: TextEditingController(text: widget.initial[f] ?? '')
  };
  @override
  void dispose() {
    for (final c in controls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                for (final f in widget.fields)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: widget.choices.containsKey(f)
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  widget.choices[f]!.contains(controls[f]!.text)
                                      ? controls[f]!.text
                                      : widget.choices[f]!.first,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: f),
                              items: widget.choices[f]!
                                  .map((v) => DropdownMenuItem(
                                      value: v, child: Text(v)))
                                  .toList(),
                              onChanged: (v) => controls[f]!.text = v ?? '')
                          : TextField(
                              controller: controls[f],
                              minLines: 1,
                              maxLines: f.contains('شرایط') || f.contains('شرح')
                                  ? 8
                                  : 3,
                              decoration: InputDecoration(
                                  labelText: f, alignLabelWithHint: true))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, {
                          for (final e in controls.entries)
                            e.key: e.value.text.trim().isEmpty &&
                                    widget.choices.containsKey(e.key)
                                ? widget.choices[e.key]!.first
                                : e.value.text.trim()
                        }),
                    child: const Text('ذخیره')),
              ]))));
}

class CloudAppShell extends StatefulWidget {
  const CloudAppShell({super.key});
  @override
  State<CloudAppShell> createState() => _CloudAppShellState();
}

class _CloudAppShellState extends State<CloudAppShell> {
  late final backend = KamchehBackend(Supabase.instance.client);
  SupabaseClient get db => backend.db;
  int tab = 0;
  bool busy = false, loading = true;
  final cache = PublicMarketplaceCache();
  String query = '', error = '';
  List<BackendRow> services = [],
      needs = [],
      people = [],
      connections = [],
      threads = [];
  Timer? timer;
  String? _knownActor;
  @override
  void initState() {
    super.initState();
    _knownActor = backend.actor;
    backend.addListener(_authChanged);
    reload();
    timer =
        Timer.periodic(const Duration(seconds: 30), (_) => reload(quiet: true));
  }

  void _authChanged() {
    if (!mounted) return;
    final changed = _knownActor != backend.actor;
    if (changed && _knownActor != null)
      Navigator.of(context).popUntil((route) => route.isFirst);
    _knownActor = backend.actor;
    setState(() {
      if (changed) {
        connections = [];
        threads = [];
        services = [];
        needs = [];
        people = [];
      }
    });
    reload(quiet: true);
  }

  @override
  void dispose() {
    timer?.cancel();
    backend.removeListener(_authChanged);
    backend.dispose();
    super.dispose();
  }

  void notify(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      notify(e is FormatException
          ? e.message
          : e is AuthException
              ? e.message
              : 'عملیات انجام نشد؛ اتصال و دسترسی حساب را بررسی کن.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload({bool quiet = false}) async {
    if (!mounted) return;
    final requestActor = backend.actor;
    if (!quiet) {
      setState(() => loading = true);
      final saved = await cache.read();
      if (saved != null && mounted && services.isEmpty)
        setState(() {
          services = List<BackendRow>.from((saved['services'] as List)
              .map((r) => Map<String, dynamic>.from(r)));
          needs = List<BackendRow>.from((saved['needs'] as List)
                  .map((r) => Map<String, dynamic>.from(r)))
              .where((r) =>
                  r['deadline'] == null ||
                  DateTime.parse(r['deadline']).isAfter(DateTime.now()))
              .toList();
          people = List<BackendRow>.from((saved['people'] as List)
              .map((r) => Map<String, dynamic>.from(r)));
        });
    }
    try {
      final results = await Future.wait([
        backend.market(false),
        backend.market(true),
        backend.profiles(),
        backend.contacts(),
        backend.threads()
      ]);
      if (requestActor != backend.actor) return;
      await backend.myProfile();
      if (requestActor != backend.actor) return;
      if (!backend.loggedIn) {
        try {
          await cache.write(results[0], results[1], results[2]);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        services = results[0];
        needs = results[1];
        people = results[2];
        connections = results[3];
        threads = results[4];
        error = '';
      });
    } catch (_) {
      if (mounted)
        setState(
            () => error = 'دریافت اطلاعات از سرور انجام نشد. دوباره تلاش کن.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String name(String? id) {
    final person = people.where((p) => p['id'] == id).firstOrNull;
    if (person != null) return person['display_name']?.toString() ?? 'عضو کمچه';
    if (id == backend.actor)
      return backend.profile?['display_name']?.toString() ?? 'حساب من';
    return 'عضو کمچه';
  }

  Future<bool> login() async {
    if (backend.loggedIn) return true;
    await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _BackendLogin(backend: backend)));
    if (mounted) await reload();
    return backend.loggedIn;
  }

  Future<void> editProfile() async {
    if (!await login() || !mounted) return;
    final p = await backend.myProfile();
    if (!mounted) return;
    final v = await backendForm(context, 'پروفایل من', [
      'نام',
      'شهر',
      'تخصص',
      'معرفی',
      'مهارت‌ها'
    ], initial: {
      'نام': p?['display_name'] ?? '',
      'شهر': p?['city'] ?? '',
      'تخصص': p?['specialty'] ?? '',
      'معرفی': p?['bio'] ?? '',
      'مهارت‌ها': (p?['skills'] as List? ?? []).join('، ')
    });
    if (v == null) return;
    await run(() async {
      if (['نام', 'شهر', 'تخصص'].any((k) => v[k]!.length < 2))
        throw const FormatException('نام، شهر و تخصص را تکمیل کن.');
      await backend.saveProfile({
        'display_name': v['نام'],
        'city': v['شهر'],
        'specialty': v['تخصص'],
        'bio': v['معرفی'],
        'skills': v['مهارت‌ها']!
            .split(RegExp('[،,]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'is_complete': true
      });
      await reload();
    });
  }

  Future<void> createListing() async {
    if (!await login() || !mounted) return;
    if (backend.profile?['is_complete'] != true) {
      await editProfile();
      if (backend.profile?['is_complete'] != true) return;
    }
    if (!mounted) return;
    final need = tab == 2;
    final values =
        await backendForm(context, need ? 'ثبت درخواست' : 'ثبت آگهی', [
      'عنوان',
      'شرح',
      'شهر',
      'محله',
      'تخصص',
      'مبلغ (تومان)'
    ], choices: const {
      'شهر': ['مشهد', 'طرقبه', 'شاندیز', 'گلبهار', 'چناران']
    });
    if (values == null) return;
    DateTime? deadline;
    if (need && mounted) {
      final timed = await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: const Text('مهلت دریافت پیشنهاد'), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('بدون مهلت')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('انتخاب تاریخ'))
              ]));
      if (timed == true && mounted) {
        final now = DateTime.now();
        final d = await pickPersianDate(context,
            initialDate: now,
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)));
        if (d == null) return;
        deadline = DateTime(d.year, d.month, d.day, 23, 59, 59);
      }
    }
    await run(() async {
      await backend.post(need, {
        'title': values['عنوان'],
        'details': values['شرح'],
        'city': values['شهر'],
        'district': values['محله'],
        'category': values['تخصص']!.isEmpty ? 'خدمات' : values['تخصص'],
        need ? 'budget' : 'amount': backendAmount(values['مبلغ (تومان)']!),
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String()
      });
      await reload();
      notify('در سرور ثبت شد.');
    });
  }

  Future<void> showListing(BackendRow row, bool need) async {
    final owner = row['owner'] as Map?;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (ctx) => Scaffold(
            appBar: AppBar(title: Text(row['title'])),
            body: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      Text(row['details'], style: const TextStyle(height: 1.9)),
                      const SizedBox(height: 12),
                      Text('${row['city']} · ${row['district']}'),
                      if (owner != null)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline),
                            title: Text(owner['display_name'] ?? ''),
                            subtitle: Text(owner['specialty'] ?? ''),
                            onTap: () =>
                                showPerson(Map<String, dynamic>.from(owner))),
                      if (row['deadline'] != null)
                        Text(
                            'مهلت: ${jalaliDate(DateTime.parse(row['deadline']))}'),
                      if (row['owner_id'] != backend.actor) ...[
                        FilledButton(
                            onPressed: () => connect(row, need, 'conversation'),
                            child: const Text('درخواست گفتگو')),
                        OutlinedButton(
                            onPressed: () => connect(row, need, 'visit'),
                            child: const Text('درخواست بازدید')),
                        if (need)
                          OutlinedButton(
                              onPressed: () => offer(row),
                              child: const Text('ارائه پیشنهاد قیمت')),
                        if (!need)
                          OutlinedButton(
                              onPressed: () => connect(row, false, 'quote'),
                              child: const Text('درخواست پیش‌فاکتور')),
                        const Text(
                            'گفتگو پس از پذیرش صاحب آگهی یا درخواست باز می‌شود.',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ] else ...[
                        OutlinedButton(
                            onPressed: () => run(() async {
                                  await db
                                      .from(need
                                          ? 'work_needs'
                                          : 'service_listings')
                                      .update({'archived': true}).eq(
                                          'id', row['id']);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await reload();
                                }),
                            child: const Text('بایگانی')),
                        if (need)
                          OutlinedButton(
                              onPressed: () => showOffers(row),
                              child: const Text('مشاهده پیشنهادها')),
                      ],
                    ]))))));
  }

  Future<void> connect(BackendRow row, bool need, String kind) async {
    if (!await login() || !mounted) return;
    final v = await backendForm(context, 'درخواست ارتباط', ['شرح درخواست']);
    if (v == null) return;
    DateTime? at;
    if (kind == 'visit' && mounted) {
      final now = DateTime.now();
      final date = await pickPersianDate(context,
          initialDate: now,
          firstDate: now,
          lastDate: now.add(const Duration(days: 180)));
      if (date == null || !mounted) return;
      final t =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t == null) return;
      at = DateTime(date.year, date.month, date.day, t.hour, t.minute);
      if (!at.isAfter(DateTime.now())) {
        notify('زمان بازدید باید در آینده باشد.');
        return;
      }
    }
    await run(() async {
      await backend.contact(row, need, kind, v['شرح درخواست']!, at: at);
      await reload();
      notify('برای بررسی صاحب درخواست ارسال شد.');
    });
  }

  Future<void> offer(BackendRow row) async {
    if (!await login() || !mounted) return;
    final v = await backendForm(context, 'پیشنهاد قیمت', [
      'مبلغ (تومان)',
      'واحد',
      'شرایط'
    ], choices: const {
      'واحد': ['project', 'square_meter', 'daily', 'hourly', 'item']
    });
    if (v == null) return;
    await run(() async {
      await backend.bid(
          row['id'],
          backendAmount(v['مبلغ (تومان)']!, optional: false)!,
          v['واحد']!,
          v['شرایط']!);
      notify('پیشنهاد در سرور ثبت شد.');
    });
  }

  Future<void> showOffers(BackendRow row) async {
    final result = await db
        .from('work_bids')
        .select()
        .eq('need_id', row['id'])
        .order('amount');
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (ctx) => Scaffold(
            appBar: AppBar(title: const Text('پیشنهادها')),
            body: ListView(children: [
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('قیمت‌های دارای واحد یکسان را با هم مقایسه کن.')),
              for (final bid in result)
                ListTile(
                    title: Text(
                        '${name(bid['bidder_id'])} · ${bid['amount']} تومان / ${bid['unit']}'),
                    subtitle: Text(bid['terms']),
                    trailing: TextButton(
                        onPressed: () => run(() async {
                              await db.rpc('decide_bid', params: {
                                'bid': bid['id'],
                                'decision': 'shortlisted'
                              });
                              await reload();
                              notify('گفتگو برای هماهنگی باز شد.');
                            }),
                        child: const Text('هماهنگی'))),
            ]))));
  }

  Future<void> showPerson(BackendRow p) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: Text(p['display_name'] ?? 'پروفایل')),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const CircleAvatar(
                  radius: 44, child: Icon(Icons.person_outline, size: 44)),
              const SizedBox(height: 12),
              Text(p['specialty'] ?? ''),
              Text(p['city'] ?? ''),
              Text(p['bio'] ?? ''),
              Wrap(
                  spacing: 6,
                  children: (p['skills'] as List? ?? [])
                      .map((s) => Chip(label: Text('$s')))
                      .toList()),
              ...services.where((s) => s['owner_id'] == p['id']).map((s) =>
                  ListTile(
                      title: Text(s['title']),
                      onTap: () => showListing(s, false))),
            ]))));
  }

  Future<void> openThread(BackendRow thread) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => BackendThread(
            backend: backend,
            thread: thread,
            peerName: name(thread['participant_a'] == backend.actor
                ? thread['participant_b']
                : thread['participant_a']))));
  }

  List<Widget> inbox() => !backend.loggedIn
      ? [
          FilledButton(
              onPressed: login, child: const Text('ورود برای مشاهده پیام‌ها'))
        ]
      : [
          const Text('ارتباط‌های در انتظار',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...connections.where((c) => c['status'] == 'pending').map((c) => Card(
              child: ListTile(
                  title: Text(name(c['sender_id'])),
                  subtitle: Text('${c['kind']} · ${c['message']}'),
                  trailing: c['recipient_id'] == backend.actor
                      ? Wrap(children: [
                          IconButton(
                              tooltip: 'پذیرش',
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        await db.rpc('decide_contact', params: {
                                          'contact': c['id'],
                                          'decision': 'accepted'
                                        });
                                        await reload();
                                      }),
                              icon: const Icon(Icons.check)),
                          IconButton(
                              tooltip: 'رد',
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        await db.rpc('decide_contact', params: {
                                          'contact': c['id'],
                                          'decision': 'declined'
                                        });
                                        await reload();
                                      }),
                              icon: const Icon(Icons.close))
                        ])
                      : TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                    await db.rpc('decide_contact', params: {
                                      'contact': c['id'],
                                      'decision': 'cancelled'
                                    });
                                    await reload();
                                  }),
                          child: const Text('لغو'))))),
          const SizedBox(height: 12),
          const Text('گفتگوها', style: TextStyle(fontWeight: FontWeight.bold)),
          if (threads.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('هنوز گفتگویی باز نشده است.')),
          ...threads.map((t) => ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(name(t['participant_a'] == backend.actor
                  ? t['participant_b']
                  : t['participant_a'])),
              onTap: () => openThread(t))),
        ];
  void openPublicTool(String title, Widget tool) {
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(12), child: tool))));
  }

  Future<void> openCloudContracts() async {
    if (!await login() || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => BackendContracts(backend: backend)));
  }

  Future<void> openCloudAccounting() async {
    if (!await login() || !mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => BackendAccounting(backend: backend)));
  }

  Widget cloudTool(IconData icon, String title, String description,
      VoidCallback onTap) =>
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE9EAED))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 26, color: _red),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      );

  List<Widget> account() => [
        const Text('ابزارهای کمچه',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('ابزارهای عمومی بدون ورود فعال هستند.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),
        const Text('اندازه‌گیری و محاسبه',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              cloudTool(Icons.square_foot_outlined, 'گونیا', 'محاسبه اضلاع',
                  () => openPublicTool('گونیا سازی', const SquaringTool())),
              cloudTool(Icons.straighten_outlined, 'متر دیجیتال',
                  'اندازه‌گیری با دوربین AR',
                  () => launchDigitalMeter(context)),
              cloudTool(Icons.calculate_outlined, 'ماشین‌حساب',
                  'متره و برآورد مصالح',
                  () => openPublicTool('برآورد مصالح', const MaterialEstimator())),
            ]),
        const SizedBox(height: 16),
        const Text('مدیریت پروژه',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              cloudTool(Icons.account_balance_wallet_outlined, 'حسابداری',
                  'دفتر کل و هزینه‌ها', openCloudAccounting),
              cloudTool(Icons.description_outlined, 'قراردادها',
                  'تنظیم و آرشیو قرارداد', openCloudContracts),
              cloudTool(Icons.campaign_outlined, 'آگهی‌های من',
                  'آگهی‌ها و درخواست‌های ثبت‌شده',
                  () async {
                    if (await login() && mounted) await showMine();
                  }),
            ]),
      ];

  List<Widget> profileEntry() {
    if (!backend.loggedIn) {
      return [
        Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: const Color(0xFFFFF7F6),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('پروفایل من',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('برای ساخت و مدیریت پروفایل خود وارد شو.'),
                      FilledButton(
                          onPressed: login,
                          child: const Text('ورود / ثبت‌نام')),
                    ]))),
      ];
    }
    return [
      Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFFFFF7F6),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const CircleAvatar(
                          child: Icon(Icons.person_outline)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(backend.profile?['display_name'] ?? 'پروفایل من',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(backend.profile?['specialty'] ?? 'تخصص ثبت نشده',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ]))
                    ]),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 3, children: [
                      TextButton.icon(
                          onPressed: editProfile,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('ویرایش پروفایل')),
                      TextButton.icon(
                          onPressed: () {
                            final p = people.where(
                                (p) => p['id'] == backend.actor).firstOrNull;
                            if (p != null) {
                              showPerson(p);
                            } else if (backend.profile != null) {
                              showPerson(Map<String, dynamic>.from(
                                  backend.profile!));
                            }
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('نمایش پروفایل')),
                    ]),
                  ]))),
    ];
  }

  Future<void> logoutCloud() => run(() async {
        await backend.logout();
        connections = [];
        threads = [];
        await reload();
      });

  Widget headerAccount() {
    if (!backend.loggedIn) {
      return TextButton(
        onPressed: login,
        child: const Text('ورود / ثبت‌نام',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'حساب کاربری',
      onSelected: (value) {
        if (value == 'profile') setState(() => tab = 1);
        if (value == 'edit') editProfile();
        if (value == 'logout') logoutCloud();
        if (value == 'rules') {
          showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                  title: const Text('قوانین کمچه'),
                  content: const SingleChildScrollView(
                      child: Text(cloudRules)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('بستن'))
                  ]));
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'profile', child: Text('پروفایل من')),
        PopupMenuItem(value: 'edit', child: Text('تنظیمات پروفایل')),
        PopupMenuItem(value: 'rules', child: Text('قوانین کمچه')),
        PopupMenuItem(value: 'logout', child: Text('خروج')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_circle_outlined, size: 20),
          const SizedBox(width: 4),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(backend.profile?['display_name'] ?? 'حساب من',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold))),
          const Icon(Icons.arrow_drop_down, size: 16),
        ]),
      ),
    );
  }

  Future<void> showMine() async {
    final s = await backend.mine('service_listings'),
        n = await backend.mine('work_needs');
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('آگهی‌ها و درخواست‌های من')),
            body: ListView(children: [
              ...s.map((r) => ListTile(
                  title: Text(r['title']),
                  subtitle: Text(r['archived'] ? 'بایگانی' : 'آگهی خدمات'),
                  onTap: () => showListing(r, false))),
              ...n.map((r) => ListTile(
                  title: Text(r['title']),
                  subtitle: Text(r['archived'] ? 'بایگانی' : 'درخواست کار'),
                  onTap: () => showListing(r, true))),
            ]))));
  }

  @override
  Widget build(BuildContext context) {
    final list = (tab == 0 ? services : needs)
        .where((r) =>
            query.isEmpty ||
            '${r['title']} ${r['details']} ${r['city']}'.contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
          title: Text([
            'آگهی‌ها',
            'پروفایل‌ها',
            'درخواست‌ها',
            'پیام‌ها',
            'ابزارها'
          ][tab]),
          actions: [
            IconButton(
                tooltip: 'به‌روزرسانی',
                onPressed: busy ? null : reload,
                icon: const Icon(Icons.refresh)),
            headerAccount(),
          ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: RefreshIndicator(
                  onRefresh: reload,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    if (loading || busy) const LinearProgressIndicator(),
                    if (error.isNotEmpty)
                      Text(error, style: const TextStyle(color: Colors.red)),
                    if (tab == 0 || tab == 2) ...[
                      TextField(
                          onChanged: (v) => setState(() => query = v.trim()),
                          decoration: const InputDecoration(
                              hintText: 'جست‌وجو',
                              prefixIcon: Icon(Icons.search))),
                      const SizedBox(height: 10),
                      if (list.isEmpty && !loading)
                        const Padding(
                            padding: EdgeInsets.all(30),
                            child: Text('هنوز موردی ثبت نشده است.',
                                textAlign: TextAlign.center)),
                      ...list.map((r) => Card(
                          color: Colors.white,
                          child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(r['title'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${r['details']}\n${r['city']} · ${r['category']}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () => showListing(r, tab == 2)))),
                    ],
                    if (tab == 1) ...[
                      ...profileEntry(),
                      if (people.isEmpty && !loading)
                        const Padding(
                            padding: EdgeInsets.all(30),
                            child: Text('هنوز پروفایلی ثبت نشده است.')),
                      GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: .95,
                          children: people
                              .map((p) => Card(
                                  child: InkWell(
                                      onTap: () => showPerson(p),
                                      child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(children: [
                                            const CircleAvatar(
                                                radius: 28,
                                                child:
                                                    Icon(Icons.person_outline)),
                                            const SizedBox(height: 10),
                                            Text(p['display_name'],
                                                maxLines: 1),
                                            Text(
                                                '${p['specialty']}\n${p['city']}',
                                                maxLines: 3,
                                                style: const TextStyle(
                                                    fontSize: 12))
                                          ])))))
                              .toList())
                    ],
                    if (tab == 3) ...inbox(),
                    if (tab == 4) ...account(),
                  ])))),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (tab == 0 || tab == 2)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.icon(
                  onPressed: busy ? null : createListing,
                  icon: const Icon(Icons.add),
                  label: Text(tab == 0 ? 'ثبت آگهی' : 'ثبت درخواست'))),
        NavigationBar(
            height: 60,
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() {
                  tab = i;
                  query = '';
                }),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.campaign_outlined), label: 'آگهی‌ها'),
              NavigationDestination(
                  icon: Icon(Icons.people_outline), label: 'پروفایل‌ها'),
              NavigationDestination(
                  icon: Icon(Icons.playlist_add_check), label: 'درخواست‌ها'),
              NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline), label: 'پیام‌ها'),
              NavigationDestination(
                  icon: Icon(Icons.handyman_outlined), label: 'ابزارها')
            ])
      ]),
    );
  }
}

class _BackendLogin extends StatefulWidget {
  const _BackendLogin({required this.backend});
  final KamchehBackend backend;
  @override
  State<_BackendLogin> createState() => _BackendLoginState();
}

class _BackendLoginState extends State<_BackendLogin> {
  final phone = TextEditingController(), code = TextEditingController();
  bool sent = false, busy = false, accepted = false;
  String error = '';
  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('ورود به کمچه')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                TextField(
                    controller: phone,
                    enabled: !sent,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'شماره موبایل')),
                if (!sent) ...[
                  const SizedBox(height: 12),
                  const Text(cloudRules,
                      style: TextStyle(fontSize: 12, height: 1.8)),
                  CheckboxListTile(
                      value: accepted,
                      onChanged: (v) => setState(() => accepted = v ?? false),
                      title: const Text('قوانین را خواندم و می‌پذیرم.'))
                ],
                if (sent)
                  TextField(
                      controller: code,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'کد پیامکی')),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: busy || !accepted
                        ? null
                        : () async {
                            final p = backendPhone(phone.text);
                            if (p == null) {
                              setState(() => error = 'شماره معتبر وارد کن.');
                              return;
                            }
                            setState(() => busy = true);
                            try {
                              if (!sent) {
                                await widget.backend.db.auth
                                    .signInWithOtp(phone: p);
                                if (mounted) setState(() => sent = true);
                              } else {
                                await widget.backend.db.auth.verifyOTP(
                                    phone: p,
                                    token: normalizeBackendDigits(code.text),
                                    type: OtpType.sms);
                                await widget.backend.db.rpc('accept_rules',
                                    params: {'version': '2026-10-19'});
                                if (context.mounted) Navigator.pop(context);
                              }
                            } catch (_) {
                              if (mounted)
                                setState(() => error =
                                    'ارسال یا تأیید پیامک انجام نشد. تنظیمات پیامک یا کد را بررسی کن.');
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(busy
                        ? 'در حال انجام…'
                        : sent
                            ? 'تأیید و ورود'
                            : 'ارسال کد')),
                if (sent)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                sent = false;
                                error = '';
                                code.clear();
                              }),
                      child: const Text('تغییر شماره یا دریافت کد جدید')),
              ]))));
}

// Private server-backed screens are imported below as one production library.
// They never read AccountWorkspace, DemoWorkRepository or a sample phone.

class BackendThread extends StatefulWidget {
  const BackendThread(
      {super.key,
      required this.backend,
      required this.thread,
      required this.peerName});
  final KamchehBackend backend;
  final BackendRow thread;
  final String peerName;
  @override
  State<BackendThread> createState() => _BackendThreadState();
}

class _BackendThreadState extends State<BackendThread> {
  final input = TextEditingController();
  final scroll = ScrollController();
  List<BackendRow> rows = [], visits = [];
  bool busy = false;
  String error = '';
  Timer? timer;
  String get id => widget.thread['id'];
  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final m = await widget.backend.messages(id);
      final v = await widget.backend.db
          .from('visit_records')
          .select()
          .eq('thread_id', id)
          .order('visit_at');
      if (mounted)
        setState(() {
          rows = m;
          visits = List<BackendRow>.from(v);
          error = '';
        });
    } catch (_) {
      if (mounted) setState(() => error = 'دریافت گفتگو انجام نشد.');
    }
  }

  Future<void> action(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
      await refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('عملیات انجام نشد. دوباره تلاش کن.')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty) return;
    await action(() async {
      await widget.backend.send(id, text);
      input.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    });
  }

  Future<void> visit() async {
    final now = DateTime.now();
    final d = await pickPersianDate(context,
        initialDate: now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 180)));
    if (d == null || !mounted) return;
    final t =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    final at = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    await action(() async {
      await widget.backend.db.from('visit_records').insert({
        'thread_id': id,
        'proposed_by': widget.backend.actor,
        'visit_at': at.toUtc().toIso8601String()
      });
    });
  }

  Future<void> attach() async {
    final file = await openFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حداکثر حجم فایل ۱۰ مگابایت است.')));
      return;
    }
    await action(() async {
      final path =
          '$id/${widget.backend.actor}/${DateTime.now().microsecondsSinceEpoch}-${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      await widget.backend.db.storage.from('kamcheh-thread-files').uploadBinary(
          path, bytes,
          fileOptions: FileOptions(
              contentType: file.mimeType ?? 'application/octet-stream'));
      await widget.backend.db.from('thread_messages').insert({
        'thread_id': id,
        'sender_id': widget.backend.actor,
        'body': input.text.trim(),
        'attachment_path': path,
        'file_name': file.name,
        'mime': file.mimeType ?? 'application/octet-stream'
      });
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.peerName), actions: [
        IconButton(
            tooltip: 'قرار بازدید',
            onPressed: busy ? null : visit,
            icon: const Icon(Icons.event_outlined)),
        IconButton(
            tooltip: 'قرارداد',
            onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => BackendContracts(
                    backend: widget.backend,
                    peerId:
                        widget.thread['participant_a'] == widget.backend.actor
                            ? widget.thread['participant_b']
                            : widget.thread['participant_a'],
                    threadId: id))),
            icon: const Icon(Icons.description_outlined))
      ]),
      body: Column(children: [
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty) Text(error),
        Expanded(
            child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(12),
                children: [
              for (final v in visits)
                Card(
                    child: ListTile(
                        title: Text(
                            'بازدید: ${jalaliDate(DateTime.parse(v['visit_at']), withTime: true)}'),
                        subtitle: Text(v['status']),
                        trailing: Wrap(children: [
                          if (v['status'] == 'pending' &&
                              v['proposed_by'] != widget.backend.actor)
                            IconButton(
                                tooltip: 'تأیید',
                                onPressed: () => action(() async {
                                      await widget.backend.db
                                          .rpc('decide_visit', params: {
                                        'visit': v['id'],
                                        'decision': 'accepted'
                                      });
                                    }),
                                icon: const Icon(Icons.check)),
                          if (['pending', 'accepted'].contains(v['status']))
                            IconButton(
                                tooltip: 'لغو',
                                onPressed: () => action(() async {
                                      await widget.backend.db
                                          .rpc('decide_visit', params: {
                                        'visit': v['id'],
                                        'decision': 'cancelled'
                                      });
                                    }),
                                icon: const Icon(Icons.close)),
                        ]))),
              for (final m in rows)
                Align(
                    alignment: m['sender_id'] == widget.backend.actor
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: m['sender_id'] == widget.backend.actor
                                ? const Color(0xFFFFEEEE)
                                : const Color(0xFFF2F3F5),
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['body']),
                              if (m['attachment_path'] != null)
                                TextButton.icon(
                                    onPressed: () => action(() async {
                                          final bytes = await widget
                                              .backend.db.storage
                                              .from('kamcheh-thread-files')
                                              .download(m['attachment_path']);
                                          await deliverFile(
                                              bytes,
                                              m['file_name'] ?? 'file',
                                              m['mime'] ??
                                                  'application/octet-stream');
                                        }),
                                    icon: const Icon(Icons.download),
                                    label: Text(m['file_name'] ?? 'پیوست')),
                              Text(
                                  jalaliDate(DateTime.parse(m['created_at']),
                                      withTime: true),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey))
                            ]))),
            ])),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
                'سابقه این گفتگو حفظ می‌شود. پیام‌ها و فایل‌ها را با دقت ارسال کن.',
                style: TextStyle(fontSize: 10, color: Colors.grey))),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  IconButton(
                      tooltip: 'ارسال فایل',
                      onPressed: busy ? null : attach,
                      icon: const Icon(Icons.attach_file)),
                  Expanded(
                      child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(hintText: 'پیام بنویس…'))),
                  IconButton.filled(
                      onPressed: busy ? null : send,
                      icon: const Icon(Icons.send))
                ]))),
      ]));
}

class BackendAccounting extends StatefulWidget {
  const BackendAccounting({super.key, required this.backend});
  final KamchehBackend backend;
  @override
  State<BackendAccounting> createState() => _BackendAccountingState();
}

class _BackendAccountingState extends State<BackendAccounting> {
  List<BackendRow> rows = [];
  int tab = 0;
  bool busy = false;
  String error = '';
  static const groups = [
    'حمل و مصالح',
    'تجهیزات و نیازمندی کارگاه',
    'حقوق پرسنل',
    'اداری و پذیرایی',
    'مهندسی',
    'متفرقه'
  ];
  static const stages = [
    'آماده‌سازی',
    'فنداسیون',
    'اسکلت',
    'دیوارچینی',
    'تأسیسات',
    'نازک‌کاری',
    'نما',
    'عمومی'
  ];
  static const types = {
    'بدهی': 'debt',
    'تسویه': 'settled',
    'علی‌الحساب': 'advance'
  };
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final r = await widget.backend.mine('accounting_entries');
      if (mounted)
        setState(() {
          rows = r;
          error = '';
        });
    } catch (_) {
      if (mounted) setState(() => error = 'دریافت حسابداری انجام نشد.');
    }
  }

  Future<void> edit({BackendRow? row}) async {
    final receipt = row?['is_income'] ?? tab == 1;
    var date = row == null ? DateTime.now() : DateTime.parse(row['entry_date']);
    final picked = await pickPersianDate(context,
        initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null || !mounted) return;
    date = picked;
    final fields = receipt
        ? ['شرح', 'از محل', 'مبلغ']
        : ['شرح', 'از محل', 'مبلغ', 'نوع حساب', 'گروه', 'مرحله'];
    final v = await backendForm(
        context, receipt ? 'دریافتی تنخواه' : 'هزینه', fields,
        initial: {
          'شرح': row?['description'] ?? '',
          'از محل': row?['source'] ?? '',
          'مبلغ': row?['amount']?.toString() ?? '',
          'نوع حساب': types.entries
                  .where((e) => e.value == row?['entry_type'])
                  .firstOrNull
                  ?.key ??
              'تسویه',
          'گروه': row?['category'] ?? groups.first,
          'مرحله': row?['stage'] ?? 'عمومی'
        },
        choices: {
          'نوع حساب': types.keys.toList(),
          'گروه': groups,
          'مرحله': stages
        });
    if (v == null || !mounted) return;
    setState(() => busy = true);
    try {
      final value = {
        'owner_id': widget.backend.actor,
        'entry_date': date.toIso8601String().substring(0, 10),
        'description': v['شرح'],
        'source': v['از محل'],
        'amount': backendAmount(v['مبلغ']!, optional: false),
        'entry_type': receipt ? 'settled' : types[v['نوع حساب']],
        'category': v['گروه'] ?? '',
        'stage': v['مرحله'] ?? '',
        'is_income': receipt
      };
      if (row == null) {
        await widget.backend.db.from('accounting_entries').insert(value);
      } else {
        await widget.backend.db
            .from('accounting_entries')
            .update(value)
            .eq('id', row['id']);
      }
      await refresh();
    } catch (_) {
      if (mounted)
        setState(() => error = 'ذخیره نشد؛ مبلغ و اتصال را بررسی کن.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(BackendRow row) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('حذف این ردیف؟'),
                content: Text(row['description']),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('انصراف')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('حذف'))
                ]));
    if (yes != true) return;
    await widget.backend.db
        .from('accounting_entries')
        .delete()
        .eq('id', row['id']);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    int sum(bool Function(BackendRow) filter) => rows
        .where(filter)
        .fold<int>(0, (n, r) => n + (r['amount'] as num).toInt());
    final debt = sum((r) => !r['is_income'] && r['entry_type'] == 'debt'),
        paid = sum((r) => !r['is_income'] && r['entry_type'] != 'debt'),
        received = sum((r) => r['is_income']);
    final items = rows.where((r) => r['is_income'] == (tab == 1));
    return Scaffold(
        appBar: AppBar(title: const Text('حسابداری')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          SegmentedButton<int>(segments: const [
            ButtonSegment(value: 0, label: Text('هزینه‌ها')),
            ButtonSegment(value: 1, label: Text('دفتر کل'))
          ], selected: {
            tab
          }, onSelectionChanged: (s) => setState(() => tab = s.first)),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty) Text(error),
          if (tab == 1) ...[
            for (final e in {
              'جمع بدهی‌ها': debt,
              'جمع هزینه‌ها': paid,
              'مانده تنخواه': received - paid,
              'کل مخارج': debt + paid
            }.entries)
              ListTile(
                  title: Text(e.key),
                  trailing: Text('${persianDigits(e.value)} تومان')),
            const Text('دریافتی‌های تنخواه',
                style: TextStyle(fontWeight: FontWeight.bold))
          ],
          FilledButton.icon(
              onPressed: busy ? null : () => edit(),
              icon: const Icon(Icons.add),
              label: Text(tab == 0 ? 'ثبت هزینه' : 'ثبت دریافتی تنخواه')),
          if (items.isEmpty)
            const Padding(
                padding: EdgeInsets.all(30),
                child: Text('هنوز ردیفی ثبت نشده است.')),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columnSpacing: 16,
                  columns: (tab == 0
                          ? [
                              'تاریخ',
                              'شرح',
                              'از محل',
                              'مبلغ',
                              'نوع حساب',
                              'گروه',
                              'مرحله',
                              ''
                            ]
                          : ['تاریخ', 'از محل', 'مبلغ', 'شرح', ''])
                      .map((t) => DataColumn(label: Text(t)))
                      .toList(),
                  rows: items
                      .map((r) => DataRow(cells: [
                            DataCell(Text(
                                jalaliDate(DateTime.parse(r['entry_date'])))),
                            if (tab == 0) DataCell(Text(r['description'])),
                            DataCell(Text(r['source'])),
                            DataCell(Text(persianDigits(r['amount']))),
                            if (tab == 0) ...[
                              DataCell(Text(types.entries
                                      .where((e) => e.value == r['entry_type'])
                                      .firstOrNull
                                      ?.key ??
                                  '')),
                              DataCell(Text(r['category'])),
                              DataCell(Text(r['stage']))
                            ] else
                              DataCell(Text(r['description'])),
                            DataCell(PopupMenuButton<String>(
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: 'edit', child: Text('ویرایش')),
                                      PopupMenuItem(
                                          value: 'delete', child: Text('حذف'))
                                    ],
                                onSelected: (v) =>
                                    v == 'edit' ? edit(row: r) : remove(r))),
                          ]))
                      .toList())),
        ]));
  }
}

class BackendContracts extends StatefulWidget {
  const BackendContracts(
      {super.key, required this.backend, this.peerId, this.threadId, this.parent});
  final KamchehBackend backend;
  final String? peerId, threadId;
  final BackendRow? parent;
  @override
  State<BackendContracts> createState() => _BackendContractsState();
}

class _BackendContractsState extends State<BackendContracts> {
  List<BackendRow> rows = [];
  String error = '';
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final r = await widget.backend.db
          .from('contract_drafts')
          .select()
          .order('updated_at', ascending: false);
      if (mounted) setState(() => rows = List<BackendRow>.from(r));
    } catch (_) {
      if (mounted) setState(() => error = 'دریافت قراردادها انجام نشد.');
    }
  }

  Future<void> create({BackendRow? parent}) async {
    parent ??= widget.parent;
    final people = await widget.backend.profiles();
    if (!mounted) return;
    final other = parent == null
        ? widget.peerId
        : parent['owner_id'] == widget.backend.actor
            ? parent['counterparty_id']
            : parent['owner_id'];
    final names = {
      for (final p in people.where((p) => p['id'] != widget.backend.actor))
        '${p['display_name']} · ${p['specialty']}': p['id']
    };
    if (names.isEmpty) {
      setState(() => error = 'طرف مقابل باید ابتدا پروفایلش را تکمیل کند.');
      return;
    }
    final peerLabel =
        names.entries.where((e) => e.value == other).firstOrNull?.key;
    final v = await backendForm(
        context, parent == null ? 'قرارداد جدید' : 'الحاقیه', [
      'عنوان',
      'طرف مقابل',
      'قالب'
    ],
        initial: {
          if (peerLabel != null) 'طرف مقابل': peerLabel
        },
        choices: {
          'طرف مقابل': peerLabel != null ? [peerLabel] : names.keys.toList(),
          'قالب': ['اجرای کار', 'خدمات طراحی', 'توافق عمومی']
        });
    if (v == null) return;
    try {
      final id = await widget.backend.db.rpc('contract_action', params: {
        'action': 'create',
        'data': {
          'title': v['عنوان'],
          'counterparty_id': names[v['طرف مقابل']],
          'template': v['قالب'],
          'payload': {
            'subject': v['عنوان'],
            'price': '',
            'schedule': '',
            'payment': '',
            'terms': preparedContractTerms(v['قالب']!)
          },
          if (parent != null) 'parent_id': parent['id'],
          if (widget.threadId != null) 'thread_id': widget.threadId
        }
      });
      await refresh();
      if (mounted) await open(rows.firstWhere((r) => r['id'] == id));
    } catch (_) {
      if (mounted) setState(() => error = 'ساخت قرارداد انجام نشد.');
    }
  }

  Future<void> open(BackendRow row) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) =>
            BackendContractEditor(backend: widget.backend, id: row['id'])));
    await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('قراردادهای من')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (error.isNotEmpty) Text(error),
        const Text(
            'اطلاعات هر طرف توسط خودش تکمیل می‌شود. قراردادهای مشترک در حساب هر دو طرف دیده می‌شوند.'),
        FilledButton.icon(
            onPressed: () => create(),
            icon: const Icon(Icons.add),
            label: const Text('قرارداد جدید')),
        ...rows.map((r) => ListTile(
            title: Text(r['title']),
            subtitle: Text('ویرایش ${persianDigits(r['revision'])}'),
            onTap: () => open(r))),
      ]));
}

class BackendContractEditor extends StatefulWidget {
  const BackendContractEditor(
      {super.key, required this.backend, required this.id});
  final KamchehBackend backend;
  final String id;
  @override
  State<BackendContractEditor> createState() => _BackendContractEditorState();
}

class _BackendContractEditorState extends State<BackendContractEditor> {
  BackendRow? contract;
  List<BackendRow> parties = [], versions = [];
  bool busy = false;
  String error = '';
  SupabaseClient get db => widget.backend.db;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final c = await db
          .from('contract_drafts')
          .select()
          .eq('id', widget.id)
          .single();
      final p = await db
          .from('contract_parties')
          .select()
          .eq('contract_id', widget.id);
      final v = await db
          .from('contract_versions')
          .select()
          .eq('contract_id', widget.id)
          .order('revision', ascending: false);
      if (mounted)
        setState(() {
          contract = c;
          parties = List<BackendRow>.from(p);
          versions = List<BackendRow>.from(v);
        });
    } catch (_) {
      if (mounted) setState(() => error = 'دریافت قرارداد انجام نشد.');
    }
  }

  Future<void> action(String action, Map<String, dynamic> data) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await db.rpc('contract_action',
          params: {'action': action, 'contract': widget.id, 'data': data});
      await refresh();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'ثبت انجام نشد؛ اطلاعات هر دو طرف، متن و تأییدها را بررسی کن.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> party() async {
    final row =
        parties.firstWhere((p) => p['profile_id'] == widget.backend.actor);
    final details = Map<String, dynamic>.from(row['details']);
    final v = await backendForm(context, 'مشخصات و خواسته‌های من', [
      'نام کامل',
      'شناسه هویتی',
      'نشانی',
      'شماره تماس',
      'خواسته‌های من'
    ], initial: {
      'نام کامل': details['name'] ?? '',
      'شناسه هویتی': details['identity'] ?? '',
      'نشانی': details['address'] ?? '',
      'شماره تماس': details['phone'] ?? '',
      'خواسته‌های من': details['wishes'] ?? ''
    });
    if (v == null) return;
    await action('party', {
      ...details,
      'name': v['نام کامل'],
      'identity': v['شناسه هویتی'],
      'address': v['نشانی'],
      'phone': v['شماره تماس'],
      'wishes': v['خواسته‌های من']
    });
  }

  Future<void> terms() async {
    final p = Map<String, dynamic>.from(contract!['payload']);
    final v = await backendForm(context, 'متن و شرایط قرارداد', [
      'موضوع و محل',
      'مبلغ',
      'زمان و مدت',
      'شیوه پرداخت',
      'شرایط'
    ], initial: {
      'موضوع و محل': p['subject'] ?? '',
      'مبلغ': p['price'] ?? '',
      'زمان و مدت': p['schedule'] ?? '',
      'شیوه پرداخت': p['payment'] ?? '',
      'شرایط': p['terms'] ?? ''
    });
    if (v == null) return;
    await action('edit', {
      'subject': v['موضوع و محل'],
      'price': v['مبلغ'],
      'schedule': v['زمان و مدت'],
      'payment': v['شیوه پرداخت'],
      'terms': v['شرایط']
    });
  }

  Future<void> document() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(
          label: 'تصاویر مدارک', extensions: ['jpg', 'jpeg', 'png'])
    ]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      setState(() => error = 'حداکثر حجم مدرک ۱۰ مگابایت است.');
      return;
    }
    final row =
            parties.firstWhere((p) => p['profile_id'] == widget.backend.actor),
        detail = Map<String, dynamic>.from(row['details']);
    final docs = List<String>.from(detail['documents'] ?? []);
    if (docs.length >= 6) {
      setState(() => error = 'حداکثر شش تصویر مدرک.');
      return;
    }
    final path =
        '${widget.id}/${widget.backend.actor}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    setState(() => busy = true);
    try {
      await db.storage.from('kamcheh-private-docs').uploadBinary(path, bytes,
          fileOptions: FileOptions(contentType: file.mimeType ?? 'image/jpeg'));
    } catch (_) {
      setState(() => error = 'بارگذاری مدرک انجام نشد.');
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    await action('party', {
      ...detail,
      'documents': [...docs, path]
    });
  }

  Future<void> sign() async {
    final v =
        await backendForm(context, 'تأیید و امضا', ['نام کامل برای امضا']);
    if (v == null || !mounted) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('تأیید متن و مدارک'),
                content: const Text(
                    'متن و اطلاعات هر دو طرف و پیوست‌ها را بررسی کرده‌ام و این ویرایش را تأیید می‌کنم. امضا تایپی است و احراز رسمی هویت نیست.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('انصراف')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('تأیید و ثبت امضا'))
                ]));
    if (yes == true)
      await action('sign',
          {'name': v['نام کامل برای امضا'], 'revision': contract!['revision']});
  }

  Future<void> pdf(BackendRow v) async {
    final snapshot = Map<String, dynamic>.from(v['snapshot']),
        c = Map<String, dynamic>.from(snapshot['contract']);
    final ps = List<Map<String, dynamic>>.from(snapshot['parties']);
    final payload = Map<String, dynamic>.from(c['payload']);
    final images = <Uint8List>[];
    for (final p in ps) {
      for (final path in p['details']['documents'] ?? []) {
        images
            .add(await db.storage.from('kamcheh-private-docs').download(path));
      }
    }
    final revision = ContractRevision(
        number: v['revision'],
        title: c['title'],
        template: c['template'],
        createdAt: DateTime.parse(v['created_at']),
        parentId: c['parent_id'],
        values: {
          'طرفین': ps
              .map((p) => Map<String, dynamic>.from(p['details'])
                  .entries
                  .where((e) => e.key != 'documents')
                  .map((e) => '${e.key}: ${e.value}')
                  .join('\n'))
              .join('\n\n'),
          'موضوع و محل': payload['subject'] ?? '',
          'مبلغ': payload['price'] ?? '',
          'زمان و مدت': payload['schedule'] ?? '',
          'شیوه پرداخت': payload['payment'] ?? '',
          'شرایط': payload['terms'] ?? '',
          'تأیید و امضای طرفین': ps
              .map((p) => '${p['signature_name']} · ${p['signed_at']}')
              .join('\n')
        },
        photos: images);
    await deliverPdf(await buildContractPdf(revision),
        'kamcheh-${widget.id}-v${v['revision']}.pdf');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(contract?['title'] ?? 'قرارداد'), actions: [
        IconButton(
            tooltip: 'به‌روزرسانی',
            onPressed: refresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: contract == null
          ? Center(child: Text(error.isEmpty ? 'در حال دریافت…' : error))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (busy) const LinearProgressIndicator(),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              Text(
                  'ویرایش ${persianDigits(contract!['revision'])} · هر تغییر تأییدهای قبلی را باطل می‌کند.'),
              OutlinedButton(
                  onPressed: busy ? null : terms,
                  child: const Text('ویرایش متن مشترک')),
              OutlinedButton(
                  onPressed: busy ? null : party,
                  child: const Text('تکمیل اطلاعات خودم')),
              OutlinedButton(
                  onPressed: busy ? null : document,
                  child: const Text('افزودن مدرک خصوصی')),
              for (final p in parties)
                ExpansionTile(
                    title:
                        Text(p['details']['name'] ?? 'اطلاعات در انتظار تکمیل'),
                    subtitle: Text(p['signed_revision'] == contract!['revision']
                        ? 'تأیید شده'
                        : 'در انتظار تأیید'),
                    children: [
                      for (final e in Map<String, dynamic>.from(p['details'])
                          .entries
                          .where((e) => e.key != 'documents'))
                        ListTile(
                            title: Text(e.key), subtitle: Text('${e.value}')),
                      for (final path in p['details']['documents'] ?? [])
                        TextButton(
                            onPressed: () async {
                              final bytes = await db.storage
                                  .from('kamcheh-private-docs')
                                  .download(path);
                              if (context.mounted)
                                await showDialog<void>(
                                    context: context,
                                    builder: (c) => Dialog(
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                              Flexible(
                                                  child: InteractiveViewer(
                                                      child:
                                                          Image.memory(bytes))),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c),
                                                  child: const Text('بستن'))
                                            ])));
                            },
                            child: const Text('مشاهده مدرک')),
                    ]),
              for (final e
                  in Map<String, dynamic>.from(contract!['payload']).entries)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${e.key}\n${e.value}')),
              FilledButton(
                  onPressed: busy ? null : sign,
                  child: const Text('تأیید و امضای من')),
              FilledButton(
                  onPressed: busy ||
                          parties.length != 2 ||
                          parties.any((p) =>
                              p['signed_revision'] != contract!['revision'])
                      ? null
                      : () => action('finalize', {}),
                  child: const Text('ثبت نسخه نهایی')),
              for (final v in versions)
                ListTile(
                    title: Text('نسخه ثبت‌شده ${persianDigits(v['revision'])}'),
                    trailing: const Icon(Icons.picture_as_pdf_outlined),
                    onTap: () async {
                      try {
                        await pdf(v);
                      } catch (_) {
                        if (mounted)
                          setState(() => error = 'دریافت PDF انجام نشد.');
                      }
                    }),
              if (versions.isNotEmpty)
                OutlinedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                            builder: (_) => BackendContracts(
                                backend: widget.backend,
                                parent: contract,
                                peerId: contract!['owner_id'] ==
                                        widget.backend.actor
                                    ? contract!['counterparty_id']
                                    : contract!['owner_id']))),
                    child: const Text('تنظیم الحاقیه')),
            ]));
}
