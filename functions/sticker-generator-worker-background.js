
import { getSupabaseClient } from './supabase-client.js';
import { callAIWithFallback } from './utils/ai-api-client.js';
import { generatePhotoStickerPromptV2, generateCharacterID } from './sticker-styles.js';

export async function handler(event){
  const {taskId, setId, userId, taskType} = JSON.parse(event.body||'{}');
  const sb=getSupabaseClient();
  await sb.from('generation_tasks').update({status:'processing', progress:5}).eq('task_id',taskId);
  const {data:set}=await sb.from('sticker_sets').select('*').eq('set_id',setId).single();
  const charId=generateCharacterID(set.photo_data?.slice(0,1000)||'', set.style);

  // load styles from DB (fallback to file)
  // grid logic: if count>=6 -> 6 per batch
  const count=set.sticker_count||18;
  const expressions=set.expressions||['早安','OK','謝謝','加油','晚安','讚'];
  const batches=Math.ceil(count/6);

  for(let b=0;b<batches;b++){
    const batchExpr=expressions.slice(b*6, (b+1)*6);
    // generate grid prompt
    const prompt=generatePhotoStickerPromptV2(set.style, batchExpr.join(','), charId, {decoration_style:'minimal'}, {compactPrompt:'Waist up 85% fill'});
    try{
      const {imageUrl}=await callAIWithFallback(prompt.prompt);
      // TODO: Sharp split 6 images + upload to sticker-images bucket
      // insert into stickers table
      for(let i=0;i<batchExpr.length;i++){
        await sb.from('stickers').insert({set_id:setId, index_number:b*6+i, expression:batchExpr[i], image_url:imageUrl, status:'completed'});
      }
      await sb.from('generation_tasks').update({progress:Math.round((b+1)/batches*90)}).eq('task_id',taskId);
    }catch(e){
      await sb.from('generation_tasks').update({status:'failed', error_message:e.message}).eq('task_id',taskId);
      return {statusCode:200};
    }
  }

  await sb.from('sticker_sets').update({status:'completed'}).eq('set_id',setId);
  await sb.from('generation_tasks').update({status:'completed', progress:100, completed_at:new Date().toISOString()}).eq('task_id',taskId);

  // deduct tokens FIFO
  const { deductTokens } = await import('./supabase-client.js');
  const tokensRequired=Math.ceil(count/6)*3;
  await deductTokens(userId, tokensRequired, `生成貼圖 ${count}張`);

  // quick_launch回補最後一組
  if(taskType==='quick_launch'){
    // check if last batch -> +14 promotion_refund with reference_id idempotency
    const { addTokens } = await import('./supabase-client.js');
    // referenceId example
    await addTokens(userId, 14, 'promotion_refund', '爆量出圖回補', {referenceId:`quick_launch_refund_${taskId}`});
  }

  return {statusCode:200, body:JSON.stringify({success:true})};
}
