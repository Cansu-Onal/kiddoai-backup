import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddoai/pages/home_page.dart';
import 'package:kiddoai/services/elevenlabs_voice_service.dart';

import 'avatar_animated_widget.dart';

class AvatarResultPage extends StatefulWidget {
  final String avatarAsset;
  final String nickname;
  final String gender;
  final String personality;
  final String favorite;
  final String style;
  final int dailyLimitMinutes;

  const AvatarResultPage({
    super.key,
    required this.avatarAsset,
    required this.nickname,
    required this.gender,
    required this.personality,
    required this.favorite,
    required this.style,
    required this.dailyLimitMinutes,
  });

  @override
  State<AvatarResultPage> createState() => _AvatarResultPageState();
}

class _AvatarResultPageState extends State<AvatarResultPage>
    with WidgetsBindingObserver {
  final ElevenLabsVoiceService _voice = ElevenLabsVoiceService();

  bool _isTalking = false;
  bool _hasSpoken = false;
  bool _disposed = false;

  String _status = "Avatar hazır";

  Timer? _girlTalkTimer;
  bool _showGirlTalking = false;

  static const String girlNormalAsset = "assets/avatars/normal_kiz.png";
  static const String girlTalkingAsset = "assets/avatars/konusan_kiz.png";

  bool get _isGirl => widget.gender == "Kız";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  String _buildIntroText() {
    return "Merhaba ${widget.nickname}! "
        "Ben ${widget.favorite}. "
        "Artık senin oyun, masal ve sohbet arkadaşınım. "
        "Birlikte çok eğlenceli şeyler yapacağız.";
  }

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _handleTap(Future<void> Function() action) async {
    await _clickSound();
    await action();
  }

  void _startGirlTalkingLoop() {
    _girlTalkTimer?.cancel();

    setState(() {
      _showGirlTalking = true;
    });

    _girlTalkTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted || _disposed || !_isTalking) return;

      setState(() {
        _showGirlTalking = !_showGirlTalking;
      });
    });
  }

  void _stopGirlTalkingLoop() {
    _girlTalkTimer?.cancel();
    _girlTalkTimer = null;

    if (!mounted || _disposed) return;

    setState(() {
      _showGirlTalking = false;
    });
  }

  Future<void> _startAvatarIntro() async {
    if (_isTalking || _disposed) return;

    setState(() {
      _isTalking = true;
      _status = "Avatar sesi hazırlanıyor...";
    });

    if (_isGirl) {
      _startGirlTalkingLoop();
    }

    try {
      if (_isGirl) {
        await _voice.speak(
  _buildIntroText(),
  gender: widget.gender,
);
      } else {
        await _voice.speak(_buildIntroText());
      }

      if (!mounted || _disposed) return;

      _stopGirlTalkingLoop();

      setState(() {
        _isTalking = false;
        _hasSpoken = true;
        _status = "Tanıtım tamamlandı";
      });
    } catch (e) {
      if (!mounted || _disposed) return;

      _stopGirlTalkingLoop();

      setState(() {
        _isTalking = false;
        _status = "Ses oynatılamadı";
      });

      debugPrint("Avatar ses hatası: $e");
    }
  }

  Future<void> _stopVoice() async {
    try {
      await _voice.stop();
    } catch (_) {}

    _stopGirlTalkingLoop();

    if (!mounted || _disposed) return;

    setState(() {
      _isTalking = false;
      _status = "Avatar hazır";
    });
  }

  Widget _buildAvatarView() {
    if (_isGirl) {
      final String asset =
          _isTalking && _showGirlTalking ? girlTalkingAsset : girlNormalAsset;

      return SizedBox(
        width: 280,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person,
              size: 160,
              color: Colors.pink,
            );
          },
        ),
      );
    }

    return AnimatedAvatar(
      isTalking: _isTalking,
      width: 280,
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6A00),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3B2F00),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      await _stopVoice();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _girlTalkTimer?.cancel();
    _voice.stop();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String startLabel = _isTalking
        ? "Konuşuyor..."
        : (_hasSpoken ? "Tekrar Konuştur" : "Avatarı Başlat");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Avatarın Hazır"),
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
                _buildAvatarView(),
                const SizedBox(height: 18),
                Text(
                  "${widget.favorite} hazır! ✨",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isTalking
                      ? "${widget.favorite} kendini tanıtıyor... 🗣️"
                      : "${widget.favorite}, sana ${widget.nickname} diye seslenecek.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Günlük kullanım süresi: ${widget.dailyLimitMinutes} dk",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6A00),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoCard("Avatar Adı", widget.favorite),
                    _infoCard("Kişilik", widget.personality),
                    _infoCard("Tarz", widget.style),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isTalking ? Colors.green : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed:
                          _isTalking ? null : () => _handleTap(_startAvatarIntro),
                      child: Text(startLabel),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _handleTap(() async {
                        await _stopVoice();

                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HomePage(
                              nickname: widget.nickname,
                              personality: widget.personality,
                              dailyLimitMinutes: widget.dailyLimitMinutes,
                            ),
                          ),
                        );
                      }),
                      child: const Text("İleri"),
                    ),
                    OutlinedButton(
                      onPressed: () => _handleTap(() async {
                        await _stopVoice();

                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }),
                      child: const Text("Geri"),
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