import "dotenv/config";
import express from "express";
import cors from "cors";
import fetch from "node-fetch";
import { GoogleGenAI } from "@google/genai";

const app = express();
app.use(cors());
app.use(express.json({ limit: "25mb" }));

const PORT = process.env.PORT || 3000;

const GROQ_API_KEY = process.env.GROQ_API_KEY;

// Sohbet için hızlı model
const GROQ_MODEL = "llama-3.1-8b-instant";

// Masal sonucu / ebeveyn analizi / duygu çemberi için güçlü model
const STORY_ANALYSIS_MODEL = "llama-3.3-70b-versatile";

const MALE_API_KEYS = [
  process.env.ELEVENLABS_API_KEY1,
  process.env.ELEVENLABS_API_KEY2,
  process.env.ELEVENLABS_API_KEY3,
].filter(Boolean);

const MALE_VOICE_IDS = [
  process.env.ELEVENLABS_VOICE_ID1,
  process.env.ELEVENLABS_VOICE_ID2,
  process.env.ELEVENLABS_VOICE_ID3,
].filter(Boolean);

const GIRL_API_KEYS = [
  process.env.ELEVENLABS_API_KEY4,
  process.env.ELEVENLABS_API_KEY5,
].filter(Boolean);

const GIRL_VOICE_IDS = [
  process.env.ELEVENLABS_VOICE_ID4,
  process.env.ELEVENLABS_VOICE_ID5,
].filter(Boolean);

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

const genAI = GEMINI_API_KEY
  ? new GoogleGenAI({ apiKey: GEMINI_API_KEY })
  : null;

const interactiveStoryResults = [];
const conversationLogs = [];

let latestInterestEmotionMap = null;
let interestEmotionMapUpdating = false;
let lastInterestMapUpdatedAt = null;

const KEEP_7_DAYS_MS = 7 * 24 * 60 * 60 * 1000;

function cleanText(value = "") {
  return String(value || "")
    .replace(/\s+/g, " ")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .trim();
}

function cleanupOldStoryResults() {
  const now = Date.now();

  for (let i = interactiveStoryResults.length - 1; i >= 0; i--) {
    const createdAtMs = new Date(
      interactiveStoryResults[i].createdAt || 0
    ).getTime();

    if (!createdAtMs || now - createdAtMs > KEEP_7_DAYS_MS) {
      interactiveStoryResults.splice(i, 1);
    }
  }
}

function cleanupOldConversationLogs() {
  const now = Date.now();

  for (let i = conversationLogs.length - 1; i >= 0; i--) {
    const createdAtMs = new Date(conversationLogs[i].createdAt || 0).getTime();

    if (!createdAtMs || now - createdAtMs > KEEP_7_DAYS_MS) {
      conversationLogs.splice(i, 1);
    }
  }
}

function saveConversationLog({
  nickname = "",
  personality = "",
  topic = "Genel",
  childText = "",
  avatarReply = "",
  interests = [],
  goals = [],
}) {
  cleanupOldConversationLogs();

  const log = {
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    nickname,
    childNickname: nickname,
    personality,
    topic,
    childText,
    message: childText,
    avatarReply,
    reply: avatarReply,
    interests,
    goals,
    createdAt: new Date().toISOString(),
  };

  conversationLogs.unshift(log);
  cleanupOldConversationLogs();

  return log;
}

/*
  DUYGU ÇEMBERİ FORMATİ

  Backend artık Türkiye haritası / bölge yapısı döndürmez.
  Yeni yapı:
  data.items = [
    {
      emotion: "mutlu",
      label: "Mutlu",
      percentage: 35,
      topics: ["oyun", "hayvanlar"]
    }
  ]

  Flutter tarafında PieChart / Doughnut Chart doğrudan data.items ile çizilecek.
*/

function getInterestEmotionFallbackData(reason = "fallback") {
  return {
    items: [
      {
        emotion: "mutlu",
        label: "Mutlu",
        percentage: 35,
        topics: ["oyun", "hayvanlar", "resim"],
      },
      {
        emotion: "meraklı",
        label: "Meraklı",
        percentage: 25,
        topics: ["uzay", "bilim", "masal"],
      },
      {
        emotion: "nötr",
        label: "Nötr",
        percentage: 15,
        topics: ["günlük sohbet", "rutin konuşmalar"],
      },
      {
        emotion: "kaygılı",
        label: "Kaygılı",
        percentage: 10,
        topics: ["okul", "yeni ortam", "ayrılma"],
      },
      {
        emotion: "üzgün",
        label: "Üzgün",
        percentage: 10,
        topics: ["arkadaşlar", "özlem", "aile"],
      },
      {
        emotion: "kızgın",
        label: "Kızgın",
        percentage: 5,
        topics: ["paylaşma", "oyuncak", "sınırlar"],
      },
    ],
    parentSummary:
      reason === "no_logs"
        ? "Henüz yeterli konuşma kaydı bulunmadığı için örnek duygu çemberi gösteriliyor. Çocuk sohbet ettikçe analiz otomatik güncellenir."
        : "Konuşmalardan ilgi ve duygu eğilimi çemberi oluşturuldu. Bu çıktı psikolojik tanı değildir.",
  };
}

function normalizeInterestTopics(value, fallbackTopics = []) {
  if (!Array.isArray(value)) return fallbackTopics;

  const cleaned = value
    .map((item) => cleanText(item))
    .filter(Boolean)
    .slice(0, 6);

  return cleaned.length > 0 ? cleaned : fallbackTopics;
}

function normalizePercentage(value, fallbackValue = 0) {
  const numberValue = Number(value);
  if (!Number.isFinite(numberValue)) return fallbackValue;
  return Math.max(0, Math.min(100, Math.round(numberValue)));
}

function sanitizeInterestEmotionMap(parsed) {
  const fallback = getInterestEmotionFallbackData();

  const emotionList = [
    { emotion: "mutlu", label: "Mutlu" },
    { emotion: "meraklı", label: "Meraklı" },
    { emotion: "nötr", label: "Nötr" },
    { emotion: "kaygılı", label: "Kaygılı" },
    { emotion: "üzgün", label: "Üzgün" },
    { emotion: "kızgın", label: "Kızgın" },
  ];

  const parsedItems = Array.isArray(parsed?.items) ? parsed.items : [];

  const items = emotionList.map((base, index) => {
    const found = parsedItems.find((item) => {
      return cleanText(item?.emotion).toLowerCase() === base.emotion;
    });

    return {
      emotion: base.emotion,
      label: base.label,
      percentage: normalizePercentage(
        found?.percentage,
        fallback.items[index]?.percentage || 0
      ),
      topics: normalizeInterestTopics(
        found?.topics,
        fallback.items[index]?.topics || ["genel sohbet"]
      ),
    };
  });

  const total = items.reduce((sum, item) => sum + item.percentage, 0);

  if (total <= 0) {
    return fallback;
  }

  let normalizedTotal = 0;

  items.forEach((item, index) => {
    if (index === items.length - 1) {
      item.percentage = Math.max(0, 100 - normalizedTotal);
    } else {
      const normalized = Math.round((item.percentage / total) * 100);
      item.percentage = normalized;
      normalizedTotal += normalized;
    }
  });

  return {
    items,
    parentSummary:
      cleanText(parsed?.parentSummary) ||
      "Konuşmalardan ilgi ve duygu eğilimi çemberi oluşturuldu. Bu çıktı psikolojik tanı değildir.",
  };
}

