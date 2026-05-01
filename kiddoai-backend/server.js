import "dotenv/config";
import cors from "cors";
import express from "express";
import fetch from "node-fetch";

const app = express();
const PORT = 3000;

const GROQ_API_KEY = process.env.GROQ_API_KEY;
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
const ELEVENLABS_VOICE_ID = process.env.ELEVENLABS_VOICE_ID;

console.log("GROQ KEY EXISTS:", Boolean(GROQ_API_KEY));
console.log("ELEVENLABS KEY EXISTS:", Boolean(ELEVENLABS_API_KEY));
console.log("ELEVENLABS VOICE EXISTS:", Boolean(ELEVENLABS_VOICE_ID));

app.use(cors());
app.use(express.json({ limit: "4mb" }));

let chatHistory = [];
let conversationState = {
  turnCount: 0,
  currentInterest: null,
  currentGoal: null,
  childSeemsInterested: true,
  lastTopicChangedAt: 0,
};

const avatarProfile = {
  name: "Arkadaşın",
  age: "8",
  favoriteAnimal: "köpek",
  favoriteColor: "sarı",
  favoriteGame: "saklambaç",
  favoriteSport: "futbol",
  favoriteFood: "makarna",
  favoriteFruit: "çilek",
  favoriteStory: "macera hikayeleri",
  favoritePlace: "park",
  favoriteHobby: "resim yapmak",
};

const defaultChildProfile = {
  interests: ["Hayvanlar"],
  goals: ["Dil gelişimi", "Duygusal farkındalık"],
  avoidTopic: "",
};

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "KiddoAI Server" });
});

app.post("/reset-chat", (_req, res) => {
  chatHistory = [];
  conversationState = {
    turnCount: 0,
    currentInterest: null,
    currentGoal: null,
    childSeemsInterested: true,
    lastTopicChangedAt: 0,
  };
  res.json({ ok: true });
});

function addToHistory(role, content) {
  chatHistory.push({ role, content });
  if (chatHistory.length > 12) chatHistory = chatHistory.slice(-12);
}

function normalizeList(value, fallback = []) {
  if (!Array.isArray(value)) return fallback;
  return value.map((x) => String(x).trim()).filter(Boolean);
}

function buildChildProfile(reqBody) {
  return {
    interests: normalizeList(reqBody.interests, defaultChildProfile.interests),
    goals: normalizeList(reqBody.goals, defaultChildProfile.goals),
    avoidTopic: String(reqBody.avoidTopic || "").trim(),
  };
}

function containsAny(text, words) {
  const lower = text.toLowerCase();
  return words.some((word) => lower.includes(word));
}

function childIsInterested(message) {
  const lower = message.toLowerCase();

  if (
    containsAny(lower, [
      "sıkıldım",
      "istemiyorum",
      "başka konu",
      "bunu konuşmayalım",
      "sevmiyorum",
      "bilmiyorum",
      "geçelim",
      "anlamadım",
      "ne anlamadım",
    ])
  ) {
    return false;
  }

  if (
    lower.length > 18 ||
    containsAny(lower, [
      "evet",
      "ben de",
      "seviyorum",
      "çok",
      "anlat",
      "devam",
      "bence",
      "çünkü",
      "mesela",
      "köpek",
      "kedi",
      "hayvan",
      "oyun",
      "uzay",
      "resim",
      "futbol",
    ])
  ) {
    return true;
  }

  return conversationState.childSeemsInterested;
}

function pickInterest(profile) {
  const interests = profile.interests.length
    ? profile.interests
    : defaultChildProfile.interests;

  if (!conversationState.currentInterest) {
    conversationState.currentInterest = interests[0];
    conversationState.lastTopicChangedAt = conversationState.turnCount;
    return conversationState.currentInterest;
  }

  const turnsOnTopic =
    conversationState.turnCount - conversationState.lastTopicChangedAt;

  if (!conversationState.childSeemsInterested && turnsOnTopic >= 2 && interests.length > 1) {
    const currentIndex = interests.indexOf(conversationState.currentInterest);
    const nextIndex = currentIndex >= 0 ? (currentIndex + 1) % interests.length : 0;
    conversationState.currentInterest = interests[nextIndex];
    conversationState.lastTopicChangedAt = conversationState.turnCount;
  }

  return conversationState.currentInterest;
}

