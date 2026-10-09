import 'dart:convert';
import 'dart:typed_data';
import 'marketplace.dart';
import 'service_listing.dart';

typedef Json = Map<String, dynamic>;
String workId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
int _sequence = 0;

class WorkNeed {
  WorkNeed(
      {required this.id,
      required this.ownerId,
      required this.title,
      required this.details,
      required this.city,
      this.district = '',
      this.category = 'خدمات',
      this.quantity = '',
      this.when = '',
      this.privateAddress = '',
      this.crew = false,
      this.skills = const [],
      this.budget,
      this.unit = PriceUnit.project,
      this.image = 'concrete',
      this.photos = const [],
      this.deadline,
      DateTime? createdAt,
      this.latitude,
      this.longitude})
      : createdAt = createdAt ?? DateTime.now();
  final String id, ownerId;
  String title,
      details,
      city,
      district,
      category,
      quantity,
      when,
      privateAddress,
      image;
  bool crew;
  List<String> skills;
  int? budget;
  PriceUnit unit;
  List<Uint8List> photos;
  double? latitude, longitude;
  bool closed = false, archived = false;
  String? chosenId;
  final selectedBidIds = <String>{};
  final DateTime createdAt;
  DateTime? deadline;
  bool expiredAt(DateTime now) => deadline != null && !now.isBefore(deadline!);
  bool acceptsAt(DateTime now) => !closed && !archived && !expiredAt(now);
  Json publicJson() => {
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'details': details,
        'city': city,
        'district': district,
        'category': category,
        'quantity': quantity,
        'when': when,
        'crew': crew,
        'skills': skills,
        'budget': budget,
        'unit': unit.name,
        'image': image,
        'closed': closed,
        'archived': archived,
        'chosenId': chosenId,
        'deadline': deadline?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'photos': photos.map(base64Encode).toList()
      };
  Json toJson() => {
        ...publicJson(),
        'selectedBidIds': selectedBidIds.toList(),
        'privateAddress': privateAddress,
        'latitude': latitude,
        'longitude': longitude
      };
  factory WorkNeed.fromJson(Json j) => WorkNeed(
      id: j['id'],
      ownerId: j['ownerId'],
      title: j['title'],
      details: j['details'],
      city: j['city'],
      district: j['district'],
      category: j['category'],
      quantity: j['quantity'],
      when: j['when'],
      crew: j['crew'],
      skills: List<String>.from(j['skills'] ?? []),
      budget: j['budget'],
      unit: PriceUnit.values.byName(j['unit']),
      image: j['image'],
      privateAddress: j['privateAddress'] ?? '',
      deadline: j['deadline'] == null ? null : DateTime.parse(j['deadline']),
      createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      photos: (j['photos'] as List).map((e) => base64Decode(e)).toList())
    ..closed = j['closed']
    ..archived = j['archived']
    ..chosenId = j['chosenId']
    ..selectedBidIds.addAll(List<String>.from(
        j['selectedBidIds'] ?? (j['chosenId'] == null ? [] : [j['chosenId']])));
}

class WorkBid {
  WorkBid(this.id, this.requestId, this.bidderId, this.amount, this.unit,
      this.when, this.terms);
  final String id, requestId, bidderId;
  int amount;
  PriceUnit unit;
  String when, terms;
  Json toJson() => {
        'id': id,
        'requestId': requestId,
        'bidderId': bidderId,
        'amount': amount,
        'unit': unit.name,
        'when': when,
        'terms': terms
      };
  factory WorkBid.fromJson(Json j) => WorkBid(
      j['id'],
      j['requestId'],
      j['bidderId'],
      j['amount'],
      PriceUnit.values.byName(j['unit']),
      j['when'],
      j['terms']);
}

