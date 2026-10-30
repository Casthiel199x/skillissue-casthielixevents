-- V14.1: ejecutar SOLAMENTE si V14 schema.sql ya existe en este proyecto.
-- No borra eventos, jugadores ni resultados.
ALTER TABLE public.si_events ADD COLUMN IF NOT EXISTS scoring jsonb NOT NULL DEFAULT '[10,8,6,5,4,3,2,2,2,2]'::jsonb;
ALTER TABLE public.si_games ADD COLUMN IF NOT EXISTS published boolean NOT NULL DEFAULT false;
-- Los resultados anteriores permanecen como borradores hasta publicarlos.
create or replace function public.si_manage(p_action text,p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare eid uuid; gid uuid; pid uuid; x jsonb; n int; code text; out_codes jsonb:='[]'::jsonb;
begin
 if not public.si_admin() then raise exception 'No autorizado'; end if;
 case p_action
 when 'create_event' then
  if nullif(trim(p_payload->>'name'),'') is null then raise exception 'Nombre obligatorio'; end if;
  insert into public.si_events(name,description,rules,location,event_date,theme,scoring) values(left(trim(p_payload->>'name'),100),coalesce(p_payload->>'description',''),coalesce(p_payload->>'rules',''),coalesce(p_payload->>'location',''),nullif(p_payload->>'event_date','')::date,coalesce(p_payload->>'theme','gold'),coalesce(p_payload->'scoring','[10,8,6,5,4,3,2,2,2,2]'::jsonb)) returning id into eid;
  insert into public.si_broadcast(event_id) values(eid);
  return jsonb_build_object('id',eid);
 when 'update_event' then
  if nullif(trim(p_payload->>'name'),'') is null then raise exception 'Nombre obligatorio'; end if;
  eid=(p_payload->>'id')::uuid;
  update public.si_events set name=left(trim(p_payload->>'name'),100),description=coalesce(p_payload->>'description',''),rules=coalesce(p_payload->>'rules',''),location=coalesce(p_payload->>'location',''),event_date=nullif(p_payload->>'event_date','')::date,theme=coalesce(p_payload->>'theme','gold'),scoring=coalesce(p_payload->'scoring',scoring),updated_at=now() where id=eid;
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
 when 'publish_results' then
  gid=(p_payload->>'game_id')::uuid;
  if not exists(select 1 from public.si_games where id=gid) then raise exception 'Prueba inexistente'; end if;
  if coalesce((p_payload->>'published')::boolean,false) and (select kind from public.si_games where id=gid)='positions' then
   -- Recalcular en una sola transacción, incluyendo los empates.
   with ranked as (
     select r.player_id,r.position,count(*) over(partition by r.position) as tied
     from public.si_results r where r.game_id=gid and r.position is not null
   ), computed as (
     select ranked.player_id,round(avg(coalesce((e.scoring->>least(i-1,jsonb_array_length(e.scoring)-1))::numeric,0)))::int as new_points
     from ranked join public.si_games g on g.id=gid join public.si_events e on e.id=g.event_id
     cross join lateral generate_series(ranked.position,ranked.position+ranked.tied-1) i
     group by ranked.player_id
   )
   update public.si_results r set points=c.new_points from computed c
   where r.game_id=gid and r.player_id=c.player_id;
  end if;
  update public.si_games set published=coalesce((p_payload->>'published')::boolean,false) where id=gid;
 when 'set_result' then
  gid=(p_payload->>'game_id')::uuid;pid=(p_payload->>'player_id')::uuid;
  if not exists(select 1 from public.si_games g join public.si_players p on p.event_id=g.event_id where g.id=gid and p.id=pid) then raise exception 'Jugador ajeno a la prueba'; end if;
  if exists(select 1 from public.si_games where id=gid and published) then raise exception 'Despublica la prueba antes de editar resultados'; end if;
  insert into public.si_results(game_id,player_id,position,points) values(gid,pid,nullif(p_payload->>'position','')::int,case when (select kind from public.si_games where id=gid)='positions' then coalesce((select (e.scoring->>least(greatest(nullif(p_payload->>'position','')::int-1,0),jsonb_array_length(e.scoring)-1))::int from public.si_events e join public.si_games g on g.event_id=e.id where g.id=gid),0) else coalesce(nullif(p_payload->>'points','')::int,0) end) on conflict(game_id,player_id) do update set position=excluded.position,points=excluded.points;
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
  update public.si_games set status='finished',published=true where id=gid and kind='vote';
  -- Repartir puntuación por posiciones empatadas y redondear al entero más próximo.
  with counts as (select p.id, count(v.voted_for) as votes from public.si_players p join public.si_games g on g.event_id=p.event_id left join public.si_vote_tokens v on v.game_id=g.id and v.voted_for=p.id where g.id=gid group by p.id), ranks as (select id,votes,rank() over(order by votes desc) as rank, count(*) over(partition by votes) as ties from counts), points as (select id,rank,round((select sum(case when i<=1 then 10 when i=2 then 8 when i=3 then 6 when i=4 then 5 when i=5 then 4 when i=6 then 3 else 2 end)::numeric from generate_series(rank,rank+ties-1) i)/ties)::int as pts from ranks)
  insert into public.si_results(game_id,player_id,position,points) select gid,id,rank,pts from points on conflict(game_id,player_id) do update set position=excluded.position,points=excluded.points;
 else raise exception 'Acción desconocida'; end case;
 return jsonb_build_object('ok',true);
end $$;
create or replace function public.si_snapshot(p_admin boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare data jsonb; eid uuid; permitted boolean;
begin
 permitted=p_admin and public.si_admin();
 select event_id into eid from public.si_active where id=1;
 select jsonb_build_object('active_id',eid,'events',case when permitted then (select coalesce(jsonb_agg(to_jsonb(e) order by e.created_at desc),'[]'::jsonb) from public.si_events e) else '[]'::jsonb end,'event', (select to_jsonb(e) from public.si_events e where e.id=eid),'games',(select coalesce(jsonb_agg(to_jsonb(g) order by g.sort_order,g.id),'[]'::jsonb) from public.si_games g where g.event_id=eid),'players',(select coalesce(jsonb_agg(to_jsonb(p) order by p.name),'[]'::jsonb) from public.si_players p where p.event_id=eid),'results',(select coalesce(jsonb_agg(to_jsonb(r)),'[]'::jsonb) from public.si_results r join public.si_games g on g.id=r.game_id where g.event_id=eid and (permitted or g.published)),'broadcast',(select to_jsonb(b) from public.si_broadcast b where b.event_id=eid),'reactions',(select coalesce(jsonb_agg(to_jsonb(z) order by z.id),'[]'::jsonb) from (select * from public.si_reactions where event_id=eid order by id desc limit 30) z),'server_time',now()) into data;
 if not permitted then data=jsonb_set(data,'{events}','[]'::jsonb); end if;
 return data;
end $$;
