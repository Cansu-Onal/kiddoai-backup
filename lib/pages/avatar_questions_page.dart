import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kiddoai/pages/avatar_result_page.dart';

class AvatarQuestionsPage extends StatefulWidget {
  const AvatarQuestionsPage({super.key});

  @override
  State<AvatarQuestionsPage> createState() => _AvatarQuestionsPageState();
}

class _AvatarQuestionsPageState extends State<AvatarQuestionsPage> {
  String? gender;
  String? personality;
  String? style;
  int? dailyLimitMinutes;

  List<String> interests = [];
  List<String> goals = [];

  String? boredomLevel;
  String? attentionSpan;

  bool showOtherInterestInput = false;
  bool showOtherGoalInput = false;

  final TextEditingController avatarNameController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController otherInterestController = TextEditingController();
  final TextEditingController otherGoalController = TextEditingController();
  final TextEditingController extraLikeController = TextEditingController();
  final TextEditingController avoidTopicController = TextEditingController();

  final AudioPlayer _audioPlayer = AudioPlayer();

  int currentStep = 0;

  final List<Map<String, dynamic>> questions = [
    {
      "title": "Avatarın kim olsun?",
      "subtitle": "Bir karakter seç.",
      "key": "gender",
      "options": ["Kız", "Erkek"],
    },
    {
      "title": "Arkadaşın nasıl biri olsun?",
      "subtitle": "Karakterini seç.",
      "key": "personality",
      "options": ["Neşeli", "Sakin"],
    },
    {
      "title": "Avatarın görünümü nasıl olsun?",
      "subtitle": "Tarzını seç.",
      "key": "style",
      "options": ["Renkli", "Sade"],
    },
    {
      "title": "Günlük kullanım süresi ne kadar olsun?",
      "subtitle":
          "Uygulamada geçirilen toplam süre bu ayara göre sınırlandırılacak.",
      "key": "dailyLimit",
      "options": ["15 dk", "30 dk", "45 dk", "60 dk"],
    },
    {
      "title": "Çocuğunuz neleri sever?",
      "subtitle": "En fazla 6 seçim yapın. Yoksa alttan yazabilirsiniz.",
      "key": "interests",
      "options": [
        "Hayvanlar",
        "Araçlar",
        "Uzay",
        "Masallar",
        "Çizim",
        "Müzik",
        "Spor",
        "Doğa",
        "Bilim",
        "Oyunlar",
      ],
    },
    {
      "title": "Hangi alanlarda gelişmesini istersiniz?",
      "subtitle": "En fazla 6 seçim yapın. Yoksa alttan yazabilirsiniz.",
      "key": "goals",
      "options": [
        "Dil gelişimi",
        "Sosyal beceriler",
        "Dikkat / odak",
        "Problem çözme",
        "Özgüven",
        "Duygusal farkındalık",
      ],
    },
    {
      "title": "Çocuğunuz çabuk sıkılır mı?",
      "subtitle": "Avatar konuşma süresini buna göre ayarlayacak.",
      "key": "boredom",
      "options": ["Evet", "Bazen", "Hayır"],
    },
    {
      "title": "Ortalama dikkat süresi ne kadar?",
      "subtitle": "Avatar konuşmaları bu süreye göre kısa ve eğlenceli tutacak.",
      "key": "attention",
      "options": ["3-5 dk", "5-10 dk", "10-15 dk", "15+ dk"],
    },
    {
      "title": "Ekstra bilgiler",
      "subtitle": "İsterseniz çocuğunuzla ilgili özel bilgileri yazabilirsiniz.",
      "key": "extra",
      "options": <String>[],
    },
    {
      "title": "Avatarına isim ver",
      "subtitle": "Bu isim avatarın adı olacak.",
      "key": "avatarName",
      "options": <String>[],
    },
    {
      "title": "Adın ne?",
      "subtitle": "Avatar sana bu isimle seslenecek.",
      "key": "userName",
      "options": <String>[],
    },
  ];

