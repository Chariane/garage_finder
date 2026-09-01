import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    this.textColor = Colors.white,
  });

  const AppLogo.hero({
    super.key,
    this.size = LogoSize.large,
    this.showTagline = true,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final double iconBoxSize = switch (size) {
      LogoSize.small => 32,
      LogoSize.medium => 42,
      LogoSize.large => 52,
    };

    final double iconSize = switch (size) {
      LogoSize.small => 18,
      LogoSize.medium => 24,
      LogoSize.large => 30,
    };

    final double titleFontSize = switch (size) {
      LogoSize.small => 18,
      LogoSize.medium => 24,
      LogoSize.large => 32,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconBoxSize,
          height: iconBoxSize,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(iconBoxSize * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.build_circle_rounded,
                  color: Colors.white,
                  size: iconSize,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: iconBoxSize * 0.26,
                    height: iconBoxSize * 0.26,
                    decoration: const BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'GARAGE ',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: textColor ?? Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  TextSpan(
                    text: 'FINDER',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppTheme.accent,
                      shadows: [
                        Shadow(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'ASSISTANCE & DÉPANNAGE BÉNIN',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}
