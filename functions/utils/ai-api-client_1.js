// Minimax + fallback
const fetch = global.fetch || require('node-fetch');

const MINIMAX_URL = 'https://api.minimax.chat/v1/text/chatcompletion_v2';

async function callMinimax(prompt, opts={}) {
  const apiKey = process.env.MINIMAX_API_KEY;
  const groupId = process.env.MINIMAX_GROUP_ID;
  if (!apiKey) throw new Error('MINIMAX_API_KEY not set');
  
  const body = {
    model: opts.model || 'abab6.5s-chat',
    messages: [
      { sender_type: 'USER', sender_name: 'user', text: prompt }
    ],
    tokens_to_generate: opts.max_tokens || 1024,
    temperature: opts.temperature || 0.8,
    stream: false
  };
  
  const url = groupId ? `${MINIMAX_URL}?GroupId=${groupId}` : MINIMAX_URL;
  
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(body)
  });
  
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Minimax ${res.status}: ${t}`);
  }
  const data = await res.json();
  // Minimax format: choices[0].messages[0].text or reply
  const text = data?.choices?.[0]?.messages?.[0]?.text || data?.reply || data?.base_resp || JSON.stringify(data);
  return text;
}

async function callAI(prompt, opts={}) {
  // priority: Minimax > DeepSeek > OpenAI
  if (process.env.MINIMAX_API_KEY) {
    try { return await callMinimax(prompt, opts); } catch(e){ console.error('Minimax fail', e.message); }
  }
  // fallback to deepseek if configured
  if (process.env.DEEPSEEK_API_KEY) {
    try {
      const r = await fetch('https://api.deepseek.com/v1/chat/completions', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'deepseek-chat', messages: [{role:'user', content: prompt}], max_tokens: opts.max_tokens||1024 })
      });
      const j = await r.json();
      return j.choices?.[0]?.message?.content || '';
    } catch(e){ console.error('DeepSeek fail', e.message); }
  }
  throw new Error('No AI key configured');
}

module.exports = { callAI, callMinimax };
