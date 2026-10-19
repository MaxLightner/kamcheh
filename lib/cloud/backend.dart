import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef BackendRow = Map<String, dynamic>;
const backendUrl = String.fromEnvironment('KAMCHEH_SUPABASE_URL');
const backendKey = String.fromEnvironment('KAMCHEH_SUPABASE_PUBLISHABLE_KEY');
const backendConfigured = backendUrl != '' && backendKey != '';

String normalizeBackendDigits(String input) => input
    .replaceAllMapped(
        RegExp('[۰-۹]'), (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString())
    .replaceAllMapped(
        RegExp('[٠-٩]'), (m) => '٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!).toString())
    .replaceAll('٬', '')
    .replaceAll(',', '')
    .trim();

String? backendPhone(String input) {
  var value = normalizeBackendDigits(input).replaceAll(RegExp(r'[\s()-]'), '');
  if (value.startsWith('0098')) value = '+${value.substring(2)}';
  if (RegExp(r'^09\d{9}$').hasMatch(value)) value = '+98${value.substring(1)}';
  return RegExp(r'^\+989\d{9}$').hasMatch(value) ? value : null;
}

int? backendAmount(String input, {bool optional = true}) {
  final raw = normalizeBackendDigits(input);
  if (optional && raw.isEmpty) return null;
  final result = int.tryParse(raw);
  if (result == null || result <= 0 || result > 9007199254740991) {
    throw const FormatException('مبلغ مثبت و معتبر به تومان وارد کن.');
  }
  return result;
}

/// The only production repository. No demo state or sample actor IDs enter it.
class KamchehBackend extends ChangeNotifier {
  KamchehBackend(this.db) {
    _auth = db.auth.onAuthStateChange.listen((_) {
      profile = null;
      notifyListeners();
    });
  }
  final SupabaseClient db;
  late final StreamSubscription<AuthState> _auth;
  BackendRow? profile;
  String? get actor => db.auth.currentUser?.id;
  bool get loggedIn => actor != null;
  static const publicProfileFields =
      'id,display_name,specialty,activity_type,city,district,bio,skills,avatar_path,is_complete,is_public,available';
  Future<BackendRow?> myProfile() async {
    final id = actor;
    if (id == null) return profile = null;
    final result = await db
        .from('profiles')
        .select(publicProfileFields)
        .eq('id', id)
        .maybeSingle();
    if (id == actor) profile = result;
    return result;
  }

  Future<List<BackendRow>> profiles() async => List<BackendRow>.from(await db
      .from('profiles')
      .select(publicProfileFields)
      .eq('is_complete', true)
      .eq('is_public', true)
      .order('created_at', ascending: false)
      .limit(100));
  Future<List<BackendRow>> market(bool needs) async {
    final table = needs ? 'work_needs' : 'service_listings';
    final fields = needs
        ? 'budget,quantity,work_time,crew_required,deadline'
        : 'amount,image_url';
    var query = db
        .from(table)
        .select(
            'id,owner_id,title,details,city,district,category,skills,unit,created_at,$fields,owner:profiles($publicProfileFields)')
        .eq('archived', false);
    query = needs
        ? query.eq('closed', false).or(
            'deadline.is.null,deadline.gt.${DateTime.now().toUtc().toIso8601String()}')
        : query.eq('enabled', true);
    return List<BackendRow>.from(
        await query.order('created_at', ascending: false).limit(100));
  }

  Future<void> saveProfile(BackendRow values) async {
    final id = actor;
    if (id == null) throw const AuthException('ابتدا وارد حساب شو.');
    await db.from('profiles').upsert({...values, 'id': id});
    await myProfile();
    notifyListeners();
  }

  Future<void> requireComplete() async {
    if (!loggedIn) throw const AuthException('ابتدا وارد حساب شو.');
    if ((await myProfile())?['is_complete'] != true)
      throw const FormatException(
          'ابتدا نام، شهر و تخصص پروفایلت را تکمیل کن.');
    final accepted = await db
        .from('rules_acceptances')
        .select('version')
        .eq('profile_id', actor!)
        .maybeSingle();
    if (accepted?['version'] != '2026-10-19')
      throw const FormatException('برای ادامه قوانین کمچه را تأیید کن.');
  }

  Future<void> post(bool need, BackendRow values) async {
    await requireComplete();
    await db
        .from(need ? 'work_needs' : 'service_listings')
        .insert({...values, 'owner_id': actor});
  }

  Future<void> contact(BackendRow row, bool need, String kind, String message,
      {DateTime? at}) async {
    await requireComplete();
    await db.from('contact_requests').insert({
      'context_type': need ? 'need' : 'service',
      'context_id': row['id'],
      'sender_id': actor,
      'recipient_id': row['owner_id'],
      'kind': kind,
      'message': message,
      if (at != null) 'visit_at': at.toUtc().toIso8601String()
    });
  }

  Future<void> bid(String need, int amount, String unit, String terms) async {
    await requireComplete();
    await db.from('work_bids').insert({
      'need_id': need,
      'bidder_id': actor,
      'amount': amount,
      'unit': unit,
      'terms': terms
    });
  }

  Future<List<BackendRow>> mine(String table) async => loggedIn
      ? List<BackendRow>.from(await db
          .from(table)
          .select()
          .eq('owner_id', actor!)
          .order('created_at', ascending: false))
      : [];
  Future<List<BackendRow>> contacts() async => loggedIn
      ? List<BackendRow>.from(await db
          .from('contact_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(100))
      : [];
  Future<List<BackendRow>> threads() async => loggedIn
      ? List<BackendRow>.from(await db
          .from('message_threads')
          .select()
          .order('created_at', ascending: false)
          .limit(100))
      : [];
  Future<List<BackendRow>> messages(String thread) async =>
      List<BackendRow>.from(await db
          .from('thread_messages')
          .select()
          .eq('thread_id', thread)
          .order('created_at'));
  Future<void> send(String thread, String text) async {
    if (actor == null || text.trim().isEmpty) return;
    await db
        .from('thread_messages')
        .insert({'thread_id': thread, 'sender_id': actor, 'body': text.trim()});
  }

  Future<void> logout() async {
    await db.auth.signOut(scope: SignOutScope.local);
    profile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.cancel();
    super.dispose();
  }
}
