import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color color;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.color = AppTheme.primary,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return SizedBox(
      width: isFullWidth ? double.infinity : (isTablet ? 400 : double.infinity),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, color: Colors.white)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      ),
    );
  }
}
