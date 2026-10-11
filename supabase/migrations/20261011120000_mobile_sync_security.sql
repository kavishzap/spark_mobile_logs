-- Mobile sync security
--
-- Do not apply this until you have read it. It does not recreate
-- sales_assistants, sales_assistant_devices, or call_logs, and it does
-- not add company_id.
--
-- Purpose:
-- 1. Record an audit row for each sync request.
-- 2. Stop user JWTs from writing call_logs directly. Existing SELECT
--    policies stay in place, so the web back office can keep reading.
--    The mobile app writes only through the sync-call-logs Edge Function,
--    which uses the service role.
-- 3. Let a signed-in assistant read their own rows when the Auth email
--    matches sales_assistants.email.
--
-- Apply this before deploying enroll-device and sync-call-logs.
-- If the web back office currently inserts into call_logs with a signed-in
-- user (not the service role), move that write first. This migration revokes
-- insert, update, and delete on call_logs from anon and authenticated.
--
-- Sign-in matches sales_assistants.email and sales_assistants.password.
-- One sales_assistant_devices row is kept per assistant. Do not add company_id.

do $$
begin
  if not exists (
    select 1
    from public.sales_assistant_devices
    group by sales_assistant_id
    having count(*) > 1
  ) then
    create unique index if not exists sales_assistant_devices_one_assistant_uidx
      on public.sales_assistant_devices (sales_assistant_id);
  end if;
end $$;

create table if not exists public.call_sync_audit (
  id uuid primary key default gen_random_uuid(),
  sales_assistant_id uuid not null,
  device_id uuid not null,
  actor_user_id uuid not null,
  event_type text not null,
  record_count integer not null default 0,
  accepted_count integer not null default 0,
  rejected_count integer not null default 0,
  details jsonb,
  created_at timestamptz not null default now()
);

alter table public.call_sync_audit enable row level security;

revoke all on table public.call_sync_audit from anon, authenticated;

revoke insert, update, delete on table public.call_logs from anon, authenticated;

create or replace function public.enforce_call_log_service_role_write()
returns trigger
language plpgsql
as $$
declare
  jwt_role text := auth.role();
begin
  if jwt_role is null or jwt_role = 'service_role' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  raise exception 'Direct writes to call_logs are disabled. Use the sync-call-logs function.'
    using errcode = '42501';
end;
$$;

drop trigger if exists call_logs_service_role_write on public.call_logs;

create trigger call_logs_service_role_write
  before insert or update or delete on public.call_logs
  for each row
  execute function public.enforce_call_log_service_role_write();

-- Additive read policies. They do not remove existing company-member policies.
-- Permissive policies are OR-combined, so this does not shrink web access.

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'sales_assistants'
      and policyname = 'assistant_select_own_profile'
  ) then
    create policy assistant_select_own_profile
      on public.sales_assistants
      for select
      to authenticated
      using (
        lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'sales_assistant_devices'
      and policyname = 'assistant_select_own_devices'
  ) then
    create policy assistant_select_own_devices
      on public.sales_assistant_devices
      for select
      to authenticated
      using (
        sales_assistant_id in (
          select id from public.sales_assistants
          where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'call_logs'
      and policyname = 'assistant_select_own_call_logs'
  ) then
    create policy assistant_select_own_call_logs
      on public.call_logs
      for select
      to authenticated
      using (
        sales_assistant_id in (
          select id from public.sales_assistants
          where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        )
      );
  end if;
end $$;
