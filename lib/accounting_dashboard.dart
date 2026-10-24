part of 'main.dart';

const _ledgerGroups = <String>[
  'مصالح و حمل',
  'تجهیزات کارگاه',
  'پرسنلی و کارگری',
  'اداری و خرج غیره',
  'مهندسی',
  'متفرقه خارج از کارگاه',
];

String _ledgerGroup(String category) => switch (category) {
      'حمل و مصالح' || 'مصالح' || 'حمل‌ونقل' => _ledgerGroups[0],
      'تجهیزات و نیازمندی کارگاه' || 'تجهیزات' => _ledgerGroups[1],
      'حقوق پرسنل' || 'دستمزد' => _ledgerGroups[2],
      'اداری و پذیرایی' => _ledgerGroups[3],
      'متفرقه' => _ledgerGroups[5],
      _ => category
    };

bool _isDebt(Expense e) => !e.income && e.accountType == 'بدهی';
bool _isForecast(Expense e) => e.accountType == 'پیش‌بینی';
bool _isDeduction(Expense e) => e.accountType == 'کسور';
bool _isOutgoing(Expense e) =>
    !e.income && !_isDebt(e) && !_isForecast(e) && !_isDeduction(e);

class AccountingDashboard extends StatefulWidget {
  const AccountingDashboard({super.key, required this.entries,
    required this.contacts, required this.tab, required this.onTab,
    required this.onEntry, required this.onContact});
  final List<Expense> entries;
  final Map<String, List<String>> contacts;
  final int tab;
  final ValueChanged<int> onTab;
  final ValueChanged<Expense> onEntry;
  final void Function(String group, String name) onContact;

  @override
  State<AccountingDashboard> createState() => _AccountingDashboardState();
}

class _AccountingDashboardState extends State<AccountingDashboard> {
  String? group, party;
  String contactQuery = '';
  bool showPaid = false;

  List<Expense> get entries => widget.entries;
  List<Expense> get debts => entries.where(_isDebt).toList();
  Map<String, int> get remaining => remainingDebts(
    debts.map((d) => AccountingDebt(d.id, d.date, d.amount)),
    entries.where((e) => e.allocations.isNotEmpty).map((e) => e.allocations));
  int get totalDue => remaining.values.fold<int>(0, (n, v) => n + v);
  int get cashIn => entries.where((e) => e.income).fold<int>(0, (n, e) => n + e.amount);
  int get cashOut => entries.where(_isOutgoing).fold<int>(0, (n, e) => n + e.amount);
  int get pettyCash => cashIn - cashOut;

