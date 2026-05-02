import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kiddoai/pages/art_page.dart';
import 'package:kiddoai/pages/chat_avatar_page.dart';
import 'package:kiddoai/pages/global_usage_guard.dart';
import 'package:kiddoai/pages/parent_panel_page.dart';
import 'package:kiddoai/pages/story_mode_page.dart';
import 'package:kiddoai/pages/music_page.dart';
import 'package:kiddoai/pages/beach_scenario_page.dart';

class HomePage extends StatefulWidget {
  final String nickname;
  final String personality;
  final int dailyLimitMinutes;

  const HomePage({
    super.key,
    required this.nickname,
    required this.personality,
    required this.dailyLimitMinutes,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _showParentPasswordDialog() async {
    final controller = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text("Ebeveyn Girişi"),
              content: TextField(
                controller: controller,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: "Firebase şifrenizi girin",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  Navigator.pop(dialogContext, controller.text.trim());
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Vazgeç"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, controller.text.trim());
                  },
                  child: const Text("Giriş"),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _handleParentEntry() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showSnack("Önce giriş yapmanız gerekiyor.");
      return;
    }

    final password = await _showParentPasswordDialog();

    if (!mounted) return;
    if (password == null) return;

    if (password.isEmpty) {
      _showSnack("Lütfen şifre girin.");
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ParentPanelPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showSnack("Şifre yanlış.");
      } else if (e.code == 'network-request-failed') {
        _showSnack("İnternet bağlantınızı kontrol edin.");
      } else {
        _showSnack("Giriş başarısız: ${e.message ?? e.code}");
      }
    } catch (_) {
      _showSnack("Şifre doğrulanamadı.");
    }
  }

  List<_HomeMenuItem> _buildMenuItems(BuildContext context) {
    return [
      _HomeMenuItem(
        title: "Masal",
        image: "assets/icons/story.png",
        color: const Color(0xFFFFB74D),
        onTap: () async {
          await _clickSound();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoryModePage(
                nickname: widget.nickname,
                personality: widget.personality,
                avatarName: "Arkadaşın",
              ),
            ),
          );
        },
      ),
      _HomeMenuItem(
        title: "Şarkı",
        image: "assets/icons/music.png",
        color: const Color(0xFFF48FB1),
        onTap: () async {
          await _clickSound();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MusicPage(),
            ),
          );
        },
      ),
      _HomeMenuItem(
        title: "Sohbet",
        image: "assets/icons/chat.png",
        color: const Color(0xFF81C784),
        onTap: () async {
          await _clickSound();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatAvatarPage(
                nickname: widget.nickname,
                personality: widget.personality,
                dailyLimitMinutes: widget.dailyLimitMinutes,
              ),
            ),
          );
        },
      ),
      _HomeMenuItem(
        title: "Deniz Oyunu",
        image: "assets/icons/beach.jpeg",
        color: const Color(0xFF64B5F6),
        onTap: () async {
          await _clickSound();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BeachScenarioPage(),
            ),
          );
        },
      ),
      _HomeMenuItem(
        title: "Resim",
        image: "assets/icons/paint.png",
        color: const Color(0xFFBA68C8),
        onTap: () async {
          await _clickSound();
          if (!context.mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ArtPage(),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFFFF9C4);
    final items = _buildMenuItems(context);

    return GlobalUsageGuard(
      dailyLimitMinutes: widget.dailyLimitMinutes,
      avatarName: "Arkadaşın",
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "Merhaba ${widget.nickname} 🌈",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5B3A00),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.personality == "Sakin"
                          ? "Bugün birlikte sakin sakin ne yapmak istersin?"
                          : "Bugün ne yapmak istersin?",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C5A00),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Günlük kullanım süresi: ${widget.dailyLimitMinutes} dk",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A6A00),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final height = constraints.maxHeight;
                          const int crossAxisCount = 2;
                          final double childAspectRatio =
                              height < 500 ? 0.82 : 0.95;

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: items.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];

                              return _HomeCard(
                                title: item.title,
                                image: item.image,
                                color: item.color,
                                onTap: item.onTap,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      await _clickSound();
                      if (!mounted) return;
                      await _handleParentEntry();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7F7F7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            offset: Offset(0, 3),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        size: 22,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMenuItem {
  final String title;
  final String image;
  final Color color;
  final Future<void> Function() onTap;

  _HomeMenuItem({
    required this.title,
    required this.image,
    required this.color,
    required this.onTap,
  });
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String image;
  final Color color;
  final Future<void> Function() onTap;

  const _HomeCard({
    required this.title,
    required this.image,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(
                    image,
                    width: 78,
                    height: 78,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
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