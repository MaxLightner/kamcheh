import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const A='11111111-1111-4111-8111-111111111111', B='22222222-2222-4222-8222-222222222222', C='33333333-3333-4333-8333-333333333333';
let count=0;
async function check(label,fn){await fn();count++;console.log(`PASS ${label}`);}
async function rejected(sql){let failed=false;try{await db.exec(sql);}catch{failed=true;}assert(failed,'expected database rejection');}
async function actor(id){await db.exec(`reset role; set request.jwt.claim.sub='${id||''}'; set role ${id?'authenticated':'anon'};`);}
const one=async(sql)=>(await db.query(sql)).rows[0];
try {
 await db.exec(`create role anon; create role authenticated;
 create schema auth;create schema storage;
 create table auth.users(id uuid primary key,phone text);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema public,auth,storage to anon,authenticated;
 grant execute on function auth.uid() to anon,authenticated;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
 alter table storage.objects enable row level security;
 grant select,insert,update,delete on storage.objects to anon,authenticated;
 create function storage.foldername(text) returns text[] language sql immutable as $$select string_to_array($1,'/')$$;`);
 const migration=readFileSync(new URL('../supabase/migrations/20261019_001_core.sql',import.meta.url),'utf8').replace('create extension if not exists pgcrypto;','-- gen_random_uuid is built into the test Postgres.');
 await db.exec(migration);
 await check('entire migration parses and applies',async()=>assert(true));
 await db.exec(`insert into auth.users(id,phone)values('${A}','+989111111111'),('${B}','+989222222222'),('${C}','+989333333333');`);
 for(const id of [A,B,C]){await actor(id);await db.exec(`update public.profiles set display_name='Test Person',city='مشهد',specialty='ساختمان',is_complete=true where id='${id}';select public.accept_rules('2026-10-19');`);}
 await actor(A);
 const need=(await one(`insert into public.work_needs(owner_id,title,details,city,deadline)values('${A}','Test Need','A real test need description','مشهد',now()+interval '1 day') returning id`)).id;
 await actor(B);
 await check('cannot reserve private address for another owner request',()=>rejected(`insert into public.work_need_private(need_id,owner_id,exact_address)values('${need}','${B}','fake');`));
 await actor(A);await db.exec(`insert into public.work_need_private(need_id,owner_id,exact_address)values('${need}','${A}','private address');`);
 await actor(B);await check('private address hidden before approval',async()=>assert.equal((await db.query('select * from public.work_need_private')).rows.length,0));
 const contact=(await one(`insert into public.contact_requests(context_type,context_id,sender_id,recipient_id,kind,visit_at)values('need','${need}','${B}','${A}','visit',now()+interval '1 day') returning id`)).id;
 await check('sender cannot accept own contact',()=>rejected(`select public.decide_contact('${contact}','accepted');`));
 await actor(C);await check('third user cannot read contact',async()=>assert.equal((await db.query('select * from public.contact_requests')).rows.length,0));
 await check('third user cannot accept contact',()=>rejected(`select public.decide_contact('${contact}','accepted');`));
 await actor(A);const thread=(await one(`select public.decide_contact('${contact}','accepted') as id`)).id;
 await check('acceptance creates one thread idempotently',async()=>assert.equal((await one(`select public.decide_contact('${contact}','accepted') as id`)).id,thread));
 await actor(B);await check('approved visitor can read exact address',async()=>assert.equal((await one('select exact_address from public.work_need_private')).exact_address,'private address'));
 await db.exec(`insert into public.thread_messages(thread_id,sender_id,body)values('${thread}','${B}','Hello');`);
 await check('participant cannot forge message sender',()=>rejected(`insert into public.thread_messages(thread_id,sender_id,body)values('${thread}','${A}','forged');`));
 await check('message deletion denied to client',()=>rejected('delete from public.thread_messages;'));
 await actor(C);await check('third user cannot read conversation',async()=>assert.equal((await db.query('select * from public.thread_messages')).rows.length,0));
 await actor(A);await db.exec(`update public.work_needs set deadline=now()-interval '1 second' where id='${need}';`);
 await actor(C);await check('expired need not publicly listed',async()=>assert.equal((await db.query(`select * from public.work_needs where id='${need}'`)).rows.length,0));
 await check('cannot contact expired need',()=>rejected(`insert into public.contact_requests(context_type,context_id,sender_id,recipient_id)values('need','${need}','${C}','${A}');`));
 await check('cannot bid on expired need',()=>rejected(`insert into public.work_bids(need_id,bidder_id,amount)values('${need}','${C}',100);`));
 await actor(A);await db.exec(`insert into public.accounting_entries(owner_id,description,amount)values('${A}','Test Cost',100);`);
 await actor(B);await check('accounting private per user',async()=>assert.equal((await db.query('select * from public.accounting_entries')).rows.length,0));
 await check('accounting cannot be assigned to another user',()=>rejected(`insert into public.accounting_entries(owner_id,amount)values('${A}',100);`));
 await actor(A);await check('accounting enum and amount checked by server',()=>rejected(`insert into public.accounting_entries(owner_id,amount,entry_type)values('${A}',0,'invalid');`));
 const contract=(await one(`select public.contract_action('create',null,'${JSON.stringify({counterparty_id:B,title:'Test Contract',payload:{subject:'Test subject',price:'100 toman',schedule:'one day',payment:'on delivery',terms:'Test terms'}})}'::jsonb) as id`)).id;
 await check('unsigned contract cannot be finalized',()=>rejected(`select public.contract_action('finalize','${contract}');`));
 const info=id=>JSON.stringify({name:id===A?'Alice':'Bob',identity:'test-identity',address:'test-address',documents:[]});
 await db.exec(`select public.contract_action('party','${contract}','${info(A)}');`);
 await actor(B);await db.exec(`select public.contract_action('party','${contract}','${info(B)}');`);
 const revision=(await one(`select revision from public.contract_drafts where id='${contract}'`)).revision;
 await actor(C);await check('contract hidden from nonparticipant',async()=>assert.equal((await db.query('select * from public.contract_drafts')).rows.length,0));
 await check('third user cannot edit contract',()=>rejected(`select public.contract_action('edit','${contract}','{}');`));
 await actor(A);await db.exec(`select public.contract_action('sign','${contract}','{"name":"Alice","revision":${revision}}');`);
 await actor(B);await db.exec(`select public.contract_action('sign','${contract}','{"name":"Bob","revision":${revision}}');select public.contract_action('finalize','${contract}');`);
 await check('both participants see immutable finalized version',async()=>assert.equal((await db.query('select * from public.contract_versions')).rows.length,1));
 await db.exec(`select public.contract_action('edit','${contract}','{"subject":"changed","price":"200","schedule":"2 days","payment":"on delivery","terms":"changed terms"}');`);
 await check('editing invalidates BOTH approvals',async()=>assert.equal((await db.query('select * from public.contract_parties where signed_at is not null')).rows.length,0));
 await check('old finalized snapshot remains unchanged',async()=>assert.equal((await one('select snapshot from public.contract_versions')).snapshot.contract.payload.price,'100 toman'));
 await check('stale revision cannot be signed',()=>rejected(`select public.contract_action('sign','${contract}','{"name":"Bob","revision":${revision}}');`));
 await check('history cannot be deleted',()=>rejected('delete from public.contract_versions;'));
 await check('nonparticipant cannot read contract file',async()=>{await actor(C);assert.equal((await db.query('select * from storage.objects')).rows.length,0);});
 await actor(null);await check('anonymous cannot write messages',()=>rejected(`insert into public.thread_messages(thread_id,sender_id,body)values('${thread}','${A}','anonymous');`));
 console.log(`Backend policy tests passed: ${count}`);
} catch(error) {console.error(error.message);console.error('Position:',error.position);if(error.query&&error.position){const p=Number(error.position)-1;console.error(error.query.slice(Math.max(0,p-160),p+160));}process.exitCode=1;}
finally {await db.close();}