  Widget _label(String title, {String? note}) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      if (note != null) Text(note, style: const TextStyle(fontSize: 11, color: muted))
    ]));

  Widget _tile({required Widget child}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line),
      borderRadius: BorderRadius.circular(14)), child: child);

  Widget _action(String text, IconData icon, VoidCallback onTap,
      {bool filled = false}) => filled
      ? FilledButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(text))
      : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 17), label: Text(text));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(13)),
        child: Row(children: [
          _tab(0, 'دفتر کل'), _tab(1, 'هزینه‌ها'), _tab(2, 'پیش‌بینی')
        ])),
      const SizedBox(height: 12),
      if (widget.tab == 0) ..._ledger(),
      if (widget.tab == 1) ..._expenses(),
      if (widget.tab == 2) ..._forecast(),
    ]);

  Widget _tab(int index, String label) => Expanded(child: InkWell(
    onTap: () => widget.onTab(index),
    borderRadius: BorderRadius.circular(10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 1),
      decoration: BoxDecoration(color: widget.tab == index ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: widget.tab == index ? [const BoxShadow(color: Color(0x12000000), blurRadius: 8)] : null),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: widget.tab == index ? FontWeight.w700 : FontWeight.w500,
          color: widget.tab == index ? red : muted)))));

  List<Widget> _ledger() {
    final timeline = entries.where((e) => !_isForecast(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return [
      _tile(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مانده تنخواه', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 6),
        Text(money(pettyCash), style: TextStyle(fontSize: 24,
          fontWeight: FontWeight.bold, color: pettyCash < 0 ? red : ink)),
        if (pettyCash < 0) const Text('از پول شخصی خرج شده',
          style: TextStyle(fontSize: 11, color: red)),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: Text('دریافتی: ${money(cashIn)}',
            style: const TextStyle(fontSize: 11, color: muted))),
          Expanded(child: Text('پرداختی: ${money(cashOut)}', textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 11, color: muted)))
        ])
      ])),
      Row(children: [
        Expanded(child: _action('دریافت تنخواه', Icons.add, _receiveCash, filled: true)),
        const SizedBox(width: 8),
        IconButton(onPressed: _showReport, tooltip: 'گزارش هفتگی و ماهانه',
          icon: const Icon(Icons.assessment_outlined)),
        IconButton(onPressed: _exportExcel, tooltip: 'خروجی اکسل',
          icon: const Icon(Icons.file_download_outlined)),
      ]),
      _label('تراکنش‌ها', note: 'تنخواه، طلب‌ها، پرداخت‌ها و کسورات به ترتیب تاریخ'),
      if (timeline.isEmpty) _tile(child: const Text('هنوز تراکنشی ثبت نشده است.')),
      ...timeline.map(_timelineRow),
    ];
  }

  Widget _timelineRow(Expense e) {
    final incoming = e.income, due = _isDebt(e), deduction = _isDeduction(e);
    final label = incoming ? 'دریافت تنخواه' : due ? 'ایجاد طلب'
      : deduction ? 'کسر از طلب' : 'پرداخت';
    final color = incoming ? const Color(0xFF207A5A)
      : due ? const Color(0xFFCA8830) : deduction ? muted : red;
    return _tile(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 35, height: 35, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(11)),
        child: Icon(incoming ? Icons.south_west : due ? Icons.receipt_long_outlined
          : deduction ? Icons.remove_circle_outline : Icons.north_east,
          color: color, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 3),
        Text('$label${e.party.isEmpty ? '' : ' · ${e.party}'}',
          style: const TextStyle(color: muted, fontSize: 10)),
        Text(jalaliDate(e.date), style: const TextStyle(color: muted, fontSize: 10)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${incoming ? '+' : due ? '' : '−'}${money(e.amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        if (e.photoBase64 != null) IconButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: const Icon(Icons.image_outlined, size: 17),
          onPressed: () => _viewPhoto(e.photoBase64!)),
      ])
    ]));
  }

  List<String> get contactNames {
    if (group == null) return [];
    final names = <String>{...?widget.contacts[group],
      ...entries.where((e) => _ledgerGroup(e.category) == group && e.party.isNotEmpty)
        .map((e) => e.party)}.toList()..sort();
    return names.where((name) => name.contains(contactQuery.trim())).toList();
  }

  List<Widget> _expenses() {
    return [
      _label('۱. گروه هزینه'),
      Wrap(spacing: 6, runSpacing: 5, children: [
        for (final g in _ledgerGroups)
          ChoiceChip(label: Text(g, style: const TextStyle(fontSize: 11)),
            selected: group == g, showCheckmark: false,
            onSelected: (_) => setState(() {
              group = g; party = null; contactQuery = '';
            }))
      ]),
      if (group != null) ...[
        _label('۲. طرف حساب', note: 'فرد یا فروشنده را انتخاب کن'),
        TextField(
          onChanged: (value) => setState(() => contactQuery = value),
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 19),
            hintText: 'جستجوی نام', isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 8),
        if (contactNames.isNotEmpty) ...[
          for (final name in contactNames)
            Padding(padding: const EdgeInsets.only(bottom: 5),
              child: ListTile(dense: true, tileColor: party == name
                ? const Color(0xFFFFF2F1) : const Color(0xFFF7F7F8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                title: Text(name, style: const TextStyle(fontSize: 12)),
                trailing: party == name ? const Icon(Icons.check_circle, color: red, size: 18)
                  : const Icon(Icons.chevron_left),
                onTap: () => setState(() => party = name))),
        ],
        Align(alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: _newContact,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: const Text('افزودن طرف حساب جدید'))),
      ],
      if (group != null && party != null) ..._partyAccount(),
    ];
  }

  List<Widget> _partyAccount() {
    final selected = debts.where((d) => _ledgerGroup(d.category) == group && d.party == party)
      .toList()..sort((a, b) => a.date.compareTo(b.date));
    final open = selected.where((d) => (remaining[d.id] ?? 0) > 0).toList();
    final total = open.fold<int>(0, (sum, d) => sum + (remaining[d.id] ?? 0));
    final history = entries.where((e) => e.party == party &&
      _ledgerGroup(e.category) == group && !_isDebt(e) && !_isForecast(e)).toList();
    return [
      _label('۳. حساب $party'),
      _tile(child: Row(children: [
        const Expanded(child: Text('مانده طلب', style: TextStyle(fontSize: 12))),
        Text(money(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
      ])),
      Row(children: [
        Expanded(child: _action('ثبت طلب', Icons.add, _addDebt, filled: true)),
        const SizedBox(width: 8),
        Expanded(child: _action('پرداخت', Icons.payments_outlined, _pay)),
      ]),
      _label('طلب‌های باز', note: 'نوار هر طلب به نسبت پرداخت، پر می‌شود.'),
      if (open.isEmpty) _tile(child: const Text('طلب تسویه‌نشده‌ای وجود ندارد.',
        style: TextStyle(fontSize: 12, color: muted))),
      ...open.map((d) => _debtRow(d)),
      if (selected.length > open.length) Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => setState(() => showPaid = !showPaid),
          child: Text(showPaid ? 'بستن تسویه‌شده‌ها' : 'نمایش تسویه‌شده‌ها'))),
      if (showPaid) ...selected.where((d) => (remaining[d.id] ?? 0) == 0).map(_debtRow),
      if (history.isNotEmpty) ...[
        _label('سابقه پرداخت و کسورات'),
        ...history.reversed.map(_timelineRow),
      ],
    ];
  }

  Widget _debtRow(Expense debt) {
    final left = remaining[debt.id] ?? debt.amount;
    final settled = debt.amount - left;
    return _tile(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(debt.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Text(money(left), style: TextStyle(color: left == 0 ? const Color(0xFF207A5A) : ink,
          fontWeight: FontWeight.bold, fontSize: 12))
      ]),
      const SizedBox(height: 4),
      Text('${jalaliDate(debt.date)} · اصل طلب ${money(debt.amount)}',
        style: const TextStyle(fontSize: 10, color: muted)),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: debt.amount == 0 ? 1 : settled / debt.amount,
          minHeight: 7, backgroundColor: const Color(0xFFF4DEDD), color: const Color(0xFF35A67C))),
      if (left > 0) Align(alignment: Alignment.centerLeft,
        child: TextButton(onPressed: () => _deduct(debt),
          child: const Text('ثبت جریمه / کسور', style: TextStyle(fontSize: 11))))
    ]));
  }

  List<Widget> _forecast() {
    final groupTotals = <String, int>{for (final g in _ledgerGroups) g: 0};
    for (final debt in debts) {
      final category = _ledgerGroup(debt.category);
      groupTotals[category] = (groupTotals[category] ?? 0) + (remaining[debt.id] ?? 0);
    }
    final future = entries.where(_isForecast).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final manual = future.fold<int>(0, (n, e) => n + e.amount);
    return [
      _tile(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('جمع هزینه‌های پیش رو', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(money(totalDue + manual),
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('بدهی‌های باز ${money(totalDue)}  +  پیش‌بینی دستی ${money(manual)}',
          style: const TextStyle(fontSize: 10, color: muted)),
      ])),
      _label('بدهی‌های قطعی به تفکیک گروه'),
      ...groupTotals.entries.map((g) => _tile(child: Row(children: [
        Expanded(child: Text(g.key, style: const TextStyle(fontSize: 12))),
        Text(money(g.value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))
      ]))),
      Row(children: [
        Expanded(child: _label('هزینه‌های پیش‌بینی‌شده')),
        _action('افزودن', Icons.add, _addForecast),
      ]),
      if (future.isEmpty) _tile(child: const Text('هنوز هزینه‌ای برای آینده وارد نشده است.',
        style: TextStyle(fontSize: 12, color: muted))),
      ...future.map((e) => _tile(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('${_ledgerGroup(e.category)} · ${jalaliDate(e.date)}',
            style: const TextStyle(fontSize: 10, color: muted))
        ])),
        Text(money(e.amount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))
      ]))),
    ];
  }

  Future<_AccountingDraft?> _record(String title,
      {String? defaultTitle, bool forecast = false}) =>
    showModalBottomSheet<_AccountingDraft>(context: context,
      useSafeArea: true, isScrollControlled: true, backgroundColor: Colors.white,
      builder: (_) => _AccountingRecordSheet(
        title: title, defaultTitle: defaultTitle ?? '', forecast: forecast));

  Future<void> _receiveCash() async {
    final draft = await _record('دریافت تنخواه', defaultTitle: 'دریافت تنخواه');
    if (draft == null || !mounted) return;
    widget.onEntry(Expense(draft.title, '', draft.amount, true,
      income: true, accountType: 'تنخواه', source: draft.source,
      date: draft.date, photoBase64: draft.photo));
  }

  Future<void> _newContact() async {
    final input = TextEditingController(text: contactQuery);
    final name = await showDialog<String>(context: context,
      builder: (ctx) => AlertDialog(title: const Text('طرف حساب جدید'),
        content: TextField(controller: input, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'نام فرد یا فروشنده')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            if (input.text.trim().isNotEmpty) Navigator.pop(ctx, input.text.trim());
          }, child: const Text('افزودن'))
        ]));
    input.dispose();
    if (name == null || group == null || !mounted) return;
    widget.onContact(group!, name);
    setState(() { party = name; contactQuery = ''; });
  }

  Future<void> _addDebt() async {
    if (group == null || party == null) return;
    final draft = await _record('ثبت طلب برای $party');
    if (draft == null || !mounted) return;
    widget.onEntry(Expense(draft.title, group!, draft.amount, false,
      party: party!, accountType: 'بدهی', source: draft.source,
      date: draft.date, photoBase64: draft.photo));
  }

  Future<void> _pay() async {
    if (group == null || party == null) return;
    final payable = debts.where((d) => d.party == party &&
      _ledgerGroup(d.category) == group && (remaining[d.id] ?? 0) > 0).toList();
    final payment = await showModalBottomSheet<_AccountingPaymentDraft>(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => _AccountingPaymentSheet(debts: payable, remaining: remaining));
    if (payment == null || !mounted) return;
    widget.onEntry(Expense('پرداخت به $party', group!, payment.amount, true,
      party: party!, accountType: 'پرداخت', source: payment.source,
      allocations: payment.allocations, date: payment.date,
      photoBase64: payment.photo));
  }

  Future<void> _deduct(Expense debt) async {
    final draft = await _record('جریمه / کسور', defaultTitle: 'کسر از ${debt.title}');
    if (draft == null || !mounted) return;
    final left = remaining[debt.id] ?? 0;
    if (draft.amount > left) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('مبلغ کسور بیشتر از مانده طلب است.')));
      return;
    }
    widget.onEntry(Expense(draft.title, debt.category, draft.amount, false,
      party: debt.party, accountType: 'کسور', date: draft.date,
      photoBase64: draft.photo, allocations: {debt.id: draft.amount}));
  }

  Future<void> _addForecast() async {
    final draft = await _record('هزینه پیش‌بینی‌شده', forecast: true);
    if (draft == null || !mounted) return;
    widget.onEntry(Expense(draft.title, draft.group ?? _ledgerGroups.last,
      draft.amount, false, date: draft.date, accountType: 'پیش‌بینی',
      source: draft.source, photoBase64: draft.photo));
  }

  Future<void> _viewPhoto(String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      await showDialog<void>(context: context,
        builder: (ctx) => Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.memory(bytes, fit: BoxFit.contain, height: 360),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بستن'))
        ])));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تصویر پیوست قابل نمایش نیست.')));
    }
  }

  Future<void> _showReport() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true,
      useSafeArea: true, builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) {
          // The filter is kept by the enclosing state to avoid changing ledger data.
          final now = DateTime.now();
          final j = Jalali.fromDateTime(now);
          final week = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
          final month = Jalali(j.year, j.month, 1).toDateTime();
          final start = _reportMonthly ? month : week;
          final list = entries.where((e) => !e.date.isBefore(start) &&
            !e.date.isAfter(now) && !_isForecast(e)).toList();
          int sum(bool Function(Expense) filter) => list.where(filter)
            .fold<int>(0, (n, e) => n + e.amount);
          final groupSums = <String, int>{};
          for (final e in list.where(_isOutgoing)) {
            final g = _ledgerGroup(e.category);
            groupSums[g] = (groupSums[g] ?? 0) + e.amount;
          }
          return Padding(padding: EdgeInsets.fromLTRB(18, 16, 18,
            MediaQuery.viewInsetsOf(ctx).bottom + 22),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('گزارش حسابداری',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                SegmentedButton<bool>(segments: const [
                  ButtonSegment(value: false, label: Text('این هفته')),
                  ButtonSegment(value: true, label: Text('این ماه شمسی')),
                ], selected: {_reportMonthly}, onSelectionChanged: (values) =>
                  refresh(() => _reportMonthly = values.first)),
                const SizedBox(height: 14),
                Text('از ${jalaliDate(start)} تا ${jalaliDate(now)}',
                  style: const TextStyle(fontSize: 11, color: muted)),
                const SizedBox(height: 12),
                _summaryLine('تنخواه دریافتی', sum((e) => e.income)),
                _summaryLine('پرداختی', sum(_isOutgoing)),
                _summaryLine('طلب‌های ثبت‌شده', sum(_isDebt)),
                _summaryLine('کسور', sum(_isDeduction)),
                const Divider(),
                for (final g in groupSums.entries) _summaryLine(g.key, g.value),
                if (list.isEmpty) const Text('در این بازه تراکنشی وجود ندارد.'),
              ]));
        }));
  }

  bool _reportMonthly = false;

  Widget _summaryLine(String name, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
      Text(money(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
    ]));

  Future<void> _exportExcel() async {
    String csv(String text) {
      // Prevent spreadsheet formula injection in user-entered descriptions.
      final safe = text.trimLeft().startsWith(RegExp(r'[=+@-]'))
        ? "'$text" : text;
      return '"${safe.replaceAll('"', '""')}"';
    }
    final lines = <List<String>>[
      ['تاریخ', 'شرح', 'طرف حساب', 'گروه', 'نوع', 'مبلغ (تومان)', 'از محل', 'ارجاع تسویه'],
      ...entries.map((e) => [jalaliDate(e.date), e.title, e.party,
        _ledgerGroup(e.category), e.income ? 'تنخواه' : e.accountType,
        e.amount.toString(), e.source,
        e.allocations.entries.map((a) => '${a.key}: ${a.value}').join(' | ')])
    ];
    final body = lines.map((row) => row.map(csv).join(',')).join('\r\n');
    await deliverFile(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(body)]),
      'kamcheh-accounting.csv', 'text/csv');
  }
}

