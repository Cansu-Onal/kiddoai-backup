import 'package:flutter/material.dart';

class PermissionsInfoPage extends StatelessWidget {
  const PermissionsInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF9C4);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Ebeveyn Bilgilendirmesi",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF6B4E00),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF6B4E00),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "KiddoLia Nedir?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B4E00),
                ),
              ),

              SizedBox(height: 14),

              Text(
                "KiddoLia; çocukların güvenli, eğitici ve eğlenceli şekilde "
                "yapay zekâ destekli içeriklerle etkileşim kurabilmesi için "
                "geliştirilmiş bir çocuk uygulamasıdır. "
                "Uygulama içerisinde sesli sohbet, interaktif masallar, "
                "çizim-boyama etkinlikleri ve gelişim destekleyici mini oyunlar bulunmaktadır.",
                style: TextStyle(
                  fontSize: 16,
                  height: 1.55,
                  color: Color(0xFF4E3600),
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 26),

              _InfoCard(
                title: "Ses ve Mikrofon Kullanımı",
                icon: Icons.mic_rounded,
                text:
                    "Uygulama, çocuk ile sesli etkileşim kurabilmek için mikrofon erişimi isteyebilir. "
                    "Bu özellik sayesinde çocuk konuşabilir ve avatar doğal sesli yanıtlar verebilir. "
                    "Ses kayıtları yalnızca uygulama deneyimini sağlamak amacıyla kullanılır.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "Yapay Zekâ Destekli Sohbet",
                icon: Icons.smart_toy_rounded,
                text:
                    "KiddoLia içerisindeki avatar sistemi çocukların yaş grubuna uygun, "
                    "yumuşak ve güvenli cevaplar üretmek üzere tasarlanmıştır. "
                    "Sistem zararlı, korkutucu veya yetişkin içeriklerini filtrelemek için "
                    "ek güvenlik kuralları kullanır.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "İnteraktif Masallar ve Oyunlar",
                icon: Icons.auto_stories_rounded,
                text:
                    "Masal ve senaryo içerikleri çocukların hayal gücünü, "
                    "iletişim becerilerini ve problem çözme yeteneklerini desteklemek amacıyla hazırlanmıştır. "
                    "Çocuğun yaptığı seçimler yalnızca gelişimsel gözlem amacıyla değerlendirilir.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "Çizim ve Boyama Özellikleri",
                icon: Icons.palette_rounded,
                text:
                    "Çocukların yaptığı çizimler ve boyamalar ebeveyn panelinde "
                    "kısa süreli olarak saklanabilir. "
                    "Kayıtlı içerikler belirli süre sonunda otomatik olarak silinir.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "Ebeveyn Paneli",
                icon: Icons.family_restroom_rounded,
                text:
                    "Ebeveyn paneli sayesinde günlük konuşma özetleri, "
                    "masal sonuçları ve çizim etkinlikleri görüntülenebilir. "
                    "Bu bilgiler yalnızca ebeveynin erişimine açıktır.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "Veri Güvenliği",
                icon: Icons.shield_rounded,
                text:
                    "KiddoLia içerisinde saklanan bilgiler çocuk güvenliği ön planda tutularak korunur. "
                    "Uygulama kişisel verileri minimum seviyede kullanmayı hedefler "
                    "ve gereksiz verileri belirli süre sonunda otomatik olarak temizler.",
              ),

              SizedBox(height: 18),

              _InfoCard(
                title: "Önemli Bilgilendirme",
                icon: Icons.info_rounded,
                text:
                    "KiddoLia bir psikolojik tanı veya profesyonel danışmanlık sistemi değildir. "
                    "Uygulama yalnızca eğitici ve destekleyici dijital deneyim sunmak amacıyla geliştirilmiştir.",
              ),

              SizedBox(height: 32),

              Center(
                child: Text(
                  "KiddoLia 💛",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE0A100),
                  ),
                ),
              ),

              SizedBox(height: 8),

              Center(
                child: Text(
                  "Keşfet • Oyna • Öğren • Eğlen",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9C7B1C),
                  ),
                ),
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB8860B),
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B4E00),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF4E3600),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}