  @override
  void initState() {
    super.initState();
    _prepareClickSound();
  }

  Future<void> _prepareClickSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setSource(AssetSource('sounds/click.wav'));
    } catch (e) {
      debugPrint("Click preload error: $e");
    }
  }

  @override
  void dispose() {
    avatarNameController.dispose();
    userNameController.dispose();
    otherInterestController.dispose();
    otherGoalController.dispose();
    extraLikeController.dispose();
    avoidTopicController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _clickSound() async {
    try {
      await _audioPlayer.play(
        AssetSource('sounds/click.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint("Click sound error: $e");
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _tapOptionAndRun(VoidCallback action) async {
    await _clickSound();
    if (!mounted) return;
    action();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFFECB3),
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.brown,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _avatarAssetPath({required String gender, required String style}) {
    if (gender == "Kız" && style == "Renkli") {
      return "assets/avatars/kiz_renkli.png";
    }
    if (gender == "Kız" && style == "Sade") {
      return "assets/avatars/kiz_sade.png";
    }
    if (gender == "Erkek" && style == "Renkli") {
      return "assets/avatars/erkek_renkli.png";
    }
    return "assets/avatars/erkek_sade.png";
  }

  String? _getSelectedValue(String key) {
    switch (key) {
      case "gender":
        return gender;
      case "personality":
        return personality;
      case "style":
        return style;
      case "dailyLimit":
        return dailyLimitMinutes == null ? null : "$dailyLimitMinutes dk";
      case "boredom":
        return boredomLevel;
      case "attention":
        return attentionSpan;
      default:
        return null;
    }
  }

  void _setSelectedValue(String key, String value) {
    setState(() {
      switch (key) {
        case "gender":
          gender = value;
          break;
        case "personality":
          personality = value;
          break;
        case "style":
          style = value;
          break;
        case "dailyLimit":
          dailyLimitMinutes = int.tryParse(value.replaceAll(" dk", ""));
          break;
        case "boredom":
          boredomLevel = value;
          break;
        case "attention":
          attentionSpan = value;
          break;
      }
    });
  }

  void _toggleMultiValue(String key, String value) {
    final list = key == "interests" ? interests : goals;

    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        if (list.length >= 6) {
          _snack("En fazla 6 seçim yapabilirsiniz.");
          return;
        }
        list.add(value);
      }
    });
  }

  void _addOtherValue(String key) {
    final controller =
        key == "interests" ? otherInterestController : otherGoalController;

    final value = controller.text.trim();

    if (value.isEmpty) {
      _snack("Lütfen bir şey yazın.");
      return;
    }

    final list = key == "interests" ? interests : goals;

    if (list.length >= 6) {
      _snack("En fazla 6 seçim yapabilirsiniz.");
      return;
    }

    if (list.contains(value)) {
      _snack("Bu seçenek zaten eklendi.");
      return;
    }

    setState(() {
      list.add(value);
      controller.clear();

      if (key == "interests") {
        showOtherInterestInput = false;
      } else {
        showOtherGoalInput = false;
      }
    });
  }

  bool _isCurrentStepAnswered() {
    final key = questions[currentStep]["key"] as String;

    if (key == "avatarName") {
      return avatarNameController.text.trim().isNotEmpty;
    }

    if (key == "userName") {
      return userNameController.text.trim().isNotEmpty;
    }

    if (key == "interests") {
      return interests.isNotEmpty;
    }

    if (key == "goals") {
      return goals.isNotEmpty;
    }

    if (key == "extra") {
      return true;
    }

    return _getSelectedValue(key) != null;
  }

  Future<void> _goNext() async {
    if (!_isCurrentStepAnswered()) {
      _snack("Lütfen bu adımı doldur.");
      return;
    }

    if (currentStep < questions.length - 1) {
      setState(() {
        currentStep++;
      });
      return;
    }

    await _createAvatar();
  }

  Future<void> _goBack() async {
    if (currentStep == 0) return;

    setState(() {
      currentStep--;
    });
  }

  Future<void> _saveAvatarProfileToFirebase({
    required String avatarName,
    required String userName,
    required String avatarAsset,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint("Avatar profile kaydedilemedi: kullanıcı yok.");
      return;
    }

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("settings")
        .doc("avatarProfile")
        .set({
      "avatarName": avatarName,
      "userName": userName,
      "avatarAsset": avatarAsset,
      "gender": gender,
      "personality": personality,
      "style": style,
      "dailyLimitMinutes": dailyLimitMinutes,
      "interests": interests,
      "goals": goals,
      "boredomLevel": boredomLevel,
      "attentionSpan": attentionSpan,
      "extraLike": extraLikeController.text.trim(),
      "avoidTopic": avoidTopicController.text.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _createAvatar() async {
    final avatarName = avatarNameController.text.trim();
    final userName = userNameController.text.trim();

    if (gender == null ||
        personality == null ||
        style == null ||
        dailyLimitMinutes == null ||
        interests.isEmpty ||
        goals.isEmpty ||
        boredomLevel == null ||
        attentionSpan == null ||
        avatarName.isEmpty ||
        userName.isEmpty) {
      _snack("Lütfen tüm adımları tamamla.");
      return;
    }

    final asset = _avatarAssetPath(gender: gender!, style: style!);

    try {
      await _saveAvatarProfileToFirebase(
        avatarName: avatarName,
        userName: userName,
        avatarAsset: asset,
      );
    } catch (e) {
      debugPrint("Avatar profile kayıt hatası: $e");
      _snack("Ayarlar kaydedilirken hata oluştu.");
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarResultPage(
          avatarAsset: asset,
          nickname: userName,
          gender: gender!,
          personality: personality!,
          favorite: avatarName,
          style: style!,
          dailyLimitMinutes: dailyLimitMinutes!,
        ),
      ),
    );
  }

  String _imageForOption(String label) {
    switch (label) {
      case "Kız":
        return "assets/icons/kiz.png";
      case "Erkek":
        return "assets/icons/erkek.png";
      case "Neşeli":
        return "assets/icons/neseli.png";
      case "Sakin":
        return "assets/icons/sakin.png";
      case "Renkli":
        return "assets/icons/renkli.png";
      case "Sade":
        return "assets/icons/sade.png";

      case "Hayvanlar":
        return "assets/icons/hayvanlar.png";
      case "Araçlar":
        return "assets/icons/araclar.png";
      case "Uzay":
        return "assets/icons/uzay.png";
      case "Masallar":
        return "assets/icons/masallar.png";
      case "Çizim":
        return "assets/icons/cizim.png";
      case "Müzik":
        return "assets/icons/muzik.png";
      case "Spor":
        return "assets/icons/spor.png";
      case "Doğa":
        return "assets/icons/doga.png";
      case "Bilim":
        return "assets/icons/bilim.png";
      case "Oyunlar":
        return "assets/icons/oyunlar.png";

      case "Dil gelişimi":
        return "assets/icons/english.png";
      case "Sosyal beceriler":
        return "assets/icons/chat.png";
      case "Dikkat / odak":
        return "assets/icons/oyunlar.png";
      case "Problem çözme":
        return "assets/icons/bilim.png";
      case "Özgüven":
        return "assets/icons/neseli.png";
      case "Duygusal farkındalık":
        return "assets/icons/chat.png";

      case "15 dk":
      case "30 dk":
      case "45 dk":
      case "60 dk":
      case "3-5 dk":
      case "5-10 dk":
      case "10-15 dk":
      case "15+ dk":
        return "assets/icons/time.png";

      default:
        return "assets/icons/kiz.png";
    }
  }

  IconData _fallbackIconForOption(String label) {
    switch (label) {
      case "Hayvanlar":
        return Icons.pets_rounded;
      case "Araçlar":
        return Icons.directions_car_rounded;
      case "Uzay":
        return Icons.rocket_launch_rounded;
      case "Masallar":
        return Icons.menu_book_rounded;
      case "Çizim":
        return Icons.brush_rounded;
      case "Müzik":
        return Icons.music_note_rounded;
      case "Spor":
        return Icons.sports_soccer_rounded;
      case "Doğa":
        return Icons.park_rounded;
      case "Bilim":
        return Icons.science_rounded;
      case "Oyunlar":
        return Icons.sports_esports_rounded;
      case "Dil gelişimi":
        return Icons.record_voice_over_rounded;
      case "Sosyal beceriler":
        return Icons.groups_rounded;
      case "Dikkat / odak":
        return Icons.center_focus_strong_rounded;
      case "Problem çözme":
        return Icons.extension_rounded;
      case "Özgüven":
        return Icons.star_rounded;
      case "Duygusal farkındalık":
        return Icons.favorite_rounded;
      case "Evet":
        return Icons.sentiment_dissatisfied_rounded;
      case "Bazen":
        return Icons.sentiment_neutral_rounded;
      case "Hayır":
        return Icons.sentiment_satisfied_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _colorForOption(String label) {
    switch (label) {
      case "Kız":
        return const Color(0xFFEC4899);
      case "Erkek":
        return const Color(0xFF3B82F6);
      case "Neşeli":
        return const Color(0xFFF59E0B);
      case "Sakin":
        return const Color(0xFF10B981);
      case "Renkli":
        return const Color(0xFFFB7185);
      case "Sade":
        return const Color(0xFF64748B);
      case "15 dk":
        return const Color(0xFF22C55E);
      case "30 dk":
        return const Color(0xFF3B82F6);
      case "45 dk":
        return const Color(0xFFF59E0B);
      case "60 dk":
        return const Color(0xFF8B5CF6);
      case "Hayvanlar":
      case "Duygusal farkındalık":
        return const Color(0xFFEC4899);
      case "Araçlar":
      case "Sosyal beceriler":
        return const Color(0xFF3B82F6);
      case "Uzay":
      case "Problem çözme":
        return const Color(0xFF8B5CF6);
      case "Masallar":
      case "Dil gelişimi":
        return const Color(0xFFF59E0B);
      case "Çizim":
      case "Özgüven":
        return const Color(0xFFFB7185);
      case "Müzik":
      case "Dikkat / odak":
        return const Color(0xFF10B981);
      case "Spor":
      case "Doğa":
      case "Bilim":
      case "Oyunlar":
        return const Color(0xFF22C55E);
      case "Evet":
        return const Color(0xFFEF4444);
      case "Bazen":
        return const Color(0xFFF59E0B);
      case "Hayır":
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Widget _buildProgressBar() {
    final progress = (currentStep + 1) / questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Adım ${currentStep + 1} / ${questions.length}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.28),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionHeader(String title, String subtitle) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final activeColor = _colorForOption(label);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _tapOptionAndRun(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withOpacity(0.18)
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? activeColor : Colors.white.withOpacity(0.85),
            width: selected ? 2.6 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 14 : 8,
              offset: const Offset(0, 6),
              color: selected
                  ? activeColor.withOpacity(0.22)
                  : const Color(0x14000000),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Image.asset(
                  _imageForOption(label),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      _fallbackIconForOption(label),
                      size: 48,
                      color: activeColor,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? activeColor : const Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
  }) {
    final hasText = controller.text.trim().isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasText
            ? Colors.white.withOpacity(0.95)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasText ? const Color(0xFFF59E0B) : Colors.white,
          width: hasText ? 2.2 : 1.4,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) {
          setState(() {});
        },
        style: const TextStyle(
          color: Color(0xFF3B2F00),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF8A6A00)),
          border: InputBorder.none,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFFF59E0B),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherInput({
    required String keyName,
    required TextEditingController controller,
    required String hintText,
  }) {
    final isOpen =
        keyName == "interests" ? showOtherInterestInput : showOtherGoalInput;

    return Column(
      children: [
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                if (keyName == "interests") {
                  showOtherInterestInput = !showOtherInterestInput;
                } else {
                  showOtherGoalInput = !showOtherGoalInput;
                }
              });
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: isOpen
                    ? const Color(0xFFF59E0B)
                    : Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFF59E0B),
                  width: 1.6,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOpen ? Icons.close_rounded : Icons.edit_rounded,
                    color: isOpen ? Colors.white : const Color(0xFF3B2F00),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOpen ? "Kapat" : "Yoksa yaz",
                    style: TextStyle(
                      color: isOpen ? Colors.white : const Color(0xFF3B2F00),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 14),
          _buildTextInput(
            controller: controller,
            hintText: hintText,
            icon: Icons.add_circle_rounded,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _addOtherValue(keyName),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Ekle",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionsGrid(
    List<String> options,
    String? selectedValue,
    String key,
  ) {
    final isMulti = key == "interests" || key == "goals";
    final selectedList = key == "interests" ? interests : goals;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: options.length == 2 ? 0.95 : 0.88,
          ),
          itemBuilder: (context, index) {
            final option = options[index];

            return _buildOptionCard(
              label: option,
              selected: isMulti
                  ? selectedList.contains(option)
                  : selectedValue == option,
              onTap: () {
                if (isMulti) {
                  _toggleMultiValue(key, option);
                } else {
                  _setSelectedValue(key, option);
                }
              },
            );
          },
        ),
        if (key == "interests")
          _buildOtherInput(
            keyName: "interests",
            controller: otherInterestController,
            hintText: "Örnek: Dinozorlar, prensesler, robotlar…",
          ),
        if (key == "goals")
          _buildOtherInput(
            keyName: "goals",
            controller: otherGoalController,
            hintText: "Örnek: Paylaşmayı öğrenmesi, sabır…",
          ),
      ],
    );
  }

  Widget _buildExtraStep() {
    return Column(
      children: [
        _buildTextInput(
          controller: extraLikeController,
          hintText: "Çocuğunuzun özellikle sevdiği bir şey var mı?",
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 16),
        _buildTextInput(
          controller: avoidTopicController,
          hintText: "Kaçınmak istediğiniz bir konu var mı?",
          icon: Icons.block_rounded,
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    final current = questions[currentStep];
    final title = current["title"] as String;
    final subtitle = current["subtitle"] as String;
    final key = current["key"] as String;
    final options = List<String>.from(current["options"] as List);

    final selectedValue = _getSelectedValue(key);

    return Column(
      children: [
        _buildQuestionHeader(title, subtitle),
        const SizedBox(height: 26),
        if (key == "avatarName")
          _buildTextInput(
            controller: avatarNameController,
            hintText: "Örnek: Pofuduk, Maviş, Leo…",
            icon: Icons.badge_rounded,
          ),
        if (key == "userName")
          _buildTextInput(
            controller: userNameController,
            hintText: "Adını yaz…",
            icon: Icons.person_rounded,
          ),
        if (key == "extra") _buildExtraStep(),
        if (key != "avatarName" && key != "userName" && key != "extra")
          _buildOptionsGrid(options, selectedValue, key),
      ],
    );
  }

  Widget _buildBottomButtons() {
    final isLast = currentStep == questions.length - 1;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: currentStep == 0 ? null : _goBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              side: const BorderSide(color: Colors.white, width: 1.6),
              backgroundColor: Colors.white.withOpacity(0.14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              "Geri",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _goNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              isLast ? "Avatarı Oluştur" : "Devam Et",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          "Avatar Soruları",
          style: TextStyle(
            color: Color(0xFF3B2F00),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        backgroundColor: background,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF3B2F00),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        "assets/icons/a.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.18),
                              Colors.black.withOpacity(0.22),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        children: [
                          _buildProgressBar(),
                          const SizedBox(height: 22),
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(bottom: 110),
                              child: _buildCurrentStep(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBottomButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}