function filterConversationLogsByPeriod(period = "daily") {
  cleanupOldConversationLogs();

  const now = Date.now();
  const normalizedPeriod = cleanText(period).toLowerCase();

  let rangeMs = 24 * 60 * 60 * 1000;

  if (normalizedPeriod === "weekly") {
    rangeMs = 7 * 24 * 60 * 60 * 1000;
  } else if (normalizedPeriod === "monthly") {
    rangeMs = 30 * 24 * 60 * 60 * 1000;
  }

  return conversationLogs
    .filter((item) => {
      const createdAtMs = new Date(item.createdAt || 0).getTime();
      if (!createdAtMs) return false;
      return now - createdAtMs <= rangeMs;
    })
    .slice(0, 300);
}

async function generateInterestEmotionMap(period = "daily") {
  const logs = filterConversationLogsByPeriod(period);

  if (logs.length === 0) {
    return {
      success: true,
      period,
      model: "fallback_no_logs",
      logCount: 0,
      generatedAt: new Date().toISOString(),
      data: getInterestEmotionFallbackData("no_logs"),
    };
  }

  const conversationText = logs
    .map((e, index) => {
      return `${index + 1}. Çocuk: ${cleanText(e.childText || e.message || "")}
Avatar: ${cleanText(e.avatarReply || e.reply || "")}
Konu: ${cleanText(e.topic || "Genel")}
İlgi alanları: ${
        Array.isArray(e.interests) ? e.interests.map(cleanText).join(", ") : ""
      }
Tarih: ${cleanText(e.createdAt || "")}`;
    })
    .join("\n\n");

  const prompt = `
Sen KiddoAI ebeveyn paneli için ilgi ve duygu çemberi oluşturan güvenli analiz sistemisin.

KURALLAR:
- Psikolojik tanı koyma.
- Klinik ifade kullanma.
- "Depresyon", "anksiyete", "travma", "bozukluk" gibi tanı dili kullanma.
- Sadece konuşma eğilimi ve ilgi alanı gözlemi yap.
- Cevap SADECE geçerli JSON olsun.
- Markdown, açıklama, kod bloğu yazma.
- Yüzdelerin toplamı yaklaşık 100 olsun.
- Her duygu için topics listesi dolu olsun.
- Topics çocuk konuşmalarından çıkarılan kısa ilgi alanları olsun.
- Bu çıktı ebeveyn panelinde pasta/çember grafik olarak gösterilecek.
- Duygu isimleri aşağıdaki sabit değerlerden farklı olmasın.

Duygular sabit:
mutlu
meraklı
nötr
kaygılı
üzgün
kızgın

JSON ŞEMASI:
{
  "items": [
    {
      "emotion": "mutlu",
      "percentage": 0,
      "topics": []
    },
    {
      "emotion": "meraklı",
      "percentage": 0,
      "topics": []
    },
    {
      "emotion": "nötr",
      "percentage": 0,
      "topics": []
    },
    {
      "emotion": "kaygılı",
      "percentage": 0,
      "topics": []
    },
    {
      "emotion": "üzgün",
      "percentage": 0,
      "topics": []
    },
    {
      "emotion": "kızgın",
      "percentage": 0,
      "topics": []
    }
  ],
  "parentSummary": ""
}

Analiz dönemi: ${period}

Konuşmalar:
${conversationText}
`.trim();

  try {
    const content = await callGroqChatCompletion({
      model: STORY_ANALYSIS_MODEL,
      messages: [
        {
          role: "system",
          content:
            "Sadece geçerli JSON döndür. Markdown, açıklama veya kod bloğu yazma.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.1,
      top_p: 0.7,
      max_tokens: 900,
    });

    console.log("INTEREST EMOTION CIRCLE RAW MODEL OUTPUT:", content);

    const parsed = extractJsonObject(content);
    const safeData = sanitizeInterestEmotionMap(parsed);

    return {
      success: true,
      period,
      model: STORY_ANALYSIS_MODEL,
      logCount: logs.length,
      generatedAt: new Date().toISOString(),
      data: safeData,
    };
  } catch (error) {
    console.error("BACKGROUND INTEREST EMOTION CIRCLE ERROR:", error.message);

    return {
      success: true,
      period,
      model: "fallback_after_model_error",
      logCount: logs.length,
      generatedAt: new Date().toISOString(),
      data: getInterestEmotionFallbackData("model_error"),
    };
  }
}

function updateInterestEmotionMapInBackground(period = "daily") {
  if (interestEmotionMapUpdating) {
    console.log("Interest emotion circle zaten güncelleniyor.");
    return;
  }

  interestEmotionMapUpdating = true;

  generateInterestEmotionMap(period)
    .then((result) => {
      latestInterestEmotionMap = result;
      lastInterestMapUpdatedAt = new Date().toISOString();
      console.log("Interest emotion circle arka planda güncellendi.");
    })
    .catch((error) => {
      console.error("Interest emotion circle background fatal error:", error);
    })
    .finally(() => {
      interestEmotionMapUpdating = false;
    });
}
function shortenText(text = "", maxLength = 360) {
  const clean = cleanText(text);
  if (clean.length <= maxLength) return clean;
  return clean.slice(0, maxLength).split(" ").slice(0, -1).join(" ").trim();
}

function normalizeHistory(history = []) {
  if (!Array.isArray(history)) return [];

  return history
    .map((item) => {
      const role = cleanText(item.role || item.type || "");
      const text = cleanText(item.text || item.message || item.content || "");
      if (!text) return null;

      if (role === "child" || role === "user") {
        return { role: "child", text: shortenText(text, 220) };
      }

      if (role === "assistant" || role === "avatar") {
        return { role: "assistant", text: shortenText(text, 220) };
      }

      return null;
    })
    .filter(Boolean)
    .slice(-6);
}

function getLastContext(history = []) {
  const cleanHistory = normalizeHistory(history);
  if (cleanHistory.length === 0) return "Önceki konuşma yok.";

  return cleanHistory
    .map((item) =>
      item.role === "child"
        ? `Çocuk: ${item.text}`
        : `Avatar: ${item.text}`
    )
    .join("\n");
}

function getInterestTopic(interests = []) {
  if (!Array.isArray(interests) || interests.length === 0) return "";

  const clean = interests.map((i) => cleanText(i)).filter(Boolean);
  return clean[0] || "";
}

function interestFollowUp(interests = []) {
  const interest = getInterestTopic(interests);
  const lower = interest.toLowerCase();

  if (!interest) return "Bugün seni en çok ne mutlu etti?";
  if (lower.includes("uzay")) return "Uzayda en çok neyi merak ediyorsun?";
  if (lower.includes("hayvan")) return "En sevdiğin hayvan hangisi?";
  if (lower.includes("araç") || lower.includes("araba")) {
    return "En çok hangi aracı seviyorsun?";
  }
  if (lower.includes("masal")) return "Bugün nasıl bir masal hayal edelim?";
  if (lower.includes("çizim") || lower.includes("resim")) {
    return "Bugün ne çizmek istersin?";
  }
  if (lower.includes("müzik")) return "En sevdiğin şarkı hangisi?";
  if (lower.includes("doğa")) return "Doğada en çok neyi seversin?";
  if (lower.includes("bilim")) return "Bugün hangi şeyi merak ettin?";
  if (lower.includes("oyun")) return "Bugün hangi oyunu oynamak istersin?";

  return `${interest} hakkında en çok neyi seviyorsun?`;
}

function detectTopicFromText(text = "", fallbackTopic = "Genel") {
  const msg = cleanText(text).toLowerCase();

  if (msg.includes("oyun") || msg.includes("oynadım") || msg.includes("oynayalım")) return "Oyun";
  if (msg.includes("nasılsın") || msg.includes("iyiyim") || msg.includes("mutlu") || msg.includes("üzgün") || msg.includes("kork") || msg.includes("duygu")) return "Duygular";
  if (msg.includes("anne") || msg.includes("annem") || msg.includes("baba") || msg.includes("babam") || msg.includes("ailem") || msg.includes("kızdı")) return "Aile";
  if (msg.includes("kuş") || msg.includes("balık") || msg.includes("kedi") || msg.includes("köpek") || msg.includes("hayvan")) return "Hayvanlar";
  if (msg.includes("araba") || msg.includes("uçak") || msg.includes("tren") || msg.includes("araç")) return "Araçlar";
  if (msg.includes("uzay") || msg.includes("ay") || msg.includes("güneş") || msg.includes("yıldız")) return "Uzay";
  if (msg.includes("renk") || msg.includes("kırmızı") || msg.includes("mavi") || msg.includes("sarı") || msg.includes("yeşil")) return "Renkler";
  if (msg.includes("çiz") || msg.includes("resim") || msg.includes("boya") || msg.includes("boyama")) return "Sanat";

  return cleanText(fallbackTopic || "Genel");
}

function directReplyIfNeeded(childText = "", interests = []) {
  const msg = cleanText(childText).toLowerCase();

  if (
    msg.includes("çok mutluyum") ||
    msg.includes("mutluyum") ||
    msg.includes("neşeliyim") ||
    msg.includes("sevinçliyim") ||
    msg.includes("keyfim iyi")
  ) {
    return "Buna çok sevindim. Bugün seni ne mutlu etti?";
  }

  if (
    msg.includes("çok heyecanlıyım") ||
    msg.includes("heyecanlıyım") ||
    msg.includes("sabırsızlanıyorum")
  ) {
    return "Ne güzel, heyecanını hissettim. Seni ne heyecanlandırdı?";
  }

  if (
    msg.includes("merak ettim") ||
    msg.includes("merak ediyorum") ||
    msg.includes("çok meraklıyım")
  ) {
    return "Merak etmek çok güzel. En çok neyi öğrenmek istiyorsun?";
  }

  if (
    msg.includes("üzgünüm") ||
    msg.includes("çok üzgünüm") ||
    msg.includes("mutsuzum") ||
    msg.includes("ağladım") ||
    msg.includes("canım sıkıldı")
  ) {
    return "Buna üzüldüm. İstersen bana ne olduğunu anlatabilirsin.";
  }

  if (
    msg.includes("korktum") ||
    msg.includes("korkuyorum") ||
    msg.includes("çok korktum")
  ) {
    return "Korkman çok normal. İstersen birlikte sakin sakin konuşalım.";
  }

  if (
    msg.includes("kızgınım") ||
    msg.includes("sinirlendim") ||
    msg.includes("çok sinirlendim")
  ) {
    return "Kızgın hissetmen normal. Sana ne olduğunu anlatmak ister misin?";
  }

  if (
    msg.includes("sıkıldım") ||
    msg.includes("canım sıkılıyor")
  ) {
    return `Sıkılınca birlikte yeni bir şey düşünebiliriz. ${interestFollowUp(interests)}`;
  }

  if (
    msg.includes("iyiyim") &&
    (msg.includes("sen nasılsın") || msg.includes("nasılsın"))
  ) {
    return `Ben de iyiyim, teşekkür ederim. ${interestFollowUp(interests)}`;
  }

  if (msg === "iyiyim" || msg.includes("ben iyiyim")) {
    return `Buna çok sevindim. ${interestFollowUp(interests)}`;
  }

  if (msg.includes("nasılsın")) {
    return `Ben iyiyim, teşekkür ederim. ${interestFollowUp(interests)}`;
  }

  return "";
}

function buildSystemPrompt({
  nickname = "",
  personality = "",
  interests = [],
  goals = [],
  topic = "Genel",
  history = [],
}) {
  const nameLine = nickname ? `Çocuğun adı: ${nickname}.` : "";
  const personalityLine = personality ? `Avatar kişiliği: ${personality}.` : "";

  const interestsLine =
    Array.isArray(interests) && interests.length > 0
      ? `Çocuğun ilgi alanları: ${interests.map(cleanText).join(", ")}.`
      : "Çocuğun ilgi alanı belirtilmedi.";

  const goalsLine =
    Array.isArray(goals) && goals.length > 0
      ? `Çocuğun gelişim hedefleri: ${goals.map(cleanText).join(", ")}.`
      : "Gelişim hedefi belirtilmedi.";

  const lastContext = getLastContext(history);

  return `
Sen KiddoAI içinde 4-6 yaş arası çocuklarla konuşan sıcak, güvenli ve doğal bir erkek avatarsın.

KİMLİK:
- Sen çocuğun oyun arkadaşı gibi konuşursun.
- Öğretmen gibi uzun ders anlatmazsın.
- Robot, yapay zeka, model, asistan veya sistem olduğunu söylemezsin.
- Sadece avatarın çocuğa söyleyeceği metni yazarsın.
DİL:
- Çocukla gerçek bir arkadaş gibi konuş.
- Sürekli soru sorma.
- Bazı cevaplarda sadece yorum yapabilir veya kendi fikrini paylaşabilirsin.
- Çocuğun son söylediği şeydeki ayrıntıyı yakala ve onun üzerinden konuş.
- Genel cevaplar verme.
- "Ne güzel", "Buna sevindim", "İstersen" kalıplarını sürekli tekrar etme.
- Aynı soru biçimini tekrar tekrar kullanma.
- Çocuk bir hayvan söylerse o hayvan hakkında konuş.
- Çocuk bir oyun söylerse o oyun hakkında konuş.
- Çocuk bir olay anlatırsa önce olaya tepki ver, sonra devam ettir.
- Konuşma doğal ilerlesin, röportaj gibi peş peşe soru sorma.
- Gerekiyorsa hiç soru sormadan kısa bir yorum yapabilirsin.
- Çocukla daha önce konuşulan konular uzun süre devam ettiyse doğal şekilde yeni bir konuya geçebilirsin.
- Konu değiştirirken çocuğun ilgi alanlarını kullan.
- Çocuk kısa cevap verirse ("evet", "hayır", "çok", "bilmiyorum") konuşmayı devam ettirmeye çalış.

GÜNCEL KONU:
${topic}

ÖNCEKİ KONUŞMA:
${lastContext}

${nameLine}
${personalityLine}
${interestsLine}
${goalsLine}

Cevabın sadece konuşma metni olsun.
`.trim();
}

function hasForeignLanguage(text = "") {
  const lower = ` ${text.toLowerCase()} `;
  const foreignWords = [
    " the ",
    " and ",
    " because ",
    " hello ",
    " sorry ",
    " you ",
    " are ",
    " ich ",
    " und ",
    " das ",
    " bonjour ",
    " merci ",
    " gracias ",
    " yes ",
    " no ",
    " okay ",
  ];

  return foreignWords.some((word) => lower.includes(word));
}

function hasBadMetaText(text = "") {
  const lower = text.toLowerCase();

  const badParts = [
    "ben bir asistanım",
    "yapay zeka",
    "ai modeli",
    "language model",
    "dil modeli",
    "prompt",
    "system",
    "developer",
    "groq",
    "qwen",
    "gemma",
    "konu:",
    "çocuk:",
    "avatar:",
    "assistant:",
    "user:",
    "uygun cevap",
    "düzeltilmiş cevap",
    "son cevap",
    "analiz",
    "madde",
  ];

  return badParts.some((part) => lower.includes(part));
}

function hasAppearanceCompliment(text = "") {
  const lower = cleanText(text).toLowerCase();

  const badCompliments = [
    "çok güzelsin",
    "güzelsin",
    "yakışıklısın",
    "çok yakışıklısın",
    "çok tatlısın",
    "tatlısın",
    "şirinsin",
    "çok şirinsin",
  ];

  return badCompliments.some((part) => lower.includes(part));
}

function isTooLong(text = "") {
  const clean = cleanText(text);
  const sentenceCount = clean.split(/[.!?]+/).filter(Boolean).length;
  return clean.length > 190 || sentenceCount > 2;
}

function hasUnsafeOrWrongTone(childText = "", reply = "") {
  const combined = `${childText} ${reply}`.toLowerCase();
  const answer = cleanText(reply).toLowerCase();

  const riskyWords = [
    "öldür",
    "öldürdüm",
    "vur",
    "vurdum",
    "döv",
    "dövdüm",
    "silah",
    "bıçak",
    "kan",
    "ölüm",
    "nefret",
    "aptal",
    "salak",
    "gerizekalı",
    "asistanım",
    "yapay zeka",
    "prompt",
    "system",
    "developer",
  ];

  const blamingPhrases = [
    "sen yanlış yaptın",
    "yanlış yaptın",
    "hata yaptın",
    "bu senin suçun",
    "kötü çocuksun",
  ];

  if (riskyWords.some((word) => combined.includes(word))) return true;
  if (blamingPhrases.some((word) => answer.includes(word))) return true;

  return false;
}

function hasWrongApproval(childText = "", reply = "") {
  const child = cleanText(childText).toLowerCase();
  const answer = cleanText(reply).toLowerCase();

  const approving =
    answer.startsWith("evet") ||
    answer.includes("doğru") ||
    answer.includes("haklısın") ||
    answer.includes("aynen");

  if (!approving) return false;

  if (child.includes("balık") && child.includes("uçar")) return true;
  if (child.includes("kuş") && child.includes("suda yaşar")) return true;
  if (child.includes("güneş mavi") || child.includes("güneş yeşil")) return true;
  if (child.includes("çimen kırmızı") || child.includes("çimen mavi")) return true;
  if (child.includes("annem kötü") || child.includes("babam kötü")) return true;

  return false;
}

function safeFallback(childText = "", interests = []) {
  const msg = cleanText(childText).toLowerCase();

  if (msg.includes("bilmec") || msg.includes("bilmece")) {
    return "Bence cevabı dikkatlice düşünmeliyiz. Bana bilmecenin tamamını tekrar söyler misin?";
  }

  if (msg.includes("iyiyim") || msg.includes("nasılsın")) {
    return `Ben de iyiyim, teşekkür ederim. ${interestFollowUp(interests)}`;
  }

  if (msg.includes("kuş") && msg.includes("balık")) {
    return "Kuş genelde uçar, balık ise suda yaşar. Sence balık nerede yüzer?";
  }

  if (msg.includes("araba") && msg.includes("uçak")) {
    return "Araba yolda gider, uçak gökyüzünde uçar. Sen hangisine binmek isterdin?";
  }

  if (msg.includes("merhaba") || msg.includes("selam")) {
    return `Merhaba, seni görmek güzel. ${interestFollowUp(interests)}`;
  }

  if (msg.includes("kork")) {
    return "Korkman çok normal. Ben buradayım, birlikte sakin bir nefes alalım.";
  }

  if (msg.includes("üzgün") || msg.includes("ağladım") || msg.includes("mutsuz")) {
    return "Üzgün hissetmen normal. İstersen bana ne olduğunu anlatabilirsin.";
  }

  if (msg.includes("annem") || msg.includes("babam") || msg.includes("kızdı")) {
    return "Buna üzülmüş olabilirsin. İstersen bana ne olduğunu anlatabilirsin.";
  }

  if (msg.includes("oyun") || msg.includes("oynadım") || msg.includes("oynayalım")) {
    return "Ne güzel, oyun oynamak eğlenceli. Hangi oyunu oynadın?";
  }

  if (msg.includes("çiz") || msg.includes("resim") || msg.includes("boyama")) {
    return "Resim yapmak çok güzel. Bugün ne çizmek istersin?";
  }

  return `Seni dinliyorum. ${interestFollowUp(interests)}`;
}

function finalCleanAnswer(childText = "", answer = "", interests = []) {
  let clean = cleanText(answer);

  clean = clean
    .replace(/^avatar\s*:/i, "")
    .replace(/^cevap\s*:/i, "")
    .replace(/^assistant\s*:/i, "")
    .replace(/^son cevap\s*:/i, "")
    .replace(/^düzeltilmiş cevap\s*:/i, "")
    .replace(/^kiddoai\s*:/i, "")
    .trim();

  clean = clean.replace(/["“”]/g, "").trim();

  const sentences = clean.split(/(?<=[.!?])\s+/).filter(Boolean);
  if (sentences.length > 2) clean = sentences.slice(0, 2).join(" ");

  clean = shortenText(clean, 190);

  if (
    !clean ||
    hasForeignLanguage(clean) ||
    hasBadMetaText(clean) ||
    hasAppearanceCompliment(clean) ||
    isTooLong(clean) ||
    hasUnsafeOrWrongTone(childText, clean) ||
    hasWrongApproval(childText, clean)
  ) {
    return safeFallback(childText, interests);
  }

  return clean;
}

async function callGroqChatCompletion({
  model,
  messages,
  temperature = 0.2,
  top_p = 0.8,
  max_tokens = 300,
}) {
  if (!GROQ_API_KEY) {
    throw new Error("GROQ_API_KEY eksik. .env dosyasına ekle.");
  }

  const response = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages,
        temperature,
        top_p,
        max_tokens,
      }),
    }
  );

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Groq API hatası: ${errText}`);
  }

  const data = await response.json();
  const content = cleanText(data?.choices?.[0]?.message?.content || "");

  if (!content) throw new Error("Groq boş cevap döndürdü.");

  return content;
}

async function getGroqReply({ finalChildText, systemPrompt, cleanHistory }) {
  const messages = [{ role: "system", content: systemPrompt }];

  for (const item of cleanHistory.slice(-4)) {
    messages.push({
      role: item.role === "child" ? "user" : "assistant",
      content: item.text,
    });
  }

  messages.push({
    role: "user",
    content: `Çocuğun son mesajı: "${finalChildText}"

Bu mesaja doğrudan cevap ver. Sadece Türkçe yaz. En fazla 2 kısa cümle olsun. Mantıklı, doğal, güvenli ve okul öncesi çocuğa uygun cevap ver.`,
  });

  return callGroqChatCompletion({
    model: GROQ_MODEL,
    messages,
    temperature: 0.12,
    top_p: 0.65,
    max_tokens: 70,
  });
}

function extractJsonObject(text = "") {
  const clean = String(text || "").trim();

  try {
    return JSON.parse(clean);
  } catch (_) {}

  const first = clean.indexOf("{");
  const last = clean.lastIndexOf("}");

  if (first === -1 || last === -1 || last <= first) {
    throw new Error("Model JSON formatında cevap döndürmedi.");
  }

  const jsonText = clean.slice(first, last + 1);
  return JSON.parse(jsonText);
}

function clampScore(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return 0;
  return Math.max(0, Math.min(10, Math.round(num)));
}

function safeStoryAnalysisFallback({
  dominantArea = "",
  emotionalMeaning = "",
  developmentComment = "",
  parentSuggestion = "",
}) {
  return {
    aiDominantArea:
      cleanText(dominantArea) || "Masal seçimlerine dayalı genel gözlem",
    aiEmotionalObservation:
      cleanText(emotionalMeaning) ||
      "Çocuğun seçimleri sosyal-duygusal gelişim açısından gözlem niteliği taşır.",
    aiDevelopmentComment:
      cleanText(developmentComment) ||
      "Bu çıktı psikolojik tanı değildir; yalnızca uygulama içindeki seçim davranışlarını yorumlar.",
    aiParentSuggestion:
      cleanText(parentSuggestion) ||
      "Ebeveyn, çocuğun seçimlerini günlük konuşmalarda nazikçe pekiştirebilir.",
    aiShortSummary:
      "Masal sonucu başarıyla kaydedildi. Yapay zeka analizi yerine güvenli varsayılan gözlem kullanıldı.",
    helpingScore: 0,
    socialScore: 0,
    cautiousScore: 0,
  };
}

async function generateInteractiveStoryAiAnalysis({
  childNickname = "",
  personality = "",
  avatarName = "",
  storyTitle = "",
  storyMessage = "",
  selectedChoice = "",
  dominantArea = "",
  emotionalMeaning = "",
  developmentComment = "",
  parentSuggestion = "",
  rawScores = null,
  aiPromptData = null,
}) {
  const safeName = cleanText(childNickname) || "Çocuk";

  const prompt = `
Sen KiddoAI ebeveyn paneli için interaktif masal sonucu yorumlayan güvenli bir analiz sistemisin.

ÇOK ÖNEMLİ KURALLAR:
- Psikolojik tanı koyma.
- "Depresyon", "anksiyete bozukluğu", "travma", "kişilik problemi" gibi klinik ifadeler kullanma.
- Çocuğu etiketleme.
- Sadece masal içindeki seçim davranışlarından gelişimsel gözlem üret.
- Dil sade, ebeveynin anlayacağı şekilde ve Türkçe olsun.
- Cevap sadece JSON olsun. Markdown yazma.

Kullanılacak JSON şeması:
{
  "aiDominantArea": "",
  "aiEmotionalObservation": "",
  "aiDevelopmentComment": "",
  "aiParentSuggestion": "",
  "aiShortSummary": "",
  "helpingScore": 0,
  "socialScore": 0,
  "cautiousScore": 0
}

Puanlar 0-10 arasında olmalı.

VERİ:
Çocuk adı: ${safeName}
Avatar: ${cleanText(avatarName)}
Kişilik: ${cleanText(personality)}
Masal adı: ${cleanText(storyTitle)}
Masal sonucu: ${cleanText(storyMessage)}
Puan özeti: ${cleanText(selectedChoice)}

Mevcut kural tabanlı gözlem:
Baskın alan: ${cleanText(dominantArea)}
Duygusal gözlem: ${cleanText(emotionalMeaning)}
Gelişimsel yorum: ${cleanText(developmentComment)}
Ebeveyn önerisi: ${cleanText(parentSuggestion)}

Ham skorlar:
${JSON.stringify(rawScores || {}, null, 2)}

Ek analiz verisi:
${JSON.stringify(aiPromptData || {}, null, 2)}
`.trim();

  try {
    const content = await callGroqChatCompletion({
      model: STORY_ANALYSIS_MODEL,
      messages: [
        {
          role: "system",
          content:
            "Sen sadece geçerli JSON döndüren, güvenli çocuk gelişimi gözlem sistemi gibi davranırsın.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.18,
      top_p: 0.75,
      max_tokens: 650,
    });

    const parsed = extractJsonObject(content);

    return {
      aiDominantArea:
        cleanText(parsed.aiDominantArea) ||
        cleanText(dominantArea) ||
        "Masal seçimlerine dayalı genel gözlem",
      aiEmotionalObservation:
        cleanText(parsed.aiEmotionalObservation) ||
        cleanText(emotionalMeaning) ||
        "Çocuğun seçimleri sosyal-duygusal gelişim açısından gözlem niteliği taşır.",
      aiDevelopmentComment:
        cleanText(parsed.aiDevelopmentComment) ||
        cleanText(developmentComment) ||
        "Bu çıktı psikolojik tanı değildir; yalnızca masal içindeki seçimleri yorumlar.",
      aiParentSuggestion:
        cleanText(parsed.aiParentSuggestion) ||
        cleanText(parentSuggestion) ||
        "Çocuğun olumlu seçimleri günlük hayatta fark edilip pekiştirilebilir.",
      aiShortSummary:
        cleanText(parsed.aiShortSummary) ||
        `${safeName}, '${storyTitle}' masalını tamamladı. Seçimleri gelişimsel gözlem niteliğinde değerlendirildi.`,
      helpingScore: clampScore(parsed.helpingScore),
      socialScore: clampScore(parsed.socialScore),
      cautiousScore: clampScore(parsed.cautiousScore),
    };
  } catch (error) {
    console.error("STORY AI ANALYSIS ERROR:", error.message);

    return safeStoryAnalysisFallback({
      dominantArea,
      emotionalMeaning,
      developmentComment,
      parentSuggestion,
    });
  }
}

async function handleChatLikeRequest(req, res, sourceEndpoint = "/chat") {
  const start = Date.now();

  try {
    const {
      topic = "Genel",
      childText = "",
      message = "",
      history = [],
      interests = [],
      goals = [],
      nickname = "",
      childNickname = "",
      personality = "",
    } = req.body;

    const finalNickname = cleanText(nickname || childNickname);
    const finalChildText = cleanText(childText || message);

    if (!finalChildText) {
      return res.status(400).json({
        success: false,
        error: "childText/message boş olamaz.",
        reply: "Seni duyamadım. Bir daha söyler misin?",
        text: "Seni duyamadım. Bir daha söyler misin?",
      });
    }

    const detectedTopic = detectTopicFromText(finalChildText, topic);
    const cleanHistory = normalizeHistory(history);

    const directReply = directReplyIfNeeded(finalChildText, interests);

    let firstModelReply = directReply;

    if (!firstModelReply) {
      const systemPrompt = buildSystemPrompt({
        nickname: finalNickname,
        personality,
        interests,
        goals,
        topic: detectedTopic,
        history: cleanHistory,
      });

      firstModelReply = await getGroqReply({
        finalChildText,
        systemPrompt,
        cleanHistory,
      });
    }

    const finalReply = finalCleanAnswer(
      finalChildText,
      firstModelReply,
      interests
    );

    const savedLog = saveConversationLog({
      nickname: finalNickname,
      personality,
      topic: detectedTopic,
      childText: finalChildText,
      avatarReply: finalReply,
      interests,
      goals,
    });
    updateInterestEmotionMapInBackground("daily");

    const totalMs = Date.now() - start;

    res.json({
      success: true,
      ok: true,
      interestEmotionMapEndpointEnabled: true,
      topic: detectedTopic,
      reply: finalReply,
      text: finalReply,
      firstModelReply,
      originalReply: firstModelReply,
      model: directReply ? "direct_safe_rule" : GROQ_MODEL,
      guardUsed: finalReply !== firstModelReply,
      guardChanged: finalReply !== firstModelReply,
      conversationSaved: true,
      savedLog,
      sourceEndpoint,
      state: {
        interest:
          Array.isArray(interests) && interests.length > 0
            ? interests[0]
            : detectedTopic,
        goal:
          Array.isArray(goals) && goals.length > 0 ? goals[0] : "",
        childSeemsInterested: true,
      },
      guardDecision:
        finalReply !== firstModelReply
          ? "cevap_temizlendi_veya_fallback_kullanildi"
          : "tek_model_net_cevap",
      totalLatencySeconds: Number((totalMs / 1000).toFixed(2)),
    });
  } catch (error) {
    console.error("CHAT/ASK ERROR:", error);

    res.status(500).json({
      success: false,
      ok: false,
      error: "Sunucu hatası",
      details: error.message,
      reply: "Biraz takıldım. Bana tekrar söyler misin?",
      text: "Biraz takıldım. Bana tekrar söyler misin?",
    });
  }
}

app.post("/chat", async (req, res) => {
  return handleChatLikeRequest(req, res, "/chat");
});

app.post("/ask", async (req, res) => {
  return handleChatLikeRequest(req, res, "/ask");
});

app.post("/reset-chat", (_req, res) => {
  cleanupOldConversationLogs();

  res.json({
    success: true,
    ok: true,
    message:
      "Sohbet sıfırlandı. Panel kayıtları 7 gün kuralına göre tutulmaya devam eder.",
  });
});

app.post("/conversation-log", (req, res) => {
  try {
    const {
      nickname = "",
      childNickname = "",
      personality = "",
      topic = "Genel",
      childText = "",
      message = "",
      avatarReply = "",
      reply = "",
      interests = [],
      goals = [],
    } = req.body;

    const finalChildText = cleanText(childText || message);
    const finalReply = cleanText(avatarReply || reply);

    if (!finalChildText && !finalReply) {
      return res.status(400).json({
        success: false,
        error: "childText/message veya avatarReply/reply gönderilmelidir.",
      });
    }

    const savedLog = saveConversationLog({
      nickname: cleanText(nickname || childNickname),
      personality,
      topic,
      childText: finalChildText,
      avatarReply: finalReply,
      interests,
      goals,
    });
    updateInterestEmotionMapInBackground("daily");

    res.json({
      success: true,
      message: "Konuşma kaydı panele eklendi.",
      result: savedLog,
    });
  } catch (error) {
    console.error("CONVERSATION LOG SAVE ERROR:", error);

    res.status(500).json({
      success: false,
      error: "Konuşma kaydı eklenemedi.",
      details: error.message,
    });
  }
});

app.get("/conversation-logs", (_req, res) => {
  cleanupOldConversationLogs();

  res.json({
    success: true,
    keepDays: 7,
    count: conversationLogs.length,
    results: conversationLogs,
  });
});

app.get("/conversation-logs/:nickname", (req, res) => {
  cleanupOldConversationLogs();

  const nickname = req.params.nickname.toLowerCase();

  const filtered = conversationLogs.filter((item) => {
    return (
      (item.nickname || "").toLowerCase() === nickname ||
      (item.childNickname || "").toLowerCase() === nickname
    );
  });

  res.json({
    success: true,
    keepDays: 7,
    count: filtered.length,
    results: filtered,
  });
});

app.get("/parent-panel/conversation-logs", (_req, res) => {
  cleanupOldConversationLogs();

  res.json({
    success: true,
    keepDays: 7,
    count: conversationLogs.length,
    results: conversationLogs,
  });
});

app.get("/parent-panel/conversation-logs/:nickname", (req, res) => {
  cleanupOldConversationLogs();

  const nickname = req.params.nickname.toLowerCase();

  const filtered = conversationLogs.filter((item) => {
    return (
      (item.nickname || "").toLowerCase() === nickname ||
      (item.childNickname || "").toLowerCase() === nickname
    );
  });

  res.json({
    success: true,
    keepDays: 7,
    count: filtered.length,
    results: filtered,
  });
});

app.post("/vision-room-check", async (req, res) => {
  try {
    const {
      imageBase64 = "",
      mimeType = "image/jpeg",
      question = "",
      focus = "",
      childAnswer = "",
      expectedObjects = [],
      alreadyFound = [],
      missingObjects = [],
      wrongObjects = [],
      instruction = "",
      helpMode = "",
    } = req.body;

    if (!GEMINI_API_KEY || !genAI) {
      return res.status(500).json({
        success: false,
        error: "GEMINI_API_KEY eksik. .env dosyasına ekle.",
      });
    }

    if (!imageBase64 || !question) {
      return res.status(400).json({
        success: false,
        error: "imageBase64 ve question zorunludur.",
      });
    }

    const prompt = `
Sen KiddoAI için 4-6 yaş çocuklara uygun görsel kontrol avatarsın.

Kurallar:
- Sadece Türkçe cevap ver.
- En fazla 2 kısa cümle yaz.
- Başlık, analiz, madde işareti yazma.
- Çocuğu kırmadan konuş.
- alreadyFound listesindeki nesneleri tekrar ipucu olarak verme.
- missingObjects listesindeki eksikler için yardım et.
- helpMode ipucu ise nesne adını direkt söyleme, konumunu/şeklini/rengini tarif et.
- helpMode reveal_answer ise sadece eksik kalan nesneleri söyle.
- wrongObjects içindekileri doğruymuş gibi onaylama.
- Yanlış nesne varsa nazikçe "onu görmedim" gibi söyle.

Soru:
${cleanText(question)}

Odak:
${cleanText(focus)}

Çocuğun cevabı:
${cleanText(childAnswer)}

Beklenen nesneler:
${JSON.stringify(expectedObjects)}

Bulunanlar:
${JSON.stringify(alreadyFound)}

Eksikler:
${JSON.stringify(missingObjects)}

Yanlış söylenenler:
${JSON.stringify(wrongObjects)}

Yardım modu:
${cleanText(helpMode)}

Ek talimat:
${cleanText(instruction)}

Sadece avatarın çocuğa söyleyeceği cevabı yaz.
`.trim();

    const response = await genAI.models.generateContent({
      model: "gemini-2.5-flash",
      contents: [
        {
          role: "user",
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType,
                data: imageBase64,
              },
            },
          ],
        },
      ],
    });

    const reply = finalCleanAnswer(childAnswer, response.text || "", []);

    res.json({
      success: true,
      reply:
        reply ||
        "Görsele baktım ama biraz karıştı. Sana küçük bir ipucu vereyim.",
    });
  } catch (error) {
    console.error("VISION ROOM CHECK ERROR:", error);

    res.status(500).json({
      success: false,
      error: "Görsel analiz hatası",
      details: error.message,
      reply:
        "Görseli incelerken biraz takıldım. Sana küçük bir ipucu vereyim.",
    });
  }
});

app.post("/tts", async (req, res) => {
  try {
    const { text = "", gender = "Erkek" } = req.body;
    const clean = cleanText(text);

    if (!clean) {
      return res.status(400).json({
        error: "text boş olamaz.",
      });
    }

    let apiKeys = [];
    let voiceIds = [];

    if (gender === "Kız") {
      apiKeys = GIRL_API_KEYS;
      voiceIds = GIRL_VOICE_IDS;
    } else {
      apiKeys = MALE_API_KEYS;
      voiceIds = MALE_VOICE_IDS;
    }

    if (apiKeys.length === 0) {
      return res.status(500).json({
        error: `ElevenLabs API key eksik. Gender: ${gender}`,
      });
    }

    if (voiceIds.length === 0) {
      return res.status(500).json({
        error: `ElevenLabs voice id eksik. Gender: ${gender}`,
      });
    }

    let lastErrorText = "";

    for (let i = 0; i < apiKeys.length; i++) {
      const apiKey = apiKeys[i];
      const voiceId = voiceIds[i] || voiceIds[0];

      try {
        const ttsResponse = await fetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
          {
            method: "POST",
            headers: {
              "xi-api-key": apiKey,
              "Content-Type": "application/json",
              Accept: "audio/mpeg",
            },
            body: JSON.stringify({
              text: clean,
              model_id: "eleven_multilingual_v2",
              language_code: "tr",
              apply_text_normalization: "on",
              voice_settings: {
                stability: 0.6,
                similarity_boost: 0.85,
                style: 0.08,
                use_speaker_boost: true,
                speed: 0.9,
              },
            }),
          }
        );

        if (ttsResponse.ok) {
          const audioBuffer = Buffer.from(await ttsResponse.arrayBuffer());

          console.log(
            `ElevenLabs TTS başarılı. Gender: ${gender}, key index: ${i}`
          );

          res.setHeader("Content-Type", "audio/mpeg");
          return res.send(audioBuffer);
        }

        lastErrorText = await ttsResponse.text();

        console.error(
          `ElevenLabs TTS ERROR. Gender: ${gender}, key index ${i}:`,
          lastErrorText
        );
      } catch (keyError) {
        lastErrorText = keyError.message;
        console.error(
          `ElevenLabs fetch error. Gender: ${gender}, key index ${i}:`,
          keyError
        );
      }
    }

    return res.status(500).json({
      error: "ElevenLabs TTS hatası. Tüm keyler denendi.",
      gender,
      details: lastErrorText,
    });
  } catch (error) {
    console.error("TTS ERROR:", error);

    res.status(500).json({
      error: "TTS sunucu hatası",
      details: error.message,
    });
  }
});

app.post("/interactive-story-result", async (req, res) => {
  try {
    cleanupOldStoryResults();

    const {
      type = "interactive_story_result",
      childNickname = "",
      personality = "",
      avatarName = "",
      storyId = "",
      storyTitle = "",
      storyMessage = "",
      selectedChoice = "",
      dominantArea = "",
      emotionalMeaning = "",
      developmentComment = "",
      parentSuggestion = "",
      parentPanelText = "",
      createdAt = "",
      useAiAnalysis = true,
      analysisModel = STORY_ANALYSIS_MODEL,
      analysisSource = "groq",
      rawScores = null,
      aiPromptData = null,
    } = req.body;

    if (!storyTitle || !selectedChoice) {
      return res.status(400).json({
        success: false,
        error: "storyTitle ve selectedChoice zorunludur.",
      });
    }

    let aiAnalysis = null;

    if (useAiAnalysis) {
      aiAnalysis = await generateInteractiveStoryAiAnalysis({
        childNickname,
        personality,
        avatarName,
        storyTitle,
        storyMessage,
        selectedChoice,
        dominantArea,
        emotionalMeaning,
        developmentComment,
        parentSuggestion,
        rawScores,
        aiPromptData,
      });
    }

    const finalDominantArea =
      aiAnalysis?.aiDominantArea || cleanText(dominantArea);
    const finalEmotionalMeaning =
      aiAnalysis?.aiEmotionalObservation || cleanText(emotionalMeaning);
    const finalDevelopmentComment =
      aiAnalysis?.aiDevelopmentComment || cleanText(developmentComment);
    const finalParentSuggestion =
      aiAnalysis?.aiParentSuggestion || cleanText(parentSuggestion);

    const result = {
      id: `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      type,
      childNickname,
      personality,
      avatarName,
      storyId,
      storyTitle,
      storyMessage,
      selectedChoice,

      analysisSource,
      analysisModel: useAiAnalysis ? analysisModel : "rule_based",
      aiAnalysisUsed: Boolean(aiAnalysis),
      aiDominantArea: aiAnalysis?.aiDominantArea || "",
      aiEmotionalObservation: aiAnalysis?.aiEmotionalObservation || "",
      aiDevelopmentComment: aiAnalysis?.aiDevelopmentComment || "",
      aiParentSuggestion: aiAnalysis?.aiParentSuggestion || "",
      aiShortSummary: aiAnalysis?.aiShortSummary || "",
      aiScores: {
        helpingScore: aiAnalysis?.helpingScore ?? null,
        socialScore: aiAnalysis?.socialScore ?? null,
        cautiousScore: aiAnalysis?.cautiousScore ?? null,
      },

      dominantArea: finalDominantArea,
      emotionalMeaning: finalEmotionalMeaning,
      developmentComment: finalDevelopmentComment,
      parentSuggestion: finalParentSuggestion,

      parentPanelText:
        parentPanelText ||
        `İnteraktif masal sonucu: ${childNickname}, '${storyTitle}' masalını tamamladı.

Puan özeti: ${selectedChoice}

Baskın gelişim alanı: ${finalDominantArea}

Duygusal gözlem: ${finalEmotionalMeaning}

Gelişimsel yorum: ${finalDevelopmentComment}

Ebeveyn önerisi: ${finalParentSuggestion}

Kısa yapay zeka özeti: ${aiAnalysis?.aiShortSummary || "Masal sonucu güvenli gözlem olarak kaydedildi."}

Not: Bu çıktı psikolojik tanı değildir; çocuğun seçim davranışına dayalı gelişimsel gözlem niteliğindedir.`,
      createdAt: createdAt || new Date().toISOString(),
    };

    interactiveStoryResults.unshift(result);
    cleanupOldStoryResults();

    res.json({
      success: true,
      message: "İnteraktif masal sonucu kaydedildi.",
      keepDays: 7,
      result,
    });
  } catch (error) {
    console.error("INTERACTIVE STORY RESULT ERROR:", error);

    res.status(500).json({
      success: false,
      error: "İnteraktif masal sonucu kaydedilemedi.",
      details: error.message,
    });
  }
});

