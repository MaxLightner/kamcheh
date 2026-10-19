-- Kamcheh shared backend, Phase 1. Run ONLY in an independent Kamcheh project.
-- Phone numbers stay in auth.users, never in public profiles or public APIs.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null default '' check (char_length(display_name) <= 120),
  specialty text not null default '' check (char_length(specialty) <= 120),
  activity_type text not null default 'individual' check (activity_type in ('individual','crew','company','engineer','supplier')),
  city text not null default '' check (char_length(city) <= 100),
  district text not null default '' check (char_length(district) <= 120),
  bio text not null default '' check (char_length(bio) <= 3000),
  skills text[] not null default '{}',
  experience_years smallint check (experience_years between 0 and 80),
  avatar_path text,
  is_complete boolean not null default false,
  is_public boolean not null default true,
  available boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint completed_profile_has_basics check (not is_complete or (char_length(trim(display_name)) >= 2 and char_length(trim(city)) >= 2 and char_length(trim(specialty)) >= 2))
);

-- Every authenticated person has ONE profile. Creating an account does not require completing it.
create or replace function public.create_profile_on_signup()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists kamcheh_auth_user_created on auth.users;
create trigger kamcheh_auth_user_created after insert on auth.users
for each row execute function public.create_profile_on_signup();

create table if not exists public.service_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 5 and 140),
  details text not null check (char_length(trim(details)) between 10 and 3000),
  city text not null check (char_length(trim(city)) between 2 and 100),
  district text not null default '',
  category text not null default 'خدمات',
  skills text[] not null default '{}',
  amount bigint check (amount is null or amount >= 0),
  unit text not null default 'project' check (unit in ('project','square_meter','daily','hourly','item','negotiable')),
  image_url text,
  enabled boolean not null default true,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.work_needs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 5 and 140),
  details text not null check (char_length(trim(details)) between 10 and 3000),
  city text not null check (char_length(trim(city)) between 2 and 100),
  district text not null default '',
  category text not null default 'خدمات',
  skills text[] not null default '{}',
  crew_required boolean not null default false,
  quantity text not null default '',
  work_time text not null default '',
  budget bigint check (budget is null or budget >= 0),
  unit text not null default 'project' check (unit in ('project','square_meter','daily','hourly','item','negotiable')),
  deadline timestamptz,
  closed boolean not null default false,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Exact addresses and geo coordinates are deliberately excluded from work_needs public rows.
create table if not exists public.work_need_private (
  need_id uuid primary key references public.work_needs(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete restrict,
  exact_address text not null default '',
  latitude numeric(10,7),
  longitude numeric(10,7),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 2 and 160),
  description text not null default '',
  media_path text not null,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.work_bids (
  id uuid primary key default gen_random_uuid(),
  need_id uuid not null references public.work_needs(id) on delete cascade,
  bidder_id uuid not null references public.profiles(id) on delete restrict,
  amount bigint not null check (amount >= 0),
  unit text not null default 'project',
  when_text text not null default '',
  terms text not null default '',
  status text not null default 'pending' check (status in ('pending','withdrawn','shortlisted','declined')),
  created_at timestamptz not null default now(),
  unique (need_id,bidder_id)
);

create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  context_type text not null check (context_type in ('service','need')),
  context_id uuid not null,
  sender_id uuid not null references public.profiles(id) on delete restrict,
  recipient_id uuid not null references public.profiles(id) on delete restrict,
  kind text not null default 'conversation' check (kind in ('conversation','quote','cooperation','visit')),
  message text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.message_threads (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null unique references public.contact_requests(id) on delete restrict,
  participant_a uuid not null references public.profiles(id),
  participant_b uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (participant_a <> participant_b)
);
create table if not exists public.thread_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads(id) on delete restrict,
  sender_id uuid not null references public.profiles(id),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table if not exists public.contract_drafts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  thread_id uuid references public.message_threads(id),
  title text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.accounting_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  entry_date date not null default current_date,
  description text not null default '',
  category text not null default '',
  source text not null default '',
  stage text not null default '',
  amount bigint not null check (amount > 0),
  entry_type text not null default 'debt' check (entry_type in ('debt','settled','advance')),
  is_income boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists service_city_category_idx on public.service_listings(city, category,created_at desc) where archived=false and enabled=true;
create index if not exists need_city_category_idx on public.work_needs(city,category,created_at desc) where archived=false and closed=false;
create index if not exists bid_need_idx on public.work_bids(need_id,created_at desc);
create index if not exists contact_recipient_idx on public.contact_requests(recipient_id,status,created_at desc);
create index if not exists messages_thread_idx on public.thread_messages(thread_id,created_at);
create index if not exists portfolio_owner_idx on public.portfolio_items(owner_id,created_at desc);
create index if not exists entries_owner_idx on public.accounting_entries(owner_id,entry_date desc);

create trigger kamcheh_profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger kamcheh_services_updated before update on public.service_listings for each row execute function public.set_updated_at();
create trigger kamcheh_needs_updated before update on public.work_needs for each row execute function public.set_updated_at();
create trigger kamcheh_contracts_updated before update on public.contract_drafts for each row execute function public.set_updated_at();

-- Make all externally exposed tables deny-by-default.
alter table public.profiles enable row level security;
alter table public.service_listings enable row level security;
alter table public.work_needs enable row level security;
alter table public.work_need_private enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.work_bids enable row level security;
alter table public.contact_requests enable row level security;
alter table public.message_threads enable row level security;
alter table public.thread_messages enable row level security;
alter table public.contract_drafts enable row level security;
alter table public.accounting_entries enable row level security;

create policy profiles_read on public.profiles for select to anon,authenticated
using ((is_public and is_complete) or id=(select auth.uid()));
create policy profiles_insert_self on public.profiles for insert to authenticated
with check (id=(select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated
using (id=(select auth.uid())) with check (id=(select auth.uid()));

create policy services_read on public.service_listings for select to anon,authenticated
using ((enabled and not archived and exists(select 1 from public.profiles p where p.id=owner_id and p.is_complete and p.is_public)) or owner_id=(select auth.uid()));
create policy services_insert on public.service_listings for insert to authenticated
with check (owner_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=owner_id and p.is_complete));
create policy services_update on public.service_listings for update to authenticated
using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));
-- Listings are archived, never deleted by clients.

