import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../constants/app_constants.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomePage({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugPrint('[WelcomePage] Building welcome page');

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final isWide = w >= 720;
        final isShort = h < 640;

        // Scale down aggressively on short viewports to avoid overflow
        final questorSize = (h * (isShort ? 0.22 : 0.28))
            .clamp(110.0, isWide ? 240.0 : 200.0);
        final titleSize =
            (h * 0.055).clamp(isShort ? 26.0 : 30.0, isWide ? 44.0 : 38.0);
        final taglineSize = isShort ? 13.0 : (isWide ? 16.0 : 14.0);
        final glowPad = isShort ? 20.0 : 36.0;
        final ctaWidth = isWide ? 300.0 : double.infinity;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFB0129A),
                AppColors.primary,
                AppColors.primaryDark,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 40 : 24,
                    vertical: isShort ? 12 : 20,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Questor
                      Container(
                        width: questorSize + glowPad,
                        height: questorSize + glowPad,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: questorSize,
                          height: questorSize,
                          child: Image.asset(
                            'assets/images/questor 9.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      SizedBox(height: isShort ? 12 : 20),

                      Text(
                        'My Leadership\nQuest',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.08,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isShort ? 8 : 12),

                      Text(
                        'Build habits. Lead with purpose.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: taglineSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.3,
                        ),
                      ),

                      // Extra breathing room before CTA
                      SizedBox(height: isShort ? 28 : 40),
                      const Spacer(flex: 2),

                      SizedBox(
                        width: ctaWidth,
                        height: isShort ? 50 : 56,
                        child: ElevatedButton(
                          onPressed: onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 22),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isShort ? 12 : 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
