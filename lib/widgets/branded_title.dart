import 'package:flutter/material.dart';
import 'ai_translated_text.dart';

class BrandedTitle extends StatelessWidget {
  final String? logoUrl;
  final String? institutionName;
  final String defaultTitle;

  const BrandedTitle({
    super.key,
    this.logoUrl,
    this.institutionName,
    required this.defaultTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null && (institutionName == null || institutionName!.isEmpty)) {
      return AiTranslatedText(defaultTitle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logoUrl != null && logoUrl!.isNotEmpty) ...[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business, color: Colors.white54, size: 20);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (institutionName != null && institutionName!.isNotEmpty)
                Text(
                  institutionName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              AiTranslatedText(
                defaultTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: institutionName != null ? Colors.white54 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
