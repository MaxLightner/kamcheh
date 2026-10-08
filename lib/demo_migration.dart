import 'demo_data.dart';
import 'service_listing.dart';
import 'user_profile.dart';
import 'work_repository.dart';

/// Only known seed records are moved. User-created records and conversations stay intact.
void migrateStructureDemo(DemoWorkRepository store,
    Iterable<UserProfile> profiles, Iterable<ServiceListing> seededServices) {
  for (final s in seededServices) {
    store.services.putIfAbsent(s.id, () => s);
  }
  for (final n in store.needs.values) {
    if (n.id == 'a24' && n.title.contains('نقشه‌بردار')) {
      n.skills = n.skills.where((s) => s != 'طراحی معماری').toList();
    }
    if (!RegExp(r'^(a\d+|m\d+|own-(labor|tile|scaffold|build))$')
        .hasMatch(n.id)) continue;
    if (cityByName(n.city).province == 'خراسان رضوی') continue;
    n.city = 'مشهد';
    n.district = 'الهیه';
    n.title = n.title.replaceAll('کرج', 'مشهد').replaceAll('گوهردشت', 'الهیه');
    n.details =
        n.details.replaceAll('کرج', 'مشهد').replaceAll('گوهردشت', 'الهیه');
    if (n.privateAddress == 'نشانی نمونه: کرج، گوهردشت، محل پروژه')
      n.privateAddress = 'نشانی نمونه: مشهد، الهیه، محل پروژه';
    if (n.latitude != null) {
      n.latitude = 36.30;
      n.longitude = 59.58;
    }
  }
  for (final p in profiles) {
    if (p.id.startsWith('demo-person-') && p.bio == 'نقشه‌برداری و کنترل تراز')
      p.skills.remove('طراحی معماری');
    if (p.id != 'profile-sample' &&
        !p.id.startsWith('demo-person-') &&
        !p.id.startsWith('demo-design-') &&
        !p.id.startsWith('owner-')) continue;
    if (p.city == null || cityByName(p.city!).province == 'خراسان رضوی')
      continue;
    p.city = 'مشهد';
    p.coverage = const AreaFilter(
        province: 'خراسان رضوی', city: 'مشهد', surroundings: true);
    p.bio = p.bio.replaceAll('کرج', 'مشهد');
  }
}
