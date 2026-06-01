import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

typedef JsonMap = Map<String, dynamic>;

class RealtimeService {
  static const String baseUrl = "http://localhost:3000";

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _stopRequested = false;
  bool get stopRequested => _stopRequested;

  bool _isSpeaking = false;
  bool _isSending = false;

  html.AudioElement? _currentAudio;

  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(String msg)? onStatus;
  void Function(JsonMap event)? onEvent;

  String? _nickname;
  String? _personality;
  String? _avatarName;

  List _interests = [];
  List _goals = [];

  final List<Map<String, String>> _history = [];

  Future connectAndStartChat({
    required String nickname,
    required String personality,
    required String avatarName,
    List interests = const [],
    List goals = const [],
  }) async {
    try {
      _stopRequested = false;
      _isSending = false;
      _isSpeaking = false;

      _nickname = nickname;
      _personality = personality;
      _avatarName = avatarName;

      _interests = interests;
      _goals = goals;
      _history.clear();

      onStatus?.call("Bağlanıyor...");

      _isConnected = true;
      onConnected?.call();
      onStatus?.call("Sohbet hazır");
    } catch (e) {
      _isConnected = false;
      onStatus?.call("Bağlantı hatası.");

      onEvent?.call({
        "type": "assistant_error",
        "message": e.toString(),
      });

      rethrow;
    }
  }

  Future sendText(String text) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return;
    if (!_isConnected) return;
    if (_isSpeaking || _isSending) return;

    _isSending = true;

    try {
      _stopRequested = false;

      final nickname = _nickname ?? "Arkadaşım";
      final personality = _personality ?? "Neşeli";
      final avatarName = _avatarName ?? "Arkadaşın";

      onEvent?.call({
        "type": "user_text",
        "text": cleanText,
      });

      _addHistory("child", cleanText);

      onStatus?.call("Avatar düşünüyor...");

      final reply = await _askServer(cleanText);

      if (_stopRequested) return;

      final cleanReply = reply.trim();

      if (cleanReply.isEmpty) {
        throw Exception("Boş cevap geldi.");
      }

      _addHistory("assistant", cleanReply);

      await speakAvatarText(
        text: cleanReply,
        nickname: nickname,
        personality: personality,
        avatarName: avatarName,
        saveToPanel: true,
      );
    } on TimeoutException {
      onStatus?.call("İstek uzun sürdü, tekrar deneyebilirsin.");

      onEvent?.call({
        "type": "assistant_text",
        "text": "Biraz bekledim ama cevap gecikti. Tekrar söyler misin?",
        "saveToPanel": false,
      });

      onEvent?.call({
        "type": "assistant_done",
        "saveToPanel": false,
      });
    } catch (e) {
      onStatus?.call("Bir sorun oldu, tekrar deneyebilirsin.");

      onEvent?.call({
        "type": "assistant_error",
        "message": e.toString(),
      });

      onEvent?.call({
        "type": "assistant_text",
        "text": "Biraz takıldım. Tekrar söyleyebilir misin?",
        "saveToPanel": false,
      });

      onEvent?.call({
        "type": "assistant_done",
        "saveToPanel": false,
      });
    } finally {
      _isSending = false;
    }
  }

  void _addHistory(String role, String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _history.add({
      "role": role,
      "text": clean,
    });

    if (_history.length > 10) {
      _history.removeRange(0, _history.length - 10);
    }
  }

  Future<String> _askServer(String message) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/chat"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "message": message,
            "childText": message,
            "history": _history,
            "interests": _interests,
            "goals": _goals,
            "nickname": _nickname ?? "",
            "personality": _personality ?? "",
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception("Chat API hata: ${response.statusCode} ${response.body}");
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    final reply = (decoded["reply"] ?? decoded["text"] ?? "").toString();

    if (reply.trim().isEmpty) {
      throw Exception("Chat API boş cevap döndürdü.");
    }

    return reply;
  }

  Future<Uint8List?> _getTtsAudio(String text) async {
    try {
      final cleanText = text.trim();
      if (cleanText.isEmpty) return null;

      final ttsRes = await http
          .post(
            Uri.parse("$baseUrl/tts"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": cleanText}),
          )
          .timeout(const Duration(seconds: 60));

      if (ttsRes.statusCode != 200) {
        throw Exception("TTS API hata: ${ttsRes.statusCode}");
      }

      final contentType = ttsRes.headers["content-type"] ?? "";

      if (!contentType.contains("audio")) {
        return null;
      }

      return ttsRes.bodyBytes;
    } catch (e) {
      onEvent?.call({
        "type": "assistant_error",
        "message": "TTS hata: $e",
      });

      return null;
    }
  }

  Future _playAudioBytes(Uint8List bytes) async {
    final blob = html.Blob([bytes], "audio/mpeg");
    final url = html.Url.createObjectUrlFromBlob(blob);

    final audio = html.AudioElement()
      ..src = url
      ..autoplay = true;

    _currentAudio = audio;

    try {
      await audio.onEnded.first.timeout(const Duration(seconds: 40));
    } catch (_) {
      try {
        audio.pause();
      } catch (_) {}
    } finally {
      audio.remove();
      html.Url.revokeObjectUrl(url);

      if (_currentAudio == audio) {
        _currentAudio = null;
      }
    }
  }

  Future speakAvatarText({
    required String text,
    required String nickname,
    required String personality,
    required String avatarName,
    bool saveToPanel = true,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    if (_isSpeaking) return;

    _isSpeaking = true;

    try {
      onEvent?.call({
        "type": "assistant_text",
        "text": cleanText,
        "saveToPanel": saveToPanel,
      });

      onStatus?.call("Avatar sesi hazırlanıyor...");

      final audioBytes = await _getTtsAudio(cleanText);

      if (_stopRequested) return;

      if (audioBytes != null) {
        onEvent?.call({"type": "assistant_audio_start"});
        onStatus?.call("Avatar konuşuyor...");
        await _playAudioBytes(audioBytes);
      } else {
        onStatus?.call("Ses hazırlanamadı.");
      }
    } finally {
      _isSpeaking = false;

      onEvent?.call({
        "type": "assistant_done",
        "saveToPanel": saveToPanel,
      });

      if (_isConnected && !_stopRequested) {
        onStatus?.call("Sohbet hazır");
      }
    }
  }

  Future resetChatOnServer() async {
    _history.clear();
  }

  Future disconnect() async {
    _stopRequested = true;
    _isSpeaking = false;
    _isSending = false;

    try {
      _currentAudio?.pause();
      _currentAudio?.remove();
      _currentAudio = null;
    } catch (_) {}

    _history.clear();

    _isConnected = false;
    onDisconnected?.call();
    onStatus?.call("Kapandı.");
  }

  Future dispose() async {
    await disconnect();
  }
}