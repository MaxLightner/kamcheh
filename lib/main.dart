import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cloud/cloud_marketplace.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'network_data.dart';
import 'marketplace.dart';
import 'feed_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'demo_data.dart';
import 'area_picker.dart';
import 'ad_draft.dart';
import 'location_map.dart';
import 'dart:ui' as ui;
import 'user_profile.dart';
import 'core.dart';
import 'contract_document.dart';
import 'estimate.dart';
import 'squaring_tool.dart';
import 'file_delivery.dart';
import 'dart:convert';
import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'work_repository.dart';
import 'demo_store.dart';
import 'service_listing.dart';
import 'request_filter.dart';
import 'persian_calendar.dart';
import 'demo_migration.dart';
import 'listing_gallery.dart';

part 'network_ui.dart';
part 'home_ui.dart';
part 'ad_ui.dart';
part 'profile_ui.dart';
part 'kamcheh_ui.dart';
part 'stages_ui.dart';
part 'work_ui.dart';
part 'work_persistence.dart';
part 'structure_ui.dart';
part 'ad_profile_ui.dart';
part 'request_details_ui.dart';
part 'message_details_ui.dart';
part 'contract_ui.dart';
part 'account_home_ui.dart';
part 'accounting_ui.dart';

const red = Color(0xFFAF282B);
const ink = Color(0xFF222329);
const muted = Color(0xFF777B84);
const line = Color(0xFFE9EAED);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kamchehCloudEnabled) {
    await Supabase.initialize(
      url: kamchehSupabaseUrl,
      publishableKey: kamchehSupabaseKey,
    );
  }
  runApp(const SakhtyarApp(persistDemo: true));
}

class SakhtyarApp extends StatelessWidget {
  const SakhtyarApp(
      {super.key, this.startWithDemoAccount = false, this.persistDemo = false});
  final bool startWithDemoAccount;
  final bool persistDemo;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'کمچه',
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        themeMode: ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10))),
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
          fontFamily: 'Vazirmatn',
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: red,
            primary: red,
            surface: Colors.white,
          ),
          dividerTheme: const DividerThemeData(color: line, thickness: 1),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: ink, fontSize: 13),
            bodyLarge: TextStyle(color: ink, fontSize: 14),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
              textStyle: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              side: const BorderSide(color: red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ),
        home: AppShell(
            startWithDemoAccount: startWithDemoAccount,
            persistDemo: persistDemo),
      );
}

String fa(Object value) => value.toString().replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)],
    );
String money(int value) =>
    '${fa(value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}٬'))} تومان';
int? parseAmount(String value) {
  final normalized = value.replaceAllMapped(
    RegExp(r'[۰-۹]'),
    (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!).toString(),
  );
  return int.tryParse(normalized.replaceAll(RegExp(r'[^0-9]'), ''));
}

class EditDialog extends StatefulWidget {
  const EditDialog({
    super.key,
    required this.title,
    required this.initial,
    required this.hint,
  });
  final String title, initial, hint;
  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 340,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(hintText: widget.hint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 42)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      );
}

