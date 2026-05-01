import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AnimatedAvatar extends StatefulWidget {
  final bool isTalking;
  final double width;
  final double headSize;
  final double headOffsetY;

  const AnimatedAvatar({
    super.key,
    required this.isTalking,
    this.width = 320,
    this.headSize = 200,
    this.headOffsetY = -70,
  });

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar> {
  static const String _normalImage = 'assets/avatars/boy_normal.png';
  static const String _talkingVideo = 'assets/videos/talking.mp4';

  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset(_talkingVideo);

    await _videoController!.initialize();
    await _videoController!.setLooping(true);
    await _videoController!.setVolume(0.0); // video sesi kapalı

    if (mounted) {
      setState(() {
        _isVideoReady = true;
        _showVideo = widget.isTalking;
      });
    }

    if (widget.isTalking) {
      await _videoController!.seekTo(Duration.zero);
      await _videoController!.play();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isTalking != widget.isTalking) {
      _handleTalkingChange();
    }
  }

  Future<void> _handleTalkingChange() async {
    if (_videoController == null || !_isVideoReady) return;

    if (widget.isTalking) {
      if (mounted) {
        setState(() {
          _showVideo = true;
        });
      }

      await _videoController!.seekTo(Duration.zero);
      await _videoController!.play();
    } else {
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);

      if (mounted) {
        setState(() {
          _showVideo = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showVideo &&
        _videoController != null &&
        _isVideoReady &&
        _videoController!.value.isInitialized) {
      return SizedBox(
        width: widget.width,
        height: widget.width,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.width,
      child: Image.asset(
        _normalImage,
        width: widget.width,
        height: widget.width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}