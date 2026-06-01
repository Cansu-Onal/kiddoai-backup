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
const GROQ_MODEL = "llama-3.1-8b-instant";

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
  if (lower.includes("uzay")) return "İstersen bugün uzay hakkında konuşabiliriz.";
  if (lower.includes("hayvan")) return "İstersen bugün sevdiğin bir hayvanı konuşabiliriz.";
  if (lower.includes("araç") || lower.includes("araba")) {
    return "İstersen bugün arabalar ve araçlarla ilgili konuşabiliriz.";
  }
  if (lower.includes("masal")) return "İstersen bugün kısa bir masal hayal edebiliriz.";
  if (lower.includes("çizim") || lower.includes("resim")) {
    return "İstersen bugün ne çizeceğimizi birlikte seçebiliriz.";
  }
  if (lower.includes("müzik")) return "İstersen bugün sevdiğin bir şarkıdan konuşabiliriz.";
  if (lower.includes("doğa")) return "İstersen bugün doğada gördüğümüz güzel şeyleri konuşabiliriz.";
  if (lower.includes("bilim")) return "İstersen bugün küçük bir merak sorusu düşünelim.";
  if (lower.includes("oyun")) return "İstersen bugün birlikte küçük bir oyun fikri bulabiliriz.";

  return `İstersen bugün ${interest} hakkında konuşabiliriz.`;
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
- Sadece Türkçe cevap ver.
- Cümlelerin kısa, doğal ve çocuk seviyesinde olsun.
- En fazla 2 kısa cümle yaz.
- Her cevapta en fazla 1 soru sor.
- Başlık, madde, analiz, "Konu:", "Çocuk:", "Avatar:" yazma.
- İngilizce, Almanca veya yabancı kelime kullanma.

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

async function getGroqReply({ finalChildText, systemPrompt, cleanHistory }) {
  if (!GROQ_API_KEY) {
    throw new Error("GROQ_API_KEY eksik. .env dosyasına ekle.");
  }

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

  const response = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages,
        temperature: 0.12,
        top_p: 0.65,
        max_tokens: 70,
        presence_penalty: 0,
        frequency_penalty: 0.35,
      }),
    }
  );

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Groq API hatası: ${errText}`);
  }

  const data = await response.json();
  const reply = cleanText(data?.choices?.[0]?.message?.content || "");

  if (!reply) throw new Error("Groq boş cevap döndürdü.");

  return reply;
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

    const totalMs = Date.now() - start;

    res.json({
      success: true,
      ok: true,
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
    } = req.body;

    if (!storyTitle || !selectedChoice) {
      return res.status(400).json({
        success: false,
        error: "storyTitle ve selectedChoice zorunludur.",
      });
    }

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
      dominantArea,
      emotionalMeaning,
      developmentComment,
      parentSuggestion,
      parentPanelText:
        parentPanelText ||
        `İnteraktif masal sonucu: ${childNickname}, '${storyTitle}' masalını tamamladı.

Puan özeti: ${selectedChoice}

Baskın gelişim alanı: ${dominantArea}

Duygusal gözlem: ${emotionalMeaning}

Gelişimsel yorum: ${developmentComment}

Ebeveyn önerisi: ${parentSuggestion}

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

app.get("/health", (_req, res) => {
  cleanupOldStoryResults();
  cleanupOldConversationLogs();

  res.json({
    ok: true,
    success: true,
    message: "server.js çalışıyor",
    model: GROQ_MODEL,
    groqEnabled: Boolean(GROQ_API_KEY),
    maleElevenLabsKeyCount: MALE_API_KEYS.length,
    maleElevenLabsVoiceCount: MALE_VOICE_IDS.length,
    girlElevenLabsKeyCount: GIRL_API_KEYS.length,
    girlElevenLabsVoiceCount: GIRL_VOICE_IDS.length,
    secondModelEnabled: false,
    qwenEnabled: false,
    modelServerRemoved: true,
    geminiVisionEnabled: Boolean(GEMINI_API_KEY),
    interactiveStoryResultCount: interactiveStoryResults.length,
    interactiveStoryKeepDays: 7,
    conversationLogCount: conversationLogs.length,
    conversationLogKeepDays: 7,
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
  console.log(`Groq direct model: ${GROQ_MODEL}`);
  console.log(`Male ElevenLabs key count: ${MALE_API_KEYS.length}`);
  console.log(`Male ElevenLabs voice count: ${MALE_VOICE_IDS.length}`);
  console.log(`Girl ElevenLabs key count: ${GIRL_API_KEYS.length}`);
  console.log(`Girl ElevenLabs voice count: ${GIRL_VOICE_IDS.length}`);
  console.log("FastAPI model_server: REMOVED");
  console.log("Second model / Qwen guard: DISABLED");
  console.log(`Gemini Vision enabled: ${Boolean(GEMINI_API_KEY)}`);
  console.log("Interactive story results keep time: 7 days");
  console.log("Conversation logs keep time: 7 days");
  console.log("Conversation save endpoints: /chat and /ask");
});