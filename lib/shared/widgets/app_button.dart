import 'package:flutter/material.dart';
import 'package:slotbooking/data/theam/app_theam.dart';

/// Button variants available in the design system.
enum AppButtonVariant {
  primary, // Filled red — main CTA
  secondary, // Outlined red
  ghost, // Text only, no background/border
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool disabled;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final double? width;
  final double height;

  // ── Main constructor ───────────────────────────────────────────────────────
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.disabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.width = double.infinity,
    this.height = 54,
  });

  // ── Static factory helpers (avoids super.key redirect limitation) ──────────

  static AppButton primary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool disabled = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width = double.infinity,
    double height = 54,
  }) => AppButton(
    key: key,
    label: label,
    onPressed: onPressed,
    variant: AppButtonVariant.primary,
    isLoading: isLoading,
    disabled: disabled,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    width: width,
    height: height,
  );

  static AppButton secondary({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool disabled = false,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width = double.infinity,
    double height = 54,
  }) => AppButton(
    key: key,
    label: label,
    onPressed: onPressed,
    variant: AppButtonVariant.secondary,
    isLoading: isLoading,
    disabled: disabled,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    width: width,
    height: height,
  );

  static AppButton ghost({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    Widget? leadingIcon,
    Widget? trailingIcon,
    double? width,
    double height = 44,
  }) => AppButton(
    key: key,
    label: label,
    onPressed: onPressed,
    variant: AppButtonVariant.ghost,
    leadingIcon: leadingIcon,
    trailingIcon: trailingIcon,
    width: width,
    height: height,
  );

  // ──────────────────────────────────────────────────────────────────────────

  bool get _isDisabled => disabled || isLoading || onPressed == null;

  Color _bgColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return _isDisabled
            ? AppTheme.primaryRed.withOpacity(0.45)
            : AppTheme.primaryRed;
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _fgColor() {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;
      case AppButtonVariant.secondary:
        return _isDisabled
            ? AppTheme.primaryRed.withOpacity(0.45)
            : AppTheme.primaryRed;
      case AppButtonVariant.ghost:
        return _isDisabled
            ? AppTheme.textSecondary.withOpacity(0.45)
            : AppTheme.textSecondary;
    }
  }

  BorderSide _borderSide() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.ghost:
        return BorderSide.none;
      case AppButtonVariant.secondary:
        return BorderSide(
          color: _isDisabled
              ? AppTheme.primaryRed.withOpacity(0.45)
              : AppTheme.primaryRed,
          width: 1.5,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fgColor();

    final Widget child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: variant == AppButtonVariant.primary
                  ? Colors.white
                  : AppTheme.primaryRed,
              strokeWidth: 2.5,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                IconTheme(
                  data: IconThemeData(color: fg, size: 20),
                  child: leadingIcon!,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: fg,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(color: fg, size: 20),
                  child: trailingIcon!,
                ),
              ],
            ],
          );

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _bgColor(),
          foregroundColor: fg,
          disabledBackgroundColor: _bgColor(),
          disabledForegroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: _borderSide(),
          ),
        ),
        child: child,
      ),
    );
  }
}
