import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_translation_service.dart';
import '../logic/language_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AiTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool isMarkdown;
  final int? maxLines;
  final TextOverflow? overflow;

  const AiTranslatedText(this.text,
      {super.key, this.style, this.textAlign, this.isMarkdown = false, this.maxLines, this.overflow});

  @override
  State<AiTranslatedText> createState() => _AiTranslatedTextState();
}

class _AiTranslatedTextState extends State<AiTranslatedText> {
  late Future<String> _translationFuture;
  String _lastLanguageCode = '';
  String _lastText = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langProvider = context.watch<LanguageProvider>();
    final targetLang = langProvider.languageCode;
    
    // Only re-fetch if language or text actually changed
    if (_lastLanguageCode != targetLang || _lastText != widget.text) {
      _lastLanguageCode = targetLang;
      _lastText = widget.text;
      
      final service = context.read<AiTranslationService>();
      if (targetLang == 'pt') {
        _translationFuture = Future.value(widget.text);
      } else {
        _translationFuture = service.translate(widget.text, targetLang);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _translationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // While translating, return original text but slightly faded to reduce visual jump
          return _buildText(widget.text, opacity: 0.5);
        }
        return _buildText(snapshot.data!, opacity: 1.0);
      },
    );
  }

  Widget _buildText(String content, {double opacity = 1.0}) {
    if (widget.isMarkdown) {
      return Opacity(
        opacity: opacity,
        child: MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: widget.style ?? const TextStyle(color: Colors.white),
            h1: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            h2: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            h3: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            listBullet: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return Opacity(
      opacity: opacity,
      child: Text(
        content,
        style: widget.style ?? const TextStyle(color: Colors.white),
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }
}
