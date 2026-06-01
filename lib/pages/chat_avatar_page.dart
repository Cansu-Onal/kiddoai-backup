import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../pages/avatar_view_page.dart';
import '../services/chat_service.dart';

class ChatAvatarPage extends StatefulWidget {
  final String nickname;
  final String personality;
  final int dailyLimitMinutes;

  const ChatAvatarPage({
    super.key,
    required this.nickname,
    required this.personality,
    required this.dailyLimitMinutes,
  });

  @override
  State<ChatAvatarPage> createState() => _ChatAvatarPageState();
}

class _ChatBubbleMessage {
  final String text;

  const _ChatBubbleMessage({required this.text});
}

class _ChatAvatarPageState extends State<ChatAvatarPage>
    with WidgetsBindingObserver {
  final SpeechToText _speech = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isTalking = false;
  bool _isListening = false;
  bool _isSending = false;
  bool _speechReady = false;
  bool _firstGreetingSpoken = false;
  bool _sendLocked = false;
  bool _disposed = false;
  bool _listenStarting = false;
  bool _isVoiceEnabled = false;

  String _status = "Sohbet hazır";
  String _lastWords = "";
  String _lastSentText = "";

  Timer? _silenceTimer;
  Timer? _forceDoneTimer;
  Timer? _listenRetryTimer;
  Timer? _girlTalkTimer;
  Timer? _girlBlinkTimer;

  static const String _avatarName = "Arkadaşın";

  String _gender = "Erkek";

  static const String girlNormalAsset = "assets/avatars/normal_kiz.png";
  static const String girlTalkingAsset = "assets/avatars/konusan_kiz.png";
  static const String girlBlinkAsset = "assets/avatars/goz_kapali_kiz.png";

  String _currentGirlAsset = girlNormalAsset;

  bool get _isGirl => _gender == "Kız";

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  List<String> _profileInterests = [];
  List<String> _profileGoals = [];
  String _extraLike = "";

  final List<_ChatBubbleMessage> _messages = [];
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadAvatarProfile();
    _initSpeech();

    _audioPlayer.onPlayerComplete.listen((_) async {
      if (!mounted || _disposed) return;
      if (!_isConnected) return;
      if (!_isTalking) return;

      await _finishAssistantTurn();
    });

    _startGirlBlinkLoop();
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
      final interestsRaw = data["interests"];
      final goalsRaw = data["goals"];

      if (!mounted || _disposed) return;

      setState(() {
        _gender = (data["gender"] ?? "Erkek").toString();

        _profileInterests = interestsRaw is List
            ? interestsRaw.map((e) => e.toString()).toList()
            : [];

        _profileGoals =
            goalsRaw is List ? goalsRaw.map((e) => e.toString()).toList() : [];

        _extraLike = (data["extraLike"] ?? "").toString();
      });
    } catch (e) {
      debugPrint("Avatar profile okunamadı: $e");
    }
  }

  void _startGirlBlinkLoop() {
    _girlBlinkTimer?.cancel();

    _girlBlinkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted || _disposed) return;
      if (!_isGirl) return;
      if (_isTalking || _isSending) return;

      setState(() {
        _currentGirlAsset = girlBlinkAsset;
      });

      await Future.delayed(const Duration(milliseconds: 180));

      if (!mounted || _disposed) return;
      if (!_isGirl) return;
      if (_isTalking || _isSending) return;

      setState(() {
        _currentGirlAsset = girlNormalAsset;
      });
    });
  }

  void _startGirlTalkingLoop() {
    if (!_isGirl) return;

    _girlTalkTimer?.cancel();

    _girlTalkTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted || _disposed) return;
      if (!_isGirl) return;
      if (!_isTalking) return;

      setState(() {
        _currentGirlAsset = _currentGirlAsset == girlTalkingAsset
            ? girlNormalAsset
            : girlTalkingAsset;
      });
    });
  }

  void _stopGirlTalkingLoop() {
    _girlTalkTimer?.cancel();
    _girlTalkTimer = null;

    if (!mounted || _disposed) return;

    setState(() {
      _currentGirlAsset = girlNormalAsset;
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted || _disposed) return;

          if (!_isVoiceEnabled) {
            setState(() => _isListening = false);
            return;
          }

          if (status == "listening") {
            if (!_isTalking && !_isSending) {
              setState(() => _isListening = true);
            }
          }

          if (status == "notListening" || status == "done") {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted || _disposed) return;

          debugPrint("Speech error: $error");

          setState(() {
            _isListening = false;
            _listenStarting = false;
            _status = "Mikrofon dinleme hatası";
          });

          if (_isVoiceEnabled && _isConnected && !_isTalking && !_isSending) {
            _scheduleListenRetry();
          }
        },
      );
    } catch (e) {
      debugPrint("Speech init error: $e");
      _speechReady = false;
    }
  }

  void _scheduleListenRetry() {
    if (!_isVoiceEnabled) return;

    _listenRetryTimer?.cancel();

    _listenRetryTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted || _disposed) return;
      if (_isVoiceEnabled &&
          _isConnected &&
          !_isTalking &&
          !_isSending &&
          !_isListening) {
        await _startListening();
      }
    });
  }

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _toggleVoice() async {
    await _clickSound();

    if (_isVoiceEnabled) {
      _listenRetryTimer?.cancel();
      await _stopListening();

      if (!mounted || _disposed) return;

      setState(() {
        _isVoiceEnabled = false;
        _isListening = false;
        _listenStarting = false;
        _lastWords = "";
        _status = _isConnected ? "Ses kapalı" : "Sohbet hazır";
      });
    } else {
      if (!mounted || _disposed) return;

      setState(() {
        _isVoiceEnabled = true;
        _status = _isConnected ? "Ses açıldı" : "Ses açık";
      });

      if (_isConnected && !_isTalking && !_isSending) {
        await _startListening();
      }
    }
  }

  Future<void> _startChat() async {
    if (_isConnecting || _isConnected) return;

    await _clickSound();
    await _loadAvatarProfile();

    setState(() {
      _isConnecting = true;
      _isConnected = false;
      _isTalking = false;
      _isListening = false;
      _isSending = false;
      _firstGreetingSpoken = false;
      _sendLocked = false;
      _listenStarting = false;
      _isVoiceEnabled = false;
      _lastWords = "";
      _lastSentText = "";
      _messages.clear();
      _chatHistory.clear();
      _status = "Avatar hazırlanıyor...";
      _currentGirlAsset = girlNormalAsset;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted || _disposed) return;

    setState(() {
      _isConnecting = false;
      _isConnected = true;
      _status = "Avatar konuşmaya başlıyor...";
    });

    await _speakFirstGreeting();
  }

  Future<void> _speakFirstGreeting() async {
    if (!_isConnected || _firstGreetingSpoken || _isSending || _isTalking) {
      return;
    }

    final interestText = _getMainInterest();

    final greeting = interestText.isEmpty
        ? "Merhaba ${widget.nickname}. Bugün nasılsın? Bana bugün neler yaptığını anlatır mısın?"
        : "Merhaba ${widget.nickname}. Bugün nasılsın? İstersen birazdan $interestText hakkında sohbet edebiliriz.";

    _addHistory("assistant", greeting);

    setState(() {
      _firstGreetingSpoken = true;
      _isSending = true;
      _isTalking = false;
      _isListening = false;
      _lastWords = "";
      _status = "Avatar sesi hazırlanıyor...";
    });

    await _playTts(greeting);
  }

  String _getMainInterest() {
    if (_extraLike.trim().isNotEmpty) return _extraLike.trim();

    final cleanInterests = _profileInterests
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (cleanInterests.isEmpty) return "";

    return cleanInterests.first;
  }

  void _addHistory(String role, String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _chatHistory.add({
      "role": role,
      "text": clean,
    });

    if (_chatHistory.length > 10) {
      _chatHistory.removeRange(0, _chatHistory.length - 10);
    }
  }

  List<Map<String, String>> _historyForServer() {
    return _chatHistory
        .map((item) => {
              "role": item["role"] ?? "",
              "text": item["text"] ?? "",
            })
        .where((item) => item["role"]!.isNotEmpty && item["text"]!.isNotEmpty)
        .toList();
  }

  Future<String> _getBotReply(String userText) async {
    final interests = <String>[
      ..._profileInterests,
      if (_extraLike.trim().isNotEmpty) _extraLike.trim(),
    ];

    final response = await http
        .post(
          Uri.parse("$_baseUrl/chat"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "message": userText,
            "history": _historyForServer(),
            "interests": interests,
            "goals": _profileGoals,
            "nickname": widget.nickname,
            "personality": widget.personality,
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Chat API hata: ${response.statusCode}");
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return (data["text"] ?? data["reply"] ?? "").toString().trim();
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

  Future<void> _playTts(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      await _finishAssistantTurn();
      return;
    }

    try {
      await _stopListening();

      if (!mounted || _disposed) return;

      setState(() {
        _isSending = true;
        _isTalking = false;
        _isListening = false;
        _lastWords = "";
        _status = "Avatar sesi hazırlanıyor...";
      });

      final audioBytes = await _getTtsBytes(cleanText);

      if (!mounted || _disposed) return;

      setState(() {
        _isSending = false;
        _isTalking = true;
        _isListening = false;
        _lastWords = "";
        _status = "Avatar konuşuyor...";
      });

      if (_isGirl) {
        _startGirlTalkingLoop();
      }

      _startForceDoneTimer();

      await _audioPlayer.stop();
      await _audioPlayer.play(BytesSource(audioBytes));
    } catch (e) {
      debugPrint("TTS play error: $e");

      if (!mounted || _disposed) return;

      _cancelForceDoneTimer();
      _stopGirlTalkingLoop();

      setState(() {
        _isSending = false;
        _isTalking = false;
        _isListening = false;
        _lastWords = "";
        _status = "Ses hazırlanamadı, tekrar deneyebilirsin.";
      });

      await _restartListeningSafely();
    }
  }

  Future<void> _finishAssistantTurn() async {
    _cancelForceDoneTimer();
    _stopGirlTalkingLoop();

    if (!mounted || _disposed) return;

    setState(() {
      _isTalking = false;
      _isSending = false;
      _isListening = false;
      _lastWords = "";
      _status = _isVoiceEnabled ? "Seni dinliyor..." : "Ses kapalı";
    });

    await _restartListeningSafely();
  }

  void _startForceDoneTimer() {
    _cancelForceDoneTimer();

    _forceDoneTimer = Timer(const Duration(seconds: 30), () async {
      if (!mounted || _disposed) return;
      if (!_isConnected) return;
      if (!_isTalking && !_isSending) return;

      await _audioPlayer.stop();
      await _finishAssistantTurn();
    });
  }

  void _cancelForceDoneTimer() {
    _forceDoneTimer?.cancel();
    _forceDoneTimer = null;
  }

  Future<void> _restartListeningSafely() async {
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted || _disposed) return;
    if (!_isVoiceEnabled) return;

    if (_isConnected &&
        !_isTalking &&
        !_isSending &&
        !_isListening &&
        !_listenStarting &&
        !_speech.isListening) {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_isVoiceEnabled) return;
    if (!_isConnected || _isTalking || _isSending || _sendLocked) return;
    if (_isListening || _listenStarting || _speech.isListening) return;

    _listenStarting = true;

    try {
      if (!_speechReady) {
        await _initSpeech();
      }

      if (!_speechReady) {
        if (!mounted || _disposed) return;
        setState(() => _status = "Mikrofon başlatılamadı");
        return;
      }

      _lastWords = "";

      if (!mounted || _disposed) return;

      setState(() {
        _isListening = true;
        _status = "Seni dinliyor...";
      });

      await _speech.listen(
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: "tr_TR",
        cancelOnError: false,
        onResult: (result) {
          if (!mounted || _disposed) return;
          if (!_isVoiceEnabled) return;
          if (!_isConnected) return;
          if (_isTalking || _isSending || _sendLocked) return;

          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;

          setState(() {
            _lastWords = text;
          });

          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(seconds: 2), () async {
            await _finishListeningAndSend();
          });
        },
      );
    } catch (e) {
      debugPrint("Speech listen error: $e");

      if (!mounted || _disposed) return;

      setState(() {
        _isListening = false;
        _status = "Mikrofon dinleme hatası";
      });

      _scheduleListenRetry();
    } finally {
      _listenStarting = false;
    }
  }

  Future<void> _finishListeningAndSend() async {
    if (!_isVoiceEnabled) return;
    if (_sendLocked) return;
    if (_isSending || _isTalking) return;

    final userText = _lastWords.trim();

    await _stopListening();

    if (userText.isEmpty) {
      await _restartListeningSafely();
      return;
    }

    final normalizedCurrent = userText.toLowerCase().trim();
    final normalizedLast = _lastSentText.toLowerCase().trim();

    if (normalizedCurrent == normalizedLast) {
      await _restartListeningSafely();
      return;
    }

    _sendLocked = true;
    _lastSentText = userText;
    _addHistory("child", userText);

    if (!mounted || _disposed) {
      _sendLocked = false;
      return;
    }

    setState(() {
      _status = "Avatar düşünüyor...";
      _isSending = true;
      _isTalking = false;
      _isListening = false;
      _lastWords = "";
      _addUserMessage(userText);
    });

    try {
      final botText = await _getBotReply(userText);

      if (!mounted || _disposed) {
        _sendLocked = false;
        return;
      }

      if (botText.isEmpty) {
        throw Exception("Boş cevap geldi");
      }

      _addHistory("assistant", botText);

      try {
        await _saveChat(
          childMessage: userText,
          aiReply: botText,
        );
      } catch (e) {
        debugPrint("Firebase kayıt hatası ama sohbet devam ediyor: $e");
      }

      await _playTts(botText);
    } on TimeoutException catch (e) {
      debugPrint("Timeout error: $e");

      if (!mounted || _disposed) {
        _sendLocked = false;
        return;
      }

      _cancelForceDoneTimer();
      _stopGirlTalkingLoop();

      setState(() {
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _lastWords = "";
        _status = "İstek uzun sürdü, tekrar deneyebilirsin.";
      });

      await _restartListeningSafely();
    } catch (e) {
      debugPrint("Send text error: $e");

      if (!mounted || _disposed) {
        _sendLocked = false;
        return;
      }

      _cancelForceDoneTimer();
      _stopGirlTalkingLoop();

      final err = e.toString();

      setState(() {
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _lastWords = "";

        if (err.contains("Chat API hata")) {
          _status = "Sunucu cevap veremedi, tekrar deneyebilirsin.";
        } else if (err.contains("TTS API hata")) {
          _status = "Ses hazırlanamadı, tekrar deneyebilirsin.";
        } else if (err.contains("SocketException") ||
            err.contains("ClientException") ||
            err.contains("XMLHttpRequest")) {
          _status = "Bağlantı sorunu var, tekrar deneyebilirsin.";
        } else {
          _status = "Bir sorun oldu, tekrar deneyebilirsin.";
        }
      });

      await _restartListeningSafely();
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _sendLocked = false;
    }
  }

  void _addUserMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final alreadyExists =
        _messages.isNotEmpty && _messages.last.text.trim() == clean;

    if (!alreadyExists) {
      _messages.add(_ChatBubbleMessage(text: clean));
    }
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {}

    if (!mounted || _disposed) return;

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _stopChat() async {
    await _clickSound();

    _cancelForceDoneTimer();
    _listenRetryTimer?.cancel();
    _stopGirlTalkingLoop();

    await _stopListening();
    await _audioPlayer.stop();

    if (!mounted || _disposed) return;

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _isTalking = false;
      _isListening = false;
      _isSending = false;
      _isVoiceEnabled = false;
      _sendLocked = false;
      _listenStarting = false;
      _lastWords = "";
      _lastSentText = "";
      _messages.clear();
      _chatHistory.clear();
      _status = "Sohbet kapalı";
      _currentGirlAsset = girlNormalAsset;
    });
  }

  Future<void> _saveChat({
    required String childMessage,
    required String aiReply,
  }) async {
    final child = childMessage.trim();
    final reply = aiReply.trim();

    if (child.isEmpty || reply.isEmpty) return;

    await ChatService.saveMessage(
      childMessage: child,
      aiReply: reply,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted || _disposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _cancelForceDoneTimer();
      _listenRetryTimer?.cancel();
      _stopGirlTalkingLoop();

      await _stopListening();
      await _audioPlayer.stop();

      if (!mounted || _disposed) return;

      setState(() {
        _isTalking = false;
        _isSending = false;
        _isListening = false;
        _listenStarting = false;
        _lastWords = "";
      });
    }

    if (state == AppLifecycleState.resumed &&
        _isVoiceEnabled &&
        _isConnected &&
        !_isTalking &&
        !_isListening &&
        !_isSending) {
      await _restartListeningSafely();
    }
  }

  @override
  void dispose() {
    _disposed = true;

    WidgetsBinding.instance.removeObserver(this);

    _silenceTimer?.cancel();
    _forceDoneTimer?.cancel();
    _listenRetryTimer?.cancel();
    _girlTalkTimer?.cancel();
    _girlBlinkTimer?.cancel();

    try {
      _speech.stop();
    } catch (_) {}

    try {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    } catch (_) {}

    super.dispose();
  }

