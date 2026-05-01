import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../pages/avatar_animated_widget.dart';
import '../services/chat_service.dart';
import '../services/realtime_service.dart';

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
  final RealtimeService _rt = RealtimeService();
  final SpeechToText _speech = SpeechToText();

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isTalking = false;
  bool _isListening = false;
  bool _isSending = false;
  bool _speechReady = false;
  bool _firstGreetingSpoken = false;
  bool _savedThisTurn = false;

  String _status = "Sohbet hazır";
  String _lastWords = "";

  Timer? _silenceTimer;
  Timer? _forceDoneTimer;

  static const String _avatarName = "Arkadaşın";

  List<String> _profileInterests = [];
  List<String> _profileGoals = [];
  String _extraLike = "";

  final List<_ChatBubbleMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loadAvatarProfile();
    _initSpeech();

    _rt.onStatus = (msg) {
      if (!mounted) return;
      setState(() => _status = msg);
    };

    _rt.onConnected = () async {
      if (!mounted) return;

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _status = "Avatar hazırlanıyor...";
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _speakFirstGreeting();
    };

    _rt.onDisconnected = () async {
      if (!mounted) return;

      await _stopListening();
      _cancelForceDoneTimer();

      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _status = "Sohbet kapalı";
      });
    };

    _rt.onEvent = (e) async {
      if (!mounted) return;

      final type = e["type"]?.toString();

      if (type == "assistant_error") {
        await _stopListening();
        _cancelForceDoneTimer();

        if (!mounted) return;
        setState(() {
          _isTalking = false;
          _isListening = false;
          _isConnecting = false;
          _isSending = false;
          _status = "Avatar şu an konuşamıyor.";
        });

        await _restartListeningSafely();
        return;
      }

      if (type == "assistant_text") {
        await _stopListening();

        final text =
            (e["text"] ?? e["message"] ?? e["reply"] ?? "").toString().trim();

        final saveToPanel = e["saveToPanel"];
        final shouldSave = saveToPanel is bool ? saveToPanel : true;

        if (text.isNotEmpty) {
          setState(() {
            _status = "Avatar sesi hazırlanıyor...";
          });

          final userText = _lastWords.trim();

          if (shouldSave &&
              !_savedThisTurn &&
              userText.isNotEmpty &&
              text.isNotEmpty) {
            _savedThisTurn = true;

            await _saveChat(
              childMessage: userText,
              aiReply: text,
            );
          }
        }

        return;
      }

      if (type == "assistant_audio_start") {
        await _stopListening();

        if (!mounted) return;

        setState(() {
          _isTalking = true;
          _isListening = false;
          _isSending = false;
          _status = "Avatar konuşuyor...";
        });

        _startForceDoneTimer();
        return;
      }

      if (type == "assistant_done") {
        await _finishAssistantTurn();
        return;
      }
    };
  }

  Future<void> _finishAssistantTurn() async {
    _cancelForceDoneTimer();

    if (!mounted) return;

    setState(() {
      _isTalking = false;
      _isSending = false;
      _status = "Seni dinliyor...";
    });

    await _restartListeningSafely();
  }

  void _startForceDoneTimer() {
    _cancelForceDoneTimer();

    _forceDoneTimer = Timer(const Duration(seconds: 18), () async {
      if (!mounted) return;
      if (!_isConnected) return;
      if (!_isTalking && !_isSending) return;

      await _finishAssistantTurn();
    });
  }

  void _cancelForceDoneTimer() {
    _forceDoneTimer?.cancel();
    _forceDoneTimer = null;
  }

  Future<void> _restartListeningSafely() async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    if (_isConnected && !_isTalking && !_isSending && !_isListening) {
      await _startListening();
    }
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

      if (!mounted) return;

      setState(() {
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

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == "listening") {
            setState(() => _isListening = true);
          }

          if (status == "notListening" || status == "done") {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;

          debugPrint("Speech error: $error");

          setState(() {
            _isListening = false;
            _status = "Mikrofon dinleme hatası";
          });
        },
      );
    } catch (e) {
      debugPrint("Speech init error: $e");
      _speechReady = false;
    }
  }

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _startChat() async {
    if (_isConnecting || _isConnected) return;

    await _clickSound();
    await _loadAvatarProfile();

    setState(() {
      _isConnecting = true;
      _isTalking = false;
      _isListening = false;
      _isSending = false;
      _firstGreetingSpoken = false;
      _savedThisTurn = false;
      _lastWords = "";
      _messages.clear();
      _status = "Bağlanıyor...";
    });

    try {
      await _rt.connectAndStartChat(
        nickname: widget.nickname,
        personality: widget.personality,
        avatarName: _avatarName,
        interests: _profileInterests,
        goals: _profileGoals,
      );
    } catch (e) {
      debugPrint("Realtime connection error: $e");

      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _status = "Bağlantı hatası";
      });
    }
  }

  Future<void> _speakFirstGreeting() async {
    if (!_isConnected || _firstGreetingSpoken || _isSending || _isTalking) {
      return;
    }

    final interestText = _getMainInterest();

    final greeting = interestText.isEmpty
        ? "Merhaba ${widget.nickname}. Bugün nasılsın? Bana bugün neler yaptığını anlatır mısın?"
        : "Merhaba ${widget.nickname}. Bugün nasılsın? İstersen birazdan $interestText hakkında sohbet edebiliriz.";

    setState(() {
      _firstGreetingSpoken = true;
      _isSending = true;
      _savedThisTurn = true;
      _lastWords = "";
      _status = "Avatar konuşmaya başlıyor...";
    });

    await _rt.speakAvatarText(
      text: greeting,
      nickname: widget.nickname,
      personality: widget.personality,
      avatarName: _avatarName,
      saveToPanel: false,
    );
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

  Future<void> _startListening() async {
    if (!_isConnected || _isTalking || _isListening || _isSending) return;

    if (!_speechReady) {
      await _initSpeech();
    }

    if (!_speechReady) {
      if (!mounted) return;
      setState(() => _status = "Mikrofon başlatılamadı");
      return;
    }

    _lastWords = "";

    setState(() {
      _isListening = true;
      _status = "Seni dinliyor...";
    });

    try {
      await _speech.listen(
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: "tr_TR",
        onResult: (result) {
          final text = result.recognizedWords.trim();

          if (!mounted) return;
          if (_isTalking || _isSending) return;

          if (text.isNotEmpty) {
            setState(() {
              _lastWords = text;
            });

            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(seconds: 2), () async {
              await _finishListeningAndSend();
            });
          }
        },
      );
    } catch (e) {
      debugPrint("Speech listen error: $e");

      if (!mounted) return;

      setState(() {
        _isListening = false;
        _status = "Mikrofon dinleme hatası";
      });
    }
  }

  Future<void> _finishListeningAndSend() async {
    if (_isSending || _isTalking) return;

    final text = _lastWords.trim();

    await _stopListening();

    if (text.isEmpty) {
      await _restartListeningSafely();
      return;
    }

    if (!mounted) return;

    setState(() {
      _status = "Avatar düşünüyor...";
      _isSending = true;
      _savedThisTurn = false;
      _addUserMessage(text);
    });

    try {
      await _rt.sendText(text).timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint("Send text error: $e");

      if (!mounted) return;

      _cancelForceDoneTimer();

      setState(() {
        _isTalking = false;
        _isListening = false;
        _isSending = false;
        _status = "Cevap gecikti. Tekrar deneyebilirsin.";
      });

      await _restartListeningSafely();
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
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  Future<void> _stopChat() async {
    await _clickSound();
    _cancelForceDoneTimer();
    await _stopListening();
    await _rt.disconnect();
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
    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _cancelForceDoneTimer();
      await _stopListening();
    }

    if (state == AppLifecycleState.resumed &&
        _isConnected &&
        !_isTalking &&
        !_isListening &&
        !_isSending) {
      await _startListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _silenceTimer?.cancel();
    _forceDoneTimer?.cancel();

    _rt.onStatus = null;
    _rt.onConnected = null;
    _rt.onDisconnected = null;
    _rt.onEvent = null;

    _speech.stop();
    _rt.dispose();

    super.dispose();
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
        : _isTalking
            ? "Avatar konuşuyor..."
            : _isListening
                ? "Seni dinliyor..."
                : _isSending
                    ? "Avatar düşünüyor..."
                    : "Sohbet açık.";

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
                AnimatedAvatar(
                  isTalking: _isTalking,
                  width: 280,
                ),
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
                if (_lastWords.isNotEmpty)
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