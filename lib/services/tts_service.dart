import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._internal();

  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  String _personality = "Normal";
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _tts.setLanguage("tr-TR");
    await _tts.setVolume(1.0);

    // Konuşma bitmeden assistant_done gitmesin diye TRUE olmalı
    await _tts.awaitSpeakCompletion(true);

    _isInitialized = true;
    await applyPersonality(_personality);
  }

  Future<void> applyPersonality(String personality) async {
    _personality = personality;

    await _tts.setLanguage("tr-TR");
    await _tts.setVolume(1.0);

    if (personality == "Neşeli") {
      await _tts.setSpeechRate(0.54);
      await _tts.setPitch(1.25);
    } else if (personality == "Sakin") {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.05);
    } else {
      await _tts.setSpeechRate(0.50);
      await _tts.setPitch(1.12);
    }
  }

  String get personality => _personality;

  Future<void> speak(String text) async {
    await init();

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    await applyPersonality(_personality);
    await _tts.stop();
    await _tts.speak(cleanText);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}