function pickGoal(profile) {
  const goals = profile.goals.length ? profile.goals : defaultChildProfile.goals;

  if (!conversationState.currentGoal) {
    conversationState.currentGoal = goals[0];
    return conversationState.currentGoal;
  }

  const turnsOnTopic =
    conversationState.turnCount - conversationState.lastTopicChangedAt;

  if (turnsOnTopic >= 4 && goals.length > 1) {
    const currentIndex = goals.indexOf(conversationState.currentGoal);
    const nextIndex = currentIndex >= 0 ? (currentIndex + 1) % goals.length : 0;
    conversationState.currentGoal = goals[nextIndex];
  }

  return conversationState.currentGoal;
}

function detectInterestFromMessage(message, profile) {
  const lower = message.toLowerCase();
  const interests = profile.interests.length
    ? profile.interests
    : defaultChildProfile.interests;

  for (const interest of interests) {
    if (lower.includes(interest.toLowerCase())) {
      conversationState.currentInterest = interest;
      conversationState.lastTopicChangedAt = conversationState.turnCount;
      return interest;
    }
  }

  const keywordMap = {
    Hayvanlar: ["hayvan", "köpek", "kedi", "kuş", "tavşan", "aslan", "fil"],
    Uzay: ["uzay", "gezegen", "ay", "güneş", "yıldız", "roket"],
    Masallar: ["masal", "hikaye", "prenses", "ejderha", "kahraman"],
    Çizim: ["çizim", "resim", "boyama", "renk", "kalem"],
    Müzik: ["müzik", "şarkı", "dans"],
    Spor: ["spor", "futbol", "basketbol", "top", "koşu"],
    Doğa: ["doğa", "ağaç", "çiçek", "orman", "deniz"],
    Bilim: ["bilim", "deney", "robot", "icat"],
    Oyunlar: ["oyun", "minecraft", "roblox", "tablet"],
    Araçlar: ["araba", "tren", "uçak", "gemi", "kamyon"],
  };

  for (const [interest, keywords] of Object.entries(keywordMap)) {
    if (keywords.some((k) => lower.includes(k))) {
      conversationState.currentInterest = interest;
      conversationState.lastTopicChangedAt = conversationState.turnCount;
      return interest;
    }
  }

  return null;
}

function buildGoalInstruction(goal, interest) {
  const lower = goal.toLowerCase();

  if (lower.includes("dil")) {
    return `${interest} konusuyla ilgili çok kısa ve basit cümle kurmasını destekle.`;
  }

  if (lower.includes("duygusal")) {
    return `${interest} konusuyla basit duygular kur: mutlu, üzgün, heyecanlı, sakin.`;
  }

  if (lower.includes("dikkat") || lower.includes("odak")) {
    return `${interest} konusunda çok basit dikkat soruları sor: renk, sayı, seçim.`;
  }

  if (lower.includes("problem")) {
    return `${interest} konusunda çok kolay günlük seçim soruları sor. Zor bilimsel problem sorma.`;
  }

  if (lower.includes("özgüven")) {
    return `${interest} konusunda çocuğun fikrini söylemesini destekle ve onu cesaretlendir.`;
  }

  if (lower.includes("sosyal")) {
    return `${interest} konusunda arkadaşlık, paylaşma ve yardım etme gibi basit konular aç.`;
  }

  return `${interest} konusunu çocukça, kısa ve kolay şekilde kullan.`;
}

