import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

class RoomExplorePage extends StatefulWidget {
  const RoomExplorePage({super.key});

  @override
  State<RoomExplorePage> createState() => _RoomExplorePageState();
}

class _RoomExplorePageState extends State<RoomExplorePage> {
  static const String roomImagePath = "assets/avatars/avatar_room.jpg";

  static const String boyIdleGif = "assets/avatars/kiddo_avatar_blink.gif";
  static const String boyTalkingGif =
      "assets/avatars/kiddo_avatar_talking_natural.gif";

  static const String girlNormalAsset = "assets/avatars/normal_kiz.png";
  static const String girlTalkingAsset = "assets/avatars/konusan_kiz.png";
  static const String girlBlinkAsset = "assets/avatars/goz_kapali_kiz.png";

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  final AudioPlayer _player = AudioPlayer();
  final SpeechToText _speech = SpeechToText();

  bool isTalking = false;
  bool isListening = false;
  bool isLoadingVoice = false;
  bool speechReady = false;
  bool _checkingAnswer = false;
  bool _roomImageLoaded = false;

  bool _waitingForRevealPermission = false;
  bool _roomChatMode = false;

  String _gender = "Erkek";
  String _girlCurrentAsset = girlNormalAsset;

  Timer? _girlFrameTimer;

  String screenStatus = "Hazırlanıyor...";
  String childAnswer = "";

  String? _roomImageBase64;

  int currentTaskIndex = 0;
  int currentAttempt = 0;
  int roomChatIndex = 0;

  final Map<int, Set<String>> _foundByTask = {};
  final Map<int, Set<String>> _wrongByTask = {};

  bool get _isGirl => _gender == "Kız";

  final List<RoomTask> tasks = const [
    RoomTask(
      question: "Kırmızı olan nesneleri bulabilir misin?",
      focus: "kırmızı nesneler",
      expectedObjects: ["araba", "top"],
      objectHints: {
        "araba": "Alt tarafta, yolculuk yapmaya benzeyen küçük şeye bak.",
        "top": "Yere yakın, yuvarlak olan şeye dikkat et.",
      },
    ),
    RoomTask(
      question: "Yuvarlak olan nesneleri söyleyebilir misin?",
      focus: "yuvarlak nesneler",
      expectedObjects: ["top", "saat"],
      objectHints: {
        "top": "Yere yakın, oyun oynarken kullanılan yuvarlak şeye bak.",
        "saat": "Duvar tarafında zamanı gösteren yuvarlak şeye bak.",
      },
    ),
    RoomTask(
      question: "Odada hangi hayvan oyuncakları var?",
      focus: "hayvan oyuncakları",
      expectedObjects: ["dinozor", "ayı"],
      objectHints: {
        "dinozor":
            "Yerde duran, eskiden yaşamış büyük hayvana benzeyen oyuncağa bak.",
        "ayı": "Yumuşak oyuncakların olduğu tarafa bak.",
      },
    ),
    RoomTask(
      question: "Üçgen şekline benzeyen nesneyi bulabilir misin?",
      focus: "üçgen şekline benzeyen nesne",
      expectedObjects: ["çadır"],
      objectHints: {
        "çadır":
            "Kitaplığın başladığı yere yakın, tepesi sivri olan büyük şeye bak.",
      },
    ),
  ];

  final List<String> roomChatQuestions = const [
    "Senin odanda nasıl oyuncakların var?",
    "En sevdiğin oyuncağın hangisi?",
    "Oyuncaklarını genelde nerede tutuyorsun?",
  ];

  RoomTask get currentTask => tasks[currentTaskIndex];

  Set<String> get _currentFound =>
      _foundByTask.putIfAbsent(currentTaskIndex, () => <String>{});

  Set<String> get _currentWrong =>
      _wrongByTask.putIfAbsent(currentTaskIndex, () => <String>{});

  List<String> get _missingObjects {
    return currentTask.expectedObjects
        .where((obj) => !_currentFound.contains(obj))
        .toList();
  }

