import 'demo_data.dart';
import 'marketplace.dart';
import 'work_repository.dart';

/// Filters describe what is needed, never the request owner's profession.
class RequestFilter {
  const RequestFilter(
      {this.category = 'همه', this.skill, this.crewOnly = false});
  final String category;
  final String? skill;
  final bool crewOnly;
  List<WorkNeed> apply(Iterable<WorkNeed> needs,
      {required AreaFilter area, String query = '', DateTime? now}) {
    final text = normalizeMarketText(query);
    return needs
        .where((n) {
          if (!n.acceptsAt(now ?? DateTime.now())) return false;
          if (category != 'همه' && n.category != category) return false;
          if (crewOnly && !n.crew) return false;
          if (skill != null && !n.skills.contains(skill)) return false;
          final location = Ad(n.id, n.title, n.category, true, n.city,
              n.district, n.image, '', '');
          return area.matches(location) &&
              (text.isEmpty ||
                  normalizeMarketText(
                          '${n.title} ${n.details} ${n.skills.join(' ')}')
                      .contains(text));
        })
        .toList()
        .reversed
        .toList();
  }
}
