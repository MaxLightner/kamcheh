import 'marketplace.dart';

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
      this.archived = false});
  final String id, ownerId;
  String title, details, city, district, category, image, price;
  int? amount;
  PriceUnit unit;
  List<String> skills;
  bool archived;
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
        'archived': archived
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
      archived: j['archived'] ?? false);
}
