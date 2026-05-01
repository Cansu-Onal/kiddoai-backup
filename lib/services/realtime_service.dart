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

  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(String msg)? onStatus;
  void Function(JsonMap event)? onEvent;

  String? _nickname;
  String? _personality;
  String? _avatarName;

  List _interests = [];
  List _goals = [];

  Future connectAndStartChat({
    required String nickname,
    required String personality,
    required String avatarName,
    List interests = const [],
    List goals = const [],
  }) async {
    try {
      _stopRequested = false;
      _nickname = nickname;
      _personality = personality;
      _avatarName = avatarName;

      _interests = interests;
      _goals = goals;

      onStatus?.call("Bağlanıyor...");

      await _resetChatOnServer();

      if (_stopRequested) return;

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
    if (_isSpeaking) return;

    try {
      _stopRequested = false;

      final nickname = _nickname ?? "Arkadaşım";
      final personality = _personality ?? "Neşeli";
      final avatarName = _avatarName ?? "Arkadaşın";

      onEvent?.call({
        "type": "user_text",
        "text": cleanText,
      });

      onStatus?.call("Avatar düşünüyor...");

      final reply = await _askServer(cleanText);

      if (_stopRequested) return;

      await speakAvatarText(
        text: reply,
        nickname: nickname,
        personality: personality,
        avatarName: avatarName,
        saveToPanel: true,
      );
    } catch (_) {
      onStatus?.call("Cevap gecikti.");

      onEvent?.call({
        "type": "assistant_text",
        "text": "Biraz takıldım. Tekrar söyleyebilir misin?",
        "saveToPanel": false,
      });

      onEvent?.call({
        "type": "assistant_done",
        "saveToPanel": false,
      });
    }
  }

  Future _resetChatOnServer() async {
    try {
      await http.post(Uri.parse("$baseUrl/reset-chat"));
    } catch (_) {}
  }

  Future resetChatOnServer() async {
    try {
      await http.post(Uri.parse("$baseUrl/reset-chat"));
    } catch (_) {}
  }

  Future _askServer(String message) async {
    final askRes = await http.post(
      Uri.parse("$baseUrl/ask"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "message": message,
        "interests": _interests,
        "goals": _goals,
      }),
    );

    final decoded = jsonDecode(askRes.body);
    return decoded["reply"];
  }

  Future<Uint8List?> _getTtsAudio(String text) async {
    try {
      final ttsRes = await http.post(
        Uri.parse("$baseUrl/tts"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      if (!(ttsRes.headers["content-type"] ?? "").contains("audio")) {
        return null;
      }

      return ttsRes.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future _playAudioBytes(Uint8List bytes) async {
    final blob = html.Blob([bytes], "audio/mpeg");
    final url = html.Url.createObjectUrlFromBlob(blob);

    final audio = html.AudioElement()
      ..src = url
      ..autoplay = true;

    await audio.onEnded.first;

    audio.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future speakAvatarText({
    required String text,
    required String nickname,
    required String personality,
    required String avatarName,
    bool saveToPanel = true,
  }) async {
    if (_isSpeaking) return;

    _isSpeaking = true;

    onEvent?.call({
      "type": "assistant_text",
      "text": text,
      "saveToPanel": saveToPanel,
    });

    final audioBytes = await _getTtsAudio(text);

    if (audioBytes != null) {
      onEvent?.call({"type": "assistant_audio_start"});
      await _playAudioBytes(audioBytes);
    }

    _isSpeaking = false;

    onEvent?.call({
      "type": "assistant_done",
      "saveToPanel": saveToPanel,
    });
  }

  Future disconnect() async {
    _stopRequested = true;
    _isSpeaking = false;

    try {
      // varsa çalan ses durdurulur
    } catch (_) {}

    _isConnected = false;
    onDisconnected?.call();
    onStatus?.call("Kapandı.");
  }

  Future dispose() async {
    await disconnect();
  }
}