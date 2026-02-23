import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart' show AppTextStyles;

/// Displays a username followed by a small purple check-mark if the user is premium.
class UsernameWithCheckmark extends StatelessWidget {
  final String name;
  final bool isPremium;
  final TextStyle? style;
  final double iconSize;

  const UsernameWithCheckmark({
    super.key,
    required this.name,
    required this.isPremium,
    this.style,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style ?? AppTextStyles.bodyBold,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (isPremium) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.verified,
            size: iconSize,
            color: Colors.purple,
          ),
        ],
      ],
    );
  }
}
