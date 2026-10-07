create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  phone text not null default '',
  account_type text not null default 'customer'
    check (account_type in ('customer', 'garage_owner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, phone, account_type)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    case
      when new.raw_user_meta_data ->> 'account_type' = 'garage_owner'
        then 'garage_owner'
      else 'customer'
    end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

create or replace function public.protect_profile_account_type()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and new.account_type is distinct from old.account_type then
    raise exception 'Account type cannot be changed by clients';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_account_type
before update on public.profiles
for each row execute function public.protect_profile_account_type();

create table if not exists public.garages (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 120),
  address text not null check (length(trim(address)) between 3 and 240),
  city text not null check (length(trim(city)) between 2 and 100),
  phone text not null check (length(trim(phone)) between 6 and 32),
  specialty text not null check (length(trim(specialty)) between 2 and 80),
  services text[] not null default '{}',
  description text not null default '' check (length(description) <= 2000),
  opening_hours jsonb not null default '{}'::jsonb,
  response_time_minutes integer
    check (response_time_minutes is null or response_time_minutes between 0 and 1440),
  price_min_cfa integer check (price_min_cfa is null or price_min_cfa >= 0),
  price_max_cfa integer check (price_max_cfa is null or price_max_cfa >= price_min_cfa),
  photo_urls text[] not null default '{}',
  location extensions.geography(point, 4326) not null,
  is_open boolean not null default false,
  availability_status text not null default 'available'
    check (availability_status in ('available', 'busy', 'emergency_only', 'unavailable')),
  availability_updated_at timestamptz not null default now(),
  review_status text not null default 'pending'
    check (review_status in ('pending', 'approved', 'rejected')),
  moderation_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists garages_location_gist_idx
  on public.garages using gist (location);
create index if not exists garages_city_lower_idx
  on public.garages (lower(city));
create index if not exists garages_specialty_lower_idx
  on public.garages (lower(specialty));
create index if not exists garages_owner_id_idx
  on public.garages (owner_id);

create table if not exists public.garage_reviews (
  id uuid primary key default gen_random_uuid(),
  garage_id uuid not null references public.garages (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text not null default '' check (length(comment) <= 1200),
  created_at timestamptz not null default now(),
  unique (garage_id, customer_id)
);

create index if not exists garage_reviews_garage_id_idx
  on public.garage_reviews (garage_id);

create trigger garages_touch_updated_at
before update on public.garages
for each row execute function public.touch_updated_at();

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

create trigger garages_protect_moderation_fields
before update on public.garages
for each row execute function public.protect_garage_moderation_fields();

alter table public.profiles enable row level security;
alter table public.garages enable row level security;
alter table public.garage_reviews enable row level security;

revoke all on public.profiles from anon, authenticated;
revoke all on public.garages from anon, authenticated;
revoke all on public.garage_reviews from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.garages to authenticated;
grant select on public.garages to anon;
grant select on public.garage_reviews to anon, authenticated;
grant insert, update, delete on public.garage_reviews to authenticated;

create policy profiles_select_self
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_insert_self
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
create policy profiles_update_self
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy garages_read_published_or_owned
  on public.garages for select to anon, authenticated
  using (
    review_status = 'approved'
    or (select auth.uid()) = owner_id
  );
create policy garages_read_admin
  on public.garages for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy garages_insert_as_owner
  on public.garages for insert to authenticated
  with check (
    (select auth.uid()) = owner_id
    and exists (
      select 1 from public.profiles as p
      where p.id = (select auth.uid()) and p.account_type = 'garage_owner'
    )
    and review_status = 'pending'
  );
create policy garages_update_own
  on public.garages for update to authenticated
  using (
    (select auth.uid()) = owner_id
    and exists (
      select 1 from public.profiles as p
      where p.id = (select auth.uid()) and p.account_type = 'garage_owner'
    )
  )
  with check (
    (select auth.uid()) = owner_id
    and exists (
      select 1 from public.profiles as p
      where p.id = (select auth.uid()) and p.account_type = 'garage_owner'
    )
  );
create policy garages_update_admin
  on public.garages for update to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy garages_delete_own
  on public.garages for delete to authenticated
  using (
    (select auth.uid()) = owner_id
    and exists (
      select 1 from public.profiles as p
      where p.id = (select auth.uid()) and p.account_type = 'garage_owner'
    )
  );

create policy reviews_read_published_garages
  on public.garage_reviews for select to anon, authenticated
  using (
    exists (
      select 1 from public.garages as g
      where g.id = garage_id and g.review_status = 'approved'
    )
  );
create policy reviews_create_as_customer
  on public.garage_reviews for insert to authenticated
  with check (
    (select auth.uid()) = customer_id
    and exists (
      select 1 from public.profiles as p
      where p.id = (select auth.uid()) and p.account_type = 'customer'
    )
    and exists (
      select 1 from public.garages as g
      where g.id = garage_id and g.review_status = 'approved'
    )
  );
create policy reviews_update_own
  on public.garage_reviews for update to authenticated
  using ((select auth.uid()) = customer_id)
  with check (
    (select auth.uid()) = customer_id
    and exists (
      select 1 from public.garages as g
      where g.id = garage_id and g.review_status = 'approved'
    )
  );
create policy reviews_delete_own
  on public.garage_reviews for delete to authenticated
  using ((select auth.uid()) = customer_id);

create or replace function public.nearby_garages(
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
  id uuid,
  name text,
  address text,
  city text,
  phone text,
  specialty text,
  services text[],
  description text,
  opening_hours jsonb,
  price_min_cfa integer,
  price_max_cfa integer,
  photo_urls text[],
  is_open boolean,
  availability_status text,
  availability_updated_at timestamptz,
  response_time_minutes integer,
  rating double precision,
  review_count integer,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  is_verified boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  with search_point as (
    select extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography as point
  )
  select
    g.id,
    g.name,
    g.address,
    g.city,
    g.phone,
    g.specialty,
    g.services,
    g.description,
    g.opening_hours,
    g.price_min_cfa,
    g.price_max_cfa,
    g.photo_urls,
    g.is_open,
    g.availability_status,
    g.availability_updated_at,
    g.response_time_minutes,
    coalesce(review_summary.rating, 0)::double precision,
    coalesce(review_summary.review_count, 0)::integer,
    extensions.st_y(g.location::extensions.geometry),
    extensions.st_x(g.location::extensions.geometry),
    extensions.st_distance(g.location, search_point.point),
    g.review_status = 'approved'
  from public.garages as g
  left join lateral (
    select avg(r.rating)::double precision as rating, count(*)::integer as review_count
    from public.garage_reviews as r
    where r.garage_id = g.id
  ) as review_summary on true
  cross join search_point
  where p_latitude between -90 and 90
    and p_longitude between -180 and 180
    and p_radius_meters between 100 and 100000
    and extensions.st_dwithin(g.location, search_point.point, p_radius_meters)
    and (p_query is null or (
      g.name ilike '%' || p_query || '%'
      or g.address ilike '%' || p_query || '%'
      or g.city ilike '%' || p_query || '%'
      or g.specialty ilike '%' || p_query || '%'
      or exists (
        select 1 from unnest(g.services) as service
        where service ilike '%' || p_query || '%'
      )
    ))
    and (p_city is null or lower(g.city) = lower(p_city))
    and (p_specialty is null or lower(g.specialty) = lower(p_specialty))
    and (p_services is null or g.services && p_services)
    and (p_min_price_cfa is null or g.price_max_cfa >= p_min_price_cfa)
    and (p_max_price_cfa is null or g.price_min_cfa <= p_max_price_cfa)
  order by extensions.st_distance(g.location, search_point.point)
  limit 100;
$$;

create or replace function public.list_garages(p_owned boolean default false)
returns table (
  id uuid,
  name text,
  address text,
  city text,
  phone text,
  specialty text,
  services text[],
  description text,
  opening_hours jsonb,
  price_min_cfa integer,
  price_max_cfa integer,
  photo_urls text[],
  is_open boolean,
  availability_status text,
  availability_updated_at timestamptz,
  response_time_minutes integer,
  rating double precision,
  review_count integer,
  latitude double precision,
  longitude double precision,
  is_verified boolean,
  review_status text,
  moderation_note text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    g.id,
    g.name,
    g.address,
    g.city,
    g.phone,
    g.specialty,
    g.services,
    g.description,
    g.opening_hours,
    g.price_min_cfa,
    g.price_max_cfa,
    g.photo_urls,
    g.is_open,
    g.availability_status,
    g.availability_updated_at,
    g.response_time_minutes,
    coalesce(review_summary.rating, 0)::double precision,
    coalesce(review_summary.review_count, 0)::integer,
    extensions.st_y(g.location::extensions.geometry),
    extensions.st_x(g.location::extensions.geometry),
    g.review_status = 'approved',
    g.review_status,
    case when p_owned then g.moderation_note else null end
  from public.garages as g
  left join lateral (
    select avg(r.rating)::double precision as rating, count(*)::integer as review_count
    from public.garage_reviews as r
    where r.garage_id = g.id
  ) as review_summary on true
  where (p_owned and g.owner_id = (select auth.uid()))
    or (not p_owned and g.review_status = 'approved')
  order by g.created_at desc
  limit 500;
$$;

revoke all on function public.nearby_garages(
  double precision, double precision, integer, text, text, text, text[], integer, integer
) from public;
grant execute on function public.nearby_garages(
  double precision, double precision, integer, text, text, text, text[], integer, integer
) to anon, authenticated;
revoke all on function public.list_garages(boolean) from public;
grant execute on function public.list_garages(boolean) to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'garage-photos',
  'garage-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy garage_photos_public_read
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'garage-photos');
create policy garage_photos_owner_upload
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'garage-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy garage_photos_owner_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'garage-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'garage-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy garage_photos_owner_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'garage-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
