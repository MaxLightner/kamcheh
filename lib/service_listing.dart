import 'marketplace.dart';
import 'dart:convert';
import 'dart:typed_data';

/// A provider's promotion, independent of a customer's request and its bids.
class ServiceListing {
  ServiceListing(
      {required this.id,
      required this.ownerId,
      required this.title,
      required this.details,
      required this.city,
      this.district = '',
      this.category = 'خدمات',
      this.image = 'concrete',
      this.price = 'با توافق',
      this.amount,
      this.unit = PriceUnit.project,
      this.skills = const [],
      this.archived = false,
      this.enabled = true,
      this.photos = const [],
      this.galleryAssets = const [],
      DateTime? createdAt,
      DateTime? updatedAt})
      : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();
  final String id, ownerId;
  String title, details, city, district, category, image, price;
  int? amount;
  PriceUnit unit;
  List<String> skills;
  bool archived;
  bool enabled;
  List<Uint8List> photos;
  List<String> galleryAssets;
  final DateTime createdAt;
  DateTime updatedAt;
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'details': details,
        'city': city,
        'district': district,
        'category': category,
        'image': image,
        'price': price,
        'amount': amount,
        'unit': unit.name,
        'skills': skills,
        'archived': archived,
        'enabled': enabled,
        'photos': photos.map(base64Encode).toList(),
        'galleryAssets': galleryAssets,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
  factory ServiceListing.fromJson(Map<String, dynamic> j) => ServiceListing(
      id: j['id'],
      ownerId: j['ownerId'],
      title: j['title'],
      details: j['details'],
      city: j['city'],
      district: j['district'] ?? '',
      category: j['category'],
      image: j['image'],
      price: j['price'] ?? 'با توافق',
      amount: j['amount'],
      unit: PriceUnit.values.byName(j['unit']),
      skills: List<String>.from(j['skills'] ?? []),
      archived: j['archived'] ?? false,
      enabled: j['enabled'] ?? true,
      photos: (j['photos'] as List? ?? []).map((p) => base64Decode(p)).toList(),
      galleryAssets: List<String>.from(j['galleryAssets'] ??
          (RegExp(r'^(a\d+|m\d+|own-build)$').hasMatch(j['id'])
              ? [j['image'], 'concrete', 'scaffold'].toSet().toList()
              : [])),
      createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt']),
      updatedAt:
          j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt']));
}

enum ServiceContactKind { quote, cooperation, visit, conversation }

extension ServiceContactLabel on ServiceContactKind {
  String get label => switch (this) {
        ServiceContactKind.quote => 'درخواست پیش‌فاکتور',
        ServiceContactKind.cooperation => 'پیشنهاد همکاری',
        ServiceContactKind.visit => 'درخواست بازدید',
        ServiceContactKind.conversation => 'درخواست گفتگو',
      };
}

class ServiceContact {
  ServiceContact(this.id, this.serviceId, this.fromId, this.kind, this.details,
      {this.amount,
      this.unit = PriceUnit.project,
      this.visitAt,
      DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  final String id, serviceId, fromId;
  final ServiceContactKind kind;
  final String details;
  final int? amount;
  final PriceUnit unit;
  final DateTime? visitAt;
  final DateTime createdAt;
  String status = 'pending';
  Map<String, dynamic> toJson() => {
        'id': id,
        'serviceId': serviceId,
        'fromId': fromId,
        'kind': kind.name,
        'details': details,
        'amount': amount,
        'unit': unit.name,
        'visitAt': visitAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'status': status
      };
  factory ServiceContact.fromJson(Map<String, dynamic> j) => ServiceContact(
      j['id'],
      j['serviceId'],
      j['fromId'],
      ServiceContactKind.values.byName(j['kind']),
      j['details'],
      amount: j['amount'],
      unit: PriceUnit.values.byName(j['unit']),
      visitAt: j['visitAt'] == null ? null : DateTime.parse(j['visitAt']),
      createdAt: DateTime.parse(j['createdAt']))
    ..status = j['status'];
}
