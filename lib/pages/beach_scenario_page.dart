import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiddoai/services/elevenlabs_voice_service.dart';

class BeachScenarioPage extends StatefulWidget {
  const BeachScenarioPage({super.key});

  @override
  State<BeachScenarioPage> createState() => _BeachScenarioPageState();
}

class _BeachScenarioPageState extends State<BeachScenarioPage>
    with TickerProviderStateMixin {
  final ElevenLabsVoiceService _voice = ElevenLabsVoiceService();

  int _roundIndex = 0;
  bool _locked = false;
  bool _started = false;

  String? _selectedOptionId;
  bool? _lastAnswerCorrect;

  final Set<String> _selectedCorrectIds = {};

  Timer? _hintTimer;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  final List<BeachRound> _rounds = [
    BeachRound(
      roundTitle: "Deniz hazırlığı",
      introVoice: "Önce denize giderken giyeceğimiz şeyleri seçelim.",
      completeVoice: "Harika! Giyilecek doğru şeyleri seçtin.",
      options: [
        BeachOption(
          id: "slippers",
          text: "Terlik",
          image: "assets/images/slippers.jfif",
          isCorrect: true,
          hintVoice: "Ayağımıza denizde rahat olacak ne giyebiliriz?",
          successVoice:
              "Harikasın! Terlik deniz için çok doğru bir seçim.",
        ),
        BeachOption(
          id: "hat",
          text: "Şapka",
          image: "assets/images/hat.jfif",
          isCorrect: true,
          hintVoice: "Güneşte başımızı korumak için ne alabiliriz?",
          successVoice:
              "Süpersin! Şapka güneşte başımızı korur. Çok iyi seçtin.",
        ),
        BeachOption(
          id: "boots",
          text: "Bot",
          image: "assets/images/boots.jfif",
          isCorrect: false,
          wrongVoice:
              "Güzel düşündün ama bot denizde biraz zor olur. Bir daha deneyelim.",
        ),
        BeachOption(
          id: "gloves",
          text: "Eldiven",
          image: "assets/images/gloves.jfif",
          isCorrect: false,
          wrongVoice:
              "İyi deneme! Eldiven daha çok kışın işe yarar. Deniz için tekrar bakalım.",
        ),
      ],
    ),
    BeachRound(
      roundTitle: "Çantaya koyalım",
      introVoice: "Şimdi deniz çantamıza koyacağımız şeyleri seçelim.",
      completeVoice: "Çok iyi! Çantamız için doğru seçimler yaptın.",
      options: [
        BeachOption(
          id: "towel",
          text: "Havlu",
          image: "assets/images/towel.jfif",
          isCorrect: true,
          hintVoice: "Denizden çıkınca kurulanmak için ne gerekir?",
          successVoice:
              "Aferin sana! Havlu denizden sonra kurulanmak için çok işe yarar.",
        ),
        BeachOption(
          id: "sunscreen",
          text: "Güneş kremi",
          image: "assets/images/sunscreen.jfif",
          isCorrect: true,
          hintVoice: "Güneşten korunmak için cildimize ne sürebiliriz?",
          successVoice:
              "Mükemmel seçim! Güneş kremi cildimizi güneşten korur.",
        ),
        BeachOption(
          id: "jacket",
          text: "Mont",
          image: "assets/images/jacket.jfif",
          isCorrect: false,
          wrongVoice:
              "Güzel deneme! Mont sıcak havada fazla olur. Başka hangisi olabilir?",
        ),
        BeachOption(
          id: "toothbrush",
          text: "Diş fırçası",
          image: "assets/images/toothbrush.jfif",
          isCorrect: false,
          wrongVoice:
              "Çok güzel denedin ama diş fırçası dişlerimiz içindir. Güneşte ne kullanırız?",
        ),
      ],
    ),
    BeachRound(
      roundTitle: "Sıcak hava seçimi",
      introVoice: "Son olarak sıcak havada rahat edeceğimiz kıyafetleri seçelim.",
      completeVoice: "Bravo! Sıcak hava için çok güzel seçim yaptın.",
      options: [
        BeachOption(
          id: "shorts",
          text: "Şort",
          image: "assets/images/shorts.jfif",
          isCorrect: true,
          hintVoice: "Sıcak havada bacaklarımız için hangisi daha rahat olur?",
          successVoice: "Çok güzel! Şort sıcak havada rahat bir seçim olur.",
        ),
        BeachOption(
          id: "tshirt",
          text: "Tişört",
          image: "assets/images/tshirt.jfif",
          isCorrect: true,
          hintVoice: "Denize giderken üstümüze ne giymek daha rahat olur?",
          successVoice: "Bravo! Tişört denize giderken daha rahat olur.",
        ),
        BeachOption(
          id: "jeans",
          text: "Kot pantolon",
          image: "assets/images/jeans.jfif",
          isCorrect: false,
          wrongVoice:
              "İyi düşündün ama kot pantolon denizde biraz rahatsız olabilir. Tekrar bakalım.",
        ),
        BeachOption(
          id: "sweater",
          text: "Kazak",
          image: "assets/images/sweater.jfif",
          isCorrect: false,
          wrongVoice:
              "Güzel deneme! Kazak soğuk havalar içindir. Deniz için hangisi daha iyi?",
        ),
      ],
    ),
  ];

  BeachRound get _currentRound => _rounds[_roundIndex];

  int get _correctNeeded =>
      _currentRound.options.where((option) => option.isCorrect).length;

  int get _correctSelectedCount =>
      _selectedCorrectIds.where((id) {
        return _currentRound.options.any(
          (option) => option.id == id && option.isCorrect,
        );
      }).length;

  bool get _roundCompleted => _correctSelectedCount >= _correctNeeded;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _bounceController,
        curve: Curves.elasticOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScenario();
    });
  }

  Future<void> _startScenario() async {
    if (_started) return;

    setState(() {
      _started = true;
      _locked = true;
    });

    await _voice.speak(
      "Haydi denize giderken yanımıza alacağımız şeyleri seçelim.",
    );

    if (!mounted) return;

    await _voice.speak(_currentRound.introVoice);

    if (!mounted) return;

    setState(() {
      _locked = false;
    });

    _scheduleHint();
  }

  void _scheduleHint() {
    _hintTimer?.cancel();

    if (_locked || _roundCompleted) return;

    _hintTimer = Timer(const Duration(seconds: 7), () async {
      if (!mounted || _locked || _roundCompleted) return;

      final next = _nextMissingCorrectOption();
      if (next == null) return;

      setState(() {
        _locked = true;
      });

      await _voice.speak(next.hintVoice ?? "Tekrar bakalım. Doğru olanı seçelim.");

      if (!mounted) return;

      setState(() {
        _locked = false;
      });

      _scheduleHint();
    });
  }

  BeachOption? _nextMissingCorrectOption() {
    for (final option in _currentRound.options) {
      if (option.isCorrect && !_selectedCorrectIds.contains(option.id)) {
        return option;
      }
    }
    return null;
  }

  Future<void> _clickSound() async {
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> _handleChoice(BeachOption option) async {
    if (_locked) return;

    if (option.isCorrect && _selectedCorrectIds.contains(option.id)) {
      return;
    }

    _hintTimer?.cancel();

    await _clickSound();

    setState(() {
      _locked = true;
      _selectedOptionId = option.id;
      _lastAnswerCorrect = option.isCorrect;
    });

    _bounceController.forward(from: 0);

    if (option.isCorrect) {
      setState(() {
        _selectedCorrectIds.add(option.id);
      });

      await _voice.speak(option.successVoice ?? "Harikasın! Çok güzel seçtin.");

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if (_roundCompleted) {
        await _completeRound();
      } else {
        setState(() {
          _locked = false;
          _selectedOptionId = null;
          _lastAnswerCorrect = null;
        });

        _scheduleHint();
      }
    } else {
      await _voice.speak(
        option.wrongVoice ?? "Güzel deneme! Bir daha bakalım.",
      );

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
        _locked = false;
        _selectedOptionId = null;
        _lastAnswerCorrect = null;
      });

      _scheduleHint();
    }
  }

  Future<void> _completeRound() async {
    await _voice.speak(_currentRound.completeVoice);

    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    if (_roundIndex == _rounds.length - 1) {
      await _showFinishDialog();
      return;
    }

    setState(() {
      _roundIndex++;
      _selectedCorrectIds.clear();
      _selectedOptionId = null;
      _lastAnswerCorrect = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await _voice.speak(_currentRound.introVoice);

    if (!mounted) return;

    setState(() {
      _locked = false;
    });

    _scheduleHint();
  }

  Future<void> _repeatInstruction() async {
    if (_locked) return;

    _hintTimer?.cancel();

    setState(() {
      _locked = true;
    });

    final next = _nextMissingCorrectOption();

    if (next != null) {
      await _voice.speak(next.hintVoice ?? _currentRound.introVoice);
    } else {
      await _voice.speak(_currentRound.introVoice);
    }

    if (!mounted) return;

    setState(() {
      _locked = false;
    });

    _scheduleHint();
  }

  Future<void> _showFinishDialog() async {
    await _voice.speak(
      "Tebrikler! Harika seçimler yaptın. Deniz çantamız hazır oldu.",
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Text(
            "Harika! 🎉",
            textAlign: TextAlign.center,
          ),
          content: const Text(
            "Deniz çantamız hazır oldu!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _restartGame();
              },
              child: const Text("Tekrar Oyna"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text("Ana Sayfa"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _restartGame() async {
    _hintTimer?.cancel();

    setState(() {
      _roundIndex = 0;
      _locked = false;
      _selectedOptionId = null;
      _lastAnswerCorrect = null;
      _selectedCorrectIds.clear();
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await _voice.speak(_currentRound.introVoice);

    if (!mounted) return;

    _scheduleHint();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _voice.stop();
    _voice.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_roundIndex + 1) / _rounds.length;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -42,
              right: -32,
              child: Container(
                width: 135,
                height: 135,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -55,
              left: -35,
              child: Container(
                width: 190,
                height: 125,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCC80),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(100),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          onPressed: () async {
                            _hintTimer?.cancel();
                            await _voice.stop();
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF00796B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: Colors.white,
                            color: const Color(0xFF26C6DA),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${_roundIndex + 1}/${_rounds.length}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          offset: Offset(0, 5),
                          color: Color(0x22000000),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("🏖️", style: TextStyle(fontSize: 40)),
                            SizedBox(width: 14),
                            Text("🌊", style: TextStyle(fontSize: 40)),
                            SizedBox(width: 14),
                            Text("☀️", style: TextStyle(fontSize: 40)),
                            SizedBox(width: 14),
                            Text("👜", style: TextStyle(fontSize: 40)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "2 doğru eşyayı seçelim",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00796B),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _locked ? null : _repeatInstruction,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text("Tekrar Dinle"),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF26C6DA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentRound.options.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final option = _currentRound.options[index];
                        final isSelected = _selectedOptionId == option.id;
                        final isCorrectSelected =
                            _selectedCorrectIds.contains(option.id);

                        final showWrong =
                            isSelected && _lastAnswerCorrect == false;

                        Color borderColor = Colors.white;
                        Color cardColor = Colors.white;

                        if (isCorrectSelected) {
                          borderColor = const Color(0xFF43A047);
                          cardColor = const Color(0xFFE8F5E9);
                        } else if (showWrong) {
                          borderColor = const Color(0xFFFFA726);
                          cardColor = const Color(0xFFFFF3E0);
                        }

                        return ScaleTransition(
                          scale: isSelected
                              ? _bounceAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: _ChoiceCard(
                            text: option.text,
                            image: option.image,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            isCorrectSelected: isCorrectSelected,
                            onTap: () => _handleChoice(option),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _lastAnswerCorrect == null
                        ? Text(
                            "Seçilen doğru: $_correctSelectedCount/$_correctNeeded 😊",
                            key: const ValueKey("neutral"),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00796B),
                            ),
                          )
                        : Text(
                            _lastAnswerCorrect == true
                                ? "Harikasın! ⭐"
                                : "Bir daha deneyelim 😊",
                            key: ValueKey(_lastAnswerCorrect),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _lastAnswerCorrect == true
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFF57C00),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String text;
  final String image;
  final Color cardColor;
  final Color borderColor;
  final bool isCorrectSelected;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.text,
    required this.image,
    required this.cardColor,
    required this.borderColor,
    required this.isCorrectSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(28),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: borderColor,
              width: 5,
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported_rounded,
                          size: 64,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              if (isCorrectSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF43A047),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BeachRound {
  final String roundTitle;
  final String introVoice;
  final String completeVoice;
  final List<BeachOption> options;

  const BeachRound({
    required this.roundTitle,
    required this.introVoice,
    required this.completeVoice,
    required this.options,
  });
}

class BeachOption {
  final String id;
  final String text;
  final String image;
  final bool isCorrect;
  final String? hintVoice;
  final String? successVoice;
  final String? wrongVoice;

  const BeachOption({
    required this.id,
    required this.text,
    required this.image,
    required this.isCorrect,
    this.hintVoice,
    this.successVoice,
    this.wrongVoice,
  });
}