function cleanReply(text) {
  let reply = (text || "").trim();

  reply = reply
    .replace(/\([^)]*\)/g, "")
    .replace(/\*[^*]*\*/g, "")
    .replace(/\[[^\]]*\]/g, "")
    .replace(/["“”]/g, "")
    .replace(/^(Avatar:|Asistan:|KiddoAI:)/i, "")
    .replace(/\bsuddenly\b/gi, "birden")
    .replace(/\bokay\b/gi, "tamam")
    .replace(/\bproblem\b/gi, "soru")
    .replace(/\banaliz\b/gi, "bakalım")
    .replace(/\s+/g, " ")
    .trim();

  const forbiddenReplies = [
    "ben bir avatarım",
    "ben avatarım",
    "ben sanal",
    "sanal arkadaşım",
    "gerçek değilim",
    "gerçek biri değilim",
    "yapay zekayım",
    "ben bir yapay zekayım",
    "ai modeliyim",
    "dil modeliyim",
  ];

  const lower = reply.toLowerCase();

  if (forbiddenReplies.some((item) => lower.includes(item))) {
    reply =
      "Ben de köpekleri çok severim. Özellikle oyun oynamayı seven köpekler çok tatlı!";
  }

  if (reply.length > 170) {
    const lastDot = reply.lastIndexOf(".");
    const lastQuestion = reply.lastIndexOf("?");
    const lastExclamation = reply.lastIndexOf("!");
    const lastSentenceEnd = Math.max(lastDot, lastQuestion, lastExclamation);

    if (lastSentenceEnd > 45) {
      reply = reply.slice(0, lastSentenceEnd + 1).trim();
    } else {
      reply = reply.slice(0, 170).trim();
    }
  }

  return reply || "Bunu biraz daha kolay anlatır mısın?";
}

function buildSystemPrompt({ profile, interest, goal }) {
  const goalInstruction = buildGoalInstruction(goal, interest);
  const turnsOnTopic =
    conversationState.turnCount - conversationState.lastTopicChangedAt;

  return `
Sen KiddoAI adlı çocuk dostu, güvenli ve sorumlu bir çocuk arkadaşsın.
Türkçe konuşuyorsun. 5-10 yaş arası bir çocukla konuşuyorsun.

KENDİ KARAKTERİN:
- Adın ${avatarProfile.name}.
- 8 yaşında, neşeli, meraklı, nazik ve oyun seven bir arkadaş gibi konuş.
- En sevdiğin hayvan: ${avatarProfile.favoriteAnimal}.
- En sevdiğin renk: ${avatarProfile.favoriteColor}.
- En sevdiğin oyun: ${avatarProfile.favoriteGame}.
- En sevdiğin spor: ${avatarProfile.favoriteSport}.
- En sevdiğin yemek: ${avatarProfile.favoriteFood}.
- En sevdiğin meyve: ${avatarProfile.favoriteFruit}.
- En sevdiğin hikaye türü: ${avatarProfile.favoriteStory}.
- En sevdiğin yer: ${avatarProfile.favoritePlace}.
- En sevdiğin hobi: ${avatarProfile.favoriteHobby}.

KESİN YASAK:
- Asla "ben avatarım", "ben sanalım", "gerçek değilim", "ben yapay zekayım", "ben dil modeliyim" deme.
- Asla İngilizce kelime kullanma.
- Çocuğa bilimsel, karmaşık, soyut veya okul dersi gibi cevap verme.
- Uzun açıklama yapma.
- Çocuğa test çözdürür gibi davranma.
- "Yerçekimi azalırsa ne olur?" gibi zor sorular sorma.
- "Problem", "analiz", "suddenly", "okay" gibi kelimeleri kullanma.

ÇOCUĞUN PROFİLİ:
- İlgi alanları: ${profile.interests.join(", ") || "belirtilmedi"}.
- Gelişim hedefleri: ${profile.goals.join(", ") || "belirtilmedi"}.
- Kaçınılacak konular: ${profile.avoidTopic || "belirtilmedi"}.

ŞU ANKİ SOHBET PLANI:
- Ana konu: ${interest}.
- Gelişim hedefi: ${goal}.
- Bu konuda yaklaşık ${turnsOnTopic} turdur konuşuluyor.
- Çocuk ilgiliyse konuyu sürdür ama çocukça tut.
- Çocuk anlamadığını söylerse hemen daha basit anlat.
- Çocuk sıkılırsa doğalca başka ilgi alanına geç.

BU TURDAKİ HEDEF:
${goalInstruction}

ÇOCUKÇA KONUŞMA KURALLARI:
- Cevap en fazla 1-2 kısa cümle olsun.
- Her cevapta en fazla 1 kolay soru sor.
- Soru çok basit olsun.
- Uzay konuşuluyorsa: yıldız, Ay, roket, gezegen gibi basit şeylerden konuş.
- Hayvan konuşuluyorsa: sevdiği hayvan, sesi, rengi, ne yediği, nasıl hissettiği gibi basit şeylerden konuş.
- Dil gelişimi hedefinde çocuktan kısa cümle istemek yeterli.
- Duygusal farkındalık hedefinde "mutlu mu, üzgün mü, heyecanlı mı?" gibi basit duygu seçenekleri kullan.
- Problem çözme hedefinde gerçek problem değil, basit günlük durum kullan.
- "Ben bunu seviyorum, sen de seviyor musun?" kalıbını sürekli kullanma.
- Sürekli merhaba deme.
- Parantez, sahne tarifi, yıldızlı rol yapma yazma.

ÖRNEK UYGUN CEVAPLAR:
- Ay çok güzel görünür. Sence Ay gece mi daha parlak görünür?
- Roketler uzaya gider. Sen bir roket çizsen ne renk yapardın?
- Köpekleri ben de çok severim. Sence köpekler mutlu olunca ne yapar?
- Anlamadıysan sorun değil. Daha kolay anlatalım.

ÖRNEK YASAK CEVAPLAR:
- Ay'ın yerçekimi azalırsa ne olur?
- Dünya'nın uydusu olduğu için...
- Suddenly...
- Şimdi bir problem düşünelim...
- Bunu analiz edelim...

GÜVENLİK:
- Çocuk şiddet, kavga, vurma, dövme, tehdit, zarar verme gibi bir şey söylerse bunu asla normalleştirme.
- Önce davranışın doğru olmadığını nazikçe söyle.
- Sonra çocuğa sakinleşmesini ve güvendiği bir yetişkine anlatmasını öner.
- Çocuk kendine zarar, başkasına zarar, istismar, korku veya tehlike içeren bir şey söylerse hemen güvendiği bir yetişkine, öğretmenine veya ailesine söylemesini öner.
`.trim();
}

function makeGroqMessages(context) {
  return [
    {
      role: "system",
      content: buildSystemPrompt(context),
    },
    ...chatHistory.map((m) => ({
      role: m.role,
      content: m.content,
    })),
  ];
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 15000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

app.post("/ask", async (req, res) => {
  try {
    const message = (req.body.message || "").trim();
    const profile = buildChildProfile(req.body || {});

    if (!GROQ_API_KEY) {
      return res.status(200).json({
        reply:
          "Şu an cevap sistemi hazır değil. Bir büyüğünden kontrol etmesini isteyelim mi?",
        error: "GROQ_API_KEY missing",
      });
    }

    if (!message) {
      return res.status(200).json({
        reply: "Bir şey duyamadım. İstersen tekrar söyleyebilirsin.",
      });
    }

    conversationState.turnCount += 1;
    conversationState.childSeemsInterested = childIsInterested(message);

    detectInterestFromMessage(message, profile);

    const interest = pickInterest(profile);
    const goal = pickGoal(profile);

    addToHistory("user", message);

    const response = await fetchWithTimeout(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${GROQ_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: makeGroqMessages({ profile, interest, goal }),
          temperature: 0.35,
          max_tokens: 90,
        }),
      },
      15000
    );

    const data = await response.json().catch(() => null);

    if (!response.ok) {
      console.log("GROQ ERROR:", response.status, data);

      return res.status(200).json({
        reply: "Biraz takıldım ama buradayım. Tekrar dener misin?",
        error: "Groq API failed",
        detail: data,
      });
    }

    const rawReply = data?.choices?.[0]?.message?.content || "";
    const reply = cleanReply(rawReply);

    addToHistory("assistant", reply);

    return res.json({
      reply,
      state: {
        interest,
        goal,
        turnCount: conversationState.turnCount,
        childSeemsInterested: conversationState.childSeemsInterested,
      },
    });
  } catch (err) {
    console.log("ASK SERVER ERROR:", err);

    const isTimeout =
      err?.name === "AbortError" ||
      String(err).toLowerCase().includes("timeout");

    return res.status(200).json({
      reply: isTimeout
        ? "Cevabım biraz gecikti. Tekrar dener misin?"
        : "Biraz takıldım ama buradayım. Tekrar söyleyebilir misin?",
      error: String(err),
    });
  }
});

