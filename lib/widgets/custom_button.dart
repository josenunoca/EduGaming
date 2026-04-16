import 'package:flutter/material.dart';
import 'ai_translated_text.dart';

enum CustomButtonVariant {
  primary,
  secondary,
  danger,
  ghost,
}

class CustomButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final bool isFullWidth;
  final double? width;
  final double height;
  final bool isLoading;
  final Color? color;

  const CustomButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.isFullWidth = false,
    this.width,
    this.height = 48,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;

    switch (variant) {
      case CustomButtonVariant.primary:
        backgroundColor = const Color(0xFF7B61FF);
        foregroundColor = Colors.white;
        break;
      case CustomButtonVariant.secondary:
        backgroundColor = const Color(0xFF1E1E2E);
        foregroundColor = Colors.white;
        break;
      case CustomButtonVariant.danger:
        backgroundColor = Colors.redAccent.withValues(alpha: 0.1);
        foregroundColor = Colors.redAccent;
        break;
      case CustomButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = Colors.white70;
        break;
    }
    
    if (color != null) backgroundColor = color!;

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(isFullWidth ? double.infinity : (width ?? 0), height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: variant == CustomButtonVariant.ghost ? 0 : 2,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );

    Widget content = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              AiTranslatedText(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          );

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: content,
    );
  }
}
