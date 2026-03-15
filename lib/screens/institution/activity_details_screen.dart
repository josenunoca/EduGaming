import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity_model.dart';
import '../../models/institution_model.dart';
import '../../models/subject_model.dart';
import '../../models/course_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final InstitutionalActivity activity;
  final InstitutionModel institution;
  const ActivityDetailsScreen({super.key, required this.activity, required this.institution});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.activity.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Detalhes'),
            Tab(text: 'Participantes'),
            Tab(text: 'Multimédia'),
            Tab(text: 'Mural'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildParticipantsTab(),
          _buildMultimediaTab(),
          _buildWallTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Planeamento'),
          const SizedBox(height: 16),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailItem(Icons.calendar_month, 'Período', 
                    '${widget.activity.startDate.day}/${widget.activity.startDate.month} até ${widget.activity.endDate.day}/${widget.activity.endDate.month}'),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.access_time, 'Horário', 
                    '${widget.activity.startTime} - ${widget.activity.endTime}'),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.info_outline, 'Descrição', widget.activity.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Recursos Envolvidos'),
          const SizedBox(height: 16),
          // Resources list placeholder
          ...widget.activity.resources.map((r) => ListTile(
            leading: Icon(r.type == 'human' ? Icons.person : Icons.build, color: Colors.blueAccent),
            title: Text(r.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text(r.role ?? (r.quantity != null ? 'Qtd: ${r.quantity}' : ''), 
              style: const TextStyle(color: Colors.white54)),
          )),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AiTranslatedText('${widget.activity.participants.length} Participantes', 
                style: const TextStyle(color: Colors.white, fontSize: 18)),
              ElevatedButton.icon(
                onPressed: () => _showInviteGroupDialog(context),
                icon: const Icon(Icons.group_add),
                label: const AiTranslatedText('Convidar Grupo'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: widget.activity.participants.length,
              itemBuilder: (context, index) {
                final p = widget.activity.participants[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(p.email, style: const TextStyle(color: Colors.white54)),
                  trailing: Text(p.role, style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => _handleFileUpload(),
            icon: const Icon(Icons.cloud_upload),
            label: const AiTranslatedText('Fazer Upload (Docs/Imagens/Vídeos)'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: widget.activity.media.length,
              itemBuilder: (context, index) {
                final m = widget.activity.media[index];
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Icon(_getMediaIcon(m.type), color: Colors.white24)),
                    ),
                    Positioned(
                      bottom: 4, right: 4,
                      child: Icon(_getVisibilityIcon(m.visibility), size: 12, color: Colors.white54),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallTab() {
    return const Center(child: AiTranslatedText('Mural de Comunicação em breve...', style: TextStyle(color: Colors.white54)));
  }

  void _showInviteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Convidar por Grupo', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInviteOption(Icons.business, 'Toda a Instituição', () => _inviteAllInstitution()),
            _buildInviteOption(Icons.school, 'Por Curso', () => _showCourseSelector()),
            _buildInviteOption(Icons.book, 'Por Disciplina', () => _showSubjectSelector()),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7B61FF)),
      title: AiTranslatedText(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // Logic placeholders
  void _inviteAllInstitution() async {
    final service = context.read<FirebaseService>();
    final members = await service.getAllInstitutionMembers(widget.institution.id);
    await service.inviteGroupToActivity(widget.activity.id, 'institution', widget.institution.id, members);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AiTranslatedText('Convitados ${members.length} membros da instituição.'))
      );
    }
  }

  void _showCourseSelector() {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Selecionar Curso', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Course>>(
            stream: service.getCourses(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final courses = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: courses.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(courses[index].name, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const AiTranslatedText('Confirmar Convite', style: TextStyle(color: Colors.white)),
                        content: AiTranslatedText('Deseja convidar todos os membros do curso ${courses[index].name}?', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const AiTranslatedText('Convidar', style: TextStyle(color: Colors.blueAccent)),
                          ),
                        ],
                      ),
                    );
                    if (!mounted || confirm != true) return;
                    final members = await service.getCourseMembers(widget.institution.id, courses[index].id);
                    await service.inviteGroupToActivity(widget.activity.id, 'course', courses[index].id, members);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: AiTranslatedText('Convitados ${members.length} membros do curso ${courses[index].name}.'))
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSubjectSelector() {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Selecionar Disciplina', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Subject>>(
            stream: service.getSubjectsByInstitution(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final subjects = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: subjects.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(subjects[index].name, style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final members = await service.getSubjectMembers(widget.institution.id, subjects[index].id);
                    await service.inviteGroupToActivity(widget.activity.id, 'subject', subjects[index].id, members);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: AiTranslatedText('Convitados ${members.length} membros da disciplina ${subjects[index].name}.'))
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleFileUpload() async {
    // 1. Visivilidade Selector
    ActivityVisibility? visibility = await showDialog<ActivityVisibility>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Quem pode visualizar?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const AiTranslatedText('Apenas Participantes', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, ActivityVisibility.participantsOnly),
            ),
            ListTile(
              title: const AiTranslatedText('Toda a Instituição', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, ActivityVisibility.wholeInstitution),
            ),
            ListTile(
              title: const AiTranslatedText('Público', style: TextStyle(color: Colors.white70)),
              onTap: () => Navigator.pop(ctx, ActivityVisibility.public),
            ),
          ],
        ),
      ),
    );

    if (visibility == null) return;

    // 2. Logic Placeholder for file picking and uploading
    final service = context.read<FirebaseService>();
    final newMedia = ActivityMedia(
      id: const Uuid().v4(),
      name: 'Upload ${DateTime.now().toLocal()}',
      url: 'https://placeholder.com/file',
      type: 'image',
      visibility: visibility,
      uploadedAt: DateTime.now(),
    );

    await service.updateActivityMedia(widget.activity.id, newMedia);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Média adicionada com sucesso.'))
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return AiTranslatedText(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getMediaIcon(String type) {
    if (type == 'image') return Icons.image;
    if (type == 'video') return Icons.videocam;
    return Icons.description;
  }

  IconData _getVisibilityIcon(ActivityVisibility v) {
    if (v == ActivityVisibility.public) return Icons.public;
    if (v == ActivityVisibility.wholeInstitution) return Icons.business;
    return Icons.lock;
  }
}
