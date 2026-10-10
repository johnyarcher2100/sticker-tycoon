
import axios from 'axios';
export function isDeepSeekAvailable(){ return !!process.env.DEEPSEEK_API_KEY; }
export async function enhanceExpressions({style, expressions}){
  if(!isDeepSeekAvailable()) return expressions;
  try{
    const base=process.env.DEEPSEEK_API_URL||'https://tbnx.plus7.plus/v1/chat/completions';
    const key=process.env.DEEPSEEK_API_KEY;
    const model=process.env.DEEPSEEK_MODEL||'deepseek-chat';
    const prompt=`你是LINE貼圖表情優化師。風格:${style}。把以下表情變成更有動作感、隨機變化、保持風格一致的描述，回傳JSON array: ${JSON.stringify(expressions)}`;
    const res=await axios.post(base, {model, messages:[{role:'user',content:prompt}]}, {headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'}, timeout:30000});
    const content=res.data.choices?.[0]?.message?.content||'';
    const match=content.match(/\[.*\]/s);
    if(match){ return JSON.parse(match[0]); }
    return expressions;
  }catch{ return expressions; }
}
