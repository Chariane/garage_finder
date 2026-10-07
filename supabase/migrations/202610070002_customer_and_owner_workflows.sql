alter table public.garages
  add column if not exists availability_status text not null default 'available'
    check (availability_status in ('available', 'busy', 'emergency_only', 'unavailable')),
  add column if not exists availability_updated_at timestamptz not null default now();

drop function if exists public.nearby_garages(
  double precision, double precision, integer, text, text, text, text[], integer, integer
);
drop function if exists public.list_garages(boolean);

create function public.nearby_garages(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_meters integer default 10000,
  p_query text default null,
  p_city text default null,
  p_specialty text default null,
  p_services text[] default null,
  p_min_price_cfa integer default null,
  p_max_price_cfa integer default null
)
returns table (
  id uuid, name text, address text, city text, phone text, specialty text,
  services text[], description text, opening_hours jsonb,
  price_min_cfa integer, price_max_cfa integer, photo_urls text[],
  is_open boolean, availability_status text, availability_updated_at timestamptz,
  response_time_minutes integer, rating double precision, review_count integer,
  latitude double precision, longitude double precision,
  distance_meters double precision, is_verified boolean
)
language sql stable security invoker set search_path = ''
as $$
  with search_point as (
    select extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography as point
  )
  select
    g.id, g.name, g.address, g.city, g.phone, g.specialty, g.services,
    g.description, g.opening_hours, g.price_min_cfa, g.price_max_cfa,
    g.photo_urls, g.is_open, g.availability_status,
    g.availability_updated_at, g.response_time_minutes,
    coalesce(review_summary.rating, 0)::double precision,
    coalesce(review_summary.review_count, 0)::integer,
    extensions.st_y(g.location::extensions.geometry),
    extensions.st_x(g.location::extensions.geometry),
    extensions.st_distance(g.location, search_point.point),
    g.review_status = 'approved'
  from public.garages g
  left join lateral (
    select avg(r.rating)::double precision as rating, count(*)::integer as review_count
    from public.garage_reviews r where r.garage_id = g.id
  ) review_summary on true
  cross join search_point
  where p_latitude between -90 and 90 and p_longitude between -180 and 180
    and p_radius_meters between 100 and 100000
    and extensions.st_dwithin(g.location, search_point.point, p_radius_meters)
    and (p_query is null or (
      g.name ilike '%' || p_query || '%' or g.address ilike '%' || p_query || '%'
      or g.city ilike '%' || p_query || '%' or g.specialty ilike '%' || p_query || '%'
      or exists (select 1 from unnest(g.services) service where service ilike '%' || p_query || '%')
    ))
    and (p_city is null or lower(g.city) = lower(p_city))
    and (p_specialty is null or lower(g.specialty) = lower(p_specialty))
    and (p_services is null or g.services && p_services)
    and (p_min_price_cfa is null or g.price_max_cfa >= p_min_price_cfa)
    and (p_max_price_cfa is null or g.price_min_cfa <= p_max_price_cfa)
  order by extensions.st_distance(g.location, search_point.point)
  limit 100;
$$;

create function public.list_garages(p_owned boolean default false)
returns table (
  id uuid, name text, address text, city text, phone text, specialty text,
  services text[], description text, opening_hours jsonb,
  price_min_cfa integer, price_max_cfa integer, photo_urls text[],
  is_open boolean, availability_status text, availability_updated_at timestamptz,
  response_time_minutes integer, rating double precision, review_count integer,
  latitude double precision, longitude double precision,
  is_verified boolean, review_status text, moderation_note text
)
language sql stable security invoker set search_path = ''
as $$
  select
    g.id, g.name, g.address, g.city, g.phone, g.specialty, g.services,
    g.description, g.opening_hours, g.price_min_cfa, g.price_max_cfa,
    g.photo_urls, g.is_open, g.availability_status,
    g.availability_updated_at, g.response_time_minutes,
    coalesce(review_summary.rating, 0)::double precision,
    coalesce(review_summary.review_count, 0)::integer,
    extensions.st_y(g.location::extensions.geometry),
    extensions.st_x(g.location::extensions.geometry),
    g.review_status = 'approved', g.review_status,
    case when p_owned then g.moderation_note else null end
  from public.garages g
  left join lateral (
    select avg(r.rating)::double precision as rating, count(*)::integer as review_count
    from public.garage_reviews r where r.garage_id = g.id
  ) review_summary on true
  where (p_owned and g.owner_id = (select auth.uid()))
    or (not p_owned and g.review_status = 'approved')
  order by g.created_at desc limit 500;
$$;
revoke all on function public.nearby_garages(
  double precision, double precision, integer, text, text, text, text[], integer, integer
) from public;
grant execute on function public.nearby_garages(
  double precision, double precision, integer, text, text, text, text[], integer, integer
) to anon, authenticated;
revoke all on function public.list_garages(boolean) from public;
grant execute on function public.list_garages(boolean) to anon, authenticated;

create or replace function public.protect_garage_moderation_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  admin_actor boolean := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role' = 'admin', false
  );
