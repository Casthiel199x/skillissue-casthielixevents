import {login,logout,token,rpc,manage,snapshot,detail,$,esc,points,configOk} from './core.js';
let state={events:[],active_id:null,event:null,games:[],players:[],results:[],broadcast:null},selected=null,tab='inicio';
const msg=(t,bad=false)=>{for(const id of ['notice','eventActionNotice']){const el=$(id);if(el){el.textContent=t;el.className='status '+(bad?'error':'ok')}}};
async function run(fn){try{const outcome=await fn();if(outcome!==false)msg('Operación completada correctamente')}catch(e){console.error('[SKILL ISSUE] Operación fallida:',e);msg('Error: '+(e?.message||String(e)),true)}}
async function refresh(){const s=await snapshot(true);state={...state,...s};$('connection').textContent='● Conectado';$('connection').className='status ok';if(selected&&!s.events?.some(e=>e.id===selected))selected=null;if(!selected)selected=s.active_id||s.events?.[0]?.id||null;await loadSelected();render()}
async function loadSelected(){if(!selected){state.event=null;state.games=[];state.players=[];state.results=[];return}const d=await detail(selected);state.event=d?.event||null;state.games=d?.games||[];state.players=d?.players||[];state.results=d?.results||[]}
function render(){const e=state.event;const active=state.events.find(x=>x.id===state.active_id);$('current').textContent='Editando: '+(e?.name||'ninguno')+' · Publicado: '+(active?.name||'ninguno');$('homeEvent').textContent=active?(active.name+' · '+(active.status==='finished'?'FINALIZADO':active.status==='live'?'EN DIRECTO':'PUBLICADO')):'Ninguno';$('homeDescription').textContent=active?.description||'Publica un evento para mostrarlo al público';$('homePlayers').textContent=state.active_id===selected?state.players.length:'—';$('homeGames').textContent=state.active_id===selected?state.games.length:'—';$('eventList').innerHTML=state.events.map(x=>`<button class="cardbtn ${x.id===selected?'active':''}" data-event="${x.id}"><b>${esc(x.name)}</b><br><span class="small muted">${esc(x.status)} ${x.id===state.active_id?(x.status==='finished'?'· ✓ FINALIZADO':x.status==='archived'?'· ARCHIVADO':'· ● PUBLICADO'):''}</span></button>`).join('')||'<p class="muted">Todavía no hay eventos.</p>';
for(const [id,val] of Object.entries({eventId:e?.id||'',eventName:e?.name||'',eventDescription:e?.description||'',eventRules:e?.rules||'',eventLocation:e?.location||'',eventDate:e?.event_date||'',eventScoring:(e?.scoring||[10,8,6,5,4,3,2,2,2,2]).join(',')}))$(id).value=val;$('eventTheme').value=e?.theme||'gold';
$('playerList').innerHTML='<table class="table">'+state.players.map(p=>`<tr><td>${esc(p.name)}</td><td><button class="danger" data-del-player="${p.id}">Eliminar</button></td></tr>`).join('')+'</table>';
$('gameList').innerHTML=state.games.map(g=>`<div class="panel"><div class="top"><h3>${esc(g.name)} <span class="pill">${esc(g.kind)}</span> <span class="pill">${g.published?'PUBLICADO':'BORRADOR'}</span></h3><button class="danger" data-del-game="${g.id}">Eliminar prueba</button></div><p class="muted">${esc(g.description)}</p><div class="toolbar"><button data-publish-game="${g.id}" ${g.published?'disabled':''}>Publicar resultados</button><button class="secondary" data-unpublish-game="${g.id}" ${!g.published?'disabled':''}>Volver a borrador</button></div><div class="row"><label>Estado</label><select style="max-width:200px" data-status-game="${g.id}"><option value="pending" ${g.status==='pending'?'selected':''}>Pendiente</option><option value="running" ${g.status==='running'?'selected':''}>En curso</option><option value="finished" ${g.status==='finished'?'selected':''}>Finalizada</option></select></div>${g.kind==='vote'?'<p class="muted">Puntuación automática al cerrar la votación.</p>':`<table class="table"><thead><tr><th>Jugador</th><th>Posición</th><th>Puntos</th><th></th></tr></thead><tbody>${state.players.map(p=>{const r=state.results.find(x=>x.game_id===g.id&&x.player_id===p.id);return `<tr><td>${esc(p.name)}</td><td><input style="max-width:90px" type="number" min="1" data-position="${g.id}:${p.id}" value="${r?.position??''}"></td><td><input style="max-width:90px" type="number" data-points="${g.id}:${p.id}" value="${r?.points??0}"></td><td><button data-save-result="${g.id}:${p.id}">Guardar</button></td></tr>`}).join('')}</tbody></table>`}</div>`).join('')||'<p class="muted">Añade una prueba para empezar.</p>';
const opts=state.games.map(g=>`<option value="${g.id}">${esc(g.name)}</option>`).join('');const selectedBroadcast=$('broadcastGame').value;$('broadcastGame').innerHTML=opts;if(state.games.some(g=>g.id===selectedBroadcast))$('broadcastGame').value=selectedBroadcast;const selectedVote=$('voteGame').value;$('voteGame').innerHTML=state.games.filter(g=>g.kind==='vote').map(g=>`<option value="${g.id}">${esc(g.name)}</option>`).join('');if(state.games.some(g=>g.id===selectedVote))$('voteGame').value=selectedVote;$('broadcastState').textContent=e?.status==='finished'?'Evento finalizado. Reábrelo para continuar.':selected===state.active_id?'Controlando el evento publicado.':'Publica este evento para controlar la retransmisión.';// Mantener acciones accesibles: el manejador informa por qué no procede.
$('finishEvent').disabled=false;
$('reopenEvent').disabled=false;
$('deleteEvent').disabled=false;
}
function showTab(t){tab=t;document.querySelectorAll('[data-page]').forEach(el=>el.classList.toggle('hidden',el.dataset.page!==t));document.querySelectorAll('[data-tab]').forEach(el=>el.classList.toggle('active',el.dataset.tab===t));$('pageTitle').textContent=({inicio:'Centro de control',eventos:'Gestión de eventos',participantes:'Participantes',pruebas:'Pruebas y puntuaciones',directo:'Retransmisión',votaciones:'Votaciones'})[t]}
async function mutate(action,payload){await manage(action,payload);await refresh()}
$('login').onclick=()=>run(async()=>{await login($('email').value,$('password').value);$('password').value='';await refresh();$('auth').classList.add('hidden');$('workspace').classList.remove('hidden')});$('logout').onclick=()=>{logout();$('workspace').classList.add('hidden');$('auth').classList.remove('hidden');$('connection').textContent='Sin conexión'};
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>showTab(b.dataset.tab));
$('newEvent').onclick=()=>{selected=null;state.event=null;state.games=[];state.players=[];state.results=[];render();$('eventName').focus()};
$('saveEvent').onclick=()=>run(async()=>{const scoring=$('eventScoring').value.split(',').map(x=>Number(x.trim()));if(!scoring.length||scoring.length>100||scoring.some(x=>!Number.isInteger(x)||x<0||x>100000))throw Error('Tabla de puntos inválida: introduce enteros positivos separados por comas');const payload={scoring,id:$('eventId').value,name:$('eventName').value.trim(),description:$('eventDescription').value,rules:$('eventRules').value,location:$('eventLocation').value,event_date:$('eventDate').value,theme:$('eventTheme').value};if(!payload.name)throw Error('Introduce un nombre');if(payload.id)await mutate('update_event',payload);else{const r=await manage('create_event',payload);selected=r.id;await refresh()}});
$('activateEvent').onclick=()=>run(async()=>{if(!selected)throw Error('Guarda primero el evento');if(!confirm('¿Publicar este evento para todos los espectadores?'))return;await mutate('activate',{id:selected})});
$('addPlayer').onclick=()=>run(async()=>{if(!selected)throw Error('Selecciona un evento');const name=$('playerName').value.trim();if(!name)throw Error('Introduce un nombre');await mutate('add_player',{event_id:selected,name});$('playerName').value=''});
$('addGame').onclick=()=>run(async()=>{if(!selected)throw Error('Selecciona un evento');const name=$('gameName').value.trim();if(!name)throw Error('Introduce un nombre');await mutate('add_game',{event_id:selected,name,description:$('gameDescription').value,kind:$('gameKind').value,sort_order:state.games.length});$('gameName').value='';$('gameDescription').value=''});
$('generateCodes').onclick=()=>run(async()=>{if(!selected||selected!==state.active_id)throw Error('Activa el evento antes de generar códigos');const id=$('voteGame').value;if(!id)throw Error('Añade una prueba de votación');if(!confirm('Esto invalida los códigos y votos anteriores de esta prueba. ¿Continuar?'))return;const codes=await manage('prepare_votes',{game_id:id});$('codes').textContent=codes.map(x=>x.name+': '+x.code).join('\n');msg('Códigos generados. Cópialos ahora: no se volverán a mostrar.')});
$('openVote').onclick=()=>run(async()=>{await mutate('set_game_status',{id:$('voteGame').value,status:'running'})});
$('closeVote').onclick=()=>run(async()=>{if(!confirm('¿Cerrar votación y calcular puntos?'))return;await mutate('close_votes',{game_id:$('voteGame').value})});
document.addEventListener('click',ev=>{const b=ev.target.closest('button');if(!b)return;if(b.dataset.event){selected=b.dataset.event;run(async()=>{await loadSelected();render()})}if(b.dataset.delPlayer)run(async()=>{if(confirm('¿Eliminar participante y sus resultados?'))await mutate('delete_player',{id:b.dataset.delPlayer})});if(b.dataset.delGame)run(async()=>{if(confirm('¿Eliminar prueba y sus resultados?'))await mutate('delete_game',{id:b.dataset.delGame})});if(b.dataset.saveResult)run(async()=>{const [game_id,player_id]=b.dataset.saveResult.split(':');const position=document.querySelector(`[data-position="${game_id}:${player_id}"]`).value;const points=document.querySelector(`[data-points="${game_id}:${player_id}"]`).value;await mutate('set_result',{game_id,player_id,position,points})});if(b.dataset.publishGame)run(async()=>{if(!confirm('¿Publicar los resultados de esta prueba? Serán visibles en la clasificación pública.'))return;await mutate('publish_results',{game_id:b.dataset.publishGame,published:true})});if(b.dataset.unpublishGame)run(async()=>{if(!confirm('¿Ocultar los resultados de esta prueba?'))return;await mutate('publish_results',{game_id:b.dataset.unpublishGame,published:false})});if(b.dataset.scene)run(async()=>{if(selected!==state.active_id)throw Error('Activa primero este evento');await mutate('broadcast',{event_id:selected,game_id:$('broadcastGame').value||'',mode:b.dataset.scene,seconds:5})})});
document.addEventListener('change',ev=>{if(ev.target.dataset.statusGame)run(async()=>{await mutate('set_game_status',{id:ev.target.dataset.statusGame,status:ev.target.value})})});

