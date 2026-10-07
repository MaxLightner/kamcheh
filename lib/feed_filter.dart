import 'demo_data.dart';
import 'marketplace.dart';
import 'network_data.dart';

enum FeedSort { newest, cheapest, mostExpensive }

const _unchanged = Object();

class FeedFilter {
  const FeedFilter(
      {this.category = 'همه',
      this.kind,
      this.skill = '',
      this.activity,
      this.verifiedOnly = false,
      this.unit,
      this.minPrice,
      this.maxPrice,
      this.sort = FeedSort.newest});
  final String category, skill;
  final AdKind? kind;
  final ActivityType? activity;
  final bool verifiedOnly;
  final PriceUnit? unit;
  final int? minPrice, maxPrice;
  final FeedSort sort;

  FeedFilter copyWith(
          {String? category,
          String? skill,
          Object? kind = _unchanged,
          Object? activity = _unchanged,
          Object? unit = _unchanged,
          Object? minPrice = _unchanged,
          Object? maxPrice = _unchanged,
          bool? verifiedOnly,
          FeedSort? sort}) =>
      FeedFilter(
          category: category ?? this.category,
          skill: skill ?? this.skill,
          kind: identical(kind, _unchanged) ? this.kind : kind as AdKind?,
          activity: identical(activity, _unchanged)
              ? this.activity
              : activity as ActivityType?,
          unit: identical(unit, _unchanged) ? this.unit : unit as PriceUnit?,
          minPrice: identical(minPrice, _unchanged)
              ? this.minPrice
              : minPrice as int?,
          maxPrice: identical(maxPrice, _unchanged)
              ? this.maxPrice
              : maxPrice as int?,
          verifiedOnly: verifiedOnly ?? this.verifiedOnly,
          sort: sort ?? this.sort);

  FeedFilter selectCategory(String value) => copyWith(
      category: value,
      kind: null,
      skill: '',
      unit: null,
      minPrice: null,
      maxPrice: null,
      sort: FeedSort.newest);
  FeedFilter clearPrice() => copyWith(
      unit: null, minPrice: null, maxPrice: null, sort: FeedSort.newest);
  int get count => [
        category != 'همه',
        kind != null,
        skill.isNotEmpty,
        activity != null,
        verifiedOnly,
        unit != null,
        minPrice != null || maxPrice != null,
        sort != FeedSort.newest
      ].where((v) => v).length;

  bool matches(Ad ad,
      {required AreaFilter area, String query = '', bool closed = false}) {
    if (closed || !area.matches(ad)) return false;
    if (category != 'همه' && category != ad.category) return false;
    if (kind != null && kind != ad.kind) return false;
    if (skill.isNotEmpty && !adSkills(ad).contains(skill)) return false;
    final profile = profileFor(ad);
    if (activity != null && profile.activity != activity) return false;
    if (verifiedOnly && !profile.verified) return false;
    final pricing = ad.pricing;
    if (unit != null && (pricing == null || pricing.unit != unit)) return false;
    if (minPrice != null && (pricing == null || pricing.amount < minPrice!))
      return false;
    if (maxPrice != null && (pricing == null || pricing.amount > maxPrice!))
      return false;
    final words =
        normalizeMarketText(query).split(' ').where((v) => v.isNotEmpty);
    final haystack = normalizeMarketText(
        '${ad.title} ${ad.owner} ${ad.area} ${ad.description} ${adSkills(ad).join(' ')} ${profile.specialty} ${profile.activity.label} ${ad.kind.label}');
    return words.every(haystack.contains);
  }

  List<Ad> apply(Iterable<Ad> ads,
      {required AreaFilter area,
      String query = '',
      bool Function(Ad)? isClosed}) {
    final result = ads
        .where((ad) => matches(ad,
            area: area, query: query, closed: isClosed?.call(ad) ?? false))
        .toList();
    // Only compare amounts when an explicit, common price unit is selected.
    if (unit != null && sort != FeedSort.newest) {
      result.sort((a, b) {
        final amount = a.pricing!.amount.compareTo(b.pricing!.amount);
        final ordered = sort == FeedSort.cheapest ? amount : -amount;
        return ordered == 0 ? a.id.compareTo(b.id) : ordered;
      });
    }
    return result;
  }
}
