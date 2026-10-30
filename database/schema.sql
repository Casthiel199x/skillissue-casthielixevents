-- SKILL ISSUE V14: proyecto NUEVO de Supabase. NO ejecutar sobre producción V13.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table public.si_admins(email text primary key);
create table public.si_events(id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 100), description text not null default '', rules text not null default '', location text not null default '', event_date date, theme text not null default 'gold', status text not null default 'draft' check(status in ('draft','published','live','finished','archived')), prizes jsonb not null default '[2000000,1000000,500000]'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.si_active(id int primary key default 1 check(id=1), event_id uuid references public.si_events(id)); insert into public.si_active(id) values(1);
create table public.si_games(id uuid primary key default gen_random_uuid(), event_id uuid not null references public.si_events(id) on delete cascade, name text not null, description text not null default '', kind text not null default 'positions' check(kind in ('positions','manual','vote')), sort_order int not null default 0, status text not null default 'pending' check(status in ('pending','running','finished')));
create table public.si_players(id uuid primary key default gen_random_uuid(), event_id uuid not null references public.si_events(id) on delete cascade, name text not null, unique(event_id,name));
create table public.si_results(game_id uuid not null references public.si_games(id) on delete cascade, player_id uuid not null references public.si_players(id) on delete cascade, position int check(position > 0), points int not null default 0, primary key(game_id,player_id));
create table public.si_broadcast(event_id uuid primary key references public.si_events(id) on delete cascade, mode text not null default 'waiting' check(mode in ('waiting','countdown','running','standings','victory','ceremony')), game_id uuid references public.si_games(id) on delete set null, countdown_end timestamptz, updated_at timestamptz not null default now());
create table public.si_vote_tokens(event_id uuid not null references public.si_events(id) on delete cascade, game_id uuid not null references public.si_games(id) on delete cascade, player_id uuid not null references public.si_players(id) on delete cascade, token_hash text not null, voted_for uuid references public.si_players(id), voted_at timestamptz, primary key(game_id,player_id),unique(game_id,token_hash));
create table public.si_reactions(id bigint generated always as identity primary key,event_id uuid not null references public.si_events(id) on delete cascade, emoji text not null check(emoji in ('🎃','👻','💀','🔥','❤️','😂','👏','🎉')),created_at timestamptz not null default now());
create index on public.si_games(event_id,sort_order);create index on public.si_players(event_id);create index on public.si_reactions(event_id,id desc);
-- Sin acceso directo a tablas: únicamente funciones de permisos definidos.
do $$ declare t text; begin foreach t in array array['si_admins','si_events','si_active','si_games','si_players','si_results','si_broadcast','si_vote_tokens','si_reactions'] loop execute format('alter table public.%I enable row level security',t); execute format('revoke all on public.%I from anon, authenticated',t); end loop; end $$;
create function public.si_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.si_admins where lower(email)=lower(auth.jwt()->>'email')) $$;
create function public.si_manage(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare eid uuid; gid uuid; pid uuid; x jsonb; n int; code text; out_codes jsonb:='[]'::jsonb;
begin
 if not public.si_admin() then raise exception 'No autorizado'; end if;
 case p_action
 when 'create_event' then
  if nullif(trim(p_payload->>'name'),'') is null then raise exception 'Nombre obligatorio'; end if;
  insert into public.si_events(name,description,rules,location,event_date,theme) values(left(trim(p_payload->>'name'),100),coalesce(p_payload->>'description',''),coalesce(p_payload->>'rules',''),coalesce(p_payload->>'location',''),nullif(p_payload->>'event_date','')::date,coalesce(p_payload->>'theme','gold')) returning id into eid;
  insert into public.si_broadcast(event_id) values(eid);
  return jsonb_build_object('id',eid);
 when 'update_event' then
  if nullif(trim(p_payload->>'name'),'') is null then raise exception 'Nombre obligatorio'; end if;
  eid=(p_payload->>'id')::uuid;
  update public.si_events set name=left(trim(p_payload->>'name'),100),description=coalesce(p_payload->>'description',''),rules=coalesce(p_payload->>'rules',''),location=coalesce(p_payload->>'location',''),event_date=nullif(p_payload->>'event_date','')::date,theme=coalesce(p_payload->>'theme','gold'),updated_at=now() where id=eid;
 when 'activate' then
  eid=(p_payload->>'id')::uuid;
  if not exists(select 1 from public.si_events where id=eid and status <> 'archived') then raise exception 'Evento no disponible'; end if;
  update public.si_events set status='published',updated_at=now() where id=eid and status='draft';
  update public.si_active set event_id=eid where id=1;
 when 'set_status' then
  update public.si_events set status=p_payload->>'status',updated_at=now() where id=(p_payload->>'id')::uuid;
 when 'add_game' then
  insert into public.si_games(event_id,name,description,kind,sort_order) values((p_payload->>'event_id')::uuid,p_payload->>'name',coalesce(p_payload->>'description',''),coalesce(p_payload->>'kind','positions'),coalesce((p_payload->>'sort_order')::int,0));
 when 'set_game_status' then update public.si_games set status=p_payload->>'status' where id=(p_payload->>'id')::uuid;
 when 'delete_game' then delete from public.si_games where id=(p_payload->>'id')::uuid;
 when 'add_player' then insert into public.si_players(event_id,name) values((p_payload->>'event_id')::uuid,trim(p_payload->>'name'));
 when 'delete_player' then delete from public.si_players where id=(p_payload->>'id')::uuid;
 when 'set_result' then
  gid=(p_payload->>'game_id')::uuid;pid=(p_payload->>'player_id')::uuid;
  if not exists(select 1 from public.si_games g join public.si_players p on p.event_id=g.event_id where g.id=gid and p.id=pid) then raise exception 'Jugador ajeno a la prueba'; end if;
  insert into public.si_results(game_id,player_id,position,points) values(gid,pid,nullif(p_payload->>'position','')::int,(p_payload->>'points')::int) on conflict(game_id,player_id) do update set position=excluded.position,points=excluded.points;
 when 'broadcast' then
  eid=(p_payload->>'event_id')::uuid;
  if not exists(select 1 from public.si_active where event_id=eid) then raise exception 'Evento no activo'; end if;
  update public.si_broadcast set mode=p_payload->>'mode',game_id=nullif(p_payload->>'game_id','')::uuid,countdown_end=case when p_payload->>'mode'='countdown' then now()+make_interval(secs=>coalesce((p_payload->>'seconds')::int,5)) else null end,updated_at=now() where event_id=eid;
 when 'prepare_votes' then
  gid=(p_payload->>'game_id')::uuid;
  select event_id into eid from public.si_games where id=gid and kind='vote';
  if eid is null then raise exception 'La prueba no es de votación'; end if;
  delete from public.si_vote_tokens where game_id=gid;
  for x in select jsonb_build_object('id',id,'name',name) from public.si_players where event_id=eid order by name loop
   code='SI-'||upper(encode(extensions.gen_random_bytes(10),'hex'));
   insert into public.si_vote_tokens(event_id,game_id,player_id,token_hash) values(eid,gid,(x->>'id')::uuid,encode(extensions.digest(code,'sha256'),'hex'));
   out_codes=out_codes||jsonb_build_array(jsonb_build_object('name',x->>'name','code',code));
  end loop;
  return out_codes;
 when 'close_votes' then
  gid=(p_payload->>'game_id')::uuid;
  update public.si_games set status='finished' where id=gid and kind='vote';
  -- Repartir puntuación por posiciones empatadas y redondear al entero más próximo.
  with counts as (select p.id, count(v.voted_for) as votes from public.si_players p join public.si_games g on g.event_id=p.event_id left join public.si_vote_tokens v on v.game_id=g.id and v.voted_for=p.id where g.id=gid group by p.id), ranks as (select id,votes,rank() over(order by votes desc) as rank, count(*) over(partition by votes) as ties from counts), points as (select id,rank,round((select sum(case when i<=1 then 10 when i=2 then 8 when i=3 then 6 when i=4 then 5 when i=5 then 4 when i=6 then 3 else 2 end)::numeric from generate_series(rank,rank+ties-1) i)/ties)::int as pts from ranks)
  insert into public.si_results(game_id,player_id,position,points) select gid,id,rank,pts from points on conflict(game_id,player_id) do update set position=excluded.position,points=excluded.points;
 else raise exception 'Acción desconocida'; end case;
 return jsonb_build_object('ok',true);
end $$;
create function public.si_snapshot(p_admin boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare data jsonb; eid uuid; permitted boolean;
begin
 permitted=p_admin and public.si_admin();
 select event_id into eid from public.si_active where id=1;
 select jsonb_build_object('active_id',eid,'events',case when permitted then (select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) from public.si_events e) else '[]'::jsonb end,'event', (select to_jsonb(e) from public.si_events e where e.id=eid),'games',(select coalesce(jsonb_agg(to_jsonb(g) order by g.sort_order,g.id),'[]'::jsonb) from public.si_games g where g.event_id=eid),'players',(select coalesce(jsonb_agg(to_jsonb(p) order by p.name),'[]'::jsonb) from public.si_players p where p.event_id=eid),'results',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.si_results r join public.si_games g on g.id=r.game_id where g.event_id=eid),'broadcast',(select to_jsonb(b) from public.si_broadcast b where b.event_id=eid),'reactions',(select coalesce(jsonb_agg(to_jsonb(z) order by z.id),'[]'::jsonb) from (select * from public.si_reactions where event_id=eid order by id desc limit 30) z),'server_time',now()) into data;
 if not permitted then data=jsonb_set(data,'{events}','[]'::jsonb); end if;
 return data;