create policy needs_read on public.work_needs for select to anon,authenticated
using ((not archived and not closed and (deadline is null or deadline>now())) or owner_id=(select auth.uid()));
create policy needs_insert on public.work_needs for insert to authenticated
with check (owner_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=owner_id and p.is_complete));
create policy needs_update on public.work_needs for update to authenticated
using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));
-- Requests are archived, never deleted by clients.

create policy need_private_owner_read on public.work_need_private for select to authenticated
using (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=work_need_private.owner_id));
create policy need_private_owner_insert on public.work_need_private for insert to authenticated
with check (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=work_need_private.owner_id));
create policy need_private_owner_update on public.work_need_private for update to authenticated
using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=work_need_private.owner_id));

create policy portfolio_read on public.portfolio_items for select to anon,authenticated
using ((is_public and exists(select 1 from public.profiles p where p.id=owner_id and p.is_complete and p.is_public)) or owner_id=(select auth.uid()));
create policy portfolio_insert on public.portfolio_items for insert to authenticated with check(owner_id=(select auth.uid()));
create policy portfolio_update on public.portfolio_items for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy portfolio_delete on public.portfolio_items for delete to authenticated using(owner_id=(select auth.uid()));

create policy bids_read on public.work_bids for select to authenticated
using (bidder_id=(select auth.uid()) or exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=(select auth.uid())));
create policy bids_insert on public.work_bids for insert to authenticated
with check (bidder_id=(select auth.uid()) and status='pending' and exists(select 1 from public.work_needs n where n.id=need_id and n.owner_id<>(select auth.uid()) and not n.closed and not n.archived and (n.deadline is null or n.deadline>now())) and exists(select 1 from public.profiles p where p.id=bidder_id and p.is_complete));

create policy contacts_read on public.contact_requests for select to authenticated
using (sender_id=(select auth.uid()) or recipient_id=(select auth.uid()));
create policy contacts_insert on public.contact_requests for insert to authenticated
with check (sender_id=(select auth.uid()) and status='pending' and recipient_id<>(select auth.uid()) and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_complete) and (
 (context_type='service' and exists(select 1 from public.service_listings s where s.id=context_id and s.owner_id=recipient_id and s.enabled and not s.archived)) or
 (context_type='need' and exists(select 1 from public.work_needs n where n.id=context_id and n.owner_id=recipient_id and not n.closed and not n.archived and (n.deadline is null or n.deadline>now())))
));
-- Status transitions and thread creation use the authenticated RPCs below.

