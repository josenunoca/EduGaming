import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class TeacherSurveyBuilderScreen extends StatefulWidget {
  final UserModel teacher;
  final InstitutionModel institution;
  final Questionnaire? existingSurvey;

  const TeacherSurveyBuilderScreen({
    super.key,
    required this.teacher,
    required this.institution,
    this.existingSurvey,
  });

  @override
  State<TeacherSurveyBuilderScreen> createState() =>
      _TeacherSurveyBuilderScreenState();
}

class _TeacherSurveyBuilderScreenState
    extends State<TeacherSurveyBuilderScreen> {
  int _step = 0;

  // Step 1 fields
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _isAnonymous = true;
  bool _isSensitive = false;
  List<SurveyAudience> _selectedAudiences = [SurveyAudience.students];

  // Step 2 fields
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 14));

  // Step 3 fields
  final List<Question> _questions = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSurvey != null) {
      final s = widget.existingSurvey!;
      _titleCtrl.text = s.title;
      _descCtrl.text = s.description;
      _selectedSubjectId = s.subjectId;
      _isAnonymous = s.isAnonymous;
      _isSensitive = s.isSensitive;
      _selectedAudiences = List.from(s.audiences);
      if (_selectedAudiences.isEmpty) _selectedAudiences.add(SurveyAudience.students);
      _startDate = s.startDate;
      _endDate = s.endDate;
      _questions.addAll(s.questions);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
          widget.existingSurvey == null
              ? 'Criar Inquérito de Disciplina'
              : 'Editar Inquérito',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStepContent(context),
            ),
          ),

          // Navigation bar
          _buildNavigation(context),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Identificação', 'Período', 'Perguntas'];
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone
                          ? const Color(0xFF7B61FF)
                          : Colors.white12,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF7B61FF)
                            : isDone
                                ? const Color(0xFF7B61FF).withValues(alpha: 0.5)
                                : Colors.white12,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i],
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.white38,
                            fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildStep1(context);
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(BuildContext context) {
    final service = context.read<FirebaseService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Título do Inquérito *'),
        _textField(_titleCtrl, 'Ex: Avaliação da disciplina de Matemática'),
        const SizedBox(height: 16),
        _label('Descrição / Instrução'),
        _textField(_descCtrl,
            'Ex: O seu feedback é anónimo e ajuda a melhorar as aulas.',
            maxLines: 3),
        const SizedBox(height: 16),
        _label('Disciplina Associada'),
        StreamBuilder<List<Subject>>(
          stream: service.getSubjectsByTeacher(widget.teacher.id),
          builder: (ctx, snap) {
            final subjects = snap.data ?? [];
            return DropdownButtonFormField<String>(
              value: _selectedSubjectId,
              decoration: _inputDeco('Selecionar disciplina (opcional)'),
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Nenhuma —')),
                ...subjects.map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.name))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedSubjectId = v;
                  _selectedSubjectName =
                      subjects.firstWhere((s) => s.id == v, orElse: () => subjects.first).name;
                });
              },
            );
          },
        ),
        const SizedBox(height: 20),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SwitchListTile(
                  dense: true,
                  activeColor: const Color(0xFF7B61FF),
                  title: const AiTranslatedText('Respostas Anónimas',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const AiTranslatedText(
                      'Os alunos não serão identificados',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),
                SwitchListTile(
                  dense: true,
                  activeColor: const Color(0xFF7B61FF),
                  title: const AiTranslatedText('Inquérito Sensível',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const AiTranslatedText(
                      'Resultados apenas visíveis para si',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: _isSensitive,
                  onChanged: (v) => setState(() => _isSensitive = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final fmt = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Data de Início *'),
        _datePicker(
          label: 'Início: ${fmt.format(_startDate)}',
          icon: Icons.calendar_today,
          onPick: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _startDate = d);
          },
        ),
        const SizedBox(height: 12),
        _label('Data de Encerramento *'),
        _datePicker(
          label: 'Encerramento: ${fmt.format(_endDate)}',
          icon: Icons.event_busy,
          onPick: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _endDate,
              firstDate: _startDate,
              lastDate: _startDate.add(const Duration(days: 180)),
            );
            if (d != null) setState(() => _endDate = d);
          },
        ),
        const SizedBox(height: 20),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.people, size: 16, color: Color(0xFF7B61FF)),
                  SizedBox(width: 8),
                  AiTranslatedText('Públicos-Alvo',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SurveyAudience.values.map((audience) {
                    final isSelected = _selectedAudiences.contains(audience);
                    return FilterChip(
                      selected: isSelected,
                      label: AiTranslatedText(audience.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          )),
                      selectedColor: const Color(0xFF7B61FF).withValues(alpha: 0.8),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      checkmarkColor: Colors.white,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedAudiences.add(audience);
                          } else if (_selectedAudiences.length > 1) {
                            _selectedAudiences.remove(audience);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (_selectedAudiences.contains(SurveyAudience.students)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF00BFA5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AiTranslatedText(
                          _selectedSubjectId != null
                              ? 'Alunos inscritos em "$_selectedSubjectName"'
                              : 'Todos os alunos da instituição',
                          style: const TextStyle(
                              color: Color(0xFF00BFA5), fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF00D1FF)),
                  SizedBox(width: 8),
                  AiTranslatedText('Visibilidade dos Resultados',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
                const SizedBox(height: 8),
                const AiTranslatedText(
                  'Os resultados são visíveis apenas para si e para a direção da instituição.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick templates
        _label('Perguntas Rápidas (Modelos)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _templateChip('Satisfação Geral (Likert)',
                () => _addLikert('Como avalia a qualidade das aulas?')),
            _templateChip('Metodologia (Likert)',
                () => _addLikert('As metodologias de ensino são adequadas?')),
            _templateChip('Dificuldade (Likert)',
                () => _addLikert('Considera os conteúdos adequados ao nível?')),
            _templateChip('Sugestão (Texto Aberto)',
                () => _addOpenText('O que poderia ser melhorado?')),
            _templateChip('Ponto Forte (Texto Aberto)',
                () => _addOpenText('O que mais aprecia nesta disciplina?')),
          ],
        ),
        const SizedBox(height: 20),

        // Custom question
        _label('Adicionar Pergunta Personalizada'),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                  side: const BorderSide(color: Color(0xFF7B61FF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddQuestionDialog(QuestionType.likertScale),
                icon: const Icon(Icons.tune, color: Color(0xFF7B61FF), size: 16),
                label: const AiTranslatedText('Likert',
                    style: TextStyle(
                        color: Color(0xFF7B61FF), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                  side: const BorderSide(color: Color(0xFF00BFA5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showAddQuestionDialog(QuestionType.openText),
                icon: const Icon(Icons.text_fields, color: Color(0xFF00BFA5), size: 16),
                label: const AiTranslatedText('Texto Livre',
                    style: TextStyle(
                        color: Color(0xFF00BFA5), fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () =>
                    _showAddQuestionDialog(QuestionType.singleChoice),
                icon: const Icon(Icons.radio_button_checked,
                    color: Colors.amber, size: 16),
                label: const AiTranslatedText('Escolha',
                    style: TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Current questions list
        if (_questions.isEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(children: [
                  const Icon(Icons.quiz_outlined, size: 40, color: Colors.white24),
                  const SizedBox(height: 8),
                  const AiTranslatedText(
                    'Use os modelos acima ou adicione perguntas personalizadas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ]),
              ),
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final q = _questions.removeAt(oldIndex);
                _questions.insert(newIndex, q);
              });
            },
            children: _questions.asMap().entries.map((entry) {
              final i = entry.key;
              final q = entry.value;
              return Padding(
                key: ValueKey(q.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Text('${i + 1}.',
                            style: const TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.text,
                                  style:
                                      const TextStyle(color: Colors.white, fontSize: 13)),
                              Text(_typeLabel(q.type),
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          onPressed: () => setState(() => _questions.removeAt(i)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle,
                            size: 16, color: Colors.white24),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _typeLabel(QuestionType type) {
    switch (type) {
      case QuestionType.likertScale:
        return 'Escala Likert';
      case QuestionType.openText:
      case QuestionType.text:
        return 'Texto Livre';
      case QuestionType.singleChoice:
      case QuestionType.selection:
        return 'Escolha Única';
      case QuestionType.multipleChoice:
        return 'Escolha Múltipla';
      case QuestionType.audio:
        return 'Resposta Áudio';
      case QuestionType.video:
        return 'Resposta Vídeo';
    }
  }

  void _addLikert(String text) {
    setState(() => _questions.add(Question(
          id: const Uuid().v4(),
          text: text,
          type: QuestionType.likertScale,
          isRequired: true,
          likertMin: 1,
          likertMax: 5,
          likertMinLabel: 'Discordo totalmente',
          likertMaxLabel: 'Concordo totalmente',
        )));
  }

  void _addOpenText(String text) {
    setState(() => _questions.add(Question(
          id: const Uuid().v4(),
          text: text,
          type: QuestionType.openText,
          isRequired: false,
        )));
  }

  Widget _templateChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF1E293B),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      label: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11)),
      onPressed: onTap,
    );
  }

  void _showAddQuestionDialog(QuestionType type) {
    final ctrl = TextEditingController();
    final List<String> options = ['Sim', 'Não'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
          type == QuestionType.likertScale
              ? 'Nova Pergunta Likert'
              : type == QuestionType.openText
                  ? 'Nova Pergunta de Texto'
                  : 'Nova Pergunta de Escolha',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('Texto da pergunta'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AiTranslatedText('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF)),
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              if (type == QuestionType.likertScale) {
                _addLikert(text);
              } else if (type == QuestionType.openText) {
                _addOpenText(text);
              } else {
                setState(() => _questions.add(Question(
                      id: const Uuid().v4(),
                      text: text,
                      type: QuestionType.singleChoice,
                      options: options,
                      isRequired: true,
                    )));
              }
            },
            child: const AiTranslatedText('Adicionar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final isLast = _step == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => setState(() => _step--),
                child: const AiTranslatedText('Anterior'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? const Color(0xFF00C853)
                    : const Color(0xFF7B61FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _canAdvance() ? () => _handleNext(context) : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : AiTranslatedText(
                      isLast ? 'Publicar Inquérito' : 'Seguinte',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Save draft
          IconButton(
            tooltip: 'Guardar rascunho',
            icon: const Icon(Icons.save_outlined, color: Colors.white54),
            onPressed: () => _save(context, publish: false),
          ),
        ],
      ),
    );
  }

  bool _canAdvance() {
    if (_step == 0) return _titleCtrl.text.trim().isNotEmpty;
    if (_step == 1) return _endDate.isAfter(_startDate);
    return _questions.isNotEmpty;
  }

  Future<void> _handleNext(BuildContext context) async {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      await _save(context, publish: true);
    }
  }

  Future<void> _save(BuildContext context, {required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              AiTranslatedText('Por favor, insira um título para o inquérito.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final service = context.read<FirebaseService>();
      final surveyId = widget.existingSurvey?.id ?? const Uuid().v4();

      final survey = Questionnaire(
        id: surveyId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        creatorId: widget.teacher.id,
        creatorRole: 'teacher',
        subjectId: _selectedSubjectId,
        institutionId: widget.institution.id,
        status: publish ? SurveyStatus.active : SurveyStatus.draft,
        visibility: SurveyVisibility.directionOnly,
        audiences: _selectedAudiences,
        objectives: [SurveyObjective.satisfactionClients],
        startDate: _startDate,
        endDate: _endDate,
        isSensitive: _isSensitive,
        isAnonymous: _isAnonymous,
        questions: _questions,
        linkedToAnnualReport: false,
        isReportLocked: false,
      );

      await service.saveSurvey(survey);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AiTranslatedText(publish
              ? 'Inquérito publicado!'
              : 'Rascunho guardado!'),
          backgroundColor:
              publish ? const Color(0xFF00C853) : const Color(0xFF7B61FF),
        ));
        if (publish) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AiTranslatedText('Erro: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Helpers
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );

  Widget _textField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        onChanged: (_) => setState(() {}),
        decoration: _inputDeco(hint),
      );

  Widget _datePicker(
      {required String label,
      required IconData icon,
      required VoidCallback onPick}) =>
      InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF7B61FF), size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7B61FF)),
        ),
      );
}
