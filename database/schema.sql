create extension if not exists pgcrypto;
create table if not exists public.users(id uuid primary key default gen_random_uuid(),name text not null,email text not null unique,password_hash text not null,role text not null default 'user' check(role in ('user','admin')),created_at timestamptz not null default now());
create table if not exists public.customers(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.users(id) on delete cascade,name text not null,email text,address text,phone text,created_at timestamptz not null default now(),unique(id,user_id));
create table if not exists public.invoices(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.users(id) on delete cascade,customer_id uuid not null,number text not null,issue_date date not null,due_date date not null,status text not null default 'draft' check(status in ('draft','sent','paid')),tax_percent integer not null default 0 check(tax_percent between 0 and 100),subtotal numeric(14,2) not null default 0,tax_amount numeric(14,2) not null default 0,total numeric(14,2) not null default 0,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,number),unique(id,user_id),foreign key(customer_id,user_id) references public.customers(id,user_id));
create table if not exists public.invoice_items(id uuid primary key default gen_random_uuid(),invoice_id uuid not null references public.invoices(id) on delete cascade,description text not null,quantity integer not null check(quantity>0),unit_price numeric(12,2) not null check(unit_price>=0),line_total numeric(14,2) not null check(line_total>=0));
create index if not exists customers_user_idx on public.customers(user_id);create index if not exists invoices_user_idx on public.invoices(user_id,created_at desc);create index if not exists invoice_items_invoice_idx on public.invoice_items(invoice_id);
alter table public.users enable row level security;alter table public.customers enable row level security;alter table public.invoices enable row level security;alter table public.invoice_items enable row level security;
-- No public/anon policies: only server-side service-role client accesses tables.
create or replace function public.save_invoice(p_user_id uuid,p_invoice_id uuid,p_payload jsonb) returns uuid language plpgsql security invoker set search_path=public as $$
declare v_id uuid; v_item jsonb; v_subtotal numeric(14,2):=0; v_tax numeric(14,2); v_total numeric(14,2);
begin
 if not exists(select 1 from customers where id=(p_payload->>'customer_id')::uuid and user_id=p_user_id) then raise exception 'not_owned_customer';end if;
 for v_item in select value from jsonb_array_elements(p_payload->'items') loop
 v_subtotal:=v_subtotal+round((v_item->>'quantity')::numeric*(v_item->>'unit_price')::numeric,2);
 end loop;
 v_tax:=round(v_subtotal*(p_payload->>'tax_percent')::numeric/100,2);v_total:=v_subtotal+v_tax;
 if p_invoice_id is null then
 insert into invoices(user_id,customer_id,number,issue_date,due_date,status,tax_percent,subtotal,tax_amount,total)
 values(p_user_id,(p_payload->>'customer_id')::uuid,p_payload->>'number',(p_payload->>'issue_date')::date,(p_payload->>'due_date')::date,p_payload->>'status',(p_payload->>'tax_percent')::integer,v_subtotal,v_tax,v_total) returning id into v_id;
 else
 update invoices set customer_id=(p_payload->>'customer_id')::uuid,number=p_payload->>'number',issue_date=(p_payload->>'issue_date')::date,due_date=(p_payload->>'due_date')::date,status=p_payload->>'status',tax_percent=(p_payload->>'tax_percent')::integer,subtotal=v_subtotal,tax_amount=v_tax,total=v_total,updated_at=now() where id=p_invoice_id and user_id=p_user_id returning id into v_id;
 if v_id is null then raise exception 'not_owned';end if;
 delete from invoice_items where invoice_id=v_id;
 end if;
 for v_item in select value from jsonb_array_elements(p_payload->'items') loop
 insert into invoice_items(invoice_id,description,quantity,unit_price,line_total) values(v_id,v_item->>'description',(v_item->>'quantity')::integer,(v_item->>'unit_price')::numeric,round((v_item->>'quantity')::numeric*(v_item->>'unit_price')::numeric,2));
 end loop;
 return v_id;
end;$$;
revoke all on function public.save_invoice(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.save_invoice(uuid,uuid,jsonb) to service_role;
