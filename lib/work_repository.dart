import 'dart:convert';
import 'dart:typed_data';
import 'marketplace.dart';

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
      this.budget,
      this.unit = PriceUnit.project,
      this.image = 'concrete',
      this.photos = const [],
      this.latitude,
      this.longitude});
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
  int? budget;
  PriceUnit unit;
  List<Uint8List> photos;
  double? latitude, longitude;
  bool closed = false, archived = false;
  String? chosenId;
  final DateTime createdAt = DateTime.now();
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
        'budget': budget,
        'unit': unit.name,
        'image': image,
        'closed': closed,
        'archived': archived,
        'chosenId': chosenId,
        'photos': photos.map(base64Encode).toList()
      };
  Json toJson() => {
        ...publicJson(),
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
      budget: j['budget'],
      unit: PriceUnit.values.byName(j['unit']),
      image: j['image'],
      privateAddress: j['privateAddress'] ?? '',
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      photos: (j['photos'] as List).map((e) => base64Decode(e)).toList())
    ..closed = j['closed']
    ..archived = j['archived']
    ..chosenId = j['chosenId'];
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

class WorkVisit {
  WorkVisit(this.id, this.requestId, this.bidderId, this.proposedBy, this.at);
  final String id, requestId, bidderId, proposedBy;
  final DateTime at;
  String status = 'pending';
  Json toJson() => {
        'id': id,
        'requestId': requestId,
        'bidderId': bidderId,
        'proposedBy': proposedBy,
        'at': at.toIso8601String(),
        'status': status
      };
  factory WorkVisit.fromJson(Json j) => WorkVisit(j['id'], j['requestId'],
      j['bidderId'], j['proposedBy'], DateTime.parse(j['at']))
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
  WorkConversation(this.id, this.requestId, this.ownerId, this.bidderId);
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
        'messages': messages.map((m) => m.toJson()).toList(),
        'readCount': readCount
      };
  factory WorkConversation.fromJson(Json j) =>
      WorkConversation(j['id'], j['requestId'], j['ownerId'], j['bidderId'])
        ..messages.addAll((j['messages'] as List)
            .map((e) => WorkMessage.fromJson(Map<String, dynamic>.from(e))))
        ..readCount.addAll(Map<String, int>.from(j['readCount']));
}

/// Local demo adapter. The future API must independently enforce these rights.
class DemoWorkRepository {
  final needs = <String, WorkNeed>{};
  final bids = <String, WorkBid>{};
  final visits = <String, WorkVisit>{};
  final conversations = <String, WorkConversation>{};
  final creditSpent = <String, int>{};
  int balance(String actor) => 10 - (creditSpent[actor] ?? 0);
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
    if (old != null) {
      n.closed = old.closed;
      n.archived = old.archived;
      n.chosenId = old.chosenId;
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
    require(!n.closed && !n.archived, 'این درخواست پیشنهاد جدید نمی‌پذیرد.');
  }

  WorkBid propose(String id, String actor, int amount, PriceUnit unit,
      String when, String terms) {
    candidate(id, actor);
    require(amount > 0 && when.trim().isNotEmpty, 'مبلغ و زمان را تکمیل کن.');
    final previous = mine(id, actor);
    require(previous == null || need(id).chosenId != previous.id,
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
    candidate(id, bidder);
    require(actor == bidder || actor == need(id).ownerId,
        'این بازدید مربوط به شما نیست.');
    require(at.isAfter(DateTime.now()), 'زمان بازدید باید در آینده باشد.');
    require(
        !visits.values.any((v) =>
            v.requestId == id && v.bidderId == bidder && v.status == 'pending'),
        'یک بازدید در انتظار پاسخ است.');
    final v = WorkVisit(workId('visit'), id, bidder, actor, at);
    visits[v.id] = v;
    return v;
  }

  void respondVisit(String id, String actor, String status) {
    final v = visits[id] ?? (throw StateError('قرار پیدا نشد.'));
    final owner = need(v.requestId).ownerId;
    require(
        actor == owner || actor == v.bidderId, 'این قرار مربوط به شما نیست.');
    require(v.status == 'pending', 'این قرار قبلاً پاسخ گرفته است.');
    if (status == 'cancelled') {
      require(actor == v.proposedBy, 'فقط پیشنهاددهنده می‌تواند لغو کند.');
    } else {
      require(actor != v.proposedBy, 'طرف دیگر باید قرار را تأیید کند.');
      require(status == 'accepted' || status == 'declined', 'پاسخ معتبر نیست.');
    }
    v.status = status;
    if (status == 'accepted') _allowConversation(v.requestId, v.bidderId);
  }

  String? privateAddress(String id, String actor) =>
      need(id).ownerId == actor ||
              visits.values.any((v) =>
                  v.requestId == id &&
                  v.bidderId == actor &&
                  v.status == 'accepted')
          ? need(id).privateAddress
          : null;
  WorkConversation _allowConversation(String id, String bidder) {
    final key = '$id::$bidder';
    return conversations.putIfAbsent(
        key, () => WorkConversation(key, id, need(id).ownerId, bidder));
  }

  WorkConversation select(String id, String bidId, String actor) {
    final n = need(id);
    require(n.ownerId == actor, 'فقط صاحب درخواست انتخاب می‌کند.');
    require(!n.closed && !n.archived, 'درخواست بسته است.');
    final b = bids[bidId];
    require(b != null && b.requestId == id, 'پیشنهاد نامعتبر است.');
    require(n.chosenId == null || n.chosenId == bidId,
        'قبلاً یک پیشنهاد انتخاب شده است.');
    n.chosenId = bidId;
    return _allowConversation(id, b!.bidderId);
  }

  WorkConversation chat(String id, String actor) {
    final c = conversations[id];
    require(c != null && c.contains(actor),
        'گفت‌وگو پس از انتخاب پیشنهاد یا تأیید بازدید باز می‌شود.');
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
        'needs': needs.values.map((v) => v.toJson()).toList(),
        'bids': bids.values.map((v) => v.toJson()).toList(),
        'visits': visits.values.map((v) => v.toJson()).toList(),
        'conversations': conversations.values.map((v) => v.toJson()).toList(),
        'creditSpent': creditSpent
      };
  void restore(Json j) {
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
