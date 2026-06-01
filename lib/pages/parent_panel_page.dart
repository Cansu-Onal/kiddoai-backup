import 'interactive_story_results_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:kiddoai/services/app_settings_service.dart';
import 'parent_saved_paintings_store.dart';
import 'painting_downloader.dart';

class ParentPanelPage extends StatelessWidget {
  const ParentPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    ParentSavedPaintingsStore.cleanupExpired();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF7E6),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF5B3A00)),
          title: const Text(
            'Ebeveyn Paneli',
            style: TextStyle(
              color: Color(0xFF5B3A00),
              fontWeight: FontWeight.w900,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF5B3A00),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFFC107),
            tabs: [
              Tab(icon: Icon(Icons.chat_rounded), text: "Konuşmalar"),
              Tab(icon: Icon(Icons.auto_stories_rounded), text: "Masallar"),
              Tab(icon: Icon(Icons.photo_library_rounded), text: "Resimler"),
              Tab(icon: Icon(Icons.settings_rounded), text: "Ayarlar"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ChatHistoryView(),
            InteractiveStoryResultsPage(),
            _SavedPaintingsView(),
            _ParentSettingsView(),
          ],
        ),
      ),
    );
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String formatDate(DateTime dateTime) {
    final day = _twoDigits(dateTime.day);
    final month = _twoDigits(dateTime.month);
    final year = dateTime.year;
    return '$day.$month.$year';
  }

  static String formatDateTime(DateTime dateTime) {
    final day = _twoDigits(dateTime.day);
    final month = _twoDigits(dateTime.month);
    final year = dateTime.year;
    final hour = _twoDigits(dateTime.hour);
    final minute = _twoDigits(dateTime.minute);
    return '$day.$month.$year  •  $hour:$minute';
  }
}

enum _ChatDateFilter {
  today,
  week,
  month,
  custom,
}

class _ChatHistoryView extends StatefulWidget {
  const _ChatHistoryView();

  @override
  State<_ChatHistoryView> createState() => _ChatHistoryViewState();
}

class _ChatHistoryViewState extends State<_ChatHistoryView> {
  _ChatDateFilter _selectedFilter = _ChatDateFilter.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _tomorrowStart => _todayStart.add(const Duration(days: 1));

  DateTime get _filterStart {
    final today = _todayStart;

    switch (_selectedFilter) {
      case _ChatDateFilter.today:
        return today;
      case _ChatDateFilter.week:
        return today.subtract(const Duration(days: 6));
      case _ChatDateFilter.month:
        return DateTime(today.year, today.month, 1);
      case _ChatDateFilter.custom:
        return _customStartDate ?? today;
    }
  }

  DateTime get _filterEnd {
    switch (_selectedFilter) {
      case _ChatDateFilter.today:
        return _tomorrowStart;
      case _ChatDateFilter.week:
        return _tomorrowStart;
      case _ChatDateFilter.month:
        final now = DateTime.now();
        return DateTime(now.year, now.month + 1, 1);
      case _ChatDateFilter.custom:
        final end = _customEndDate ?? DateTime.now();
        return DateTime(end.year, end.month, end.day).add(
          const Duration(days: 1),
        );
    }
  }

  String get _filterLabel {
    switch (_selectedFilter) {
      case _ChatDateFilter.today:
        return "Bugün";
      case _ChatDateFilter.week:
        return "Son 7 gün";
      case _ChatDateFilter.month:
        return "Bu ay";
      case _ChatDateFilter.custom:
        final start = _customStartDate;
        final end = _customEndDate;

        if (start == null || end == null) {
          return "Tarih seç";
        }

        return "${ParentPanelPage.formatDate(start)} - ${ParentPanelPage.formatDate(end)}";
    }
  }

  Color _riskColor(bool hasRisk) {
    return hasRisk ? const Color(0xFFFFE0E0) : Colors.white;
  }

