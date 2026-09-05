import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'}
serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
 try{
  const url=Deno.env.get('SUPABASE_URL')!, service=Deno.env.get('SERVICE_ROLE_KEY')!
  const authHeader=req.headers.get('Authorization')||''
  const token=authHeader.replace(/^Bearer\s+/i,'')
  const admin=createClient(url,service)
  const {data:{user}}=await admin.auth.getUser(token); if(!user) throw new Error('Unauthorized')
  const {data:profile}=await admin.from('profiles').select('role,is_active').eq('id',user.id).single(); if(profile?.role!=='admin'||!profile?.is_active) throw new Error('Admin access required')
  const b=await req.json(); if(!b.email||!b.password||!b.full_name) throw new Error('Name, email and password are required')
  const {data,error}=await admin.auth.admin.createUser({email:b.email,password:b.password,email_confirm:true,user_metadata:{full_name:b.full_name,role:b.role||'viewer'}}); if(error) throw error
  const uid=data.user.id
  await admin.from('profiles').update({full_name:b.full_name,role:b.role||'viewer',email:b.email,is_active:true}).eq('id',uid)
  await admin.from('user_permissions').upsert({user_id:uid,...(b.permissions||{})})
  if(Array.isArray(b.area_ids)&&b.area_ids.length) await admin.from('area_assignments').insert(b.area_ids.map((area_id:string)=>({user_id:uid,area_id,assigned_by:user.id})))
  return new Response(JSON.stringify({user_id:uid}),{headers:{...cors,'Content-Type':'application/json'}})
 }catch(e){return new Response(JSON.stringify({error:e.message}),{status:400,headers:{...cors,'Content-Type':'application/json'}})}
})
