import {SUPABASE_URL,SUPABASE_ANON_KEY} from '../skill_issue_config.js';
const base=SUPABASE_URL.replace(/\/+$/,'');
export const configOk=base.startsWith('https://')&&!base.includes('TU_PROYECTO')&&SUPABASE_ANON_KEY&&!SUPABASE_ANON_KEY.includes('TU_CLAVE');
let session=JSON.parse(sessionStorage.getItem('si14_session')||'null');
export function token(){return session?.access_token||null}
export function logout(){session=null;sessionStorage.removeItem('si14_session')}
export async function login(email,password){const r=await fetch(`${base}/auth/v1/token?grant_type=password`,{method:'POST',headers:{apikey:SUPABASE_ANON_KEY,'Content-Type':'application/json'},body:JSON.stringify({email,password})});const j=await r.json();if(!r.ok)throw Error(j.error_description||j.msg||'No se pudo iniciar sesión');session=j;sessionStorage.setItem('si14_session',JSON.stringify(j));return j}
export async function rpc(name,params={}){if(!configOk)throw Error('Configura skill_issue_config.js');const headers={apikey:SUPABASE_ANON_KEY,Authorization:`Bearer ${token()||SUPABASE_ANON_KEY}`,'Content-Type':'application/json'};const r=await fetch(`${base}/rest/v1/rpc/${name}`,{method:'POST',headers,body:JSON.stringify(params)});const raw=await r.text();let j;try{j=JSON.parse(raw)}catch{j=raw}if(!r.ok)throw Error(j?.message||`Error ${r.status}`);return j}
export const manage=(action,payload={})=>rpc('si_manage',{p_action:action,p_payload:payload});
export const snapshot=(admin=false)=>rpc('si_snapshot',{p_admin:admin});
export const detail=id=>rpc('si_event_detail',{p_id:id});
export const $=id=>document.getElementById(id);
export function esc(x){return String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
export function points(s){const totals=new Map((s.players||[]).map(p=>[p.id,0]));for(const r of s.results||[])totals.set(r.player_id,(totals.get(r.player_id)||0)+Number(r.points||0));return [...(s.players||[])].map(p=>({...p,points:totals.get(p.id)||0})).sort((a,b)=>b.points-a.points||a.name.localeCompare(b.name))}
export function dateString(d){return d?new Date(d).toLocaleString('es-ES'):''}