class WorkChatRequest {
  WorkChatRequest(this.id, this.requestId, this.fromId, this.details,
      {DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  final String id, requestId, fromId, details;
  final DateTime createdAt;
  String status = 'pending';
  Json toJson() => {
        'id': id,
        'requestId': requestId,
        'fromId': fromId,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
        'status': status
      };
  factory WorkChatRequest.fromJson(Json j) =>
      WorkChatRequest(j['id'], j['requestId'], j['fromId'], j['details'],
          createdAt: DateTime.parse(j['createdAt']))
        ..status = j['status'];
}

class WorkVisit {
  WorkVisit(this.id, this.requestId, this.bidderId, this.proposedBy, this.at,
      {this.contextType = 'request'});
  final String contextType;
  String get contextId => requestId;
  final String id, requestId, bidderId, proposedBy;
  final DateTime at;
  String status = 'pending';
  Json toJson() => {
        'id': id,
        'requestId': requestId,
        'bidderId': bidderId,
        'proposedBy': proposedBy,
        'contextId': contextId,
        'contextType': contextType,
        'at': at.toIso8601String(),
        'status': status
      };
  factory WorkVisit.fromJson(Json j) => WorkVisit(
      j['id'],
      j['contextId'] ?? j['requestId'],
      j['bidderId'],
      j['proposedBy'],
      DateTime.parse(j['at']),
      contextType: j['contextType'] ?? 'request')
    ..status = j['status'];
}

class WorkMessage {
  WorkMessage(this.id, this.senderId, this.text,
      {this.fileName, this.mime, this.bytes, DateTime? at})
      : at = at ?? DateTime.now();
  final String id, senderId, text;
  final String? fileName, mime;
  final Uint8List? bytes;
  final DateTime at;
  Json toJson() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'fileName': fileName,
        'mime': mime,
        'bytes': bytes == null ? null : base64Encode(bytes!),
        'at': at.toIso8601String()
      };
  factory WorkMessage.fromJson(Json j) =>
      WorkMessage(j['id'], j['senderId'], j['text'],
          fileName: j['fileName'],
          mime: j['mime'],
          bytes: j['bytes'] == null ? null : base64Decode(j['bytes']),
          at: DateTime.parse(j['at']));
}

class WorkConversation {
  WorkConversation(this.id, this.requestId, this.ownerId, this.bidderId,
      {this.contextType = 'request', DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
  final String contextType;
  final DateTime createdAt;
  String get contextId => requestId;
  final String id, requestId, ownerId, bidderId;
  final messages = <WorkMessage>[];
  final readCount = <String, int>{};
  bool contains(String actor) => actor == ownerId || actor == bidderId;
  String peer(String actor) => actor == ownerId ? bidderId : ownerId;
  int unread(String actor) => messages
      .skip(readCount[actor] ?? 0)
      .where((m) => m.senderId != actor)
      .length;
  Json toJson() => {
        'id': id,
        'requestId': requestId,
        'ownerId': ownerId,
        'bidderId': bidderId,
        'contextType': contextType,
        'createdAt': createdAt.toIso8601String(),
        'contextId': contextId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'readCount': readCount
      };
  factory WorkConversation.fromJson(Json j) => WorkConversation(
      j['id'], j['contextId'] ?? j['requestId'], j['ownerId'], j['bidderId'],
      contextType: j['contextType'] ?? 'request',
      createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt']))
    ..messages.addAll((j['messages'] as List)
        .map((e) => WorkMessage.fromJson(Map<String, dynamic>.from(e))))
    ..readCount.addAll(Map<String, int>.from(j['readCount']));
}

/// Local demo adapter. The future API must independently enforce these rights.
class DemoWorkRepository {
  DemoWorkRepository({DateTime Function()? clock})
      : now = clock ?? DateTime.now;
  final DateTime Function() now;
  final chatRequests = <String, WorkChatRequest>{};
  WorkChatRequest requestChat(String id, String actor, String details) {
    candidate(id, actor);
    require(details.trim().isNotEmpty, 'شرح درخواست گفتگو را بنویس.');
    require(!conversations.containsKey(conversationKey(id, actor, 'request')),
        'گفتگوی این درخواست قبلاً باز شده است.');
    require(
        !chatRequests.values.any((c) =>
            c.requestId == id && c.fromId == actor && c.status == 'pending'),
        'درخواست گفتگو در انتظار پاسخ داری.');
    final c = WorkChatRequest(workId('chat-request'), id, actor, details.trim(),
        createdAt: now());
    chatRequests[c.id] = c;
    return c;
  }

  void respondChatRequest(String id, String actor, String status) {
    final c = chatRequests[id] ?? (throw StateError('درخواست گفتگو پیدا نشد.'));
    final n = need(c.requestId);
    require(c.status == 'pending', 'این درخواست قبلاً پاسخ گرفته است.');
    if (status == 'cancelled') {
      require(actor == c.fromId, 'فقط درخواست‌دهنده می‌تواند لغو کند.');
    } else {
      require(actor == n.ownerId, 'فقط صاحب درخواست اجازه گفتگو می‌دهد.');
      require(status == 'accepted' || status == 'declined', 'پاسخ معتبر نیست.');
      if (status == 'accepted')
        require(!n.closed && !n.archived, 'درخواست بسته است.');
    }
    c.status = status;
    if (status == 'accepted') {
      final chat = _allowConversation(n.id, c.fromId);
      send(chat.id, c.fromId, 'درخواست گفتگو\n${c.details}');
    }
  }

  final services = <String, ServiceListing>{};
  final contacts = <String, ServiceContact>{};
  final needs = <String, WorkNeed>{};
  final bids = <String, WorkBid>{};
  final visits = <String, WorkVisit>{};
  final conversations = <String, WorkConversation>{};
  final creditSpent = <String, int>{};
  int balance(String actor) => 10 - (creditSpent[actor] ?? 0);
  void saveService(ServiceListing s, String actor) {
    require(
        s.ownerId == actor &&
            (services[s.id] == null || services[s.id]!.ownerId == actor),
        'فقط صاحب آگهی می‌تواند آن را ویرایش کند.');
    require(
        s.title.trim().isNotEmpty &&
            s.details.trim().isNotEmpty &&
            s.city.isNotEmpty,
        'عنوان، شرح خدمات و شهر را تکمیل کن.');
    require(s.amount == null || s.amount! > 0, 'مبلغ باید مثبت باشد.');
    require(s.photos.length + s.galleryAssets.length <= 6,
        'حداکثر ۶ عکس برای آگهی انتخاب کن.');
    require(s.photos.every((p) => p.lengthInBytes <= 12 * 1024 * 1024),
        'حجم عکس بیش از حد مجاز است.');
    final old = services[s.id];
    if (old != null) {
      s.archived = old.archived;
      s.enabled = old.enabled;
    }
    s.updatedAt = DateTime.now();
    s.photos = s.photos.map((p) => Uint8List.fromList(p)).toList();
    services[s.id] = s;
  }

  void changeServiceStatus(String id, String actor,
      {bool? enabled, bool? archived}) {
    final s = service(id);
    require(s.ownerId == actor, 'فقط صاحب آگهی می‌تواند آن را مدیریت کند.');
    if (enabled != null) s.enabled = enabled;
    if (archived != null) s.archived = archived;
  }

  ServiceListing service(String id) =>
      services[id] ?? (throw StateError('آگهی پیدا نشد.'));
  ({String title, String ownerId, String city, String district}) contextInfo(
      String id, String type) {
    if (type == 'service') {
      final s = service(id);
      return (
        title: s.title,
        ownerId: s.ownerId,
        city: s.city,
        district: s.district
      );
    }
    final n = need(id);
    return (
      title: n.title,
      ownerId: n.ownerId,
      city: n.city,
      district: n.district
    );
  }

  String conversationKey(String id, String peer, String type) =>
      type == 'service' ? 'service:$id::$peer' : '$id::$peer';
  ServiceContact requestServiceContact(
      String id, String actor, ServiceContactKind kind, String details,
      {int? amount, PriceUnit unit = PriceUnit.project, DateTime? visitAt}) {
    final s = service(id);
    require(actor.isNotEmpty && actor != s.ownerId,
        'برای آگهی خودت درخواست ارتباط ثبت نمی‌شود.');
    require(s.enabled && !s.archived, 'آگهی فعلاً فعال نیست.');
    require(details.trim().isNotEmpty, 'شرح درخواست ارتباط را بنویس.');
    require(amount == null || amount > 0, 'مبلغ باید مثبت باشد.');
    require(
        kind != ServiceContactKind.visit ||
            (visitAt != null && visitAt.isAfter(DateTime.now())),
        'تاریخ بازدید باید در آینده باشد.');
    require(
        !contacts.values.any((c) =>
            c.serviceId == id && c.fromId == actor && c.status == 'pending'),
        'یک درخواست ارتباط در انتظار پاسخ داری.');
    final c = ServiceContact(workId('contact'), id, actor, kind, details.trim(),
        amount: amount,
        unit: unit,
        visitAt: kind == ServiceContactKind.visit ? visitAt : null);
    contacts[c.id] = c;
    return c;
  }

  void respondServiceContact(String id, String actor, String status) {
    final c = contacts[id] ?? (throw StateError('درخواست ارتباط پیدا نشد.'));
    final s = service(c.serviceId);
    require(c.status == 'pending', 'این درخواست قبلاً پاسخ گرفته است.');
    if (status == 'cancelled')
      require(actor == c.fromId, 'فقط درخواست‌دهنده می‌تواند لغو کند.');
    else {
      require(
          actor == s.ownerId, 'صاحب آگهی باید درخواست ارتباط را بررسی کند.');
      require(status == 'accepted' || status == 'declined', 'پاسخ معتبر نیست.');
      if (status == 'accepted' && c.visitAt != null)
        require(c.visitAt!.isAfter(DateTime.now()),
            'زمان این بازدید گذشته است؛ درخواست جدید ثبت کنید.');
    }
    c.status = status;
    if (status != 'accepted') return;
    final chat = _allowConversation(s.id, c.fromId, contextType: 'service');
    send(chat.id, c.fromId,
        '${c.kind.label}\n${c.details}${c.amount == null ? '' : '\n${c.amount} تومان / ${c.unit.label}'}');
    if (c.visitAt != null) {
      final visit = WorkVisit(
          workId('visit'), s.id, c.fromId, c.fromId, c.visitAt!,
          contextType: 'service')
        ..status = 'accepted';
      visits[visit.id] = visit;
    }
  }

  WorkVisit proposeServiceVisit(
      String id, String peer, String actor, DateTime at) {
    final c = chat(conversationKey(id, peer, 'service'), actor);
    require(c.contextType == 'service', 'این گفتگو مربوط به آگهی نیست.');
    require(at.isAfter(DateTime.now()), 'زمان بازدید باید در آینده باشد.');
    require(
        !visits.values.any((v) =>
            v.contextType == 'service' &&
            v.contextId == id &&
            v.bidderId == peer &&
            v.status == 'pending'),
        'یک بازدید در انتظار پاسخ است.');
    final v =
        WorkVisit(workId('visit'), id, peer, actor, at, contextType: 'service');
    visits[v.id] = v;
    return v;
  }

  void require(bool test, String message) {
    if (!test) throw StateError(message);
  }

  WorkNeed need(String id) =>
      needs[id] ?? (throw StateError('درخواست پیدا نشد.'));
  Iterable<WorkBid> proposals(String id) =>
      bids.values.where((b) => b.requestId == id);
  WorkBid? mine(String id, String actor) =>
      proposals(id).where((b) => b.bidderId == actor).firstOrNull;
  Iterable<WorkBid> visibleBids(String id, String actor) =>
      need(id).ownerId == actor || mine(id, actor) != null
          ? proposals(id)
          : const [];
  void saveNeed(WorkNeed n, String actor) {
    require(n.ownerId == actor, 'فقط صاحب درخواست می‌تواند آن را ویرایش کند.');
    final old = needs[n.id];
    require(old == null || old.ownerId == actor, 'مالک درخواست تغییر نمی‌کند.');
    require(
        n.title.trim().isNotEmpty &&
            n.details.trim().isNotEmpty &&
            n.city.isNotEmpty,
        'عنوان، شرح و شهر را تکمیل کن.');
    require(n.budget == null || n.budget! > 0, 'بودجه باید بیشتر از صفر باشد.');
    require(
        n.deadline == null ||
            n.deadline!.isAfter(now()) ||
            old?.deadline == n.deadline,
        'مهلت جدید باید در آینده باشد.');
    if (old != null) {
      n.closed = old.closed;
      n.archived = old.archived;
      n.chosenId = old.chosenId;
      n.selectedBidIds.addAll(old.selectedBidIds);
    }
    needs[n.id] = n;
  }

  void changeStatus(String id, String actor,
      {bool? closed, bool archive = false}) {
    final n = need(id);
    require(n.ownerId == actor, 'فقط صاحب درخواست مجاز است.');
    if (closed != null) n.closed = closed;
    if (archive) {
      n.archived = true;
      n.closed = true;
    }
  }

  void candidate(String id, String actor) {
    final n = need(id);
    require(actor.isNotEmpty && actor != n.ownerId,
        'برای درخواست خودت نمی‌توانی پیشنهاد بدهی.');
    require(n.acceptsAt(now()),
        'درخواست بسته است یا مهلت دریافت پیشنهاد پایان یافته است.');
  }

  WorkBid propose(String id, String actor, int amount, PriceUnit unit,
      String when, String terms) {
    candidate(id, actor);
    require(amount > 0 && when.trim().isNotEmpty, 'مبلغ و زمان را تکمیل کن.');
    final previous = mine(id, actor);
    require(
        previous == null ||
            (need(id).chosenId != previous.id &&
                !need(id).selectedBidIds.contains(previous.id)),
        'پیشنهاد انتخاب‌شده قابل تغییر نیست.');
    if (previous == null) {
      require(balance(actor) > 0, 'اعتبار آزمایشی کافی نیست.');
      creditSpent[actor] = (creditSpent[actor] ?? 0) + 1;
    }
    final b = WorkBid(previous?.id ?? workId('bid'), id, actor, amount, unit,
        when.trim(), terms.trim());
    bids[b.id] = b;
    return b;
  }

  WorkVisit proposeVisit(String id, String bidder, String actor, DateTime at) {
    final n = need(id);
    if (conversations.containsKey(conversationKey(id, bidder, 'request')) &&
        !n.closed &&
        !n.archived) {
      require(
          bidder != n.ownerId && bidder.isNotEmpty, 'طرف بازدید معتبر نیست.');
    } else {
      candidate(id, bidder);
    }
    require(actor == bidder || actor == need(id).ownerId,
        'این بازدید مربوط به شما نیست.');
    require(at.isAfter(now()), 'زمان بازدید باید در آینده باشد.');
    require(
        !visits.values.any((v) =>
            v.contextType == 'request' &&
            v.requestId == id &&
            v.bidderId == bidder &&
            v.status == 'pending'),
        'یک بازدید در انتظار پاسخ است.');
    final v = WorkVisit(workId('visit'), id, bidder, actor, at);
    visits[v.id] = v;
    return v;
  }

  void respondVisit(String id, String actor, String status) {
    final v = visits[id] ?? (throw StateError('قرار پیدا نشد.'));
    final owner = contextInfo(v.contextId, v.contextType).ownerId;
    require(
        actor == owner || actor == v.bidderId, 'این قرار مربوط به شما نیست.');
    require(v.status == 'pending', 'این قرار قبلاً پاسخ گرفته است.');
    if (status == 'cancelled') {
      require(actor == v.proposedBy, 'فقط پیشنهاددهنده می‌تواند لغو کند.');
    } else {
      require(actor != v.proposedBy, 'طرف دیگر باید قرار را تأیید کند.');
      require(status == 'accepted' || status == 'declined', 'پاسخ معتبر نیست.');
      if (status == 'accepted') {
        require(
            v.at.isAfter(now()), 'زمان بازدید گذشته است؛ قرار جدید تنظیم کن.');
        if (v.contextType == 'request')
          require(!need(v.contextId).closed && !need(v.contextId).archived,
              'درخواست بسته است.');
      }
    }
    v.status = status;
    if (status == 'accepted')
      _allowConversation(v.contextId, v.bidderId, contextType: v.contextType);
  }

  String? privateAddress(String id, String actor) =>
      need(id).ownerId == actor ||
              visits.values.any((v) =>
                  v.contextType == 'request' &&
                  v.requestId == id &&
                  v.bidderId == actor &&
                  v.status == 'accepted')
          ? need(id).privateAddress
          : null;
  WorkConversation _allowConversation(String id, String bidder,
      {String contextType = 'request'}) {
    final key = conversationKey(id, bidder, contextType);
    return conversations.putIfAbsent(
        key,
        () => WorkConversation(
            key, id, contextInfo(id, contextType).ownerId, bidder,
            contextType: contextType));
  }

  WorkConversation select(String id, String bidId, String actor) {
    final n = need(id);
    require(n.ownerId == actor, 'فقط صاحب درخواست انتخاب می‌کند.');
    require(!n.closed && !n.archived, 'درخواست بسته است.');
    final b = bids[bidId];
    require(b != null && b.requestId == id, 'پیشنهاد نامعتبر است.');
    n.chosenId ??= bidId;
    n.selectedBidIds.add(bidId);
    return _allowConversation(id, b!.bidderId);
  }

  WorkConversation chat(String id, String actor) {
    final c = conversations[id];
    require(c != null && c.contains(actor),
        'گفتگو پس از پذیرش ارتباط، انتخاب پیشنهاد یا تأیید بازدید باز می‌شود.');
    return c!;
  }

  void send(String id, String actor, String text,
      {String? fileName, String? mime, Uint8List? bytes}) {
    final c = chat(id, actor);
    require(text.trim().isNotEmpty || bytes != null, 'پیام خالی است.');
    require(
        bytes == null || (bytes.isNotEmpty && bytes.length <= 10 * 1024 * 1024),
        'حداکثر حجم پیوست ۱۰ مگابایت است.');
    c.messages.add(WorkMessage(workId('message'), actor, text.trim(),
        fileName: fileName,
        mime: mime,
        bytes: bytes == null ? null : Uint8List.fromList(bytes)));
    c.readCount[actor] = c.messages.length;
  }

  void read(String id, String actor) {
    final c = chat(id, actor);
    c.readCount[actor] = c.messages.length;
  }

  Json toJson() => {
        'chatRequests': chatRequests.values.map((c) => c.toJson()).toList(),
        'contacts': contacts.values.map((v) => v.toJson()).toList(),
        'services': services.values.map((v) => v.toJson()).toList(),
        'needs': needs.values.map((v) => v.toJson()).toList(),
        'bids': bids.values.map((v) => v.toJson()).toList(),
        'visits': visits.values.map((v) => v.toJson()).toList(),
        'conversations': conversations.values.map((v) => v.toJson()).toList(),
        'creditSpent': creditSpent
      };
  void restore(Json j) {
    chatRequests.clear();
    for (final x in j['chatRequests'] ?? []) {
      final c = WorkChatRequest.fromJson(Map<String, dynamic>.from(x));
      chatRequests[c.id] = c;
    }
    contacts.clear();
    for (final x in j['contacts'] ?? []) {
      final c = ServiceContact.fromJson(Map<String, dynamic>.from(x));
      contacts[c.id] = c;
    }
    services.clear();
    for (final x in j['services'] ?? []) {
      final v = ServiceListing.fromJson(Map<String, dynamic>.from(x));
      services[v.id] = v;
    }
    needs.clear();
    bids.clear();
    visits.clear();
    conversations.clear();
    creditSpent.clear();
    for (final x in j['needs']) {
      final v = WorkNeed.fromJson(Map<String, dynamic>.from(x));
      needs[v.id] = v;
    }
    for (final x in j['bids']) {
      final v = WorkBid.fromJson(Map<String, dynamic>.from(x));
      bids[v.id] = v;
    }
    for (final x in j['visits']) {
      final v = WorkVisit.fromJson(Map<String, dynamic>.from(x));
      visits[v.id] = v;
    }
    for (final x in j['conversations']) {
      final v = WorkConversation.fromJson(Map<String, dynamic>.from(x));
      conversations[v.id] = v;
    }
    creditSpent.addAll(Map<String, int>.from(j['creditSpent']));
  }
}
