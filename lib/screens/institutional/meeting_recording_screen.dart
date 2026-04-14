import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doc_text_extractor/doc_text_extractor.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/institution_organ_model.dart';
import '../../services/institutional_service.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_chat_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/ai_translated_text.dart';

class MeetingRecordingScreen extends StatefulWidget {
  final Meeting meeting;
  final bool canManage;

  const MeetingRecordingScreen({super.key, required this.meeting, this.canManage = false});

  @override
  State<MeetingRecordingScreen> createState() => _MeetingRecordingScreenState();
}

class _MeetingRecordingScreenState extends State<MeetingRecordingScreen> {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _timer;
  int _recordDuration = 0;
  bool _isUploading = false;
  bool _isGenerating = false;
  late TextEditingController _minutesController;
  late TextEditingController _transcriptController;
  late TextEditingController _agendaController;
  late TextEditingController _locationController;
  late TextEditingController _invitationController;
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  List<String> _contextFileUrls = [];
  String? _contextText;
  bool _isUploadingDoc = false;
  bool _isDragging = false;
  List<Participant> _participants = [];
  bool _isGeneratingInvitation = false;
  bool _isDictatingAgenda = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _minutesController = TextEditingController(text: widget.meeting.minutes);
    _transcriptController = TextEditingController(text: widget.meeting.transcript);
    _agendaController = TextEditingController(text: widget.meeting.agenda);
    _locationController = TextEditingController(text: widget.meeting.location ?? 'Rua da Empresa, 123, Sala de Reuniões');
    _invitationController = TextEditingController(text: widget.meeting.invitationText);
    _startDate = widget.meeting.date;
    if (widget.meeting.startTime != null) {
      _startTime = TimeOfDay.fromDateTime(widget.meeting.startTime!);
    }
    if (widget.meeting.endTime != null) {
      _endTime = TimeOfDay.fromDateTime(widget.meeting.endTime!);
    }
    _contextFileUrls = List.from(widget.meeting.contextFileUrls);
    _contextText = widget.meeting.contextText;
    _participants = List.from(widget.meeting.participants);
    
