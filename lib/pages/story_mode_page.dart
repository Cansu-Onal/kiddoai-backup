import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kiddoai/pages/story_page.dart';
import 'package:kiddoai/pages/interactive_story_page.dart';

class StoryModePage extends StatelessWidget {
  final String nickname;
  final String personality;
  final String avatarName;

  const StoryModePage({
    super.key,
    required this.nickname,
    required this.personality,
    required this.avatarName,
  });

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB74D),
        title: const Text(
          "Masal Seç",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Nasıl masal dinlemek istersin?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5B3A00),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _ModeCard(
                      title: "Klasik Masal",
                      emoji: "📖",
                      color: const Color(0xFFFFB74D),
                      subtitle: "Masalı dinle",
                      onTap: () async {
                        await _clickSound();
                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoryPage(
                              nickname: nickname,
                              personality: personality,
                              avatarName: avatarName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ModeCard(
                      title: "İnteraktif",
                      emoji: "🎮",
                      color: const Color(0xFF81C784),
                      subtitle: "Seçerek ilerle",
                      onTap: () async {
                        await _clickSound();
                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InteractiveStoryPage(),
                          ),
                        );
                      },
                    ),
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

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 58),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}