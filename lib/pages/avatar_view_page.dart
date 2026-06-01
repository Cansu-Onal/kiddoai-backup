import 'dart:async';
import 'package:flutter/material.dart';

import 'room_explore_page.dart';

class AvatarView extends StatefulWidget {
  final bool isTalking;
  final bool isListening;
  final String gender;

  final bool isVoiceEnabled;
  final VoidCallback? onVoiceToggle;

  const AvatarView({
    super.key,
    required this.isTalking,
    required this.isListening,
    this.gender = "Erkek",
    this.isVoiceEnabled = true,
    this.onVoiceToggle,
  });

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> {
  Timer? _girlTimer;
  bool _toggleGirlFrame = false;

  static const String boyIdleGif = "assets/avatars/kiddo_avatar_blink.gif";
  static const String boyTalkingGif =
      "assets/avatars/kiddo_avatar_talking_natural.gif";

  static const String girlNormal = "assets/avatars/normal_kiz.png";
  static const String girlTalking = "assets/avatars/konusan_kiz.png";
  static const String girlBlink = "assets/avatars/goz_kapali_kiz.png";

  bool get _isGirl => widget.gender == "Kız";

  @override
  void initState() {
    super.initState();
    _updateGirlLoop();
  }

  @override
  void didUpdateWidget(covariant AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isTalking != widget.isTalking ||
        oldWidget.isListening != widget.isListening ||
        oldWidget.gender != widget.gender ||
        oldWidget.isVoiceEnabled != widget.isVoiceEnabled) {
      _updateGirlLoop();
    }
  }

  void _updateGirlLoop() {
    _girlTimer?.cancel();
    _girlTimer = null;

    if (!_isGirl) return;

    if (widget.isTalking) {
      _girlTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
        if (!mounted) return;
        setState(() {
          _toggleGirlFrame = !_toggleGirlFrame;
        });
      });
      return;
    }

    if (widget.isListening && widget.isVoiceEnabled) {
      _girlTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
        if (!mounted) return;
        setState(() {
          _toggleGirlFrame = !_toggleGirlFrame;
        });
      });
      return;
    }

    setState(() {
      _toggleGirlFrame = false;
    });
  }

  String _currentAvatarAsset() {
    if (_isGirl) {
      if (widget.isTalking) {
        return _toggleGirlFrame ? girlTalking : girlNormal;
      }

      if (widget.isListening && widget.isVoiceEnabled) {
        return _toggleGirlFrame ? girlBlink : girlNormal;
      }

      return girlNormal;
    }

    return widget.isTalking ? boyTalkingGif : boyIdleGif;
  }

  @override
  void dispose() {
    _girlTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String statusText = widget.isTalking
        ? "Konuşuyor"
        : widget.isListening && widget.isVoiceEnabled
            ? "Dinliyor"
            : widget.isVoiceEnabled
                ? "Hazır"
                : "Ses Kapalı";

    final String currentAvatar = _currentAvatarAsset();

    return SizedBox(
      width: 320,
      height: 420,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 320,
              height: 420,
              color: const Color(0xFFF6F7FB),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  currentAvatar,
                  key: ValueKey(currentAvatar),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.face_rounded,
                        size: 100,
                        color: Color(0xFF5B3A00),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          Positioned(
            right: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TopButton(
                  icon: Icons.home_rounded,
                  text: "Odayı Keşfet",
                  color: const Color(0xFFFFD54F),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoomExplorePage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _TopButton(
                  icon: widget.isVoiceEnabled
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  text: widget.isVoiceEnabled ? "Sesi Kapat" : "Sesi Aç",
                  color: widget.isVoiceEnabled
                      ? const Color(0xFFFFCC80)
                      : const Color(0xFFE0E0E0),
                  onTap: widget.onVoiceToggle,
                ),
              ],
            ),
          ),

          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 3),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !widget.isVoiceEnabled
                        ? Icons.mic_off_rounded
                        : widget.isTalking
                            ? Icons.volume_up_rounded
                            : widget.isListening
                                ? Icons.hearing_rounded
                                : Icons.face_rounded,
                    color: const Color(0xFF5B3A00),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5B3A00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;

  const _TopButton({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: const Color(0xFF5B3A00),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5B3A00),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}