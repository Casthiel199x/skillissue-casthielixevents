// Deploy with Supabase Edge Functions. Requires authenticated administrator.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req => {
 const headers = {'Content-Type':'application/json','Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
 const reply=(obj:unknown,status=200)=>new Response(JSON.stringify(obj),{status,headers});
 if(req.method==='OPTIONS')return new Response(null,{headers});
 if(req.method!=='POST')return reply({error:'Método no permitido'},405);
 try{
  const bearer=req.headers.get('Authorization')||'';
  const url=Deno.env.get('SUPABASE_URL')!;
  const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
  const client=createClient(url,anon,{global:{headers:{Authorization:bearer}}});
  const {data:{user},error}=await client.auth.getUser();
  if(error||!user?.email)return reply({error:'Debes iniciar sesión como administrador'},401);
  const {data:isAdmin,error:adminError}=await client.rpc('si_is_admin');
  if(adminError||!isAdmin)return reply({error:'Sin permisos de administrador'},403);
  const {lodestone_id}=await req.json();
  if(typeof lodestone_id!=='string'||!/^[0-9]{1,16}$/.test(lodestone_id))return reply({error:'ID inválido'},400);
  const target=`https://eu.finalfantasyxiv.com/lodestone/character/${lodestone_id}/`;
  const response=await fetch(target,{headers:{'User-Agent':'Mozilla/5.0 (compatible; SkillIssueCommunity/1.0)'},signal:AbortSignal.timeout(12000)});
  if(!response.ok)return reply({error:'Lodestone no ha permitido consultar el perfil. Usa edición manual.'},502);
  const html=await response.text();
  const unescape=(s:string)=>s.replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>');
  const meta=(key:string)=>{const m=html.match(new RegExp(`<meta[^>]+(?:property|name)=["']${key}["'][^>]+content=["']([^"']+)`, 'i'))||html.match(new RegExp(`<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${key}["']`, 'i'));return m?unescape(m[1]):''};
  const title=meta('og:title').replace(/\s*\|.*$/,'').trim();
  const name=title||unescape(html.match(/class=["'][^"']*frame__chara__name[^"']*["'][^>]*>([^<]+)/i)?.[1]||'');
  if(!name||name.length>100)return reply({error:'No se pudo leer el nombre del personaje. Completa la ficha manualmente.'},422);
  const rawImage=meta('og:image');
  const image=/^https:\/\/(?:img2?\.finalfantasyxiv\.com)\//.test(rawImage)?rawImage:null;
  const world=unescape(html.match(/class=["'][^"']*frame__chara__world[^"']*["'][^>]*>([^<]+)/i)?.[1]||'').trim();
  return reply({lodestone_id,name,world,portrait_url:image,avatar_url:image,source:'lodestone-public',lodestone_url:target});
 }catch(e){return reply({error:'No se pudo consultar Lodestone. Puedes rellenar la ficha manualmente.'},502)}
});
