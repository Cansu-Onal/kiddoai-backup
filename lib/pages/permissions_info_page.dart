import 'package:flutter/material.dart';

class PermissionsInfoPage extends StatelessWidget {
  const PermissionsInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF9C4);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(title: const Text("İzinler"), centerTitle: true),
      body: const Padding(
        padding: EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Text(
            "Ebeveyn Bilgilendirme (Şimdilik taslak):\n\n"
            "• Uygulama sesli yanıt verebilir.\n"
            "• Çocukla sohbet/masal/oyun içerikleri sunabilir.\n"
            "• Kullanım öncesi ebeveyn onayı gerekir.\n\n"
            "Bu sayfa daha sonra detaylı metin ile doldurulacaktır.",
            style: TextStyle(fontSize: 16, height: 1.35),
          ),
        ),
      ),
    );
  }
}