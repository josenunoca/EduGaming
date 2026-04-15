import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/institution_organ_model.dart';
import '../../models/user_model.dart';
import '../../services/institutional_service.dart';
import '../../services/firebase_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/ai_translated_text.dart';
import 'meeting_recording_screen.dart';
import '../../models/institution_model.dart';

class MeetingListScreen extends StatefulWidget {
  final InstitutionOrgan organ;

  const MeetingListScreen({super.key, required this.organ});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final institutionalService = Provider.of<InstitutionalService>(context);
    final firebaseService = Provider.of<FirebaseService>(context);
    final currentUser = firebaseService.currentUser;

    return StreamBuilder<UserModel?>(
      stream: firebaseService.getUserStream(currentUser?.uid ?? ''),
      builder: (context, userSnapshot) {
        final userModel = userSnapshot.data;
        if (userModel == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        return StreamBuilder<InstitutionModel?>(
          stream: userModel.institutionId != null 
              ? firebaseService.getInstitutionStream(userModel.institutionId!)
              : Stream.value(null),
          builder: (context, instSnapshot) {
            final institution = instSnapshot.data;
            
            // The user can manage if they are the institution/admin OR the leader of this specific organ
            // OR if they have delegated responsibility for this specific organ
            final bool isDelegated = institution?.delegatedRoles['organs:${widget.organ.id}']?.contains(userModel.id) ?? false;
            final bool isGlobalOrganDelegate = institution?.delegatedRoles['academic']?.contains(userModel.id) ?? false; // Academic usually covers organs

            final bool canManage = userModel.role == UserRole.institution ||
                userModel.role == UserRole.admin ||
                (currentUser?.email?.startsWith('instituicao@') == true) ||
                institutionalService.isLeaderForOrgan(
                    widget.organ, currentUser?.email) ||
                isDelegated ||
                isGlobalOrganDelegate;

            return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.organ.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const AiTranslatedText('Gestão Documental e Reuniões',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_showArchive ? Icons.list : Icons.archive,
                    color: Colors.white70),
                onPressed: () => setState(() => _showArchive = !_showArchive),
                tooltip: _showArchive ? 'Ver Sessões' : 'Ver Arquivo',
              ),
            ],
          ),
          body: StreamBuilder<List<Meeting>>(
            stream: institutionalService.getMeetingsStream(widget.organ.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final meetings = snapshot.data ?? [];

              if (meetings.isEmpty) {
                return _buildEmptyState(context, canManage);
              }

              if (_showArchive) {
                return _buildArchiveView(meetings, canManage);
              }

              return _buildMeetingsList(meetings, canManage);
            },
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  backgroundColor: const Color(0xFF7B61FF),
                  onPressed: () => _showAddMeetingDialog(context),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const AiTranslatedText('Convocatória',
                      style: TextStyle(color: Colors.white)),
                )
              : null,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_shared, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const AiTranslatedText('Nenhum documento ou sessão registada',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 24),
          if (canManage)
            ElevatedButton.icon(
              onPressed: () => _showAddMeetingDialog(context),
              icon: const Icon(Icons.email),
              label: const AiTranslatedText('Nova Convocatória'),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList(List<Meeting> meetings, bool canManage) {
    final upcoming = meetings.where((m) => m.status != 'finalized').toList();
    final archived = meetings.where((m) => m.status == 'finalized').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isNotEmpty) ...[
            _buildSectionHeader('Próximas Sessões'),
            const SizedBox(height: 12),
            ...upcoming.map((m) => _buildMeetingCard(m, canManage)),
            const SizedBox(height: 24),
          ],
          if (archived.isNotEmpty) ...[
            _buildSectionHeader('Arquivo Histórico (Sessões Realizadas)'),
            const SizedBox(height: 12),
            ...archived.map((m) => _buildMeetingCard(m, canManage)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: AiTranslatedText(title,
          style: const TextStyle(
              color: Color(0xFF7B61FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildMeetingCard(Meeting meeting, bool canManage) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.05))),
      child: InkWell(
        onTap: () => _navigateToMeeting(context, meeting, canManage),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(meeting.status),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(dateFormat.format(meeting.date),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(meeting.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              if (meeting.startTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time,
                          color: Colors.white24, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(meeting.startTime!)} - ${meeting.endTime != null ? timeFormat.format(meeting.endTime!) : '...'}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 12),
                      ),
                      if (meeting.location != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on,
                            color: Colors.white24, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(meeting.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white24, fontSize: 12))),
                      ],
                    ],
                  ),
                ),

              // New: Invitation Preview for Scheduled meetings
              if (meeting.status == 'scheduled' &&
                  meeting.invitationText != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B61FF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7B61FF).withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.email_outlined,
                              color: Color(0xFF7B61FF), size: 14),
                          SizedBox(width: 8),
                          AiTranslatedText('Convocatória Efetuada:',
                              style: TextStyle(
                                  color: Color(0xFF7B61FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(meeting.invitationText!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),

              // New: Supporting Documents for Upcoming meetings
              if (meeting.status != 'finalized' &&
                  meeting.contextFileUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AiTranslatedText('Documentos Anexos:',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: meeting.contextFileUrls.map((url) {
                          final fileName = Uri.decodeFull(
                              url.split('/').last.split('?').first);
                          final extension =
                              fileName.split('.').last.toLowerCase();
                          return InkWell(
                            onTap: () => _launchURL(url),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_getFileIcon(extension),
                                      color: _getFileColor(extension),
                                      size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                      fileName.length > 15
                                          ? '${fileName.substring(0, 12)}...'
                                          : fileName,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

              if (meeting.status != 'finalized' &&
                  meeting.agenda != null &&
                  meeting.agenda!.isNotEmpty &&
                  meeting.status != 'scheduled')
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AiTranslatedText('Agenda em curso:',
                          style: TextStyle(
                              color: Color(0xFF7B61FF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(meeting.agenda!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.3)),
                    ],
                  ),
                ),

              // New: Email Tracking for Scheduled meetings
              if (meeting.status == 'scheduled')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: InkWell(
                    onTap: () => _showTrackingDetails(meeting),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mark_email_read_outlined,
                              color: Colors.blue, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            '${meeting.participants.where((p) => p.deliveredAt != null).length} Entregues • ${meeting.participants.where((p) => p.readAt != null).length} Lidos',
                            style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.blue, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),

              if (meeting.status == 'scheduled' || meeting.status == 'ongoing')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            _navigateToMeeting(context, meeting, canManage),
                        icon: const Icon(Icons.login,
                            size: 16, color: Colors.white),
                        label: const AiTranslatedText('ENTRAR NA REUNIÃO',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              if (meeting.status == 'finalized')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const AiTranslatedText('Descarregar Ata'),
                        onPressed: () => PdfService.generateMeetingMinutesPDF(
                          organ: widget.organ,
                          meeting: meeting,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveView(List<Meeting> meetings, bool canManage) {
    final archivedMeetings =
        meetings.where((m) => m.status == 'finalized').toList();

    if (archivedMeetings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            AiTranslatedText('Nenhum sessão arquivada',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archivedMeetings.length,
      itemBuilder: (context, index) {
        final meeting = archivedMeetings[index];
        final files = meeting.contextFileUrls;

        return Card(
          color: Colors.white.withOpacity(0.03),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white12)),
          child: ExpansionTile(
            collapsedIconColor: Colors.white54,
            iconColor: const Color(0xFF7B61FF),
            title: Text(meeting.title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(meeting.date),
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Documentos da Sessão',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildArchiveDocTile(
                      icon: Icons.description,
                      name: 'Ata da Sessão (PDF)',
                      color: Colors.green,
                      onTap: () => PdfService.generateMeetingMinutesPDF(
                          organ: widget.organ, meeting: meeting),
                    ),
                    if (meeting.invitationText != null)
                      _buildArchiveDocTile(
                        icon: Icons.email_outlined,
                        name: 'Convocatória Enviada',
                        color: Colors.blue,
                        onTap: () => _viewInvitation(meeting),
                      ),
                    _buildArchiveDocTile(
                      icon: Icons.people_outline,
                      name: 'Lista de Convocados e Presenças',
                      color: Colors.orange,
                      onTap: () => _viewParticipants(meeting),
                    ),
                    ...files.map((url) {
                      final fileName =
                          Uri.decodeFull(url.split('/').last.split('?').first);
                      final extension = fileName.split('.').last.toLowerCase();
                      return _buildArchiveDocTile(
                        icon: _getFileIcon(extension),
                        name: fileName,
                        color: _getFileColor(extension),
                        onTap: () => _launchURL(url),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchiveDocTile(
      {required IconData icon,
      required String name,
      required Color color,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(name,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13))),
              const Icon(Icons.open_in_new, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _viewParticipants(Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Convocados e Presenças',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: meeting.participants.length,
            itemBuilder: (context, index) {
              final p = meeting.participants[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text(p.name[0],
                      style: const TextStyle(color: Colors.white)),
                ),
                title: Text(p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(p.email,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: p.isPresent
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 20)
                    : const Icon(Icons.radio_button_unchecked,
                        color: Colors.white24, size: 20),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Fechar')),
        ],
      ),
    );
  }

  void _viewInvitation(Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Convocatória Arquivada',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(meeting.invitationText ?? '',
              style: const TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Fechar')),
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

  void _showTrackingDetails(Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Detalhes de Entrega',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: meeting.participants.length,
            itemBuilder: (context, index) {
              final p = meeting.participants[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text(p.name[0],
                      style: const TextStyle(color: Colors.white)),
                ),
                title: Text(p.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.email,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    if (p.deliveredAt != null)
                      Text(
                          'Entregue: ${DateFormat('dd/MM HH:mm').format(p.deliveredAt!)}',
                          style: const TextStyle(
                              color: Colors.blue, fontSize: 10)),
                  ],
                ),
                trailing: p.readAt != null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all, color: Colors.blue, size: 16),
                          Text('Lido',
                              style:
                                  TextStyle(color: Colors.blue, fontSize: 10)),
                        ],
                      )
                    : (p.deliveredAt != null
                        ? const Icon(Icons.done,
                            color: Colors.white24, size: 16)
                        : const Icon(Icons.mail_outline,
                            color: Colors.white10, size: 16)),
                onTap: () {
                  // Small cheat: Clicking on a participant marks it as read for demo purposes
                  final service =
                      Provider.of<InstitutionalService>(context, listen: false);
                  service.updateParticipantEmailStatus(meeting.id, p.email,
                      isRead: true);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Fechar')),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'docx':
      case 'doc':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'pptx':
      case 'ppt':
        return Colors.orange;
      default:
        return Colors.white54;
    }
  }

  void _navigateToMeeting(
      BuildContext context, Meeting meeting, bool canManage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MeetingRecordingScreen(meeting: meeting, canManage: canManage),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'finalized':
        color = Colors.green;
        label = 'Finalizada e Assinada';
        break;
      case 'recorded':
        color = Colors.blue;
        label = 'Ata em Elaboração';
        break;
      case 'ongoing':
        color = Colors.redAccent;
        label = 'Sessão em Curso';
        break;
      case 'scheduled':
        color = Colors.orange;
        label = 'Convocatória Enviada';
        break;
      default:
        color = Colors.grey;
        label = 'Rascunho';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: AiTranslatedText(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showAddMeetingDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController =
        TextEditingController(text: 'Sede da Empresa / Sala de Reuniões');
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Nova Convocatória',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Assunto / Título',
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 16),
                _buildDialogPicker(
                  icon: Icons.calendar_today,
                  label: 'Data da Sessão',
                  value: DateFormat('dd/MM/yyyy').format(selectedDate),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null)
                      setDialogState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDialogPicker(
                        icon: Icons.access_time,
                        label: 'Início',
                        value: startTime.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: startTime);
                          if (picked != null)
                            setDialogState(() => startTime = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDialogPicker(
                        icon: Icons.access_time_filled,
                        label: 'Fim',
                        value: endTime.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: endTime);
                          if (picked != null)
                            setDialogState(() => endTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Local da Sessão',
                      labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final service =
                      Provider.of<InstitutionalService>(context, listen: false);
                  final participants =
                      await service.getOrganMembers(widget.organ.memberIds);

                  final startDT = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      startTime.hour,
                      startTime.minute);
                  final endDT = DateTime(selectedDate.year, selectedDate.month,
                      selectedDate.day, endTime.hour, endTime.minute);

                  final meeting = Meeting(
                    id: '',
                    organId: widget.organ.id,
                    title: titleController.text,
                    date: selectedDate,
                    startTime: startDT,
                    endTime: endDT,
                    location: locationController.text,
                    status: 'scheduled',
                    participants: participants,
                    institutionId: widget.organ.institutionId,
                  );

                  final id = await service.createMeeting(meeting);

                  if (context.mounted) {
                    Navigator.pop(context);
                    // Pass canManage correctly when navigating after creation
                    _navigateToMeeting(context, meeting.copyWith(id: id), true);
                  }
                }
              },
              child: const AiTranslatedText('Criar Convocatória'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogPicker(
      {required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: const Color(0xFF7B61FF)),
                const SizedBox(width: 4),
                AiTranslatedText(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