create policy threads_read on public.message_threads for select to authenticated
using (participant_a=(select auth.uid()) or participant_b=(select auth.uid()));
create policy thread_messages_read on public.thread_messages for select to authenticated
using (exists(select 1 from public.message_threads t where t.id=thread_id and (t.participant_a=(select auth.uid()) or t.participant_b=(select auth.uid()))));
create policy thread_messages_insert on public.thread_messages for insert to authenticated
with check(sender_id=(select auth.uid()) and exists(select 1 from public.message_threads t where t.id=thread_id and (t.participant_a=(select auth.uid()) or t.participant_b=(select auth.uid()))));

create policy contracts_owner_read on public.contract_drafts for select to authenticated using(owner_id=(select auth.uid()));
create policy contracts_owner_insert on public.contract_drafts for insert to authenticated with check(owner_id=(select auth.uid()));
create policy contracts_owner_update on public.contract_drafts for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy contracts_owner_delete on public.contract_drafts for delete to authenticated using(owner_id=(select auth.uid()));
create policy accounting_owner_read on public.accounting_entries for select to authenticated using(owner_id=(select auth.uid()));
create policy accounting_owner_insert on public.accounting_entries for insert to authenticated with check(owner_id=(select auth.uid()));
create policy accounting_owner_update on public.accounting_entries for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy accounting_owner_delete on public.accounting_entries for delete to authenticated using(owner_id=(select auth.uid()));

-- Additional backend-only tables have no client update privilege by design.
revoke all on public.profiles,public.service_listings,public.work_needs,public.work_need_private,public.portfolio_items,
 public.work_bids,public.contact_requests,public.message_threads,public.thread_messages,public.contract_drafts,public.accounting_entries from anon,authenticated;
grant select on public.profiles,public.service_listings,public.work_needs,public.portfolio_items to anon;
grant select on public.profiles,public.service_listings,public.work_needs,public.portfolio_items,
 public.work_need_private,public.work_bids,public.contact_requests,public.message_threads,public.thread_messages,
 public.contract_drafts,public.accounting_entries to authenticated;
grant insert,update on public.profiles to authenticated;
grant insert,update on public.service_listings,public.work_needs to authenticated;
grant insert,update,delete on public.portfolio_items,
 public.contract_drafts,public.accounting_entries to authenticated;
grant insert on public.work_need_private,public.work_bids,public.contact_requests,public.thread_messages to authenticated;
grant update on public.work_need_private to authenticated;

