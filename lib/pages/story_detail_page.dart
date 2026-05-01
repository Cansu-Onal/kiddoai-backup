import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/realtime_service.dart';
import 'story_page.dart';

class StoryDetailPage extends StatefulWidget {
  final StoryModel story;
  final String nickname;
  final String personality;
  final String avatarName;

  const StoryDetailPage({
    super.key,
    required this.story,
    required this.nickname,
    required this.personality,
    required this.avatarName,
  });

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  final RealtimeService _rt = RealtimeService();

  bool _isSpeaking = false;
  bool _isLoadingVoice = false;
  bool _stopReading = false;
  bool _autoStarted = false;

  String _status = "Hazırlanıyor...";
  int _currentPage = 0;

  late List<String> _pages;

  @override
  void initState() {
    super.initState();

    _pages = _paginateStoryText(widget.story.metin, maxChars: 280);

    _rt.onStatus = (msg) {
      if (!mounted) return;
      setState(() {
        _status = msg;
      });
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoStarted) return;
      _autoStarted = true;
      _startStoryReading();
    });
  }

  List<String> _paginateStoryText(String text, {int maxChars = 280}) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final pages = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      final current = buffer.toString().trim();

      if (current.isNotEmpty &&
          (current.length + sentence.length + 1) > maxChars) {
        pages.add(current);
        buffer.clear();
      }

      buffer.write("$sentence ");
    }

    final last = buffer.toString().trim();
    if (last.isNotEmpty) {
      pages.add(last);
    }

    if (pages.isEmpty) {
      pages.add(text.trim());
    }

    return pages;
  }

  String _getThemeImagePath() {
    switch (widget.story.id) {
      case 1:
        return "assets/story_themes/aslan_fare.png";
      case 2:
        return "assets/story_themes/tavsan_kaplumbaga.png";
      case 3:
        return "assets/story_themes/karinca_bocek.png";
      case 4:
        return "assets/story_themes/karga_tilki.png";
      case 5:
        return "assets/story_themes/sehir_tarla_faresi.png";
      default:
        return "assets/story_themes/default_story.png";
    }
  }

  Future<void> _startStoryReading() async {
    if (_isSpeaking || _isLoadingVoice) return;

    setState(() {
      _isLoadingVoice = true;
      _isSpeaking = true;
      _stopReading = false;
      _currentPage = 0;
      _status = "Masal başlıyor...";
    });

    try {
      for (int i = 0; i < _pages.length; i++) {
        if (_stopReading) break;

        if (!mounted) return;
        setState(() {
          _currentPage = i;
          _status = "Sayfa ${i + 1} / ${_pages.length}";
        });

        String textToSpeak = _pages[i];

        if (i == 0) {
          textToSpeak = "${widget.story.baslik}. ${_pages[i]}";
        }

        if (i == _pages.length - 1) {
          textToSpeak = "$textToSpeak Masalın mesajı: ${widget.story.mesaj}";
        }

        await _rt.speakAvatarText(
         text: textToSpeak,
  nickname: widget.nickname,
  personality: widget.personality,
  avatarName: widget.avatarName,
  saveToPanel: false,
        );

        if (_stopReading) break;

        if (i < _pages.length - 1) {
          await Future.delayed(const Duration(milliseconds: 350));

          if (!mounted) return;
          setState(() {
            _currentPage = i + 1;
            _status = "Sayfa ${i + 2} / ${_pages.length}";
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _isLoadingVoice = false;
        _status = _stopReading ? "Durduruldu" : "Masal bitti ✨";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _isLoadingVoice = false;
        _status = "Hata oluştu";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Masal okunamadı: $e")),
      );
    }
  }

  Future<void> _stopStory() async {
    _stopReading = true;
    await _rt.disconnect();

    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
      _isLoadingVoice = false;
      _status = "Durduruldu";
    });
  }

  Widget _buildFlipTransition(Widget child, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        final angle = (1 - value) * 0.12;

        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle * math.pi),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStoryPage(String text, int pageIndex) {
    final themeImage = _getThemeImagePath();
    final isLastPage = pageIndex == _pages.length - 1;

    return Container(
      key: ValueKey(pageIndex),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Colors.black12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              themeImage,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFD9C19C),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.52),
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.32, 0.58, 1.0],
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
                child: Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width > 900 ? 360 : 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.story.baslik,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  blurRadius: 12,
                                  color: Colors.black,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "📖 ${_currentPage + 1} / ${_pages.length}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 23,
                                  height: 1.78,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 12,
                                      color: Colors.black,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (isLastPage) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                "Masalın Mesajı: ${widget.story.mesaj}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.55,
                                  fontWeight: FontWeight.w800,
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
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeImage = _getThemeImagePath();

    return Scaffold(
      backgroundColor: const Color(0xFFF2DFC0),
      appBar: AppBar(
        title: Text(widget.story.baslik),
        centerTitle: true,
        backgroundColor: const Color(0xFFD6A056),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      themeImage,
                      width: 72,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 72,
                          height: 58,
                          color: const Color(0xFFE9D5B0),
                          child: const Icon(Icons.image_outlined),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.avatarName} anlatıyor",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6B3E1F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _status,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B3E1F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: _buildFlipTransition,
                child: _buildStoryPage(_pages[_currentPage], _currentPage),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isLoadingVoice || _isSpeaking ? null : _startStoryReading,
                      icon: Icon(
                        _isSpeaking
                            ? Icons.volume_up_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isSpeaking ? "Okunuyor" : "Dinle"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD28C45),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          (_isSpeaking || _isLoadingVoice) ? _stopStory : null,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text("Durdur"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B3E1F),
                        side: const BorderSide(color: Color(0xFF6B3E1F)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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