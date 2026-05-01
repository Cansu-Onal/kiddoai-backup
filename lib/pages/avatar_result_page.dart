import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddoai/pages/home_page.dart';
import 'package:kiddoai/services/realtime_service.dart';

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
  final RealtimeService _rt = RealtimeService();

  bool _isTalking = false;
  bool _hasSpoken = false;

  String _status = "Avatar hazır";

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _handleTap(Future<void> Function() action) async {
    await _clickSound();
    await action();
  }

  String _buildIntroText() {
    return "Merhaba ${widget.nickname}! "
        "Ben ${widget.favorite}. "
        "Artık senin oyun, masal ve sohbet arkadaşınım. "
        "Birlikte çok eğlenceli şeyler yapacağız.";
  }

  Future<void> _startAvatarIntro() async {
    if (_isTalking) return;

    setState(() {
      _isTalking = true;
      _status = "Avatar sesi hazırlanıyor...";
    });

    await _rt.speakAvatarText(
      text: _buildIntroText(),
      nickname: widget.nickname,
      personality: widget.personality,
      avatarName: widget.favorite,
      saveToPanel: false,
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _rt.onStatus = (msg) {
      if (!mounted) return;
      setState(() => _status = msg);
    };

    _rt.onEvent = (e) {
      if (!mounted) return;

      final type = e["type"]?.toString();

      if (type == "assistant_audio_start") {
        setState(() {
          _isTalking = true;
          _status = "Avatar konuşuyor...";
        });
        return;
      }

      if (type == "assistant_done") {
        setState(() {
          _isTalking = false;
          _hasSpoken = true;
          _status = "Tanıtım tamamlandı";
        });
        return;
      }

      if (type == "assistant_error") {
        final errorMessage = (e["message"] ?? "").toString();

        setState(() {
          _isTalking = false;
          _status = errorMessage.isEmpty
              ? "Ses oynatılamadı"
              : "Ses oynatılamadı: $errorMessage";
        });
        return;
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _rt.onStatus = null;
    _rt.onEvent = null;
    _rt.dispose();

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
                AnimatedAvatar(
                  isTalking: _isTalking,
                  width: 280,
                ),
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
                      onPressed: _isTalking
                          ? null
                          : () => _handleTap(_startAvatarIntro),
                      child: Text(startLabel),
                    ),
                    FilledButton.tonal(
                      onPressed: () => _handleTap(() async {
                        if (!mounted) return;

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
                        if (!mounted) return;
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