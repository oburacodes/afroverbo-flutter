import 'package:flutter/material.dart';
import 'dart:math' as math;

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D2C),
      body: Stack(
        children: [
          // African geometric pattern background
          Positioned.fill(child: CustomPaint(painter: AfricanPatternPainter())),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // African-style logo container
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🌍', style: TextStyle(fontSize: 72)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Decorative line with diamond
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 1.5,
                          color: const Color(0xFFFFD700).withOpacity(0.6),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 1.5,
                          color: const Color(0xFFFFD700).withOpacity(0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Afroverbo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Kente-style accent bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _kenteBar(const Color(0xFFFFD700)),
                        _kenteBar(const Color(0xFF006B3C)),
                        _kenteBar(const Color(0xFFCC0000)),
                        _kenteBar(const Color(0xFFFFD700)),
                        _kenteBar(const Color(0xFF006B3C)),
                        _kenteBar(const Color(0xFFCC0000)),
                        _kenteBar(const Color(0xFFFFD700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Discover and learn Kenyan\nlanguages with ease',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.6,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'I already have an account',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kenteBar(Color color) {
    return Container(
      width: 24,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// African geometric pattern background painter
class AfricanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    // Top-right decorative arc pattern
    paint.color = const Color(0xFFFFD700).withOpacity(0.08);
    paint.strokeWidth = 1.5;
    for (int i = 1; i <= 6; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width, 0),
          width: i * 80.0,
          height: i * 80.0,
        ),
        math.pi / 2,
        math.pi / 2,
        false,
        paint,
      );
    }

    // Bottom-left decorative arc pattern
    for (int i = 1; i <= 6; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(0, size.height),
          width: i * 80.0,
          height: i * 80.0,
        ),
        -math.pi / 2,
        math.pi / 2,
        false,
        paint,
      );
    }

    // Scattered diamond shapes (Adinkra-inspired)
    paint.color = const Color(0xFFFFD700).withOpacity(0.06);
    paint.style = PaintingStyle.fill;
    final diamonds = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.3),
      Offset(size.width * 0.15, size.height * 0.75),
      Offset(size.width * 0.9, size.height * 0.7),
      Offset(size.width * 0.5, size.height * 0.08),
    ];
    for (final center in diamonds) {
      final path = Path();
      path.moveTo(center.dx, center.dy - 12);
      path.lineTo(center.dx + 8, center.dy);
      path.lineTo(center.dx, center.dy + 12);
      path.lineTo(center.dx - 8, center.dy);
      path.close();
      canvas.drawPath(path, paint);
    }

    // Subtle triangle pattern (top-left)
    paint.color = const Color(0xFFFFD700).withOpacity(0.05);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final x = col * 30.0 + 10;
        final y = row * 30.0 + size.height * 0.35;
        final path = Path();
        path.moveTo(x + 10, y);
        path.lineTo(x + 20, y + 18);
        path.lineTo(x, y + 18);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