  IconData _riskIcon(bool hasRisk) {
    return hasRisk ? Icons.warning_rounded : Icons.verified_rounded;
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? _todayStart,
        end: _customEndDate ?? _todayStart,
      ),
      helpText: "Tarih aralığı seç",
      cancelText: "İptal",
      confirmText: "Seç",
    );

    if (range == null) return;

    setState(() {
      _selectedFilter = _ChatDateFilter.custom;
      _customStartDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _customEndDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      );
    });
  }

  Widget _buildFilterChip({
    required String label,
    required _ChatDateFilter filter,
    required IconData icon,
  }) {
    final selected = _selectedFilter == filter;

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
        fontWeight: FontWeight.w800,
        color: selected ? const Color(0xFF5B3A00) : Colors.grey.shade700,
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_rounded, color: Color(0xFF5B3A00)),
              SizedBox(width: 8),
              Text(
                "Konuşma Filtresi",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5B3A00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: "Bugün",
                filter: _ChatDateFilter.today,
                icon: Icons.today_rounded,
              ),
              _buildFilterChip(
                label: "Haftalık",
                filter: _ChatDateFilter.week,
                icon: Icons.date_range_rounded,
              ),
              _buildFilterChip(
                label: "Aylık",
                filter: _ChatDateFilter.month,
                icon: Icons.calendar_month_rounded,
              ),
              ActionChip(
                avatar: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: Text(
                  _selectedFilter == _ChatDateFilter.custom
                      ? _filterLabel
                      : "Tarih seç",
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                backgroundColor: _selectedFilter == _ChatDateFilter.custom
                    ? const Color(0xFFFFD54F)
                    : Colors.white,
                onPressed: _pickCustomDateRange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          "Giriş yapılmamış.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("dailyChats")
          .where("userId", isEqualTo: user.uid)
          .where("date", isGreaterThanOrEqualTo: Timestamp.fromDate(_filterStart))
          .where("date", isLessThan: Timestamp.fromDate(_filterEnd))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Konuşmalar yüklenirken hata oluştu:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        docs.sort((a, b) {
          final aTime = a.data()["date"];
          final bTime = b.data()["date"];

          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        final int totalMessages = docs.fold<int>(
          0,
          (sum, doc) => sum + ((doc.data()["totalMessages"] ?? 0) as int),
        );

        final int riskyCount = docs.fold<int>(
          0,
          (sum, doc) => sum + ((doc.data()["riskyCount"] ?? 0) as int),
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildFilterBar(),
              const SizedBox(height: 14),
              _DailyChatSummaryCard(
                dayCount: docs.length,
                totalMessages: totalMessages,
                riskyCount: riskyCount,
                filterLabel: _filterLabel,
              ),
              const SizedBox(height: 14),
              Expanded(
                child: docs.isEmpty
                    ? const _EmptyChatView()
                    : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();

                          final timestamp = data["date"];
                          DateTime? date;
                          if (timestamp is Timestamp) {
                            date = timestamp.toDate();
                          }

                          final lastUpdatedAt = data["lastUpdatedAt"];
                          DateTime? lastUpdatedDate;
                          if (lastUpdatedAt is Timestamp) {
                            lastUpdatedDate = lastUpdatedAt.toDate();
                          }

                          final total = (data["totalMessages"] ?? 0).toString();
                          final risky = (data["riskyCount"] ?? 0).toString();
                          final hasRisk = data["hasRisk"] == true;
                          final normalSummary =
                              (data["normalSummary"] ?? "").toString();
                          final topicsRaw = data["topics"];

                          final List<String> topics = topicsRaw is List
                              ? topicsRaw.map((e) => e.toString()).toList()
                              : [];

                          final messagesRaw = data["messages"];
                          final List<Map<String, dynamic>> messages =
                              messagesRaw is List
                                  ? messagesRaw
                                      .whereType<Map>()
                                      .map((e) => Map<String, dynamic>.from(e))
                                      .toList()
                                  : [];

                          final riskyMessagesRaw = data["riskyMessages"];
                          final List<Map<String, dynamic>> riskyMessages =
                              riskyMessagesRaw is List
                                  ? riskyMessagesRaw
                                      .whereType<Map>()
                                      .map((e) => Map<String, dynamic>.from(e))
                                      .toList()
                                  : [];

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _riskColor(hasRisk),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: hasRisk
                                    ? Colors.red.shade100
                                    : Colors.green.shade100,
                              ),
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
                              leading: CircleAvatar(
                                backgroundColor: hasRisk
                                    ? Colors.red.shade100
                                    : Colors.green.shade100,
                                child: Icon(
                                  _riskIcon(hasRisk),
                                  color: hasRisk
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                              title: Text(
                                date == null
                                    ? "Günlük sohbet"
                                    : ParentPanelPage.formatDate(date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Color(0xFF3B2F00),
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  hasRisk
                                      ? "$risky riskli içerik • Toplam $total konuşma"
                                      : "Risk yok • Toplam $total konuşma",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: hasRisk
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              children: [
                                const SizedBox(height: 12),
                                if (lastUpdatedDate != null)
                                  _InfoRow(
                                    icon: Icons.update_rounded,
                                    title: "Son güncelleme",
                                    value: ParentPanelPage.formatDateTime(
                                      lastUpdatedDate,
                                    ),
                                  ),
                                _InfoRow(
                                  icon: Icons.topic_rounded,
                                  title: "Ana konular",
                                  value: topics.isEmpty
                                      ? "Genel sohbet"
                                      : topics.join(", "),
                                ),
                                _InfoRow(
                                  icon: Icons.summarize_rounded,
                                  title: "Günlük özet",
                                  value: normalSummary.isEmpty
                                      ? "Bugün genel sohbet edildi."
                                      : normalSummary,
                                ),
                                if (messages.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.forum_rounded,
                                              color: Color(0xFF5B3A00),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Günlük Konuşma Detayları",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF5B3A00),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ...messages.reversed.take(10).map((item) {
                                          final childMessage =
                                              (item["childMessage"] ?? "")
                                                  .toString();
                                          final aiReply =
                                              (item["aiReply"] ?? "").toString();
                                          final topic =
                                              (item["topic"] ?? "").toString();

                                          return Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (topic.isNotEmpty)
                                                  Text(
                                                    "Konu: $topic",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Color(0xFF5B3A00),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  "Çocuğun mesajı:",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  childMessage.isEmpty
                                                      ? "-"
                                                      : childMessage,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  "Avatar cevabı:",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Text(
                                                  aiReply.isEmpty
                                                      ? "-"
                                                      : aiReply,
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ],
                                if (hasRisk) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red.shade100,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.warning_rounded,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Riskli Konuşmalar",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF7A0000),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        if (riskyMessages.isEmpty)
                                          const Text(
                                            "Risk işaretlenmiş ama detay mesaj kaydı yok.",
                                          )
                                        else
                                          ...riskyMessages.map((item) {
                                            final childMessage =
                                                (item["childMessage"] ?? "")
                                                    .toString();
                                            final aiReply =
                                                (item["aiReply"] ?? "")
                                                    .toString();
                                            final riskCategory =
                                                (item["riskCategory"] ?? "")
                                                    .toString();
                                            final riskReason =
                                                (item["riskReason"] ?? "")
                                                    .toString();

                                            return Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (riskCategory.isNotEmpty ||
                                                      riskReason.isNotEmpty)
                                                    Text(
                                                      "Kategori: ${riskCategory.isEmpty ? "-" : riskCategory}\nSebep: ${riskReason.isEmpty ? "-" : riskReason}",
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            Color(0xFF7A0000),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    "Çocuğun mesajı:",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  Text(
                                                    childMessage.isEmpty
                                                        ? "-"
                                                        : childMessage,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    "Avatar cevabı:",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  Text(
                                                    aiReply.isEmpty
                                                        ? "-"
                                                        : aiReply,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyChatSummaryCard extends StatelessWidget {
  final int dayCount;
  final int totalMessages;
  final int riskyCount;
  final String filterLabel;

  const _DailyChatSummaryCard({
    required this.dayCount,
    required this.totalMessages,
    required this.riskyCount,
    required this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasRisk = riskyCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasRisk
              ? [const Color(0xFFFFEBEE), const Color(0xFFFFCDD2)]
              : [const Color(0xFFE8F5E9), const Color(0xFFDFF8E3)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Icon(
            hasRisk ? Icons.warning_rounded : Icons.verified_rounded,
            size: 38,
            color: hasRisk ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              hasRisk
                  ? "$filterLabel içinde $riskyCount riskli içerik bulundu.\n$dayCount günlük kayıt • $totalMessages toplam konuşma"
                  : "$filterLabel için riskli içerik yok.\n$dayCount günlük kayıt • $totalMessages toplam konuşma",
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3B2F00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
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
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Seçilen tarih aralığında kayıtlı konuşma yok.",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5B3A00),
        ),
      ),
    );
  }
}

class _SavedPaintingsView extends StatefulWidget {
  const _SavedPaintingsView();

  @override
  State<_SavedPaintingsView> createState() => _SavedPaintingsViewState();
}

class _SavedPaintingsViewState extends State<_SavedPaintingsView> {
  late Future<List<SavedPainting>> _paintingsFuture;

  @override
  void initState() {
    super.initState();
    _reloadLocalFuture();
  }

  void _reloadLocalFuture() {
    _paintingsFuture = ParentSavedPaintingsStore.getPaintings();
  }

  Future<void> _reload() async {
    await ParentSavedPaintingsStore.cleanupExpired();
    if (!mounted) return;
    setState(_reloadLocalFuture);
  }

  Future<void> _deletePainting(SavedPainting item) async {
    await ParentSavedPaintingsStore.deletePainting(item.id);
    await _reload();
  }

  Future<void> _downloadPainting(SavedPainting item) async {
    await downloadPaintingBytes(
      bytes: item.bytes,
      fileName: 'kiddo_ai_boyama_${item.id}.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedPainting>>(
      future: _paintingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Resimler yüklenirken hata oluştu:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5B3A00),
                ),
              ),
            ),
          );
        }

        final paintings = snapshot.data ?? [];

        if (paintings.isEmpty) {
          return const _EmptySavedPaintingsView();
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _HeaderSummaryCard(count: paintings.length),
                const SizedBox(height: 10),
                const Text(
                  'Kaydedilen resimler Firestore içinde 7 gün saklanır. Süresi dolan resimler uygulama açıldığında otomatik silinir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A6A00),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    itemCount: paintings.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.62,
                    ),
                    itemBuilder: (context, index) {
                      final item = paintings[index];

                      return GestureDetector(
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => _PaintingPreviewDialog(
                              item: item,
                              onDownload: () => _downloadPainting(item),
                              onDelete: () async {
                                Navigator.pop(context);
                                await _deletePainting(item);
                              },
                            ),
                          );
                          await _reload();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8,
                                offset: Offset(0, 3),
                                color: Color(0x12000000),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.memory(
                                    item.bytes,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 4, 10, 10),
                                child: Column(
                                  children: [
                                    Text(
                                      item.title,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF5B3A00),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Kayıt: ${ParentPanelPage.formatDateTime(item.createdAt)}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Silinme: ${ParentPanelPage.formatDateTime(item.expiresAt)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          tooltip: 'İndir',
                                          onPressed: () =>
                                              _downloadPainting(item),
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            color: Color(0xFF5B3A00),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Sil',
                                          onPressed: () =>
                                              _deletePainting(item),
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red.shade400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSummaryCard extends StatelessWidget {
  final int count;

  const _HeaderSummaryCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        '$count adet boyanmış resim kayıtlı. Her kayıt 7 gün saklanır.',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5B3A00),
        ),
      ),
    );
  }
}

class _EmptySavedPaintingsView extends StatelessWidget {
  const _EmptySavedPaintingsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Henüz kaydedilen resim yok.',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF5B3A00),
        ),
      ),
    );
  }
}

class _PaintingPreviewDialog extends StatelessWidget {
  final SavedPainting item;
  final Future<void> Function() onDownload;
  final Future<void> Function() onDelete;

  const _PaintingPreviewDialog({
    required this.item,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'İndir',
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade400,
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kayıt zamanı: ${ParentPanelPage.formatDateTime(item.createdAt)}\nOtomatik silinme: ${ParentPanelPage.formatDateTime(item.expiresAt)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.memory(
                  item.bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ParentSettingsView extends StatefulWidget {
  const _ParentSettingsView();

  @override
  State<_ParentSettingsView> createState() => _ParentSettingsViewState();
}

class _ParentSettingsViewState extends State<_ParentSettingsView> {
  int _dailyLimitMinutes = 30;
  String _avatarAsset = "assets/images/avatar.png";

  String? _gender;
  String? _personality;
  String? _style;
  String? _boredomLevel;
  String? _attentionSpan;

  List<String> _interests = [];
  List<String> _goals = [];

  final TextEditingController _avatarNameController =
      TextEditingController(text: "Arkadaşın");
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _extraLikeController = TextEditingController();
  final TextEditingController _avoidTopicController = TextEditingController();
  final TextEditingController _otherInterestController =
      TextEditingController();
  final TextEditingController _otherGoalController = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  bool _showOtherInterestInput = false;
  bool _showOtherGoalInput = false;

  final List<int> _timeOptions = [15, 30, 45, 60];

  final List<String> _interestOptions = [
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
  ];

  final List<String> _goalOptions = [
    "Dil gelişimi",
    "Sosyal beceriler",
    "Dikkat / odak",
    "Problem çözme",
    "Özgüven",
    "Duygusal farkındalık",
  ];

  final List<String> _boredomOptions = ["Evet", "Bazen", "Hayır"];
  final List<String> _attentionOptions = [
    "3-5 dk",
    "5-10 dk",
    "10-15 dk",
    "15+ dk",
  ];

  @override
  void dispose() {
    _avatarNameController.dispose();
    _userNameController.dispose();
    _extraLikeController.dispose();
    _avoidTopicController.dispose();
    _otherInterestController.dispose();
    _otherGoalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_loaded) return;

    final settings = await AppSettingsService.getSettings();

    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? profileData;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("settings")
          .doc("avatarProfile")
          .get();

      if (doc.exists) {
        profileData = doc.data();
      }
    }

    if (!mounted) return;

    setState(() {
      _dailyLimitMinutes =
          profileData?["dailyLimitMinutes"] ?? settings.dailyLimitMinutes;
      _avatarNameController.text =
          (profileData?["avatarName"] ?? settings.avatarName).toString();
      _userNameController.text = (profileData?["userName"] ?? "").toString();
      _avatarAsset = (profileData?["avatarAsset"] ?? settings.avatarAsset)
          .toString();

      _gender = profileData?["gender"]?.toString();
      _personality = profileData?["personality"]?.toString();
      _style = profileData?["style"]?.toString();
      _boredomLevel = profileData?["boredomLevel"]?.toString();
      _attentionSpan = profileData?["attentionSpan"]?.toString();

      final interestsRaw = profileData?["interests"];
      final goalsRaw = profileData?["goals"];

      _interests = interestsRaw is List
          ? interestsRaw.map((e) => e.toString()).toList()
          : [];
      _goals =
          goalsRaw is List ? goalsRaw.map((e) => e.toString()).toList() : [];

      _extraLikeController.text =
          (profileData?["extraLike"] ?? "").toString();
      _avoidTopicController.text =
          (profileData?["avoidTopic"] ?? "").toString();

      _loaded = true;
    });
  }

  Future<void> _saveSettings() async {
    final avatarName = _avatarNameController.text.trim();
    final userName = _userNameController.text.trim();

    if (avatarName.isEmpty) {
      _showMessage("Avatar adı boş olamaz.");
      return;
    }

    if (_interests.isEmpty) {
      _showMessage("En az bir ilgi alanı seçmelisiniz.");
      return;
    }

    if (_goals.isEmpty) {
      _showMessage("En az bir gelişim hedefi seçmelisiniz.");
      return;
    }

    setState(() => _saving = true);

    try {
      await AppSettingsService.updateSettings(
        dailyLimitMinutes: _dailyLimitMinutes,
        avatarAsset: _avatarAsset,
        avatarName: avatarName,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("settings")
            .doc("avatarProfile")
            .set({
          "avatarName": avatarName,
          "userName": userName,
          "avatarAsset": _avatarAsset,
          "gender": _gender,
          "personality": _personality,
          "style": _style,
          "dailyLimitMinutes": _dailyLimitMinutes,
          "interests": _interests,
          "goals": _goals,
          "boredomLevel": _boredomLevel,
          "attentionSpan": _attentionSpan,
          "extraLike": _extraLikeController.text.trim(),
          "avoidTopic": _avoidTopicController.text.trim(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      setState(() => _saving = false);
      _showMessage("Ayarlar kaydedildi ✅");
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage("Ayarlar kaydedilirken hata oluştu.");
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF5B3A00)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5B3A00),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: child,
    );
  }

  Widget _buildTimeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _timeOptions.map((minute) {
        final selected = _dailyLimitMinutes == minute;

        return ChoiceChip(
          label: Text("$minute dk"),
          selected: selected,
          selectedColor: const Color(0xFFFFD54F),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF5B3A00) : Colors.grey.shade700,
          ),
          onSelected: (_) {
            setState(() {
              _dailyLimitMinutes = minute;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSingleChoice({
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final selected = selectedValue == option;

        return ChoiceChip(
          label: Text(option),
          selected: selected,
          selectedColor: const Color(0xFFFFD54F),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF5B3A00) : Colors.grey.shade700,
          ),
          onSelected: (_) => setState(() => onSelected(option)),
        );
      }).toList(),
    );
  }

  Widget _buildMultiChoice({
    required String title,
    required IconData icon,
    required List<String> options,
    required List<String> selectedValues,
    required TextEditingController otherController,
    required bool showOtherInput,
    required VoidCallback onToggleOther,
    required VoidCallback onAddOther,
  }) {
    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon),
          const SizedBox(height: 6),
          const Text(
            "En fazla 6 seçim yapılabilir.",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A6A00),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final selected = selectedValues.contains(option);

              return FilterChip(
                label: Text(option),
                selected: selected,
                selectedColor: const Color(0xFFFFD54F),
                backgroundColor: Colors.white,
                checkmarkColor: const Color(0xFF5B3A00),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF5B3A00)
                      : Colors.grey.shade700,
                ),
                onSelected: (_) {
                  setState(() {
                    if (selectedValues.contains(option)) {
                      selectedValues.remove(option);
                    } else {
                      if (selectedValues.length >= 6) {
                        _showMessage("En fazla 6 seçim yapabilirsiniz.");
                        return;
                      }
                      selectedValues.add(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedValues
                .where((item) => !options.contains(item))
                .map(
                  (item) => Chip(
                    label: Text(item),
                    deleteIcon: const Icon(Icons.close_rounded),
                    onDeleted: () {
                      setState(() {
                        selectedValues.remove(item);
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onToggleOther,
            icon: Icon(
              showOtherInput ? Icons.close_rounded : Icons.edit_rounded,
            ),
            label: Text(showOtherInput ? "Kapat" : "Yoksa yaz"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B3A00),
              side: const BorderSide(color: Color(0xFFFFC107), width: 1.6),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (showOtherInput) ...[
            const SizedBox(height: 12),
            TextField(
              controller: otherController,
              decoration: InputDecoration(
                hintText: "Yeni seçenek yazın",
                filled: true,
                fillColor: const Color(0xFFFFF8E1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFC107),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onAddOther,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Ekle"),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF5B3A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addOtherInterest() {
    final value = _otherInterestController.text.trim();

    if (value.isEmpty) {
      _showMessage("Lütfen bir ilgi alanı yazın.");
      return;
    }

    if (_interests.length >= 6) {
      _showMessage("En fazla 6 seçim yapabilirsiniz.");
      return;
    }

    if (_interests.contains(value)) {
      _showMessage("Bu ilgi alanı zaten ekli.");
      return;
    }

    setState(() {
      _interests.add(value);
      _otherInterestController.clear();
      _showOtherInterestInput = false;
    });
  }

  void _addOtherGoal() {
    final value = _otherGoalController.text.trim();

    if (value.isEmpty) {
      _showMessage("Lütfen bir gelişim hedefi yazın.");
      return;
    }

    if (_goals.length >= 6) {
      _showMessage("En fazla 6 seçim yapabilirsiniz.");
      return;
    }

    if (_goals.contains(value)) {
      _showMessage("Bu gelişim hedefi zaten ekli.");
      return;
    }

    setState(() {
      _goals.add(value);
      _otherGoalController.clear();
      _showOtherGoalInput = false;
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFFF8E1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFFFC107),
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadSettings(),
      builder: (context, snapshot) {
        if (!_loaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFFFE0A3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFF5B3A00),
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Buradan avatarın konuşma tercihlerini, günlük kullanım süresini, ilgi alanlarını ve gelişim hedeflerini güncelleyebilirsiniz.",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5B3A00),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Günlük Kullanım Süresi", Icons.timer),
                    const SizedBox(height: 14),
                    _buildTimeSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Avatar Bilgileri", Icons.badge_rounded),
                    const SizedBox(height: 14),
                    const Text(
                      "Avatar adı",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _avatarNameController,
                      hint: "Örnek: Pamuk, Maviş, Leo",
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Çocuğun adı",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _userNameController,
                      hint: "Çocuğun adı",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Avatar Karakteri", Icons.face_rounded),
                    const SizedBox(height: 14),
                    const Text(
                      "Cinsiyet",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildSingleChoice(
                      options: const ["Kız", "Erkek"],
                      selectedValue: _gender,
                      onSelected: (value) => _gender = value,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Kişilik",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildSingleChoice(
                      options: const ["Neşeli", "Sakin"],
                      selectedValue: _personality,
                      onSelected: (value) => _personality = value,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Görünüm",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildSingleChoice(
                      options: const ["Renkli", "Sade"],
                      selectedValue: _style,
                      onSelected: (value) => _style = value,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildMultiChoice(
                title: "İlgi Alanları",
                icon: Icons.favorite_rounded,
                options: _interestOptions,
                selectedValues: _interests,
                otherController: _otherInterestController,
                showOtherInput: _showOtherInterestInput,
                onToggleOther: () {
                  setState(() {
                    _showOtherInterestInput = !_showOtherInterestInput;
                  });
                },
                onAddOther: _addOtherInterest,
              ),
              const SizedBox(height: 16),
              _buildMultiChoice(
                title: "Gelişim Hedefleri",
                icon: Icons.trending_up_rounded,
                options: _goalOptions,
                selectedValues: _goals,
                otherController: _otherGoalController,
                showOtherInput: _showOtherGoalInput,
                onToggleOther: () {
                  setState(() {
                    _showOtherGoalInput = !_showOtherGoalInput;
                  });
                },
                onAddOther: _addOtherGoal,
              ),
              const SizedBox(height: 16),
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                      "Dikkat ve Davranış",
                      Icons.psychology_rounded,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Çocuğunuz çabuk sıkılır mı?",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildSingleChoice(
                      options: _boredomOptions,
                      selectedValue: _boredomLevel,
                      onSelected: (value) => _boredomLevel = value,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Ortalama dikkat süresi",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildSingleChoice(
                      options: _attentionOptions,
                      selectedValue: _attentionSpan,
                      onSelected: (value) => _attentionSpan = value,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Ekstra Bilgiler", Icons.note_alt_rounded),
                    const SizedBox(height: 14),
                    const Text(
                      "Çocuğun özellikle sevdiği şeyler",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _extraLikeController,
                      hint: "Örnek: Dinozorlar, robotlar, prensesler...",
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Kaçınılacak konular",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _avoidTopicController,
                      hint: "Örnek: Korkutucu hikayeler, şiddet...",
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _saveSettings,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? "Kaydediliyor..." : "Ayarları Kaydet"),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: const Color(0xFF5B3A00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}