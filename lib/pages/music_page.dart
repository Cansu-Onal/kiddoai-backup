import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _Song {
  final String title;
  final String audioPath;
  final String bgPath;

  const _Song({
    required this.title,
    required this.audioPath,
    required this.bgPath,
  });
}

class _MusicPageState extends State<MusicPage> {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  final List<_Song> _songs = const [
    _Song(
      title: "Ali Baba'nın Çiftliği",
      audioPath: "audio/ali_babanin_ciftligi.mp3",
      bgPath: "assets/audio/ali_babanin_ciftligi_bg.jpg",
    ),
    _Song(
      title: "Arkadaşım Eşek",
      audioPath: "audio/arkadasim_esek.mp3",
      bgPath: "assets/audio/arkadasim_esek_bg.jpg",
    ),
    _Song(
      title: "Ilgaz Anadolu",
      audioPath: "audio/ilgaz_anadolu.mp3",
      bgPath: "assets/audio/ilgaz_anadolu_bg.jpg",
    ),
    _Song(
      title: "İzmir Marşı",
      audioPath: "audio/izmir_marsi.mp3",
      bgPath: "assets/audio/izmir_marsi_bg.png",
    ),
    _Song(
      title: "Kırmızı Balık",
      audioPath: "audio/kirmizi_balik.mp3",
      bgPath: "assets/audio/kirmizi_balik_bg.png",
    ),
    _Song(
      title: "Mini Mini Bir Kuş",
      audioPath: "audio/mini_mini_bir_kus.mp3",
      bgPath: "assets/audio/mini_mini_bir_kus_bg.png",
    ),
  ];

  int? _selectedIndex;
  int? _playingIndex;

  bool _isPlaying = false;
  bool _isMuted = false;
  bool _fullPlayerOpen = false;

  double _volume = 0.8;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initTts();
    _listenPlayer();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("tr-TR");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  void _listenPlayer() {
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });

    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  Future<void> _speakSongName(String title) async {
    try {
      await _tts.stop();
      await _tts.speak(title);
    } catch (_) {}
  }

  Future<void> _handleSongTap(int index) async {
    final song = _songs[index];

    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });

      await _speakSongName(song.title);
      return;
    }

    await _playSong(index);
  }

  Future<void> _playSong(int index) async {
    final song = _songs[index];

    await _tts.stop();
    await _player.stop();
    await _player.setVolume(_isMuted ? 0 : _volume);
    await _player.play(AssetSource(song.audioPath));

    if (!mounted) return;

    setState(() {
      _playingIndex = index;
      _selectedIndex = index;
      _fullPlayerOpen = true;
      _isPlaying = true;
      _position = Duration.zero;
    });
  }

  Future<void> _togglePlayPause() async {
    if (_playingIndex == null) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _stopSong() async {
    await _player.stop();

    if (!mounted) return;

    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
    });
  }

  Future<void> _stopEverything() async {
    try {
      await _tts.stop();
    } catch (_) {}

    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> _seekForward() async {
    final next = _position + const Duration(seconds: 10);
    await _player.seek(next > _duration ? _duration : next);
  }

  Future<void> _seekBackward() async {
    final previous = _position - const Duration(seconds: 10);
    await _player.seek(previous < Duration.zero ? Duration.zero : previous);
  }

  Future<void> _changeVolume(double value) async {
    setState(() {
      _volume = value;
      _isMuted = value == 0;
    });

    await _player.setVolume(_isMuted ? 0 : _volume);
  }

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });

    await _player.setVolume(_isMuted ? 0 : _volume);
  }

  Future<void> _closeFullPlayer() async {
    setState(() {
      _fullPlayerOpen = false;
    });
  }

  Future<bool> _onWillPop() async {
    await _stopEverything();
    return true;
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _stateSub?.cancel();

    _tts.stop();
    _player.stop();
    _player.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _fullPlayerOpen && _playingIndex != null
          ? _buildFullPlayer(_songs[_playingIndex!])
          : _buildSongList(),
    );
  }

  Widget _buildSongList() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7D6),
      appBar: AppBar(
        title: const Text("Şarkılar 🎵"),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          final song = _songs[index];
          final isSelected = _selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              elevation: isSelected ? 6 : 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _handleSongTap(index),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.play_circle_fill_rounded
                            : Icons.music_note_rounded,
                        size: 34,
                        color: const Color(0xFF6B3F00),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          song.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4A3000),
                          ),
                        ),
                      ),
                      Text(
                        isSelected ? "Tekrar tıkla" : "Dinle",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.brown.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFullPlayer(_Song song) {
    final maxSeconds = _duration.inSeconds.toDouble();
    final currentSeconds = _position.inSeconds.toDouble();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            song.bgPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                color: const Color(0xFFFFD54F),
              );
            },
          ),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _closeFullPlayer,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _stopSong,
                        icon: const Icon(
                          Icons.stop_circle_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3B2F00),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Slider(
                          value: maxSeconds == 0
                              ? 0
                              : currentSeconds.clamp(0, maxSeconds),
                          max: maxSeconds == 0 ? 1 : maxSeconds,
                          onChanged: (value) async {
                            await _player.seek(
                              Duration(seconds: value.toInt()),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(_position),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              _formatTime(_duration),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: _seekBackward,
                              icon: const Icon(Icons.replay_10_rounded),
                              iconSize: 38,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _togglePlayPause,
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                              iconSize: 72,
                              color: const Color(0xFFFF9800),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _seekForward,
                              icon: const Icon(Icons.forward_10_rounded),
                              iconSize: 38,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _isMuted ? 0 : _volume,
                                min: 0,
                                max: 1,
                                onChanged: _changeVolume,
                              ),
                            ),
                          ],
                        ),
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
    );
  }
}