class _AccountingDraft {
  const _AccountingDraft(this.title, this.amount, this.source,
    this.date, this.photo, this.group);
  final String title, source;
  final int amount;
  final DateTime date;
  final String? photo, group;
}

class _AccountingRecordSheet extends StatefulWidget {
  const _AccountingRecordSheet({required this.title,
    required this.defaultTitle, required this.forecast});
  final String title, defaultTitle;
  final bool forecast;
  @override
  State<_AccountingRecordSheet> createState() => _AccountingRecordSheetState();
}

class _AccountingRecordSheetState extends State<_AccountingRecordSheet> {
  final form = GlobalKey<FormState>();
  late final description = TextEditingController(text: widget.defaultTitle);
  final amount = TextEditingController(), source = TextEditingController();
  DateTime date = DateTime.now();
  String? photo;
  String group = _ledgerGroups.last;

  @override
  void dispose() {
    description.dispose(); amount.dispose(); source.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery,
      imageQuality: 70, maxWidth: 1400);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photo = base64Encode(bytes));
  }

  Future<void> _selectDate() async {
    final selected = await pickPersianDate(context, initialDate: date,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (selected != null && mounted) setState(() => date = selected);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(18, 18, 18,
      MediaQuery.viewInsetsOf(context).bottom + 22),
    child: SingleChildScrollView(child: Form(key: form,
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: const TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold)),
          const SizedBox(height: 17),
          TextFormField(controller: description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'بابت چه چیزی؟',
              hintText: 'مثلاً دستمزد هفته دوم'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'شرح را وارد کن.' : null),
          const SizedBox(height: 10),
          TextFormField(controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مبلغ (تومان)'),
            validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0
              ? 'مبلغ معتبر وارد کن.' : null),
          const SizedBox(height: 10),
          if (widget.forecast) ...[
            DropdownButtonFormField<String>(initialValue: group,
              isExpanded: true,
              items: _ledgerGroups.map((e) => DropdownMenuItem(
                value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
              decoration: const InputDecoration(labelText: 'گروه هزینه'),
              onChanged: (value) => setState(() => group = value ?? group)),
            const SizedBox(height: 10),
          ],
          TextFormField(controller: source,
            decoration: const InputDecoration(labelText: 'توضیح / محل پرداخت (اختیاری)'),
            maxLines: 1),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _selectDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(jalaliDate(date)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _selectPhoto,
              icon: Icon(photo == null ? Icons.add_a_photo_outlined
                : Icons.check_circle_outline, size: 18),
              label: Text(photo == null ? 'عکس رسید' : 'رسید پیوست شد')))
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(context, _AccountingDraft(
              description.text.trim(), parseAmount(amount.text)!,
              source.text.trim(), date, photo, widget.forecast ? group : null));
          }, child: const Text('ثبت'))
        ]))));
}

