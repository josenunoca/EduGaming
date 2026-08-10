import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_chat_service.dart';
import '../../services/edugaming_help_ai_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class EduGamingHelpCenterScreen extends StatefulWidget {
  final UserModel user;

  const EduGamingHelpCenterScreen({super.key, required this.user});

  @override
  State<EduGamingHelpCenterScreen> createState() =>
      _EduGamingHelpCenterScreenState();
}

class _EduGamingHelpCenterScreenState
    extends State<EduGamingHelpCenterScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'content':
          'Olá, ${widget.user.name}! Sou o Assistente de Ajuda Inteligente 360 da EduGaming.\n\nComo posso ajudar hoje? Pode perguntar sobre o controlo de presenças, sumários das aulas, materiais para a próxima semana, faltas de professores ou qualquer dúvida sobre a plataforma!',
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  List<String> get _quickQuestions {
    switch (widget.user.role) {
      case UserRole.parent:
        return [
          '❓ Como funciona o controlo de presenças e alertas?',
          '🗓️ Que atividades e sumários o meu filho teve hoje?',
          '📦 Que materiais são necessários para as atividades da próxima semana?',
          '⚠️ Existe alguma observação sobre o comportamento do meu educando?',
          '📊 Quantas faltas teve a professora este mês ou ano letivo?',
          '📝 Como registar faltas de vários dias seguidos com comprovativo?',
        ];
      case UserRole.teacher:
        return [
          '👥 Quem são os alunos ausentes hoje e na próxima semana?',
          '📑 Como gerar relatórios de assiduidade em PDF?',
          '🎮 Como criar jogos pedagógicos com Inteligência Artificial?',
          '📅 Como gerir sumários e presenças das minhas turmas?',
        ];
      case UserRole.student:
        return [
          '🎮 Como jogar os quizzes e ganhar créditos no ranking?',
          '📚 Que sumários e trabalhos tenho pendentes esta semana?',
          '📱 Como marcar presença com o QR Code Dinâmico?',
        ];
      default:
        return [
          '⚡ Como funciona a plataforma EduGaming 360?',
          '⚙️ Como gerir colaboradores e permissões?',
          '📊 Como emitir relatórios institucionais em PDF?',
        ];
    }
  }

  void _sendQuestion(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    final question = text.trim();
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _messages.add({'role': 'ai', 'content': ''});
      _isTyping = true;
    });

    _scrollToBottom();

    final firebaseService = context.read<FirebaseService>();
    final aiChatService = context.read<AiChatService>();

    try {
      final stream = EduGamingHelpAiService.askHelp(
        user: widget.user,
        userQuestion: question,
        firebaseService: firebaseService,
        aiChatService: aiChatService,
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          _messages.last['content'] = (_messages.last['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last['content'] = 'Erro ao processar resposta: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Color(0xFF00D1FF)),
            SizedBox(width: 8),
            AiTranslatedText(
              'Ajuda Inteligente 360',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // User Role Badge Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Color(0xFF00D1FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo Adaptado: ${widget.user.name} • ${_getRoleBadgeText(widget.user.role)}',
                    style: const TextStyle(
                        color: Color(0xFF00D1FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF7B61FF)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? Radius.zero : null,
                        bottomLeft: !isUser ? Radius.zero : null,
                      ),
                      border: Border.all(
                        color: isUser
                            ? const Color(0xFF7B61FF)
                            : const Color(0xFF00D1FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Questions Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickQuestions.length,
              itemBuilder: (context, index) {
                final q = _quickQuestions[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF00D1FF)),
                    label: Text(
                      q,
                      style: const TextStyle(
                          color: Color(0xFF00D1FF), fontSize: 11),
                    ),
                    onPressed: () => _sendQuestion(q),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: _sendQuestion,
                    decoration: InputDecoration(
                      hintText: 'Pergunte o que quiser sobre a escola ou plataforma...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF00D1FF),
                  child: IconButton(
                    icon: _isTyping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.black, size: 18),
                    onPressed: () => _sendQuestion(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleBadgeText(UserRole role) {
    switch (role) {
      case UserRole.parent:
        return 'Encarregado(a) de Educação';
      case UserRole.student:
        return 'Aluno(a)';
      case UserRole.teacher:
        return 'Docente / Professor(a)';
      case UserRole.admin:
        return 'Administração';
      default:
        return 'Utilizador';
    }
  }
}

/// Floating Action Button Widget to easily trigger Help Center anywhere
class EduGamingHelpButton extends StatelessWidget {
  final UserModel user;

  const EduGamingHelpButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '💡 Central de Ajuda Inteligente 360',
      child: FloatingActionButton(
        heroTag: 'help_btn_${user.id}',
        backgroundColor: const Color(0xFF00D1FF),
        foregroundColor: Colors.black,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EduGamingHelpCenterScreen(user: user),
            ),
          );
        },
        child: const Icon(Icons.lightbulb_outline_rounded, size: 28),
      ),
    );
  }
}
