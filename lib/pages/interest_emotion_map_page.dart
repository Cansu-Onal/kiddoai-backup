import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum InterestMapPeriod {
  daily,
  weekly,
  monthly,
}

class InterestEmotionMapPage extends StatefulWidget {
  const InterestEmotionMapPage({super.key});

  @override
  State<InterestEmotionMapPage> createState() => _InterestEmotionMapPageState();
}

class _InterestEmotionMapPageState extends State<InterestEmotionMapPage> {
  InterestMapPeriod _selectedPeriod = InterestMapPeriod.daily;
  bool _loading = false;
  String? _error;
  InterestEmotionMapResult? _result;
  EmotionCircleItem? _selectedItem;

  static String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";

    // Android emulator için:
    // return "http://10.0.2.2:3000";

    // Gerçek telefon için kendi bilgisayar IP adresin:
    return "http://192.168.2.39:3000";
  }

  String get _periodText {
    switch (_selectedPeriod) {
      case InterestMapPeriod.daily:
        return "Günlük";
      case InterestMapPeriod.weekly:
        return "Haftalık";
      case InterestMapPeriod.monthly:
        return "Aylık";
    }
  }

  String get _periodValue {
    switch (_selectedPeriod) {
      case InterestMapPeriod.daily:
        return "daily";
      case InterestMapPeriod.weekly:
        return "weekly";
      case InterestMapPeriod.monthly:
        return "monthly";
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMap();
  }

  Future<void> _fetchMap({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedItem = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/interest-emotion-map"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "period": _periodValue,
              "forceRefresh": forceRefresh,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw Exception("Sunucu hatası: ${response.statusCode}\n${response.body}");
      }

      final decoded = jsonDecode(response.body);
      final result = InterestEmotionMapResult.fromJson(
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _selectedItem = result.items.isNotEmpty ? result.items.first : null;
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

  void _changePeriod(InterestMapPeriod period) {
    if (_selectedPeriod == period) return;

    setState(() {
      _selectedPeriod = period;
    });

    _fetchMap(forceRefresh: true);
  }

  Color _emotionColor(String emotion) {
    final lower = emotion.toLowerCase();

    if (lower.contains("mutlu")) return const Color(0xFF22C55E);
    if (lower.contains("merak")) return const Color(0xFF3B82F6);
    if (lower.contains("nötr") || lower.contains("notr")) {
      return const Color(0xFF64748B);
    }
    if (lower.contains("kayg") || lower.contains("kork")) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains("üzg") || lower.contains("uzg")) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains("kız") || lower.contains("kiz")) {
      return const Color(0xFFEF4444);
    }

    return const Color(0xFF5B3A00);
  }

  IconData _emotionIcon(String emotion) {
    final lower = emotion.toLowerCase();

    if (lower.contains("mutlu")) return Icons.sentiment_very_satisfied_rounded;
    if (lower.contains("merak")) return Icons.psychology_alt_rounded;
    if (lower.contains("nötr") || lower.contains("notr")) {
      return Icons.sentiment_neutral_rounded;
    }
    if (lower.contains("kayg") || lower.contains("kork")) {
      return Icons.shield_rounded;
    }
    if (lower.contains("üzg") || lower.contains("uzg")) {
      return Icons.sentiment_dissatisfied_rounded;
    }
    if (lower.contains("kız") || lower.contains("kiz")) {
      return Icons.local_fire_department_rounded;
    }

    return Icons.favorite_rounded;
  }

  Widget _periodChip({
    required String label,
    required InterestMapPeriod period,
    required IconData icon,
  }) {
    final selected = _selectedPeriod == period;

    return ChoiceChip(
      selected: selected,
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: Colors.white,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? const Color(0xFF5B3A00) : Colors.grey.shade700,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w900,
        color: selected ? const Color(0xFF5B3A00) : Colors.grey.shade700,
      ),
      onSelected: (_) => _changePeriod(period),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: Color(0xFF5B3A00),
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "İlgi ve Duygu Çemberi",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5B3A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Çocuğun konuşmalarından 70B model ile çıkarılan duygu eğilimleri ve bu duygularla ilişkili ilgi alanları gösterilir. Bu bir psikolojik tanı değildir.",
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A5A00),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _periodChip(
                label: "Günlük",
                period: InterestMapPeriod.daily,
                icon: Icons.today_rounded,
              ),
              _periodChip(
                label: "Haftalık",
                period: InterestMapPeriod.weekly,
                icon: Icons.date_range_rounded,
              ),
              _periodChip(
                label: "Aylık",
                period: InterestMapPeriod.monthly,
                icon: Icons.calendar_month_rounded,
              ),
              ActionChip(
                avatar: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Yenile"),
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                backgroundColor: Colors.white,
                onPressed: () => _fetchMap(forceRefresh: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(InterestEmotionMapResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFFFF7E6)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$_periodText analiz özeti",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.parentSummary.isEmpty
                ? "Bu dönem için genel bir özet bulunamadı."
                : result.parentSummary,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.38,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Model: ${result.model.isEmpty ? "llama-3.3-70b-versatile" : result.model}",
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleCard(List<EmotionCircleItem> items) {
    final selected = _selectedItem;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF5B3A00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Duygu Dağılımı",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: Color(0xFF5B3A00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 260,
            child: GestureDetector(
              onTapDown: (details) {
                final box = context.findRenderObject();
                if (box is! RenderBox) return;

                final local = details.localPosition;
                final size = const Size(260, 260);
                final center = Offset(size.width / 2, size.height / 2);
                final dx = local.dx - center.dx;
                final dy = local.dy - center.dy;
                final distance = math.sqrt(dx * dx + dy * dy);

                if (distance < 55 || distance > 130) return;

                var angle = math.atan2(dy, dx);
                angle += math.pi / 2;
                if (angle < 0) angle += math.pi * 2;

                final total = items.fold<double>(
                  0,
                  (sum, item) => sum + item.percentage,
                );

                double start = 0;

                for (final item in items) {
                  final sweep = (item.percentage / total) * math.pi * 2;
                  if (angle >= start && angle <= start + sweep) {
                    setState(() {
                      _selectedItem = item;
                    });
                    break;
                  }
                  start += sweep;
                }
              },
              child: Center(
                child: CustomPaint(
                  size: const Size(260, 260),
                  painter: EmotionCirclePainter(
                    items: items,
                    selectedEmotion: selected?.emotion ?? "",
                    colorOf: _emotionColor,
                  ),
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Center(
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF7E6),
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _emotionIcon(selected?.emotion ?? ""),
                              color: _emotionColor(selected?.emotion ?? ""),
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              selected?.label ?? "Duygu",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: _emotionColor(selected?.emotion ?? ""),
                              ),
                            ),
                            Text(
                              "%${selected?.percentage ?? 0}",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                color: _emotionColor(selected?.emotion ?? ""),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final selected = _selectedItem?.emotion == item.emotion;
              final color = _emotionColor(item.emotion);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedItem = item;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.16) : color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? color : color.withOpacity(0.25),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_emotionIcon(item.emotion), color: color, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "${item.label} %${item.percentage}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _selectedEmotionDetails() {
    final item = _selectedItem;
    if (item == null) return const SizedBox.shrink();

    final color = _emotionColor(item.emotion);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(_emotionIcon(item.emotion), color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${item.label} • %${item.percentage}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Bu duyguya bağlı ilgi alanları",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3B2F00),
            ),
          ),
          const SizedBox(height: 8),
          if (item.topics.isEmpty)
            const Text(
              "Bu dönem için belirgin bir ilgi alanı bulunamadı.",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B3A00),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.topics
                  .map(
                    (topic) => Chip(
                      label: Text(topic),
                      avatar: const Icon(Icons.favorite_rounded, size: 18),
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.donut_large_outlined,
                size: 62,
                color: Color(0xFF5B3A00),
              ),
              SizedBox(height: 12),
              Text(
                "Henüz ilgi ve duygu çemberi oluşturulamadı.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF5B3A00),
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Çocuk sohbet ettikten sonra bu sayfayı yenileyerek günlük, haftalık veya aylık duygu çemberini görebilirsiniz.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A5A00),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          const Text(
            "70B model ile ilgi ve duygu çemberi hazırlanıyor...",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF5B3A00),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_rounded, color: Colors.red, size: 44),
                const SizedBox(height: 10),
                Text(
                  "Çember yüklenemedi:\n$_error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7A0000),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _fetchMap(forceRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Tekrar Dene"),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final result = _result;

    if (result == null || result.items.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMap(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 14),
          _summaryCard(result),
          const SizedBox(height: 14),
          _circleCard(result.items),
          const SizedBox(height: 14),
          _selectedEmotionDetails(),
          const SizedBox(height: 18),
          const Text(
            "Not: Bu çember konuşmalardaki duygu ve ilgi eğilimlerini gösterir. Psikolojik tanı amacı taşımaz.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class EmotionCirclePainter extends CustomPainter {
  final List<EmotionCircleItem> items;
  final String selectedEmotion;
  final Color Function(String emotion) colorOf;

  EmotionCirclePainter({
    required this.items,
    required this.selectedEmotion,
    required this.colorOf,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<double>(0, (sum, item) => sum + item.percentage);

    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (final item in items) {
      final sweepAngle = (item.percentage / total) * math.pi * 2;
      final selected = item.emotion == selectedEmotion;

      final paint = Paint()
        ..color = colorOf(item.emotion)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 48 : 40
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect.deflate(selected ? 28 : 32),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant EmotionCirclePainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedEmotion != selectedEmotion;
  }
}

class InterestEmotionMapResult {
  final String period;
  final String model;
  final String parentSummary;
  final List<EmotionCircleItem> items;

  InterestEmotionMapResult({
    required this.period,
    required this.model,
    required this.parentSummary,
    required this.items,
  });

  factory InterestEmotionMapResult.fromJson(Map<String, dynamic> json) {
    final rawData = json["data"];
    final data = rawData is Map<String, dynamic> ? rawData : json;

    final rawItems = data["items"];

    List<EmotionCircleItem> items = [];

    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((e) => EmotionCircleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    items.sort((a, b) => b.percentage.compareTo(a.percentage));

    return InterestEmotionMapResult(
      period: (json["period"] ?? data["period"] ?? "").toString(),
      model: (json["model"] ?? data["model"] ?? "").toString(),
      parentSummary: (data["parentSummary"] ?? json["parentSummary"] ?? "").toString(),
      items: items,
    );
  }
}

class EmotionCircleItem {
  final String emotion;
  final String label;
  final int percentage;
  final List<String> topics;

  EmotionCircleItem({
    required this.emotion,
    required this.label,
    required this.percentage,
    required this.topics,
  });

  factory EmotionCircleItem.fromJson(Map<String, dynamic> json) {
    final emotion = (json["emotion"] ?? "").toString().trim();

    return EmotionCircleItem(
      emotion: emotion,
      label: (json["label"] ?? _capitalize(emotion)).toString(),
      percentage: int.tryParse((json["percentage"] ?? 0).toString()) ?? 0,
      topics: _stringList(json["topics"]),
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return "Duygu";
    return value[0].toUpperCase() + value.substring(1);
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [];
  }
}