class _AccountingPaymentDraft {
  const _AccountingPaymentDraft(this.amount, this.source,
    this.date, this.allocations, this.photo);
  final int amount;
  final String source;
  final DateTime date;
  final Map<String, int> allocations;
  final String? photo;
}

class _AccountingPaymentSheet extends StatefulWidget {
  const _AccountingPaymentSheet({required this.debts, required this.remaining});
  final List<Expense> debts;
  final Map<String, int> remaining;
  @override
  State<_AccountingPaymentSheet> createState() => _AccountingPaymentSheetState();
}

class _AccountingPaymentSheetState extends State<_AccountingPaymentSheet> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController(), source = TextEditingController();
  final selected = <String>{};
  bool manual = false;
  DateTime date = DateTime.now();
  String? photo;

  @override
  void dispose() {
    amount.dispose(); source.dispose();
    super.dispose();
  }

  Map<String, int> get preview => allocateOldestFirst(
    debts: widget.debts.map((e) => AccountingDebt(e.id, e.date, e.amount)),
    remaining: widget.remaining,
    amount: parseAmount(amount.text) ?? 0,
    prioritizedIds: manual ? selected : null);

  Future<void> _selectDate() async {
    final result = await pickPersianDate(context, initialDate: date,
      firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (result != null && mounted) setState(() => date = result);
  }

  Future<void> _selectPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery,
      imageQuality: 70, maxWidth: 1400);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photo = base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final allocations = preview;
    final amountValue = parseAmount(amount.text) ?? 0;
    final linked = allocations.values.fold<int>(0, (n, v) => n + v);
    return Padding(padding: EdgeInsets.fromLTRB(17, 17, 17,
      MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Form(key: form,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('ثبت پرداخت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('ابتدا ببین مبلغ کدام طلب‌ها را تسویه می‌کند.',
              style: TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 16),
            TextFormField(controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مبلغ پرداخت (تومان)'),
              onChanged: (_) => setState(() {}),
              validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0
                ? 'مبلغ معتبر وارد کن.' : null),
            const SizedBox(height: 10),
            TextField(controller: source,
              decoration: const InputDecoration(labelText: 'از محل / شماره پیگیری (اختیاری)')),
            const SizedBox(height: 11),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 17),
                label: Text(jalaliDate(date)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _selectPhoto,
                icon: const Icon(Icons.image_outlined, size: 17),
                label: Text(photo == null ? 'عکس پرداخت' : 'عکس پیوست شد')))
            ]),
            const SizedBox(height: 15),
            SegmentedButton<bool>(segments: const [
              ButtonSegment(value: false, label: Text('قدیمی‌ترین اول')),
              ButtonSegment(value: true, label: Text('انتخاب دستی')),
            ], selected: {manual}, onSelectionChanged: (v) =>
              setState(() => manual = v.first)),
            const SizedBox(height: 10),
            if (widget.debts.isEmpty)
              const Text('طلب بازی وجود ندارد؛ مبلغ به عنوان علی‌الحساب ثبت می‌شود.',
                style: TextStyle(fontSize: 12, color: muted)),
            for (final debt in widget.debts) ...[
              Builder(builder: (_) {
                final left = widget.remaining[debt.id] ?? debt.amount;
                final used = allocations[debt.id] ?? 0;
                final progress = debt.amount == 0 ? 1.0 :
                  (debt.amount - left + used) / debt.amount;
                return Container(margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      if (manual) Checkbox(value: selected.contains(debt.id),
                        onChanged: (v) => setState(() => v == true
                          ? selected.add(debt.id) : selected.remove(debt.id))),
                      Expanded(child: Text(debt.title,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Text(used > 0 ? 'پرداخت ${money(used)}' : 'مانده ${money(left)}',
                        style: const TextStyle(fontSize: 11, color: muted)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0),
                        minHeight: 7, backgroundColor: const Color(0xFFF2DFDD),
                        color: const Color(0xFF35A67C)))
                  ]));
              })
            ],
            if (amountValue > 0) ...[
              Text('تسویه طلب‌ها: ${money(linked)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              if (amountValue > linked) Text('علی‌الحساب بدون تخصیص: ${money(amountValue - linked)}',
                style: const TextStyle(color: muted, fontSize: 11)),
            ],
            const SizedBox(height: 13),
            FilledButton(onPressed: manual && selected.isEmpty ? null : () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, _AccountingPaymentDraft(amountValue,
                source.text.trim(), date, allocations, photo));
            }, child: const Text('تأیید و ثبت پرداخت'))
          ]))));
  }
}
