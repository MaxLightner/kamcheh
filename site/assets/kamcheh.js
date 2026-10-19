/* Kamcheh shared web interface: UI reads one data source at a time.
   Demo records are never persisted, authenticated, or combined with server data. */
const cfg=window.KAMCHEH_CONFIG||{};
const configured=Boolean(cfg.supabaseUrl&&cfg.supabasePublishableKey);
const demoMode=cfg.demo===true||new URLSearchParams(typeof location.search==='string'?location.search:'').get('demo')==='1';
const state={client:null,session:null,profile:null,services:[],needs:[],tab:'services',query:'',city:'',category:'',sort:'new',mode:configured?'server':demoMode?'demo':'unconfigured'};
const $=s=>document.querySelector(s);
const $$=s=>document.querySelectorAll(s);
const text=v=>String(v??'').trim();
function digits(value){return String(value??'').replace(/[۰-۹]/g,c=>String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c))).replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).replace(/[٬,\s]/g,'');}
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num=n=>Number(n).toLocaleString('fa-IR');
const toast=message=>{const e=$('#k-toast');if(!e)return;e.textContent=message;e.classList.add('k-show');clearTimeout(toast.timeout);toast.timeout=setTimeout(()=>e.classList.remove('k-show'),4200);};
function errorMessage(error){return error?.message?.includes('Invalid login')?'اطلاعات ورود معتبر نیست.':(error?.message||'ارتباط با سرور برقرار نشد.');}
function openDialog(content){const dlg=$('#k-dialog');if(!dlg)return;$('#k-form-content').innerHTML=content;if(!dlg.open)dlg.showModal();}
function closeDialog(){$('#k-dialog')?.close();}
function authRequired(){if(!configured){toast('برای ثبت اطلاعات، ابتدا بک‌اند مشترک کمچه باید متصل شود.');return false;}if(!state.session){showLogin();return false;}if(!state.profile?.is_complete){showProfileSetup();return false;}return true;}
function validPhone(raw){let p=String(raw||'').replace(/[۰-۹]/g,c=>String('۰۱۲۳۴۵۶۷۸۹'.indexOf(c))).replace(/[٠-٩]/g,c=>String('٠١٢٣٤٥٦٧٨٩'.indexOf(c))).replace(/[\s()-]/g,'');if(p.startsWith('0098'))p='+'+p.slice(2);if(/^09\d{9}$/.test(p))return '+98'+p.slice(1);if(/^9\d{9}$/.test(p))return '+98'+p;if(/^\+989\d{9}$/.test(p))return p;return null;}

async function fetchProfile(){
 if(!state.client||!state.session){state.profile=null;return;}
 try{
  const {data,error}=await state.client.from('profiles')
   .select('id,display_name,city,specialty,is_complete')
   .eq('id',state.session.user.id).maybeSingle();
  if(error)throw error;state.profile=data||null;
 }catch(_){state.profile=null;toast('دریافت پروفایل انجام نشد.');}
}
function showProfileSetup(){
 if(!state.session)return showLogin();
 const previous=state.profile||{};
 openDialog('<h3>پروفایل کمچه</h3><p>برای ثبت آگهی فقط نام، شهر و تخصص لازم است. مشاهده بازار بدون تکمیل پروفایل هم ممکن است.</p>'+
 '<label for="k-name">نام نمایشی</label><input id="k-name" maxlength="120" required>'+
 '<label for="k-my-city">شهر</label><input id="k-my-city" maxlength="100" required>'+
 '<label for="k-specialty">حوزه فعالیت</label><input id="k-specialty" maxlength="120" required>'+
 '<button type="button" class="btn btn-primary" id="k-profile-save">ذخیره پروفایل</button>');
 $('#k-name').value=previous.display_name||'';
 $('#k-my-city').value=previous.city||'';
 $('#k-specialty').value=previous.specialty||'';
 $('#k-profile-save').onclick=async()=>{
  const name=text($('#k-name').value),city=text($('#k-my-city').value),specialty=text($('#k-specialty').value);
  if(name.length<2||city.length<2||specialty.length<2){toast('نام، شهر و تخصص حداقل دو حرف داشته باشند.');return;}
  const btn=$('#k-profile-save');btn.disabled=true;
  try{
   const {error}=await state.client.from('profiles').upsert({
    id:state.session.user.id,display_name:name,city,specialty,is_complete:true
   });if(error)throw error;
   await fetchProfile();closeDialog();toast('پروفایل ذخیره شد.');
  }catch(error){toast(errorMessage(error));}finally{btn.disabled=false;}
 };
}

