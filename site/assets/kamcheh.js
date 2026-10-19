/* Public, shared-marketplace web client. Never store privileged Supabase keys here. */
const cfg = window.KAMCHEH_CONFIG || {};
const configured = Boolean(cfg.supabaseUrl && cfg.supabaseAnonKey);
const state = {client:null, session:null, services:[], needs:[], tab:'services', query:'', city:''};
const $ = (selector) => document.querySelector(selector);
const esc = (v='') => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const toast = (message) => { const el = $('#k-toast');if(!el) return;el.textContent=message;el.classList.add('k-show');clearTimeout(toast.timeout);toast.timeout=setTimeout(()=>el.classList.remove('k-show'),4200); };
const text = (v) => String(v||'').trim();
function errorMessage(error){return error?.message?.includes('Invalid login') ? 'اطلاعات ورود معتبر نیست.' : (error?.message||'ارتباط با سرور برقرار نشد.');}
function openDialog(content) {const dlg=$('#k-dialog');$('#k-form-content').innerHTML=content;dlg.showModal();}
function closeDialog() {$('#k-dialog')?.close();}
function authRequired() {
 if(!configured){toast('ابتدا باید آدرس و کلید عمومی Supabase در assets/config.js تنظیم شود.');return false;}
 if(!state.session){showLogin();return false;}
 return true;
}
function validPhone(raw){
 let p=String(raw||'').replace(/[۰-۹]/g,c=>String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c))).replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).replace(/[\s()-]/g,'');
 if(p.startsWith('0098')) p='+'+p.slice(2);
 if(/^09\d{9}$/.test(p)) return '+98'+p.slice(1);
 if(/^9\d{9}$/.test(p)) return '+98'+p;
 if(/^\+989\d{9}$/.test(p)) return p;
 return null;
}
function showLogin(){
 if(!configured){toast('اتصال Supabase هنوز تنظیم نشده است.');return;}
 if(state.session) return showAccount();
 openDialog('<h3>ورود یا ثبت‌نام کمچه</h3><p>ورود با شماره تلفن و کد یک‌بارمصرف. همان حساب در وب و اپ استفاده می‌شود.</p><label for="k-phone">شماره موبایل</label><input id="k-phone" required type="tel" dir="ltr" placeholder="09123456789" autocomplete="tel"><button type="button" class="k-primary" id="k-otp">ارسال کد تأیید</button><div id="k-otp-area"></div>');
 $('#k-otp').onclick=async()=>{
  const phone=validPhone($('#k-phone').value);if(!phone){toast('شماره موبایل معتبر وارد کن.');return;}
  const btn=$('#k-otp');btn.disabled=true;
  try {
   const {error}=await state.client.auth.signInWithOtp({phone});if(error) throw error;
   $('#k-otp-area').innerHTML='<label for="k-code">کد تأیید پیامکی</label><input id="k-code" type="text" inputmode="numeric" dir="ltr" autocomplete="one-time-code" placeholder="کد دریافت‌شده"><button type="button" class="k-primary" id="k-verify">ورود</button>';
   $('#k-verify').onclick=async()=>{try{const code=$('#k-code').value.replace(/\s/g,'');const {error}=await state.client.auth.verifyOtp({phone,token:code,type:'sms'});if(error)throw error;closeDialog();toast('وارد حساب کاربری شدی.');}catch(e){toast(errorMessage(e));}};
  }catch(e){toast(errorMessage(e));btn.disabled=false;}
 };
}
function showAccount(){
 if(!state.session) return showLogin();
 const phone=esc(state.session.user.phone||'حساب کاربری');
 openDialog(`<h3>حساب کمچه</h3><p>شماره: <b dir="ltr">${phone}</b></p><p>این حساب برای سایت و اپلیکیشن مشترک خواهد بود. گزینه‌های ثبت آگهی و درخواست از صفحه اصلی در دسترس‌اند.</p><button id="k-signout" class="k-outline" style="width:100%" type="button">خروج از حساب</button>`);
 $('#k-signout').onclick=async()=>{await state.client.auth.signOut();closeDialog();toast('خروج انجام شد.');};
}
function showPostNeed(){
 if(!authRequired())return;
 openDialog('<h3>ثبت درخواست کار</h3><p>درخواست در دیتابیس ذخیره می‌شود و در هر دو نسخه قابل خواندن است.</p><label>عنوان درخواست</label><input id="k-title" required maxlength="140" placeholder="مثلاً اکیپ گچ‌کاری برای ساختمان ۴ طبقه"><label>شرح کار</label><textarea id="k-details" required maxlength="3000"></textarea><label>شهر</label><select id="k-post-city"><option>مشهد</option><option>طرقبه</option><option>شاندیز</option><option>گلبهار</option><option>چناران</option></select><label>تخصص موردنیاز</label><input id="k-category" maxlength="80" placeholder="گچ‌کاری، نما، اسکلت…"><label>بودجه تقریبی (تومان؛ اختیاری)</label><input type="number" min="0" id="k-amount"><button id="k-submit" type="button" class="k-primary">ثبت درخواست</button>');
 $('#k-submit').onclick=async()=>{
  const title=text($('#k-title').value),details=text($('#k-details').value);if(title.length<5||details.length<10){toast('عنوان حداقل ۵ و شرح حداقل ۱۰ کاراکتر لازم دارد.');return;}
  const btn=$('#k-submit');btn.disabled=true;
  try{
   const amount=text($('#k-amount').value);
   const data={owner_id:state.session.user.id,title,details,city:$('#k-post-city').value,category:text($('#k-category').value)||'خدمات',budget:amount?Number(amount):null};
   const {error}=await state.client.from('work_needs').insert(data);if(error)throw error;
   closeDialog();toast('درخواست ثبت شد.');await refresh();switchTab('needs');
  }catch(e){toast(errorMessage(e));}finally{btn.disabled=false;}
 };
}
function showPostService(){
 if(!authRequired())return;
 openDialog('<h3>معرفی خدمات و اکیپ</h3><p>آگهی ثبت‌شده در سایت و نسخه نصب‌شدنی قابل بازیابی خواهد بود.</p><label>عنوان خدمات</label><input id="k-title" required maxlength="140" placeholder="مثلاً اکیپ آرماتوربندی و قالب‌بندی"><label>توضیحات</label><textarea id="k-details" required maxlength="3000"></textarea><label>شهر</label><select id="k-post-city"><option>مشهد</option><option>طرقبه</option><option>شاندیز</option><option>گلبهار</option><option>چناران</option></select><label>تخصص</label><input id="k-category" maxlength="80" placeholder="مثلاً آرماتوربندی"><label>قیمت (تومان؛ اختیاری)</label><input id="k-amount" type="number" min="0"><button type="button" id="k-submit" class="k-primary">ثبت آگهی</button>');
 $('#k-submit').onclick=async()=>{
  const title=text($('#k-title').value),details=text($('#k-details').value);if(title.length<5||details.length<10){toast('عنوان حداقل ۵ و توضیحات حداقل ۱۰ کاراکتر لازم دارد.');return;}
  const btn=$('#k-submit');btn.disabled=true;
  try{
   const amount=text($('#k-amount').value);
   const data={owner_id:state.session.user.id,title,details,city:$('#k-post-city').value,category:text($('#k-category').value)||'خدمات',amount:amount?Number(amount):null};
   const {error}=await state.client.from('service_listings').insert(data);if(error)throw error;
   closeDialog();toast('آگهی ثبت شد.');await refresh();switchTab('services');
  }catch(e){toast(errorMessage(e));}finally{btn.disabled=false;}
 };
}
function card(o,type){
 const isService=type==='services'; const amount=isService?o.amount:o.budget;
 const price=amount!=null?`${Number(amount).toLocaleString('fa-IR')} تومان`:'توافقی';
 const time=o.created_at?new Date(o.created_at).toLocaleDateString('fa-IR'):'—';
 const kind=isService?'معرفی خدمات':'درخواست کار';
 return `<article class="k-card"><div class="k-tags"><span>${kind}</span><span>${esc(o.category||'ساختمان')}</span></div><h3>${esc(o.title)}</h3><p>${esc(o.details)}</p><div class="k-meta">${esc(o.city)} ${o.district?'، '+esc(o.district):''} | ${esc(time)}</div><div class="k-meta">${isService?'قیمت':'بودجه'}: ${esc(price)}</div></article>`;
}
function render(){
 const selector=state.tab==='services'?'#kamcheh-services':'#kamcheh-requests';
 const list=state.tab==='services'?state.services:state.needs;
 const items=list.filter(o=>(!state.city||o.city===state.city)&&(!state.query||[o.title,o.details,o.city,o.category].join(' ').includes(state.query)));
 const container=$(selector);if(!container)return;
 container.innerHTML=items.length?items.map(o=>card(o,state.tab)).join(''):`<div class="k-empty">${configured?'فعلاً موردی مطابق این جستجو ثبت نشده است.':'پایگاه داده هنوز متصل نشده؛ این بخش پس از تنظیم Supabase داده واقعی نشان می‌دهد.'}</div>`;
}
function switchTab(tab){
 state.tab=tab;const s=$('#kamcheh-services'),n=$('#kamcheh-requests');if(!s||!n)return;
 s.hidden=tab!=='services';n.hidden=tab!=='needs';
 document.querySelectorAll('[data-k-tab]').forEach(b=>{const active=b.dataset.kTab===tab;b.classList.toggle('k-active',active);b.setAttribute('aria-selected',String(active));});render();
}
async function refresh(){
 if(!state.client){render();return;}
 try{
  const [s,n]=await Promise.all([
   state.client.from('service_listings').select('id,title,details,city,district,category,amount,created_at').eq('enabled',true).eq('archived',false).order('created_at',{ascending:false}).limit(100),
   state.client.from('work_needs').select('id,title,details,city,district,category,budget,created_at').eq('closed',false).eq('archived',false).order('created_at',{ascending:false}).limit(100)]);
  if(s.error)throw s.error;if(n.error)throw n.error;
  state.services=s.data||[];state.needs=n.data||[];
  if($('#k-status'))$('#k-status').textContent=`${state.services.length.toLocaleString('fa-IR')} آگهی خدمات و ${state.needs.length.toLocaleString('fa-IR')} درخواست کار در پایگاه داده`;
  render();
 }catch(e){if($('#k-status'))$('#k-status').textContent='خطا در دریافت داده از سرور';toast(errorMessage(e));}
}
function wire(){
 document.addEventListener('click',e=>{
  const action=e.target.closest('[data-k-action]');
  if(action){e.preventDefault();({account:showAccount,'post-need':showPostNeed,'post-service':showPostService,close:closeDialog})[action.dataset.kAction]?.();return;}
  const unavailable=e.target.closest('a[data-k-unavailable]');if(unavailable){e.preventDefault();toast('این بخش هنوز در نسخه آزمایشی پیاده‌سازی نشده است.');}
 });
 $('#k-dialog')?.addEventListener('click',e=>{if(e.target===$('#k-dialog'))closeDialog();});
 document.querySelectorAll('[data-k-tab]').forEach(b=>b.addEventListener('click',()=>switchTab(b.dataset.kTab)));
 $('#k-search')?.addEventListener('input',e=>{state.query=text(e.target.value);render();});
 $('#k-city')?.addEventListener('change',e=>{state.city=e.target.value;render();});
 $('#k-reload')?.addEventListener('click',refresh);
 const heroSearch=document.querySelector('section input[placeholder*="جستجوی تخصص"]');
 heroSearch?.addEventListener('input',e=>{if($('#k-search')){$('#k-search').value=e.target.value;state.query=text(e.target.value);render();}});
 document.querySelectorAll('a[href*="#kamcheh-requests"]').forEach(a=>a.addEventListener('click',()=>switchTab('needs')));
 if(location.hash==='#kamcheh-requests')switchTab('needs');else render();
}
async function start(){
 wire();
 if(!configured){if($('#k-status'))$('#k-status').textContent='اتصال Supabase تنظیم نشده است؛ هیچ داده ساختگی به‌جای داده واقعی نمایش داده نمی‌شود.';return;}
 try{
  const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm');
  state.client=createClient(cfg.supabaseUrl,cfg.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true}});
  const {data}=await state.client.auth.getSession();state.session=data?.session||null;
  state.client.auth.onAuthStateChange((_event,session)=>{state.session=session;});
  await refresh();
  document.body.classList.add('k-connected');
 }catch(e){toast('کتابخانه یا سرویس Supabase در دسترس نیست. '+errorMessage(e));if($('#k-status'))$('#k-status').textContent='اتصال به سرور ناموفق بود.';}
}
start();