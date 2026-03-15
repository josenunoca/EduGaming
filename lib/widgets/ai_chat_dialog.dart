import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../services/ai_chat_service.dart';
import '../models/subject_model.dart';
import '../utils/download_helper.dart';
import '../services/did_video_service.dart';
import '../widgets/ai_translated_text.dart';
// import '../logic/language_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class AiChatDialog extends StatefulWidget {
  final List<SubjectContent> selectedContents;
  final bool isStudent;

  const AiChatDialog(
      {super.key, required this.selectedContents, this.isStudent = false});

  @override
  State<AiChatDialog> createState() => _AiChatDialogState();
}

class _AiChatDialogState extends State<AiChatDialog> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isInitializing = true;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  // Voice features
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _initVoice();
  }

  Future<void> _initVoice() async {
    try {
      debugPrint('Initializing SpeechToText...');
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint('STT Error: $error'),
      );
      debugPrint('STT Available: $available');

      if (!kIsWeb) {
        await _tts.setLanguage('pt-PT');
      }
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('Voice init exception: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  void _listen() async {
    try {
      if (!_isListening) {
        debugPrint('Starting listening...');
        bool statusGranted = true;
        if (!kIsWeb) {
          var status = await Permission.microphone.request();
          statusGranted = status.isGranted;
          debugPrint('Microphone permission: $statusGranted');
        }

        if (statusGranted) {
          bool available = _speech.isAvailable;
          if (!available) {
            debugPrint('Speech not available, re-initializing...');
            available = await _speech.initialize();
          }

          if (available) {
            setState(() => _isListening = true);
            _speech.listen(
              onResult: (val) {
                debugPrint('STT Update: ${val.recognizedWords}');
                setState(() {
                  _lastWords = val.recognizedWords;
                  if (val.recognizedWords.isNotEmpty) {
                    _msgController.text = _lastWords;
                  }
                });
              },
            );
          } else {
            debugPrint('Speech still not available after init');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissão de microfone negada')));
        }
      } else {
        debugPrint('Stopping listening...');
        setState(() => _isListening = false);
        _speech.stop();
      }
    } catch (e) {
      debugPrint('Speech exception: $e');
    }
  }

  Future<void> _initializeChat() async {
    final chatService = context.read<AiChatService>();
    await chatService.initializeSession(widget.selectedContents);
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _messages.add({
          'role': 'assistant',
          'text':
              'Olá! Analisei os ${widget.selectedContents.length} documentos selecionados. Estou pronto para discutir o conteúdo de forma profissional. O que gostaria de explorar?'
        });
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _msgController.clear();
      _isTyping = true;
      _messages.add({'role': 'assistant', 'text': ''});
    });
    _scrollToBottom();

    final chatService = context.read<AiChatService>();
    String responseAccumulated = '';

    try {
      await for (final chunk in chatService.sendMessage(text)) {
        responseAccumulated += chunk;
        if (mounted) {
          setState(() {
            _messages.last['text'] = responseAccumulated;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last['text'] = 'Erro de comunicação: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _exportToPdf() async {
    debugPrint('[PDF] Starting export...');

    // Function to sanitize text for PDF (removing emojis but PRESERVING math symbols and LaTeX)
    String sanitizeForPdf(String input) {
      if (input.isEmpty) return '';
      // We are more permissive now to allow mathematical symbols that NotoSans supports
      // E.g. Beta (β), Delta (Δ), Pi (π), cdot (·), etc.
      // Standard Helvetica is replaced by NotoSans which covers most of these.
      return input
          .replaceAll(
              RegExp(
                  r'[^\x00-\xFF\u00A0-\u024F\u0370-\u03FF\u2000-\u206F\u2100-\u214F\u2200-\u22FF\n]'),
              '?')
          .replaceAll('  ', ' ')
          .trim();
    }

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();
    final fontBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    final pdf = pw.Document();

    // Header information
    final dateStr = DateTime.now().toString().split('.')[0];
    final contentsStr = widget.selectedContents.map((c) => c.name).join(', ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
          italic: fontItalic,
          boldItalic: fontBoldItalic,
        ),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Relatório DocTalk AI',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(dateStr,
                      style: const pw.TextStyle(color: PdfColors.grey)),
                ],
              ),
            ),
            pw.Paragraph(
              text: sanitizeForPdf('Documentos selecionados: $contentsStr'),
              style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
            ),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 15),

            // Generate list of blocks that can flow across pages
            ..._messages.expand((msg) {
              final isUser = msg['role'] == 'user';
              final roleName = isUser ? 'VOCÊ' : 'IA PROFESSOR';
              final content = msg['text'] ?? '';

              return [
                // Role Header
                pw.Header(
                  level: 2,
                  text: roleName,
                  textStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: isUser ? PdfColors.blue600 : PdfColors.grey600,
                  ),
                ),
                // Message Content
                ..._buildPdfRichContent(content, font, fontBold, fontItalic),
              ];
            }),

            pw.Footer(
              trailing: pw.Text('Gerado por EduGaming Platform',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    // Use the robust DownloadHelper
    try {
      debugPrint('[PDF] Saving document...');
      final bytes = await pdf.save();
      debugPrint('[PDF] Bytes saved: ${bytes.length}. Triggering download...');
      await DownloadHelper.downloadFile(
        bytes,
        'DocTalk_Export_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      debugPrint('[PDF] Download triggered.');
    } catch (e) {
      debugPrint('[PDF] Error saving or downloading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao exportar PDF: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generatePodcastAudio() async {
    setState(() => _isTyping = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'A criar roteiro do podcast (pode demorar alguns segundos)...')));

    try {
      final chatService = context.read<AiChatService>();

      // Step 1: Generate Script
      final script = await chatService.generatePodcastScript();
      if (script.isEmpty) throw 'Não foi possível gerar o roteiro.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A sintetizar vozes profissionais...')));
      }

      // Step 2: Synthesize Audio
      final audioBytes = await chatService.synthesizePodcastAudio(script);

      if (audioBytes != null) {
        // Step 3: Trigger Download using robust DownloadHelper
        await DownloadHelper.downloadFile(
          audioBytes,
          'DocTalk_Pro_Podcast_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
      } else {
        // Fallback or Error
        throw 'A síntese de áudio falhou. Verifique se a API de Text-to-Speech está ativa.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao gerar podcast: $e')));
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _generateInterviewVideo() async {
    setState(() => _isTyping = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A criar roteiro do vídeo...'),
        duration: Duration(seconds: 5)));

    try {
      final chatService = context.read<AiChatService>();

      // Step 1: Generate the dialogue script reusing the podcast script generator
      final script = await chatService.generatePodcastScript();
      if (script.isEmpty) throw 'Não foi possível gerar o guião do vídeo.';

      final videoService = DIdVideoService();

      // Step 2: Generate video via D-ID API
      final videoBytes = await videoService.generateInterviewVideo(
        script,
        onStatusUpdate: (status) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(status), duration: const Duration(seconds: 4)));
          }
        },
      );

      if (videoBytes != null) {
        // Step 3: Download
        await DownloadHelper.downloadFile(
          videoBytes,
          'DocTalk_Interview_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('🎬 Vídeo descarregado com sucesso!'),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao gerar vídeo: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _generateImageFromChat() async {
    if (_messages.isEmpty) return;

    setState(() => _isTyping = true);
    final lastAiMessage =
        _messages.lastWhere((m) => m['role'] == 'assistant')['text'] ?? '';
    final prompt =
        'A high-quality educational illustration based on this concept: $lastAiMessage. Professional, clean, and clear.';

    final chatService = context.read<AiChatService>();
    final base64Image = await chatService.generateImage(prompt);

    if (mounted) {
      setState(() => _isTyping = false);
      if (base64Image != null) {
        // In a real app, we'd show the image in a dialog or allow download
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const AiTranslatedText('Imagem Gerada'),
            content: Image.memory(base64Decode(base64Image)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Falha ao gerar imagem. Verifique se o modelo Imagen está ativo.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('DocTalk AI',
                style: TextStyle(fontSize: 16)),
            Text(
              '${widget.selectedContents.length} conteúdos selecionados',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download_for_offline,
                color: Color(0xFF00D1FF)),
            tooltip: 'Exportar & Gerar',
            onSelected: (value) {
              if (value == 'pdf') _exportToPdf();
              if (value == 'image') _generateImageFromChat();
              if (value == 'audio') _generatePodcastAudio();
              if (value == 'video') _generateInterviewVideo();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 12),
                    AiTranslatedText('Exportar para PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'audio',
                child: Row(
                  children: [
                    Icon(Icons.podcasts, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 12),
                    AiTranslatedText('Descarregar Podcast (MP3)'),
                  ],
                ),
              ),
              if (!widget.isStudent)
                const PopupMenuItem(
                  value: 'video',
                  child: Row(
                    children: [
                      Icon(Icons.video_camera_front,
                          color: Colors.purpleAccent, size: 20),
                      SizedBox(width: 12),
                      AiTranslatedText('Gerar Vídeo Entrevista (MP4)'),
                    ],
                  ),
                ),
              if (!widget.isStudent)
                const PopupMenuItem(
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 12),
                      AiTranslatedText('Gerar Imagem do Tema'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF7B61FF)),
                        SizedBox(height: 16),
                        AiTranslatedText(
                            'Preparando contexto dos documentos...',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildMessageBubble(msg['text'] ?? '', isUser);
                      },
                    ),
                  ),
          ),
          if (_messages.isNotEmpty &&
              _messages.last['isUser'] == 'false' &&
              _messages.last['text']!.contains('Erro técnico'))
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DICA: Verifica se a tua chave de API tem a "Generative Language API" ativa nas restrições de chave no Cloud Console.',
                style: TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    // Process text to handle LaTeX delimiters if necessary
    // Here we ensure $...$ and $$...$$ are preserved for the markdown renderer
    final processedText = text;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF7B61FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: processedText,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    color: isUser ? Colors.white : Colors.white70,
                    fontSize: 14),
                strong: TextStyle(
                    color: isUser ? Colors.white : Colors.white,
                    fontWeight: FontWeight.bold),
                em: const TextStyle(fontStyle: FontStyle.italic),
                code: TextStyle(
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              builders: {
                'latex': _MathBuilder(isUser: isUser),
              },
              // Custom syntax for LaTeX
              inlineSyntaxes: [
                _MathSyntax(),
              ],
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up,
                        color: Colors.white54, size: 18),
                    onPressed: () => _speak(text),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isListening && _lastWords.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 12, left: 16),
                child: Row(
                  children: [
                    const Icon(Icons.mic, color: Color(0xFF00D1FF), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Captado: $_lastWords',
                        style: const TextStyle(
                            color: Color(0xFF00D1FF), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _listen,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.redAccent : Colors.white54,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'A ouvir...'
                          : 'Pergunte sobre os documentos...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7B61FF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cleanLatex(String t) {
    return t
        .replaceAll(r'\ ', ' ')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\$', r'$')
        .replaceAll(r'\&', '&')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}');
  }

  /// Parses text into a mix of plain text and math widgets for PDF
  List<pw.Widget> _buildPdfRichContent(
      String text, pw.Font font, pw.Font boldFont, pw.Font italicFont) {
    final List<pw.Widget> blocks = [];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        blocks.add(pw.SizedBox(height: 8));
        continue;
      }

      // Check if line contains LaTeX-like patterns even without $
      final hasRawMath = line.contains(r'\frac') ||
          line.contains(r'\times') ||
          line.contains('_');
      final mathLayers = line.split(RegExp(r'\$'));
      final List<pw.Widget> lineWidgets = [];

      int k = 0;
      while (k < mathLayers.length) {
        final segment = _cleanLatex(mathLayers[k]);
        if (segment.isNotEmpty) {
          // If it's a math segment (between $) OR if the whole line is "raw math"
          if (k % 2 == 1 || (mathLayers.length == 1 && hasRawMath)) {
            lineWidgets.add(_buildMathWidget(segment, italicFont));
          } else {
            final boldParts = segment.split('**');
            int m = 0;
            while (m < boldParts.length) {
              final t = boldParts[m];
              if (t.isNotEmpty) {
                // Check if this "normal" segment has subscripts or symbols
                if (t.contains('_') || t.contains(r'\times')) {
                  lineWidgets
                      .add(_buildMathWidget(t, m % 2 == 1 ? boldFont : font));
                } else {
                  lineWidgets.add(pw.Text(t,
                      style: pw.TextStyle(
                          font: m % 2 == 1 ? boldFont : font, fontSize: 11)));
                }
              }
              m = m + 1;
            }
          }
        }
        k = k + 1;
      }
      blocks.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            spacing: 2,
            children: lineWidgets,
          ),
        ),
      );
    }
    return blocks;
  }

  pw.Widget _buildMathWidget(String math, pw.Font mathFont) {
    String p = math
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\beta', 'β')
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\pi', 'π')
        .replaceAll(r'\infty', '∞')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\rightarrow', '→')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\sigma', 'σ')
        .replaceAll(r'\sum', 'Σ');

    final RegExp fracRegex = RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}');
    if (fracRegex.hasMatch(p)) {
      final List<pw.Widget> rowParts = [];
      int lastEnd = 0;

      for (final match in fracRegex.allMatches(p)) {
        if (match.start > lastEnd) {
          rowParts.add(
              _buildMathWidget(p.substring(lastEnd, match.start), mathFont));
        }

        final n = match.group(1) ?? '';
        final d = match.group(2) ?? '';

        rowParts.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                _buildMathWidget(n, mathFont),
                pw.Container(
                    height: 0.5,
                    width: (n.length > d.length ? n.length : d.length) * 5.5,
                    color: PdfColors.black),
                _buildMathWidget(d, mathFont),
              ],
            ),
          ),
        );
        lastEnd = match.end;
      }

      if (lastEnd < p.length) {
        rowParts.add(_buildMathWidget(p.substring(lastEnd), mathFont));
      }

      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: rowParts,
      );
    }

    // Subscript handling (e.g. R_d or R_{sub})
    final RegExp subRegex =
        RegExp(r'([a-zA-Z0-9])_(\{([^}]*)\}|([a-zA-Z0-9]))');
    if (subRegex.hasMatch(p)) {
      final List<pw.Widget> subParts = [];
      int lastEnd = 0;
      for (final match in subRegex.allMatches(p)) {
        if (match.start > lastEnd) {
          subParts.add(_mathText(p.substring(lastEnd, match.start), mathFont));
        }

        final base = match.group(1) ?? '';
        final subscript = match.group(3) ?? match.group(4) ?? '';

        subParts.add(
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _mathText(base, mathFont),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: -2),
                child: pw.Text(subscript,
                    style: pw.TextStyle(
                        font: mathFont, fontSize: 7, color: PdfColors.blue900)),
              ),
            ],
          ),
        );
        lastEnd = match.end;
      }
      if (lastEnd < p.length) {
        subParts.add(_mathText(p.substring(lastEnd), mathFont));
      }
      return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: subParts);
    }

    return _mathText(p, mathFont);
  }

  pw.Widget _mathText(String text, pw.Font mathFont) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        font: mathFont,
        color: PdfColors.blue900,
        fontSize: 11,
      ),
    );
  }
}

class _MathSyntax extends md.InlineSyntax {
  _MathSyntax() : super(r'\$\$?([^$]+)\$\$?');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('latex', match.group(1)!));
    return true;
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  final bool isUser;
  _MathBuilder({required this.isUser});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    return Math.tex(
      text,
      textStyle: TextStyle(
        fontSize: 16,
        color: isUser ? Colors.white : const Color(0xFF00D1FF),
      ),
      onErrorFallback: (err) => Text(
        text,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
