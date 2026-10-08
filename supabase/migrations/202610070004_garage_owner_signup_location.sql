alter table public.profiles
  add column if not exists garage_address text,
  add column if not exists garage_latitude double precision,
  add column if not exists garage_longitude double precision;

alter table public.profiles
  add constraint profiles_garage_owner_location_check
  check (
    account_type <> 'garage_owner'
    or (
      length(trim(coalesce(garage_address, ''))) between 3 and 240
      and garage_latitude is not null
      and garage_latitude between -90 and 90
      and garage_longitude is not null
      and garage_longitude between -180 and 180
    )
  ) not valid;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  account_type_value text := case
    when new.raw_user_meta_data ->> 'account_type' = 'garage_owner'
      then 'garage_owner'
    else 'customer'
  end;
  garage_address_value text := nullif(
    trim(new.raw_user_meta_data ->> 'garage_address'), ''
  );
  garage_latitude_text text := nullif(
    trim(new.raw_user_meta_data ->> 'garage_latitude'), ''
  );
  garage_longitude_text text := nullif(
    trim(new.raw_user_meta_data ->> 'garage_longitude'), ''
  );
  garage_latitude_value double precision;
  garage_longitude_value double precision;
begin
  if length(trim(coalesce(new.raw_user_meta_data ->> 'display_name', ''))) < 2
    or length(trim(coalesce(new.raw_user_meta_data ->> 'phone', ''))) < 6
    or nullif(trim(new.email), '') is null then
    raise exception 'Name, email, and phone are required';
  end if;

  if account_type_value = 'garage_owner' then
    if length(coalesce(garage_address_value, '')) not between 3 and 240
      or garage_latitude_text is null
      or garage_latitude_text !~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
      or garage_longitude_text is null
      or garage_longitude_text !~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$' then
      raise exception 'Garage owners must provide a valid garage address and location';
    end if;

    garage_latitude_value := garage_latitude_text::double precision;
    garage_longitude_value := garage_longitude_text::double precision;
    if garage_latitude_value not between -90 and 90
      or garage_longitude_value not between -180 and 180 then
      raise exception 'Garage location coordinates are out of range';
    end if;
  end if;

  insert into public.profiles (
    id,
    display_name,
    phone,
    account_type,
    garage_address,
    garage_latitude,
    garage_longitude
  ) values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    account_type_value,
    garage_address_value,
    garage_latitude_value,
    garage_longitude_value
  );
  return new;
end;
$$;
