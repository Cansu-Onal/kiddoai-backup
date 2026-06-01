import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'story_detail_page.dart';

class StoryModel {
  final int id;
  final String baslik;
  final String kategori;
  final List<String> karakterler;
  final String metin;
  final String mesaj;
  final String animasyonIpuclari;

  StoryModel({
    required this.id,
    required this.baslik,
    required this.kategori,
    required this.karakterler,
    required this.metin,
    required this.mesaj,
    required this.animasyonIpuclari,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] ?? 0,
      baslik: json['baslik'] ?? '',
      kategori: json['kategori'] ?? '',
      karakterler: List<String>.from(json['karakterler'] ?? []),
      metin: json['metin'] ?? '',
      mesaj: json['mesaj'] ?? '',
      animasyonIpuclari: json['animasyon_ipuclari'] ?? '',
    );
  }
}

class StoryPage extends StatefulWidget {
  final String nickname;
  final String personality;
  final String avatarName;

  const StoryPage({
    super.key,
    required this.nickname,
    required this.personality,
    required this.avatarName,
  });

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Future<List<StoryModel>> _storiesFuture;
  final AudioPlayer _player = AudioPlayer();

  int? _lastTappedStoryId;
  bool _isSpeaking = false;

  String _gender = "Erkek";

  static String get _baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }

  @override
  void initState() {
    super.initState();
    _storiesFuture = _loadStories();
    _loadGender();

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _loadGender() async {
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
      debugPrint("StoryPage gender okunamadı: $e");
    }
  }

  Future<List<StoryModel>> _loadStories() async {
    final String jsonString =
        await rootBundle.loadString('assets/masallar.json');

    final List<dynamic> jsonData = json.decode(jsonString);

    return jsonData.map((e) => StoryModel.fromJson(e)).toList();
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

    try {
      setState(() => _isSpeaking = true);

      await _player.stop();

      final bytes = await _getTtsBytes(cleanText);

      await _player.play(BytesSource(bytes));
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSpeaking = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ses oynatılamadı: $e")),
      );
    }
  }

  Future<void> _speakTitle(StoryModel story) async {
    setState(() {
      _lastTappedStoryId = story.id;
    });

    await _speakText(story.baslik);
  }

  Future<void> _handleStoryTap(StoryModel story) async {
    if (_lastTappedStoryId == story.id) {
      await _player.stop();

      if (!mounted) return;

      setState(() => _isSpeaking = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryDetailPage(
            story: story,
            nickname: widget.nickname,
            personality: widget.personality,
            avatarName: widget.avatarName,
          ),
        ),
      );
      return;
    }

    await _speakTitle(story);
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text("Masallar"),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: FutureBuilder<List<StoryModel>>(
        future: _storiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Masallar yüklenemedi.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final stories = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stories.length,
            itemBuilder: (context, index) {
              final story = stories[index];
              final bool isSelected = _lastTappedStoryId == story.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? Border.all(color: Colors.orange.shade400, width: 2)
                      : null,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.auto_stories, color: Colors.orange),
                  ),
                  title: Text(
                    story.baslik,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isSelected && _isSpeaking
                          ? "Başlık okunuyor..."
                          : story.kategori,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: Icon(
                    isSelected
                        ? Icons.play_circle_fill_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isSelected ? 28 : 18,
                    color: isSelected ? Colors.orange.shade700 : null,
                  ),
                  onTap: () => _handleStoryTap(story),
                ),
              );
            },
          );
        },
      ),
    );
  }
}