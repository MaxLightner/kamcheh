part of 'main.dart';

const accountingGroups = [
  'حمل و مصالح',
  'تجهیزات و نیازمندی کارگاه',
  'حقوق پرسنل',
  'اداری و پذیرایی',
  'مهندسی',
  'متفرقه'
];
const accountingStages = [
  'آماده‌سازی و خاک‌برداری',
  'فنداسیون',
  'اسکلت',
  'دیوارچینی',
  'تأسیسات',
  'نازک‌کاری',
  'نما',
  'محوطه‌سازی',
  'عمومی'
];

extension AccountingUi on _AppShellState {
  Future<void> editAccounting({Expense? existing, bool receipt = false}) async {
    if (!canAct) {
      await ensureAccess(
          () => editAccounting(existing: existing, receipt: receipt));
      return;
    }
    final owner = actorId;
    final result = await Navigator.of(context).push<Expense>(MaterialPageRoute(
        builder: (_) => AccountingEntryPage(
            existing: existing, receipt: existing?.income ?? receipt)));
    if (result == null || !mounted || owner != actorId) return;
    update(() {
      final index = existing == null
          ? -1
          : expenses.indexWhere((e) => e.id == existing.id);
      if (index < 0)
        expenses.insert(0, result);
      else
        expenses[index] = result;
    });
    notice(existing == null ? 'ثبت شد' : 'ویرایش ذخیره شد');
  }

  Future<void> removeAccounting(Expense entry) async {
    final owner = actorId;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('حذف ردیف حسابداری؟'),
                content: Text('${entry.title}\n${money(entry.amount)} تومان'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('حذف'))
                ]));
    if (yes == true && mounted && owner == actorId)
      update(() => expenses.removeWhere((e) => e.id == entry.id));
  }

  List<Widget> accountingView() {
    final costs = expenses.where((e) => !e.income).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final receipts = expenses.where((e) => e.income).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final debt = costs
        .where((e) => e.accountType == 'بدهی')
        .fold<int>(0, (n, e) => n + e.amount);
    final payments = costs
        .where((e) => e.accountType != 'بدهی')
        .fold<int>(0, (n, e) => n + e.amount);
    final received = receipts.fold<int>(0, (n, e) => n + e.amount);
    final rows = accountingTab == 0 ? costs : receipts;
    Widget value(int amount) => Text('${money(amount)} تومان',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
    DataCell cell(String text) =>
        DataCell(Text(text, style: const TextStyle(fontSize: 11)));
    return [
      SegmentedButton<int>(segments: const [
        ButtonSegment(
            value: 0,
            icon: Icon(Icons.receipt_long_outlined, size: 17),
            label: Text('هزینه‌ها')),
        ButtonSegment(
            value: 1,
            icon: Icon(Icons.account_balance_wallet_outlined, size: 17),
            label: Text('دفتر کل'))
      ], selected: {
        accountingTab
      }, onSelectionChanged: (s) => setState(() => accountingTab = s.first)),
      const SizedBox(height: 12),
      if (accountingTab == 1) ...[
        panel([
          Row(children: [
            const Expanded(child: Text('جمع بدهی‌ها')),
            value(debt)
          ]),
          const Divider(),
          Row(children: [
            const Expanded(child: Text('جمع هزینه‌ها')),
            value(payments)
          ]),
          small('تسویه و علی‌الحساب؛ بدون بدهی'),
          const Divider(),
          Row(children: [
            const Expanded(child: Text('مانده تنخواه')),
            value(received - payments)
          ]),
          small('دریافتی‌های تنخواه منهای تسویه و علی‌الحساب'),
          const Divider(),
          Row(children: [
            const Expanded(child: Text('کل مخارج')),
            value(debt + payments)
          ]),
        ]),
        section('دریافتی‌های تنخواه'),
      ],
      button(accountingTab == 0 ? 'ثبت هزینه' : 'ثبت دریافتی تنخواه',
          () => editAccounting(receipt: accountingTab == 1),
          icon: Icons.add),
      if (rows.isEmpty)
        emptyState(
            accountingTab == 0
                ? 'هنوز هزینه‌ای ثبت نشده'
                : 'هنوز تنخواهی دریافت نشده',
            'از دکمه بالا اولین ردیف را ثبت کن.'),
      if (rows.isNotEmpty) ...[
        small(
            'برای دیدن تمام ستون‌ها جدول را افقی جابه‌جا کن. از منوی هر ردیف ویرایش یا حذف کن.'),
        const SizedBox(height: 6),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 66,
                columnSpacing: 18,
                horizontalMargin: 8,
                headingRowColor:
                    const WidgetStatePropertyAll(Color(0xFFFFF5F3)),
                columns: (accountingTab == 0
                        ? [
                            'تاریخ',
                            'شرح',
                            'از محل',
                            'مبلغ (تومان)',
                            'نوع حساب',
                            'گروه',
                            'مرحله',
                            ''
                          ]
                        : ['تاریخ', 'از محل', 'مبلغ (تومان)', 'شرح', ''])
                    .map((title) => DataColumn(
                        label: Text(title,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold))))
                    .toList(),
                rows: rows
                    .map((e) => DataRow(key: ValueKey(e.id), cells: [
                          cell(jalaliDate(e.date)),
                          if (accountingTab == 0) cell(e.title),
                          cell(e.source.isEmpty ? '—' : e.source),
                          cell(money(e.amount)),
                          if (accountingTab == 0) ...[
                            cell(e.accountType),
                            cell(e.category),
                            cell(e.stage.isEmpty ? '—' : e.stage)
                          ] else
                            cell(e.title),
                          DataCell(PopupMenuButton<String>(
                              tooltip: 'مدیریت ردیف',
                              iconSize: 18,
                              itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('ویرایش')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('حذف'))
                                  ],
                              onSelected: (v) => v == 'edit'
                                  ? editAccounting(existing: e)
                                  : removeAccounting(e))),
                        ]))
                    .toList())),
      ],
      const SizedBox(height: 12),
      small(
          'حسابداری خصوصی همین حساب؛ در نسخه آزمایشی روی همین دستگاه ذخیره می‌شود. برای تسویه یک بدهی، همان ردیف را ویرایش کن تا دوباره در مخارج شمرده نشود.'),
    ];
  }
}

