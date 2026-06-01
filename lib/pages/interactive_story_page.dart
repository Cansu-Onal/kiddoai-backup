import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class InteractiveStoryPage extends StatefulWidget {
  final String nickname;
  final String personality;
  final String avatarName;

  const InteractiveStoryPage({
    super.key,
    this.nickname = "",
    this.personality = "",
    this.avatarName = "",
  });

  @override
  State<InteractiveStoryPage> createState() => _InteractiveStoryPageState();
}

class _InteractiveStoryPageState extends State<InteractiveStoryPage> {
  final AudioPlayer _player = AudioPlayer();

  bool _isLoading = true;
  bool _isSpeaking = false;
  bool _choicesEnabled = false;
  bool _parentResultSent = false;

  String? _error;
  String _gender = "Erkek";

  late InteractiveStory _story;
  late String _currentNodeId;

  int empathyScore = 0;
  int friendshipScore = 0;
  int distanceScore = 0;
  int totalChoices = 0;

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  String get _safeNickname {
    final value = widget.nickname.trim();
    return value.isEmpty ? "Çocuk" : value;
  }

  String get _safeAvatarName {
    final value = widget.avatarName.trim();
    return value.isEmpty ? "Avatar" : value;
  }

  @override
  void initState() {
    super.initState();
    _loadAvatarProfileThenStory();
  }

  Future<void> _loadAvatarProfileThenStory() async {
    await _loadAvatarProfile();
    await _loadStory();
  }

