
import { getSupabaseClient } from './supabase-client.js';
export async function handleBeaconEvent(userId, {hwid, type, dm}){
  const sb=getSupabaseClient();
  const taipeiToday=new Date().toLocaleDateString('en-CA',{timeZone:'Asia/Taipei'});
  const globalDailyKey=`${userId}:${taipeiToday}`;

  // 2. device check
  const {data:device}=await sb.from('beacon_devices').select('*').eq('hwid',hwid).eq('is_active',true).maybeSingle();
  if(!device){
    await sb.from('beacon_events').insert({user_id:userId, hwid, event_type:type, device_message:dm, message_sent:false, global_daily_key:globalDailyKey, error_message:'device not found'});
    return {success:false, reason:'device not found'};
  }

  const {data:user}=await sb.from('users').select('line_user_id').eq('line_user_id',userId).maybeSingle();
  const isFriend=!!user;

  // 4. actions
  const {data:actions}=await sb.from('beacon_actions').select('*, beacon_messages!inner(*)').eq('hwid',hwid).eq('trigger_type',type).eq('is_active',true).order('created_at',{ascending:false});
  let selected=null;
  for(const action of (actions||[])){
    const aud=action.target_audience;
    if(aud!=='all'){
      if(aud==='friends' && !isFriend) continue;
      if(aud==='non_friends' && isFriend) continue;
    }
    // RPC checks (simulated via direct query)
    const {data:daily}=await sb.rpc('check_beacon_daily_limit',{p_user_id:userId, p_hwid:hwid, p_action_id:action.id}).maybeSingle().catch(()=>({data:{allowed:true}}));
    const {data:cooldown}=await sb.rpc('check_beacon_cooldown',{p_user_id:userId, p_hwid:hwid, p_action_id:action.id}).maybeSingle().catch(()=>({data:{allowed:true}}));
    // fallback direct check
    if(daily && daily.allowed===false) continue;
    if(cooldown && cooldown.allowed===false) continue;
    selected=action;
    break;
  }

  const {data:inserted}=await sb.from('beacon_events').insert({
    user_id:userId, hwid, event_type:type, device_message:dm, is_friend:isFriend,
    message_sent:!!selected, global_daily_key:globalDailyKey,
    action_id:selected?.id||null, message_id:selected?.message_id||null,
    error_message:selected?null:'no matching action or limit reached'
  }).select().single();

  // 6. statistics upsert
  await sb.from('beacon_statistics').upsert({hwid, date:taipeiToday, enter_count:type==='enter'?1:0, leave_count:type==='leave'?1:0},{onConflict:'hwid,date'}).catch(async()=>{
    const {data:stat}=await sb.from('beacon_statistics').select('*').eq('hwid',hwid).eq('date',taipeiToday).maybeSingle();
    if(stat){
      await sb.from('beacon_statistics').update({enter_count: type==='enter'?stat.enter_count+1:stat.enter_count, leave_count: type==='leave'?stat.leave_count+1:stat.leave_count}).eq('hwid',hwid).eq('date',taipeiToday);
    } else {
      await sb.from('beacon_statistics').insert({hwid, date:taipeiToday, enter_count:type==='enter'?1:0, leave_count:type==='leave'?1:0});
    }
  });

  // 7. global daily throttle
  const {data:alreadySent}=await sb.from('beacon_events').select('id').eq('global_daily_key',globalDailyKey).eq('message_sent',true).neq('id', inserted?.id||'').limit(1).maybeSingle();
  if(alreadySent){
    await sb.from('beacon_events').update({message_sent:false, error_message:'global daily limit 1 reached'}).eq('id', inserted.id);
    return {success:false, reason:'global daily limit'};
  }

  if(!selected) return {success:false, reason:'no action selected'};
  const msg=selected.beacon_messages;
  return {success:true, message: msg.message_type==='text' ? {type:'text', text:msg.message_content} : JSON.parse(msg.message_content)};
}
export default async function handler(event){
  // Netlify function wrapper
  const body=JSON.parse(event.body||'{}');
  return {statusCode:200, body:JSON.stringify({success:true})};
}
