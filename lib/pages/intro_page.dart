import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'register_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  late VideoPlayerController _controller;
  bool _isReady = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset("assets/videos/intro.mp4")
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setLooping(false);
        _controller.setVolume(1.0);
        setState(() {
          _isReady = true;
        });
      });

    _controller.addListener(() {
      if (!_controller.value.isInitialized) return;

      final position = _controller.value.position;
      final duration = _controller.value.duration;

      if (duration != Duration.zero &&
          position >= duration &&
          !_controller.value.isPlaying) {
        _skip();
      }
    });
  }

  Future<void> _startIntro() async {
    if (!_isReady) return;

    setState(() {
      _hasStarted = true;
    });

    await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

          Container(
            color: Colors.black.withOpacity(_hasStarted ? 0.3 : 0.45),
          ),

          if (!_hasStarted)
            Center(
              child: FilledButton(
                onPressed: _isReady ? _startIntro : null,
                child: Text(_isReady ? "Başla" : "Yükleniyor..."),
              ),
            ),

          if (_hasStarted)
            const Positioned(
              bottom: 120,
              left: 20,
              right: 20,
              child: Text(
                "KiddoAI’ye Hoş Geldin\n\n"
                "Bu uygulama, çocukların eğlenerek öğrenmesini sağlar.\n"
                "Kendi avatarını oluştur ve keşfetmeye başla!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _skip,
              child: const Text(
                "Atla",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}