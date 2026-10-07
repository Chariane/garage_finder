alter table public.service_requests
  drop constraint if exists service_requests_status_check;

alter table public.service_requests
  add constraint service_requests_status_check
  check (status in (
    'pending', 'accepted', 'en_route', 'completed', 'declined',
    'cancelled', 'expired'
  ));

create index if not exists service_requests_pending_expiry_idx
  on public.service_requests (created_at)
  where status = 'pending';

create policy service_requests_customer_cancel
  on public.service_requests for update to authenticated
  using ((select auth.uid()) = customer_id)
  with check ((select auth.uid()) = customer_id);

create or replace function public.guard_service_request_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  garage_owner_actor boolean;
begin
  if auth.uid() is not null then
    if new.id is distinct from old.id
      or new.garage_id is distinct from old.garage_id
      or new.customer_id is distinct from old.customer_id
      or new.customer_phone is distinct from old.customer_phone
      or new.vehicle is distinct from old.vehicle
      or new.issue_description is distinct from old.issue_description
      or new.customer_latitude is distinct from old.customer_latitude
      or new.customer_longitude is distinct from old.customer_longitude
      or new.created_at is distinct from old.created_at then
      raise exception 'Request identity and customer details are immutable';
    end if;

    select exists (
      select 1 from public.garages g
      where g.id = old.garage_id and g.owner_id = auth.uid()
    ) into garage_owner_actor;

    if garage_owner_actor then
      if new.status is distinct from old.status and not (
        (old.status = 'pending' and new.status in ('accepted', 'declined'))
        or (old.status = 'accepted' and new.status in ('en_route', 'completed'))
        or (old.status = 'en_route' and new.status = 'completed')
      ) then
        raise exception 'Invalid service request status transition';
      end if;
    elsif old.customer_id = auth.uid() then
      if old.status <> 'pending'
        or new.status <> 'cancelled'
        or new.response_eta_minutes is distinct from old.response_eta_minutes then
        raise exception 'Customers may only cancel pending requests';
      end if;
    else
      raise exception 'Only the customer or garage owner can update this request';
    end if;
  end if;

  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.expire_unanswered_service_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired_count integer;
begin
  update public.service_requests
  set status = 'expired', updated_at = now()
  where status = 'pending'
    and created_at <= now() - interval '30 minutes';

  get diagnostics expired_count = row_count;
  return expired_count;
end;
$$;

revoke all on function public.expire_unanswered_service_requests()
  from public, anon, authenticated;

create extension if not exists pg_cron;

select cron.schedule(
  'expire-unanswered-service-requests',
  '* * * * *',
  'select public.expire_unanswered_service_requests()'
);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'service_requests'
    ) then
    alter publication supabase_realtime add table public.service_requests;
  end if;
end;
$$;
