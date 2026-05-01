import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DailyUsageGuard extends StatefulWidget {
  final Widget child;
  final int dailyLimitMinutes;
  final String avatarName;

  const DailyUsageGuard({
    super.key,
    required this.child,
    required this.dailyLimitMinutes,
    required this.avatarName,
  });

  @override
  State<DailyUsageGuard> createState() => _DailyUsageGuardState();
}

class _DailyUsageGuardState extends State<DailyUsageGuard> {
  Timer? _timer;
  bool _limitReached = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer(Duration(minutes: widget.dailyLimitMinutes), () {
      if (!mounted) return;

      setState(() {
        _limitReached = true;
      });

      Future.delayed(const Duration(seconds: 5), () {
        SystemNavigator.pop();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitReached) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.nightlight_round,
                    size: 72,
                    color: Color(0xFF7E57C2),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "${widget.avatarName} uykuya gidiyor 🌙",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5B3A00),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Benim uyku saatim geldi. Bugünlük bu kadar yeterli. Yarın yine görüşürüz!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D4C41),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "Uygulama birazdan kapanacak.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}