-- Public portfolios are explicitly opted-in images only (never upload ID cards/contracts here).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('kamcheh-portfolio','kamcheh-portfolio',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy kamcheh_portfolio_read on storage.objects for select to anon,authenticated
using(bucket_id='kamcheh-portfolio');
create policy kamcheh_portfolio_upload on storage.objects for insert to authenticated
with check(bucket_id='kamcheh-portfolio' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy kamcheh_portfolio_update on storage.objects for update to authenticated
using(bucket_id='kamcheh-portfolio' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='kamcheh-portfolio' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy kamcheh_portfolio_delete on storage.objects for delete to authenticated
using(bucket_id='kamcheh-portfolio' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Document storage remains private and owner-scoped.
insert into storage.buckets(id,name,public,file_size_limit)
values ('kamcheh-private-docs','kamcheh-private-docs',false,10485760) on conflict (id) do nothing;
create policy kamcheh_private_read on storage.objects for select to authenticated
using(bucket_id='kamcheh-private-docs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy kamcheh_private_upload on storage.objects for insert to authenticated
with check(bucket_id='kamcheh-private-docs' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy kamcheh_private_delete on storage.objects for delete to authenticated
using(bucket_id='kamcheh-private-docs' and (storage.foldername(name))[1]=(select auth.uid())::text);

-- One business backend for every client. Private helpers perform only explicitly
-- authorized cross-party transitions; exposed wrappers never accept an actor ID.
create schema if not exists kamcheh_private;
revoke all on schema kamcheh_private from public, anon;
grant usage on schema kamcheh_private to authenticated;

alter table public.contact_requests add column visit_at timestamptz;
alter table public.contact_requests add constraint contact_visit_date check(kind <> 'visit' or visit_at is not null);
create unique index contacts_one_pending on public.contact_requests(context_type,context_id,sender_id) where status='pending';

create table public.visit_records (
 id uuid primary key default gen_random_uuid(),
 thread_id uuid not null references public.message_threads(id) on delete restrict,
 proposed_by uuid not null references public.profiles(id) on delete restrict,
 visit_at timestamptz not null,
 status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
 created_at timestamptz not null default now()
);
alter table public.visit_records enable row level security;
create policy visits_read on public.visit_records for select to authenticated using(exists(
 select 1 from public.message_threads t where t.id=thread_id and auth.uid() in (t.participant_a,t.participant_b)));
create policy visits_insert on public.visit_records for insert to authenticated with check(
 proposed_by=auth.uid() and visit_at>now() and status='pending' and exists(
 select 1 from public.message_threads t where t.id=thread_id and auth.uid() in (t.participant_a,t.participant_b)));
grant select,insert on public.visit_records to authenticated;
create index visits_thread_idx on public.visit_records(thread_id,visit_at);

create function kamcheh_private.decide_contact(contact uuid, decision text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.contact_requests; thread uuid;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 select * into c from public.contact_requests where id=contact for update;
 if not found or auth.uid() not in (c.sender_id,c.recipient_id) then raise exception 'contact_not_accessible'; end if;
 if decision='cancelled' then
   if auth.uid()<>c.sender_id or c.status<>'pending' then raise exception 'invalid_transition'; end if;
 elsif decision in ('accepted','declined') then
   if auth.uid()<>c.recipient_id then raise exception 'recipient_only'; end if;
   if c.status='accepted' and decision='accepted' then
     select id into thread from public.message_threads where contact_id=c.id; return thread;
   end if;
   if c.status<>'pending' then raise exception 'invalid_transition'; end if;
 else raise exception 'invalid_decision'; end if;
 if decision='accepted' and c.kind='visit' and c.visit_at<=now() then raise exception 'visit_in_past'; end if;
 update public.contact_requests set status=decision where id=c.id;
 if decision='accepted' then
   insert into public.message_threads(contact_id,participant_a,participant_b) values(c.id,c.sender_id,c.recipient_id)
   on conflict(contact_id) do update set contact_id=excluded.contact_id returning id into thread;
   if c.kind='visit' then insert into public.visit_records(thread_id,proposed_by,visit_at,status) values(thread,c.sender_id,c.visit_at,'accepted'); end if;
 end if;
 return thread;
end; $$;
revoke all on function kamcheh_private.decide_contact(uuid,text) from public,anon;
grant execute on function kamcheh_private.decide_contact(uuid,text) to authenticated;
create function public.decide_contact(contact uuid, decision text) returns uuid
language sql security invoker set search_path='' as $$select kamcheh_private.decide_contact(contact,decision)$$;
revoke all on function public.decide_contact(uuid,text) from public,anon;
grant execute on function public.decide_contact(uuid,text) to authenticated;

create function kamcheh_private.decide_visit(visit uuid, decision text)
returns void language plpgsql security definer set search_path='' as $$
declare v public.visit_records; t public.message_threads;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 select * into v from public.visit_records where id=visit for update;
 select * into t from public.message_threads where id=v.thread_id;
 if t.id is null or auth.uid() not in(t.participant_a,t.participant_b) then raise exception 'visit_not_accessible'; end if;
 if v.status not in('pending','accepted') then raise exception 'invalid_transition'; end if;
 if decision='cancelled' then null;
 elsif decision in('accepted','declined') and v.status='pending' and auth.uid()<>v.proposed_by then
   if decision='accepted' and v.visit_at<=now() then raise exception 'visit_in_past'; end if;
 else raise exception 'invalid_transition'; end if;
 update public.visit_records set status=decision where id=v.id;
end; $$;
revoke all on function kamcheh_private.decide_visit(uuid,text) from public,anon;
grant execute on function kamcheh_private.decide_visit(uuid,text) to authenticated;
create function public.decide_visit(visit uuid, decision text) returns void
language sql security invoker set search_path='' as $$select kamcheh_private.decide_visit(visit,decision)$$;
revoke all on function public.decide_visit(uuid,text) from public,anon;
grant execute on function public.decide_visit(uuid,text) to authenticated;

-- Exact address may also be read by the approved visitor, never just by a bidder.
drop policy need_private_owner_read on public.work_need_private;
create policy need_private_read on public.work_need_private for select to authenticated using(
 owner_id=auth.uid() or exists(select 1 from public.contact_requests c where c.context_type='need'
 and c.context_id=need_id and c.recipient_id=work_need_private.owner_id and c.sender_id=auth.uid()
 and c.kind='visit' and c.status='accepted'));

-- A selected bid grants coordination only, not a work-start/end contract.
create function kamcheh_private.decide_bid(bid uuid, decision text)
returns uuid language plpgsql security definer set search_path='' as $$
declare b public.work_bids; n public.work_needs; c uuid; thread uuid;
begin
 if auth.uid() is null then raise exception 'authentication_required'; end if;
 select * into b from public.work_bids where id=bid for update;
 select * into n from public.work_needs where id=b.need_id;
 if n.owner_id is distinct from auth.uid() or decision not in('shortlisted','declined') then raise exception 'owner_only'; end if;
 if b.status not in('pending','shortlisted') then raise exception 'invalid_transition'; end if;
 update public.work_bids set status=decision where id=b.id;
 if decision='shortlisted' then
   select t.id into thread from public.message_threads t join public.contact_requests r on r.id=t.contact_id
   where r.context_type='need' and r.context_id=n.id and r.sender_id=b.bidder_id and r.recipient_id=n.owner_id limit 1;
   if thread is null then
     select id into c from public.contact_requests where context_type='need' and context_id=n.id
       and sender_id=b.bidder_id and recipient_id=n.owner_id and status='pending' limit 1 for update;
     if c is null then
       insert into public.contact_requests(context_type,context_id,sender_id,recipient_id,message,status)
       values('need',n.id,b.bidder_id,n.owner_id,b.terms,'accepted') returning id into c;
     else update public.contact_requests set status='accepted' where id=c; end if;
     insert into public.message_threads(contact_id,participant_a,participant_b) values(c,b.bidder_id,n.owner_id) returning id into thread;
   end if;
 end if;
 return thread;
end; $$;
revoke all on function kamcheh_private.decide_bid(uuid,text) from public,anon;
grant execute on function kamcheh_private.decide_bid(uuid,text) to authenticated;
create function public.decide_bid(bid uuid, decision text) returns uuid
language sql security invoker set search_path='' as $$select kamcheh_private.decide_bid(bid,decision)$$;
revoke all on function public.decide_bid(uuid,text) from public,anon;
grant execute on function public.decide_bid(uuid,text) to authenticated;

-- Contract state is shared; private identity fields are entered by each party.
alter table public.contract_drafts add column counterparty_id uuid references public.profiles(id) on delete restrict;
alter table public.contract_drafts add column template text not null default 'اجرای کار';
alter table public.contract_drafts add column revision integer not null default 1;
alter table public.contract_drafts add column parent_id uuid references public.contract_drafts(id) on delete restrict;
alter table public.contract_drafts add constraint contract_distinct_parties check(counterparty_id is not null and counterparty_id<>owner_id);
create table public.contract_parties (
 contract_id uuid not null references public.contract_drafts(id) on delete restrict,
 profile_id uuid not null references public.profiles(id) on delete restrict,
 details jsonb not null default '{}'::jsonb,
 signature_name text,
 signed_revision integer,
 signed_at timestamptz,
 primary key(contract_id,profile_id)
);
create table public.contract_versions (
 id uuid primary key default gen_random_uuid(),
 contract_id uuid not null references public.contract_drafts(id) on delete restrict,
 revision integer not null,
 snapshot jsonb not null,
 created_at timestamptz not null default now(),
 unique(contract_id,revision)
);
alter table public.contract_parties enable row level security;
alter table public.contract_versions enable row level security;
drop policy contracts_owner_read on public.contract_drafts;
drop policy contracts_owner_insert on public.contract_drafts;
drop policy contracts_owner_update on public.contract_drafts;
drop policy contracts_owner_delete on public.contract_drafts;
revoke insert,update,delete on public.contract_drafts from authenticated;
create policy contracts_participant_read on public.contract_drafts for select to authenticated using(auth.uid() in(owner_id,counterparty_id));
create policy parties_read on public.contract_parties for select to authenticated using(exists(
 select 1 from public.contract_drafts c where c.id=contract_id and auth.uid() in(c.owner_id,c.counterparty_id)));
create policy versions_read on public.contract_versions for select to authenticated using(exists(
 select 1 from public.contract_drafts c where c.id=contract_id and auth.uid() in(c.owner_id,c.counterparty_id)));
grant select on public.contract_parties,public.contract_versions to authenticated;

create function kamcheh_private.contract_action(action text, contract uuid default null, data jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.contract_drafts; me uuid:=auth.uid(); other uuid; p public.contract_parties; snap jsonb;
begin
 if me is null then raise exception 'authentication_required'; end if;
 if action='create' then
   other:=(data->>'counterparty_id')::uuid;
   if other is null or other=me or not exists(select 1 from public.profiles where id=other and is_complete and is_public)
      or not exists(select 1 from public.profiles where id=me and is_complete) then raise exception 'invalid_parties'; end if;
   if data->>'parent_id' is not null then
     select * into c from public.contract_drafts where id=(data->>'parent_id')::uuid;
     if c.id is null or not(me in(c.owner_id,c.counterparty_id) and other in(c.owner_id,c.counterparty_id))
        or not exists(select 1 from public.contract_versions where contract_id=c.id) then raise exception 'invalid_parent'; end if;
   end if;
   if data->>'thread_id' is not null and not exists(select 1 from public.message_threads t where t.id=(data->>'thread_id')::uuid
      and me in(t.participant_a,t.participant_b) and other in(t.participant_a,t.participant_b)) then raise exception 'invalid_thread'; end if;
   insert into public.contract_drafts(owner_id,counterparty_id,title,template,payload,parent_id,thread_id)
   values(me,other,left(coalesce(data->>'title',''),160),coalesce(data->>'template','اجرای کار'),coalesce(data->'payload','{}'),(data->>'parent_id')::uuid,(data->>'thread_id')::uuid) returning id into contract;
   insert into public.contract_parties(contract_id,profile_id) values(contract,me),(contract,other);
   return contract;
 end if;
 select * into c from public.contract_drafts where id=contract for update;
 if not found or me not in(c.owner_id,c.counterparty_id) then raise exception 'contract_not_accessible'; end if;
 if action in('edit','party') then
   if action='edit' then
     update public.contract_drafts set payload=data where id=c.id;
   else
     if jsonb_array_length(coalesce(data->'documents','[]'))>6 or exists(select 1 from jsonb_array_elements_text(coalesce(data->'documents','[]')) doc
        where doc not like c.id::text||'/'||me::text||'/%') then raise exception 'invalid_documents'; end if;
     update public.contract_parties set details=data where contract_id=c.id and profile_id=me;
   end if;
   update public.contract_drafts set revision=revision+1 where id=c.id;
   update public.contract_parties set signature_name=null,signed_revision=null,signed_at=null where contract_id=c.id;
 elsif action='sign' then
   if coalesce((data->>'revision')::integer,0)<>c.revision then raise exception 'contract_changed_review_again'; end if;
   if coalesce(c.payload->>'subject','')='' or coalesce(c.payload->>'price','')='' or coalesce(c.payload->>'terms','')='' or coalesce(c.payload->>'schedule','')='' or coalesce(c.payload->>'payment','')='' then raise exception 'incomplete_contract'; end if;
   if exists(select 1 from public.contract_parties where contract_id=c.id and (
      coalesce(details->>'name','')='' or coalesce(details->>'identity','')='' or coalesce(details->>'address','')='')) then raise exception 'incomplete_parties'; end if;
   select * into p from public.contract_parties where contract_id=c.id and profile_id=me;
   if trim(coalesce(data->>'name',''))<>trim(p.details->>'name') then raise exception 'signature_name_mismatch'; end if;
   update public.contract_parties set signature_name=data->>'name',signed_revision=c.revision,signed_at=now() where contract_id=c.id and profile_id=me;
 elsif action='finalize' then
   if (select count(*) from public.contract_parties where contract_id=c.id and signed_revision=c.revision and signed_at is not null)<>2 then raise exception 'both_signatures_required'; end if;
   snap:=jsonb_build_object('contract',to_jsonb(c),'parties',(select jsonb_agg(to_jsonb(cp)) from public.contract_parties cp where contract_id=c.id));
   insert into public.contract_versions(contract_id,revision,snapshot) values(c.id,c.revision,snap) on conflict(contract_id,revision) do nothing;
 else raise exception 'invalid_action'; end if;
 return c.id;
end; $$;
revoke all on function kamcheh_private.contract_action(text,uuid,jsonb) from public,anon;
grant execute on function kamcheh_private.contract_action(text,uuid,jsonb) to authenticated;
create function public.contract_action(action text, contract uuid default null, data jsonb default '{}'::jsonb) returns uuid
language sql security invoker set search_path='' as $$select kamcheh_private.contract_action(action,contract,data)$$;
revoke all on function public.contract_action(text,uuid,jsonb) from public,anon;
grant execute on function public.contract_action(text,uuid,jsonb) to authenticated;

-- Attachments are immutable and scoped to a thread or a shared contract.
alter table public.thread_messages add column attachment_path text;
alter table public.thread_messages add column file_name text;
alter table public.thread_messages add column mime text;
alter table public.thread_messages drop constraint thread_messages_body_check;
alter table public.thread_messages add constraint message_body_or_file check(
 char_length(body)<=5000 and (char_length(trim(body))>0 or attachment_path is not null));
drop policy thread_messages_insert on public.thread_messages;
create policy thread_messages_insert on public.thread_messages for insert to authenticated with check(
 sender_id=auth.uid() and exists(select 1 from public.message_threads t where t.id=thread_id and auth.uid() in(t.participant_a,t.participant_b))
 and (attachment_path is null or attachment_path like thread_id::text||'/'||auth.uid()::text||'/%'));
insert into storage.buckets(id,name,public,file_size_limit)
values('kamcheh-thread-files','kamcheh-thread-files',false,10485760) on conflict(id) do nothing;
create policy thread_files_read on storage.objects for select to authenticated using(bucket_id='kamcheh-thread-files' and exists(
 select 1 from public.message_threads t where t.id::text=(storage.foldername(name))[1] and auth.uid() in(t.participant_a,t.participant_b)));
create policy thread_files_insert on storage.objects for insert to authenticated with check(bucket_id='kamcheh-thread-files'
 and (storage.foldername(name))[2]=auth.uid()::text and exists(select 1 from public.message_threads t
 where t.id::text=(storage.foldername(name))[1] and auth.uid() in(t.participant_a,t.participant_b)));
drop policy kamcheh_private_read on storage.objects;
drop policy kamcheh_private_upload on storage.objects;
drop policy kamcheh_private_delete on storage.objects;
create policy contract_files_read on storage.objects for select to authenticated using(bucket_id='kamcheh-private-docs' and exists(
 select 1 from public.contract_drafts c where c.id::text=(storage.foldername(name))[1] and auth.uid() in(c.owner_id,c.counterparty_id)));
create policy contract_files_insert on storage.objects for insert to authenticated with check(bucket_id='kamcheh-private-docs'
 and (storage.foldername(name))[2]=auth.uid()::text and exists(select 1 from public.contract_drafts c
 where c.id::text=(storage.foldername(name))[1] and auth.uid() in(c.owner_id,c.counterparty_id)));

-- No API may remove messages, shared contract history, or finalized documents.
revoke all on function public.create_profile_on_signup() from public,anon,authenticated;
revoke all on function public.set_updated_at() from public,anon,authenticated;

create table public.rules_acceptances (
 profile_id uuid primary key references public.profiles(id) on delete restrict,
 version text not null,
 accepted_at timestamptz not null default now()
);
alter table public.rules_acceptances enable row level security;
create policy rules_self_read on public.rules_acceptances for select to authenticated using(profile_id=auth.uid());
grant select on public.rules_acceptances to authenticated;
create function kamcheh_private.accept_rules(version text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or version<>'2026-10-19' then raise exception 'invalid_rules_acceptance'; end if;
 insert into public.rules_acceptances(profile_id,version) values(auth.uid(),version)
 on conflict(profile_id) do update set version=excluded.version,accepted_at=now();
end; $$;
revoke all on function kamcheh_private.accept_rules(text) from public,anon;
grant execute on function kamcheh_private.accept_rules(text) to authenticated;
create function public.accept_rules(version text) returns void language sql security invoker set search_path=''
as $$select kamcheh_private.accept_rules(version)$$;
revoke all on function public.accept_rules(text) from public,anon;
grant execute on function public.accept_rules(text) to authenticated;
drop policy services_insert on public.service_listings;
create policy services_insert on public.service_listings for insert to authenticated with check(
 owner_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_complete)
 and exists(select 1 from public.rules_acceptances r where r.profile_id=auth.uid() and r.version='2026-10-19'));
drop policy needs_insert on public.work_needs;
create policy needs_insert on public.work_needs for insert to authenticated with check(
 owner_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_complete)
 and exists(select 1 from public.rules_acceptances r where r.profile_id=auth.uid() and r.version='2026-10-19'));