app.get("/interactive-story-results", (_req, res) => {
  cleanupOldStoryResults();

  res.json({
    success: true,
    keepDays: 7,
    count: interactiveStoryResults.length,
    results: interactiveStoryResults,
  });
});

app.get("/interactive-story-results/:childNickname", (req, res) => {
  cleanupOldStoryResults();

  const childNickname = req.params.childNickname.toLowerCase();

  const filteredResults = interactiveStoryResults.filter((item) => {
    return (item.childNickname || "").toLowerCase() === childNickname;
  });

  res.json({
    success: true,
    keepDays: 7,
    count: filteredResults.length,
    results: filteredResults,
  });
});

app.post("/interest-emotion-map", async (req, res) => {
  try {
    const { period = "daily", forceRefresh = false } = req.body || {};

    cleanupOldConversationLogs();

    if (!forceRefresh && latestInterestEmotionMap) {
      return res.json({
        ...latestInterestEmotionMap,
        fromCache: true,
        updating: interestEmotionMapUpdating,
        lastInterestMapUpdatedAt,
      });
    }

    if (interestEmotionMapUpdating && latestInterestEmotionMap) {
      return res.json({
        ...latestInterestEmotionMap,
        fromCache: true,
        updating: true,
        lastInterestMapUpdatedAt,
      });
    }

    const result = await generateInterestEmotionMap(period);

    latestInterestEmotionMap = result;
    lastInterestMapUpdatedAt = new Date().toISOString();

    return res.json({
      ...result,
      fromCache: false,
      updating: false,
      lastInterestMapUpdatedAt,
    });
  } catch (error) {
    console.error("INTEREST MAP ERROR:", error);

    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.get("/interest-emotion-map", async (req, res) => {
  try {
    const period = req.query.period || "daily";

    cleanupOldConversationLogs();

    if (latestInterestEmotionMap) {
      return res.json({
        ...latestInterestEmotionMap,
        fromCache: true,
        updating: interestEmotionMapUpdating,
        lastInterestMapUpdatedAt,
      });
    }

    const result = await generateInterestEmotionMap(period);

    latestInterestEmotionMap = result;
    lastInterestMapUpdatedAt = new Date().toISOString();

    return res.json({
      ...result,
      fromCache: false,
      updating: false,
      lastInterestMapUpdatedAt,
    });
  } catch (error) {
    console.error("INTEREST MAP GET ERROR:", error);

    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.post("/interest-emotion-map/refresh", async (req, res) => {
  try {
    const { period = "daily" } = req.body || {};

    const result = await generateInterestEmotionMap(period);

    latestInterestEmotionMap = result;
    lastInterestMapUpdatedAt = new Date().toISOString();

    return res.json({
      ...result,
      fromCache: false,
      updating: false,
      lastInterestMapUpdatedAt,
    });
  } catch (error) {
    console.error("INTEREST MAP REFRESH ERROR:", error);

    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

app.get("/health", (_req, res) => {
  cleanupOldStoryResults();
  cleanupOldConversationLogs();

  res.json({
    ok: true,
    success: true,
    message: "server.js çalışıyor",
    chatModel: GROQ_MODEL,
    storyAnalysisModel: STORY_ANALYSIS_MODEL,
    groqEnabled: Boolean(GROQ_API_KEY),
    maleElevenLabsKeyCount: MALE_API_KEYS.length,
    maleElevenLabsVoiceCount: MALE_VOICE_IDS.length,
    girlElevenLabsKeyCount: GIRL_API_KEYS.length,
    girlElevenLabsVoiceCount: GIRL_VOICE_IDS.length,
    secondModelEnabled: true,
    qwenEnabled: false,
    modelServerRemoved: true,
    geminiVisionEnabled: Boolean(GEMINI_API_KEY),
    interactiveStoryResultCount: interactiveStoryResults.length,
    interactiveStoryKeepDays: 7,
    conversationLogCount: conversationLogs.length,
    conversationLogKeepDays: 7,
    interestEmotionMapEnabled: true,
    interestEmotionMapUpdating,
    interestEmotionMapReady: Boolean(latestInterestEmotionMap),
    lastInterestMapUpdatedAt,
    askEndpointEnabled: true,
    chatEndpointEnabled: true,
  });
});

app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: "Route not found",
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running: http://0.0.0.0:${PORT}`);
  console.log(`Groq chat model: ${GROQ_MODEL}`);
  console.log(`Groq story analysis model: ${STORY_ANALYSIS_MODEL}`);
  console.log(`Male ElevenLabs key count: ${MALE_API_KEYS.length}`);
  console.log(`Male ElevenLabs voice count: ${MALE_VOICE_IDS.length}`);
  console.log(`Girl ElevenLabs key count: ${GIRL_API_KEYS.length}`);
  console.log(`Girl ElevenLabs voice count: ${GIRL_VOICE_IDS.length}`);
  console.log("FastAPI model_server: REMOVED");
  console.log("Second model for story analysis: ENABLED");
  console.log(`Gemini Vision enabled: ${Boolean(GEMINI_API_KEY)}`);
  console.log("Interactive story results keep time: 7 days");
  console.log("Conversation logs keep time: 7 days");
  console.log("Conversation save endpoints: /chat and /ask");
});