  bool get _allFound => _missingObjects.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadAvatarProfile();
    _initSpeech();
    _loadRoomImage();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _askCurrentTask();
    });
  }

  Future<void> _loadAvatarProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("settings")
          .doc("avatarProfile")
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        _gender = (data["gender"] ?? "Erkek").toString();
      });
    } catch (e) {
      debugPrint("Avatar profile okunamadı: $e");
    }
  }

  void _startGirlFrameLoop() {
    _girlFrameTimer?.cancel();

    if (!_isGirl) return;

    _girlFrameTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted) return;

      if (isTalking) {
        setState(() {
          _girlCurrentAsset = _girlCurrentAsset == girlTalkingAsset
              ? girlNormalAsset
              : girlTalkingAsset;
        });
        return;
      }

      if (isListening) {
        setState(() {
          _girlCurrentAsset = _girlCurrentAsset == girlBlinkAsset
              ? girlNormalAsset
              : girlBlinkAsset;
        });
        return;
      }

      setState(() {
        _girlCurrentAsset = girlNormalAsset;
      });
    });
  }

  void _stopGirlFrameLoop() {
    _girlFrameTimer?.cancel();
    _girlFrameTimer = null;

    if (!mounted) return;

    setState(() {
      _girlCurrentAsset = girlNormalAsset;
    });
  }

  Future<void> _loadRoomImage() async {
    try {
      final data = await rootBundle.load(roomImagePath);
      final bytes = data.buffer.asUint8List();

      if (!mounted) return;

      setState(() {
        _roomImageBase64 = base64Encode(bytes);
        _roomImageLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _roomImageLoaded = false;
        screenStatus = "Oda görseli yüklenemedi.";
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      speechReady = await _speech.initialize(
        debugLogging: true,
        onStatus: (status) {
          debugPrint("SPEECH STATUS: $status");

          if (!mounted) return;

          if (status == "listening") {
            setState(() {
              isListening = true;
              screenStatus = "Seni dinliyorum... Konuşunca Bitir'e bas 😊";
            });

            if (_isGirl) _startGirlFrameLoop();
          }

          if (status == "notListening" || status == "done") {
            setState(() {
              isListening = false;
            });

            if (!isTalking) {
              _stopGirlFrameLoop();
            }
          }
        },
        onError: (error) {
          debugPrint("SPEECH ERROR: ${error.errorMsg}");

          if (!mounted) return;

          setState(() {
            isListening = false;
            screenStatus = "Mikrofon takıldı. Sesi Dinle'ye tekrar bas.";
          });

          if (!isTalking) {
            _stopGirlFrameLoop();
          }
        },
      );

      if (!mounted) return;

      if (!speechReady) {
        setState(() {
          screenStatus = "Mikrofon izni alınamadı.";
        });
      }
    } catch (e) {
      speechReady = false;

      if (!mounted) return;

      setState(() {
        screenStatus = "Mikrofon başlatılamadı.";
      });
    }
  }

  Future<Uint8List> _getTtsBytes(String text) async {
    final response = await http
        .post(
          Uri.parse("$_baseUrl/tts"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "text": text,
            "gender": _gender,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception("TTS API hata: ${response.statusCode}");
    }

    return response.bodyBytes;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll("ı", "i")
        .replaceAll("ğ", "g")
        .replaceAll("ü", "u")
        .replaceAll("ş", "s")
        .replaceAll("ö", "o")
        .replaceAll("ç", "c")
        .trim();
  }

  Set<String> _detectObjectsFromSpeech(String spokenText) {
    final normalized = _normalize(spokenText);
    final found = <String>{};

    for (final obj in currentTask.expectedObjects) {
      final nObj = _normalize(obj);

      if (normalized.contains(nObj)) {
        found.add(obj);
      }
    }

    final aliases = <String, List<String>>{
      "araba": ["arac", "araç", "otomobil", "kirmizi araba", "kırmızı araba"],
      "top": ["kirmizi top", "kırmızı top"],
      "dinozor": ["dinazor", "dino"],
      "ayı": ["ayi", "pelus", "pelüş"],
      "çadır": ["cadir", "kamp"],
      "saat": ["duvar saati"],
    };

    aliases.forEach((object, words) {
      if (!currentTask.expectedObjects.contains(object)) return;

      for (final word in words) {
        if (normalized.contains(_normalize(word))) {
          found.add(object);
        }
      }
    });

    return found;
  }

  Set<String> _detectWrongObjectsFromSpeech(String spokenText) {
    final normalized = _normalize(spokenText);
    final wrong = <String>{};

    final knownObjects = [
      "dinozor",
      "dinazor",
      "araba",
      "araç",
      "top",
      "ayı",
      "ayi",
      "çadır",
      "cadir",
      "saat",
      "kitap",
      "lamba",
      "yastık",
      "yastik",
      "çiçek",
      "cicek",
      "masa",
      "sandalye",
    ];

    for (final word in knownObjects) {
      final canonical = _canonicalObject(word);

      if (normalized.contains(_normalize(word)) &&
          !currentTask.expectedObjects.contains(canonical)) {
        wrong.add(canonical);
      }
    }

    return wrong;
  }

  String _canonicalObject(String value) {
    final n = _normalize(value);

    if (n == "dinazor") return "dinozor";
    if (n == "ayi") return "ayı";
    if (n == "cadir") return "çadır";
    if (n == "arac") return "araba";
    if (n == "yastik") return "yastık";
    if (n == "cicek") return "çiçek";

    return value;
  }

  String _buildLocalHint() {
    final missing = _missingObjects;

    if (missing.isEmpty) {
      return "Harika, bu bölümde aradıklarımızı buldun 😊";
    }

    final hintObject = missing.first;
    final hint = currentTask.objectHints[hintObject] ??
        "Henüz bulmadığın bir nesne var. Etrafına dikkatlice bak.";

    return "Güzel denedin. $hint";
  }

  String _buildProgressReply({
    required Set<String> newlyFound,
    required Set<String> newlyWrong,
  }) {
    if (_allFound) {
      return "Harika, aradıklarımızı buldun 😊";
    }

    final parts = <String>[];

    if (newlyFound.isNotEmpty) {
      parts.add("${newlyFound.join(", ")} doğru, onu işaretledim.");
    } else if (childAnswer.trim().isNotEmpty) {
      parts.add("Güzel denedin.");
    }

    if (newlyWrong.isNotEmpty) {
      parts.add("${newlyWrong.join(", ")} bu sorunun cevabı değil.");
    }

    parts.add(_buildLocalHint());

    return parts.take(3).join(" ");
  }

  Future<String> _getVisionReply({
    required String childText,
    required String mode,
  }) async {
    if (_roomImageBase64 == null || _roomImageBase64!.isEmpty) {
      throw Exception("Oda görseli hazır değil.");
    }

    String instruction;

    final foundObjects = _currentFound.toList();
    final missingObjects = _missingObjects;

    if (mode == "hint_first") {
      instruction =
          "Çocuğun söylediği ve alreadyFound listesindeki nesneleri tekrar ipucu olarak verme. Eksik kalan missingObjects listesinden sadece bir tanesi için ipucu ver. Nesne adını direkt söyleme. Sadece konumunu, rengini veya şeklini tarif et. Yanlış nesne söylediyse bunu nazikçe belirt. En fazla 2 kısa cümle.";
    } else if (mode == "second_try") {
      instruction =
          "Çocuk ikinci kez deniyor. alreadyFound listesini tekrar etme. missingObjects listesinden sadece eksik kalanlar için ipucu ver. Nesne adını direkt söyleme, yerini tarif et. Sonunda 'istersen ben sayabilirim' diye sor. En fazla 2 kısa cümle.";
    } else if (mode == "reveal_answer") {
      instruction =
          "Çocuk onay verdi. Sadece missingObjects listesindeki eksik nesneleri söyle. alreadyFound listesindeki nesneleri tekrar sayma. Her eksik nesnenin yerini çok basit tarif et. En fazla 2 kısa cümle.";
    } else if (mode == "no_answer_hint") {
      instruction =
          "Çocuk cevap vermedi. Cevabı direkt söyleme. missingObjects listesinden bir eksik nesne için nesne adını söylemeden yer ipucu ver. En fazla 2 kısa cümle.";
    } else {
      instruction =
          "Cevabı kontrol et. alreadyFound listesini tekrar etme. Eksik nesneleri direkt söyleme, ipucu ver. En fazla 2 kısa cümle.";
    }

    final response = await http
        .post(
          Uri.parse("$_baseUrl/vision-room-check"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "imageBase64": _roomImageBase64,
            "mimeType": "image/jpeg",
            "question": currentTask.question,
            "focus": currentTask.focus,
            "childAnswer": childText,
            "attempt": currentAttempt,
            "helpMode": mode,
            "instruction": instruction,
            "expectedObjects": currentTask.expectedObjects,
            "alreadyFound": foundObjects,
            "missingObjects": missingObjects,
            "wrongObjects": _currentWrong.toList(),
          }),
        )
        .timeout(const Duration(seconds: 35));

    if (response.statusCode != 200) {
      throw Exception("Vision API hata: ${response.statusCode}");
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final reply = (data["reply"] ?? "").toString().trim();

    if (reply.isEmpty) {
      throw Exception("Vision boş cevap döndürdü.");
    }

    return reply;
  }

  Future<String> _getRoomChatReply(String childText) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/chat"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "message":
                  "Oda ve oyuncaklar hakkında çocukla konuşuyorsun. Çocuğun cevabı: $childText. Kısa, sıcak ve çocuk dostu cevap ver. Sonra oda veya oyuncaklarla ilgili küçük bir soru sor.",
              "topic": "Oda ve oyuncaklar",
              "nickname": "çocuk",
              "personality": "nazik ve sıcak",
              "interests": ["oyuncaklar", "oda", "renkler", "şekiller"],
              "goals": ["konuşma", "nesne anlatma", "kendini ifade etme"],
              "history": [],
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw Exception("Chat API hata: ${response.statusCode}");
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text = (data["text"] ?? data["reply"] ?? "").toString().trim();

      if (text.isEmpty) throw Exception("Boş cevap");
      return text;
    } catch (e) {
      return "Ne güzel anlattın 😊 Oyuncağınla en çok hangi oyunu oynuyorsun?";
    }
  }

  Future<void> _speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    StreamSubscription<void>? completeSub;
    final completer = Completer<void>();

    try {
      await _stopListening(useCancel: true);
      await _player.stop();

      if (!mounted) return;

      setState(() {
        isLoadingVoice = true;
        isTalking = false;
        isListening = false;
        screenStatus = "Avatar konuşuyor...";
      });

      final bytes = await _getTtsBytes(cleanText);

      if (!mounted) return;

      completeSub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      setState(() {
        isLoadingVoice = false;
        isTalking = true;
        isListening = false;
      });

      if (_isGirl) {
        _startGirlFrameLoop();
      }

      await _player.play(BytesSource(bytes));

      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {},
      );

      await completeSub.cancel();

      if (!mounted) return;

      setState(() {
        isTalking = false;
        isLoadingVoice = false;
      });

      _stopGirlFrameLoop();
    } catch (e) {
      try {
        await completeSub?.cancel();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        isLoadingVoice = false;
        isTalking = false;
        isListening = false;
        screenStatus = "Ses hazırlanamadı. Devam edebilirsin.";
      });

      _stopGirlFrameLoop();
    }
  }

  Future<void> _askCurrentTask() async {
    _checkingAnswer = false;
    _waitingForRevealPermission = false;
    _roomChatMode = false;

    final textToSpeak = currentTaskIndex == 0
        ? "Haydi odamı birlikte inceleyelim. Bulduklarını işaretleyeceğim, eksikler için ipucu vereceğim. ${currentTask.question}"
        : currentTask.question;

    setState(() {
      childAnswer = "";
      currentAttempt = 0;
      screenStatus = "Avatar konuşuyor...";
    });

    await _speak(textToSpeak);

    if (!mounted) return;

    setState(() {
      screenStatus = "Hazırsan Sesi Dinle butonuna bas 😊";
    });
  }

  Future<void> _startListening({bool keepPreviousText = false}) async {
    if (!mounted) return;

    if (isTalking || isLoadingVoice || _checkingAnswer) return;

    if (!speechReady) {
      await _initSpeech();
    }

    if (!speechReady) {
      if (!mounted) return;
      setState(() {
        screenStatus = "Mikrofon başlatılamadı. Tarayıcıdan izin ver.";
      });
      return;
    }

    try {
      if (_speech.isListening) {
        await _speech.cancel();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      if (!keepPreviousText) childAnswer = "";
      isListening = true;
      _checkingAnswer = false;
      screenStatus = "Seni dinliyorum... Konuşunca Bitir'e bas 😊";
    });

    if (_isGirl) {
      _startGirlFrameLoop();
    }

    try {
      await _speech.listen(
        localeId: "tr_TR",
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 30),
        cancelOnError: false,
        onResult: (result) {
          if (!mounted) return;
          if (_checkingAnswer || isTalking || isLoadingVoice) return;

          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;

          setState(() {
            childAnswer = text;
            screenStatus = "Duydum: $childAnswer";
          });
        },
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isListening = false;
        screenStatus = "Mikrofon dinlemeye başlayamadı. Tekrar dene.";
      });

      if (!isTalking) {
        _stopGirlFrameLoop();
      }
    }
  }

  Future<void> _finishListeningAndCheck() async {
    if (isTalking || isLoadingVoice || _checkingAnswer) return;

    final text = childAnswer.trim();

    await _stopListening(useCancel: false);

    if (text.isEmpty) {
      await _giveHintWithoutAnswer();
      return;
    }

    await _checkAnswer(text);
  }

  Future<void> _giveHintWithoutAnswer() async {
    if (_checkingAnswer) return;

    _checkingAnswer = true;
    await _stopListening(useCancel: true);

    String response;

    try {
      response = await _getVisionReply(
        childText: "Çocuk cevap vermedi.",
        mode: "no_answer_hint",
      );
    } catch (e) {
      response = _buildLocalHint();
    }

    await _speak(response);

    if (!mounted) return;

    setState(() {
      _checkingAnswer = false;
      currentAttempt++;
      screenStatus = "Tekrar denemek için Sesi Dinle'ye bas 😊";
    });
  }

  Future<void> _stopListening({bool useCancel = false}) async {
    try {
      if (_speech.isListening) {
        if (useCancel) {
          await _speech.cancel();
        } else {
          await _speech.stop();
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      isListening = false;
    });

    if (!isTalking) {
      _stopGirlFrameLoop();
    }
  }

  bool _isYes(String value) {
    final text = _normalize(value);
    return text.contains("evet") ||
        text.contains("olur") ||
        text.contains("say") ||
        text.contains("tamam") ||
        text.contains("isterim") ||
        text.contains("anlat");
  }

  bool _isNo(String value) {
    final text = _normalize(value);
    return text.contains("hayir") ||
        text.contains("yok") ||
        text.contains("istemem") ||
        text.contains("gerek yok");
  }

  Future<void> _checkAnswer(String spokenText) async {
    if (_checkingAnswer) return;

    _checkingAnswer = true;
    await _stopListening(useCancel: true);

    if (_roomChatMode) {
      await _handleRoomChatAnswer(spokenText);
      return;
    }

    if (_waitingForRevealPermission) {
      await _handleRevealPermission(spokenText);
      return;
    }

    final newlyFound = _detectObjectsFromSpeech(spokenText);
    final newlyWrong = _detectWrongObjectsFromSpeech(spokenText);

    setState(() {
      childAnswer = spokenText;
      _currentFound.addAll(newlyFound);
      _currentWrong.addAll(newlyWrong);
      screenStatus = "Cevabın kontrol ediliyor...";
    });

    if (_allFound) {
      await _speak("Harika, aradıklarımızı buldun 😊");

      if (!mounted) return;

      setState(() {
        screenStatus = "Harika, aradıklarımızı buldun 😊";
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _goNextTask();
      return;
    }

    String response;

    try {
      response = await _getVisionReply(
        childText: spokenText,
        mode: currentAttempt == 0 ? "hint_first" : "second_try",
      );
    } catch (e) {
      response = _buildProgressReply(
        newlyFound: newlyFound,
        newlyWrong: newlyWrong,
      );
    }

    if (newlyFound.isNotEmpty || newlyWrong.isNotEmpty) {
      response = _buildProgressReply(
        newlyFound: newlyFound,
        newlyWrong: newlyWrong,
      );
    }

    await _speak(response);

    if (!mounted) return;

    if (currentAttempt == 0) {
      setState(() {
        currentAttempt++;
        _checkingAnswer = false;
        screenStatus = "Tekrar cevap vermek için Sesi Dinle'ye bas 😊";
      });

      return;
    }

    setState(() {
      _waitingForRevealPermission = true;
      _checkingAnswer = false;
      screenStatus = "Avatar sana bir soru soracak...";
    });

    await _speak("İstersen eksik kalanları ben sayayım mı?");

    if (!mounted) return;

    setState(() {
      screenStatus =
          "Cevap için Sesi Dinle'ye bas. Evet ya da hayır diyebilirsin 😊";
    });
  }

  Future<void> _handleRevealPermission(String spokenText) async {
    setState(() {
      screenStatus = "Cevabın hazırlanıyor...";
    });

    if (_isYes(spokenText)) {
      String response;

      final missing = _missingObjects;

      if (missing.isEmpty) {
        response = "Aslında aradıklarımızı buldun. Sıradaki soruya geçelim 😊";
      } else {
        try {
          response = await _getVisionReply(
            childText:
                "Çocuk onay verdi. Sadece eksik kalanları söyle: ${missing.join(", ")}",
            mode: "reveal_answer",
          );
        } catch (e) {
          response =
              "Eksik kalanlar: ${missing.join(", ")}. Şimdi sıradaki soruya geçelim.";
        }
      }

      await _speak(response);
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _goNextTask();
      return;
    }

    if (_isNo(spokenText)) {
      await _speak("Tamam, sorun değil. Sıradaki soruya geçelim.");
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _goNextTask();
      return;
    }

    setState(() {
      _checkingAnswer = false;
      screenStatus = "Evet ya da hayır demek için Sesi Dinle'ye bas 😊";
    });

    await _speak("Saymamı ister misin? Evet ya da hayır diyebilirsin.");
  }

  Future<void> _handleRoomChatAnswer(String spokenText) async {
    setState(() {
      screenStatus = "Avatar düşünüyor...";
    });

    final reply = await _getRoomChatReply(spokenText);
    await _speak(reply);

    if (!mounted) return;

    roomChatIndex++;

    if (roomChatIndex >= roomChatQuestions.length) {
      setState(() {
        _checkingAnswer = false;
        _roomChatMode = false;
        childAnswer = "";
        screenStatus = "Oda sohbeti tamamlandı ✨";
      });

      await _speak(
        "Odanı ve oyuncaklarını anlatman çok güzeldi. Bugünlük oda keşfimiz bitti 😊",
      );
      return;
    }

    setState(() {
      _checkingAnswer = false;
      childAnswer = "";
      screenStatus = "Avatar sana yeni bir soru soruyor...";
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    await _speak(roomChatQuestions[roomChatIndex]);

    if (!mounted) return;

    setState(() {
      screenStatus = "Cevap vermek için Sesi Dinle'ye bas 😊";
    });
  }

  Future<void> _goNextTask() async {
    if (currentTaskIndex < tasks.length - 1) {
      setState(() {
        currentTaskIndex++;
        currentAttempt = 0;
        childAnswer = "";
        _waitingForRevealPermission = false;
        _checkingAnswer = false;
        screenStatus = "Sıradaki soruya geçiyoruz...";
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await _askCurrentTask();
    } else {
      await _startRoomChat();
    }
  }

  Future<void> _startRoomChat() async {
    setState(() {
      _roomChatMode = true;
      _waitingForRevealPermission = false;
      _checkingAnswer = false;
      roomChatIndex = 0;
      childAnswer = "";
      screenStatus = "Şimdi senin odanı konuşalım 😊";
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    await _speak(
      "Odamdaki nesneleri çok güzel inceledik. Şimdi biraz senin odanı konuşalım. ${roomChatQuestions[roomChatIndex]}",
    );

    if (!mounted) return;

    setState(() {
      screenStatus = "Cevap vermek için Sesi Dinle'ye bas 😊";
    });
  }

  Future<void> _repeatQuestion() async {
    if (isTalking || isLoadingVoice) return;

    await _stopListening(useCancel: true);

    setState(() {
      _checkingAnswer = false;
    });

    if (_roomChatMode) {
      await _speak(roomChatQuestions[roomChatIndex]);
      if (!mounted) return;
      setState(() {
        screenStatus = "Cevap vermek için Sesi Dinle'ye bas 😊";
      });
      return;
    }

    if (_waitingForRevealPermission) {
      await _speak("İstersen eksik kalanları ben sayayım mı?");
      if (!mounted) return;
      setState(() {
        screenStatus = "Evet ya da hayır için Sesi Dinle'ye bas 😊";
      });
      return;
    }

    await _askCurrentTask();
  }

  @override
  void dispose() {
    _girlFrameTimer?.cancel();

    try {
      _speech.cancel();
    } catch (_) {}

    try {
      _player.stop();
      _player.dispose();
    } catch (_) {}

    super.dispose();
  }

  Widget _buildFoundPanel() {
    return Positioned(
      right: 12,
      top: 12,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Buldukların",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Color(0xFF5B3A00),
              ),
            ),
            const SizedBox(height: 8),
            ...currentTask.expectedObjects.map((obj) {
              final found = _currentFound.contains(obj);

              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(
                      found
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: found ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        found ? obj : "Eksik",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: found ? Colors.green.shade800 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _currentAvatarAsset() {
    if (_isGirl) {
      if (isTalking || isListening) {
        return _girlCurrentAsset;
      }

      return girlNormalAsset;
    }

    return isTalking ? boyTalkingGif : boyIdleGif;
  }

  @override
  Widget build(BuildContext context) {
    final avatarAsset = _currentAvatarAsset();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB74D),
        title: const Text(
          "Avatarın Odası",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      roomImagePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 85,
                    child: SizedBox(
                      width: 250,
                      height: 350,
                      child: Image.asset(
                        avatarAsset,
                        key: ValueKey(avatarAsset),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.face_rounded,
                            size: 130,
                            color: Color(0xFF5B3A00),
                          );
                        },
                      ),
                    ),
                  ),
                  _buildFoundPanel(),
                  if (!_roomImageLoaded)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.75),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    screenStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isListening
                          ? Colors.orange.shade800
                          : const Color(0xFF5B3A00),
                    ),
                  ),
                  if (childAnswer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Sen: $childAnswer",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: isTalking ||
                                isLoadingVoice ||
                                _checkingAnswer ||
                                isListening
                            ? null
                            : () => _startListening(),
                        icon: const Icon(Icons.mic_rounded),
                        label: const Text("Sesi Dinle"),
                      ),
                      FilledButton.icon(
                        onPressed: isTalking ||
                                isLoadingVoice ||
                                _checkingAnswer ||
                                !isListening
                            ? null
                            : _finishListeningAndCheck,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text("Bitir"),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            isTalking || isLoadingVoice || _checkingAnswer
                                ? null
                                : _repeatQuestion,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text("Soruyu Tekrarla"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomTask {
  final String question;
  final String focus;
  final List<String> expectedObjects;
  final Map<String, String> objectHints;

  const RoomTask({
    required this.question,
    required this.focus,
    required this.expectedObjects,
    required this.objectHints,
  });
}