import 'package:flutter/material.dart';
import 'ai_translated_text.dart';

class BrandedTitle extends StatelessWidget {
  final String? logoUrl;
  final String? institutionName;
  final String defaultTitle;
  final VoidCallback? onLogoTap;

  const BrandedTitle({
    super.key,
    this.logoUrl,
    this.institutionName,
    required this.defaultTitle,
    this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null &&
        (institutionName == null || institutionName!.isEmpty) &&
        onLogoTap == null) {
      return AiTranslatedText(defaultTitle);
    }

    Widget logoAvatar = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
        border: onLogoTap != null
            ? Border.all(color: const Color(0xFF00D1FF), width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (logoUrl != null && logoUrl!.isNotEmpty)
            Image.network(
              logoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.business,
                    color: Colors.white54, size: 20);
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
            )
          else
            const Icon(Icons.business, color: Colors.white54, size: 20),
          if (onLogoTap != null)
            Container(
              color: Colors.black45,
              child: const Icon(Icons.camera_alt,
                  color: Colors.white, size: 16),
            ),
        ],
      ),
    );

    if (onLogoTap != null) {
      logoAvatar = Tooltip(
        message: 'Carregar/Alterar Logótipo da Instituição',
        child: InkWell(
          onTap: onLogoTap,
          borderRadius: BorderRadius.circular(20),
          child: logoAvatar,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoAvatar,
        const SizedBox(width: 10),
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
                  color:
                      institutionName != null ? Colors.white54 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