begin
  if auth.uid() is not null then
    if new.owner_id is distinct from old.owner_id then
      raise exception 'Garage owner cannot be changed by clients';
    end if;
    if admin_actor then
      if new.review_status not in ('pending', 'approved', 'rejected')
        or (new.review_status = 'rejected' and length(trim(coalesce(new.moderation_note, ''))) not between 10 and 500)
        or new.name is distinct from old.name
        or new.address is distinct from old.address
        or new.city is distinct from old.city
        or new.phone is distinct from old.phone
        or new.specialty is distinct from old.specialty
        or new.services is distinct from old.services
        or new.description is distinct from old.description
        or new.price_min_cfa is distinct from old.price_min_cfa
        or new.price_max_cfa is distinct from old.price_max_cfa
        or new.photo_urls is distinct from old.photo_urls
        or new.location is distinct from old.location
        or new.opening_hours is distinct from old.opening_hours
        or new.response_time_minutes is distinct from old.response_time_minutes
        or new.is_open is distinct from old.is_open
        or new.availability_status is distinct from old.availability_status
        or new.availability_updated_at is distinct from old.availability_updated_at then
        raise exception 'Moderators may only change review status and note';
      end if;
    else
      if new.moderation_note is distinct from old.moderation_note
        or new.review_status is distinct from old.review_status then
        raise exception 'Moderation fields cannot be changed by owners';
      end if;
      if old.review_status in ('approved', 'rejected') and (
        new.name is distinct from old.name
        or new.address is distinct from old.address
        or new.city is distinct from old.city
        or new.phone is distinct from old.phone
        or new.specialty is distinct from old.specialty
        or new.services is distinct from old.services
        or new.description is distinct from old.description
        or new.price_min_cfa is distinct from old.price_min_cfa
        or new.price_max_cfa is distinct from old.price_max_cfa
        or new.photo_urls is distinct from old.photo_urls
        or new.location is distinct from old.location
        or new.opening_hours is distinct from old.opening_hours
        or new.response_time_minutes is distinct from old.response_time_minutes
      ) then
        new.review_status = 'pending';
        new.moderation_note = null;
      end if;
    end if;
  end if;
  return new;
end;
$$;

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references public.garages (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  customer_phone text not null check (length(trim(customer_phone)) between 6 and 32),
  vehicle text not null check (length(trim(vehicle)) between 2 and 100),
  issue_description text not null check (length(trim(issue_description)) between 5 and 1500),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'en_route', 'completed', 'declined')),
  response_eta_minutes integer check (response_eta_minutes is null or response_eta_minutes between 0 and 1440),
  customer_latitude double precision check (customer_latitude is null or customer_latitude between -90 and 90),
  customer_longitude double precision check (customer_longitude is null or customer_longitude between -180 and 180),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_requests_garage_status_idx
  on public.service_requests (garage_id, status, created_at desc);
create index if not exists service_requests_customer_idx
  on public.service_requests (customer_id, created_at desc);

drop policy if exists reviews_create_as_customer on public.garage_reviews;
create policy reviews_create_as_customer
  on public.garage_reviews for insert to authenticated
  with check (
    (select auth.uid()) = customer_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.account_type = 'customer'
    )
    and exists (
      select 1 from public.garages g
      where g.id = garage_reviews.garage_id and g.review_status = 'approved'
    )
    and exists (
      select 1 from public.service_requests sr
      where sr.garage_id = garage_reviews.garage_id
        and sr.customer_id = (select auth.uid())
        and sr.status = 'completed'
    )
  );
drop policy if exists reviews_update_own on public.garage_reviews;
create policy reviews_update_own
  on public.garage_reviews for update to authenticated
  using ((select auth.uid()) = customer_id)
  with check (
    (select auth.uid()) = customer_id
    and exists (
      select 1 from public.garages g
      where g.id = garage_reviews.garage_id and g.review_status = 'approved'
    )
    and exists (
      select 1 from public.service_requests sr
      where sr.garage_id = garage_reviews.garage_id
        and sr.customer_id = (select auth.uid())
        and sr.status = 'completed'
    )
  );