    // Auto-mark presence if the current user is a participant
    _autoMarkPresence();
  }

  void _autoMarkPresence() {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.currentUser;
    if (user != null) {
      final index = _participants.indexWhere((p) => p.email == user.email);
      if (index != -1 && _participants[index].status == 'invited') {
        _updateParticipantStatus(user.email!, 'attended_auto');
      }
    }
  }

  Future<void> _updateParticipantStatus(String email, String status) async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    await instService.updateParticipantStatus(widget.meeting.id, email, status);
    setState(() {
      final index = _participants.indexWhere((p) => p.email == email);
      if (index != -1) {
        _participants[index] = Participant(
          name: _participants[index].name,
          email: _participants[index].email,
          status: status,
          isGuest: _participants[index].isGuest,
        );
      }
    });
  }

  Future<void> _helpWithAgenda() async {
    if (_agendaController.text.isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final aiChatService = Provider.of<AiChatService>(context, listen: false);
      final improved = await aiChatService.refineMeetingAgenda(_agendaController.text);
      setState(() {
        _agendaController.text = improved;
        _isGenerating = false;
      });
      _saveMeetingDetails();
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _toggleAgendaDictation() async {
    if (_isDictatingAgenda) {
      final path = await _audioRecorder.stop();
      if (path == null) {
        setState(() => _isDictatingAgenda = false);
        return;
      }
      
      setState(() {
        _isDictatingAgenda = false;
        _isGenerating = true;
      });

      try {
        Uint8List audioBytes;
        if (kIsWeb) {
          final response = await http.get(Uri.parse(path));
          audioBytes = response.bodyBytes;
        } else {
          audioBytes = await io.File(path).readAsBytes();
        }

        final aiChatService = Provider.of<AiChatService>(context, listen: false);
        final result = await aiChatService.transcribeAndImproveAgenda(audioBytes);
        
        setState(() {
          _agendaController.text = result;
          _isGenerating = false;
        });
        _saveMeetingDetails();
      } catch (e) {
        setState(() => _isGenerating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao processar áudio: $e')),
          );
        }
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        const config = RecordConfig();
        
        final fileName = 'agenda_${DateTime.now().millisecondsSinceEpoch}.m4a';
        String? path;
        
        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          path = p.join(directory.path, fileName);
        }
        
        await _audioRecorder.start(config, path: path ?? '');
        setState(() => _isDictatingAgenda = true);
      }
    }
  }

  Future<void> _finalizeMeetingNotice() async {
    if (_invitationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, gere o texto da convocatória primeiro')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final instService = Provider.of<InstitutionalService>(context, listen: false);
      
      // 1. Generate the formal PDF
      // We don't have a direct "generateAndGetUrl" but we can generate it
      // For now, let's just mark it as scheduled and finalized.
      
      await instService.updateMeeting(widget.meeting.id, {
        'status': 'scheduled',
        'agenda': _agendaController.text,
        'invitationText': _invitationController.text,
      });

      await instService.markScheduledMeetingAsDelivered(widget.meeting.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('Convocatória Finalizada! Agora está visível para todos os participantes.')),
        );
        setState(() => _isGenerating = false);
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao finalizar: $e')),
        );
      }
    }
  }

  Future<void> _saveMeetingDetails() async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    await instService.updateMeeting(widget.meeting.id, {
      'agenda': _agendaController.text,
      'location': _locationController.text,
      'date': Timestamp.fromDate(_startDate),
      'startTime': Timestamp.fromDate(startDateTime),
      'endTime': Timestamp.fromDate(endDateTime),
      'invitationText': _invitationController.text,
    });
  }

  Future<void> _generateInvitation() async {
    if (_agendaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, defina a ordem de trabalhos primeiro')),
      );
      return;
    }
    setState(() => _isGeneratingInvitation = true);
    try {
      final aiChatService = Provider.of<AiChatService>(context, listen: false);
      final msg = await aiChatService.generateMeetingInvitation(
        title: widget.meeting.title,
        agenda: _agendaController.text,
        date: "${_startDate.day}/${_startDate.month}/${_startDate.year}",
        time: "${_startTime.format(context)} - ${_endTime.format(context)}",
        location: _locationController.text,
      );
      setState(() {
        _invitationController.text = msg;
        _isGeneratingInvitation = false;
      });
      _saveMeetingDetails();
    } catch (e) {
      setState(() => _isGeneratingInvitation = false);
    }
  }

  void _addGuest() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final emailController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Adicionar Convidado Externo', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nome', labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'E-mail', labelStyle: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                  final newGuest = Participant(
                    name: nameController.text,
                    email: emailController.text,
                    status: 'invited',
                    isGuest: true,
                  );
                  final instService = Provider.of<InstitutionalService>(context, listen: false);
                  final updatedParticipants = [..._participants, newGuest];
                  await instService.updateMeeting(widget.meeting.id, {
                    'participants': updatedParticipants.map((p) => p.toMap()).toList(),
                  });
                  setState(() => _participants = updatedParticipants);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const AiTranslatedText('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _minutesController.dispose();
    _transcriptController.dispose();
    _agendaController.dispose();
    _locationController.dispose();
    _invitationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(widget.meeting.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF7B61FF),
            labelColor: Color(0xFF7B61FF),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Convocatória'),
              Tab(text: 'Presenças'),
              Tab(text: 'Documentos'),
              Tab(text: 'Sessão e Ata'),
            ],
          ),
          actions: [
            if (_minutesController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                onPressed: () => _exportToPdf(),
              ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildConvocatoriaTab(),
            _buildPresenceTab(),
            _buildDocumentsTab(),
            _buildSessionTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildConvocatoriaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Convocatória e Ordem de Trabalhos'),
          const SizedBox(height: 16),
          if (widget.canManage) ...[
            _buildMandatoryFields(),
            const SizedBox(height: 24),
          ],
          const AiTranslatedText('Ordem de Trabalhos (Tópicos)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _agendaController,
            maxLines: 5,
            enabled: widget.canManage,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Ex: Aprovação de contas, Planeamento 2024...'),
            onChanged: (v) => _saveMeetingDetails(),
          ),
          const SizedBox(height: 16),
          if (widget.canManage)
            Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _helpWithAgenda,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const AiTranslatedText('Melhorar Agenda com IA'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.8)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _toggleAgendaDictation,
                icon: Icon(_isDictatingAgenda ? Icons.stop : Icons.mic, size: 18),
                label: AiTranslatedText(_isDictatingAgenda ? 'Parar Ditado' : 'Ditar Agenda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDictatingAgenda ? Colors.redAccent : Colors.white10,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Texto da Convocatória (Editável)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _isGeneratingInvitation ? null : _generateInvitation,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const AiTranslatedText('Gerar Texto com IA'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _invitationController,
            maxLines: 8,
            enabled: widget.canManage,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('O texto formal da convocatória será gerado aqui...'),
            onChanged: (v) => _saveMeetingDetails(),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          if (widget.canManage)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _finalizeMeetingNotice,
                    icon: Icon(_isGenerating ? Icons.hourglass_empty : Icons.check_circle),
                    label: const AiTranslatedText('Finalizar e Notificar Participantes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF7B61FF)),
                  onPressed: _sendEmailInvitations,
                  tooltip: 'Enviar por E-mail',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white70),
                  onPressed: _exportConvocatoriaToPdf,
                  tooltip: 'Descarregar PDF',
                ),
              ],
            ),
          const SizedBox(height: 24),
          _buildParticipantsHeader(),
          const SizedBox(height: 8),
          _buildParticipantsList(),
          const SizedBox(height: 16),
          if (widget.canManage)
            OutlinedButton.icon(
              onPressed: _addGuest,
              icon: const Icon(Icons.person_add, color: Colors.white70),
              label: const AiTranslatedText('Adicionar Novo Convidado (Fora do Órgão)', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white24)),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return AiTranslatedText(title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildMandatoryFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPickerTile(
                  icon: Icons.calendar_today,
                  label: 'Data',
                  value: "${_startDate.day}/${_startDate.month}/${_startDate.year}",
                  onTap: _selectDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPickerTile(
                  icon: Icons.access_time,
                  label: 'Início',
                  value: _startTime.format(context),
                  onTap: () => _selectTime(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPickerTile(
                  icon: Icons.access_time_filled,
                  label: 'Fim',
                  value: _endTime.format(context),
                  onTap: () => _selectTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on, color: Colors.white54, size: 20),
              labelText: 'Localização da Sessão',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
            ),
            onChanged: (v) => _saveMeetingDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile({required IconData icon, required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF7B61FF)),
                const SizedBox(width: 4),
                AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _saveMeetingDetails();
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked; else _endTime = picked;
      });
      _saveMeetingDetails();
    }
  }

  Widget _buildParticipantsHeader() {
    return const AiTranslatedText('Participantes Convocados',
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildParticipantsList() {
    if (_participants.isEmpty) return const SizedBox();
    return Column(
      children: _participants.map((p) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: p.isGuest ? Colors.orange.withValues(alpha: 0.2) : const Color(0xFF7B61FF).withValues(alpha: 0.2),
          child: Text(p.name.substring(0, 1).toUpperCase(), style: TextStyle(color: p.isGuest ? Colors.orange : const Color(0xFF7B61FF))),
        ),
        title: Text(p.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(p.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: p.isGuest ? IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
          onPressed: () => _removeParticipant(p.email),
        ) : const Icon(Icons.check_circle, color: Colors.white24, size: 20),
      )).toList(),
    );
  }

  void _removeParticipant(String email) async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final updated = _participants.where((p) => p.email != email).toList();
    await instService.updateMeeting(widget.meeting.id, {
      'participants': updated.map((p) => p.toMap()).toList(),
    });
    setState(() => _participants = updated);
  }

  Future<void> _sendEmailInvitations() async {
    if (_invitationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, gere o texto da convocatória primeiro')),
      );
      return;
    }

    final emails = _participants.map((p) => p.email).join(',');
    final subject = Uri.encodeComponent('Convocatória: ${widget.meeting.title}');
    final body = Uri.encodeComponent(_invitationController.text);
    
    final uri = Uri.parse('mailto:$emails?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      
      final instService = Provider.of<InstitutionalService>(context, listen: false);
      try {
        await instService.updateMeeting(widget.meeting.id, {'status': 'scheduled'});
        await instService.markScheduledMeetingAsDelivered(widget.meeting.id);
      } catch (e) {
        debugPrint('Error updating meeting status: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Convocatória preparada! Abra o seu cliente de e-mail para enviar.')),
      );
    }
  }

  Future<void> _exportConvocatoriaToPdf() async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final organs = await instService.getOrgans();
    if (!mounted) return;
    final organ = organs.firstWhere((o) => o.id == widget.meeting.organId);

    await PdfService.generateConvocatoriaPDF(
      organ: organ,
      meeting: widget.meeting.copyWith(
        agenda: _agendaController.text,
        location: _locationController.text,
      ),
    );
  }

  Widget _buildPresenceTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Lista de Presenças',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.white70),
                onPressed: () => _exportAttendanceSheet(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final p = _participants[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.status.contains('attended') ? Colors.green : Colors.grey,
                  child: Text(p.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(p.email, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: _buildPresenceAction(p),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportAttendanceSheet() async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final organs = await instService.getOrgans();
    if (!mounted) return;
    final organ = organs.firstWhere((o) => o.id == widget.meeting.organId);
    
    await PdfService.generateAttendanceSheetPDF(
      organ: organ,
      meeting: widget.meeting.copyWith(participants: _participants, agenda: _agendaController.text),
    );
  }

  Widget _buildPresenceAction(Participant p) {
    if (p.status == 'attended_auto') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (!widget.canManage) {
      return Icon(
        p.status == 'attended_manual' ? Icons.check_circle : Icons.radio_button_unchecked,
        color: p.status == 'attended_manual' ? Colors.green : Colors.white24,
      );
    }
    return PopupMenuButton<String>(
      icon: Icon(
        p.status == 'attended_manual' ? Icons.check_circle : Icons.radio_button_unchecked,
        color: p.status == 'attended_manual' ? Colors.green : Colors.white24,
      ),
      onSelected: (status) => _updateParticipantStatus(p.email, status),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'attended_manual', child: AiTranslatedText('Presente (Manual)')),
        const PopupMenuItem(value: 'absent', child: AiTranslatedText('Ausente')),
        const PopupMenuItem(value: 'invited', child: AiTranslatedText('Convocado')),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildContextCard(),
    );
  }

  Widget _buildSessionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (widget.canManage) ...[
            _buildRecordingCard(),
            const SizedBox(height: 24),
          ],
          if (_isGenerating || _isUploading)
            _buildProgressCard()
          else
            _buildMinutesEditor(),
        ],
      ),
    );
  }

  // --- Utility Methods (Context / Recording / Upload) ---

  Widget _buildContextCard() {
    return DropTarget(
      onDragDone: (detail) => _onFilesDropped(detail),
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDragging 
              ? const Color(0xFF7B61FF).withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDragging ? const Color(0xFF7B61FF) : Colors.white10,
            width: _isDragging ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Documentos de Apoio',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (_isUploadingDoc)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B61FF)))
                else if (widget.canManage)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF7B61FF)),
                    onPressed: _pickAndUploadDocument,
                  ),
              ],
            ),
            if (widget.canManage)
              const AiTranslatedText('Arraste ou carregue ficheiros para dar contexto.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            if (_contextFileUrls.isEmpty && !_isDragging)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: AiTranslatedText('Nenhum documento carregado.',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              )
            else ...[
              if (_isDragging)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.file_upload, color: Color(0xFF7B61FF), size: 40),
                        SizedBox(height: 8),
                        AiTranslatedText('Largar ficheiros aqui', style: TextStyle(color: Color(0xFF7B61FF))),
                      ],
                    ),
                  ),
                ),
              ..._contextFileUrls.map((url) => _buildFileItem(url)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(String url) {
    final fileName = url.split('%2F').last.split('?').first.toLowerCase();
    IconData icon = Icons.description;
    Color iconColor = Colors.white70;

    if (fileName.contains('.jpg') || fileName.contains('.png') || fileName.contains('.jpeg')) {
      icon = Icons.image;
      iconColor = Colors.blueAccent;
    } else if (fileName.contains('.mp3') || fileName.contains('.wav') || fileName.contains('.m4a')) {
      icon = Icons.audiotrack;
      iconColor = Colors.orangeAccent;
    } else if (fileName.contains('.pdf')) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (fileName.contains('.xls') || fileName.contains('.xlsx')) {
      icon = Icons.table_chart;
      iconColor = Colors.greenAccent;
    } else if (fileName.contains('.ppt') || fileName.contains('.pptx')) {
      icon = Icons.slideshow;
      iconColor = Colors.orange;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(url.split('%2F').last.split('?').first,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white24, size: 18),
            onPressed: () => _launchURL(url),
          ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
              onPressed: () => _removeDocument(url),
            ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _pickAndUploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx', 'doc', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'png', 'jpeg', 'mp3', 'wav', 'm4a'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      await _uploadBytes(result.files.single.bytes!, result.files.single.name);
    }
  }

  Future<void> _onFilesDropped(DropDoneDetails detail) async {
    setState(() => _isDragging = false);
    for (final file in detail.files) {
      final bytes = await file.readAsBytes();
      await _uploadBytes(bytes, file.name);
    }
  }

  Future<void> _uploadBytes(Uint8List bytes, String fileName) async {
    setState(() => _isUploadingDoc = true);
    try {
      final instService = Provider.of<InstitutionalService>(context, listen: false);
      final url = await instService.uploadMeetingDocument(widget.meeting.id, bytes, fileName);
      
      String extracted = '';
      if (!kIsWeb && (fileName.endsWith('.pdf') || fileName.endsWith('.txt'))) {
        try {
          final extractor = TextExtractor();
          final tempDir = await getTemporaryDirectory();
          final tempFile = await io.File(p.join(tempDir.path, fileName)).writeAsBytes(bytes);
          final extractionResult = await extractor.extractText(tempFile.path);
          extracted = extractionResult.text;
        } catch (e) {
          debugPrint('Text extraction failed: $e');
        }
      }

      if (mounted) {
        setState(() {
          _contextFileUrls.add(url);
          if (extracted.isNotEmpty) {
            _contextText =
                '${_contextText ?? ''}\n\n--- Documento: $fileName ---\n$extracted';
          }
          _isUploadingDoc = false;
        });

        await instService.updateMeeting(widget.meeting.id, {
          'contextFileUrls': _contextFileUrls,
          'contextText': _contextText,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingDoc = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar documento: $e')),
        );
      }
    }
  }

  Future<void> _removeDocument(String url) async {
    setState(() => _contextFileUrls.remove(url));
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    await instService.updateMeeting(widget.meeting.id, {
      'contextFileUrls': _contextFileUrls,
    });
  }

  Widget _buildRecordingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const AiTranslatedText('Gravação da Sessão',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 20),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
                color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => _isRecording ? _stopRecording() : _startRecording(),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF7B61FF).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _isRecording ? Colors.red : const Color(0xFF7B61FF), width: 4),
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? Colors.red : const Color(0xFF7B61FF),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AiTranslatedText(
            _isRecording ? 'Gravando...' : 'Toque para iniciar a sessão',
            style: TextStyle(color: _isRecording ? Colors.red : Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF7B61FF)),
          const SizedBox(height: 16),
          AiTranslatedText(
            _isUploading ? 'A carregar áudio...' : 'Gerando transcrição e ata...',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMinutesEditor() {
    if (_minutesController.text.isEmpty && !_isGenerating) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText('Proposta de Ata',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _minutesController,
          maxLines: null,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _finalizeAndSave(),
            icon: const Icon(Icons.check_circle),
            label: const AiTranslatedText('Finalizar e Bloquear Ata'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _finalizeAndSave() async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    await instService.updateMeeting(widget.meeting.id, {
      'minutes': _minutesController.text,
      'status': 'finalized',
    });
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Ata finalizada!')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _exportToPdf() async {
    final instService = Provider.of<InstitutionalService>(context, listen: false);
    final organs = await instService.getOrgans();
    final organ = organs.firstWhere((o) => o.id == widget.meeting.organId);
    
    await PdfService.generateMeetingMinutesPDF(
      organ: organ,
      meeting: widget.meeting,
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final dir = await getApplicationDocumentsDirectory();
          path = p.join(dir.path, 'meeting_${widget.meeting.id}.m4a');
          _recordingPath = path;
        }
        const config = RecordConfig();
        await _audioRecorder.start(config, path: path ?? '');
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() => _recordDuration++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      _recordingPath = path;
      _uploadAndGenerate();
    }
  }

  Future<void> _uploadAndGenerate() async {
    if (_recordingPath == null) return;
    setState(() => _isUploading = true);
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final aiChatService = Provider.of<AiChatService>(context, listen: false);
    final instService = Provider.of<InstitutionalService>(context, listen: false);

    try {
      Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(_recordingPath!));
        bytes = response.bodyBytes;
      } else {
        bytes = await _readFileBytes(_recordingPath!);
      }

      final audioUrl = await firebaseService.uploadMeetingAudio(widget.meeting.id, bytes);
      if (audioUrl != null) {
        setState(() {
          _isUploading = false;
          _isGenerating = true;
        });
        final result = await aiChatService.generateMeetingMinutes(audioUrl, context: _contextText);
        setState(() {
          _minutesController.text = result['minutes'] ?? '';
          _transcriptController.text = result['transcript'] ?? '';
          _isGenerating = false;
        });
        await instService.updateMeeting(widget.meeting.id, {
          'audioUrl': audioUrl,
          'transcript': _transcriptController.text,
          'minutes': _minutesController.text,
          'status': 'recorded',
        });
      }
    } catch (e) {
      setState(() { _isUploading = false; _isGenerating = false; });
    }
  }

  Future<Uint8List> _readFileBytes(String path) async {
    if (kIsWeb) return Uint8List(0);
    final file = io.File(path);
    return await file.readAsBytes();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