class AccountingEntryPage extends StatefulWidget {
  const AccountingEntryPage({this.existing, required this.receipt});
  final Expense? existing;
  final bool receipt;
  @override
  State<AccountingEntryPage> createState() => _AccountingEntryPageState();
}

class _AccountingEntryPageState extends State<AccountingEntryPage> {
  final form = GlobalKey<FormState>();
  late final description =
      TextEditingController(text: widget.existing?.title ?? '');
  late final source =
      TextEditingController(text: widget.existing?.source ?? '');
  late final amount =
      TextEditingController(text: widget.existing?.amount.toString() ?? '');
  late DateTime date = widget.existing?.date ?? DateTime.now();
  late String type = widget.existing?.accountType ?? 'تسویه';
  late String group = accountingGroups.contains(widget.existing?.category)
      ? widget.existing!.category
      : switch (widget.existing?.category) {
          'مصالح' || 'حمل‌ونقل' => accountingGroups[0],
          'تجهیزات' => accountingGroups[1],
          'دستمزد' => accountingGroups[2],
          _ => accountingGroups[5]
        };
  late String stage = accountingStages.contains(widget.existing?.stage)
      ? widget.existing!.stage
      : 'عمومی';
  @override
  void dispose() {
    description.dispose();
    source.dispose();
    amount.dispose();
    super.dispose();
  }

  Widget field(String title, TextEditingController controller,
          {String? hint, bool numeric = false, bool required = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextFormField(
              controller: controller,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                  labelText: title, hintText: hint, isDense: true),
              maxLines: numeric ? 1 : 2,
              minLines: 1,
              validator: (v) {
                if (required && (v ?? '').trim().isEmpty)
                  return '$title را وارد کن.';
                if (numeric && (parseAmount(v ?? '') ?? 0) <= 0)
                  return 'مبلغ مثبت و معتبر وارد کن.';
                return null;
              }));
  Widget dropdown(String title, String value, List<String> options,
          ValueChanged<String> change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: title, isDense: true),
              items: options
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (s) => setState(() => change(s!))));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(
              '${widget.existing == null ? 'ثبت' : 'ویرایش'} ${widget.receipt ? 'دریافتی تنخواه' : 'هزینه'}')),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                  key: form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    OutlinedButton.icon(
                        onPressed: () async {
                          final result = await pickPersianDate(context,
                              initialDate: date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100));
                          if (result != null && mounted)
                            setState(() => date = result);
                        },
                        icon:
                            const Icon(Icons.calendar_month_outlined, size: 18),
                        label: Text('تاریخ: ${jalaliDate(date)}')),
                    const SizedBox(height: 14),
                    field('شرح', description, required: true),
                    field('از محل', source,
                        hint: 'مثلاً نقدی، تهاتر، بانک ملی یا چک'),
                    field('مبلغ (تومان)', amount,
                        numeric: true, required: true),
                    if (!widget.receipt) ...[
                      dropdown(
                          'نوع حساب',
                          type,
                          const ['بدهی', 'تسویه', 'علی‌الحساب'],
                          (v) => type = v),
                      dropdown(
                          'گروه', group, accountingGroups, (v) => group = v),
                      dropdown(
                          'مرحله', stage, accountingStages, (v) => stage = v),
                    ],
                    FilledButton.icon(
                        onPressed: () {
                          if (!form.currentState!.validate()) return;
                          Navigator.pop(
                              context,
                              Expense(
                                  description.text.trim(),
                                  widget.receipt ? '' : group,
                                  parseAmount(amount.text)!,
                                  widget.receipt || type != 'بدهی',
                                  income: widget.receipt,
                                  source: source.text.trim(),
                                  stage: widget.receipt ? '' : stage,
                                  accountType: widget.receipt ? 'تسویه' : type,
                                  date: date,
                                  restoredId: widget.existing?.id));
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('ذخیره')),
                  ])))));
}
