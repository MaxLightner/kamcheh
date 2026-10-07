import 'dart:typed_data';
import 'demo_data.dart';
import 'marketplace.dart';

/// Editable snapshots are kept separately from published listings in the demo.
class AdDraft {
  AdDraft(
      {required this.id,
      required this.category,
      required this.kind,
      required this.values,
      required this.area,
      required this.skills,
      required this.photos,
      this.editingId,
      this.point,
      this.serviceArea,
      this.priceUnit})
      : updatedAt = DateTime.now();
  final String id, category;
  final String? editingId;
  final AdKind kind;
  final Map<String, String> values;
  final AreaFilter area;
  final MapPoint? point;
  final AreaFilter? serviceArea;
  final PriceUnit? priceUnit;
  final List<String> skills;
  final List<Uint8List> photos;
  final DateTime updatedAt;
  String get title => values['title']?.trim().isNotEmpty == true
      ? values['title']!.trim()
      : 'آگهی بدون عنوان';
}
