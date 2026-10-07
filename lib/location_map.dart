import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'demo_data.dart';

/// District positions are illustrative demo markers, never official borders.
class LocationMap extends StatefulWidget {
  const LocationMap(
      {super.key,
      required this.city,
      this.point,
      this.districts = const {},
      this.onDistrict,
      this.onPoint,
      this.height = 210,
      this.districtPreview = false});
  final CityArea city;
  final MapPoint? point;
  final Set<String> districts;
  final ValueChanged<String>? onDistrict;
  final ValueChanged<MapPoint>? onPoint;
  final double height;
  final bool districtPreview;
  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  bool tileFailed = false;
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFAF282B);
    final city = widget.city;
    final point = widget.point;
    final center =
        LatLng(point?.latitude ?? city.lat, point?.longitude ?? city.lon);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
              height: widget.height,
              child: Stack(children: [
                FlutterMap(
                    key: ValueKey('map-${city.name}'),
                    options: MapOptions(
                        initialCenter: center,
                        initialZoom: point == null ? 11.5 : 14,
                        onTap: widget.onPoint == null
                            ? null
                            : (_, p) => widget
                                .onPoint!(MapPoint(p.latitude, p.longitude)),
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.drag |
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.doubleTapZoom)),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'ir.sakhtyar.preview',
                          errorTileCallback: (_, __, ___) {
                            if (!tileFailed && mounted)
                              setState(() => tileFailed = true);
                          }),
                      MarkerLayer(
                          markers:
                              (widget.onDistrict != null ||
                                      widget.districtPreview)
                                  ? List.generate(city.districts.length, (i) {
                                      final d = city.districts[i];
                                      final selected =
                                          widget.districts.contains(d);
                                      return Marker(
                                          point: LatLng(
                                              city.lat + (i ~/ 3 - .5) * .026,
                                              city.lon + (i % 3 - 1) * .036),
                                          width: 108,
                                          height: 36,
                                          child: TextButton(
                                              key: ValueKey('map-district-$d'),
                                              onPressed: widget.onDistrict == null
                                                  ? null
                                                  : () => widget.onDistrict!(d),
                                              style: TextButton.styleFrom(
                                                  backgroundColor: selected
                                                      ? accent
                                                      : Colors.white,
                                                  foregroundColor: selected
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 4),
                                                  side: BorderSide(
                                                      color: selected
                                                          ? accent
                                                          : const Color(
                                                              0xFFD8DBDF))),
                                              child: Text(
                                                  '${selected ? '✓ ' : ''}$d',
                                                  style: const TextStyle(fontSize: 10))));
                                    })
                                  : [
                                      Marker(
                                          point: center,
                                          width: 42,
                                          height: 48,
                                          child: Tooltip(
                                              message: point == null
                                                  ? 'محدوده کلی شهر؛ محل دقیق ثبت نشده'
                                                  : 'نقطه ثبت‌شده توسط آگهی‌دهنده',
                                              child: Icon(
                                                  point == null
                                                      ? Icons.location_searching
                                                      : Icons.location_on,
                                                  color: accent,
                                                  size: 34)))
                                    ]),
                    ]),
                const Positioned(
                    bottom: 0,
                    left: 0,
                    child: ColoredBox(
                        color: Colors.white,
                        child: Padding(
                            padding: EdgeInsets.all(3),
                            child: Text('© OpenStreetMap contributors',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(fontSize: 9))))),
                if (tileFailed)
                  Positioned(
                      top: 6,
                      left: 6,
                      right: 6,
                      child: Container(
                          padding: const EdgeInsets.all(7),
                          color: Colors.white,
                          child: Row(children: [
                            const Expanded(
                                child: Text(
                                    'نقشه بارگذاری نشد؛ انتخاب شهر و محله همچنان فعال است.',
                                    style: TextStyle(fontSize: 10))),
                            TextButton(
                                onPressed: () =>
                                    setState(() => tileFailed = false),
                                child: const Text('بستن',
                                    style: TextStyle(fontSize: 10)))
                          ]))),
              ]))),
      Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
              (widget.onDistrict != null || widget.districtPreview)
                  ? 'جای محله‌ها در دمو نمایشی است؛ مرز رسمی نیست.'
                  : widget.onPoint != null
                      ? 'برای ثبت محل، روی نقشه بزن. نقطه دقیق اختیاری است.'
                      : point == null
                          ? 'محدوده کلی ${city.name}؛ نقطه دقیق ثبت نشده.'
                          : 'محل ثبت‌شده توسط آگهی‌دهنده',
              style: const TextStyle(fontSize: 10, color: Color(0xFF777B84)))),
    ]);
  }
}
