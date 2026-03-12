import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart'; // Added for UserModel and UserRole
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/content_uploader.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/ai_chat_dialog.dart';
import 'gamification/ai_game_creator_screen.dart';
import 'gamification/ai_game_editor_screen.dart';
import 'gamification/ai_game_ranking_screen.dart';
import 'gamification/grades_management_screen.dart';
import 'syllabus_management_screen.dart';
import 'gamification/exam_monitor_screen.dart';

class SubjectDetailsScreen extends StatefulWidget {
  final Subject subject;
  const SubjectDetailsScreen({super.key, required this.subject});

  @override
  State<SubjectDetailsScreen> createState() => _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends State<SubjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Subject _currentSubject;
  String _searchQuery = '';
  final List<SubjectContent> _selectedContents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _currentSubject = widget.subject;
  }

  Future<void> _updateSubject() async {
    final service = context.read<FirebaseService>();
    await service.updateSubject(_currentSubject);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AiTranslatedText(_currentSubject.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
                icon: Icon(Icons.assessment_outlined),
                child: AiTranslatedText('Componentes')),
            Tab(
                icon: Icon(Icons.library_books_outlined),
                child: AiTranslatedText('Conteúdos')),
            Tab(
                icon: Icon(Icons.auto_awesome),
                child: AiTranslatedText('IA Gamer')),
            Tab(
                icon: Icon(Icons.videogame_asset_outlined),
                child: AiTranslatedText('Avaliação/Ranking')),
            Tab(
                icon: Icon(Icons.people_outline),
                child: AiTranslatedText('Alunos')),
            Tab(
                icon: Icon(Icons.assignment_turned_in_outlined),
                child: AiTranslatedText('Notas e Pautas')),
            Tab(
                icon: Icon(Icons.menu_book_outlined),
                child: AiTranslatedText('Programa e Sumários')),
          ],
        ),
      ),
      body: StreamBuilder<Subject?>(
        stream: context.read<FirebaseService>().getSubjectStream(widget.subject.id),
        initialData: widget.subject,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            _currentSubject = snapshot.data!;
          }
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEvaluationTab(),
                _buildContentsTab(),
                _buildGamificationTab(),
                _buildGamesTab(),
                _buildStudentsTab(),
                GradesManagementScreen(subject: _currentSubject),
                SyllabusManagementScreen(subject: _currentSubject),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEvaluationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Regras de Avaliação',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExamMonitorScreen(subject: _currentSubject),
                        ),
                      );
                    },
                    icon: const Icon(Icons.monitor_heart, size: 18),
                    label: const AiTranslatedText('Monitor'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddEvaluationDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const AiTranslatedText('Novo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B61FF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _currentSubject.evaluationComponents.isEmpty
                ? const Center(
                    child: AiTranslatedText('Nenhuma componente definida.',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _currentSubject.evaluationComponents.length,
                    itemBuilder: (context, index) {
                      final comp = _currentSubject.evaluationComponents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  AiTranslatedText(comp.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  Text('${(comp.weight * 100).toInt()}%',
                                      style: const TextStyle(
                                          color: Color(0xFF00D1FF),
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Divider(color: Colors.white10),
                              AiTranslatedText(
                                  '${comp.contentIds.length} itens vinculados',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    label: const AiTranslatedText(
                                        'Vincular Itens',
                                        style: TextStyle(fontSize: 11)),
                                    onPressed: () =>
                                        _showLinkContentDialog(comp),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.05),
                                  ),
                                  ActionChip(
                                    label: const AiTranslatedText(
                                        'Editar',
                                        style: TextStyle(fontSize: 11)),
                                    onPressed: () =>
                                        _showAddEvaluationDialog(editableComponent: comp),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.05),
                                  ),
                                  ActionChip(
                                    label: const AiTranslatedText('Remover',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.redAccent)),
                                    onPressed: () async {
                                      final service = context.read<FirebaseService>();
                                      final hasResults = await service.hasEvaluationResults(
                                        _currentSubject.id,
                                        gameIds: comp.contentIds,
                                      );

                                      if (hasResults) {
                                        if (mounted) _showLockedItemDialog();
                                        return;
                                      }

                                      final confirmed = await _confirmDeletetion(
                                        'Eliminar Componente',
                                        'Tem a certeza que quer eliminar esta componente de avaliação? Todos os vínculos com jogos e ficheiros serão removidos desta regra.'
                                      );

                                      if (confirmed == true && mounted) {
                                        setState(() {
                                          _currentSubject.evaluationComponents.removeAt(index);
                                          _updateSubject();
                                        });
                                      }
                                    },
                                    backgroundColor:
                                        Colors.redAccent.withOpacity(0.1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showLockedItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Item Bloqueado', style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
          'Este item não pode ser eliminado porque já existem resultados de alunos registados como prova de avaliação neste ano letivo. A integridade dos dados tem de ser mantida.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1FF)),
            child: const AiTranslatedText('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDeletetion(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(title, style: const TextStyle(color: Colors.white)),
        content: AiTranslatedText(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ContentUploader(
            onUploadComplete: (content) {
              setState(() {
                _currentSubject.contents.add(content);
                _updateSubject();
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showAddUrlDialog,
            icon: const Icon(Icons.link),
            label: const AiTranslatedText('Adicionar Link (URL)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              foregroundColor: const Color(0xFF00D1FF),
              side: const BorderSide(color: Color(0xFF00D1FF)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiChatDialog(
                      selectedContents: List.from(_currentSubject.contents)),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const AiTranslatedText(
                'DocTalk: Conversar com IA sobre todos os conteúdos'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: const Color(0xFF7B61FF),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedContents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatDialog(
                          selectedContents: List.from(_selectedContents)),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined),
                label: AiTranslatedText(
                    'Conversar com IA sobre ${_selectedContents.length} itens selecionados'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF00D1FF),
                  foregroundColor: const Color(0xFF0F172A),
                ),
              ),
            ),
          Expanded(
            child: _currentSubject.contents.isEmpty
                ? const Center(
                    child: AiTranslatedText('Ainda não carregou ficheiros.',
                        style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _currentSubject.contents.length,
                    itemBuilder: (context, index) {
                      final content = _currentSubject.contents[index];
                      final isSelected = _selectedContents.contains(content);
                      final isLink = content.type == 'url' ||
                          content.url.startsWith('http');
                      final bool isEvaluation = content.category != 'support';

                      return InkWell(
                        key: ValueKey(content.id),
                        onTap: () async {
                          final uri = Uri.tryParse(content.url);
                          if (uri != null) {
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Não foi possível abrir o conteúdo.')),
                                );
                              }
                            }
                          }
                        },
                        child: Column(
                          children: [
                            ListTile(
                              leading: Checkbox(
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
                              ),
                              title: Row(
                                children: [
                                  Icon(_getFileIcon(content.type),
                                      color: isEvaluation ? Colors.redAccent : const Color(0xFF00D1FF), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: AiTranslatedText(content.name,
                                          style: const TextStyle(
                                              color: Colors.white))),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isLink)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 28.0, top: 4.0, bottom: 4.0),
                                      child: Text(
                                        content.url,
                                        style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 12,
                                            decoration: TextDecoration.underline),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      const SizedBox(width: 28),
                                      AiTranslatedText(content.type.toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white38, fontSize: 11)),
                                      const SizedBox(width: 8),
                                      _buildCategoryBadge(content.category),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEvaluation)
                                    IconButton(
                                      icon: const Icon(Icons.analytics, color: Color(0xFF00D1FF), size: 20),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: AiTranslatedText('Estatísticas de acesso em desenvolvimento.'))
                                        );
                                      },
                                      tooltip: 'Estatísticas',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.white24),
                                    onPressed: () =>
                                        _confirmDeleteContent(content, index),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.white10, indent: 56),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteContent(SubjectContent content, int index) async {
    final service = context.read<FirebaseService>();
    final hasResults = await service.hasEvaluationResults(_currentSubject.id,
        gameId: content.id);

    if (hasResults) {
      if (mounted) _showLockedItemDialog();
      return;
    }

    final confirmed = await _confirmDeletetion('Eliminar Conteúdo',
        'Tem a certeza que quer eliminar o conteúdo selecionado? Esta ação não pode ser desfeita.');

    if (confirmed == true && mounted) {
      setState(() {
        _currentSubject.contents.removeAt(index);
        _selectedContents.remove(content);
        _updateSubject();
      });
    }
  }

  void _showAddUrlDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String selectedCategory = 'support';
    final weightController = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Adicionar Link (URL)',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Título do Link',
                    hintText: 'Ex: Wikipedia, Artigo Científico',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'URL / Link',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Tipo de Conteúdo'),
                  items: const [
                    DropdownMenuItem(
                        value: 'support',
                        child: AiTranslatedText('Material de Apoio')),
                    DropdownMenuItem(
                        value: 'exam',
                        child: AiTranslatedText('Exame / Prova')),
                    DropdownMenuItem(
                        value: 'game', child: AiTranslatedText('Jogo')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedCategory = v!),
                ),
                if (selectedCategory != 'support') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Peso / Ponderação',
                      hintText: 'Ex: 1.5',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor, preencha o título e o URL.')),
                  );
                  return;
                }

                String cleanUrl = urlController.text.trim();
                if (!cleanUrl.startsWith('http')) {
                  cleanUrl = 'https://$cleanUrl';
                }

                final newContent = SubjectContent(
                  id: const Uuid().v4(),
                  name: titleController.text.trim(),
                  url: cleanUrl,
                  type: 'url',
                  category: selectedCategory,
                  weight: double.tryParse(weightController.text) ?? 0.0,
                );

                setState(() {
                  _currentSubject.contents.add(newContent);
                  _updateSubject();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF)),
              child: const AiTranslatedText('Adicionar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    Color color = Colors.blue;
    String label = 'Apoio';
    if (category == 'exam') {
      color = Colors.redAccent;
      label = 'Exame';
    } else if (category == 'game') {
      color = Colors.orange;
      label = 'Jogo';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4)),
      child: AiTranslatedText(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGamesTab() {
    final service = context.watch<FirebaseService>();

    return StreamBuilder<List<AiGame>>(
      stream: service.getAiGamesBySubject(_currentSubject.id),
      builder: (context, snapshot) {
        final aiGames = snapshot.data ?? [];
        final evalContents =
            _currentSubject.contents.where((c) => c.category != 'support').toList();
        
        final allEvalItems = [
          ...evalContents.map((c) =>
              {'name': c.name, 'weight': c.weight, 'type': c.category, 'id': c.id}),
          ..._currentSubject.games.map((g) =>
              {'name': g.name, 'weight': g.weight, 'type': 'game', 'id': g.id}),
          ...aiGames.map((g) =>
              {'name': g.title, 'weight': 1.0, 'type': 'ai_game', 'id': g.id}), // Default weight 1.0 for AiGames
        ];

        double totalWeight = 0;
        for (var item in allEvalItems) {
          totalWeight += (item['weight'] as double);
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _showAddGameDialog,
                icon: const Icon(Icons.videogame_asset),
                label: const AiTranslatedText('Adicionar Jogo (URL)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF7B61FF),
                ),
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: AiTranslatedText('Itens de Avaliação e Ranking',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: allEvalItems.isEmpty
                    ? const Center(
                        child: AiTranslatedText('Nenhum exame ou jogo configurado.',
                            style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: allEvalItems.length,
                    itemBuilder: (context, index) {
                      final item = allEvalItems[index];
                      final bool isAiGame = item['type'] == 'ai_game';
                      
                      return Card(
                        color: Colors.white.withValues(alpha: 0.05),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: _buildCategoryBadge(item['type'] as String),
                          title: AiTranslatedText(item['name'] as String,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            'Peso: ${item['weight']}',
                            style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAiGame)
                                IconButton(
                                  icon: const Icon(Icons.analytics, color: Color(0xFF00D1FF)),
                                  onPressed: () {
                                    final gameObj = aiGames.firstWhere((g) => g.id == item['id']);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AiGameRankingScreen(game: gameObj)),
                                    );
                                  },
                                  tooltip: 'Estatísticas Detalhadas',
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white24, size: 20),
                                onPressed: () async {
                                  final service = context.read<FirebaseService>();
                                  final hasResults = await service.hasEvaluationResults(
                                    _currentSubject.id,
                                    gameId: item['id'] as String,
                                  );

                                  if (hasResults) {
                                    if (mounted) _showLockedItemDialog();
                                    return;
                                  }

                                  final confirmed = await _confirmDeletetion(
                                    'Eliminar Jogo/Exame',
                                    'Tem a certeza que quer eliminar este item de avaliação?'
                                  );

                                  if (confirmed == true && mounted) {
                                    if (item['type'] == 'ai_game') {
                                      await service.deleteAiGame(item['id'] as String);
                                    } else {
                                      await service.deleteSubjectContent(
                                          _currentSubject.id, item['id'] as String);
                                    }
                                    setState(() {
                                      _currentSubject.contents
                                          .removeWhere((c) => c.id == item['id']);
                                      _currentSubject.games
                                          .removeWhere((g) => g.id == item['id']);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AiTranslatedText('TOTAL PONDERAÇÃO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(
                      totalWeight.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D1FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentsTab() {
    final service = context.watch<FirebaseService>();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Pesquisar Alunos (Nome ou E-mail)',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Enrollment>>(
              stream: service.getEnrollmentsForSubject(_currentSubject.id),
              builder: (context, enrollmentSnapshot) {
                if (enrollmentSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final enrollments = enrollmentSnapshot.data ?? [];
                // Only consider accepted as enrolled in this view
                final enrolledIds = enrollments
                    .where((e) => e.status == 'accepted')
                    .map((e) => e.userId)
                    .toSet();

                return StreamBuilder<List<UserModel>>(
                  stream: _searchQuery.isEmpty
                      ? service.getUsers() // Fallback to all or just show enrolled? We probably want to limit all users to students.
                      : service.searchUsers(_searchQuery),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = userSnapshot.data ?? [];
                    final students = users
                        .where((u) => u.role == UserRole.student)
                        .toList();

                    if (students.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum aluno encontrado.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        final isEnrolled = enrolledIds.contains(student.id);

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF7B61FF),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: AiTranslatedText(
                            student.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: AiTranslatedText(
                            student.email,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isEnrolled) ...[
                                const AiTranslatedText('Suspenso',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white70)),
                                Checkbox(
                                  value: enrollments.firstWhere((e) => e.userId == student.id && e.status == 'accepted').isSuspended,
                                  onChanged: (bool? value) async {
                                    final enrollment = enrollments.firstWhere((e) => e.userId == student.id && e.status == 'accepted');
                                    await service.toggleEnrollmentSuspension(enrollment.id, value ?? false);
                                  },
                                  activeColor: Colors.red,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Checkbox(
                                value: isEnrolled,
                                onChanged: (bool? value) async {
                                  if (value == true && !isEnrolled) {
                                    await service.enrollStudentDirectly(
                                      student: student,
                                      subject: _currentSubject,
                                    );
                                  } else if (value == false && isEnrolled) {
                                    // Find the enrollment ID to remove or reject it
                                    final enrollmentToRemove = enrollments.firstWhere(
                                          (e) => e.userId == student.id && e.status == 'accepted',
                                    );
                                    await service.rejectEnrollment(enrollmentToRemove.id);
                                  }
                                },
                                activeColor: const Color(0xFF00D1FF),
                                checkColor: const Color(0xFF0F172A),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('video') || type.contains('mp4')) {
      return Icons.play_circle_outline;
    }
    if (type.contains('audio') || type.contains('mp3')) return Icons.audiotrack;
    if (type.contains('jpg') || type.contains('png') || type.contains('image')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

  void _showAddEvaluationDialog({EvaluationComponent? editableComponent}) {
    final nameController = TextEditingController(text: editableComponent?.name ?? '');
    final weightController = TextEditingController(text: ((editableComponent?.weight ?? 0.2) * 100).toStringAsFixed(0));
    final pinController = TextEditingController(text: editableComponent?.pin ?? '');
    
    DateTime? startTime = editableComponent?.startTime;
    DateTime? endTime = editableComponent?.endTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(editableComponent == null ? 'Nova Componente' : 'Editar Componente',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        const InputDecoration(labelText: 'Nome (Ex: Exame, TPC)')),
                TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Peso (%)')),
                TextField(
                    controller: pinController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'PIN de Acesso (Opcional)')),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Data/Hora Início', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  subtitle: Text(startTime != null ? '${startTime!.day}/${startTime!.month}/${startTime!.year} ${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}' : 'Não definido', style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFF00D1FF)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startTime ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(startTime ?? DateTime.now()),
                      );
                      if (time != null) {
                        setDialogState(() {
                          startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
                ListTile(
                  title: const Text('Data/Hora Fim', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  subtitle: Text(endTime != null ? '${endTime!.day}/${endTime!.month}/${endTime!.year} ${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}' : 'Não definido', style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFF00D1FF)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: endTime ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(endTime ?? DateTime.now()),
                      );
                      if (time != null) {
                        setDialogState(() {
                          endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final weight = double.tryParse(weightController.text) ?? 0;
                setState(() {
                  if (editableComponent != null) {
                     final index = _currentSubject.evaluationComponents.indexWhere((c) => c.id == editableComponent.id);
                     if (index != -1) {
                       _currentSubject.evaluationComponents[index] = EvaluationComponent(
                         id: editableComponent.id,
                         name: nameController.text,
                         weight: weight / 100,
                         contentIds: editableComponent.contentIds,
                         pin: pinController.text.trim().isEmpty ? null : pinController.text.trim(),
                         startTime: startTime,
                         endTime: endTime,
                       );
                     }
                  } else {
                    _currentSubject.evaluationComponents.add(EvaluationComponent(
                      id: const Uuid().v4(),
                      name: nameController.text,
                      weight: weight / 100,
                      contentIds: [],
                      pin: pinController.text.trim().isEmpty ? null : pinController.text.trim(),
                      startTime: startTime,
                      endTime: endTime,
                    ));
                  }
                  _updateSubject();
                });
                Navigator.pop(context);
              },
              child: Text(editableComponent == null ? 'Adicionar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGameDialog() {
    final nameController = TextEditingController();
    final weightController = TextEditingController(text: '1.0');
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Adicionar Jogo (URL)',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome do Jogo')),
            TextField(
                controller: urlController,
                decoration:
                    const InputDecoration(labelText: 'URL (Web ou Store)')),
            TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Peso no Ranking')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentSubject.games.add(GameContent(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  url: urlController.text,
                  type: 'general',
                  weight: double.tryParse(weightController.text) ?? 1.0,
                ));
                _updateSubject();
              });
              Navigator.pop(context);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showLinkContentDialog(EvaluationComponent component) {
    // Only show items that contribute to evaluation or games
    final eligibleContents =
        _currentSubject.contents.where((c) => c.category != 'support').toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Vincular a ${component.name}',
              style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<List<AiGame>>(
              stream: context.read<FirebaseService>().getAiGamesBySubject(_currentSubject.id),
              builder: (context, snapshot) {
                final aiGames = snapshot.data ?? [];
                
                if (eligibleContents.isEmpty && _currentSubject.games.isEmpty && aiGames.isEmpty) {
                  return const Text('Não existem itens de avaliação para vincular.',
                      style: TextStyle(color: Colors.white54));
                }

                return ListView(
                  shrinkWrap: true,
                  children: [
                    if (eligibleContents.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Ficheiros (Exames/Jogos)',
                            style: TextStyle(
                                color: Color(0xFF00D1FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      ...eligibleContents.map((content) {
                        final isLinked =
                            component.contentIds.contains(content.id);
                        return CheckboxListTile(
                          title: Text(content.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          value: isLinked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                component.contentIds.add(content.id);
                              } else {
                                component.contentIds.remove(content.id);
                              }
                              _updateSubject();
                            });
                            setDialogState(() {});
                          },
                        );
                      }),
                    ],
                    if (_currentSubject.games.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Jogos (URL)',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      ..._currentSubject.games.map((game) {
                        final isLinked =
                            component.contentIds.contains(game.id);
                        return CheckboxListTile(
                          title: Text(game.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          value: isLinked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                component.contentIds.add(game.id);
                              } else {
                                component.contentIds.remove(game.id);
                              }
                              _updateSubject();
                            });
                            setDialogState(() {});
                          },
                        );
                      }),
                    ],
                    if (aiGames.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Jogos Gerados por IA',
                            style: TextStyle(
                                color: Color(0xFF7B61FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      ...aiGames.map((game) {
                        final isLinked =
                            component.contentIds.contains(game.id);
                        return CheckboxListTile(
                          title: Text(game.title,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                          value: isLinked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                component.contentIds.add(game.id);
                              } else {
                                component.contentIds.remove(game.id);
                              }
                              _updateSubject();
                            });
                            setDialogState(() {});
                          },
                        );
                      }),
                    ],
                  ],
                );
              }
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar')),
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationTab() {
    final service = context.watch<FirebaseService>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 48, color: Color(0xFF00D1FF)),
                const SizedBox(height: 16),
                const AiTranslatedText(
                  'Crie Experiências Imersivas com IA',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const AiTranslatedText(
                  'Transforme os seus ficheiros PDF, vídeos e textos em jogos interativos estilo Kahoot ou desafios de lógica.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiGameCreatorScreen(
                          subject: _currentSubject,
                          initialSelectedContents: _selectedContents,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const AiTranslatedText('Novo Jogo de IA Gamer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AiTranslatedText(
              'Os Meus Jogos Gerados',
              style:
                  TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AiGame>>(
            stream: service.getAiGamesBySubject(_currentSubject.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final games = snapshot.data ?? [];
              if (games.isEmpty) {
                return const Center(
                  child: AiTranslatedText(
                    'Ainda não gerou nenhum jogo com IA.',
                    style: TextStyle(color: Colors.white24),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: games.length,
                itemBuilder: (context, index) {
                  final game = games[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GlassCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: game.isAssessment
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.greenAccent.withValues(alpha: 0.2),
                          child: Icon(
                            game.type == 'kahoot'
                                ? Icons.quiz
                                : Icons.extension,
                            color: game.isAssessment
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                        ),
                        title: AiTranslatedText(game.title,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Row(
                          children: [
                            AiTranslatedText(
                              game.isAssessment ? 'Avaliação' : 'Treino',
                              style: TextStyle(
                                  color: game.isAssessment
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontSize: 11),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${game.questions.length} questões',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AiGameRankingScreen(game: game),
                            ),
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.edit, color: Colors.white24),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AiGameEditorScreen(
                                        subject: _currentSubject, game: game),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white24),
                              onPressed: () => _confirmDeleteAiGame(game.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAiGame(String gameId) async {
    final service = context.read<FirebaseService>();
    final hasResults = await service.hasEvaluationResults(_currentSubject.id, gameId: gameId);

    if (hasResults) {
      if (mounted) _showLockedItemDialog();
      return;
    }

    final confirmed = await _confirmDeletetion(
      'Eliminar Jogo AI',
      'Tem a certeza que quer eliminar este jogo? Todos os dados associados serão removidos.'
    );

    if (confirmed == true && mounted) {
      await service.deleteAiGame(gameId);
    }
  }
}
