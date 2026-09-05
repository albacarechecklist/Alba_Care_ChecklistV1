import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'}
serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors})
 try{
  const url=Deno.env.get('SUPABASE_URL')!, service=Deno.env.get('SERVICE_ROLE_KEY')!, resend=Deno.env.get('RESEND_API_KEY')
  const admin=createClient(url,service);const {submission_id}=await req.json();if(!submission_id) throw new Error('submission_id required')
  const {data:s,error}=await admin.from('submissions').select('*,areas(name),profiles!submissions_submitted_by_fkey(full_name,email)').eq('id',submission_id).single();if(error)throw error
  const {data:set}=await admin.from('app_settings').select('value').eq('key','admin_notification_email').maybeSingle();const to=set?.value?.trim();
  if(!resend||!to) return new Response(JSON.stringify({ok:true,email_sent:false,reason:'RESEND_API_KEY or admin_notification_email not configured'}),{headers:{...cors,'Content-Type':'application/json'}})
  const subject=`Alba Care checklist submitted - ${s.areas?.name||'Area'}`
  const html=`<h2>Alba Care Daily Checklist</h2><p><b>${s.profiles?.full_name||'Staff'}</b> submitted <b>${s.areas?.name||''}</b>.</p><p>Date: ${s.checklist_date}<br>Compliance: <b>${s.compliance_score??'N/A'}%</b><br>C: ${s.c_count} &nbsp; NC: ${s.nc_count} &nbsp; N/A: ${s.na_count}</p>`
  const rr=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${resend}`,'Content-Type':'application/json'},body:JSON.stringify({from:'Alba Care Checklist <onboarding@resend.dev>',to:[to],subject,html})});if(!rr.ok) throw new Error(await rr.text())
  return new Response(JSON.stringify({ok:true,email_sent:true}),{headers:{...cors,'Content-Type':'application/json'}})
 }catch(e){return new Response(JSON.stringify({error:e.message}),{status:400,headers:{...cors,'Content-Type':'application/json'}})}
})