Widget _buildAvatar() {
  return AvatarView(
    isTalking: _isTalking,
    isListening: _isListening,
    isVoiceEnabled: _isVoiceEnabled,
    gender: _gender,
    onVoiceToggle: _isConnected ? _toggleVoice : null,
  );
}

  Widget _buildChatBubble(_ChatBubbleMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: const BoxDecoration(
          color: Color(0xFFFFD54F),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 3),
              color: Color(0x12000000),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3B2F00),
            height: 1.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String infoText = !_isConnected
        ? "Başlatınca avatar önce sana soru soracak."
        : !_isVoiceEnabled
            ? "Ses kapalı. Konuşacağın zaman Sesi Aç."
            : _isTalking
                ? "Avatar konuşuyor..."
                : _isListening
                    ? "Seni dinliyor..."
                    : _isSending
                        ? "Avatar düşünüyor..."
                        : "Ses açık. Konuşabilirsin.";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Avatar Sohbeti"),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAvatar(),
                const SizedBox(height: 18),
                Text(
                  _avatarName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  infoText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _messages.isEmpty
                      ? Text(
                          "Sen konuşunca sadece senin mesajların burada görünecek.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : Column(
                          children: _messages.map(_buildChatBubble).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                if (_lastWords.isNotEmpty && !_isTalking && !_isSending)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      "Sen: $_lastWords",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isConnected ? Colors.green : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed:
                          (_isConnecting || _isConnected) ? null : _startChat,
                      child: Text(
                        _isConnecting ? "Bağlanıyor..." : "Avatarı Başlat",
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isConnected ? _toggleVoice : null,
                      icon: Icon(
                        _isVoiceEnabled
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                      ),
                      label: Text(
                        _isVoiceEnabled ? "Sesi Kapat" : "Sesi Aç",
                      ),
                    ),
                    OutlinedButton(
                      onPressed:
                          (_isConnected || _isConnecting) ? _stopChat : null,
                      child: const Text("Durdur"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}