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
    and (
      p_services is null
      or g.services && p_services
      or exists (
        select 1
        from unnest(p_services) selected(service)
        where lower(g.specialty) = lower(selected.service)
      )
    )
    and (p_min_price_cfa is null or g.price_max_cfa >= p_min_price_cfa)
    and (p_max_price_cfa is null or g.price_min_cfa <= p_max_price_cfa)
  order by extensions.st_distance(g.location, search_point.point)
  limit 100;
$$;
