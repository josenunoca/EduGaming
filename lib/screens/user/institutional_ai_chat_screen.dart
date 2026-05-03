import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../models/institution_model.dart';
import '../../../services/ai_chat_service.dart';
import '../../../services/institutional_knowledge_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import '../../../services/firebase_service.dart';

class InstitutionalAiChatScreen extends StatefulWidget {
  final UserModel user;
  final InstitutionModel institution;

  const InstitutionalAiChatScreen({
    super.key,
    required this.user,
    required this.institution,
  });

  @override
  State<InstitutionalAiChatScreen> createState() => _InstitutionalAiChatScreenState();
}

class _InstitutionalAiChatScreenState extends State<InstitutionalAiChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _loadKnowledgeBase();
  }

  Future<void> _loadKnowledgeBase() async {
    final aiService = context.read<AiChatService>();
    final knowledgeService = context.read<InstitutionalKnowledgeService>();

    try {
      final docs = await knowledgeService.getVisibleDocuments(widget.institution.id, widget.user);
      if (docs.isEmpty) {
        setState(() {
          _messages.add({
            'role': 'ai', 
            'content': 'Ainda não existem documentos públicos ou regulamentos disponíveis no repositório desta instituição.',
            'feedback': null,
          });
        });
      } else {
        await aiService.initializeInstitutionalSession(docs);
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _messages.add({
          'role': 'ai', 
          'content': 'Erro ao ligar ao cérebro da instituição: $e',
          'feedback': null,
        });
      });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;

    final userMsg = _msgController.text.trim();
    _msgController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMsg});
      _isTyping = true;
    });

    _scrollToBottom();

    final aiService = context.read<AiChatService>();
    String responseContent = '';
    
    setState(() {
      _messages.add({
        'role': 'ai', 
        'content': '',
        'prompt': userMsg,
        'feedback': null,
      });
    });

    aiService.sendMessage(userMsg).listen(
      (chunk) {
        if (chunk.startsWith('ERRO_IA:')) {
          setState(() {
            _isTyping = false;
            _messages.last['content'] = 'Ocorreu um erro técnico: ${chunk.replaceFirst('ERRO_IA:', '')}';
          });
          return;
        }
        responseContent += chunk;
        setState(() {
          _messages.last['content'] = responseContent;
        });
        _scrollToBottom();
      },
      onDone: () => setState(() => _isTyping = false),
      onError: (e) {
        setState(() {
          _isTyping = false;
          _messages.last['content'] = 'Desculpe, ocorreu um erro na ligação com a Instituição. Detalhes: $e';
        });
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Apoio à Família (IA)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index], index),
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline, color: Colors.orangeAccent, size: 64),
            const SizedBox(height: 16),
            const AiTranslatedText(
              'Como posso ajudar?',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AiTranslatedText(
              'Pergunte-me qualquer coisa sobre o regulamento, matrículas ou funcionamento da ${widget.institution.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    bool isUser = msg['role'] == 'user';
    int? feedback = msg['feedback'];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GlassCard(
              color: isUser ? Colors.orangeAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  msg['content']!,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
            if (!isUser && msg['content']!.isNotEmpty && !msg['content']!.contains('Erro')) 
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFeedbackButton(index, 1, Icons.thumb_up_outlined, Icons.thumb_up, feedback),
                    const SizedBox(width: 8),
                    _buildFeedbackButton(index, -1, Icons.thumb_down_outlined, Icons.thumb_down, feedback),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackButton(int index, int rating, IconData iconOutlined, IconData iconFilled, int? currentFeedback) {
    bool isSelected = currentFeedback == rating;
    return GestureDetector(
      onTap: currentFeedback != null ? null : () => _submitFeedback(index, rating),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected 
              ? (rating == 1 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2))
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSelected ? iconFilled : iconOutlined,
          size: 16,
          color: isSelected 
              ? (rating == 1 ? Colors.greenAccent : Colors.redAccent) 
              : Colors.white38,
        ),
      ),
    );
  }

  Future<void> _submitFeedback(int index, int rating) async {
    final msg = _messages[index];
    setState(() {
      _messages[index]['feedback'] = rating;
    });

    try {
      final firebaseService = context.read<FirebaseService>();
      await firebaseService.saveAiFeedback(
        institutionId: widget.institution.id,
        userId: widget.user.id,
        userRole: widget.user.role.name,
        prompt: msg['prompt'] ?? 'N/A',
        response: msg['content'] ?? '',
        rating: rating,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AiTranslatedText(rating == 1 ? 'Obrigado pelo seu feedback positivo!' : 'Obrigado pelo feedback. Vamos melhorar a nossa base de conhecimento.'),
            duration: const Duration(seconds: 2),
            backgroundColor: rating == 1 ? Colors.green.withValues(alpha: 0.8) : Colors.orange.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving feedback: $e');
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: GlassCard(
                child: TextField(
                  controller: _msgController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Escreva a sua pergunta...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isTyping ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