document.addEventListener('input',ev=>{if(!ev.target.matches('[data-position]'))return;const [gid]=ev.target.dataset.position.split(':');const game=state.games.find(g=>g.id===gid);if(game?.kind!=='positions')return;const input=ev.target;const position=Number(input.value);const scoring=state.event?.scoring||[10,8,6,5,4,3,2,2,2,2];const pts=Number.isInteger(position)&&position>0?(scoring[position-1]??scoring[scoring.length-1]??0):0;const cell=document.querySelector(`[data-points="${input.dataset.position}"]`);if(cell)cell.value=pts;});
if(!configOk){$('authError').textContent='Configura primero skill_issue_config.js con las claves del nuevo Supabase.'}else if(token()){refresh().then(()=>{$('auth').classList.add('hidden');$('workspace').classList.remove('hidden')}).catch(()=>{logout();$('authError').textContent='La sesión caducó. Inicia sesión de nuevo.'})}

// Event actions: delegated click listener to avoid lost handlers and disabled controls.
const eventActions = {
 finishEvent: async () => {
  if(!selected) throw Error('Selecciona un evento de la lista');
  if(!confirm('¿Finalizar el evento seleccionado?')) return false;
  msg('Enviando solicitud para finalizar…');
  await manage('finish_event',{id:selected});
  await refresh();
  if(state.events.find(e=>e.id===selected)?.status!=='finished') throw Error('Supabase no ha confirmado el cierre del evento');
  msg('Evento FINALIZADO correctamente');return false;
 },
 reopenEvent: async () => {
  if(!selected) throw Error('Selecciona un evento');
  if(!confirm('¿Reabrir este evento?')) return false;
  msg('Reabriendo evento…');await manage('reopen_event',{id:selected});await refresh();
  if(state.events.find(e=>e.id===selected)?.status==='finished') throw Error('Supabase no ha confirmado la reapertura');
  msg('Evento reabierto correctamente');return false;
 },
 deleteEvent: async () => {
  if(!selected||!state.event) throw Error('Selecciona un evento');
  const name=state.event.name;
  if(!confirm(`¿Eliminar DEFINITIVAMENTE «${name}» y todos sus datos?`))return false;
  const typed=prompt('Escribe exactamente el nombre del evento para confirmar:');
  if(typed===null)return false;
  if(typed!==name)throw Error('El nombre no coincide; no se ha eliminado nada');
  msg('Eliminando evento…');const id=selected;
  await manage('delete_event',{id});selected=null;await refresh();
  if(state.events.some(e=>e.id===id))throw Error('Supabase no ha confirmado la eliminación');
  msg('Evento eliminado correctamente');return false;
 }
};
for(const id of Object.keys(eventActions)){
 const button=$(id);
 button.disabled=false;
 button.addEventListener('click',()=>{console.info('[SKILL ISSUE] clic',id,selected);msg('Procesando '+button.textContent+'…');run(eventActions[id]);});
}
