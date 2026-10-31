-- SKILL ISSUE V15: ejecutar sobre V14.3 + columna scoring. No borra datos.
create table if not exists public.si_profiles (
 id uuid primary key default gen_random_uuid(),
 lodestone_id text unique,
 lodestone_url text,
 name text not null,
 world text not null default '',
 data_center text not null default '',
 avatar_url text,
 portrait_url text,
 race text not null default '',
 main_job text not null default '',
 verified boolean not null default false,
 updated_at timestamptz not null default now()
);
alter table public.si_players add column if not exists profile_id uuid references public.si_profiles(id) on delete set null;
create index if not exists si_players_profile_idx on public.si_players(profile_id);
alter table public.si_profiles enable row level security;
revoke all on public.si_profiles from anon,authenticated;
-- Los campos importados son datos públicos, no verificación de propiedad.
create or replace function public.si_profile_save(p_player_id uuid,p_data jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare pid uuid; eid uuid; lid text; n text; existing uuid; link text;
begin
 if not public.si_admin() then raise exception 'No autorizado'; end if;
 select event_id,profile_id into eid,pid from public.si_players where id=p_player_id;
 if eid is null then raise exception 'Participante no encontrado'; end if;
 if exists(select 1 from public.si_events where id=eid and status='finished') then raise exception 'Reabre el evento para editar perfiles'; end if;
 n=left(trim(coalesce(p_data->>'name','')),100);
 if n='' then raise exception 'El nombre es obligatorio'; end if;
 lid=nullif(trim(coalesce(p_data->>'lodestone_id','')),'');
 if lid is not null and lid !~ '^[0-9]{1,16}$' then raise exception 'ID de Lodestone inválido'; end if;
 link=case when lid is not null then 'https://eu.finalfantasyxiv.com/lodestone/character/'||lid||'/' else null end;
 if lid is not null then select id into existing from public.si_profiles where lodestone_id=lid; end if;
 if existing is not null then pid=existing; end if;
 if pid is null then
  insert into public.si_profiles(name,lodestone_id,lodestone_url) values(n,lid,link) returning id into pid;
 end if;
 update public.si_profiles set
  name=n,
  lodestone_id=coalesce(lid,lodestone_id),
  lodestone_url=coalesce(link,lodestone_url),
  world=left(coalesce(p_data->>'world',''),100),
  data_center=left(coalesce(p_data->>'data_center',''),100),
  avatar_url=case when coalesce(p_data->>'avatar_url','') ~ '^https://(img2\.finalfantasyxiv\.com|img\.finalfantasyxiv\.com)/' then left(p_data->>'avatar_url',500) else avatar_url end,
  portrait_url=case when coalesce(p_data->>'portrait_url','') ~ '^https://(img2\.finalfantasyxiv\.com|img\.finalfantasyxiv\.com)/' then left(p_data->>'portrait_url',500) else portrait_url end,
  race=left(coalesce(p_data->>'race',''),100),
  main_job=left(coalesce(p_data->>'main_job',''),100),
  updated_at=now() where id=pid;
 update public.si_players set profile_id=pid where id=p_player_id;
 return jsonb_build_object('ok',true,'profile_id',pid);
end $$;
create or replace function public.si_profiles_for_event(p_event_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'player_id',p.id,'profile_id',pr.id,'name',p.name,'character_name',pr.name,
  'world',pr.world,'data_center',pr.data_center,'race',pr.race,'main_job',pr.main_job,
  'avatar_url',pr.avatar_url,'portrait_url',pr.portrait_url,'lodestone_url',pr.lodestone_url,
  'verified',pr.verified,
  'events',(select count(distinct p2.event_id) from public.si_players p2 where p2.profile_id=pr.id),
  'podiums',(select count(*) from public.si_results r2 join public.si_players p2 on p2.id=r2.player_id join public.si_games g2 on g2.id=r2.game_id where p2.profile_id=pr.id and g2.published and r2.position between 1 and 3),
  'wins',(select count(*) from public.si_results r2 join public.si_players p2 on p2.id=r2.player_id join public.si_games g2 on g2.id=r2.game_id where p2.profile_id=pr.id and g2.published and r2.position=1)
 ) order by p.name),'[]'::jsonb)
 from public.si_players p left join public.si_profiles pr on pr.id=p.profile_id
 where p.event_id=p_event_id and (public.si_admin() or exists(select 1 from public.si_active a where a.event_id=p_event_id));
$$;
revoke all on function public.si_profile_save(uuid,jsonb),public.si_profiles_for_event(uuid) from public;
grant execute on function public.si_profile_save(uuid,jsonb) to authenticated;
grant execute on function public.si_profiles_for_event(uuid) to anon,authenticated;

create or replace function public.si_is_admin() returns boolean language sql stable security definer set search_path='' as $$ select public.si_admin() $$;
revoke all on function public.si_is_admin() from public;
grant execute on function public.si_is_admin() to authenticated;
