import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ElevenLabsVoiceService {
  final AudioPlayer _player = AudioPlayer();

  bool _disposed = false;

  String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000";
    }
    return "http://10.0.2.2:3000";
  }

  Future<void> speak(String text, {String gender = "Erkek"}) async {
    if (_disposed) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    StreamSubscription<void>? completeSub;

    try {
      await _player.stop();

      final response = await http
          .post(
            Uri.parse("$baseUrl/tts"),
            headers: {
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "text": cleanText,
              "gender": gender,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (_disposed) return;

      if (response.statusCode != 200) {
        debugPrint("TTS HTTP hata: ${response.statusCode}");
        debugPrint(response.body);
        return;
      }

      final contentType = response.headers["content-type"] ?? "";
      if (!contentType.contains("audio")) {
        debugPrint("TTS audio dönmedi:");
        debugPrint(response.body);
        return;
      }

      final completer = Completer<void>();

      completeSub = _player.onPlayerComplete.listen((_) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await _player.play(BytesSource(response.bodyBytes));

      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () async {
          await _player.stop();
        },
      );
    } catch (e) {
      debugPrint("ElevenLabs ses hatası: $e");
    } finally {
      await completeSub?.cancel();
    }
  }

  Future<void> stop() async {
    if (_disposed) return;

    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      await _player.stop();
      await _player.dispose();
    } catch (_) {}
  }
}