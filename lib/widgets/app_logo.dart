import 'package:flutter/material.dart';

enum LogoSize { small, medium, large }

class AppLogo extends StatelessWidget {
  final LogoSize size;
  final bool showTagline;
  final Color? textColor;

  const AppLogo({
    super.key,
    this.size = LogoSize.medium,
    this.showTagline = false,
    this.textColor,
  });

  const AppLogo.appBar({
    super.key,
    this.size = LogoSize.small,
    this.showTagline = false,
    this.textColor,
  });

  const AppLogo.hero({
    super.key,
    this.size = LogoSize.large,
    this.showTagline = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = switch (size) {
      LogoSize.small => 34.0,
      LogoSize.medium => 46.0,
      LogoSize.large => 58.0,
    };
    final titleSize = switch (size) {
      LogoSize.small => 18.0,
      LogoSize.medium => 24.0,
      LogoSize.large => 31.0,
    };
    final theme = Theme.of(context);
    final foreground = textColor ?? theme.colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/garage_finder_icon.png',
          width: iconSize,
          height: iconSize,
          semanticLabel: 'Garage Finder',
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Garage ',
                    style: TextStyle(
                      color: foreground,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: 'Finder',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                'GARAGES & DÉPANNAGE AU BÉNIN',
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.68),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
