import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InteractiveStoryResultsPage extends StatefulWidget {
  const InteractiveStoryResultsPage({super.key});

  @override
  State<InteractiveStoryResultsPage> createState() =>
      _InteractiveStoryResultsPageState();
}

class _InteractiveStoryResultsPageState
    extends State<InteractiveStoryResultsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  static const int keepDays = 7;

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    return "http://10.0.2.2:3000";
  }

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  bool _isWithinLast7Days(Map<String, dynamic> item) {
    final createdAt = (item["createdAt"] ?? "").toString();

    try {
      final date = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);
      return difference.inDays < keepDays;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchResults() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/interactive-story-results"))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }

      final decoded = jsonDecode(response.body);
      final rawResults = decoded["results"];

      final List<Map<String, dynamic>> list = rawResults is List
          ? rawResults
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where(_isWithinLast7Days)
              .toList()
          : [];

      list.sort((a, b) {
        final aDate = DateTime.tryParse((a["createdAt"] ?? "").toString());
        final bDate = DateTime.tryParse((b["createdAt"] ?? "").toString());

        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, "0");
      final month = date.month.toString().padLeft(2, "0");
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, "0");
      final minute = date.minute.toString().padLeft(2, "0");

      return "$day.$month.$year • $hour:$minute";
    } catch (_) {
      return value;
    }
  }

  int? _extractScore(String text, String key) {
    final regex = RegExp("$key\\s*:?\\s*(\\d+)(?:/10)?", caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? "");
  }

  bool _containsAny(String text, List<String> words) {
    final lower = text.toLowerCase();
    return words.any((word) => lower.contains(word));
  }

  Map<String, int?> _buildDisplayScores(Map<String, dynamic> item) {
    final selectedChoice = (item["selectedChoice"] ?? "").toString();
    final storyMessage = (item["storyMessage"] ?? "").toString();
    final dominantArea = (item["dominantArea"] ?? "").toString();
    final emotionalMeaning = (item["emotionalMeaning"] ?? "").toString();
    final developmentComment = (item["developmentComment"] ?? "").toString();
    final parentSuggestion = (item["parentSuggestion"] ?? "").toString();

    final joinedText =
        "$storyMessage $dominantArea $emotionalMeaning $developmentComment $parentSuggestion";

    final oldEmpathy = _extractScore(selectedChoice, "Empati");
    final oldFriendship = _extractScore(selectedChoice, "Arkadaşlık");
    final oldDistance = _extractScore(selectedChoice, "Mesafe");

    int helping = oldEmpathy ?? 0;
    int social = oldFriendship ?? 0;
    int cautious = oldDistance ?? 0;

    final hasSocialChoice = _containsAny(joinedText, [
      "arkadaş",
      "birlikte oyun",
      "oyun oynama",
      "yakınlaşma",
      "sosyal",
      "dostluk",
      "bağ kurma",
      "birlikte",
    ]);

    final hasHelpingChoice = _containsAny(joinedText, [
      "yardım",
      "destek",
      "fark etme",
      "düşünceli",
      "zor durumda",
    ]);

    final hasCautiousChoice = _containsAny(joinedText, [
      "mesafe",
      "temkinli",
      "bekleme",
      "güvenli alan",
      "önce izleme",
    ]);

    if (hasSocialChoice) social = max(social, 8);
    if (hasHelpingChoice) helping = max(helping, 7);
    if (!hasCautiousChoice && hasSocialChoice) cautious = min(cautious, 3);

    return {
      "helping": helping.clamp(0, 10),
      "social": social.clamp(0, 10),
      "cautious": cautious.clamp(0, 10),
    };
  }

  Color _scoreColor(int score, {bool reverse = false}) {
    if (reverse) {
      if (score <= 3) return const Color(0xFF15803D);
      if (score <= 6) return const Color(0xFFB45309);
      return const Color(0xFFB91C1C);
    }

    if (score >= 8) return const Color(0xFF15803D);
    if (score >= 5) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  Widget _scoreChip({
    required String label,
    required int? score,
    required IconData icon,
    bool reverseColor = false,
  }) {
    final safeScore = score ?? 0;
    final color = _scoreColor(safeScore, reverse: reverseColor);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              score == null ? "-" : "$score/10",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFF5B3A00),
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Son 7 güne ait ${_results.length} interaktif masal sonucu gösteriliyor.",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5B3A00),
              ),
            ),
          ),
          IconButton(
            onPressed: _fetchResults,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF5B3A00),
          ),
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: Color(0xFF1D4ED8)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Bu sonuçlar 7 gün boyunca gösterilir. Psikolojik tanı değildir; çocuğun masal içindeki seçimlerinden elde edilen gelişimsel gözlem niteliğindedir.",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3A8A),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> item) {
    final childNickname = (item["childNickname"] ?? "").toString();
    final avatarName = (item["avatarName"] ?? "").toString();
    final storyTitle = (item["storyTitle"] ?? "Masal").toString();
    final emotionalMeaning = (item["emotionalMeaning"] ?? "").toString();
    final developmentComment = (item["developmentComment"] ?? "").toString();
    final storyMessage = (item["storyMessage"] ?? "").toString();
    final createdAt = (item["createdAt"] ?? "").toString();
    final dominantArea = (item["dominantArea"] ?? "").toString();
    final parentSuggestion = (item["parentSuggestion"] ?? "").toString();

    final scores = _buildDisplayScores(item);
    final helping = scores["helping"];
    final social = scores["social"];
    final cautious = scores["cautious"];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3CD),
          child: Icon(
            Icons.auto_stories_rounded,
            color: Color(0xFF5B3A00),
          ),
        ),
        title: Text(
          storyTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Color(0xFF3B2F00),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            createdAt.isEmpty
                ? "İnteraktif masal sonucu"
                : _formatDate(createdAt),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A5A00),
            ),
          ),
        ),
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              _scoreChip(
                label: "Yardım Eğilimi",
                score: helping,
                icon: Icons.volunteer_activism_rounded,
              ),
              const SizedBox(width: 8),
              _scoreChip(
                label: "Sosyal Katılım",
                score: social,
                icon: Icons.groups_rounded,
              ),
              const SizedBox(width: 8),
              _scoreChip(
                label: "Temkinli Yaklaşım",
                score: cautious,
                icon: Icons.shield_rounded,
                reverseColor: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBox(
            icon: Icons.child_care_rounded,
            title: "Çocuk",
            value: childNickname.isEmpty ? "-" : childNickname,
          ),
          _InfoBox(
            icon: Icons.face_rounded,
            title: "Avatar",
            value: avatarName.isEmpty ? "-" : avatarName,
          ),
          if (storyMessage.isNotEmpty)
            _InfoBox(
              icon: Icons.emoji_events_rounded,
              title: "Masal Sonucu",
              value: storyMessage,
            ),
          if (dominantArea.isNotEmpty)
            _InfoBox(
              icon: Icons.psychology_rounded,
              title: "Baskın Gözlem Alanı",
              value: _cleanOldTerms(dominantArea),
            ),
          _InfoBox(
            icon: Icons.favorite_rounded,
            title: "Duygusal Gözlem",
            value: emotionalMeaning.isEmpty
                ? "-"
                : _cleanOldTerms(emotionalMeaning),
          ),
          _InfoBox(
            icon: Icons.trending_up_rounded,
            title: "Gelişimsel Yorum",
            value: developmentComment.isEmpty
                ? "-"
                : _cleanOldTerms(developmentComment),
          ),
          if (parentSuggestion.isNotEmpty)
            _InfoBox(
              icon: Icons.family_restroom_rounded,
              title: "Ebeveyn İçin Pekiştirme Önerisi",
              value: _cleanOldTerms(parentSuggestion),
            ),
          _ShortSummaryBox(
            childNickname: childNickname,
            storyTitle: storyTitle,
            storyMessage: storyMessage,
            dominantArea: _cleanOldTerms(dominantArea),
            helping: helping,
            social: social,
            cautious: cautious,
          ),
        ],
      ),
    );
  }

  String _cleanOldTerms(String text) {
    return text
        .replaceAll("Empati", "Yardım etme")
        .replaceAll("empati", "yardım etme")
        .replaceAll("Arkadaşlık", "Sosyal katılım")
        .replaceAll("arkadaşlık", "sosyal katılım")
        .replaceAll("Mesafe", "Temkinli yaklaşım")
        .replaceAll("mesafe", "temkinli yaklaşım");
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "İnteraktif masal sonuçları yüklenemedi:\n$_error",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B3A00),
            ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchResults,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SizedBox(height: 120),
            Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: Color(0xFF5B3A00),
            ),
            SizedBox(height: 16),
            Text(
              "Son 7 güne ait interaktif masal sonucu yok.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5B3A00),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchResults,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length + 2,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _summaryCard();
          if (index == 1) return _warningCard();

          final item = _results[index - 2];
          return _resultCard(item);
        },
      ),
    );
  }
}

