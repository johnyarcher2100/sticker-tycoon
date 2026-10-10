
export const ConversationStage={IDLE:'IDLE',NAMING:'NAMING',UPLOAD_PHOTO:'UPLOAD_PHOTO',STYLING:'STYLING',FRAMING:'FRAMING',EXPRESSIONS:'EXPRESSIONS',SCENE_SELECT:'SCENE_SELECT',CUSTOM_SCENE:'CUSTOM_SCENE',COUNT_SELECT:'COUNT_SELECT',CONFIRMING:'CONFIRMING',GENERATING:'GENERATING',EDITING:'EDITING',AWAITING_COUPON_CODE:'AWAITING_COUPON_CODE'};
import { getSupabaseClient } from './supabase-client.js';
export async function getConversationState(userId){
  const {data}=await getSupabaseClient().from('conversation_states').select('*').eq('user_id',userId).maybeSingle();
  if(!data) return {user_id:userId, stage:ConversationStage.IDLE, temp_data:{}};
  return data;
}
export async function updateConversationState(userId, stage, tempData={}){
  const sb=getSupabaseClient();
  const {data:ex}=await sb.from('conversation_states').select('user_id').eq('user_id',userId).maybeSingle();
  if(ex){ await sb.from('conversation_states').update({stage, temp_data:tempData, updated_at:new Date().toISOString()}).eq('user_id',userId); }
  else { await sb.from('conversation_states').insert({user_id:userId, stage, temp_data:tempData}); }
}
export async function resetConversationState(userId){
  await getSupabaseClient().from('conversation_states').delete().eq('user_id',userId);
}
export function isInCreationFlow(state){ return state && state.stage!==ConversationStage.IDLE && state.stage!==ConversationStage.GENERATING; }
