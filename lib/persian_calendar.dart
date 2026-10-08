import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

String persianDigits(Object value) => value
    .toString()
    .replaceAllMapped(RegExp('[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);
String jalaliDate(DateTime date, {bool withTime = false}) {
  final j = Jalali.fromDateTime(date.toLocal());
  final time = withTime
      ? ' · ${date.toLocal().hour}:${date.toLocal().minute.toString().padLeft(2, '0')}'
      : '';
  return persianDigits(
      '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}$time');
}

Future<DateTime?> pickPersianDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) =>
    showDialog<DateTime>(
        context: context,
        builder: (_) => _PersianDatePicker(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate));

class _PersianDatePicker extends StatefulWidget {
  const _PersianDatePicker(
      {required this.initialDate,
      required this.firstDate,
      required this.lastDate});
  final DateTime initialDate, firstDate, lastDate;
  @override
  State<_PersianDatePicker> createState() => _PersianDatePickerState();
}

class _PersianDatePickerState extends State<_PersianDatePicker> {
  late Jalali selected = Jalali.fromDateTime(widget.initialDate);
  late Jalali month = Jalali(selected.year, selected.month);
  DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool enabled(Jalali j) =>
      !j.toDateTime().isBefore(dayOnly(widget.firstDate)) &&
      !j.toDateTime().isAfter(dayOnly(widget.lastDate));
  bool canMove(int delta) {
    final next = month.addMonths(delta);
    return delta < 0
        ? !Jalali(next.year, next.month, next.monthLength)
            .toDateTime()
            .isBefore(dayOnly(widget.firstDate))
        : !next.toDateTime().isAfter(dayOnly(widget.lastDate));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('تاریخ بازدید · شمسی'),
        content: SingleChildScrollView(
            child: SizedBox(
                width: 310,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    IconButton(
                        tooltip: 'ماه قبل',
                        onPressed: canMove(-1)
                            ? () => setState(() => month = month.addMonths(-1))
                            : null,
                        icon: const Icon(Icons.chevron_right)),
                    Expanded(
                        child: Text(
                            '${month.formatter.mN} ${persianDigits(month.year)}',
                            textAlign: TextAlign.center)),
                    IconButton(
                        tooltip: 'ماه بعد',
                        onPressed: canMove(1)
                            ? () => setState(() => month = month.addMonths(1))
                            : null,
                        icon: const Icon(Icons.chevron_left)),
                  ]),
                  Row(
                      children: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
                          .map((d) => Expanded(child: Center(child: Text(d))))
                          .toList()),
                  const SizedBox(height: 8),
                  GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7),
                      itemCount: month.weekDay - 1 + month.monthLength,
                      itemBuilder: (_, index) {
                        final day = index - (month.weekDay - 1) + 1;
                        if (day < 1) return const SizedBox.shrink();
                        final j = Jalali(month.year, month.month, day);
                        final chosen = selected.year == j.year &&
                            selected.month == j.month &&
                            selected.day == day;
                        return TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: chosen
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : null),
                            onPressed: enabled(j)
                                ? () => setState(() => selected = j)
                                : null,
                            child: Text(persianDigits(day)));
                      }),
                  const SizedBox(height: 8),
                  Text(jalaliDate(selected.toDateTime())),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: enabled(selected)
                  ? () => Navigator.pop(context, selected.toDateTime())
                  : null,
              child: const Text('انتخاب تاریخ'))
        ],
      );
}