  Future<void> _loadAvatarProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("settings")
          .doc("avatarProfile")
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        _gender = (data["gender"] ?? "Erkek").toString();
      });
    } catch (e) {
      debugPrint("Masal avatar gender okunamadı: $e");
    }
  }

  Future<void> _loadStory() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/story/interactive_story.json');

      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      _story = InteractiveStory.fromJson(jsonData);
      _currentNodeId = _story.startNode;

      setState(() {
        _isLoading = false;
        _error = null;
        _choicesEnabled = false;
        _parentResultSent = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      await _speakCurrentNode();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = "Masal yüklenemedi: $e";
      });
    }
  }

  StoryNode get _currentNode => _story.nodes[_currentNodeId]!;

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<Uint8List> _getTtsBytes(String text) async {
    final response = await http
        .post(
          Uri.parse("$_baseUrl/tts"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "text": text,
            "gender": _gender,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception("TTS API hata: ${response.statusCode}");
    }

    return response.bodyBytes;
  }

  Future<void> _speakText(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final bytes = await _getTtsBytes(cleanText);

    if (!mounted || !_isSpeaking) return;

    await _player.stop();
    await _player.play(BytesSource(bytes));
    await _player.onPlayerComplete.first;
  }

  List<String> _splitTextIntoChunks(String text) {
    final cleanText = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');
    final sentences = cleanText.split(RegExp(r'(?<=[.!?])\s+'));

    final List<String> chunks = [];
    String buffer = "";

    for (final sentence in sentences) {
      final next = buffer.isEmpty ? sentence : "$buffer $sentence";

      if (next.length > 230 && buffer.isNotEmpty) {
        chunks.add(buffer.trim());
        buffer = sentence;
      } else {
        buffer = next;
      }
    }

    if (buffer.trim().isNotEmpty) {
      chunks.add(buffer.trim());
    }

    return chunks;
  }

  Future<void> _speakLongText(String text) async {
    final chunks = _splitTextIntoChunks(text);

    for (final chunk in chunks) {
      if (!mounted || !_isSpeaking) return;
      await _speakText(chunk);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _speakCurrentNode() async {
    if (_isSpeaking) return;

    final node = _currentNode;

    setState(() {
      _isSpeaking = true;
      _choicesEnabled = false;
    });

    await _player.stop();

    try {
      await _speakLongText(node.text);

      if (!mounted || !_isSpeaking) return;

      if (node.choices.length >= 2) {
        await Future.delayed(const Duration(milliseconds: 900));

        if (!mounted || !_isSpeaking) return;

        final prompt = node.choicePrompt?.trim();

        if (prompt != null && prompt.isNotEmpty) {
          await _speakText("Ece biraz durdu ve düşündü.");
          await Future.delayed(const Duration(milliseconds: 500));
          await _speakText(prompt);
        } else {
          final first = node.choices[0].title;
          final second = node.choices[1].title;

          await _speakText("Ece biraz durdu ve düşündü.");
          await Future.delayed(const Duration(milliseconds: 500));
          await _speakText("Sence $first mı, yoksa $second mı?");
        }
      }
    } catch (e) {
      debugPrint("Interactive story speak error: $e");
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _choicesEnabled = true;
    });
  }

  Future<void> _skipToChoices() async {
    await _clickSound();
    await _player.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _choicesEnabled = true;
    });
  }

  Future<void> _choose(StoryChoice choice) async {
    if (!_choicesEnabled) return;

    await _clickSound();
    await _player.stop();

    empathyScore += choice.scores.empathy;
    friendshipScore += choice.scores.friendship;
    distanceScore += choice.scores.distance;
    totalChoices++;

    if (choice.next != null && _story.nodes.containsKey(choice.next)) {
      setState(() {
        _currentNodeId = choice.next!;
        _isSpeaking = false;
        _choicesEnabled = false;
      });

      final nextNode = _story.nodes[_currentNodeId]!;

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      if (nextNode.end != null) {
        await _showEnding(nextNode);
      } else {
        await _speakCurrentNode();
      }
    } else {
      await _showEnding(_currentNode);
    }
  }

  int _scoreOutOfTen(int rawScore) {
    final maxPossible = max(totalChoices * 2, 1);
    return ((rawScore / maxPossible) * 10).round().clamp(0, 10);
  }

  Map<String, int> _normalizedScores() {
    return {
      "empathy": _scoreOutOfTen(empathyScore),
      "friendship": _scoreOutOfTen(friendshipScore),
      "distance": _scoreOutOfTen(distanceScore),
    };
  }

  Map<String, String> _buildParentAnalysis(String endingTitle) {
    final scores = _normalizedScores();

    final empathy = scores["empathy"] ?? 0;
    final friendship = scores["friendship"] ?? 0;
    final distance = scores["distance"] ?? 0;

    String dominantArea;
    String emotionalMeaning;
    String developmentComment;
    String parentSuggestion;

    final hasStrongSocialPattern = friendship >= 7 || empathy >= 7;
    final hasStrongBalancedSocialPattern =
        empathy >= 7 && friendship >= 7 && distance <= 4;

    if (hasStrongBalancedSocialPattern) {
      dominantArea = "Güçlü sosyal bağ ve empatik yaklaşım";
      emotionalMeaning =
          "Çocuk, masal boyunca hem arkadaşlık kurmaya hem de zor durumda olan kişiye destek olmaya yönelik güçlü seçimler yaptı.";
      developmentComment =
          "Seçimler, çocuğun sosyal ilişki kurmaya açık olduğunu, yardım etme davranışını fark ettiğini ve olumlu sosyal temasları tercih ettiğini gösteriyor.";
      parentSuggestion =
          "Bu güçlü yönü yeni etkinlik vermekten çok günlük hayatta fark edip pekiştirmek daha anlamlı olur.";
    } else if (empathy >= friendship && empathy >= distance) {
      dominantArea = "Yardım etme eğilimi";
      emotionalMeaning =
          "Çocuk, zor durumda olan kişiye destek olmayı öne çıkaran seçimler yaptı.";
      developmentComment =
          "Seçimler, çocuğun başkasının ihtiyacını fark etmeye ve yardım etmeye açık olduğunu gösteriyor.";
      parentSuggestion =
          "Çocuğun yardım etme davranışını fark edip sözel olarak pekiştirmek uygun olur.";
    } else if (friendship >= empathy && friendship >= distance) {
      dominantArea = "Sosyal katılım ve yakınlaşma";
      emotionalMeaning =
          "Çocuk, birlikte oyun oynama, yakınlaşma ve sosyal bağ kurma yönünde seçimler yaptı.";
      developmentComment =
          "Seçimler, çocuğun sosyal ilişki başlatmaya ve oyun yoluyla bağ kurmaya açık olduğunu gösteriyor.";
      parentSuggestion =
          "Çocuğun sosyal isteğini destekleyen olumlu geri bildirimler verilebilir.";
    } else if (hasStrongSocialPattern && distance <= 5) {
      dominantArea = "Olumlu sosyal seçimler";
      emotionalMeaning =
          "Çocuk, masal içinde genel olarak sosyal ve destekleyici seçeneklere yöneldi.";
      developmentComment =
          "Seçimler, çocuğun arkadaşlık, yardımlaşma ve sosyal bağ kurma davranışlarını olumlu gördüğünü düşündürüyor.";
      parentSuggestion =
          "Bu davranışları günlük konuşmalarda pekiştirmek yeterli olabilir.";
    } else {
      dominantArea = "Temkinli yaklaşım ve güvenli alan ihtiyacı";
      emotionalMeaning =
          "Çocuk, bazı durumlarda mesafe koyma veya beklemeyi tercih eden seçimler yaptı.";
      developmentComment =
          "Bu seçimler tek başına olumsuz değildir; çocuk yeni sosyal durumlarda önce gözlem yapma ihtiyacı duyuyor olabilir.";
      parentSuggestion =
          "Çocuğu zorlamadan, seçenek sunarak desteklemek daha uygundur.";
    }

    return {
      "dominantArea": dominantArea,
      "emotionalMeaning": emotionalMeaning,
      "developmentComment": developmentComment,
      "parentSuggestion": parentSuggestion,
      "endingTitle": endingTitle,
    };
  }

  Future<void> _sendParentAnalysis(String endingTitle, StoryNode node) async {
    if (_parentResultSent) return;

    final analysis = _buildParentAnalysis(endingTitle);
    final scores = _normalizedScores();

    final empathy = scores["empathy"] ?? 0;
    final friendship = scores["friendship"] ?? 0;
    final distance = scores["distance"] ?? 0;

    final payload = {
      "type": "interactive_story_result",
      "childNickname": _safeNickname,
      "personality": widget.personality,
      "avatarName": _safeAvatarName,
      "storyId": "interactive_story",
      "storyTitle": _story.title,
      "storyMessage": endingTitle,
      "selectedChoice":
          "Empati: $empathy/10, Arkadaşlık: $friendship/10, Mesafe: $distance/10",
      "dominantArea": analysis["dominantArea"],
      "emotionalMeaning": analysis["emotionalMeaning"],
      "developmentComment": analysis["developmentComment"],
      "parentSuggestion": analysis["parentSuggestion"],
      "parentPanelText":
          "İnteraktif masal sonucu: $_safeNickname, '${_story.title}' masalını '$endingTitle' sonucu ile tamamladı.\n\n"
          "Puan özeti: Empati $empathy/10, Arkadaşlık $friendship/10, Mesafe $distance/10\n\n"
          "Baskın gelişim alanı: ${analysis["dominantArea"]}\n\n"
          "Duygusal gözlem: ${analysis["emotionalMeaning"]}\n\n"
          "Gelişimsel yorum: ${analysis["developmentComment"]}\n\n"
          "Ebeveyn önerisi: ${analysis["parentSuggestion"]}\n\n"
          "Not: Bu çıktı psikolojik tanı değildir; çocuğun uygulama içindeki seçim davranışlarına dayalı gelişimsel gözlem niteliğindedir.",
      "createdAt": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/interactive-story-result"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _parentResultSent = true;
      }

      debugPrint("Parent analysis send status: ${response.statusCode}");
    } catch (e) {
      debugPrint("Parent analysis send error: $e");
    }
  }

  Future<void> _finishStoryNow() async {
    if (totalChoices <= 0) return;

    await _clickSound();
    await _player.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _choicesEnabled = false;
    });

    String title;

    if (friendshipScore >= empathyScore && friendshipScore >= distanceScore) {
      title = "Neşeli Arkadaşlık";
    } else if (empathyScore >= friendshipScore && empathyScore >= distanceScore) {
      title = "İyilikle Gelen Dostluk";
    } else {
      title = "Temkinli Yaklaşım";
    }

    await _sendParentAnalysis(title, _currentNode);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Text(
            "🌟 Masal tamamlandı",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            "Sonuç ebeveyn paneline gönderildi.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartStory();
              },
              child: const Text("Tekrar Oyna"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text("Çık"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEnding(StoryNode node) async {
    if (_isSpeaking) return;

    setState(() {
      _isSpeaking = true;
      _choicesEnabled = false;
    });

    String title;
    String emoji;

    if (node.end == "good") {
      title = "İyilikle Gelen Dostluk";
      emoji = "🌟";
    } else if (node.end == "middle") {
      title = "Yavaş Gelişen Dostluk";
      emoji = "🌿";
    } else if (node.end == "bad") {
      title = "Kaçan Fırsat";
      emoji = "🌙";
    } else {
      if (empathyScore >= friendshipScore && empathyScore >= distanceScore) {
        title = "İyilikle Gelen Dostluk";
        emoji = "🌟";
      } else if (friendshipScore >= empathyScore &&
          friendshipScore >= distanceScore) {
        title = "Neşeli Arkadaşlık";
        emoji = "🎈";
      } else {
        title = "Kaçan Fırsat";
        emoji = "🌙";
      }
    }

    try {
      await _speakLongText(node.text);
    } catch (e) {
      debugPrint("Ending speak error: $e");
    }

    await _sendParentAnalysis(title, node);

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _choicesEnabled = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: Text(
            "$emoji Masal tamamlandı",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            "$title\n\nHarika seçimler yaptın. Masalı başarıyla tamamladın.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartStory();
              },
              child: const Text("Tekrar Oyna"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text("Çık"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restartStory() async {
    await _player.stop();

    setState(() {
      _currentNodeId = _story.startNode;
      empathyScore = 0;
      friendshipScore = 0;
      distanceScore = 0;
      totalChoices = 0;
      _isSpeaking = false;
      _choicesEnabled = false;
      _parentResultSent = false;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    await _speakCurrentNode();
  }

  double _progressValue() {
    final nodeKeys = _story.nodes.keys.toList();
    final currentIndex = nodeKeys.indexOf(_currentNodeId);

    if (currentIndex < 0 || nodeKeys.isEmpty) return 0.1;

    return ((currentIndex + 1) / nodeKeys.length).clamp(0.1, 1.0);
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF4D8),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF4D8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF81C784),
          title: const Text("İnteraktif Masal"),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    }

    final node = _currentNode;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/story/story_park_bg.jfif",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.18),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () async {
                          await _player.stop();
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: _progressValue(),
                            minHeight: 11,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.55),
                            color: const Color(0xFF81C784),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassCircleButton(
                        icon: Icons.volume_up_rounded,
                        onTap: _isSpeaking ? () {} : _speakCurrentNode,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (node.choices.length >= 2)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.42,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StoryChoiceCard(
                              choice: node.choices[0],
                              disabled: !_choicesEnabled,
                              onTap: () => _choose(node.choices[0]),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StoryChoiceCard(
                              choice: node.choices[1],
                              disabled: !_choicesEnabled,
                              onTap: () => _choose(node.choices[1]),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _GlassPanel(
                      child: FilledButton(
                        onPressed: _isSpeaking ? null : () => _showEnding(node),
                        child: const Text("Sonu Gör"),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: totalChoices > 0 ? _finishStoryNow : null,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text("Masalı Bitir"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF7A4BD8),
                        side: const BorderSide(
                          color: Color(0xFF7A4BD8),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isSpeaking && node.choices.length >= 2) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _skipToChoices,
                        icon: const Icon(Icons.touch_app_rounded),
                        label: const Text("Seçime Geç"),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7A4BD8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _GlassPanel(
                    child: Text(
                      _isSpeaking
                          ? "Masalı dinleyelim..."
                          : _choicesEnabled
                              ? "Seçimini yapmak için karta dokun 😊"
                              : "Hazırlanıyor...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                      ),
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

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.78),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                icon,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryChoiceCard extends StatelessWidget {
  final StoryChoice choice;
  final VoidCallback onTap;
  final bool disabled;

  const _StoryChoiceCard({
    required this.choice,
    required this.onTap,
    required this.disabled,
  });

  String _cleanAssetPath(String path) {
    var clean = path.trim();

    if (clean.startsWith("assets/assets/")) {
      clean = clean.replaceFirst("assets/assets/", "assets/");
    }

    return clean;
  }

  String _pngPath(String path) {
    final clean = _cleanAssetPath(path);

    return clean
        .replaceAll(".jfif", ".png")
        .replaceAll(".jpeg", ".png")
        .replaceAll(".jpg", ".png");
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _pngPath(choice.image);

    return Opacity(
      opacity: disabled ? 0.58 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(30),
            elevation: 5,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: disabled ? null : onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.75),
                    width: 2.5,
                  ),
                ),
                padding: const EdgeInsets.all(11),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Image.asset(
                          imagePath,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.image_not_supported_rounded,
                                size: 70,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      choice.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF263238),
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

class InteractiveStory {
  final String title;
  final String startNode;
  final Map<String, StoryNode> nodes;

  InteractiveStory({
    required this.title,
    required this.startNode,
    required this.nodes,
  });

  factory InteractiveStory.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'];

    final nodesJson =
        rawNodes is Map<String, dynamic> ? rawNodes : <String, dynamic>{};

    return InteractiveStory(
      title: (json['title'] ?? 'İnteraktif Masal').toString(),
      startNode: (json['startNode'] ?? 'start').toString(),
      nodes: nodesJson.map(
        (key, value) => MapEntry(
          key,
          StoryNode.fromJson(
            value is Map<String, dynamic> ? value : <String, dynamic>{},
          ),
        ),
      ),
    );
  }
}

class StoryNode {
  final String text;
  final String? question;
  final String? choicePrompt;
  final List<StoryChoice> choices;
  final String? end;

  StoryNode({
    required this.text,
    this.question,
    this.choicePrompt,
    required this.choices,
    this.end,
  });

  factory StoryNode.fromJson(Map<String, dynamic> json) {
    final choicesJson = json['choices'];

    return StoryNode(
      text: (json['text'] ?? '').toString(),
      question: json['question']?.toString(),
      choicePrompt: json['choicePrompt']?.toString(),
      end: json['end']?.toString(),
      choices: choicesJson is List
          ? choicesJson
              .whereType<Map>()
              .map(
                (item) => StoryChoice.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : [],
    );
  }
}

class StoryChoice {
  final String title;
  final String image;
  final String? next;
  final StoryScores scores;

  StoryChoice({
    required this.title,
    required this.image,
    this.next,
    required this.scores,
  });

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      next: json['next']?.toString(),
      scores: StoryScores.fromJson(
        json['scores'] is Map<String, dynamic>
            ? json['scores'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
    );
  }
}

class StoryScores {
  final int empathy;
  final int friendship;
  final int distance;

  StoryScores({
    required this.empathy,
    required this.friendship,
    required this.distance,
  });

  factory StoryScores.fromJson(Map<String, dynamic> json) {
    return StoryScores(
      empathy: json['empathy'] is int
          ? json['empathy'] as int
          : int.tryParse((json['empathy'] ?? 0).toString()) ?? 0,
      friendship: json['friendship'] is int
          ? json['friendship'] as int
          : int.tryParse((json['friendship'] ?? 0).toString()) ?? 0,
      distance: json['distance'] is int
          ? json['distance'] as int
          : int.tryParse((json['distance'] ?? 0).toString()) ?? 0,
    );
  }
}