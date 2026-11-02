# SHADOWHACKER AI — Voice Personal Assistant

## इस प्रोजेक्ट में
- Gemini / OpenAI मॉडल स्विच
- हिंदी voice input (फोन के Speech Recognition से)
- AI reply को हिंदी में बोलकर सुनाना (फोन के Text-to-Speech से)
- Chat history फोन में सेव
- APK GitHub Actions से ऑनलाइन build

## जरूरी बात
Voice recognition और बोलकर जवाब देने के लिए फोन की Android Speech Recognition / Text-to-Speech सेवाएँ इस्तेमाल होती हैं। यह अभी लगातार हमेशा सुनने वाला wake-word assistant नहीं है: माइक बटन दबाकर बोलना होगा। इंटरनेट और backend जरूरी हैं।

## मोबाइल से APK बनाना
1. ZIP extract करें।
2. GitHub पर login करके नया repository बनाएं, जैसे `shadowhacker-ai`।
3. Extract किए गए folder के अंदर की सभी files/folders repository के root में upload करें। `.github/workflows/android-apk.yml` भी जरूर upload करें।
4. GitHub repository → Actions → `Build SHADOWHACKER AI APK` → Run workflow।
5. Build पूरा होने पर workflow run के नीचे Artifacts में `shadowhacker-ai-voice-apk` डाउनलोड करें और ZIP extract करें। APK install करें।

## Backend लगाना
1. `server` folder को Node.js hosting पर deploy करें। Hosting में Start command `npm start` और Root/working directory `server` रखें (या server folder के अंदर deploy करें)।
2. Hosting के Environment Variables में `GEMINI_API_KEY` और `OPENAI_API_KEY` डालें। कम-से-कम जिस provider का उपयोग करना है उसकी key जरूरी है।
3. Deploy होने के बाद HTTPS URL नोट करें, जैसे `https://your-service.example`।
4. `lib/main.dart` में `serverUrl` को `https://your-service.example/chat` से बदलें।
5. GitHub पर updated `lib/main.dart` upload/commit करें। Actions दोबारा चलाकर नया APK लें।

API key कभी भी Flutter ऐप के अंदर न डालें। केवल backend hosting के Environment Variables में रखें। API usage पर शुल्क लग सकता है; provider की pricing/limits देखें। Backend को public करने से पहले authentication, rate limits और usage limits जोड़ें।

## API keys
- Gemini: https://aistudio.google.com/apikey
- OpenAI: https://platform.openai.com/api-keys

## Troubleshooting
- माइक permission पूछे तो Allow करें।
- फोन में Google Speech Services / speech recognition उपलब्ध और अपडेटेड होना चाहिए।
- AI जवाब न दे तो `serverUrl`, backend deployment और server environment variables जांचें।
- `YOUR-BACKEND-DOMAIN` placeholder रहने पर ऐप backend से connect नहीं होगा।
