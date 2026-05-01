import 'package:flutter/material.dart';
import 'package:kiddoai/pages/paint_page.dart';
import 'package:kiddoai/pages/draw_page.dart';


class ArtPage extends StatelessWidget {
  const ArtPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9C4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF9C4),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF5B3A00)),
        title: const Text(
          "Resim",
          style: TextStyle(
            color: Color(0xFF5B3A00),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Ne yapmak istersin?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C5A00),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _ArtOptionCard(
                      title: "Boyama",
                      icon: Icons.palette_rounded,
                      color: const Color(0xFFFFCC80),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaintPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _ArtOptionCard(
                      title: "Çizim",
                      icon: Icons.brush_rounded,
                      color: const Color(0xFFB39DDB),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DrawPage(),
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

class _ArtOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ArtOptionCard({
    required this.title,
    required this.icon,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 70,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
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