-- Kamcheh shared backend, Phase 1. Run ONLY in an independent Kamcheh project.
-- Phone numbers stay in auth.users, never in public profiles or public APIs.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
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
  owner_id uuid not null references public.profiles(id) on delete cascade,
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
  owner_id uuid not null references public.profiles(id) on delete cascade,
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
  owner_id uuid not null references public.profiles(id) on delete cascade,
  exact_address text not null default '',
  latitude numeric(10,7),
  longitude numeric(10,7),
  check (latitude is null or latitude between -90 and 90),
  check (longitude is null or longitude between -180 and 180)
);

create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 160),
  description text not null default '',
  media_path text not null,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.work_bids (
  id uuid primary key default gen_random_uuid(),
  need_id uuid not null references public.work_needs(id) on delete cascade,
  bidder_id uuid not null references public.profiles(id) on delete cascade,
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
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'conversation' check (kind in ('conversation','quote','cooperation','visit')),
  message text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.message_threads (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null unique references public.contact_requests(id) on delete cascade,
  participant_a uuid not null references public.profiles(id),
  participant_b uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  check (participant_a <> participant_b)
);
create table if not exists public.thread_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table if not exists public.contract_drafts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  thread_id uuid references public.message_threads(id),
  title text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.accounting_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  entry_date date not null default current_date,
  description text not null default '',
  category text not null default '',
  source text not null default '',
  stage text not null default '',
  amount bigint not null check (amount >= 0),
  entry_type text not null default 'debt',
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
create policy services_delete on public.service_listings for delete to authenticated using (owner_id=(select auth.uid()));

create policy needs_read on public.work_needs for select to anon,authenticated
using ((not archived and not closed) or owner_id=(select auth.uid()));
create policy needs_insert on public.work_needs for insert to authenticated
with check (owner_id=(select auth.uid()) and exists(select 1 from public.profiles p where p.id=owner_id and p.is_complete));
create policy needs_update on public.work_needs for update to authenticated
using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));
create policy needs_delete on public.work_needs for delete to authenticated using (owner_id=(select auth.uid()));

create policy need_private_owner_read on public.work_need_private for select to authenticated
using (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=owner_id));
create policy need_private_owner_insert on public.work_need_private for insert to authenticated
with check (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=owner_id));
create policy need_private_owner_update on public.work_need_private for update to authenticated
using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()) and exists (select 1 from public.work_needs n where n.id=need_id and n.owner_id=owner_id));

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
with check (sender_id=(select auth.uid()) and status='pending' and recipient_id<>(select auth.uid()) and (
 (context_type='service' and exists(select 1 from public.service_listings s where s.id=context_id and s.owner_id=recipient_id and s.enabled and not s.archived)) or
 (context_type='need' and exists(select 1 from public.work_needs n where n.id=context_id and n.owner_id=recipient_id and not n.closed and not n.archived))
));
-- Status transitions and creation of message threads are intentionally server-only,
-- pending a validated accept/decline RPC in the next migration.

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
grant insert,update,delete on public.service_listings,public.work_needs,public.portfolio_items,
 public.contract_drafts,public.accounting_entries to authenticated;
grant insert on public.work_need_private,public.work_bids,public.contact_requests,public.thread_messages to authenticated;
grant update on public.work_need_private to authenticated;

-- Public portfolios are explicitly opted-in images only (never upload ID cards/contracts here).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('kamcheh-portfolio','kamcheh-portfolio',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
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