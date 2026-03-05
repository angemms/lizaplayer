import 'package:flutter/material.dart';
import 'package:lizaplayer/services/token_storage.dart';
import 'package:lizaplayer/screens/home_screen.dart';
import 'dart:math';
import 'dart:ui';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final TextEditingController _tokenController = TextEditingController();

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    );

    _waveController.value = Random().nextDouble();
    _waveController.repeat();
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token cannot be empty')));
      return;
    }
    await TokenStorage.saveToken(token);
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(token: token)));
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFF0A0A0A)),

          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (_, __) => CustomPaint(painter: WavePainter(_waveController.value)),
              ),
            ),
          ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (_, __) => CustomPaint(painter: WavePainter(_waveController.value * 1.35, thin: true)),
              ),
            ),
          ),

          Center(
            child: Container(
              width: 460,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.95), blurRadius: 120, spreadRadius: 40),
                  BoxShadow(color: const Color(0xFFAAAAAA).withOpacity(0.25), blurRadius: 80, spreadRadius: 20),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'lizaplayer',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    'ENTER THE VOID',
                    style: TextStyle(fontSize: 15, letterSpacing: 6, color: Colors.white.withOpacity(0.4)),
                  ),

                  const SizedBox(height: 90),

                  TextField(
                    controller: _tokenController,
                    style: const TextStyle(fontSize: 17, color: Colors.white),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'PASTE OAUTH TOKEN',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32),
                        borderSide: const BorderSide(color: Color(0xFFAAAAAA), width: 2.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    ),
                  ),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: _saveToken,
                    child: Container(
                      width: double.infinity,
                      height: 66,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: const Color(0xFF111111),
                        border: Border.all(color: const Color(0xFFAAAAAA).withOpacity(0.5)),
                        boxShadow: [BoxShadow(color: const Color(0xFFAAAAAA).withOpacity(0.25), blurRadius: 30)],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'CONNECT',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFFCCCCCC)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animation;
  final bool thin;
  WavePainter(this.animation, {this.thin = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(thin ? 0.12 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thin ? 1.8 : 3.2;

    for (int i = 0; i < 7; i++) {
      final path = Path();
      final baseY = size.height * (0.08 + i * 0.135);
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width + 50; x += 6) {
        final wave = sin((x / 92) + animation * 6.8 + i * 1.9) * (thin ? 18 : 34);
        path.lineTo(x, baseY + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
