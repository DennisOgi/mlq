import 'package:flutter/material.dart';
import 'dart:math' as math;

class SparklesOverlay extends StatelessWidget {
  final Widget child;
  final int sparkleCount;

  const SparklesOverlay({
    super.key,
    required this.child,
    this.sparkleCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ...List.generate(sparkleCount, (index) {
          final random = math.Random(index);
          final angle = (index / sparkleCount) * 2 * math.pi;
          final distance = 80.0 + random.nextDouble() * 20;
          final size = 4.0 + random.nextDouble() * 4;

          return Positioned(
            left: 60 + math.cos(angle) * distance,
            top: 60 + math.sin(angle) * distance,
            child: Icon(
              Icons.star,
              size: size,
              color: Colors.amber.withOpacity(0.6),
            ),
          );
        }),
      ],
    );
  }
}
