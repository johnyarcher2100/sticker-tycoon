
import { callAIWithFallback } from './utils/ai-api-client.js';
import { generatePhotoStickerPromptV2 } from './sticker-styles.js';
import { enhanceExpressions } from './deepseek-enhancer.js';

export async function generateStickerSetFromPhoto({photoBase64, style, expressions, characterId, sceneConfig, framingConfig}){
  let exprList=expressions;
  try{ exprList=await enhanceExpressions({style, expressions}); }catch{}
  const results=[];
  for(const expr of exprList){
    const {prompt}=generatePhotoStickerPromptV2(style, expr, characterId, sceneConfig, framingConfig);
    try{
      const {imageUrl}=await callAIWithFallback(prompt + ` photo ref:${photoBase64.slice(0,500)}`);
      results.push({expression:expr, imageUrl, status:'completed'});
    }catch(e){
      results.push({expression:expr, error:e.message, status:'failed'});
    }
  }
  return results;
}
