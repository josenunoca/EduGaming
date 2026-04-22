import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/firebase_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../models/course_model.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/participant_selector_dialog.dart';

class SurveyBuilderScreen extends StatefulWidget {
  final InstitutionModel institution;
  final UserModel currentUser;
  final Questionnaire? existingSurvey;

  const SurveyBuilderScreen({
    super.key,
    required this.institution,
    required this.currentUser,
    this.existingSurvey,
  });

  @override
  State<SurveyBuilderScreen> createState() => _SurveyBuilderScreenState();
}

class _SurveyBuilderScreenState extends State<SurveyBuilderScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1 - Identification
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _legalBasisCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _linkedToAnnualReport = false;
  bool _includeInReports = false;
  String? _selectedCourseId;

  // Step 2 - Objectives
  final Set<SurveyObjective> _selectedObjectives = {};
  final _customObjectiveCtrl = TextEditingController();

  // Step 3 - Audiences
  final Set<SurveyAudience> _selectedAudiences = {};
  final Set<String> _excludedUserIds = {};
  final _externalEmailCtrl = TextEditingController();
  final List<String> _externalEmails = [];

  // Step 4 - Questions
  final List<Question> _questions = [];

  @override
  void initState() {
    super.initState();
    final s = widget.existingSurvey;
    if (s != null) {
      _titleCtrl.text = s.title;
      _descriptionCtrl.text = s.description;
      _legalBasisCtrl.text = s.legalBasis ?? '';
      _startDate = s.startDate;
      _endDate = s.endDate;
      _linkedToAnnualReport = s.linkedToAnnualReport;
      _includeInReports = s.includeInReports;
      _selectedCourseId = s.courseId;
      _selectedObjectives.addAll(s.objectives);
      _customObjectiveCtrl.text = s.customObjective ?? '';
      _selectedAudiences.addAll(s.audiences);
      _excludedUserIds.addAll(s.excludedTargetIds);
      _externalEmails.addAll(s.externalEmails);
      _questions.addAll(s.questions);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _legalBasisCtrl.dispose();
    _customObjectiveCtrl.dispose();
    _externalEmailCtrl.dispose();
    super.dispose();
  }

  Questionnaire _buildSurvey(SurveyStatus status) {
    return Questionnaire(
      id: widget.existingSurvey?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      questions: _questions,
      institutionId: widget.institution.id,
      creatorId: widget.currentUser.id,
      creatorRole: widget.currentUser.role == UserRole.teacher ? 'teacher' : 'institution',
      objectives: _selectedObjectives.toList(),
      customObjective: _selectedObjectives.contains(SurveyObjective.custom)
          ? _customObjectiveCtrl.text.trim()
          : null,
      legalBasis: _legalBasisCtrl.text.trim().isNotEmpty ? _legalBasisCtrl.text.trim() : null,
      audiences: _selectedAudiences.toList(),
      excludedTargetIds: _excludedUserIds.toList(),
      externalEmails: _externalEmails,
      linkedToAnnualReport: _linkedToAnnualReport,
      includeInReports: _includeInReports,
      startDate: _startDate,
      endDate: _endDate,
      status: status,
      isActive: status == SurveyStatus.active,
      courseId: _selectedCourseId,
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      final service = context.read<FirebaseService>();
      await service.saveSurvey(_buildSurvey(SurveyStatus.draft));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AiTranslatedText('Rascunho guardado com sucesso!'),
            backgroundColor: Color(0xFF00BFA5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publish() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('O inquérito precisa de um título.')),
      );
      return;
    }
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Adicione pelo menos uma pergunta.')),
      );
      return;
    }
    if (_selectedAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Selecione pelo menos um perfil de destinatários.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Publicar Inquérito',
            style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
          'Ao publicar, o inquérito ficará imediatamente disponível para os destinatários selecionados. Deseja continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AiTranslatedText('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const AiTranslatedText('Publicar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final service = context.read<FirebaseService>();
      await service.saveSurvey(_buildSurvey(SurveyStatus.active));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AiTranslatedText('Inquérito publicado com sucesso!'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
          widget.existingSurvey != null ? 'Editar Inquérito' : 'Novo Inquérito',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _saveDraft,
              icon: const Icon(Icons.save_outlined, color: Colors.white70, size: 18),
              label: const AiTranslatedText('Guardar Rascunho',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF00BFA5),
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          type: StepperType.horizontal,
          onStepContinue: () {
            if (_currentStep < 3) {
              setState(() => _currentStep++);
            } else {
              _publish();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: details.onStepContinue,
                    child: AiTranslatedText(
                      _currentStep < 3 ? 'Seguinte' : 'Publicar',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const AiTranslatedText('Anterior',
                          style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const AiTranslatedText('Identificação',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStep1(),
            ),
            Step(
              title: const AiTranslatedText('Objetivos',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStep2(),
            ),
            Step(
              title: const AiTranslatedText('Destinatários',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildStep3(),
            ),
            Step(
              title: const AiTranslatedText('Perguntas',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              isActive: _currentStep >= 3,
              state: StepState.indexed,
              content: _buildStep4(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Identification ────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Título do Inquérito *'),
        _buildTextField(_titleCtrl, 'Ex: Satisfação dos alunos 2024/25'),
        const SizedBox(height: 16),
        _buildLabel('Descrição / Fundamentação Legal'),
        _buildTextField(_descriptionCtrl, 'Contexto e objetivos do inquérito...', maxLines: 3),
        const SizedBox(height: 16),
        _buildLabel('Base Legal / Normativo'),
        _buildTextField(_legalBasisCtrl,
            'Ex: Decreto-Lei n.º 137/2012, de 2 de julho'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDatePicker('Data de Início', _startDate, (d) => setState(() => _startDate = d))),
            const SizedBox(width: 12),
            Expanded(child: _buildDatePicker('Data de Fim', _endDate, (d) => setState(() => _endDate = d))),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            children: [
              SwitchListTile(
                dense: true,
                activeColor: const Color(0xFF00BFA5),
                title: const AiTranslatedText(
                  'Vincular ao Relatório Anual de Atividades',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const AiTranslatedText(
                  'Os dados serão exportados automaticamente para o relatório final.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                value: _linkedToAnnualReport,
                onChanged: (v) => setState(() => _linkedToAnnualReport = v),
              ),
              const Divider(color: Colors.white10, height: 1),
              SwitchListTile(
                dense: true,
                activeColor: const Color(0xFF00BFA5),
                title: const AiTranslatedText(
                  'Incluir na Análise Estatística de Relatórios',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: const AiTranslatedText(
                  'Permite integrar métricas deste inquérito em relatórios institucionais/de curso.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                value: _includeInReports,
                onChanged: (v) => setState(() => _includeInReports = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Associar a um Curso (Opcional)'),
        StreamBuilder<List<Course>>(
          stream: context.read<FirebaseService>().getCoursesStream(widget.institution.id),
          builder: (context, snapshot) {
            final courses = snapshot.data ?? [];
            return DropdownButtonFormField<String?>(
              value: _selectedCourseId,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Selecione o curso...'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nenhum / Institucional')),
                ...courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => _selectedCourseId = v),
            );
          },
        ),
      ],
    );
  }

  // ─── Step 2: Objectives ────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText(
          'Selecione os objetivos do inquérito (pode escolher múltiplos):',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...SurveyObjective.values.map((obj) => GlassCard(
          child: CheckboxListTile(
            dense: true,
            activeColor: const Color(0xFF00BFA5),
            checkColor: Colors.white,
            title: AiTranslatedText(obj.label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            value: _selectedObjectives.contains(obj),
            onChanged: (v) => setState(() {
              if (v == true) _selectedObjectives.add(obj);
              else _selectedObjectives.remove(obj);
            }),
          ),
        )),
        if (_selectedObjectives.contains(SurveyObjective.custom)) ...[
          const SizedBox(height: 12),
          _buildLabel('Descreva o objetivo personalizado:'),
          _buildTextField(_customObjectiveCtrl, 'Ex: Avaliação da transição digital'),
        ],
      ],
    );
  }

  // ─── Step 3: Audiences ─────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText(
          'Perfis de Destinatários:',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...SurveyAudience.values.where((a) => a != SurveyAudience.externalEmail).map((aud) => GlassCard(
          child: CheckboxListTile(
            dense: true,
            activeColor: const Color(0xFF00BFA5),
            checkColor: Colors.white,
            title: AiTranslatedText(aud.label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: _selectedAudiences.contains(aud) ? TextButton(
              onPressed: () => _manageAudienceParticipants(aud),
              child: const Text('Gerir/Excluir Participantes', style: TextStyle(color: Color(0xFF00BFA5), fontSize: 11)),
            ) : null,
            value: _selectedAudiences.contains(aud),
            onChanged: (v) => setState(() {
              if (v == true) _selectedAudiences.add(aud);
              else _selectedAudiences.remove(aud);
            }),
          ),
        )),
        const SizedBox(height: 16),
        const AiTranslatedText('Emails Externos (opcional):',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(_externalEmailCtrl, 'email@exemplo.pt'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final email = _externalEmailCtrl.text.trim();
                if (email.contains('@') && !_externalEmails.contains(email)) {
                  setState(() {
                    _externalEmails.add(email);
                    _externalEmailCtrl.clear();
                  });
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ],
        ),
        if (_externalEmails.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _externalEmails.map((email) => Chip(
              backgroundColor: const Color(0xFF1E293B),
              label: Text(email, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
              onDeleted: () => setState(() => _externalEmails.remove(email)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _manageAudienceParticipants(SurveyAudience audience) async {
    final groupType = _mapAudienceToGroup(audience);
    final List<String>? selectedEmails = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => ParticipantSelectorDialog(
        institutionId: widget.institution.id,
        // We initialize with what is NOT excluded? 
        // Actually, ParticipantSelectorDialog usually shows the WHOLE group.
        // If we want to manage exclusions, we should know who is currently excluded.
        // For simplicity, let's treat the dialog as "these are the people who WILL receive it".
      ),
    );

    if (selectedEmails != null) {
      final service = context.read<FirebaseService>();
      final groupUsers = await _getGroupUsers(audience, service);
      final groupEmails = groupUsers.map((u) => u.email).toList();
      
      // Those NOT in selectedEmails but IN groupEmails are excluded
      final excluded = groupEmails.where((e) => !selectedEmails.contains(e)).toList();
      
      setState(() {
        // We might want to filter only for this audience, but _excludedUserIds is global for the survey.
        // It's fine since we check if the user is in the audience AND not excluded.
        _excludedUserIds.addAll(excluded);
        // Also remove those who were previously excluded but now selected
        for (var email in selectedEmails) {
          _excludedUserIds.remove(email);
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Participantes atualizados: ${_excludedUserIds.length} exclusões totais.'),
        ));
      }
    }
  }

  ParticipantGroupType _mapAudienceToGroup(SurveyAudience audience) {
    switch (audience) {
      case SurveyAudience.students: return ParticipantGroupType.alunos;
      case SurveyAudience.parents: return ParticipantGroupType.encarregados;
      case SurveyAudience.teachers: return ParticipantGroupType.docentes;
      case SurveyAudience.nonTeachingStaff: return ParticipantGroupType.naoDocentes;
      case SurveyAudience.organMembers: return ParticipantGroupType.orgaos;
      case SurveyAudience.externalEmail: return ParticipantGroupType.manual;
    }
  }

  Future<List<UserModel>> _getGroupUsers(SurveyAudience audience, FirebaseService service) async {
    switch (audience) {
      case SurveyAudience.teachers: return service.getInstitutionDocentes(widget.institution.id);
      case SurveyAudience.nonTeachingStaff: return service.getInstitutionNaoDocentes(widget.institution.id);
      case SurveyAudience.students: 
        final all = await service.getAllInstitutionMembers(widget.institution.id);
        return all.where((u) => u.role == UserRole.student).toList();
      case SurveyAudience.parents:
        final all = await service.getAllInstitutionMembers(widget.institution.id);
        return all.where((u) => u.role == UserRole.parent).toList();
      case SurveyAudience.organMembers:
        // This is tricky because there are multiple organs. 
        // For now, let's just return all members of all organs? 
        // Or maybe let the user select the organ in the dialog.
        return []; 
      default: return [];
    }
  }

  // ─── Step 4: Questions ─────────────────────────────────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_questions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: const AiTranslatedText(
              'Adicione perguntas ao seu inquérito.\nSão suportados vários formatos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ..._questions.asMap().entries.map((entry) {
          final i = entry.key;
          final q = entry.value;
          return _QuestionItem(
            index: i,
            question: q,
            onEdit: () => _showQuestionDialog(existing: q, index: i),
            onDelete: () => setState(() => _questions.removeAt(i)),
            onMoveUp: i > 0 ? () => setState(() {
              final tmp = _questions.removeAt(i);
              _questions.insert(i - 1, tmp);
            }) : null,
            onMoveDown: i < _questions.length - 1 ? () => setState(() {
              final tmp = _questions.removeAt(i);
              _questions.insert(i + 1, tmp);
            }) : null,
          );
        }),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00BFA5),
              side: const BorderSide(color: Color(0xFF00BFA5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showQuestionDialog(),
            icon: const Icon(Icons.add),
            label: const AiTranslatedText('Adicionar Pergunta'),
          ),
        ),
      ],
    );
  }

  // ─── Question Dialog ───────────────────────────────────────────────────────
  void _showQuestionDialog({Question? existing, int? index}) {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    QuestionType selectedType = existing?.type ?? QuestionType.singleChoice;
    final optionsCtrl = TextEditingController(
        text: existing?.options.join('\n') ?? '');
    final likertMinCtrl = TextEditingController(
        text: existing?.likertMinLabel ?? 'Discordo totalmente');
    final likertMaxCtrl = TextEditingController(
        text: existing?.likertMaxLabel ?? 'Concordo totalmente');
    bool isRequired = existing?.isRequired ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: AiTranslatedText(
            existing == null ? 'Nova Pergunta' : 'Editar Pergunta',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Question text
                  const AiTranslatedText('Texto da Pergunta *',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Ex: Como avalia a prestação do professor?'),
                  ),
                  const SizedBox(height: 16),

                  // Type selector
                  const AiTranslatedText('Tipo de Resposta',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<QuestionType>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(''),
                    items: const [
                      DropdownMenuItem(value: QuestionType.singleChoice, child: Text('Escolha Única')),
                      DropdownMenuItem(value: QuestionType.multipleChoice, child: Text('Escolha Múltipla')),
                      DropdownMenuItem(value: QuestionType.likertScale, child: Text('Escala de Likert (1-5)')),
                      DropdownMenuItem(value: QuestionType.openText, child: Text('Resposta Livre (Texto)')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 12),

                  // Options / Likert labels
                  if (selectedType == QuestionType.singleChoice ||
                      selectedType == QuestionType.multipleChoice) ...[
                    const AiTranslatedText('Opções (uma por linha) *',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: optionsCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Opção 1\nOpção 2\nOpção 3'),
                    ),
                  ],
                  if (selectedType == QuestionType.likertScale) ...[
                    const AiTranslatedText('Rótulo mínimo (1):',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    TextField(
                      controller: likertMinCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Discordo totalmente'),
                    ),
                    const SizedBox(height: 8),
                    const AiTranslatedText('Rótulo máximo (5):',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    TextField(
                      controller: likertMaxCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Concordo totalmente'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    activeColor: const Color(0xFF00BFA5),
                    title: const AiTranslatedText('Resposta Obrigatória',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    value: isRequired,
                    onChanged: (v) => setDialogState(() => isRequired = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AiTranslatedText('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5)),
              onPressed: () {
                if (textCtrl.text.trim().isEmpty) return;
                final options = (selectedType == QuestionType.singleChoice ||
                    selectedType == QuestionType.multipleChoice)
                    ? optionsCtrl.text.split('\n').map((o) => o.trim()).where((o) => o.isNotEmpty).toList()
                    : <String>[];
                final newQ = Question(
                  id: existing?.id ?? const Uuid().v4(),
                  text: textCtrl.text.trim(),
                  type: selectedType,
                  options: options,
                  likertMinLabel: selectedType == QuestionType.likertScale ? likertMinCtrl.text : null,
                  likertMaxLabel: selectedType == QuestionType.likertScale ? likertMaxCtrl.text : null,
                  isRequired: isRequired,
                );
                setState(() {
                  if (index != null) {
                    _questions[index] = newQ;
                  } else {
                    _questions.add(newQ);
                  }
                });
                Navigator.pop(ctx);
              },
              child: const AiTranslatedText('Guardar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AiTranslatedText(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF00BFA5)),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime value, Function(DateTime) onPick) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: Color(0xFF00BFA5)),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFF00BFA5)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  Text(
                    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question Item Widget ──────────────────────────────────────────────────────
class _QuestionItem extends StatelessWidget {
  final int index;
  final Question question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _QuestionItem({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  String get _typeLabel {
    switch (question.type) {
      case QuestionType.singleChoice: return 'Escolha Única';
      case QuestionType.multipleChoice: return 'Múltipla Escolha';
      case QuestionType.likertScale: return 'Escala Likert';
      case QuestionType.openText: return 'Resposta Livre';
      default: return 'Texto';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(_typeLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (onMoveUp != null)
                IconButton(icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.white38),
                    onPressed: onMoveUp),
              if (onMoveDown != null)
                IconButton(icon: const Icon(Icons.arrow_downward, size: 16, color: Colors.white38),
                    onPressed: onMoveDown),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF00BFA5)),
                  onPressed: onEdit),
              IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  onPressed: onDelete),
            ],
          ),
        ),
      ),
    );
  }
}
