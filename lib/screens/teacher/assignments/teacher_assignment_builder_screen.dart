import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../models/assignment_model.dart';
import '../../../models/subject_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_service.dart';

class TeacherAssignmentBuilderScreen extends StatefulWidget {
  final String institutionId;
  final Subject subject;
  final UserModel teacher;
  final Assignment? existingAssignment;

  const TeacherAssignmentBuilderScreen({
    super.key,
    required this.institutionId,
    required this.subject,
    required this.teacher,
    this.existingAssignment,
  });

  @override
  State<TeacherAssignmentBuilderScreen> createState() => _TeacherAssignmentBuilderScreenState();
}

class _TeacherAssignmentBuilderScreenState extends State<TeacherAssignmentBuilderScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _effortCtrl;

  late DateTime _startDate;
  late DateTime _dueDate;

  bool _allowLate = false;
  bool _isVisibleToStudents = true;
  bool _autoPlagiarism = true;
  bool _addRepo = false;
  bool _allowGroup = false;

  AssignmentType _type = AssignmentType.treino;
  String? _linkedEvaluation;

  final List<String> _localAttachments = []; // Placeholder for file paths during build

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAssignment;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _descCtrl = TextEditingController(text: a?.description ?? '');
    _effortCtrl = TextEditingController(text: (a?.effortHours ?? 2).toString());

    _startDate = a?.startDate ?? DateTime.now();
    _dueDate = a?.dueDate ?? DateTime.now().add(const Duration(days: 7));

    _allowLate = a?.allowLateSubmissions ?? false;
    _isVisibleToStudents = a?.isVisibleToStudents ?? true;
    _autoPlagiarism = a?.autoPlagiarismDetection ?? true;
    _addRepo = a?.addToPlagiarismRepo ?? false;
    _allowGroup = a?.allowGroupSubmissions ?? false;
    _type = a?.type ?? AssignmentType.treino;
    _linkedEvaluation = a?.linkedEvaluationComponentId;
    
    if (a != null) _localAttachments.addAll(a.attachmentsUrls);
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startDate : _dueDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (time != null) {
        setState(() {
          final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isStart) {
            _startDate = dt;
            if (_dueDate.isBefore(_startDate)) _dueDate = _startDate.add(const Duration(days: 1));
          } else {
            _dueDate = dt;
          }
        });
      }
    }
  }

  Future<void> _pickAttachment() async {
    // Uses file_picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      setState(() {
        _localAttachments.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final assignment = Assignment(
        id: widget.existingAssignment?.id ?? const Uuid().v4(),
        subjectId: widget.subject.id,
        teacherId: widget.teacher.id,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        type: _type,
        linkedEvaluationComponentId: _linkedEvaluation,
        createdAt: widget.existingAssignment?.createdAt ?? DateTime.now(),
        startDate: _startDate,
        dueDate: _dueDate,
        allowLateSubmissions: _allowLate,
        effortHours: int.tryParse(_effortCtrl.text) ?? 2,
        attachmentsUrls: _localAttachments, // In complete build this uploads to Firebase Storage
        isVisibleToStudents: _isVisibleToStudents,
        autoPlagiarismDetection: _autoPlagiarism,
        addToPlagiarismRepo: _addRepo,
        allowGroupSubmissions: _allowGroup,
        submissions: widget.existingAssignment?.submissions ?? [],
      );

      final fb = context.read<FirebaseService>();
      if (widget.existingAssignment == null) {
        await fb.createAssignment(widget.institutionId, assignment);
      } else {
        await fb.updateAssignment(widget.institutionId, assignment);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trabalho guardado com sucesso!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFieldRow(String label, Widget input) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
          ),
          const SizedBox(width: 16),
          Expanded(child: input),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Detalhes da Submissão'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: CircularProgressIndicator(color: Colors.white)))
          else
            TextButton.icon(
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Guardar', style: TextStyle(color: Colors.white)),
              onPressed: _save,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldRow(
                  'Nome:',
                  TextFormField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  ),
                ),
                _buildFieldRow(
                  'Data de Criação:',
                  Text(DateFormat('dd-MM-yyyy').format(widget.existingAssignment?.createdAt ?? DateTime.now()), style: const TextStyle(color: Colors.white70)),
                ),
                _buildFieldRow(
                  'Data de Início:',
                  InkWell(
                    onTap: () => _pickDateTime(true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: Text(dateFormat.format(_startDate), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                _buildFieldRow(
                  'Data Limite:',
                  InkWell(
                    onTap: () => _pickDateTime(false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                      child: Text(dateFormat.format(_dueDate), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
                _buildFieldRow(
                  'Tipologia:',
                  DropdownButtonFormField<AssignmentType>(
                    value: _type,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: AssignmentType.treino, child: Text('Treino (Não acumula nota)')),
                      DropdownMenuItem(value: AssignmentType.avaliacao, child: Text('Avaliação (Integra Pauta)')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _type = v!;
                        if (_type == AssignmentType.treino) _linkedEvaluation = null;
                      });
                    },
                  ),
                ),
                if (_type == AssignmentType.avaliacao && widget.subject.evaluationComponents.isNotEmpty)
                  _buildFieldRow(
                    'Componente de Avaliação:',
                    DropdownButtonFormField<String>(
                      value: _linkedEvaluation,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Selecionar Componente...')),
                        ...widget.subject.evaluationComponents.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _linkedEvaluation = v),
                    ),
                  ),
                _buildFieldRow(
                  'Entregas após Data Limite:',
                  Switch(
                    value: _allowLate,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) => setState(() => _allowLate = v),
                  ),
                ),
                _buildFieldRow(
                  'Esforço Aluno (horas):',
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _effortCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        isDense: true,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
                _buildFieldRow(
                  'Anexo:',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Carregar Anexos'),
                        onPressed: _pickAttachment,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E8B57)),
                      ),
                      if (_localAttachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${_localAttachments.length} ficheiros anexados.', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        )
                    ],
                  ),
                ),
                _buildFieldRow(
                  'Descrição:',
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                _buildFieldRow(
                  'Visível aos Alunos:',
                  Switch(
                    value: _isVisibleToStudents,
                    activeColor: Colors.blueAccent,
                    onChanged: (v) => setState(() => _isVisibleToStudents = v),
                  ),
                ),
                const Divider(color: Colors.white24, height: 48),
                _buildFieldRow(
                  'Mecanismo Automático de Deteção de Plágio:',
                  ElevatedButton(
                    onPressed: () => setState(() => _autoPlagiarism = !_autoPlagiarism),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _autoPlagiarism ? const Color(0xFF2E8B57) : Colors.grey,
                    ),
                    child: Text(_autoPlagiarism ? 'Ativo' : 'Inativo', style: const TextStyle(color: Colors.white)),
                  ),
                ),
                if (_autoPlagiarism)
                  _buildFieldRow(
                    'Adicionar envios ao repositório:',
                    Switch(
                      value: _addRepo,
                      activeColor: Colors.orangeAccent,
                      onChanged: (v) => setState(() => _addRepo = v),
                    ),
                  ),
                _buildFieldRow(
                  'Permitir Entregas em Grupo:',
                  Switch(
                    value: _allowGroup,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) => setState(() => _allowGroup = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
