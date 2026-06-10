import 'package:flutter/material.dart';
import 'package:slotbooking/data/theam/app_theam.dart';

/// Semantic text variants mapped to [AppTheme] text styles.
enum AppTextVariant {
  headlineLarge,
  headlineMedium,
  titleLarge,
  bodyLarge,
  bodyMedium,
  label, // small caps utility label (e.g. "SECURE ACCESS")
}

class AppText extends StatelessWidget {
  final String text;
  final AppTextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final double? letterSpacing;
  final TextOverflow? overflow;

  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.letterSpacing,
    this.overflow,
  });

  // Convenience constructors ─────────────────────────────────────────────────

  const AppText.headlineLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.headlineLarge,
       letterSpacing = -0.5;

  const AppText.headlineMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.headlineMedium,
       letterSpacing = null;

  const AppText.titleLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.titleLarge,
       letterSpacing = null;

  const AppText.bodyLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.bodyLarge,
       letterSpacing = null;

  const AppText.bodyMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.bodyMedium,
       letterSpacing = null;

  /// Small-caps utility label — e.g. "SECURE ACCESS", "MOBILE NUMBER"
  const AppText.label(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : variant = AppTextVariant.label,
       letterSpacing = 1.5;

  @override
  Widget build(BuildContext context) {
    final base = _baseStyle(context);
    return Text(
      text,
      style: base.copyWith(
        color: color ?? base.color,
        letterSpacing: letterSpacing ?? base.letterSpacing,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextStyle _baseStyle(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    switch (variant) {
      case AppTextVariant.headlineLarge:
        return tt.headlineLarge!;
      case AppTextVariant.headlineMedium:
        return tt.headlineMedium!;
      case AppTextVariant.titleLarge:
        return tt.titleLarge!;
      case AppTextVariant.bodyLarge:
        return tt.bodyLarge!;
      case AppTextVariant.bodyMedium:
        return tt.bodyMedium!;
      case AppTextVariant.label:
        return TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: color ?? AppTheme.textSecondary,
        );
    }
  }
}
