import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Consistent section title used across Home and feature screens.
class MlqSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;

  const MlqSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: AppTextStyles.sectionHeader.copyWith(color: c),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Centered content column used so desktop pages don't stretch edge-to-edge.
class MlqPageWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MlqPageWidth({
    super.key,
    required this.child,
    this.maxWidth = 1080,
    this.padding,
  });

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 720;

  @override
  Widget build(BuildContext context) {
    final wide = isDesktop(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(horizontal: wide ? 28 : 16),
          child: child,
        ),
      ),
    );
  }
}

/// Soft surface container — preferred over nested Material Cards.
class MlqSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const MlqSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: NeumorphicStyles.large,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: content,
      ),
    );
  }
}

class MlqLoadingState extends StatelessWidget {
  final String? message;

  const MlqLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class MlqEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MlqEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.flag_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(icon, size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plum → violet header with a curved bottom, optional gold title word,
/// Questor art on the right and an optional bottom slot (stats/tabs).
class MlqHeroHeader extends StatelessWidget {
  final String title;
  final String? highlight;
  final String? subtitle;
  final String? artAsset;
  final Widget? bottom;
  final bool showBack;
  final Widget? action;

  const MlqHeroHeader({
    super.key,
    required this.title,
    this.highlight,
    this.subtitle,
    this.artAsset = AppAssets.questorHappy,
    this.bottom,
    this.showBack = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.violetLight,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBack)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: title),
                          if (highlight != null)
                            TextSpan(
                              text: ' $highlight',
                              style: const TextStyle(
                                  color: AppColors.secondary),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (artAsset != null)
                SizedBox(
                  height: 84,
                  width: 84,
                  child: Image.asset(artAsset!, fit: BoxFit.contain),
                ),
              if (action != null) action!,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 16),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// Translucent stat tiles for use inside [MlqHeroHeader.bottom].
class MlqHeroStats extends StatelessWidget {
  final List<({String value, String label, IconData icon})> items;

  const MlqHeroStats({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].icon,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          items[i].value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pill segment tabs. On cream the active tab is plum with white text;
/// with [onDark] (inside a purple header) it is gold with plum text.
class MlqSegmentTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final bool onDark;

  const MlqSegmentTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = onDark ? AppColors.secondary : AppColors.plum;
    final activeFg = onDark ? AppColors.textOnGold : Colors.white;
    final idleBg =
        onDark ? Colors.white.withValues(alpha: 0.12) : AppColors.surface;
    final idleFg = onDark
        ? Colors.white.withValues(alpha: 0.85)
        : AppColors.textSecondary;
    final idleBorder = onDark ? Colors.transparent : AppColors.border;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Material(
              color: i == selected ? activeBg : idleBg,
              shape: StadiumBorder(
                side: BorderSide(
                  color: i == selected ? activeBg : idleBorder,
                ),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onChanged(i),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: i == selected ? activeFg : idleFg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 8 px rounded progress bar: gold fill on lilac.
class MlqProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  final Color track;

  const MlqProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppColors.secondary,
    this.track = AppColors.primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: track,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Cover illustration that fills its box; falls back to a plum gradient
/// with Questor when [asset] is null or fails to load.
class MlqCoverImage extends StatelessWidget {
  final String? asset;
  final IconData fallbackIcon;
  final Alignment alignment;

  const MlqCoverImage({
    super.key,
    required this.asset,
    this.fallbackIcon = Icons.school_rounded,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    if (asset == null) return _fallback();
    return Image.asset(
      asset!,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.plum, AppColors.primary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 14,
            child: Icon(fallbackIcon,
                color: AppColors.secondary.withValues(alpha: 0.9), size: 26),
          ),
          Positioned(
            right: 6,
            bottom: -6,
            top: 12,
            child: Image.asset(AppAssets.questorHappy, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label (level, XP, status).
class MlqPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;

  const MlqPill({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.primarySoft,
    this.foreground = AppColors.primary,
  });

  const MlqPill.gold({super.key, required this.label, this.icon})
      : background = AppColors.secondary,
        foreground = AppColors.textOnGold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today's Quest" hero: the single most useful next action.
class MlqQuestCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? coverAsset;
  final IconData icon;

  const MlqQuestCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.eyebrow = "TODAY'S QUEST",
    this.coverAsset,
    this.icon = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 14, color: AppColors.goldText),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.goldText,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (onAction != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: onAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.textOnGold,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 120,
              height: 148,
              child: coverAsset != null
                  ? MlqCoverImage(asset: coverAsset, fallbackIcon: icon)
                  : Container(
                      color: AppColors.primarySoft,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(top: 12),
                      child: Image.asset(
                        AppAssets.questorHappy,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ],
      ),
    );
  }
}

class MlqShortcut {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const MlqShortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Row of equal lilac shortcut tiles (Goals / Challenges / Victory).
class MlqShortcutRow extends StatelessWidget {
  final List<MlqShortcut> items;

  const MlqShortcutRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _ShortcutTile(item: items[i])),
        ],
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final MlqShortcut item;

  const _ShortcutTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