function showLogin(){
 if(!configured){toast('ورود پس از اتصال دیتابیس و پیامک فعال می‌شود.');return;}
 if(state.session)return showAccount();
 openDialog('<h3>ورود به کمچه</h3><p>شماره موبایل و کد یک‌بارمصرف؛ یک حساب برای سایت و اپ.</p><p>پروفایل و آگهی عمومی است؛ نشانی دقیق، مدارک قرارداد و حسابداری خصوصی‌اند. محتوای خلاف واقع و انتشار مدارک دیگران مجاز نیست.</p><label><input id="k-rules" type="checkbox"> قوانین آزمایشی کمچه را می‌پذیرم.</label><label for="k-phone">شماره موبایل</label><input id="k-phone" required type="tel" dir="ltr" placeholder="09123456789" autocomplete="tel"><button type="button" class="btn btn-primary" id="k-otp">ارسال کد</button><div id="k-otp-area"></div>');
 $('#k-otp').onclick=async()=>{if(!$('#k-rules').checked){toast('ابتدا قوانین را بخوان و تأیید کن.');return;}const phone=validPhone($('#k-phone').value);if(!phone){toast('شماره موبایل معتبر وارد کن.');return;}const b=$('#k-otp');b.disabled=true;try{const {error}=await state.client.auth.signInWithOtp({phone});if(error)throw error;$('#k-otp-area').innerHTML='<label for="k-code">کد پیامکی</label><input id="k-code" type="text" inputmode="numeric" dir="ltr" autocomplete="one-time-code"><button type="button" class="btn btn-primary" id="k-verify">تأیید و ورود</button>';$('#k-verify').onclick=async()=>{try{const code=$('#k-code').value.replace(/\s/g,'');const {error}=await state.client.auth.verifyOtp({phone,token:digits(code),type:'sms'});if(error)throw error;const accepted=await state.client.rpc('accept_rules',{version:'2026-10-19'});if(accepted.error)throw accepted.error;closeDialog();toast('ورود انجام شد.');updateAccountButton();await fetchProfile();if(!state.profile?.is_complete)showProfileSetup();}catch(e){toast(errorMessage(e));}};}catch(e){toast(errorMessage(e));b.disabled=false;}};
}
function updateAccountButton(){const el=$('[data-k-action="account"] span:last-child');if(el)el.textContent=state.session?'حساب من':'ورود';}
function showAccount(){if(!state.session)return showLogin();const phone=esc(state.session.user.phone||'حساب کاربری');openDialog(`<h3>حساب کمچه</h3><p>شماره موبایل: <b dir="ltr">${phone}</b></p><button type="button" class="btn btn-secondary" id="k-inbox">پیام‌ها و ارتباط‌ها</button><a class="btn btn-secondary" href="app/">قرارداد، بازدید و حسابداری در اپ</a><button id="k-edit-profile" class="btn btn-primary" style="width:100%" type="button">ویرایش پروفایل</button><button id="k-signout" class="k-outline" style="width:100%" type="button">خروج از حساب</button>`);$('#k-edit-profile').onclick=showProfileSetup;$('#k-inbox').onclick=showInbox;$('#k-signout').onclick=async()=>{const {error}=await state.client.auth.signOut({scope:'local'});if(error){toast(errorMessage(error));return;}state.session=null;state.profile=null;closeDialog();toast('خروج انجام شد.');updateAccountButton();};}
function showPostNeed(){
 if(!authRequired())return;
 openDialog('<h3>ثبت درخواست کار</h3><p>نیاز اجرایی پروژه را ثبت کن.</p><label for="k-title">عنوان</label><input id="k-title" required maxlength="140" placeholder="مثلاً اکیپ قالب‌بندی برای ساختمان چهارطبقه"><label for="k-details">شرح کار</label><textarea id="k-details" required maxlength="3000"></textarea><label for="k-post-city">شهر</label><select id="k-post-city"><option>مشهد</option><option>طرقبه</option><option>شاندیز</option><option>گلبهار</option><option>چناران</option></select><label for="k-category">تخصص مورد نیاز</label><input id="k-category" maxlength="80" placeholder="مثلاً اسکلت و بتن"><label for="k-amount">بودجه تقریبی (تومان؛ اختیاری)</label><input type="number" min="0" id="k-amount"><button id="k-submit" type="button" class="btn btn-primary">ثبت درخواست</button>');
 $('#k-submit').onclick=async()=>{const title=text($('#k-title').value),details=text($('#k-details').value);if(title.length<5||details.length<10){toast('عنوان باید حداقل ۵ و شرح حداقل ۱۰ کاراکتر باشد.');return;}const btn=$('#k-submit');btn.disabled=true;try{const amount=digits($('#k-amount').value),parsed=amount?Number(amount):null;if(amount&&(!Number.isSafeInteger(parsed)||parsed<=0))throw Error('مبلغ مثبت و معتبر وارد کن.');const record={owner_id:state.session.user.id,title,details,city:$('#k-post-city').value,category:text($('#k-category').value)||'خدمات',budget:parsed};const {error}=await state.client.from('work_needs').insert(record);if(error)throw error;closeDialog();toast('درخواست ثبت شد.');await refresh();switchTab('needs');}catch(e){toast(errorMessage(e));}finally{btn.disabled=false;}};
}
function showPostService(){
 if(!authRequired())return;
 openDialog('<h3>معرفی خدمات</h3><p>خدمات اجرایی یا اکیپ خود را معرفی کن.</p><label for="k-title">عنوان</label><input id="k-title" required maxlength="140" placeholder="مثلاً اکیپ آرماتوربندی"><label for="k-details">توضیحات خدمات</label><textarea id="k-details" required maxlength="3000"></textarea><label for="k-post-city">شهر</label><select id="k-post-city"><option>مشهد</option><option>طرقبه</option><option>شاندیز</option><option>گلبهار</option><option>چناران</option></select><label for="k-category">تخصص</label><input id="k-category" maxlength="80" placeholder="مثلاً اسکلت و بتن"><label for="k-amount">قیمت (تومان؛ اختیاری)</label><input id="k-amount" type="number" min="0"><button type="button" id="k-submit" class="btn btn-primary">ثبت آگهی</button>');
 $('#k-submit').onclick=async()=>{const title=text($('#k-title').value),details=text($('#k-details').value);if(title.length<5||details.length<10){toast('عنوان باید حداقل ۵ و توضیحات حداقل ۱۰ کاراکتر باشد.');return;}const btn=$('#k-submit');btn.disabled=true;try{const amount=digits($('#k-amount').value),parsed=amount?Number(amount):null;if(amount&&(!Number.isSafeInteger(parsed)||parsed<=0))throw Error('مبلغ مثبت و معتبر وارد کن.');const record={owner_id:state.session.user.id,title,details,city:$('#k-post-city').value,category:text($('#k-category').value)||'خدمات',amount:parsed};const {error}=await state.client.from('service_listings').insert(record);if(error)throw error;closeDialog();toast('آگهی ثبت شد.');await refresh();switchTab('services');}catch(e){toast(errorMessage(e));}finally{btn.disabled=false;}};
}
function listing(o){return {owner_id:text(o.owner_id),owner:o.owner||null,deadline:o.deadline||null,id:text(o.id),title:text(o.title),details:text(o.details),city:text(o.city),district:text(o.district),category:text(o.category),amount:o.amount??null,budget:o.budget??null,created_at:text(o.created_at),skills:Array.isArray(o.skills)?o.skills:[],image:text(o.image_url||o.image),demo:Boolean(o.demo)};}
const priceOf=(o,type)=>{const amount=type==='services'?o.amount:o.budget;return amount==null?'توافقی':`${num(amount)} تومان`;};
function card(o,type){
 const service=type==='services';const category=esc(o.category||'ساختمان');const skills=(o.skills||[]).slice(0,2).map(s=>`<span>${esc(s)}</span>`).join('');
 const fallback='<div class="k-image-fallback"><span class="material-icons-outlined">'+(service?'construction':'assignment')+'</span></div>';
 const image=service&&o.image?`<img src="${esc(o.image)}" alt="تصویر نمونه مرتبط با ${esc(o.category||'ساختمان')}" loading="lazy" onerror="this.style.display='none'">`:fallback;
 return `<article class="k-card" data-type="${type}"><div class="k-card-visual">${image}<span class="k-card-tag">${category}</span></div><div class="k-card-body"><h3 class="k-card-title">${esc(o.title)}</h3><p class="k-card-desc">${esc(o.details)}</p><div class="k-card-meta"><span class="material-icons-outlined">location_on</span>${esc(o.city)}${o.district?'، '+esc(o.district):''}</div>${skills?`<div class="k-card-skills">${skills}</div>`:''}</div><div class="k-card-bottom"><div class="k-card-price"><span>${service?'هزینه خدمات':'بودجه پروژه'}</span><strong>${esc(priceOf(o,type))}</strong></div><button type="button" data-k-detail="${esc(o.id)}" data-k-type="${type}">جزئیات <span aria-hidden="true">←</span></button></div></article>`;
}
function visibleItems(){
 const list=state.tab==='services'?state.services:state.needs;
 const q=state.query.toLocaleLowerCase('fa');const c=state.category.toLocaleLowerCase('fa');
 const items=list.filter(o=>{
  if(state.city&&o.city!==state.city)return false;
  const content=[o.title,o.details,o.city,o.district,o.category,...o.skills].join(' ').toLocaleLowerCase('fa');
  return (!q||content.includes(q))&&(!c||content.includes(c));
 });
 return items.sort((a,b)=>state.sort==='az'?a.title.localeCompare(b.title,'fa'):(b.created_at||'').localeCompare(a.created_at||''));
}
function render(){
 const box=$(state.tab==='services'?'#kamcheh-services':'#kamcheh-requests');if(!box)return;
 const items=visibleItems();
 if($('#k-result-count'))$('#k-result-count').textContent=`${num(items.length)} مورد`;
 box.innerHTML=items.length?items.map(o=>card(o,state.tab)).join(''):'<div class="k-empty"><span class="material-icons-outlined">search_off</span><strong>موردی پیدا نشد</strong><p>عبارت جست‌وجو یا شهر را تغییر بده.</p></div>';
}
function switchTab(tab){
 if(!['services','needs'].includes(tab))return;
 state.tab=tab;
 const services=$('#kamcheh-services'),needs=$('#kamcheh-requests');if(!services||!needs)return;
 services.hidden=tab!=='services';needs.hidden=tab!=='needs';
 $$('[data-k-tab]').forEach(b=>{const active=b.dataset.kTab===tab;b.classList.toggle('is-selected',active);b.setAttribute('aria-selected',String(active));});
 if($('#market-heading'))$('#market-heading').textContent=tab==='services'?'متخصصان و اکیپ‌ها':'درخواست‌های کار';
 if($('#market-subtitle'))$('#market-subtitle').textContent=tab==='services'?'نیروی اجرایی و پیمانکار برای پروژه‌های ساختمانی':'پروژه‌هایی که به نیروی اجرایی نیاز دارند';
 render();
}
function showDetail(id,type){
 const source=type==='needs'?state.needs:state.services;const o=source.find(x=>x.id===id);if(!o)return;
 const budget=priceOf(o,type);const skills=o.skills.length?`<div class="k-details-skills">${o.skills.map(s=>`<span>${esc(s)}</span>`).join('')}</div>`:'';
 openDialog(`<div class="k-details-title">${esc(o.title)}</div><p class="k-details-note">${esc(o.category)} · ${esc(o.city)}${o.district?'، '+esc(o.district):''}</p><p>${esc(o.details)}</p>${skills}<div class="k-details-end"><strong>${esc(budget)}</strong><button type="button" class="btn btn-secondary" id="k-detail-close">بستن</button></div>${o.demo?'<p class="k-details-note">این مورد فقط برای نمایش طراحی است و اطلاعات تماس واقعی ندارد.</p>':''}`);
 $('#k-detail-close').onclick=closeDialog;
 if(!o.demo&&configured){
  const holder=document.createElement('div');holder.className='k-details-actions';holder.innerHTML=
   (o.owner?'<button type="button" id="k-owner" class="btn btn-secondary">پروفایل '+esc(o.owner.display_name)+'</button>':'')+
   (state.session?.user.id===o.owner_id?'<button type="button" id="k-archive" class="btn btn-text">بایگانی</button>':'<button type="button" id="k-contact" class="btn btn-primary">درخواست گفتگو</button>'+(type==='needs'?'<button type="button" id="k-bid" class="btn btn-secondary">ارائه پیشنهاد قیمت</button>':'<button type="button" id="k-quote" class="btn btn-secondary">درخواست پیش‌فاکتور</button>'));
  $('#k-form-content').appendChild(holder);
  if($('#k-owner'))$('#k-owner').onclick=()=>showPublicProfile(o.owner);
  if($('#k-contact'))$('#k-contact').onclick=()=>requestContact(o,type,'conversation');
  if($('#k-quote'))$('#k-quote').onclick=()=>requestContact(o,type,'quote');
  if($('#k-bid'))$('#k-bid').onclick=()=>sendBid(o);
  if($('#k-archive'))$('#k-archive').onclick=async()=>{try{const {error}=await state.client.from(type==='needs'?'work_needs':'service_listings').update({archived:true}).eq('id',o.id);if(error)throw error;closeDialog();await refresh();}catch(e){toast(errorMessage(e));}};
 }
}
function showMode(message,isWarning=true){const el=$('#k-mode-note');if(!el)return;el.hidden=!isWarning;if($('#k-status'))$('#k-status').textContent=message;}
async function refresh(){
 if(!state.client){render();return;}
 try{
  const [s,n]=await Promise.all([
   state.client.from('service_listings').select('id,owner_id,title,details,city,district,category,amount,created_at,skills,image_url,owner:profiles(id,display_name,specialty,city,bio,skills)').eq('enabled',true).eq('archived',false).order('created_at',{ascending:false}).limit(100),
   state.client.from('work_needs').select('id,owner_id,title,details,city,district,category,budget,created_at,skills,deadline,owner:profiles(id,display_name,specialty,city,bio,skills)').eq('closed',false).eq('archived',false).or('deadline.is.null,deadline.gt.'+new Date().toISOString()).order('created_at',{ascending:false}).limit(100)
  ]);
  if(s.error)throw s.error;if(n.error)throw n.error;
  state.services=(s.data||[]).map(listing);state.needs=(n.data||[]).map(listing);
  showMode('',false);render();
 }catch(error){showMode('دریافت اطلاعات از سرور ناموفق بود. لطفاً بعداً دوباره تلاش کن.');toast(errorMessage(error));}
}
function wire(){
 document.addEventListener('click',e=>{
  const detail=e.target.closest('[data-k-detail]');if(detail){showDetail(detail.dataset.kDetail,detail.dataset.kType);return;}
  const action=e.target.closest('[data-k-action]');if(action){e.preventDefault();({account:showAccount,'post-need':showPostNeed,'post-service':showPostService,close:closeDialog})[action.dataset.kAction]?.();return;}
  const switcher=e.target.closest('[data-k-switch]');if(switcher){e.preventDefault();switchTab(switcher.dataset.kSwitch);$('#marketplace')?.scrollIntoView({behavior:'smooth'});return;}
  const unavailable=e.target.closest('a[data-k-unavailable]');if(unavailable){e.preventDefault();toast('این بخش هنوز فعال نشده است.');}
 });
 $('#k-dialog')?.addEventListener('click',e=>{if(e.target===$('#k-dialog'))closeDialog();});
 $$('[data-k-tab]').forEach(b=>b.addEventListener('click',()=>switchTab(b.dataset.kTab)));
 $$('[data-k-category]').forEach(b=>b.addEventListener('click',()=>{state.category=b.dataset.kCategory;$$('[data-k-category]').forEach(x=>x.classList.toggle('is-active',x===b));render();$('#marketplace')?.scrollIntoView({behavior:'smooth'});}));
 $('#k-search')?.addEventListener('input',e=>{state.query=text(e.target.value);render();});
 $('#k-city')?.addEventListener('change',e=>{state.city=e.target.value;render();});
 $('#k-sort')?.addEventListener('change',e=>{state.sort=e.target.value;render();});
 $('#search-form')?.addEventListener('submit',e=>{e.preventDefault();render();$('#marketplace')?.scrollIntoView({behavior:'smooth'});});
 $('#k-reload')?.addEventListener('click',refresh);
 document.querySelectorAll('a[href*="#kamcheh-requests"]').forEach(a=>a.addEventListener('click',()=>switchTab('needs')));
 if(location.hash==='#kamcheh-requests')switchTab('needs');
}
async function start(){
 wire();
 if(!configured&&!demoMode){state.services=[];state.needs=[];showMode('اتصال کمچه هنوز تنظیم نشده است. لطفاً بعداً دوباره تلاش کن.');render();return;}
 if(!configured){
  // One consistent list surface: demo data is clearly labeled and stays out of persistence.
  const demo=window.KAMCHEH_DEMO_DATA||{services:[],needs:[]};
  state.services=demo.services.map(listing);state.needs=demo.needs.map(listing);
  showMode('این کارت‌ها نمونه طراحی هستند. بعد از اتصال بک‌اند، اطلاعات واقعی کاربران جایگزین می‌شود.');
  render();return;
 }
 // When connected, never show demo content, including during outages.
 try{
  const {createClient}=await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.118.0/+esm');
  state.client=createClient(cfg.supabaseUrl,cfg.supabasePublishableKey,{auth:{persistSession:true,autoRefreshToken:true}});
  const {data}=await state.client.auth.getSession();state.session=data?.session||null;
  state.client.auth.onAuthStateChange((_event,session)=>{const changed=state.session?.user.id!==session?.user.id;state.session=session;if(changed){state.profile=null;closeDialog();state.services=[];state.needs=[];setTimeout(()=>refresh(),0);}if(session)setTimeout(()=>fetchProfile(),0);updateAccountButton();});
  updateAccountButton();await fetchProfile();await refresh();
 }catch(e){showMode('اتصال بک‌اند در دسترس نیست.');toast(errorMessage(e));}
}
function showPublicProfile(p){
 openDialog(`<h3>${esc(p.display_name)}</h3><p>${esc(p.specialty)} · ${esc(p.city)}</p><p>${esc(p.bio||'')}</p><p>${esc((p.skills||[]).join(' · '))}</p><button class="btn btn-secondary" type="button" data-k-action="close">بستن</button>`);
}
function requestContact(o,type,kind){
 if(!authRequired())return;
 openDialog('<h3>درخواست ارتباط</h3><p>گفتگو پس از پذیرش طرف مقابل باز می‌شود.</p><label for="k-contact-text">شرح درخواست</label><textarea id="k-contact-text" maxlength="3000"></textarea><button id="k-contact-send" type="button" class="btn btn-primary">ارسال درخواست</button>');
 $('#k-contact-send').onclick=async()=>{const b=$('#k-contact-send');b.disabled=true;try{const {error}=await state.client.from('contact_requests').insert({context_type:type==='needs'?'need':'service',context_id:o.id,sender_id:state.session.user.id,recipient_id:o.owner_id,kind,message:text($('#k-contact-text').value)});if(error)throw error;closeDialog();toast('برای بررسی طرف مقابل ارسال شد.');}catch(e){toast(errorMessage(e));}finally{b.disabled=false;}};
}
function sendBid(o){
 if(!authRequired())return;
 openDialog('<h3>پیشنهاد قیمت</h3><label for="k-bid-amount">مبلغ (تومان)</label><input id="k-bid-amount" inputmode="numeric"><label for="k-bid-unit">واحد</label><select id="k-bid-unit"><option value="project">کل کار</option><option value="square_meter">متر مربع</option><option value="daily">روزانه</option><option value="hourly">ساعتی</option><option value="item">عدد</option></select><label for="k-bid-terms">شرایط</label><textarea id="k-bid-terms"></textarea><button type="button" id="k-bid-save" class="btn btn-primary">ثبت پیشنهاد</button>');
 $('#k-bid-save').onclick=async()=>{const b=$('#k-bid-save');b.disabled=true;try{const amount=Number(digits($('#k-bid-amount').value));if(!Number.isSafeInteger(amount)||amount<=0)throw Error('مبلغ معتبر وارد کن.');const {error}=await state.client.from('work_bids').insert({need_id:o.id,bidder_id:state.session.user.id,amount,unit:$('#k-bid-unit').value,terms:text($('#k-bid-terms').value)});if(error)throw error;closeDialog();toast('پیشنهاد ثبت شد.');}catch(e){toast(errorMessage(e));}finally{b.disabled=false;}};
}
async function showInbox(){
 if(!state.session)return showLogin();
 try{const [c,t]=await Promise.all([state.client.from('contact_requests').select().eq('status','pending').order('created_at',{ascending:false}),state.client.from('message_threads').select().order('created_at',{ascending:false})]);if(c.error)throw c.error;if(t.error)throw t.error;
 openDialog('<h3>پیام‌ها و ارتباط‌ها</h3>'+(c.data||[]).map(r=>`<article><p>${esc(r.message)} · ${esc(r.kind)}</p>${r.recipient_id===state.session.user.id?`<button type="button" data-contact="${esc(r.id)}" data-decision="accepted">پذیرش</button><button type="button" data-contact="${esc(r.id)}" data-decision="declined">رد</button>`:`<button type="button" data-contact="${esc(r.id)}" data-decision="cancelled">لغو درخواست</button>`}</article>`).join('')+'<h4>گفتگوها</h4>'+(t.data||[]).map((r,i)=>`<button class="btn btn-secondary" type="button" data-thread="${esc(r.id)}">گفتگوی ${num(i+1)}</button>`).join('')+(!(c.data||[]).length&&!(t.data||[]).length?'<p>هنوز ارتباطی ثبت نشده است.</p>':''));
 $$('[data-contact]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{const {error}=await state.client.rpc('decide_contact',{contact:b.dataset.contact,decision:b.dataset.decision});if(error)throw error;await showInbox();}catch(e){toast(errorMessage(e));b.disabled=false;}});
 $$('[data-thread]').forEach(b=>b.onclick=()=>showThread(b.dataset.thread));
 }catch(e){toast(errorMessage(e));}
}
async function showThread(id){
 try{const {data,error}=await state.client.from('thread_messages').select().eq('thread_id',id).order('created_at');if(error)throw error;
 openDialog('<h3>گفتگوی کمچه</h3><div class="k-thread">'+(data||[]).map(m=>`<article><strong>${m.sender_id===state.session.user.id?'من':'طرف مقابل'}</strong><p>${esc(m.body)}</p>${m.attachment_path?'<p>پیوست را در نسخه اپ ببین.</p>':''}</article>`).join('')+'</div><p>سابقه گفتگو حفظ می‌شود.</p><textarea id="k-chat-body" maxlength="5000" placeholder="پیام بنویس…"></textarea><button type="button" id="k-chat-send" class="btn btn-primary">ارسال</button><button type="button" id="k-chat-refresh" class="btn btn-text">به‌روزرسانی</button><a class="btn btn-secondary" href="app/">بازدید، پیوست و قرارداد در اپ</a>');
 $('#k-chat-refresh').onclick=()=>showThread(id);
 $('#k-chat-send').onclick=async()=>{const body=text($('#k-chat-body').value);if(!body)return;const b=$('#k-chat-send');b.disabled=true;try{const {error}=await state.client.from('thread_messages').insert({thread_id:id,sender_id:state.session.user.id,body});if(error)throw error;await showThread(id);}catch(e){toast(errorMessage(e));b.disabled=false;}};
 }catch(e){toast(errorMessage(e));}
}
start();
