import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class DailyUsageGuard extends StatefulWidget {
  final Widget child;
  final int dailyLimitMinutes;
  final String avatarName;

  const DailyUsageGuard({
    super.key,
    required this.child,
    required this.dailyLimitMinutes,
    required this.avatarName,
  });

  @override
  State<DailyUsageGuard> createState() => _DailyUsageGuardState();
}

class _DailyUsageGuardState extends State<DailyUsageGuard> {
  Timer? _timer;
  Timer? _closeTimer;

  final AudioPlayer _player = AudioPlayer();

  bool _limitReached = false;
  bool _isSpeaking = false;
  bool _speechStarted = false;

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  static const String _avatarImage = "assets/avatars/boy_normal.png";

  @override
  void initState() {
    super.initState();

    _timer = Timer(Duration(minutes: widget.dailyLimitMinutes), () {
      if (!mounted) return;

      setState(() {
        _limitReached = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGoodbyeFlow();
      });
    });
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
          body: jsonEncode({"text": text}),
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

    try {
      const text =
          "Benim artık gitmem lazım. Bugünlük bu kadar yeterli. "
          "Yarın yine görüşürüz. Görüşürüz, seni seviyorum.";

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

    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _closeTimer?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitReached) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 300,
                  height: 360,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 8),
                        color: Color(0x22000000),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    _avatarImage,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.face_rounded,
                        size: 160,
                        color: Color(0xFF7E57C2),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 22),

                const Text(
                  "Benim artık gitmem lazım.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5B3A00),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Bugünlük bu kadar yeterli. Yarın yine görüşürüz. Seni seviyorum.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6D4C41),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  _isSpeaking
                      ? "Sesli veda ediyorum..."
                      : "Uygulama birazdan kapanacak.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}