import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_chat_service.dart';

/// A text field that supports AI-powered spell checking.
/// Spell check is triggered manually via the icon button — not automatically on typing.
class AiTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final InputDecoration? decoration;
  final TextStyle? style;

  const AiTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.onChanged,
    this.decoration,
    this.style,
  });

  @override
  State<AiTextField> createState() => _AiTextFieldState();
}

class _AiTextFieldState extends State<AiTextField> {
  late TextEditingController _internalController;
  bool _isChecking = false;
  List<Map<String, String>> _errors = [];

  @override
  void initState() {
    super.initState();
    // Use the external controller if provided, otherwise create our own.
    _internalController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    // Only dispose if we created the controller ourselves.
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  Future<void> _performSpellCheck() async {
    final text = _internalController.text;
    if (!mounted || text.trim().isEmpty) return;

    setState(() => _isChecking = true);
    try {
      final aiService = context.read<AiChatService>();
      final errors = await aiService.checkSpelling(text);
      if (mounted) {
        setState(() => _errors = errors);
        if (errors.isNotEmpty) {
          _showSuggestions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sem erros ortográficos detetados! ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AiTextField Spell Check Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível verificar a ortografia.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = widget.decoration ?? const InputDecoration();
    return TextField(
      controller: _internalController,
      maxLines: widget.maxLines,
      style: widget.style ?? const TextStyle(color: Colors.white, fontSize: 14),
      onChanged: widget.onChanged,
      decoration: baseDecoration.copyWith(
        labelText: widget.labelText,
        hintText: widget.hintText,
        suffixIcon: _isChecking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.spellcheck,
                  color: _errors.isNotEmpty ? Colors.redAccent : Colors.white24,
                  size: 18,
                ),
                tooltip: 'Verificar ortografia com IA',
                onPressed: _performSpellCheck,
              ),
      ),
    );
  }

  void _showSuggestions() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sugestões da IA',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_errors.isEmpty)
                const Text('Nenhum erro detetado.', style: TextStyle(color: Colors.white54))
              else
                ..._errors.map((error) => ListTile(
                      leading: const Icon(Icons.auto_awesome, color: Color(0xFF7B61FF), size: 18),
                      title: Text(
                        error['original'] ?? '',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        'Sugestão: ${error['suggestion']}',
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                      onTap: () {
                        final newText = _internalController.text
                            .replaceAll(error['original']!, error['suggestion']!);
                        _internalController.text = newText;
                        _internalController.selection = TextSelection.fromPosition(
                          TextPosition(offset: newText.length),
                        );
                        setState(() {
                          _errors.removeWhere((e) => e['original'] == error['original']);
                        });
                        Navigator.pop(ctx);
                        if (widget.onChanged != null) {
                          widget.onChanged!(newText);
                        }
                      },
                    )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
