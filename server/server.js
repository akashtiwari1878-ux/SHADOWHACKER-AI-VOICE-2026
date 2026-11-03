import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
dotenv.config();
const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.post('/chat', async (req, res) => {
  try {
    const { provider, messages } = req.body ?? {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'messages array is required' });
    }
    const clean = messages.slice(-20).map(m => ({
      role: m.role === 'assistant' ? 'assistant' : 'user',
      content: String(m.content ?? '').slice(0, 8000)
    }));
    let reply = '';
    if (provider === 'openai') {
      if (!process.env.OPENAI_API_KEY) return res.status(500).json({ error: 'OPENAI_API_KEY server par set nahi hai' });
      const r = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'gpt-5-mini', messages: clean })
      });
      const d = await r.json();
      if (!r.ok) return res.status(r.status).json({ error: d.error?.message ?? 'OpenAI request failed' });
      reply = d.choices?.[0]?.message?.content ?? '';
    } else {
      if (!process.env.GEMINI_API_KEY) return res.status(500).json({ error: 'GEMINI_API_KEY server par set nahi hai' });
      const contents = clean.map(m => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content }]
      }));
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=${process.env.GEMINI_API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents })
      });
      const d = await r.json();
      if (!r.ok) return res.status(r.status).json({ error: d.error?.message ?? 'Gemini request failed' });
      reply = d.candidates?.[0]?.content?.parts?.map(p => p.text ?? '').join('') ?? '';
    }
    return res.json({ reply });
  } catch (e) {
    return res.status(500).json({ error: e.message ?? 'Internal server error' });
  }
});

app.get('/', (_req, res) => res.send('SHADOWHACKER AI backend is running'));
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`SHADOWHACKER AI server listening on ${port}`));
