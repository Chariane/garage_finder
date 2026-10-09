create or replace function public.owner_garage_requests(p_garage_id uuid)
returns table (
  id uuid,
  garage_id uuid,
  garage_name text,
  customer_id uuid,
  customer_name text,
  customer_phone text,
  vehicle text,
  issue_description text,
  status text,
  response_eta_minutes integer,
  customer_latitude double precision,
  customer_longitude double precision,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    request.id,
    request.garage_id,
    garage.name,
    request.customer_id,
    nullif(trim(profile.display_name), ''),
    request.customer_phone,
    request.vehicle,
    request.issue_description,
    request.status,
    request.response_eta_minutes,
    request.customer_latitude,
    request.customer_longitude,
    request.created_at
  from public.service_requests as request
  join public.garages as garage on garage.id = request.garage_id
  left join public.profiles as profile on profile.id = request.customer_id
  where garage.id = p_garage_id
    and garage.owner_id = (select auth.uid())
  order by request.created_at desc;
$$;

revoke all on function public.owner_garage_requests(uuid) from public, anon;
grant execute on function public.owner_garage_requests(uuid) to authenticated;
