import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/subject_model.dart';
import '../../../services/ai_chat_service.dart';
import '../../../services/firebase_service.dart'; // Added
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import 'ai_game_editor_screen.dart';

class AiGameCreatorScreen extends StatefulWidget {
  final Subject subject;
  final List<SubjectContent> initialSelectedContents;

  const AiGameCreatorScreen({
    super.key,
    required this.subject,
    this.initialSelectedContents = const [],
  });

  @override
  State<AiGameCreatorScreen> createState() => _AiGameCreatorScreenState();
}

class _AiGameCreatorScreenState extends State<AiGameCreatorScreen> {
  late List<SubjectContent> _selectedContents;
  String _selectedGameType = 'kahoot';
  bool _isGenerating = false;
  bool _isAssessment = false;
  final TextEditingController _pinController = TextEditingController();

  final List<Map<String, String>> _gameTypes = [
    {
      'id': 'kahoot',
      'name': 'Estilo Kahoot (Múltipla Escolha)',
      'icon': 'quiz'
    },
    {'id': 'quiz', 'name': 'Exame Técnico Tradicional', 'icon': 'assignment'},
    {'id': 'flashcards', 'name': 'Flashcards de Estudo Ativo', 'icon': 'style'},
    {'id': 'puzzle_logic', 'name': 'Desafio de Lógica Profunda', 'icon': 'extension'},
    {'id': 'jigsaw', 'name': 'Jigsaw Puzzle (Arrastar e Rodar)', 'icon': '🧩'},
    {'id': 'memory', 'name': 'Jogo da Memória Visual', 'icon': 'psychology'},
    {'id': 'word_search', 'name': 'Sopa de Letras (Word Search)', 'icon': 'grid_on'},
    {'id': 'matching', 'name': 'Correspondência de Conceitos', 'icon': 'sync_alt'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedContents = List.from(widget.initialSelectedContents);
  }

  Future<void> _generateGame() async {
    if (_selectedContents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText('Selecione pelo menos um conteúdo.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final service = context.read<FirebaseService>();
    final authUser = context.read<FirebaseService>().currentUser; // Assuming currentUser is exposed or get uid

    try {
      if (authUser == null) throw 'Utilizador não autenticado.';
      
      // Determine target for credits (Institution or Teacher)
      final targetId = widget.subject.institutionId.isNotEmpty 
          ? widget.subject.institutionId 
          : authUser.uid;
      final targetType = widget.subject.institutionId.isNotEmpty ? 'institution' : 'user';

      // Check credits
      final hasCredits = await service.hasEnoughAiCredits(targetId, targetType, 1);
      if (!hasCredits) {
        if (mounted) {
          _showOutOfCreditsDialog(context, targetType);
          setState(() => _isGenerating = false);
        }
        return;
      }

      final aiService = context.read<AiChatService>();
      final gameData = await aiService.generateAiGame(
        contents: _selectedContents,
        gameType: _selectedGameType,
      );

      if (gameData != null && mounted) {
        final newGame = AiGame(
          id: const Uuid().v4(),
          title: gameData['title'] ?? 'Novo Jogo AI',
          type: _selectedGameType,
          questions: (gameData['questions'] as List? ?? [])
              .map((q) => GameQuestion.fromMap(q as Map<String, dynamic>))
              .toList(),
          isAssessment: _isAssessment,
          subjectId: widget.subject.id,
          sourceContentIds: _selectedContents.map((c) => c.id).toList(),
          imageUrl: gameData['imageUrl'],
          settings: gameData['settings'],
          pin: _pinController.text.isNotEmpty ? _pinController.text : null,
        );
        
        // Deduct credit after successful generation
        await service.deductAiCredits(targetId, targetType, 1);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AiGameEditorScreen(subject: widget.subject, game: newGame),
            ),
          );
        }
      } else {
        throw 'Falha ao processar resposta da IA.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar jogo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Criador de Jogos AI'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AiTranslatedText(
                  '1. Selecione os Conteúdos Base',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: GlassCard(
                    child: ListView.builder(
                    itemCount: widget.subject.contents.length,
                    itemBuilder: (context, index) {
                      final content = widget.subject.contents[index];
                      final isSelected = _selectedContents.contains(content);
                      return CheckboxListTile(
                        title: AiTranslatedText(content.name,
                            style: const TextStyle(color: Colors.white70)),
                        subtitle: Text(content.type.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        value: isSelected,
                        activeColor: const Color(0xFF00D1FF),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedContents.add(content);
                            } else {
                              _selectedContents.remove(content);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
                const AiTranslatedText(
                  '2. Escolha o Estilo do Jogo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 80,
                  ),
                  itemCount: _gameTypes.length,
                  itemBuilder: (context, index) {
                    final type = _gameTypes[index];
                    final isSelected = _selectedGameType == type['id'];
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedGameType = type['id']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF7B61FF).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00D1FF)
                                : Colors.white.withValues(alpha: 0.1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFF00D1FF).withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildTypeIcon(type),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AiTranslatedText(
                                type['name']!,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              const AiTranslatedText(
                '3. Opções Adicionais',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const AiTranslatedText('Modo de Avaliação',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const AiTranslatedText(
                          'Se ativado, os resultados contam para a nota final.',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                      value: _isAssessment,
                      activeThumbColor: const Color(0xFF00D1FF),
                      onChanged: (val) => setState(() => _isAssessment = val),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _pinController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Definir PIN de Acesso (Opcional)',
                          labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                          hintText: 'Ex: 1234',
                          hintStyle: TextStyle(color: Colors.white24),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.white38),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _isGenerating
                  ? const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF00D1FF)),
                          SizedBox(height: 16),
                          AiTranslatedText(
                              'A IA está a desenvolver o seu jogo...',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _generateGame,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: const Color(0xFF7B61FF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        shadowColor:
                            const Color(0xFF7B61FF).withValues(alpha: 0.4),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 12),
                          AiTranslatedText(
                            'GERAR JOGO COM IA',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(Map<String, String> type) {
    final iconData = type['icon']!;
    if (iconData.length == 1 && iconData.codeUnitAt(0) > 127) {
      // It's an emoji
      return Text(iconData, style: const TextStyle(fontSize: 18));
    }
    
    // It's a Material icon name
    IconData actualIcon;
    switch (type['id']) {
      case 'kahoot':
        actualIcon = Icons.quiz;
        break;
      case 'quiz':
        actualIcon = Icons.assignment;
        break;
      case 'flashcards':
        actualIcon = Icons.style;
        break;
      case 'puzzle_logic':
        actualIcon = Icons.extension;
        break;
      case 'memory':
        actualIcon = Icons.psychology;
        break;
      case 'word_search':
        actualIcon = Icons.grid_on;
        break;
      case 'matching':
        actualIcon = Icons.sync_alt;
        break;
      default:
        actualIcon = Icons.games;
    }
    return Icon(actualIcon, color: const Color(0xFF00D1FF), size: 20);
  }

  void _showOutOfCreditsDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Créditos Insuficientes', style: TextStyle(color: Colors.white)),
        content: AiTranslatedText(
          type == 'institution'
          ? 'A sua instituição esgotou os créditos de IA. Contacte o administrador para recarregar.'
          : 'Esgotou os seus créditos de IA. Adquira um novo pack na sua área pessoal.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
