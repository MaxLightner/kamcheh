import 'user_profile.dart';
import 'marketplace.dart';

const rulesVersion = 'demo-2026-10-08';
const rulesText = '''قوانین نسخه آزمایشی کمچه

این نسخه برای آزمایش رابط و مسیرها با داده نمونه است. پیام، پیشنهاد، عضویت و قرارداد به اشخاص واقعی ارسال نمی‌شوند. اطلاعات این دمو روی همین دستگاه و مرورگر ذخیره می‌شود؛ میان دستگاه‌ها همگام نیست.

اطلاعات پروفایل و نمونه‌کار باید متعلق به شما یا با اجازه صاحب آن باشد. شماره تأییدشده به معنای تأیید هویت، تخصص یا کیفیت کار نیست.

افزودن عضو اکیپ نیاز به تأیید او دارد. حذف عضو نیاز به تأیید ندارد و به او اعلام می‌شود. عضویت در چند اکیپ مجاز است؛ عضویت مستقیم برگشتی مجاز نیست.

درخواست و پیشنهاد باید روشن و واقعی باشند. مبلغ، واحد، زمان و شرایط را پیش از توافق بررسی کنید. تصمیم انتخاب و اجرای همکاری با طرفین است.

از انتشار اطلاعات خصوصی دیگران، محتوای خلاف واقع و پیام مزاحم خودداری کنید. نظرها باید درباره تجربه خودتان باشند و امکان گزارش محتوا وجود خواهد داشت.

نسخه نهایی قوانین پیش از عرضه واقعی منتشر می‌شود. این متن مقررات استفاده از دموی فعلی است.''';

enum TeamLinkStatus { invited, active, declined, removed }

class TeamLink {
  TeamLink(this.id, this.ownerId, this.memberId);
  final String id, ownerId, memberId;
  TeamLinkStatus status = TeamLinkStatus.invited;
}

class AccountNotice {
  AccountNotice(this.profileId, this.text);
  final String profileId, text;
  final DateTime createdAt = DateTime.now();
}

class RulesAcceptance {
  RulesAcceptance(this.profileId, this.version);
  final String profileId, version;
  final DateTime acceptedAt = DateTime.now();
}

// Stable records shared by the demo and a future server adapter.
class RequestRecord {
  const RequestRecord(
      {required this.id,
      required this.ownerId,
      required this.title,
      required this.specialtyId,
      this.crewRequired = false,
      this.fields = const {}});
  final String id, ownerId, title, specialtyId;
  final bool crewRequired;
  final Map<String, Object?> fields;
}

class ProposalRecord {
  const ProposalRecord(
      this.id, this.requestId, this.profileId, this.price, this.terms);
  final String id, requestId, profileId, terms;
  final MarketPrice price;
}

class VisitDraft {
  const VisitDraft(this.id, this.requestId, this.fromProfileId,
      this.toProfileId, this.at, this.place);
  final String id, requestId, fromProfileId, toProfileId, place;
  final DateTime at;
}

class MessageRecord {
  const MessageRecord(
      this.id, this.conversationId, this.senderId, this.text, this.sentAt);
  final String id, conversationId, senderId, text;
  final DateTime sentAt;
}

class ContractRecord {
  const ContractRecord(this.id, this.ownerId, this.templateId, this.fields);
  final String id, ownerId, templateId;
  final Map<String, String> fields;
}

class CreditEntry {
  const CreditEntry(
      this.id, this.profileId, this.actionId, this.delta, this.at);
  final String id, profileId, actionId;
  final int delta;
  final DateTime at;
}

abstract class ProfileRepository {
  Iterable<UserProfile> get profiles;
  UserProfile? profile(String id);
  void save(UserProfile value);
  Iterable<TeamLink> members(String ownerId);
  Iterable<TeamLink> invitations(String memberId);
  String? invite(String ownerId, String memberId);
  String? accept(String linkId, String actorId);
  void decline(String linkId, String actorId);
  void remove(String linkId, String actorId);
}

class DemoProfileRepository implements ProfileRepository {
  final _profiles = <String, UserProfile>{};
  final links = <TeamLink>[];
  final notices = <AccountNotice>[];
  final acceptances = <RulesAcceptance>[];
  int _next = 0;
  @override
  Iterable<UserProfile> get profiles => _profiles.values;
  @override
  UserProfile? profile(String id) => _profiles[id];
  @override
  void save(UserProfile value) {
    _profiles[value.id] = value;
  }

  @override
  Iterable<TeamLink> members(String ownerId) => links
      .where((l) => l.ownerId == ownerId && l.status == TeamLinkStatus.active);
  @override
  Iterable<TeamLink> invitations(String memberId) => links.where(
      (l) => l.memberId == memberId && l.status == TeamLinkStatus.invited);
  bool _backlink(String ownerId, String memberId) => links.any((l) =>
      l.ownerId == memberId &&
      l.memberId == ownerId &&
      (l.status == TeamLinkStatus.active ||
          l.status == TeamLinkStatus.invited));
  @override
  String? invite(String ownerId, String memberId) {
    if (ownerId == memberId) return 'نمی‌توانی خودت را اضافه کنی.';
    if (profile(ownerId) == null || profile(memberId) == null)
      return 'پروفایل پیدا نشد.';
    if (_backlink(ownerId, memberId)) return 'لینک مستقیم برگشتی مجاز نیست.';
    if (links.any((l) =>
        l.ownerId == ownerId &&
        l.memberId == memberId &&
        (l.status == TeamLinkStatus.active ||
            l.status == TeamLinkStatus.invited)))
      return 'این عضو قبلاً اضافه یا دعوت شده است.';
    links.add(TeamLink(
        'team-${DateTime.now().microsecondsSinceEpoch}-${++_next}',
        ownerId,
        memberId));
    notices.add(AccountNotice(
        memberId, '${profile(ownerId)!.name} برای عضویت دعوتت کرد.'));
    return null;
  }

  @override
  String? accept(String linkId, String actorId) {
    final l = links.where((l) => l.id == linkId).firstOrNull;
    if (l == null ||
        l.memberId != actorId ||
        l.status != TeamLinkStatus.invited) return 'این دعوت قابل پذیرش نیست.';
    if (_backlink(l.ownerId, l.memberId))
      return 'لینک مستقیم برگشتی مجاز نیست.';
    l.status = TeamLinkStatus.active;
    notices.add(
        AccountNotice(l.ownerId, '${profile(actorId)!.name} دعوت را پذیرفت.'));
    return null;
  }

  @override
  void decline(String linkId, String actorId) {
    final l = links.where((l) => l.id == linkId).firstOrNull;
    if (l == null ||
        l.memberId != actorId ||
        l.status != TeamLinkStatus.invited) return;
    l.status = TeamLinkStatus.declined;
    notices.add(
        AccountNotice(l.ownerId, '${profile(actorId)!.name} دعوت را نپذیرفت.'));
  }

  @override
  void remove(String linkId, String actorId) {
    final l = links.where((l) => l.id == linkId).firstOrNull;
    if (l == null ||
        l.ownerId != actorId ||
        ![TeamLinkStatus.invited, TeamLinkStatus.active].contains(l.status))
      return;
    l.status = TeamLinkStatus.removed;
    notices.add(AccountNotice(
        l.memberId, '${profile(actorId)!.name} لینک عضویت شما را حذف کرد.'));
  }

  void acceptRules(String profileId) {
    if (!acceptances
        .any((a) => a.profileId == profileId && a.version == rulesVersion))
      acceptances.add(RulesAcceptance(profileId, rulesVersion));
  }
}
