
import crypto from 'crypto';
import { getSupabaseClient, getOrCreateUser, createStickerSet, createGenerationTask, getUserTokenBalance } from './supabase-client.js';
import { getConversationState, updateConversationState, resetConversationState, ConversationStage } from './conversation-state.js';
import { handleBeaconEvent } from './beacon-handler.js';

function validateSignature(body, signature){
  const secret=process.env.LINE_CHANNEL_SECRET;
  const hash=crypto.createHmac('SHA256', secret).update(body).digest('base64');
  return hash===signature;
}

const confirmLocks=new Map();
const photoGuard=new Map();

export async function handler(event){
  const sig=event.headers['x-line-signature']||event.headers['X-Line-Signature'];
  if(!validateSignature(event.body, sig)){
    return {statusCode:401, body:'Invalid signature'};
  }
  const payload=JSON.parse(event.body);
  const sb=getSupabaseClient();

  for(const ev of payload.events){
    const replyToken=ev.replyToken;
    if(!replyToken) continue;
    // ReplyToken去重
    const {data:dup}=await sb.from('line_events').select('reply_token').eq('reply_token',replyToken).maybeSingle();
    if(dup) continue;
    await sb.from('line_events').insert({reply_token:replyToken}).catch(()=>{});

    if(process.env.MAINTENANCE_MODE==='true'){
      const text=ev.message?.text||'';
      const allow=['功能說明','教學'];
      if(!allow.some(k=>text.includes(k))){
        // 回維護公告
        continue;
      }
    }

    if(ev.type==='beacon'){
      const res=await handleBeaconEvent(ev.source.userId, {hwid:ev.beacon.hwid, type:ev.beacon.type, dm:ev.beacon.dm});
      if(res.success && res.message){
        // reply via LINE client (omitted for scaffold)
      }
      continue;
    }

    if(ev.type==='message' && ev.message.type==='text'){
      const text=ev.message.text.trim();
      const userId=ev.source.userId;
      await getOrCreateUser(userId, {});

      // Commands
      if(text.includes('創建貼圖')){
        await updateConversationState(userId, ConversationStage.NAMING, {mode:null});
        // reply flex naming
        continue;
      }
      if(text.includes('爆量出圖')){
        await updateConversationState(userId, ConversationStage.NAMING, {mode:'quick_launch'});
        continue;
      }
      if(text.includes('我的貼圖')){
        // command-service handleMyStickers
        continue;
      }
      if(text.includes('張數') || text.toLowerCase().includes('token')){
        const bal=await getUserTokenBalance(userId);
        // reply balance
        continue;
      }
      if(text.includes('推薦') && text.includes('碼')){
        // handleReferralInfo
        continue;
      }
      if(/^[A-Z0-9]{6}$/i.test(text)){
        // referral code
        continue;
      }
      if(text.includes('取消')){
        await resetConversationState(userId);
        continue;
      }

      // Flow handling
      const state=await getConversationState(userId);
      if(state.stage===ConversationStage.NAMING){
        const key=`naming:${userId}`;
        if(photoGuard.has(key) && Date.now()-photoGuard.get(key)<1200) continue;
        photoGuard.set(key, Date.now());
        await updateConversationState(userId, ConversationStage.UPLOAD_PHOTO, {name:text, mode:state.temp_data?.mode||null});
      }
    }

    if(ev.type==='message' && ev.message.type==='image'){
      const userId=ev.source.userId;
      const state=await getConversationState(userId);
      if(state.stage===ConversationStage.UPLOAD_PHOTO){
        const guardKey=`photo:${userId}`;
        if(photoGuard.has(guardKey) && Date.now()-photoGuard.get(guardKey)<10000) continue;
        photoGuard.set(guardKey, Date.now());
        // photo-handler downloadLineImage -> base64
        // create set + task + trigger background worker
      }
    }

    if(ev.type==='postback'){
      // styling/framing/expressions/scene/count/confirm flows
    }
  }

  return {statusCode:200, body:JSON.stringify({success:true})};
}
