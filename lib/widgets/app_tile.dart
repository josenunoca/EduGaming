import 'package:flutter/material.dart';
import 'glass_card.dart';
import 'ai_translated_text.dart';

class AppTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final String? photoUrl;
  final Color color;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const AppTile({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.photoUrl,
    required this.color,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: color.withValues(alpha: 0.1),
      highlightColor: color.withValues(alpha: 0.05),
      child: GlassCard(
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: photoUrl != null 
                    ? Border.all(color: color.withValues(alpha: 0.2)) 
                    : null,
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? Image.network(
                          photoUrl!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        )
                      : Icon(icon, size: 24, color: color),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: AiTranslatedText(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Flexible(
                  child: AiTranslatedText(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
