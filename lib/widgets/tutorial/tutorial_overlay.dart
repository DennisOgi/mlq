import 'package:flutter/material.dart';

class TutorialStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final TutorialPosition position;
  final IconData? icon;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.position = TutorialPosition.bottom,
    this.icon,
  });
}

enum TutorialPosition { top, bottom, left, right, center }

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final Color primaryColor;
  final Color backgroundColor;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
    this.primaryColor = const Color(0xFFC901F8),
    this.backgroundColor = const Color(0x88000000),
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      widget.onComplete();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _skip() {
    widget.onSkip?.call();
    widget.onComplete();
  }

  Rect? _getTargetRect() {
    final currentStep = widget.steps[_currentStep];
    final RenderBox? renderBox = currentStep.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }

  Widget _buildTooltip(TutorialStep step, Rect targetRect) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    // Tooltip dimensions (should match container width/estimated height below)
    const tooltipWidth = 320.0;
    const estimatedHeight = 156.0; // approximate min height for clamping

    // Reserve space for bottom navigation and safe area so tooltips don't sit too low
    const bottomNavReserve = 72.0; // typical BottomNavigationBar height
    final minY = padding.top + 16.0;
    final maxY = screenSize.height - (estimatedHeight + bottomNavReserve + padding.bottom + 16.0);

    // Initial desired position near the target
    double tooltipX = targetRect.center.dx - (tooltipWidth / 2);
    double tooltipY;

    // Base placement by requested position
    switch (step.position) {
      case TutorialPosition.top:
        tooltipY = targetRect.top - estimatedHeight - 12.0;
        break;
      case TutorialPosition.bottom:
        tooltipY = targetRect.bottom + 12.0;
        break;
      case TutorialPosition.center:
        tooltipY = (screenSize.height - estimatedHeight) / 2;
        break;
      default:
        tooltipY = targetRect.bottom + 12.0;
        break;
    }

    // Smart flip: if bottom placement would overflow, move above target; if top too high, move below
    if (step.position == TutorialPosition.bottom || step.position == TutorialPosition.center) {
      if (tooltipY > maxY) {
        tooltipY = targetRect.top - estimatedHeight - 12.0; // flip above
      }
    }
    if (step.position == TutorialPosition.top) {
      if (tooltipY < minY) {
        tooltipY = targetRect.bottom + 12.0; // flip below
      }
    }

    // Final clamp within safe bounds
    tooltipX = tooltipX.clamp(16.0, screenSize.width - (tooltipWidth + 16.0));
    tooltipY = tooltipY.clamp(minY, maxY);

    return Positioned(
      left: tooltipX,
      top: tooltipY,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.primaryColor, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          if (step.icon != null) ...[
                            Icon(
                              step.icon,
                              color: widget.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                          ),
                          if (widget.onSkip != null)
                            TextButton(
                              onPressed: _skip,
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Description
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Step indicator
                          Row(
                            children: List.generate(
                              widget.steps.length,
                              (index) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _currentStep
                                      ? widget.primaryColor
                                      : Colors.grey[300],
                                ),
                              ),
                            ),
                          ),
                          
                          // Navigation buttons
                          Row(
                            children: [
                              if (_currentStep > 0)
                                TextButton(
                                  onPressed: _previousStep,
                                  child: const Text('Back'),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _currentStep == widget.steps.length - 1
                                      ? 'Finish'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetRect = _getTargetRect();
    if (targetRect == null) {
      // Target not found, skip to next step or complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nextStep();
      });
      return const SizedBox.shrink();
    }

    final currentStep = widget.steps[_currentStep];

    return Material(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // Highlight target area
          CustomPaint(
            size: Size.infinite,
            painter: HighlightPainter(
              targetRect: targetRect,
              highlightColor: Colors.white,
            ),
          ),
          
          // Tooltip
          _buildTooltip(currentStep, targetRect),
        ],
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color highlightColor;

  HighlightPainter({
    required this.targetRect,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw highlight border around target
    final highlightRect = RRect.fromRectAndRadius(
      targetRect.inflate(8),
      const Radius.circular(8),
    );
    
    canvas.drawRRect(highlightRect, paint);
    
    // Optional: Add a subtle glow effect
    final glowPaint = Paint()
      ..color = highlightColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawRRect(highlightRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
