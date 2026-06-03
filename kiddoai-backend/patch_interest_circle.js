import fs from "fs";

const filePath = "./server.js";
let code = fs.readFileSync(filePath, "utf8");

code = code.replace(
/function getInterestEmotionFallbackData\(reason = "fallback"\) \{[\s\S]*?\n\}/,
`function getInterestEmotionFallbackData(reason = "fallback") {
  return {
    items: [
      { emotion: "mutlu", label: "Mutlu", percentage: 35, topics: ["oyun", "hayvanlar", "resim"] },
      { emotion: "meraklı", label: "Meraklı", percentage: 25, topics: ["uzay", "bilim", "masal"] },
      { emotion: "nötr", label: "Nötr", percentage: 15, topics: ["günlük sohbet"] },
      { emotion: "kaygılı", label: "Kaygılı", percentage: 10, topics: ["okul", "yeni ortam"] },
      { emotion: "üzgün", label: "Üzgün", percentage: 10, topics: ["arkadaşlar", "özlem"] },
      { emotion: "kızgın", label: "Kızgın", percentage: 5, topics: ["paylaşma", "oyuncak"] },
    ],
    parentSummary:
      reason === "no_logs"
        ? "Henüz yeterli konuşma kaydı bulunmadığı için örnek analiz gösteriliyor. Çocuk sohbet ettikçe duygu çemberi otomatik güncellenir."
        : "Konuşmalardan ilgi ve duygu eğilimi oluşturuldu. Bu çıktı psikolojik tanı değildir.",
  };
}`
);

code = code.replace(
/function sanitizeInterestEmotionMap\(parsed\) \{[\s\S]*?\n\}\n\nfunction filterConversationLogsByPeriod/,
`function sanitizeInterestEmotionMap(parsed) {
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
    const found = parsedItems.find(
      (item) => cleanText(item?.emotion).toLowerCase() === base.emotion
    );

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
      "Konuşmalardan ilgi ve duygu eğilimi oluşturuldu. Bu çıktı psikolojik tanı değildir.",
  };
}

function filterConversationLogsByPeriod`
);

code = code.replace(
/- Her bölge için topics listesi dolu olsun\./g,
"- Her duygu için topics listesi dolu olsun."
);

code = code.replace(
/Bölgeler ve duygular sabit:[\s\S]*?JSON ŞEMASI:/,
`Duygular sabit:
mutlu
meraklı
nötr
kaygılı
üzgün
kızgın

JSON ŞEMASI:`
);

code = code.replace(
/\{\s*"regions": \{[\s\S]*?\},\s*"parentSummary": ""\s*\}/,
`{
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
}`
);

fs.writeFileSync(filePath, code, "utf8");

console.log("server.js duygu çemberi formatına güncellendi.");