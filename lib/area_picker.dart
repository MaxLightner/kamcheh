import 'package:flutter/material.dart';
import 'location_map.dart';
import 'demo_data.dart';

class AreaPicker extends StatefulWidget {
  const AreaPicker(
      {super.key,
      required this.initial,
      this.requireCity = false,
      this.showMap = true,
      this.pickLocation = false,
      this.initialPoint,
      this.coverage = false});
  final AreaFilter initial;
  final bool requireCity, showMap, pickLocation, coverage;
  final MapPoint? initialPoint;
  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  late String? province = widget.initial.province, city = widget.initial.city;
  late final selected = Set<String>.from(widget.initial.districts);
  late bool surroundings = widget.initial.surroundings;
  late MapPoint? point = widget.initialPoint;
  void toggle(String value) => setState(() {
        if (selected.contains(value)) {
          selected.remove(value);
        } else {
          if (widget.requireCity) selected.clear();
          selected.add(value);
        }
      });
  @override
  Widget build(BuildContext context) {
    final current = city == null ? null : cityByName(city!);
    final provinces = cities.map((c) => c.province).toSet().toList()..sort();
    final options = cities
        .where((c) => province == null || c.province == province)
        .toList();
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                widget.coverage
                                    ? 'محدوده فعالیت'
                                    : widget.requireCity
                                        ? 'محل آگهی'
                                        : 'محدوده جست‌وجو',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                        TextButton(
                            onPressed: () {
                              setState(() {
                                province = null;
                                city = null;
                                selected.clear();
                                surroundings = false;
                                point = null;
                              });
                            },
                            child: const Text('پاک کردن')),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20))
                      ])),
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('استان',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: ValueKey('province-$province'),
                                    initialValue: province,
                                    decoration: const InputDecoration(
                                        hintText: 'همه استان‌ها'),
                                    items: [
                                      const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('همه استان‌ها')),
                                      ...provinces.map((p) => DropdownMenuItem(
                                          value: p, child: Text(p)))
                                    ],
                                    onChanged: (p) => setState(() {
                                          province = p;
                                          city = null;
                                          selected.clear();
                                          surroundings = false;
                                          point = null;
                                        })),
                                const SizedBox(height: 12),
                                const Text('شهر',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    key: ValueKey('city-$province-$city'),
                                    initialValue: city,
                                    decoration: InputDecoration(
                                        hintText: province == null
                                            ? 'همه شهرها'
                                            : 'همه شهرهای استان'),
                                    items: [
                                      const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('همه شهرها')),
                                      ...options.map((c) => DropdownMenuItem(
                                          value: c.name, child: Text(c.name)))
                                    ],
                                    onChanged: (c) => setState(() {
                                          city = c;
                                          if (c != null)
                                            province = cityByName(c).province;
                                          selected.clear();
                                          surroundings = false;
                                          point = null;
                                        })),
                                if (current != null) ...[
                                  if (current.nearby.isNotEmpty &&
                                      !widget.requireCity)
                                    CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        value: surroundings,
                                        onChanged: (v) =>
                                            setState(() => surroundings = v!),
                                        title: Text('$city و شهرهای اطراف',
                                            style:
                                                const TextStyle(fontSize: 13)),
                                        subtitle: Text(
                                            current.nearby.join('، '),
                                            style:
                                                const TextStyle(fontSize: 11))),
                                  const SizedBox(height: 8),
                                  Text(
                                      widget.requireCity
                                          ? 'محله · انتخاب اختیاری'
                                          : 'محله‌ها · انتخاب چندتایی',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 8),
                                  if (widget.showMap)
                                    LocationMap(
                                        key: ValueKey('area-map-$city'),
                                        city: current,
                                        point: point,
                                        districts: selected,
                                        onDistrict:
                                            widget.pickLocation ? null : toggle,
                                        onPoint: widget.pickLocation
                                            ? (p) => setState(() => point = p)
                                            : null),
                                  if (widget.pickLocation && point != null)
                                    TextButton.icon(
                                        onPressed: () =>
                                            setState(() => point = null),
                                        icon: const Icon(
                                            Icons.location_off_outlined,
                                            size: 16),
                                        label: const Text('حذف نقطه دقیق',
                                            style: TextStyle(fontSize: 11))),
                                  const SizedBox(height: 8),
                                  Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: current.districts
                                          .map((d) => FilterChip(
                                              key: ValueKey('district-chip-$d'),
                                              label: Text(d,
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              selected: selected.contains(d),
                                              onSelected: (_) => toggle(d),
                                              visualDensity:
                                                  VisualDensity.compact))
                                          .toList()),
                                  Text(
                                      selected.isEmpty
                                          ? 'بدون انتخاب محله، تمام $city نمایش داده می‌شود.'
                                          : '${selected.length} محله انتخاب شده',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF777B84))),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'فهرست شهرها و جانمایی محله‌ها در این پیش‌نمایش نمونه‌اند.',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF777B84))),
                                ] else
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 18),
                                      child: Text(
                                          'برای انتخاب محله روی نقشه، ابتدا شهر را انتخاب کن.',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF777B84)))),
                              ]))),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                          onPressed: widget.requireCity && city == null
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  widget.pickLocation
                                      ? AdLocation(
                                          AreaFilter(
                                              province: province,
                                              city: city,
                                              districts: Set.from(selected)),
                                          point)
                                      : AreaFilter(
                                          province: province,
                                          city: city,
                                          districts: Set.from(selected),
                                          surroundings: surroundings)),
                          child: Text(widget.requireCity
                              ? 'تأیید محل'
                              : widget.coverage
                                  ? 'تأیید محدوده فعالیت'
                                  : 'نمایش آگهی‌ها'))),
                ]))));
  }
}
