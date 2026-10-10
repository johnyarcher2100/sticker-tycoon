const { callAI } = require('./utils/ai-api-client');

exports.handler = async (event) => {
  const { prompt, style, type } = JSON.parse(event.body || '{}');
  
  const system = `你是貼圖大亨的文案大師，專做LINE貼圖的搞笑文案，台灣口氣，短而賤，8字內。風格：${style||'賤賤可愛'}`;
  const fullPrompt = `${system}\n用戶要：${prompt}\n類型：${type||'貼圖文字'}\n直接給10個選項，一行一個，不要編號`;

  try {
    const result = await callAI(fullPrompt, { model: 'abab6.5s-chat', max_tokens: 512, temperature: 0.9 });
    return { statusCode: 200, body: JSON.stringify({ text: result }) };
  } catch(e){
    return { statusCode: 500, body: JSON.stringify({ error: e.message }) };
  }
};
