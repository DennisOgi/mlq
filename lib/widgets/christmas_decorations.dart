import 'dart:math';
import 'package:flutter/material.dart';

/// Christmas decorations widget that displays seasonal decorations
/// Automatically expires after January 12, 2026
class ChristmasDecorations extends StatelessWidget {
  const ChristmasDecorations({super.key});

  /// Check if decorations should be shown (expires Jan 12, 2026)
  static bool get shouldShow {
    final now = DateTime.now();
    final expiryDate = DateTime(2026, 1, 12); // Second week of January 2026
    return now.isBefore(expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) return const SizedBox.shrink();

    return const IgnorePointer(
      child: Stack(
        children: [
          // Top left decoration
          Positioned(
            top: 0,
            left: 0,
            child: _ChristmasCorner(isLeft: true),
          ),
          // Top right decoration
          Positioned(
            top: 0,
            right: 0,
            child: _ChristmasCorner(isLeft: false),
          ),
        ],
      ),
    );
  }
}

class _ChristmasCorner extends StatelessWidget {
  final bool isLeft;

  const _ChristmasCorner({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(isLeft ? 1.0 : -1.0, 1.0),
      child: CustomPaint(
        size: const Size(80, 100),
        painter: _ChristmasCornerPainter(),
      ),
    );
  }
}

class _ChristmasCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw holly leaves
    final leafPaint = Paint()
      ..color = const Color(0xFF228B22) // Forest green
      ..style = PaintingStyle.fill;

    // Draw berries
    final berryPaint = Paint()
      ..color = const Color(0xFFDC143C) // Crimson red
      ..style = PaintingStyle.fill;

    // Holly leaf 1
    final leaf1 = Path()
      ..moveTo(10, 30)
      ..quadraticBezierTo(30, 10, 50, 25)
      ..quadraticBezierTo(40, 35, 50, 50)
      ..quadraticBezierTo(30, 40, 10, 50)
      ..quadraticBezierTo(20, 40, 10, 30);
    canvas.drawPath(leaf1, leafPaint);

    // Holly leaf 2
    final leaf2 = Path()
      ..moveTo(30, 50)
      ..quadraticBezierTo(50, 35, 70, 45)
      ..quadraticBezierTo(60, 55, 70, 70)
      ..quadraticBezierTo(50, 60, 30, 70)
      ..quadraticBezierTo(40, 60, 30, 50);
    canvas.drawPath(leaf2, leafPaint);

    // Berries
    canvas.drawCircle(const Offset(35, 45), 6, berryPaint);
    canvas.drawCircle(const Offset(28, 52), 5, berryPaint);
    canvas.drawCircle(const Offset(42, 52), 5, berryPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Snowfall overlay widget for festive effect
class SnowfallOverlay extends StatefulWidget {
  final Widget child;

  const SnowfallOverlay({super.key, required this.child});

  /// Check if snowfall should be shown (expires Jan 12, 2026)
  static bool get shouldShow {
    final now = DateTime.now();
    final expiryDate = DateTime(2026, 1, 12);
    return now.isBefore(expiryDate);
  }

  @override
  State<SnowfallOverlay> createState() => _SnowfallOverlayState();
}

class _SnowfallOverlayState extends State<SnowfallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Snowflake> _snowflakes = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Generate snowflakes
    for (int i = 0; i < 30; i++) {
      _snowflakes.add(_Snowflake(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 2,
        speed: _random.nextDouble() * 0.3 + 0.1,
        drift: _random.nextDouble() * 0.02 - 0.01,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SnowfallOverlay.shouldShow) return widget.child;

    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _SnowfallPainter(_snowflakes, _controller.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Snowflake {
  double x;
  double y;
  final double size;
  final double speed;
  final double drift;

  _Snowflake({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
  });
}

class _SnowfallPainter extends CustomPainter {
  final List<_Snowflake> snowflakes;
  final double animationValue;

  _SnowfallPainter(this.snowflakes, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    for (final flake in snowflakes) {
      // Update position based on animation
      final y = (flake.y + animationValue * flake.speed * 3) % 1.0;
      final x = (flake.x + sin(animationValue * 2 * pi) * flake.drift) % 1.0;

      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        flake.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SnowfallPainter oldDelegate) => true;
}

/// Christmas banner widget for announcements
class ChristmasBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const ChristmasBanner({
    super.key,
    this.message = '🎄 Happy Holidays! Check out our Christmas challenges! 🎁',
    this.onTap,
  });

  /// Check if banner should be shown (expires Jan 12, 2026)
  static bool get shouldShow {
    final now = DateTime.now();
    final expiryDate = DateTime(2026, 1, 12);
    return now.isBefore(expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E5631), // Dark green
              Color(0xFFC41E3A), // Christmas red
              Color(0xFF1E5631), // Dark green
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Christmas-themed app bar decoration
class ChristmasAppBarDecoration extends StatelessWidget {
  const ChristmasAppBarDecoration({super.key});

  static bool get shouldShow {
    final now = DateTime.now();
    final expiryDate = DateTime(2026, 1, 12);
    return now.isBefore(expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left lights
            _buildLights(),
            // Right lights (mirrored)
            Transform.scale(
              scaleX: -1,
              child: _buildLights(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLights() {
    return Row(
      children: List.generate(5, (index) {
        final colors = [
          Colors.red,
          Colors.green,
          Colors.yellow,
          Colors.blue,
          Colors.orange,
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _AnimatedLight(color: colors[index], delay: index * 200),
        );
      }),
    );
  }
}

class _AnimatedLight extends StatefulWidget {
  final Color color;
  final int delay;

  const _AnimatedLight({required this.color, required this.delay});

  @override
  State<_AnimatedLight> createState() => _AnimatedLightState();
}

class _AnimatedLightState extends State<_AnimatedLight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