class Expense {
  Expense(this.title, this.category, this.amount, this.paid,
      {this.income = false,
      this.source = '',
      this.stage = '',
      String? accountType,
      DateTime? date,
      String? restoredId})
      : accountType = accountType ?? (paid ? 'تسویه' : 'بدهی'),
        date = date ?? DateTime.now(),
        id = restoredId ??
            'expense-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  static int _counter = 0;
  final String id, title, category, source, stage, accountType;
  final int amount;
  final bool paid, income;
  final DateTime date;
}

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key, this.startWithDemoAccount = false, this.persistDemo = false});
  final bool startWithDemoAccount;
  final bool persistDemo;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final DemoWorkRepository workStore = seedWorkStore();
  final demoStore = DemoStore();
  bool loadingDemo = false, storageReady = false, storageFailed = false;
  String? workEditingId, workChatId;
  bool workCrew = false, showChatSearch = false;
  DateTime? workDeadline;
  bool bidSortDescending = false;
  Timer? deadlineRefresh;
  final chatSearchInput = TextEditingController();
  final chatScroll = ScrollController();
  bool sendingAttachment = false;
  int visitMessageTab = 0;
  String chatSearch = '';
  PriceUnit? bidSortUnit;
  final workPrivate = TextEditingController();
  final reports = <DemoReport>[];
  String page = 'home', search = '', stage = 'دیوارچینی';
  FeedFilter feedFilter = const FeedFilter();
  bool showProfileFeed = false, onlyAvailable = false;
  String profileQuery = '', profileSpecialty = '', profileType = 'همه';
  late final DemoProfileRepository profileRepository = createDemoProfiles();
  PriceUnit? draftPriceUnit;
  AdKind? draftAdKind;
  MapPoint? adPoint;
  AreaFilter? draftServiceArea;
  String? activeAdDraftId;
  int myAdsTab = 0;
  bool selectingAdPhotos = false;
  int composerGeneration = 0;
  bool changingAdCategory = false;
  List<AdDraft> get adDrafts => workspace.adDrafts;
  Set<String> get deletedAds => workspace.deletedAds;
  int tab = 0, material = 0;
  int messageTab = 0, bookmarkTab = 0, requestTab = 0;
  String directoryGroup = 'همه', selectedRequest = 'own-labor';
  late final accountSpaces = <String, AccountWorkspace>{
    samplePhone: AccountWorkspace.sample()
  };
  late String? activePhone = widget.startWithDemoAccount ? samplePhone : null;
  late AccountWorkspace workspace = widget.startWithDemoAccount
      ? accountSpaces[samplePhone]!
      : AccountWorkspace();
  bool get signedIn => activePhone != null;
  bool get canAct => signedIn && workspace.profile.complete;
  UserProfile get myProfile => workspace.profile;
  String get myName => myProfile.name;
  String get myBio => myProfile.bio;
  set myBio(String value) => myProfile.bio = value;
  String? editingAdId;
  Map<String, Ad> get savedPeople => workspace.savedPeople;
  Set<String> get closedAds => workspace.closedAds;
  Set<String> get mySkills => myProfile.skills;
  final draftSkills = <String>{}, draftPhotos = <Uint8List>[];
  final quantityInput = TextEditingController(),
      durationInput = TextEditingController();
  Map<String, WorkRequest> get workRequests => workspace.workRequests;
  List<BidOffer> get myOffers => workspace.myOffers;
  List<VisitRecord> get visits => workspace.visits;
  List<WorkReview> get workReviews => workspace.workReviews;
  Map<String, String> get threadAdIds => workspace.threadAdIds;
  bool showExperience = true, showAvailability = true;
  void update(VoidCallback action) {
    setState(action);
    persistWork();
  }

  Set<String> get savedIds => workspace.savedIds;
  Set<String> get likedIds => workspace.likedIds;
  bool get saved => savedIds.contains(selectedAd.id);
  final history = <(String, int)>[];
  List<ChatThread> get threads => workspace.threads;
  int threadIndex = 0;
  List<String> get sent => threads[threadIndex].outgoing;
  List<Ad> get createdAds => workspace.createdAds;
  Ad selectedAd = demoAds.first;
  AreaFilter selectedArea = const AreaFilter();
  AreaFilter adArea = const AreaFilter(
      province: 'خراسان رضوی', city: 'مشهد', surroundings: true);
  String get region => selectedArea.label;
  String postKind = 'نیاز دارم', postCategory = 'نیرو', inboxQuery = '';
  final adNotes = TextEditingController();
  List<Expense> get expenses => workspace.expenses;
  int accountingTab = 0;
  int contractIndex = 0;
  String? selectedContractId;
  List<ContractDraft> get drafts => workspace.drafts;
  String get contractStatus => drafts[contractIndex].status;
  set contractStatus(String value) => drafts[contractIndex].status = value;
  Map<String, String> get contractValues => drafts[contractIndex].values;
  final requestForm = GlobalKey<FormState>(),
      financeForm = GlobalKey<FormState>();
  final description = TextEditingController(),
      people = TextEditingController(text: '3'),
      location = TextEditingController(text: 'مشهد، الهیه'),
      wage = TextEditingController(),
      start = TextEditingController();
  final searchInput = TextEditingController();
  final inboxInput = TextEditingController();
  final txTitle = TextEditingController(),
      txAmount = TextEditingController(),
      chat = TextEditingController();
  String txCat = 'مصالح';
  bool txPaid = true, txIncome = false;
  RequestFilter requestFilter = const RequestFilter();
  String requestQuery = '';
  final requestInput = TextEditingController();
  final workSkills = <String>{};
  static const titles = {
    'home': 'آگهی‌ها',
    'professionals': 'پروفایل‌ها',
    'requests': 'درخواست‌ها',
    'estimate': 'برآورد مصالح',
    'squaring': 'گونیا سازی',
    'reports': 'گزارش‌های من',
    'publicMissing': 'پروفایل',
    'rules': 'قوانین کمچه',
    'team': 'اعضا و دعوت‌ها',
    'pro': 'پروفایل حرفه‌ای',
    'project': 'پروژه من',
    'contract': 'تنظیم قرارداد',
    'contracts': 'قراردادهای من',
    'request': 'ثبت درخواست',
    'applicants': 'پیشنهادهای درخواست',
    'worker': 'پروفایل کارگر',
    'ledger': 'حسابداری',
    'finance': 'ثبت مورد مالی',
    'supplier': 'پروفایل تأمین‌کننده',
    'chat': 'گفت‌وگو',
    'inbox': 'پیام‌ها',
    'activities': 'درخواست‌ها و پیشنهادهای من',
    'me': 'صفحه من',
    'ownProfile': 'معرفی و نمونه‌کارهای من',
    'post': 'آگهی‌های من',
    'detail': 'جزئیات آگهی',
    'myAds': 'آگهی‌های من',
    'settings': 'تنظیمات',
    'profilePreview': 'پیش‌نمایش پروفایل عمومی',
    'profileStats': 'بازدید پروفایل من',
  };

  @override
  void initState() {
    super.initState();
    if (widget.persistDemo)
      deadlineRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted &&
            ['requests', 'detail', 'applicants', 'activities'].contains(page))
          setState(() {});
      });
    if (widget.persistDemo) {
      loadingDemo = true;
      loadWork();
    }
    final incoming = Uri.base.queryParameters['profile'];
    if (incoming != null) {
      final p = profileRepository.profile(incoming);
      if (p == null) {
        page = 'publicMissing';
      } else {
        selectedAd = profileCard(p);
        page = 'pro';
        if (!widget.persistDemo) recordProfileView(p);
      }
      history.add(('home', 0));
    }
  }

  @override
  void dispose() {
    deadlineRefresh?.cancel();
    chatSearchInput.dispose();
    chatScroll.dispose();
    workPrivate.dispose();
    if (storageReady) demoStore.close();
    for (final c in [
      description,
      people,
      location,
      wage,
      start,
      txTitle,
      txAmount,
      chat,
      searchInput,
      requestInput,
      inboxInput,
      adNotes,
      quantityInput,
      durationInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(String value) {
    if (['project', 'supplier'].contains(value)) {
      notice('این بخش در نسخه اولیه فعال نیست.');
      return;
    }
    if (['team', 'reports'].contains(value) && !signedIn) {
      ensureAccess(() => go(value), activity: false);
      return;
    }
    if (!signedIn &&
        [
          'ownProfile',
          'profilePreview',
          'profileStats',
          'myAds',
          'settings',
          'inbox',
          'chat',
          'project',
          'ledger',
          'contracts',
          'contract',
          'finance',
          'activities',
          'applicants',
          'request',
          'post'
        ].contains(value)) {
      ensureAccess(() => go(value),
          activity: !['inbox', 'settings'].contains(value));
      return;
    }
    if (!canAct &&
        [
          'request',
          'post',
          'contract',
          'finance',
          'project',
          'ledger',
          'contracts',
          'activities',
          'applicants'
        ].contains(value)) {
      ensureAccess(() => go(value));
      return;
    }
    setState(() {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      history.add(value == 'chat' ? ('inbox', 3) : (page, tab));
      page = value;
      if (value == 'chat' || value == 'inbox') tab = 3;
      if (['post', 'myAds'].contains(value)) tab = 0;
      if (value == 'professionals') tab = 1;
      if (['requests', 'activities', 'request', 'applicants'].contains(value))
        tab = 2;
    });
  }

  void back() => setState(() {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (history.isEmpty) {
          page = ['home', 'professionals', 'requests', 'inbox', 'me'][tab];
        } else {
          final previous = history.removeLast();
          page = previous.$1;
          tab = previous.$2;
        }
      });
  void openAd(Ad ad) {
    selectedAd = adFor(ad.id);
    go('detail');
  }

  void openThread({Ad? ad}) => gatedOpenThread(ad: ad);
  Widget conversationBody() => durableConversation();
  void sendMessage() => sendWorkMessage();
  List<Widget> inbox() => workInbox();
  void legacyOpenThread({Ad? ad}) {
    if (!canAct) {
      ensureAccess(() => openThread(ad: ad));
      return;
    }
    if (ad != null) {
      selectedAd = ad;
      final found = threads
          .indexWhere((t) => t.peer == ad.owner && t.subject == ad.title);
      if (found < 0) {
        threads.insert(
            0,
            ChatThread('thread-${threads.length}', ad.owner, ad.title, ad.image,
                'شرایط و زمان همکاری را اینجا هماهنگ کنید.',
                time: 'اکنون'));
        threadIndex = 0;
      } else {
        threadIndex = found;
      }
    }
    chat.clear();
    threads[threadIndex].unread = 0;
    go('chat');
  }

  Ad peerAd(String name) => demoAds.firstWhere((ad) => ad.owner == name,
      orElse: () => Ad('peer-$name', 'کارگری ساختمان و بتن‌ریزی', 'نیرو', false,
          'مشهد', 'الهیه', 'worker', 'روزانه با توافق', name));

  void notice(String text) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  Future<String?> edit(String title, String initial, {String hint = ''}) async {
    return showDialog<String>(
      context: context,
      builder: (_) => EditDialog(title: title, initial: initial, hint: hint),
    );
  }

  Future<void> createContract({String? peer, String? subject}) =>
      createSimpleContract(peer: peer, subject: subject);

  Future<void> chooseRegion() async {
    final value = await showModalBottomSheet<AreaFilter>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (_) => AreaPicker(initial: selectedArea));
    if (value != null && mounted) setState(() => selectedArea = value);
  }

  Future<void> chooseAdArea() async {
    final value = await showModalBottomSheet<AdLocation>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 460),
        builder: (_) => AreaPicker(
            initial: adArea,
            requireCity: true,
            pickLocation: true,
            initialPoint: adPoint));
    if (value != null && mounted)
      setState(() {
        adArea = value.area;
        adPoint = value.point;
      });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF2F3F5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Scaffold(
              appBar: page == 'home'
                  ? null
                  : AppBar(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.white,
                      automaticallyImplyLeading: false,
                      title: Text(
                        page == 'chat' ? chatPeerName : titles[page] ?? 'کمچه',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      leading: ![
                        'home',
                        'professionals',
                        'requests',
                        'inbox',
                        'me'
                      ].contains(page)
                          ? IconButton(
                              onPressed: back,
                              tooltip: 'بازگشت',
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 20,
                              ),
                            )
                          : null,
                      actions: page == 'chat'
                          ? [
                              PopupMenuButton<String>(
                                tooltip: 'امکانات گفت‌وگو',
                                onSelected: (v) {
                                  if (v == 'contract') {
                                    createContract(
                                        peer: chatPeerName,
                                        subject: chatSubject);
                                  } else if (v == 'appointment') {
                                    createVisit();
                                  } else {
                                    final c = currentWorkChat;
                                    if (c != null)
                                      showWorkProfile(c.peer(actorId));
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'profile',
                                      child: Text('پروفایل و سابقه')),
                                  PopupMenuItem(
                                      value: 'appointment',
                                      child: Text('ثبت قرار بازدید')),
                                  PopupMenuItem(
                                      value: 'contract',
                                      child: Text('تنظیم قرارداد'))
                                ],
                              )
                            ]
                          : null,
                      shape: const Border(bottom: BorderSide(color: line)),
                    ),
              body: loadingDemo
                  ? const Center(child: CircularProgressIndicator())
                  : kamchehCloudEnabled &&
                          ['home', 'professionals', 'requests'].contains(page)
                      ? CloudMarketplacePage(
                          key: ValueKey('cloud-$page'),
                          initialNeeds: page == 'requests',
                        )
                  : page == 'me'
                      ? accountHome()
                      : page == 'chat'
                          ? conversationBody()
                          : SingleChildScrollView(
                              key: ValueKey(page),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: body(),
                              ),
                            ),
              bottomNavigationBar: page == 'chat'
                  ? null
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      if (page == 'home' && !kamchehCloudEnabled)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                            child: SizedBox(
                                width: double.infinity,
                                child: button('ثبت آگهی', () => go('myAds'),
                                    icon: Icons.add))),
                      NavigationBar(
                        height: 60,
                        selectedIndex: tab,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        indicatorColor: const Color(0xFFFFEEEE),
                        onDestinationSelected: selectTab,
                        destinations: [
                          NavigationDestination(
                            icon: Icon(Icons.campaign_outlined),
                            selectedIcon: Icon(Icons.campaign, color: red),
                            label: 'آگهی‌ها',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people, color: red),
                            label: 'پروفایل‌ها',
                          ),
                          NavigationDestination(
                              icon: Icon(Icons.playlist_add_check_outlined),
                              selectedIcon:
                                  Icon(Icons.playlist_add_check, color: red),
                              label: 'درخواست‌ها'),
                          NavigationDestination(
                            icon: messageNavigationIcon(false),
                            selectedIcon: messageNavigationIcon(true),
                            label: 'پیام‌ها',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.person_outline_rounded),
                            selectedIcon: Icon(Icons.person, color: red),
                            label: 'صفحه من',
                          ),
                        ],
                      ),
                    ]),
            ),
          ),
        ),
      );

  List<Widget> body() => switch (page) {
        'home' => home(),
        'professionals' => professionals(),
        'requests' => requestFeed(),
        'pro' => professional(),
        'project' => project(),
        'contract' => contract(),
        'contracts' => contracts(),
        'request' => workerRequest(),
        'applicants' => applicants(),
        'worker' => worker(),
        'ledger' => ledger(),
        'finance' => finance(),
        'supplier' => supplier(),
        'chat' => [],
        'inbox' => messageHub(),
        'myAds' => ownServices(),
        'settings' => settingsView(),
        'activities' => activities(),
        'me' => me(),
        'estimate' => [const MaterialEstimator()],
        'squaring' => [const SquaringTool()],
        'reports' => myReports(),
        'publicMissing' => [
            emptyState('پروفایل پیدا نشد',
                'این شناسه در داده‌های این نسخه موجود نیست.')
          ],
        'rules' => rulesView(),
        'team' => teamView(),
        'ownProfile' => ownProfile(),
        'profilePreview' => publicProfileView(myProfile, preview: true),
        'profileStats' => profileStatsView(),
        'post' => ownServices(),
        'detail' => detail(),
        _ => home(),
      };
  Widget section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 7),
        child: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      );
  Widget small(String text) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: muted, height: 1.45),
      );
  Widget image(String name, {double w = 82, double h = 76}) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/images/$name.jpg',
          width: w,
          height: h,
          fit: BoxFit.cover,
        ),
      );
  Widget gallery(List<String> names) => Row(
        children: names
            .map(
              (name) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: image(name, h: 92),
                ),
              ),
            )
            .toList(),
      );
  Widget label(String text, {Color color = muted}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
  Widget button(
    String text,
    VoidCallback onPressed, {
    bool outlined = false,
    IconData? icon,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: outlined
            ? OutlinedButton(onPressed: onPressed, child: Text(text))
            : FilledButton(
                onPressed: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(child: Text(text, textAlign: TextAlign.center)),
                  ],
                ),
              ),
      );
  Widget pair(String name, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: small(name)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      );
  Widget panel(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
  Widget input(
    String title,
    TextEditingController controller, {
    bool number = false,
    bool required = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return required ? 'این قسمت را تکمیل کن' : null;
                if (number && (parseAmount(v) == null || parseAmount(v)! <= 0))
                  return 'یک عدد بیشتر از صفر وارد کن';
                return null;
              },
            ),
          ],
        ),
      );
  Widget listing(
    String title,
    String subtitle,
    String price,
    String asset,
    String route, {
    String time = 'امروز',
  }) =>
      InkWell(
        onTap: () {
          if (route == 'contract') contractIndex = 0;
          go(route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    small(subtitle),
                    const SizedBox(height: 4),
                    Text(price,
                        style: const TextStyle(fontSize: 13, color: muted)),
                    const SizedBox(height: 4),
                    small(time),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              image(asset),
            ],
          ),
        ),
      );
  List<Widget> home() => networkHome();
  Widget adRow(Ad ad) => networkAdRow(ad);

  List<Widget> professionals() => directoryView();
  List<Widget> professional() => profileView();

  List<Widget> project() => [
        panel([
          const Text(
            'ساخت ساختمان الهیه',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          small('مشهد · الهیه'),
        ]),
        Row(
          children: [
            Expanded(
              child: Text(
                'مرحله فعلی: $stage',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => stage = v),
              itemBuilder: (_) => [
                'آماده‌سازی',
                'دیوارچینی',
                'تأسیسات',
                'نازک‌کاری',
              ].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
              child: const Text('تغییر مرحله', style: TextStyle(color: red)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            'آماده‌سازی',
            'دیوارچینی',
            'تأسیسات',
            'نازک‌کاری',
          ].map((s) => label(s, color: s == stage ? red : muted)).toList(),
        ),
        section('نیازهای این مرحله'),
        small('افراد و تأمین‌کنندگان مشهد، متناسب با مرحله‌ای که انتخاب کردی.'),
        ...demoAds
            .where((ad) =>
                !ad.need &&
                ad.city == 'مشهد' &&
                switch (stage) {
                  'آماده‌سازی' =>
                    ad.title.contains('خاک') || ad.title.contains('داربست'),
                  'دیوارچینی' => ad.title.contains('بنایی') ||
                      ad.title.contains('بلوک') ||
                      ad.title.contains('شن'),
                  'تأسیسات' =>
                    ad.title.contains('ارت') || ad.title.contains('تأسیسات'),
                  _ => ad.title.contains('کاشی') || ad.title.contains('سرامیک'),
                })
            .map(adRow),
        button('ثبت نیاز برای این مرحله', () {
          postKind = 'نیاز دارم';
          go('post');
        }, outlined: true, icon: Icons.add),
        section('حساب پروژه'),
        pair(
          'هزینه‌های ثبت‌شده',
          money(
              expenses.where((e) => !e.income).fold(0, (n, e) => n + e.amount)),
        ),
        button('مشاهده دفتر مالی', () => go('ledger'), outlined: true),
        section('افراد مرتبط'),
        menuRow('علی رضایی', 'کارگری ساختمان · مشهد · ۴٫۷ ★',
            Icons.engineering_outlined, () {
          selectedAd = peerAd('علی رضایی');
          go('worker');
        }),
      ];
  List<Widget> workerRequest() => unifiedRequestForm();
  List<Widget> applicants() => requestDetails();
  List<Widget> worker() => profileView(workerMode: true);

  List<Widget> ledger() => accountingView();
  List<Widget> finance() => accountingView();
  List<Widget> supplier() => profileView(supplierMode: true);

  List<Widget> legacyInbox() => [
        SizedBox(
            height: 40,
            child: TextField(
                controller: inboxInput,
                onChanged: (v) => setState(() => inboxQuery = v),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                    hintText: 'جست‌وجو در گفت‌وگوها',
                    prefixIcon: Icon(Icons.search, size: 19),
                    fillColor: Color(0xFFF6F7F8)))),
        const SizedBox(height: 8),
        ...threads
            .asMap()
            .entries
            .where((e) =>
                '${e.value.peer} ${e.value.subject}'.contains(inboxQuery))
            .map((e) {
          final t = e.value;
          return InkWell(
              onTap: () {
                threadIndex = e.key;
                openThread();
              },
              child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: line))),
                  child: Row(children: [
                    image(t.image, w: 48, h: 48),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            Expanded(
                                child: Text(t.peer,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: t.unread > 0
                                            ? FontWeight.bold
                                            : FontWeight.w500))),
                            small(t.time)
                          ]),
                          Text(t.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 11, color: muted)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Expanded(
                                child: Text(t.last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11, color: muted))),
                            if (t.unread > 0)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: red,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(fa(t.unread),
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white)))
                          ])
                        ]))
                  ])));
        }),
      ];
  Widget legacyConversationBody() {
    final t = threads[threadIndex];
    return Column(children: [
      Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: const BoxDecoration(
              color: Color(0xFFF8F8F9),
              border: Border(bottom: BorderSide(color: line))),
          child: Row(children: [
            image(t.image, w: 30, h: 30),
            const SizedBox(width: 8),
            Expanded(
                child: Text(t.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted)))
          ])),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(
                child: TextButton.icon(
                    onPressed: createVisit,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: const Text('قرار بازدید',
                        style: TextStyle(fontSize: 11)))),
            Expanded(
                child: TextButton.icon(
                    onPressed: () =>
                        createContract(peer: t.peer, subject: t.subject),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('تنظیم قرارداد',
                        style: TextStyle(fontSize: 11))))
          ])),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
        bubble(t.incoming, false),
        ...t.outgoing.asMap().entries.map((e) => t.references.containsKey(e.key)
            ? sharedMessage(t.references[e.key]!)
            : bubble(e.value, true)),
        ...visits.where((v) => v.threadId == t.id).map(visitCard),
        ...drafts
            .asMap()
            .entries
            .where((e) => e.value.threadId == t.id)
            .map((e) => panel([
                  Text(e.value.title),
                  small(e.value.status),
                  TextButton(
                      onPressed: () {
                        contractIndex = e.key;
                        selectedContractId = e.value.id;
                        go('contract');
                      },
                      child: const Text('مشاهده قرارداد'))
                ])),
      ])),
      SafeArea(
          top: false,
          child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: line))),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: chat,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                            hintText: 'پیام بنویس…', isDense: true),
                        onSubmitted: (_) => sendMessage())),
                const SizedBox(width: 7),
                IconButton.filled(
                    tooltip: 'ارسال پیام',
                    onPressed: sendMessage,
                    icon: const Icon(Icons.send_rounded, size: 19))
              ]))),
    ]);
  }

  Widget bubble(String text, bool mine) => Align(
        alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: mine ? red : const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: mine ? Colors.white : ink,
              fontSize: 13,
              height: 1.8,
            ),
          ),
        ),
      );
  void legacySendMessage() {
    if (!canAct) {
      ensureAccess(sendMessage);
      return;
    }
    if (chat.text.trim().isEmpty) return;
    setState(() {
      sent.add(chat.text.trim());
      threads[threadIndex].time = 'اکنون';
    });
    chat.clear();
  }

  List<Widget> contract() => simpleContract();
  List<Widget> contracts() => simpleContracts();
  List<Widget> activities() => requestBoard();

  Widget menuRow(
          String title, String subtitle, IconData icon, VoidCallback action) =>
      InkWell(
          onTap: action,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: line))),
              child: Row(children: [
                Icon(icon, size: 21, color: muted),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      if (subtitle.isNotEmpty) small(subtitle)
                    ])),
                const Icon(Icons.chevron_left, size: 19, color: muted)
              ])));
  List<Widget> me() => accountView();
  List<Widget> ownProfile() => ownProfileView();
  List<Widget> post() => [
        small('نیازت را ثبت کن؛ افراد مرتبط بازدید یا پیشنهاد می‌دهند.'),
        button('ثبت درخواست جدید', () => startWorkRequest())
      ];

  Widget option(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback action,
  ) =>
      InkWell(
        onTap: action,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Icon(icon, color: red, size: 27),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    small(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: muted),
            ],
          ),
        ),
      );
  List<Widget> detail() => selectedAd.need ? workDetail() : serviceDetails();
}
