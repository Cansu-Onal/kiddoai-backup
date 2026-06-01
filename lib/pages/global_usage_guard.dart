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

class GlobalUsageGuard extends StatefulWidget {
  final Widget child;
  final int dailyLimitMinutes;
  final String avatarName;

  const GlobalUsageGuard({
    super.key,
    required this.child,
    required this.dailyLimitMinutes,
    required this.avatarName,
  });

  @override
  State<GlobalUsageGuard> createState() => _GlobalUsageGuardState();
}

class _GlobalUsageGuardState extends State<GlobalUsageGuard> {
  Timer? _timer;
  Timer? _closeTimer;
  Timer? _girlFrameTimer;

  final AudioPlayer _player = AudioPlayer();

  bool _limitReached = false;
  bool _isSpeaking = false;
  bool _speechStarted = false;
  bool _girlToggle = false;

  String _gender = "Erkek";

  static const String _boyIdleGif = "assets/avatars/kiddo_avatar_blink.gif";
  static const String _boyTalkingGif =
      "assets/avatars/kiddo_avatar_talking_natural.gif";

  static const String _girlNormal = "assets/avatars/normal_kiz.png";
  static const String _girlTalking = "assets/avatars/konusan_kiz.png";
  static const String _girlBlink = "assets/avatars/goz_kapali_kiz.png";

  bool get _isGirl => _gender == "Kız";

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  @override
  void initState() {
    super.initState();
    _loadGender();

    _timer = Timer(
      Duration(minutes: widget.dailyLimitMinutes),
      () {
        if (!mounted) return;

        setState(() {
          _limitReached = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startGoodbyeFlow();
        });
      },
    );
  }

  Future<void> _loadGender() async {
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
      debugPrint("GlobalUsageGuard gender okunamadı: $e");
    }
  }

  void _startGirlFrameLoop() {
    _girlFrameTimer?.cancel();

    if (!_isGirl) return;

    _girlFrameTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted) return;

      setState(() {
        _girlToggle = !_girlToggle;
      });
    });
  }

  void _stopGirlFrameLoop() {
    _girlFrameTimer?.cancel();
    _girlFrameTimer = null;

    if (!mounted) return;

    setState(() {
      _girlToggle = false;
    });
  }

  String _currentAvatarAsset() {
    if (_isGirl) {
      if (_isSpeaking) {
        return _girlToggle ? _girlTalking : _girlNormal;
      }

      return _girlBlink;
    }

    return _isSpeaking ? _boyTalkingGif : _boyIdleGif;
  }

  Future<void> _startGoodbyeFlow() async {
    if (_speechStarted) return;
    _speechStarted = true;

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    await _speakGoodbye();

    _closeTimer = Timer(const Duration(seconds: 2), () {
      SystemNavigator.pop();
    });
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
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception("TTS error: ${response.statusCode}");
    }

    return response.bodyBytes;
  }

  Future<void> _speakGoodbye() async {
    if (_isSpeaking) return;

    setState(() {
      _isSpeaking = true;
    });

    if (_isGirl) {
      _startGirlFrameLoop();
    }

    try {
      final text =
          "Benim gitme vaktim geldi. Bugünlük bu kadar yeterli. Görüşürüz.";

      final bytes = await _getTtsBytes(text);

      if (!mounted) return;

      await _player.stop();
      await _player.play(BytesSource(bytes));
      await _player.onPlayerComplete.first;
    } catch (e) {
      debugPrint("Goodbye speech error: $e");
      await Future.delayed(const Duration(seconds: 4));
    }

    if (!mounted) return;

    _stopGirlFrameLoop();

    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _closeTimer?.cancel();
    _girlFrameTimer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitReached) {
      return widget.child;
    }

    final avatarAsset = _currentAvatarAsset();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 260,
                    height: 330,
                    child: Image.asset(
                      avatarAsset,
                      key: ValueKey(avatarAsset),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.face_rounded,
                          size: 150,
                          color: Color(0xFFE0A100),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Benim gitme vaktim geldi 🌙",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5B3A00),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Bugünlük bu kadar yeterli. Görüşürüz!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D4C41),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isSpeaking
                        ? "Avatar konuşuyor..."
                        : "Uygulama birazdan kapanacak.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}