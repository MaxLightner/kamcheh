// Shared cloud marketplace (phase 1) for Android and Flutter web.
// Existing Flutter demo screens remain untouched until their complete server migration.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kamchehSupabaseUrl = String.fromEnvironment('KAMCHEH_SUPABASE_URL');
const kamchehSupabaseKey = String.fromEnvironment('KAMCHEH_SUPABASE_PUBLISHABLE_KEY');
const kamchehCloudEnabled =
    kamchehSupabaseUrl != '' && kamchehSupabaseKey != '';

class CloudMarketplacePage extends StatefulWidget {
  const CloudMarketplacePage({super.key, this.initialNeeds = false});
  final bool initialNeeds;

  @override
  State<CloudMarketplacePage> createState() => _CloudMarketplacePageState();
}

class _CloudMarketplacePageState extends State<CloudMarketplacePage> {
  SupabaseClient get db => Supabase.instance.client;
  bool _loading = true;
  late bool _needs;
  String _city = '';
  String _query = '';
  String? _error;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _requests = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _needs = widget.initialNeeds;
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await Future.wait([
        db.from('service_listings')
            .select('id,title,details,city,district,category,amount,skills,created_at')
            .eq('archived', false).eq('enabled', true)
            .order('created_at', ascending: false).limit(100),
        db.from('work_needs')
            .select('id,title,details,city,district,category,budget,skills,created_at')
            .eq('archived', false).eq('closed', false)
            .order('created_at', ascending: false).limit(100),
      ]);
      if (!mounted) return;
      setState(() {
        _services = (result[0] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
        _requests = (result[1] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'دریافت اطلاعات از سرور ناموفق بود.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String? _normalizePhone(String raw) {
    var phone = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    phone = phone.replaceAllMapped(RegExp(r'[۰-۹]'),
        (m) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!).toString());
    if (RegExp(r'^09\d{9}$').hasMatch(phone)) return '+98${phone.substring(1)}';
    if (RegExp(r'^\+989\d{9}$').hasMatch(phone)) return phone;
    return null;
  }

  Future<bool> _ensureLogin() async {
    if (db.auth.currentUser != null) return true;
    final phone = TextEditingController();
    final token = TextEditingController();
    String? normalized;
    bool codeSent = false;
    bool busy = false;
    bool loggedIn = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, change) {
          return AlertDialog(
            title: const Text('ورود به کمچه'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('یک حساب مشترک برای سایت و اپلیکیشن'),
              const SizedBox(height: 14),
              TextField(controller: phone, enabled: !codeSent,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'شماره موبایل')),
              if (codeSent) TextField(controller: token,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'کد پیامکی')),
            ]),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('انصراف')),
              FilledButton(onPressed: busy ? null : () async {
                change(() => busy = true);
                try {
                  if (!codeSent) {
                    normalized = _normalizePhone(phone.text);
                    if (normalized == null) throw Exception('شماره موبایل معتبر نیست.');
                    await db.auth.signInWithOtp(phone: normalized!);
                    change(() => codeSent = true);
                  } else {
                    await db.auth.verifyOTP(phone: normalized!, token: token.text.trim(),
                      type: OtpType.sms);
                    loggedIn = db.auth.currentUser != null;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                } catch (_) { _notify('ارسال یا تأیید کد انجام نشد. تنظیمات پیامک را بررسی کن.');
                } finally { if (dialogContext.mounted) change(() => busy = false); }
              }, child: Text(codeSent ? 'تأیید و ورود' : 'ارسال کد')),
            ],
          );
        }),
      );
    } finally {
      phone.dispose();
      token.dispose();
    }
    return loggedIn;
  }

  Future<bool> _ensureProfile() async {
    final user = db.auth.currentUser;
    if (user == null) return false;
    try {
      final row = await db.from('profiles')
          .select('display_name,city,specialty,is_complete').eq('id',user.id).maybeSingle();
      if (row?['is_complete'] == true) return true;
      if (!mounted) return false;
      final name = TextEditingController(text: (row?['display_name'] ?? '').toString());
      final city = TextEditingController(text: (row?['city'] ?? '').toString());
      final specialty = TextEditingController(text: (row?['specialty'] ?? '').toString());
      bool saved = false;
      try {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('تکمیل پروفایل'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: [
              const Text('برای ثبت آگهی یا درخواست، نام، شهر و تخصص لازم است.'),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی')),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'شهر')),
              TextField(controller: specialty, decoration: const InputDecoration(labelText: 'حوزه فعالیت')),
            ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بعداً')),
            FilledButton(onPressed: () async {
              if (name.text.trim().length < 2 || city.text.trim().length < 2 ||
                  specialty.text.trim().length < 2) { _notify('هر سه بخش باید تکمیل شوند.');return; }
              try {
                await db.from('profiles').upsert({
                  'id': user.id,
                  'display_name': name.text.trim(),
                  'city': city.text.trim(),
                  'specialty': specialty.text.trim(),
                  'is_complete': true,
                });
                saved = true;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) { _notify('ذخیره پروفایل انجام نشد.'); }
            }, child: const Text('ذخیره'))],
        ));
      } finally { name.dispose();city.dispose();specialty.dispose(); }
      return saved;
    } catch (_) {
      _notify('خواندن پروفایل ممکن نیست.');
      return false;
    }
  }

  Future<void> _create() async {
    if (!await _ensureLogin() || !mounted) return;
    if (!await _ensureProfile() || !mounted) return;
    final title = TextEditingController();
    final details = TextEditingController();
    final category = TextEditingController();
    final amount = TextEditingController();
    String city = 'مشهد';
    bool submitted = false;
    try {
      await showDialog<void>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx,change) => AlertDialog(
          title: Text(_needs ? 'ثبت درخواست کار' : 'معرفی خدمات'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, maxLength: 140,
              decoration: const InputDecoration(labelText: 'عنوان')),
            TextField(controller: details, minLines: 3, maxLines: 5,
              decoration: const InputDecoration(labelText: 'توضیحات')),
            DropdownButtonFormField<String>(initialValue: city,
              items: ['مشهد','طرقبه','شاندیز','گلبهار','چناران'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
              onChanged: (value) => change(() => city = value ?? 'مشهد')),
            TextField(controller: category, decoration: const InputDecoration(labelText:'تخصص')),
            TextField(controller: amount,keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _needs ? 'بودجه (اختیاری)' : 'قیمت (اختیاری)')),
          ])),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(ctx),child:const Text('انصراف')),
            FilledButton(onPressed: () async {
              final t=title.text.trim(),d=details.text.trim();
              if(t.length<5 || d.length<10){_notify('عنوان حداقل ۵ و شرح حداقل ۱۰ حرف لازم دارد.');return;}
              final a=amount.text.trim();final n=a.isEmpty?null:int.tryParse(a);
              if(a.isNotEmpty && (n==null || n<0)){_notify('مبلغ معتبر وارد کن.');return;}
              try {
                await db.from(_needs?'work_needs':'service_listings').insert({
                  'owner_id': db.auth.currentUser!.id,'title':t,'details':d,
                  'city':city,'category':category.text.trim().isEmpty?'خدمات':category.text.trim(),
                  _needs?'budget':'amount':n,
                });
                submitted=true;
                if(ctx.mounted) Navigator.pop(ctx);
              } catch(_){_notify('ثبت در سرور انجام نشد.');}
            },child:const Text('ثبت')),
          ],
        )));
    } finally {title.dispose();details.dispose();category.dispose();amount.dispose();}
    if(submitted){_notify('اطلاعات با موفقیت در سرور ثبت شد.');await _refresh();}
  }

  List<Map<String,dynamic>> get _visible {
    final q=_query.trim().toLowerCase();
    return (_needs?_requests:_services).where((item){
      if(_city.isNotEmpty && item['city']!=_city)return false;
      return q.isEmpty || ['title','details','city','category'].any((key)=>(item[key]??'').toString().toLowerCase().contains(q));
    }).toList();
  }

  Widget _tile(Map<String,dynamic> item){
    final price=item[_needs?'budget':'amount'];
    return Card(margin:const EdgeInsets.only(bottom:10),color:Colors.white,
      child:InkWell(onTap:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text((item['title']??'').toString()),
        content:Text((item['details']??'').toString()),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('بستن'))])),
        child:Padding(padding:const EdgeInsets.all(14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((item['title']??'').toString(),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
            const SizedBox(height:7),
            Text((item['details']??'').toString(),maxLines:2,overflow:TextOverflow.ellipsis),
            const SizedBox(height:8),
            Row(children:[const Icon(Icons.location_on_outlined,size:16),
              Text((item['city']??'').toString()),const Spacer(),
              Text(price==null?'توافقی':'${price.toString()} تومان',style:const TextStyle(fontWeight:FontWeight.bold))]),
          ])),),);
  }

  @override
  Widget build(BuildContext context){
    return RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(12),children:[
      const Text('بازار آنلاین کمچه',style:TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
      const Padding(padding:EdgeInsets.symmetric(vertical:7),child:Text(
        'داده‌های این بخش با سایت مشترک است. دیگر ابزارهای اپ فعلاً در حالت آزمایشی‌اند.',
        style:TextStyle(color:Colors.black54,fontSize:12))),
      Row(children:[
        Expanded(child:ChoiceChip(label:const Text('متخصصان و اکیپ‌ها'),selected:!_needs,
          onSelected:(_)=>setState(()=>_needs=false))),
        const SizedBox(width:8),
        Expanded(child:ChoiceChip(label:const Text('درخواست‌های کار'),selected:_needs,
          onSelected:(_)=>setState(()=>_needs=true))),
      ]),
      const SizedBox(height:10),
      TextField(controller:_search,onChanged:(v)=>setState(()=>_query=v),
        decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'جست‌وجو در بازار')),
      const SizedBox(height:8),
      Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:_city,
        decoration:const InputDecoration(labelText:'شهر'),
        items:['','مشهد','طرقبه','شاندیز','گلبهار','چناران'].map((v)=>DropdownMenuItem(
          value:v,child:Text(v.isEmpty?'همه شهرها':v))).toList(),
        onChanged:(v)=>setState(()=>_city=v??''))),
        const SizedBox(width:8),
        IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh),tooltip:'به‌روزرسانی')]),
      const SizedBox(height:10),
      FilledButton.icon(onPressed:_create,icon:const Icon(Icons.add),
        label:Text(_needs?'ثبت درخواست کار':'معرفی خدمات')),
      const SizedBox(height:12),
      if(_loading)const LinearProgressIndicator(),
      if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
      if(!_loading && _visible.isEmpty)const Padding(padding:EdgeInsets.all(24),
        child:Center(child:Text('هنوز موردی ثبت نشده است.'))),
      ..._visible.map(_tile),
    ]));
  }
}