end $$;
create function public.si_event_detail(p_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select case when public.si_admin() then jsonb_build_object('event',to_jsonb(e),'games',(select coalesce(jsonb_agg(to_jsonb(g) order by sort_order),'[]'::jsonb) from public.si_games g where g.event_id=e.id),'players',(select coalesce(jsonb_agg(to_jsonb(p) order by name),'[]'::jsonb) from public.si_players p where p.event_id=e.id),'results',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.si_results r join public.si_games g on g.id=r.game_id where g.event_id=e.id)) else null end from public.si_events e where e.id=p_id;
$$;
create function public.si_ballot() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('event',jsonb_build_object('id',e.id,'name',e.name),'games',(select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'candidates',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name)),'[]'::jsonb) from public.si_players p where p.event_id=e.id))),'[]'::jsonb) from public.si_games g where g.event_id=e.id and g.kind='vote' and g.status='running')) from public.si_active a join public.si_events e on e.id=a.event_id where a.id=1;
$$;
create function public.si_vote(p_game uuid,p_code text,p_candidate uuid) returns text language plpgsql security definer set search_path='' as $$
declare voter public.si_vote_tokens%rowtype; eid uuid;
begin
 select g.event_id into eid from public.si_games g join public.si_active a on a.event_id=g.event_id where g.id=p_game and g.kind='vote' and g.status='running';
 if eid is null then return 'CLOSED'; end if;
 select * into voter from public.si_vote_tokens where game_id=p_game and token_hash=encode(extensions.digest(upper(trim(p_code)),'sha256'),'hex') for update;
 if not found then return 'BAD_CODE'; end if;
 if voter.voted_at is not null then return 'USED'; end if;
 if voter.player_id=p_candidate then return 'SELF'; end if;
 if not exists(select 1 from public.si_players where id=p_candidate and event_id=eid) then return 'INVALID'; end if;
 update public.si_vote_tokens set voted_for=p_candidate,voted_at=now() where game_id=p_game and player_id=voter.player_id;
 return 'OK';
end $$;
create function public.si_react(p_emoji text) returns boolean language plpgsql security definer set search_path='' as $$
declare eid uuid;
begin
 if p_emoji not in ('🎃','👻','💀','🔥','❤️','😂','👏','🎉') then return false; end if;
 select a.event_id into eid from public.si_active a join public.si_events e on e.id=a.event_id where a.id=1 and e.status in ('published','live');
 if eid is null then return false; end if;
 insert into public.si_reactions(event_id,emoji) values(eid,p_emoji); return true;
end $$;
revoke all on function public.si_admin(),public.si_manage(text,jsonb),public.si_snapshot(boolean),public.si_event_detail(uuid),public.si_ballot(),public.si_vote(uuid,text,uuid),public.si_react(text) from public;
grant execute on function public.si_manage(text,jsonb),public.si_event_detail(uuid) to authenticated;
grant execute on function public.si_snapshot(boolean),public.si_ballot(),public.si_vote(uuid,text,uuid),public.si_react(text) to anon,authenticated;
-- IMPORTANTE: reemplaza el email y ejecuta esta sentencia manualmente después:
-- insert into public.si_admins(email) values('TU_EMAIL_DE_SUPABASE@EJEMPLO.COM');
