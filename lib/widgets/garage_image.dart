import 'package:flutter/material.dart';

class GarageImage extends StatelessWidget {
  final String imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  const GarageImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  });

  bool get _isNetworkImage =>
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  int? _cacheDimension(BuildContext context, double? logicalPixels) {
    if (logicalPixels == null ||
        !logicalPixels.isFinite ||
        logicalPixels <= 0) {
      return null;
    }
    return (logicalPixels * MediaQuery.devicePixelRatioOf(context)).round();
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = _cacheDimension(context, width);
    final cacheHeight = _cacheDimension(context, height);

    if (_isNetworkImage) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        semanticLabel: semanticLabel,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallback(context),
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    }

    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF182033) : const Color(0xFFEAF1FF),
      child: Icon(
        Icons.car_repair_rounded,
        size: 46,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