class _ShortSummaryBox extends StatelessWidget {
  final String childNickname;
  final String storyTitle;
  final String storyMessage;
  final String dominantArea;
  final int? helping;
  final int? social;
  final int? cautious;

  const _ShortSummaryBox({
    required this.childNickname,
    required this.storyTitle,
    required this.storyMessage,
    required this.dominantArea,
    required this.helping,
    required this.social,
    required this.cautious,
  });

  String _buildText() {
    final name = childNickname.trim().isEmpty ? "Çocuk" : childNickname.trim();

    final h = helping == null ? "-" : "$helping/10";
    final s = social == null ? "-" : "$social/10";
    final c = cautious == null ? "-" : "$cautious/10";

    return "$name, '$storyTitle' masalını tamamladı.\n\n"
        "Sonuç: ${storyMessage.isEmpty ? "Masal tamamlandı" : storyMessage}\n\n"
        "Gözlem puanları: Yardım Eğilimi $h, Sosyal Katılım $s, Temkinli Yaklaşım $c\n\n"
        "Genel gözlem: ${dominantArea.isEmpty ? "Çocuğun seçimleri sosyal-duygusal gelişim açısından gözlem niteliği taşır." : dominantArea}";
  }

  @override
  Widget build(BuildContext context) {
    return _InfoBox(
      icon: Icons.summarize_rounded,
      title: "Kısa Panel Özeti",
      value: _buildText(),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF5B3A00), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF3B2F00),
                  fontSize: 14,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: "$title\n",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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