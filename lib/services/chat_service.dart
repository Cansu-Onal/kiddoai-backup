import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Map<String, List<String>> riskyCategories = {
    "şiddet": [
      "dövdüm",
      "dövdü",
      "vurdum",
      "vurdu",
      "vur",
      "öldür",
      "öldürdüm",
      "bıçak",
      "silah",
      "kan",
      "kavga",
      "yaraladım",
      "patlat",
      "tekme",
      "tokat",
    ],
    "küfür": [
      "salak",
      "aptal",
      "gerizekalı",
      "mal",
      "lan",
      "pislik",
      "iğrenç",
      "nefret ediyorum",
    ],
    "kendine zarar": [
      "kendimi öldür",
      "ölmek istiyorum",
      "intihar",
      "yaşamak istemiyorum",
      "canımı yakmak",
      "kendime zarar",
    ],
    "korku / istismar": [
      "korkuyorum",
      "bana vurdu",
      "bana bağırdı",
      "biri bana zarar verdi",
      "yalnızım",
      "karanlıkta korkuyorum",
    ],
    "yasak içerik": [
      "sigara",
      "alkol",
      "uyuşturucu",
      "hap",
      "zararlı şey",
    ],
  };

  static Map<String, dynamic> analyzeRisk(String text) {
    final lower = text.toLowerCase();

    for (final entry in riskyCategories.entries) {
      for (final word in entry.value) {
        if (lower.contains(word)) {
          return {
            "riskLevel": "high",
            "riskCategory": entry.key,
            "riskReason": "Riskli ifade: $word",
          };
        }
      }
    }

    if (lower.contains("üzgün") ||
        lower.contains("ağlıyorum") ||
        lower.contains("kimse beni sevmiyor") ||
        lower.contains("mutsuzum") ||
        lower.contains("canım sıkıldı")) {
      return {
        "riskLevel": "medium",
        "riskCategory": "duygusal",
        "riskReason": "Üzüntü belirtisi",
      };
    }

    return {
      "riskLevel": "normal",
      "riskCategory": "",
      "riskReason": "",
    };
  }

  static String detectTopic(String text) {
    final lower = text.toLowerCase();

    final Map<String, List<String>> topicKeywords = {
      "Araçlar": [
        "araba",
        "tren",
        "uçak",
        "gemi",
        "otobüs",
        "kamyon",
        "araç",
        "traktör",
      ],
      "Müzik": [
        "şarkı",
        "müzik",
        "dans",
        "söylemek",
        "piyano",
        "gitar",
      ],
      "Hayvanlar": [
        "kedi",
        "köpek",
        "kuş",
        "balık",
        "tavşan",
        "aslan",
        "kaplan",
        "fil",
        "zürafa",
        "dinozor",
        "hayvan",
      ],
      "Uzay": [
        "uzay",
        "gezegen",
        "ay",
        "güneş",
        "yıldız",
        "roket",
        "astronot",
        "mars",
      ],
      "Masal": [
        "masal",
        "hikaye",
        "prenses",
        "peri",
        "ejderha",
        "kahraman",
        "kitap",
      ],
      "Çizim": [
        "resim",
        "çizim",
        "boyama",
        "boyadım",
        "çizdim",
        "renk",
        "kalem",
      ],
      "Spor": [
        "top",
        "futbol",
        "basketbol",
        "koşmak",
        "spor",
        "zıplamak",
        "oynamak",
      ],
      "Okul": [
        "okul",
        "ödev",
        "ders",
        "sınav",
        "öğretmen",
        "sınıf",
        "matematik",
        "harf",
        "sayı",
      ],
      "Aile": [
        "anne",
        "baba",
        "aile",
        "kardeş",
        "abla",
        "abi",
        "dede",
        "nine",
      ],
      "Duygular": [
        "mutlu",
        "üzgün",
        "korktum",
        "korkuyorum",
        "sinirli",
        "kızdım",
        "ağlıyorum",
        "yalnız",
      ],
      "Oyun": [
        "oyun",
        "tablet",
        "telefon",
        "bilgisayar",
        "minecraft",
        "roblox",
      ],
      "Doğa": [
        "ağaç",
        "çiçek",
        "orman",
        "deniz",
        "yağmur",
        "bulut",
        "gökkuşağı",
      ],
      "Bilim": [
        "deney",
        "bilim",
        "mıknatıs",
        "robot",
        "icat",
        "laboratuvar",
      ],
    };

    for (final entry in topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return "Günlük sohbet";
  }

  static String _dateId() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  static String _todayDocId(String uid) {
    return "${uid}_${_dateId()}";
  }

  static DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _safeTopicKey(String topic) {
    return topic
        .replaceAll(".", "_")
        .replaceAll("/", "_")
        .replaceAll("[", "_")
        .replaceAll("]", "_")
        .replaceAll("*", "_")
        .trim();
  }

  static Future<void> saveMessage({
    required String childMessage,
    required String aiReply,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    print("========== CHAT SAVE START ==========");
    print("USER UID: ${user?.uid}");
    print("CHILD MESSAGE: $childMessage");
    print("AI REPLY: $aiReply");

    if (user == null) {
      print("CHAT SAVE STOPPED: currentUser null");
      print("========== CHAT SAVE END ==========");
      return;
    }

    final child = childMessage.trim();
    final reply = aiReply.trim();

    if (child.isEmpty && reply.isEmpty) {
      print("CHAT SAVE STOPPED: empty message");
      print("========== CHAT SAVE END ==========");
      return;
    }

    final risk = analyzeRisk("$child $reply");
    final topic = detectTopic("$child $reply");
    final safeTopicKey = _safeTopicKey(topic);

    final riskLevel = risk["riskLevel"]?.toString() ?? "normal";
    final bool isRisky = riskLevel == "high" || riskLevel == "medium";

    final nowServer = FieldValue.serverTimestamp();
    final messageCreatedAt = Timestamp.now();

    final messageData = {
      "childMessage": child,
      "aiReply": reply,
      "topic": topic,
      "riskLevel": riskLevel,
      "riskCategory": risk["riskCategory"] ?? "",
      "riskReason": risk["riskReason"] ?? "",
      "isRisky": isRisky,
      "createdAt": messageCreatedAt,
    };

    final rootDocRef = _db.collection("dailyChats").doc(_todayDocId(user.uid));

    final userDocRef = _db
        .collection("users")
        .doc(user.uid)
        .collection("dailyChats")
        .doc(_dateId());

    final updateData = {
      "userId": user.uid,
      "date": Timestamp.fromDate(_todayDateOnly()),
      "lastUpdatedAt": nowServer,
      "mainTopic": topic,
      "normalSummary": "Bugün çocuk ağırlıklı olarak $topic hakkında konuştu.",
      "totalMessages": FieldValue.increment(1),
      "riskyCount": FieldValue.increment(isRisky ? 1 : 0),
      "topics": FieldValue.arrayUnion([topic]),
      "messages": FieldValue.arrayUnion([messageData]),
      "lastMessage": messageData,
      "lastChildMessage": child,
      "lastAiReply": reply,
      "lastMessageAt": messageCreatedAt,
      "topicCounts.$safeTopicKey": FieldValue.increment(1),
      if (isRisky) ...{
        "hasRisk": true,
        "riskyMessages": FieldValue.arrayUnion([messageData]),
      },
    };

    try {
      final rootSnapshot = await rootDocRef.get();
      final userSnapshot = await userDocRef.get();

      if (!rootSnapshot.exists) {
        await rootDocRef.set({
          "createdAt": nowServer,
          "hasRisk": isRisky,
          ...updateData,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      } else {
        await rootDocRef
            .set(updateData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      }

      if (!userSnapshot.exists) {
        await userDocRef.set({
          "createdAt": nowServer,
          "hasRisk": isRisky,
          ...updateData,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      } else {
        await userDocRef
            .set(updateData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      }

      print("CHAT SAVE SUCCESS");
    } catch (e, st) {
      print("CHAT SAVE ERROR: $e");
      print(st);
    }

    print("========== CHAT SAVE END ==========");
  }
}