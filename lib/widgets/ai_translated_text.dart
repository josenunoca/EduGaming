import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/language_provider.dart';
import '../logic/static_translations.dart';
import '../services/ai_translation_service.dart';

class AiTranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String? contextOverride;
  final int? maxLines;
  final TextOverflow? overflow;

  const AiTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.contextOverride,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final targetLang = languageProvider.languageCode;

    // Portuguese → no translation needed
    if (targetLang == 'pt') {
      return Text(text, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }

    // Static dictionary lookup → zero API calls, instant result
    final staticResult = getStaticTranslation(text, targetLang);
    if (staticResult != null) {
      return Text(staticResult, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
    }

    // Only reach here for dynamic/user-generated content → call AI API
    final translationService = context.read<AiTranslationService>();

    return FutureBuilder<String>(
      future: translationService.translate(
        text,
        targetLang,
        context: contextOverride,
      ),
      builder: (context, snapshot) {
        final displayedText = snapshot.data ?? text;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            displayedText,
            key: ValueKey(displayedText),
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      },
    );
  }
}
