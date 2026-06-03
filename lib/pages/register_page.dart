import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'avatar_questions_page.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLogin = false;
  bool _isBusy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFFC107),
        content: Text(
          msg,
          style: const TextStyle(
            color: Color(0xFF3B2F00),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<bool> _showConsentDialog() async {
    bool approved = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("İzin ve Onay"),
          content: const SingleChildScrollView(
            child: Text(
              "Kayıt tamamlanmadan önce aşağıdakileri onaylamanız gerekir:\n\n"
              "• Uygulama ses/konuşma çıktısı verebilir.\n"
              "• Uygulama, çocukla etkileşim için metin/ses yanıtları üretir.\n"
              "• Ebeveyn bilgilendirmesi ve güvenlik kurallarını okudum.\n\n"
              "Onaylıyor musunuz?",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                approved = false;
                Navigator.pop(ctx);
              },
              child: const Text("Onaylamıyorum"),
            ),
            FilledButton(
              onPressed: () {
                approved = true;
                Navigator.pop(ctx);
              },
              child: const Text("Onaylıyorum"),
            ),
          ],
        );
      },
    );

    return approved;
  }

  Future<void> _goHomePage() async {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePage(
          nickname: "Arkadaşım",
          personality: "Neşeli",
          dailyLimitMinutes: 30,
        ),
      ),
    );
  }

  Future<void> _goAvatarQuestions() async {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const AvatarQuestionsPage(),
      ),
    );
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten hesap var. Giriş yapmayı dene.';
      case 'invalid-email':
        return 'E-posta formatı hatalı.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre yanlış.';
      case 'network-request-failed':
        return 'İnternet bağlantını kontrol et.';
      default:
        return 'Bir hata oluştu: ${e.message ?? e.code}';
    }
  }

  Future<void> _handleLogin({
    required String email,
    required String pass,
  }) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: pass,
    );

    _showSnack("Giriş başarılı.");
    await _goHomePage();
  }

  Future<void> _handleRegister({
    required String email,
    required String pass,
  }) async {
    if (pass.length < 6) {
      _showSnack("Şifre en az 6 karakter olmalı.");
      return;
    }

    final consent = await _showConsentDialog();
    if (!consent) {
      _showSnack("Onay verilmeden kayıt tamamlanamaz.");
      return;
    }

    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: pass,
    );

    _showSnack("Kayıt tamamlandı.");
    await _goAvatarQuestions();
  }

  Future<void> _onMainButtonPressed() async {
    if (_isBusy) return;

    final email = _emailController.text.trim();
    final pass = _passController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _showSnack("Lütfen e-posta ve şifre giriniz.");
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      if (_isLogin) {
        await _handleLogin(email: email, pass: pass);
      } else {
        await _handleRegister(email: email, pass: pass);
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_firebaseErrorMessage(e));
    } catch (e) {
      _showSnack("Beklenmeyen hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _emailController.clear();
      _passController.clear();
      _obscurePassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF9C4);

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isLogin ? "Giriş Yap" : "Kayıt Ol"),
        centerTitle: true,
        backgroundColor: background,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isLogin
                              ? Icons.lock_open_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 72,
                          color: const Color(0xFF6B4E00),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isLogin ? "Giriş Yap" : "Kayıt Ol",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3B2F00),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? "Hesabınla giriş yap."
                              : "Ebeveyn hesabını oluştur.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF6B4E00),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: "E-posta",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: "Şifre",
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? "Şifreyi göster"
                                  : "Şifreyi gizle",
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF6B4E00),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _isBusy ? null : _onMainButtonPressed,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: const Color(0xFF3B2F00),
                              disabledBackgroundColor:
                                  const Color(0xFFFFE082),
                            ),
                            child: _isBusy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: Color(0xFF3B2F00),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? "Giriş Yap" : "Kayıt Ol",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isLogin
                                ? "Hesabın yok mu? Kayıt Ol"
                                : "Zaten hesabın var mı? Giriş Yap",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B4E00),
                            ),
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
      ),
    );
  }
}