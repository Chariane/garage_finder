alter table public.garages
  add column if not exists phone_verified_at timestamptz,
  add column if not exists on_site_verified_at timestamptz,
  add column if not exists on_site_accuracy_meters double precision,
  add column if not exists on_site_distance_meters double precision,
  add column if not exists automated_review_status text not null default 'not_checked'
    check (automated_review_status in ('not_checked', 'passed', 'needs_review')),
  add column if not exists automated_review_reasons text[] not null default '{}';

create table if not exists public.garage_phone_verification_challenges (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  phone_e164 text not null check (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  provider_sid text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes',
  verified_at timestamptz,
  consumed_at timestamptz
);

create index if not exists garage_phone_challenges_owner_created_idx
  on public.garage_phone_verification_challenges (owner_id, created_at desc);

alter table public.garage_phone_verification_challenges enable row level security;
revoke all on public.garage_phone_verification_challenges from public, anon, authenticated;
grant all on public.garage_phone_verification_challenges to service_role;

create or replace function public.normalize_phone_for_verification(phone text)
returns text
language sql immutable parallel safe
set search_path = ''
as $$
  select regexp_replace(trim(coalesce(phone, '')), '[^0-9+]', '', 'g');
$$;
revoke all on function public.normalize_phone_for_verification(text)
  from public, anon, authenticated;

create or replace function public.enforce_garage_phone_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  challenge_id uuid;
  verified_at timestamptz;
  risk_reasons text[] := '{}';
begin
  if actor_id is null then
    return new;
  end if;
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role' = 'admin', false) then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.phone_verified_at is not null
     and public.normalize_phone_for_verification(old.phone)
       = public.normalize_phone_for_verification(new.phone) then
    new.phone_verified_at := old.phone_verified_at;
  else
    select challenge.id, challenge.verified_at
      into challenge_id, verified_at
      from public.garage_phone_verification_challenges as challenge
      where challenge.owner_id = actor_id
        and challenge.phone_e164 = public.normalize_phone_for_verification(new.phone)
        and challenge.verified_at is not null
        and challenge.consumed_at is null
        and challenge.expires_at > now()
      order by challenge.verified_at desc
      limit 1
      for update;

    if challenge_id is null then
      raise exception 'GARAGE_PHONE_VERIFICATION_REQUIRED';
    end if;

    update public.garage_phone_verification_challenges
      set consumed_at = now()
      where id = challenge_id;
    new.phone_verified_at := verified_at;
  end if;

  if tg_op = 'INSERT' then
    new.on_site_verified_at := null;
    new.on_site_accuracy_meters := null;
    new.on_site_distance_meters := null;
  elsif new.location is distinct from old.location then
    new.on_site_verified_at := null;
    new.on_site_accuracy_meters := null;
    new.on_site_distance_meters := null;
  else
    new.on_site_verified_at := old.on_site_verified_at;
    new.on_site_accuracy_meters := old.on_site_accuracy_meters;
    new.on_site_distance_meters := old.on_site_distance_meters;
  end if;

  if exists (
    select 1 from public.garages as other
    where other.id is distinct from new.id
      and other.owner_id <> actor_id
      and public.normalize_phone_for_verification(other.phone)
        = public.normalize_phone_for_verification(new.phone)
  ) then
    risk_reasons := array_append(risk_reasons, 'phone_used_by_another_owner');
  end if;

  if exists (
    select 1 from public.garages as other
    where other.id is distinct from new.id
      and lower(trim(other.name)) = lower(trim(new.name))
      and extensions.st_dwithin(other.location, new.location, 250)
  ) then
    risk_reasons := array_append(risk_reasons, 'possible_duplicate_nearby');
  end if;

  if coalesce(array_length(new.photo_urls, 1), 0) = 0 then
    risk_reasons := array_append(risk_reasons, 'garage_photo_missing');
  end if;
  if new.on_site_verified_at is null
     or new.on_site_verified_at < now() - interval '24 hours' then
    risk_reasons := array_append(risk_reasons, 'on_site_presence_missing');
  end if;

  new.automated_review_reasons := risk_reasons;
  new.automated_review_status := case
    when coalesce(array_length(risk_reasons, 1), 0) = 0 then 'passed'
    else 'needs_review'
  end;
  if tg_op = 'INSERT' then
    new.review_status := 'pending';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_garage_phone_verification()
  from public, anon, authenticated;

drop trigger if exists garages_enforce_phone_verification on public.garages;
create trigger garages_enforce_phone_verification
before insert or update on public.garages
for each row execute function public.enforce_garage_phone_verification();

create or replace function public.record_garage_on_site_presence(
  p_owner_id uuid,
  p_garage_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_meters double precision,
  p_location_is_mocked boolean default false
)
returns table (verified boolean, distance_meters double precision)
language plpgsql
security definer
set search_path = ''
as $$
declare
  garage_location extensions.geography(point, 4326);
  reported_location extensions.geography(point, 4326);
  calculated_distance double precision;
  current_reasons text[];
begin
  select g.location into garage_location
  from public.garages as g
  where g.id = p_garage_id and g.owner_id = p_owner_id
  for update;

  if garage_location is null
     or p_latitude is null
     or p_longitude is null
     or p_accuracy_meters is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180
     or p_accuracy_meters not between 0 and 50
     or p_location_is_mocked then
    return query select false, null::double precision;
    return;
  end if;

  reported_location := extensions.st_setsrid(
    extensions.st_makepoint(p_longitude, p_latitude), 4326
  )::extensions.geography;
  calculated_distance := extensions.st_distance(garage_location, reported_location);
  if calculated_distance > 150 then
    return query select false, calculated_distance;
    return;
  end if;

  update public.garages
  set on_site_verified_at = now(),
      on_site_accuracy_meters = p_accuracy_meters,
      on_site_distance_meters = calculated_distance
  where id = p_garage_id and owner_id = p_owner_id;

  select g.automated_review_reasons into current_reasons
  from public.garages as g where g.id = p_garage_id;
  current_reasons := array_remove(current_reasons, 'on_site_presence_missing');
  update public.garages
  set automated_review_reasons = current_reasons,
      automated_review_status = case
        when coalesce(array_length(current_reasons, 1), 0) = 0 then 'passed'
        else 'needs_review'
      end
  where id = p_garage_id and owner_id = p_owner_id;

  return query select true, calculated_distance;
end;
$$;
revoke all on function public.record_garage_on_site_presence(
  uuid, uuid, double precision, double precision, double precision, boolean
) from public, anon, authenticated;
grant execute on function public.record_garage_on_site_presence(
  uuid, uuid, double precision, double precision, double precision, boolean
) to service_role;

drop function if exists public.list_garages(boolean);
create function public.list_garages(p_owned boolean default false)
returns table (
  id uuid, name text, address text, city text, phone text, specialty text,
  services text[], description text, opening_hours jsonb,
  price_min_cfa integer, price_max_cfa integer, photo_urls text[],
  is_open boolean, availability_status text, availability_updated_at timestamptz,
  response_time_minutes integer, rating double precision, review_count integer,
  latitude double precision, longitude double precision,
  is_verified boolean, review_status text, moderation_note text,
  phone_verified_at timestamptz, on_site_verified_at timestamptz,
  automated_review_status text,
  automated_review_reasons text[]
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
    case when p_owned then g.moderation_note else null end,
    case when p_owned then g.phone_verified_at else null end,
    case when p_owned then g.on_site_verified_at else null end,
    case when p_owned then g.automated_review_status else null end,
    case when p_owned then g.automated_review_reasons else null end
  from public.garages g
  left join lateral (
    select avg(r.rating)::double precision as rating, count(*)::integer as review_count
    from public.garage_reviews r where r.garage_id = g.id
  ) review_summary on true
  where (p_owned and g.owner_id = (select auth.uid()))
    or (not p_owned and g.review_status = 'approved')
  order by g.created_at desc limit 500;
$$;
revoke all on function public.list_garages(boolean) from public;
grant execute on function public.list_garages(boolean) to anon, authenticated;