create or replace function public.limit_service_request_rate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.customer_id::text, 0)
  );
  if (select count(*) from public.service_requests r
      where r.customer_id = new.customer_id
        and r.created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Request limit reached. Try again later.';
  end if;
  return new;
end;
$$;
create trigger service_requests_rate_limit
before insert on public.service_requests
for each row execute function public.limit_service_request_rate();

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (length(title) between 1 and 160),
  body text not null check (length(body) between 1 and 500),
  request_id uuid references public.service_requests (id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists user_notifications_recipient_idx
  on public.user_notifications (recipient_id, created_at desc);

create table if not exists public.garage_reports (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references public.garages (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  category text not null check (category in ('phone', 'address', 'closed', 'behavior', 'other')),
  description text not null default '' check (length(description) <= 1000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now()
);
create index if not exists garage_reports_open_idx
  on public.garage_reports (created_at desc) where status = 'open';

alter table public.service_requests enable row level security;
alter table public.user_notifications enable row level security;
alter table public.garage_reports enable row level security;

drop policy if exists garages_read_admin on public.garages;
create policy garages_read_admin
  on public.garages for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
drop policy if exists garages_update_admin on public.garages;
create policy garages_update_admin
  on public.garages for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

revoke all on public.service_requests, public.user_notifications, public.garage_reports
  from anon, authenticated;
grant select, insert, update on public.service_requests to authenticated;
grant select on public.user_notifications to authenticated;
grant update (read_at) on public.user_notifications to authenticated;
grant select, insert on public.garage_reports to authenticated;

create policy service_requests_customer_read
  on public.service_requests for select to authenticated
  using ((select auth.uid()) = customer_id);
create policy service_requests_owner_read
  on public.service_requests for select to authenticated
  using (exists (
    select 1 from public.garages g
    where g.id = garage_id and g.owner_id = (select auth.uid())
  ));
create policy service_requests_customer_create
  on public.service_requests for insert to authenticated
  with check (
    (select auth.uid()) = customer_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.account_type = 'customer'
    )
    and exists (
      select 1 from public.garages g
      where g.id = garage_id and g.review_status = 'approved'
        and g.availability_status in ('available', 'emergency_only')
    )
  );
create policy service_requests_owner_update
  on public.service_requests for update to authenticated
  using (exists (
    select 1 from public.garages g
    where g.id = garage_id and g.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.garages g
    where g.id = garage_id and g.owner_id = (select auth.uid())
  ));

create or replace function public.guard_service_request_update()
returns trigger
language plpgsql
set search_path = ''
as $$
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
    if not exists (
      select 1 from public.garages g
      where g.id = old.garage_id and g.owner_id = auth.uid()
    ) then
      raise exception 'Only the garage owner can update request status';
    end if;
    if new.status is distinct from old.status and not (
      (old.status = 'pending' and new.status in ('accepted', 'declined'))
      or (old.status = 'accepted' and new.status in ('en_route', 'completed'))
      or (old.status = 'en_route' and new.status = 'completed')
    ) then
      raise exception 'Invalid service request status transition';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;
create trigger service_requests_guard_update
before update on public.service_requests
for each row execute function public.guard_service_request_update();

create or replace function public.notify_service_request_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  garage_owner uuid;
begin
  if tg_op = 'INSERT' then
    select g.owner_id into garage_owner
    from public.garages g where g.id = new.garage_id;
    insert into public.user_notifications (recipient_id, title, body, request_id)
    values (garage_owner, 'Nouvelle demande de dépannage', new.vehicle || ' : ' || left(new.issue_description, 200), new.id);
  elsif new.status is distinct from old.status then
    insert into public.user_notifications (recipient_id, title, body, request_id)
    values (
      new.customer_id,
      'Mise à jour de votre dépannage',
      'Le statut de votre demande est maintenant : ' || new.status,
      new.id
    );
  end if;
  return new;
end;
$$;
create trigger service_requests_notify_insert
after insert on public.service_requests
for each row execute function public.notify_service_request_changes();
create trigger service_requests_notify_update
after update of status on public.service_requests
for each row execute function public.notify_service_request_changes();

create policy notifications_read_own
  on public.user_notifications for select to authenticated
  using ((select auth.uid()) = recipient_id);
create policy notifications_mark_own_read
  on public.user_notifications for update to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

create policy garage_reports_create_customer
  on public.garage_reports for insert to authenticated
  with check (
    (select auth.uid()) = reporter_id
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.account_type = 'customer'
    )
    and exists (
      select 1 from public.garages g
      where g.id = garage_id and g.review_status = 'approved'
    )
  );
create policy garage_reports_read_reporter
  on public.garage_reports for select to authenticated
  using ((select auth.uid()) = reporter_id);
grant update (status) on public.garage_reports to authenticated;
create policy garage_reports_admin_read
  on public.garage_reports for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy garage_reports_admin_update
  on public.garage_reports for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create or replace function public.guard_garage_report_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and (
    new.id is distinct from old.id
    or new.garage_id is distinct from old.garage_id
    or new.reporter_id is distinct from old.reporter_id
    or new.category is distinct from old.category
    or new.description is distinct from old.description
    or new.created_at is distinct from old.created_at
    or (auth.jwt() -> 'app_metadata' ->> 'role') is distinct from 'admin'
  ) then
    raise exception 'Only moderators can update report status';
  end if;
  return new;
end;
$$;
create trigger garage_reports_guard_update
before update on public.garage_reports
for each row execute function public.guard_garage_report_update();

create or replace function public.guard_garage_availability()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and new.availability_status is distinct from old.availability_status then
    if not exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_type = 'garage_owner'
    ) or new.owner_id is distinct from auth.uid() then
      raise exception 'Only the garage owner can change availability';
    end if;
    new.availability_updated_at = now();
  end if;
  return new;
end;
$$;
create trigger garages_guard_availability
before update on public.garages
for each row execute function public.guard_garage_availability();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'user_notifications'
    ) then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end;
$$;
