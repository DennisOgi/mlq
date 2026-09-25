import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Soft branded backdrop used on auth and lock screens. Does not replace Questor/logo.
class MlqAuthBackdrop extends StatelessWidget {
  final Widget child;

  const MlqAuthBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6EAF4),
                AppColors.background,
                Color(0xFFFFF8F0),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.42,
            child: Image.asset(
              AppAssets.uiBgMesh,
              fit: BoxFit.cover,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