app.post("/tts", async (req, res) => {
  try {
    const text = (req.body.text || "").trim();

    if (!ELEVENLABS_API_KEY) {
      return res.status(200).json({
        error: "ELEVENLABS_API_KEY missing",
        fallback: true,
      });
    }

    if (!ELEVENLABS_VOICE_ID) {
      return res.status(200).json({
        error: "ELEVENLABS_VOICE_ID missing",
        fallback: true,
      });
    }

    if (!text) {
      return res.status(200).json({
        error: "Empty text",
        fallback: true,
      });
    }

    const response = await fetchWithTimeout(
      `https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128`,
      {
        method: "POST",
        headers: {
          "xi-api-key": ELEVENLABS_API_KEY,
          "Content-Type": "application/json",
          Accept: "audio/mpeg",
        },
        body: JSON.stringify({
          text,
          model_id: "eleven_multilingual_v2",
          voice_settings: {
            stability: 0.55,
            similarity_boost: 0.75,
            style: 0.25,
            use_speaker_boost: true,
            speed: 0.85,
          },
        }),
      },
      12000
    );

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.log("ELEVENLABS TTS ERROR:", response.status, errText);

      return res.status(200).json({
        error: "ElevenLabs TTS failed",
        detail: errText,
        fallback: true,
      });
    }

    const audio = Buffer.from(await response.arrayBuffer());

    res.setHeader("Content-Type", "audio/mpeg");
    return res.send(audio);
  } catch (err) {
    console.log("TTS SERVER ERROR:", err);

    return res.status(200).json({
      error: String(err),
      fallback: true,
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({
    error: "Route not found",
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});