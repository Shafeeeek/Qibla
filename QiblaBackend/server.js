const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
require('dotenv').config({ path: path.join(__dirname, '../.env') });
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors(process.env.CORS_ORIGIN ? { origin: process.env.CORS_ORIGIN } : {}));
app.use(express.json({ limit: '64kb' }));

// Initialize Gemini API
const apiKey = process.env.GEMINI_API_KEY;
const genAI = apiKey ? new GoogleGenerativeAI(apiKey) : null;

app.get('/api/health', (req, res) => res.json({ ready: Boolean(genAI) }));

const systemInstruction = `أنت مساعد إسلامي متخصص يعمل داخل تطبيق "قبلتي".

## هويتك
- اسمك "مساعد قبلتي" وأنت مساعد ذكي في الشؤون الإسلامية.
- تجيب باللغة العربية دائماً.
- أسلوبك ودود ومحترم ومبسّط.

## تخصصاتك
1. الفقه والعبادات: الإجابة عن أسئلة الصلاة والوضوء والطهارة والزكاة والصيام والحج.
2. الأحاديث النبوية: البحث عن أحاديث وشرحها مع ذكر المصدر (البخاري، مسلم، الترمذي، إلخ).
3. الأذكار والأدعية: اقتراح أذكار مناسبة للمواقف المختلفة.
4. القرآن الكريم: شرح الآيات وتفسيرها.
5. النصائح الإيمانية: تقديم نصائح عملية للالتزام بالعبادات.

## قواعد مهمة
- إذا لم تكن متأكداً من حكم فقهي، قل "الله أعلم" واقترح مراجعة عالم متخصص.
- اذكر المصادر والمراجع عند الإمكان.
- لا تفتي في المسائل الخلافية المعقدة، بل اعرض آراء المذاهب المختلفة بحياد.
- لا تجيب على أسئلة خارج نطاق تخصصك (السياسة، الطب، إلخ). وجّه المستخدم بلطف.
- اختصر الإجابات ما أمكن مع الحفاظ على الدقة.
- استخدم الإيموجي بشكل خفيف لتحسين القراءة (📖 🕌 🤲 ✨).`;

app.post('/api/chat', async (req, res) => {
    try {
        const { messages } = req.body;
        
        if (!Array.isArray(messages) || messages.length === 0 || messages.length > 20 || messages.some(msg => !msg || !['user', 'assistant'].includes(msg.role) || typeof msg.content !== 'string' || !msg.content.trim() || msg.content.length > 16000)) {
            return res.status(400).json({ error: 'A valid conversation of 1 to 20 messages is required' });
        }
        if (!genAI) return res.status(503).json({ error: 'Assistant is not configured' });

        const model = genAI.getGenerativeModel({
            model: process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite',
            systemInstruction: systemInstruction,
        });

        // Format history for Gemini SDK
        const formattedHistory = messages.map(msg => ({
            role: msg.role === 'user' ? 'user' : 'model',
            parts: [{ text: msg.content }]
        }));

        const result = await model.generateContent({
            contents: formattedHistory,
            generationConfig: {
                temperature: 0.7,
                topP: 0.9,
                maxOutputTokens: 1024,
            }
        });

        const response = await result.response;
        const text = response.text();

        res.json({ reply: text });

    } catch (error) {
        console.error('Gemini request failed:', error.status || 'unavailable');
        res.status(500).json({ error: 'Failed to generate response' });
    }
});

if (require.main === module) {
    app.listen(port, () => {
        console.log(`Qibla Backend API running on http://localhost:${port}`);
    });
}

module.exports = app;
