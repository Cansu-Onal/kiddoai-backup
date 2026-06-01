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
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 760;

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(isWide ? 28 : 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "Nasıl masal dinlemek istersin?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5B3A00),
                      ),
                    ),
                    SizedBox(height: isWide ? 30 : 20),

                    // BÜYÜK EKRAN
                    if (isWide)
                      SizedBox(
                        height: constraints.maxHeight * 0.68,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModeCard(
                                title: "Klasik Masal",
                                subtitle: "Masalı dinle",
                                imagePath: "assets/story/klasik.jpg",
                                fallbackColor: const Color(0xFFFFB74D),
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
                            const SizedBox(width: 18),
                            Expanded(
                              child: _ModeCard(
                                title: "İnteraktif",
                                subtitle: "Seçerek ilerle",
                                imagePath: "assets/story/inter_masal.jpg",
                                fallbackColor: const Color(0xFF81C784),
                                onTap: () async {
                                  await _clickSound();

                                  if (!context.mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const InteractiveStoryPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )

                    // KÜÇÜK EKRAN
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 260,
                            child: _ModeCard(
                              title: "Klasik Masal",
                              subtitle: "Masalı dinle",
                              imagePath: "assets/story/klasik.jpg",
                              fallbackColor: const Color(0xFFFFB74D),
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
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 260,
                            child: _ModeCard(
                              title: "İnteraktif",
                              subtitle: "Seçerek ilerle",
                              imagePath: "assets/story/inter_masal.jpg",
                              fallbackColor: const Color(0xFF81C784),
                              onTap: () async {
                                await _clickSound();

                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const InteractiveStoryPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color fallbackColor;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.fallbackColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Material(
      color: fallbackColor,
      borderRadius: BorderRadius.circular(30),
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,

                // KÜÇÜK EKRAN → tamamı görünsün
                // BÜYÜK EKRAN → kartı doldursun
                fit: isSmallScreen ? BoxFit.contain : BoxFit.cover,

                alignment: Alignment.center,

                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: fallbackColor,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 10,
                            color: Colors.black,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Colors.black,
                          offset: Offset(0, 1),
                        ),
                      ],
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