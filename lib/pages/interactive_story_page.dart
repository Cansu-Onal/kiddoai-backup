import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddoai/services/elevenlabs_voice_service.dart';

class InteractiveStoryPage extends StatefulWidget {
  const InteractiveStoryPage({super.key});

  @override
  State<InteractiveStoryPage> createState() => _InteractiveStoryPageState();
}

class _InteractiveStoryPageState extends State<InteractiveStoryPage> {
  final ElevenLabsVoiceService _voice = ElevenLabsVoiceService();

  bool _isLoading = true;
  bool _isSpeaking = false;
  String? _error;

  late InteractiveStory _story;
  late String _currentNodeId;

  int empathyScore = 0;
  int friendshipScore = 0;
  int distanceScore = 0;

  @override
  void initState() {
    super.initState();
    _loadStory();
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
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      await _speakCurrentNode();
    } catch (e) {
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
      if (!mounted) return;
      await _voice.speak(chunk);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _speakCurrentNode() async {
    if (_isSpeaking) return;

    final node = _currentNode;

    setState(() {
      _isSpeaking = true;
    });

    await _voice.stop();

    // Masal metni tamamen bitmeden seçim kısmına geçmez.
    await _speakLongText(node.text);

    if (!mounted) return;

    if (node.choices.length >= 2) {
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      final prompt = node.choicePrompt?.trim();

      if (prompt != null && prompt.isNotEmpty) {
        await _voice.speak("Ece biraz durdu ve düşündü.");
        await Future.delayed(const Duration(milliseconds: 500));
        await _voice.speak(prompt);
      } else {
        final first = node.choices[0].title;
        final second = node.choices[1].title;

        await _voice.speak("Ece biraz durdu ve düşündü.");
        await Future.delayed(const Duration(milliseconds: 500));
        await _voice.speak("Sence $first mı, yoksa $second mı?");
      }
    }

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _choose(StoryChoice choice) async {
    if (_isSpeaking) return;

    await _clickSound();
    await _voice.stop();

    empathyScore += choice.scores.empathy;
    friendshipScore += choice.scores.friendship;
    distanceScore += choice.scores.distance;

    if (choice.next != null && _story.nodes.containsKey(choice.next)) {
      setState(() {
        _currentNodeId = choice.next!;
        _isSpeaking = false;
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

  Future<void> _showEnding(StoryNode node) async {
    if (_isSpeaking) return;

    setState(() {
      _isSpeaking = true;
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

    await _speakLongText(node.text);

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
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
            "$emoji $title",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            node.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w600,
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
    await _voice.stop();

    setState(() {
      _currentNodeId = _story.startNode;
      empathyScore = 0;
      friendshipScore = 0;
      distanceScore = 0;
      _isSpeaking = false;
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
    _voice.stop();
    _voice.dispose();
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
                          await _voice.stop();
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
                              disabled: _isSpeaking,
                              onTap: () => _choose(node.choices[0]),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StoryChoiceCard(
                              choice: node.choices[1],
                              disabled: _isSpeaking,
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
                  _GlassPanel(
                    child: Text(
                      _isSpeaking
                          ? "Masalı dinleyelim..."
                          : "Seçimini yapmak için karta dokun 😊",
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

  String _pngPath(String path) {
    return path
        .replaceAll(".jfif", ".png")
        .replaceAll(".jpeg", ".png")
        .replaceAll(".jpg", ".png");
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _pngPath(choice.image);

    return Opacity(
      opacity: disabled ? 0.75 : 1,
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
    final nodesJson = json['nodes'] as Map<String, dynamic>;

    return InteractiveStory(
      title: json['title'] ?? 'İnteraktif Masal',
      startNode: json['startNode'] ?? 'start',
      nodes: nodesJson.map(
        (key, value) => MapEntry(
          key,
          StoryNode.fromJson(value as Map<String, dynamic>),
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
      text: json['text'] ?? '',
      question: json['question'],
      choicePrompt: json['choicePrompt'],
      end: json['end'],
      choices: choicesJson is List
          ? choicesJson
              .map(
                (item) => StoryChoice.fromJson(
                  item as Map<String, dynamic>,
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
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      next: json['next'],
      scores: StoryScores.fromJson(
        json['scores'] as Map<String, dynamic>? ?? {},
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
      empathy: json['empathy'] ?? 0,
      friendship: json['friendship'] ?? 0,
      distance: json['distance'] ?? 0,
    );
  }
}