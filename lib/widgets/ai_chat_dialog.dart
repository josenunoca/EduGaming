import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_chat_service.dart';
import '../models/subject_model.dart';
import '../utils/download_helper.dart';
import '../services/did_video_service.dart';
import '../widgets/ai_translated_text.dart';
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
  final List<Map<String, dynamic>> _messages = [];
  bool _isInitializing = true;
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  // Image attachment
  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  bool _isDragOver = false;

  // Search mode
  DocSearchMode _searchMode = DocSearchMode.internal;

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
    await chatService.initializeSessionWithMode(widget.selectedContents, _searchMode);
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _messages.add({
          'role': 'assistant',
          'text': _welcomeMessage(),
        });
      });
    }
  }

  String _welcomeMessage() {
    switch (_searchMode) {
      case DocSearchMode.internal:
        return 'Olá! Analisei ${widget.selectedContents.length} documentos selecionados. '
            'Modo 📁 **Interno** ativo: responderei exclusivamente com base nesses documentos. '
            'O que gostaria de explorar?';
      case DocSearchMode.internet:
        return 'Olá! Modo 🌐 **Internet** ativo: pesquisarei os melhores conteúdos online. '
            'Tenho também acesso aos ${widget.selectedContents.length} documentos internos como contexto. '
            'O que gostaria de saber?';
      case DocSearchMode.both:
        return 'Olá! Modo 📁+🌐 **Interno + Internet** ativo: combinarei os documentos internos com pesquisa online. '
            'Vou indicar sempre a origem de cada informação. O que gostaria de explorar?';
    }
  }

  Future<void> _changeSearchMode(DocSearchMode mode) async {
    if (mode == _searchMode) return;
    final chatService = context.read<AiChatService>();
    setState(() {
      _searchMode = mode;
      _isInitializing = true;
      _messages.clear();
    });
    await chatService.initializeSessionWithMode(widget.selectedContents, mode);
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _messages.add({'role': 'assistant', 'text': _welcomeMessage()});
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
    final hasImage = _pendingImageBytes != null;
    if ((text.isEmpty && !hasImage) || _isTyping) return;

    final imageBytes = _pendingImageBytes;
    final imageMime = _pendingImageMime ?? 'image/jpeg';
    final displayText = text.isEmpty ? '📎 Imagem anexada' : text;

    setState(() {
      _messages.add({
        'role': 'user',
        'text': displayText,
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes),
      });
      _msgController.clear();
      _pendingImageBytes = null;
      _pendingImageMime = null;
      _isTyping = true;
      _messages.add({'role': 'assistant', 'text': ''});
    });
    _scrollToBottom();

    final chatService = context.read<AiChatService>();
    String responseAccumulated = '';

    try {
      final stream = imageBytes != null
          ? chatService.sendMessageWithImage(text, imageBytes, imageMime)
          : chatService.sendMessage(text);

      await for (final chunk in stream) {
        responseAccumulated += chunk;
        if (mounted) {
          setState(() => _messages.last['text'] = responseAccumulated);
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _messages.last['text'] = 'Erro de comunicação: $e');
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? (picked.name.endsWith('.png') ? 'image/png' : 'image/jpeg');
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageMime = mime;
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _pasteImageFromClipboard() async {
    // Flutter's Clipboard doesn't support binary image data natively.
    // We open the camera as a quick-capture alternative.
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/jpeg';
      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageMime = mime;
      });
    } catch (e) {
      debugPrint('Camera capture error: $e');
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
              final imageBase64 = msg['imageBase64'] as String?;

              final List<pw.Widget> blocks = [
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
              ];

              // Add image if present
              if (imageBase64 != null && imageBase64.isNotEmpty) {
                try {
                  final imageBytes = base64Decode(imageBase64);
                  blocks.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '[Imagem anexada pelo utilizador]',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Image(
                            pw.MemoryImage(imageBytes),
                            fit: pw.BoxFit.contain,
                            width: 400,
                          ),
                        ],
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('[PDF] Failed to embed image: $e');
                }
              }

              // Add text content
              blocks.addAll(
                _buildPdfRichContent(content, font, fontBold, fontItalic),
              );

              return blocks;
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

      if (audioBytes != null && audioBytes.isNotEmpty) {
        // Step 3: Trigger Download
        await DownloadHelper.downloadFile(
          audioBytes,
          'DocTalk_Pro_Podcast_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
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
          _buildSearchModeSelector(),
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
                        return _buildMessageBubble(
                          msg['text'] ?? '',
                          isUser,
                          imageBase64: msg['imageBase64'],
                        );
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

  Widget _buildSearchModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.manage_search_rounded, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          const Text('Pesquisa:', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 10),
          _modChip(DocSearchMode.internal, '📁 Interno', const Color(0xFF7B61FF)),
          const SizedBox(width: 6),
          _modChip(DocSearchMode.internet, '🌐 Internet', const Color(0xFF00D1FF)),
          const SizedBox(width: 6),
          _modChip(DocSearchMode.both, '📁+🌐 Ambos', const Color(0xFF00FF85)),
        ],
      ),
    );
  }

  Widget _modChip(DocSearchMode mode, String label, Color activeColor) {
    final isActive = _searchMode == mode;
    return GestureDetector(
      onTap: _isInitializing ? null : () => _changeSearchMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.1),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : Colors.white38,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, {String? imageBase64}) {
    final processedText = text;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                (isUser ? 0.78 : 0.92)),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF7B61FF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageBase64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(imageBase64),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 10),
            ],
            MarkdownBody(
                data: processedText,
                selectable: true,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                styleSheet: MarkdownStyleSheet(
                  // Paragraphs
                  p: TextStyle(
                      color: isUser ? Colors.white : Colors.white70,
                      fontSize: 14,
                      height: 1.55),
                  // Bold & italic
                  strong: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF00D1FF),
                      fontWeight: FontWeight.bold),
                  em: TextStyle(
                      color: isUser ? Colors.white70 : Colors.white60,
                      fontStyle: FontStyle.italic),
                  // Headings
                  h1: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF7B61FF),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  h2: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF00D1FF),
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                  h3: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF00FF85),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  // Code
                  code: TextStyle(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      color: const Color(0xFF00FF85),
                      fontFamily: 'monospace',
                      fontSize: 12),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF7B61FF).withValues(alpha: 0.3)),
                  ),
                  codeblockPadding: const EdgeInsets.all(14),
                  // Blockquote
                  blockquote: const TextStyle(
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                      fontSize: 13),
                  blockquoteDecoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: Color(0xFF7B61FF), width: 3)),
                    color: Color(0x0AFFFFFF),
                  ),
                  blockquotePadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  // Tables
                  tableHead: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  tableBody: TextStyle(
                      color: isUser ? Colors.white : Colors.white70,
                      fontSize: 12.5),
                  tableHeadAlign: TextAlign.center,
                  tableBorder: TableBorder.all(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.35),
                    width: 1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  tableColumnWidth: const FlexColumnWidth(),
                  tableCellsPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  tableCellsDecoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  // Lists
                  listBullet: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF7B61FF)),
                  listIndent: 18,
                  // Horizontal rule
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color:
                                const Color(0xFF7B61FF).withValues(alpha: 0.3),
                            width: 1.5)),
                  ),
                ),
                builders: {'latex': _MathBuilder(isUser: isUser)},
                inlineSyntaxes: [_MathSyntax()],
              ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.white54, size: 18),
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
    return DragTarget<Uint8List>(
      onWillAcceptWithDetails: (_) {
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() {
          _pendingImageBytes = details.data;
          _pendingImageMime = 'image/png';
          _isDragOver = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isDragOver ? const Color(0xFF7B61FF).withValues(alpha: 0.1) : const Color(0xFF1E293B),
            border: Border(
              top: BorderSide(color: _isDragOver ? const Color(0xFF7B61FF) : Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag hint ──
                if (_isDragOver)
                  Container(
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF7B61FF), width: 2, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_rounded, color: Color(0xFF7B61FF), size: 28),
                          SizedBox(height: 4),
                          Text('Soltar imagem aqui', style: TextStyle(color: Color(0xFF7B61FF), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                // ── Image preview ──
                if (_pendingImageBytes != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pendingImageBytes!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _pendingImageBytes = null;
                            _pendingImageMime = null;
                          }),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                // ── Voice indicator ──
                if (_isListening && _lastWords.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 10, left: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: Color(0xFF00D1FF), size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Captado: $_lastWords', style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 12))),
                      ],
                    ),
                  ),
                // ── Input row ──
                Row(
                  children: [
                    // Mic
                    IconButton(
                      onPressed: _listen,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.redAccent : Colors.white54,
                      ),
                    ),
                    // Image attach
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.attach_file_rounded, color: Colors.white54),
                      tooltip: 'Anexar imagem',
                    ),
                    // Paste image
                    IconButton(
                      onPressed: _pasteImageFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, color: Colors.white54),
                      tooltip: 'Colar imagem (Ctrl+V)',
                    ),
                    const SizedBox(width: 4),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _pendingImageBytes != null
                              ? 'Adicione uma pergunta sobre a imagem (opcional)...'
                              : _searchMode == DocSearchMode.internal
                                  ? 'Pergunte sobre os documentos internos...'
                                  : _searchMode == DocSearchMode.internet
                                      ? 'Pergunte qualquer coisa (pesquisa online)...'
                                      : 'Pergunte (docs internos + internet)...',
                          hintStyle: const TextStyle(color: Colors.white30),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          fillColor: Colors.white.withValues(alpha: 0.05),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Send button
                    Container(
                      decoration: BoxDecoration(
                        color: _pendingImageBytes != null ? Colors.greenAccent.shade700 : const Color(0xFF7B61FF),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: Icon(
                          _pendingImageBytes != null ? Icons.image_search_rounded : Icons.send,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Strips LaTeX commands to clean readable text for PDF
  String _latexToReadable(String latex) {
    return latex
        .replaceAllMapped(RegExp(r'\\text\{([^}]*)\}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\\textbf\{([^}]*)\}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\\mathrm\{([^}]*)\}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\\frac\{([^}]*)\}\{([^}]*)\}'),
            (m) => '(${m.group(1)})/(${m.group(2)})')
        .replaceAllMapped(RegExp(r'_\{([^}]*)\}'), (m) => m.group(1) ?? '')
        .replaceAllMapped(RegExp(r'\^\{([^}]*)\}'), (m) => '^${m.group(1)}')
        .replaceAll(r'\times', 'Ã—')
        .replaceAll(r'\cdot', 'Â·')
        .replaceAll(r'\beta', 'Î²')
        .replaceAll(r'\alpha', 'Î±')
        .replaceAll(r'\gamma', 'Î³')
        .replaceAll(r'\Delta', 'Î”')
        .replaceAll(r'\delta', 'Î´')
        .replaceAll(r'\pi', 'Ï€')
        .replaceAll(r'\infty', 'âˆž')
        .replaceAll(r'\pm', 'Â±')
        .replaceAll(r'\leq', 'â‰¤')
        .replaceAll(r'\geq', 'â‰¥')
        .replaceAll(r'\neq', 'â‰ ')
        .replaceAll(r'\approx', 'â‰ˆ')
        .replaceAll(r'\rightarrow', 'â†’')
        .replaceAll(r'\leftarrow', 'â†')
        .replaceAll(r'\mu', 'Î¼')
        .replaceAll(r'\sigma', 'Ïƒ')
        .replaceAll(r'\sum', 'Î£')
        .replaceAll(r'\int', 'âˆ«')
        .replaceAll(r'\partial', 'âˆ‚')
        .replaceAll(r'\sqrt', 'âˆš')
        .replaceAll(r'\lambda', 'Î»')
        .replaceAll(r'\theta', 'Î¸')
        .replaceAll(r'\phi', 'Ï†')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}')
        .replaceAll(r'\\', ' ')
        .trim();
  }

  /// Build inline pw.TextSpan list for **bold**, *italic*, $latex$, `code`
  List<pw.InlineSpan> _buildInlineSpans(
      String text, pw.Font font, pw.Font boldFont, pw.Font italicFont) {
    final spans = <pw.InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|\$([^$]+)\$|`([^`]+)`');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(pw.TextSpan(
            text: text.substring(last, m.start),
            style: pw.TextStyle(font: font, fontSize: 11)));
      }
      if (m.group(1) != null) {
        spans.add(pw.TextSpan(
            text: m.group(1)!,
            style: pw.TextStyle(font: boldFont, fontSize: 11)));
      } else if (m.group(2) != null) {
        spans.add(pw.TextSpan(
            text: m.group(2)!,
            style: pw.TextStyle(
                font: italicFont, fontSize: 11, color: PdfColors.grey700)));
      } else if (m.group(3) != null) {
        spans.add(pw.TextSpan(
            text: _latexToReadable(m.group(3)!),
            style: pw.TextStyle(
                font: italicFont, fontSize: 11, color: PdfColors.blue900)));
      } else if (m.group(4) != null) {
        spans.add(pw.TextSpan(
            text: m.group(4)!,
            style: pw.TextStyle(
                font: font,
                fontSize: 9.5,
                color: PdfColors.green900,
                background:
                    const pw.BoxDecoration(color: PdfColors.grey200))));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(pw.TextSpan(
          text: text.substring(last),
          style: pw.TextStyle(font: font, fontSize: 11)));
    }
    return spans;
  }

  /// Parse markdown table lines (skip separator rows) into string rows
  List<List<String>> _parseMarkdownTable(List<String> tableLines) {
    final rows = <List<String>>[];
    for (final line in tableLines) {
      final t = line.trim();
      if (t.startsWith('|') && !RegExp(r'^\|[\s\-|:]+\|$').hasMatch(t)) {
        rows.add(t
            .split('|')
            .where((c) => c.isNotEmpty)
            .map((c) => _latexToReadable(
                c.trim().replaceAll(RegExp(r'\*\*?([^*]+)\*\*?'), r'$1')))
            .toList());
      }
    }
    return rows;
  }

  /// Render table rows as a styled pw.Table
  pw.Widget _buildPdfTable(
      List<List<String>> rows, pw.Font font, pw.Font boldFont) {
    if (rows.isEmpty) return pw.SizedBox();
    final header = rows.first;
    final data = rows.skip(1).toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.indigo200, width: 0.5),
      columnWidths: {
        for (int i = 0; i < header.length; i++) i: const pw.FlexColumnWidth()
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
          children: header
              .map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    child: pw.Text(cell,
                        style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.white)),
                  ))
              .toList(),
        ),
        ...data.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: e.key.isEven ? PdfColors.grey50 : PdfColors.white),
              children: e.value
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: pw.Text(cell,
                            style: pw.TextStyle(font: font, fontSize: 10)),
                      ))
                  .toList(),
            )),
      ],
    );
  }

  /// Full markdown-aware PDF content builder
  List<pw.Widget> _buildPdfRichContent(
      String text, pw.Font font, pw.Font boldFont, pw.Font italicFont) {
    final blocks = <pw.Widget>[];
    final lines = text.split('\n');
    int i = 0;
    while (i < lines.length) {
      final trimmed = lines[i].trim();

      if (trimmed.isEmpty) {
        blocks.add(pw.SizedBox(height: 6));
        i++;
        continue;
      }

      // Code block
      if (trimmed.startsWith('```')) {
        final codeLines = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        i++;
        blocks.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: codeLines
                .map((cl) => pw.Text(cl,
                    style: pw.TextStyle(
                        font: font, fontSize: 9, color: PdfColors.green900)))
                .toList(),
          ),
        ));
        continue;
      }

      // Markdown table
      if (trimmed.startsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          tableLines.add(lines[i]);
          i++;
        }
        final rows = _parseMarkdownTable(tableLines);
        if (rows.isNotEmpty) {
          blocks.add(pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: _buildPdfTable(rows, font, boldFont),
          ));
        }
        continue;
      }

      // H3
      if (trimmed.startsWith('### ')) {
        blocks.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
          child: pw.Text(trimmed.substring(4),
              style: pw.TextStyle(
                  font: boldFont, fontSize: 13, color: PdfColors.indigo600)),
        ));
        i++;
        continue;
      }
      // H2
      if (trimmed.startsWith('## ')) {
        blocks.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(trimmed.substring(3),
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 15,
                      color: PdfColors.indigo800)),
              pw.Container(
                  height: 1,
                  margin: const pw.EdgeInsets.only(top: 2),
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.indigo200)),
            ],
          ),
        ));
        i++;
        continue;
      }
      // H1
      if (trimmed.startsWith('# ')) {
        blocks.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(trimmed.substring(2),
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 18,
                      color: PdfColors.indigo900)),
              pw.Container(
                  height: 2,
                  margin: const pw.EdgeInsets.only(top: 3),
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.indigo400)),
            ],
          ),
        ));
        i++;
        continue;
      }

      // Divider
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(pw.Divider(thickness: 0.5, color: PdfColors.grey400));
        i++;
        continue;
      }

      // Numbered list
      final numM = RegExp(r'^(\d+)\. (.+)').firstMatch(trimmed);
      if (numM != null) {
        blocks.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: '${numM.group(1)}. ',
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      color: PdfColors.indigo700)),
              ..._buildInlineSpans(
                  numM.group(2)!, font, boldFont, italicFont),
            ]),
          ),
        ));
        i++;
        continue;
      }

      // Bullet list
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('â€¢ ')) {
        final content = trimmed.substring(2);
        blocks.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, bottom: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: 'â€¢ ',
                  style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 11,
                      color: PdfColors.indigo600)),
              ..._buildInlineSpans(content, font, boldFont, italicFont),
            ]),
          ),
        ));
        i++;
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        blocks.add(pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                left: pw.BorderSide(color: PdfColors.indigo300, width: 3)),
            color: PdfColors.grey50,
          ),
          child: pw.RichText(
            text: pw.TextSpan(
                children: _buildInlineSpans(
                    trimmed.substring(2), font, boldFont, italicFont)),
          ),
        ));
        i++;
        continue;
      }

      // Normal paragraph
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.RichText(
          text: pw.TextSpan(
              children:
                  _buildInlineSpans(trimmed, font, boldFont, italicFont)),
        ),
      ));
      i++;
    }
    return blocks;
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
