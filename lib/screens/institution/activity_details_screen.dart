import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/activity_model.dart';
import '../../models/institution_model.dart';
import '../../models/subject_model.dart';
import '../../models/course_model.dart';
import '../../services/firebase_service.dart';
import '../../services/ai_chat_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/participant_selector_dialog.dart';
import '../../models/user_model.dart';
import '../../widgets/ai_text_field.dart';
import '../../utils/marketing_export_helper.dart';
import '../../models/facility_model.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final InstitutionalActivity activity;
  final InstitutionModel institution;
  const ActivityDetailsScreen(
      {super.key, required this.activity, required this.institution});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InstitutionalActivity _currentActivity;
  bool _isSelectionMode = false;
  final Set<String> _selectedMediaIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.activity.hasFinancialImpact ? 5 : 4, vsync: this);
    _currentActivity = widget.activity;
  }

  Future<void> _refreshActivity() async {
    final service = context.read<FirebaseService>();
    final updated = await service.getActivityById(_currentActivity.id);
    if (updated != null && mounted) {
      setState(() {
        _currentActivity = updated;
      });
    }
  }

  Future<void> _toggleCompletion() async {
    final service = context.read<FirebaseService>();
    final newStatus = _currentActivity.status == 'completed' ? 'planned' : 'completed';
    await service.updateActivityStatus(_currentActivity.id, newStatus);
    await _refreshActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_currentActivity.title),
        actions: [
          if (_tabController.index == 2 && _currentActivity.media.isNotEmpty)
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
              onPressed: () => setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedMediaIds.clear();
              }),
            ),
          if (_isSelectionMode && _selectedMediaIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _confirmBulkDelete(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {
            _isSelectionMode = false;
            _selectedMediaIds.clear();
          }),
          tabs: [
            const Tab(text: 'Detalhes'),
            const Tab(text: 'Participantes'),
            const Tab(text: 'Multimédia'),
            if (_currentActivity.hasFinancialImpact) const Tab(text: 'Finanças'),
            const Tab(text: 'Mural'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildParticipantsTab(),
          _buildMultimediaTab(),
          if (_currentActivity.hasFinancialImpact) _buildFinancialsTab(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Planeamento'),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                onPressed: () => _showEditDetailsDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailItem(Icons.category, 'Grupo', _currentActivity.activityGroup),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.calendar_month, 'Período',
                      '${_currentActivity.startDate.day}/${_currentActivity.startDate.month}/${_currentActivity.startDate.year} - ${_currentActivity.endDate.day}/${_currentActivity.endDate.month}/${_currentActivity.endDate.year}'),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.access_time, 'Horário',
                      '${_currentActivity.startTime} - ${_currentActivity.endTime}'),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.info_outline, 'Objetivos',
                      _currentActivity.description),
                  const Divider(color: Colors.white10),
                  _buildDetailItem(Icons.person, 'Responsável',
                      _currentActivity.responsibleName ?? 'Nenhum atribuído'),
                  if (_currentActivity.status == 'completed') ...[
                    const Divider(color: Colors.white10),
                    _buildDetailItem(Icons.check_circle, 'Estado', 'CONCLUÍDA', color: Colors.greenAccent),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_currentActivity.status != 'completed')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _toggleCompletion(),
                icon: const Icon(Icons.check_circle_outline),
                label: const AiTranslatedText('Marcar como Concluída'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                  foregroundColor: Colors.greenAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _toggleCompletion(),
                icon: const Icon(Icons.history),
                label: const AiTranslatedText('Reabrir Atividade'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Metas Mensuráveis'),
              TextButton.icon(
                onPressed: () => _showAddGoalDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const AiTranslatedText('Adicionar Meta'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentActivity.goals.isEmpty)
             const Center(child: Text('Nenhuma meta definida.', style: TextStyle(color: Colors.white24, fontSize: 13))),
          ..._currentActivity.goals.map((goal) => _buildGoalCard(goal)),
          
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Recursos Envolvidos'),
              TextButton.icon(
                onPressed: () => _showAddResourceDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const AiTranslatedText('Adicionar Recurso'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentActivity.resources.isEmpty)
             const Center(child: Text('Nenhum recurso listado.', style: TextStyle(color: Colors.white24, fontSize: 13))),
          ..._currentActivity.resources.map((r) => _buildResourceItem(r)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(ActivityGoal goal) {
    final progress = goal.targetValue > 0 ? (goal.currentValue / goal.targetValue).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(goal.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                Text('${goal.currentValue} / ${goal.targetValue} ${goal.unit}',
                    style: const TextStyle(color: Color(0xFF7B61FF), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7B61FF)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white54),
                  onPressed: () => _showUpdateGoalProgressDialog(goal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceItem(ActivityResource r) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
        child: Icon(r.type == 'human' ? Icons.person : Icons.build, color: const Color(0xFF7B61FF), size: 20),
      ),
      title: Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(
          r.role ?? (r.quantity != null ? 'Qtd: ${r.quantity}' : ''),
          style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
        onPressed: () => _removeResource(r),
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
              AiTranslatedText(
                  '${_currentActivity.participants.length} Participantes',
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
              itemCount: _currentActivity.participants.length,
              itemBuilder: (context, index) {
                final p = _currentActivity.participants[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title:
                      Text(p.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(p.email,
                      style: const TextStyle(color: Colors.white54)),
                  trailing: Text(p.role,
                      style: const TextStyle(
                          color: Color(0xFF7B61FF), fontSize: 10)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaTab() {
    final images =
        _currentActivity.media.where((m) => m.type == 'image').toList();
    final videos =
        _currentActivity.media.where((m) => m.type == 'video').toList();
    final docs =
        _currentActivity.media.where((m) => m.type == 'document').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleFileUpload(),
                  icon: const Icon(Icons.cloud_upload),
                  label: const AiTranslatedText('Adicionar Ficheiros'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B61FF),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSocialMediaPrep(),
                  icon: const Icon(Icons.auto_awesome),
                  label: const AiTranslatedText('Preparar Publicação'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _simulateSocialImpact(),
                  icon: const Icon(Icons.analytics),
                  label: const AiTranslatedText('Analisar Impacto'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_currentActivity.media.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(48.0),
              child: Text('Nenhum ficheiro carregado.',
                  style: TextStyle(color: Colors.white24)),
            )),
          if (images.isNotEmpty) ...[
            _buildExplorerSection('Imagens', images, Icons.image),
            const SizedBox(height: 24),
          ],
          if (videos.isNotEmpty) ...[
            _buildExplorerSection('Vídeos', videos, Icons.videocam),
            const SizedBox(height: 24),
          ],
          if (docs.isNotEmpty) ...[
            _buildExplorerSection('Documentos', docs, Icons.description),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildExplorerSection(
      String title, List<ActivityMedia> items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${items.length} itens',
                style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 100,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.70),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _buildMediaExplorerItem(items[index]),
        ),
      ],
    );
  }

  Widget _buildMediaExplorerItem(ActivityMedia m) {
    final isSelected = _selectedMediaIds.contains(m.id);
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected)
              _selectedMediaIds.remove(m.id);
            else
              _selectedMediaIds.add(m.id);
          });
        } else {
          _previewMedia(m);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedMediaIds.add(m.id);
          });
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected ? const Color(0xFF7B61FF) : Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: m.type == 'image'
                        ? Image.network(m.url,
                            width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Center(
                                child: Icon(Icons.image,
                                    color: Colors.white10)))
                        : Container(
                            color: Colors.white.withValues(alpha: 0.02),
                            child: Center(
                                child: Icon(_getMediaIcon(m.type),
                                    color: Colors.white24, size: 32)),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleMediaSelection(m, forSocial: true, forReport: false),
                            child: _buildTagIcon(m.isSocialMediaSelected, Icons.share, Colors.blueAccent, 'Social'),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _toggleMediaSelection(m, forSocial: false, forReport: true),
                            child: _buildTagIcon(m.isAnnualReportSelected, Icons.assignment, Colors.orangeAccent, 'Rel'),
                          ),
                          const Spacer(),
                          if (!_isSelectionMode)
                            GestureDetector(
                                onTap: () => _confirmDeleteMedia(m),
                                child: const Icon(Icons.close,
                                    color: Colors.redAccent, size: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? const Color(0xFF7B61FF) : Colors.white24,
                size: 20,
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4)),
              child: Icon(_getVisibilityIcon(m.visibility),
                  size: 8, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagIcon(
      bool active, IconData icon, Color color, String tooltip) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: active ? color : Colors.white10, size: 12),
    );
  }

  void _toggleMediaSelection(ActivityMedia media, {required bool forSocial, required bool forReport}) async {
    final updatedMedia = ActivityMedia(
      id: media.id,
      name: media.name,
      url: media.url,
      type: media.type,
      visibility: media.visibility,
      uploadedAt: media.uploadedAt,
      isSocialMediaSelected: forSocial ? !media.isSocialMediaSelected : media.isSocialMediaSelected,
      isAnnualReportSelected: forReport ? !media.isAnnualReportSelected : media.isAnnualReportSelected,
    );
    
    final newMediaList = _currentActivity.media.map((m) => m.id == media.id ? updatedMedia : m).toList();
    
    final updatedActivity = InstitutionalActivity(
      id: _currentActivity.id,
      title: _currentActivity.title,
      description: _currentActivity.description,
      institutionId: _currentActivity.institutionId,
      startDate: _currentActivity.startDate,
      endDate: _currentActivity.endDate,
      startTime: _currentActivity.startTime,
      endTime: _currentActivity.endTime,
      activityGroup: _currentActivity.activityGroup,
      hasFinancialImpact: _currentActivity.hasFinancialImpact,
      resources: _currentActivity.resources,
      participants: _currentActivity.participants,
      media: newMediaList,
      goals: _currentActivity.goals,
      financials: _currentActivity.financials,
      indicators: _currentActivity.indicators,
      status: _currentActivity.status,
    );
    
    setState(() => _currentActivity = updatedActivity);
    await context.read<FirebaseService>().saveActivity(updatedActivity);
  }

  void _previewMedia(ActivityMedia media) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            if (media.type == 'image')
              Image.network(media.url, fit: BoxFit.contain)
            else
              Container(
                padding: const EdgeInsets.all(32),
                color: const Color(0xFF1E293B),
                child: Column(
                  children: [
                    Icon(_getMediaIcon(media.type),
                        color: Colors.white24, size: 64),
                    const SizedBox(height: 16),
                    Text(media.name,
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 24),
                    const AiTranslatedText('Pré-visualização não suportada.',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSocialMediaPrep() {
    final selectedMedia = _currentActivity.media
        .where((m) => m.isSocialMediaSelected)
        .toList();

    String platform = 'Facebook';
    String generatedContent = '';
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF10B981)),
              const SizedBox(width: 12),
              const AiTranslatedText('Preparar Publicação',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AiTranslatedText('Ficheiros Selecionados:',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (selectedMedia.isEmpty)
                    const Text('Nenhum ficheiro marcado para Redes Sociais.',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11))
                  else
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedMedia.length,
                        itemBuilder: (context, index) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: selectedMedia[index].type == 'image'
                                ? DecorationImage(
                                    image: NetworkImage(selectedMedia[index].url),
                                    fit: BoxFit.cover)
                                : null,
                            color: Colors.white10,
                          ),
                          child: selectedMedia[index].type != 'image'
                              ? Icon(_getMediaIcon(selectedMedia[index].type),
                                  color: Colors.white24, size: 20)
                              : null,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const AiTranslatedText('Escolher Plataforma:',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Facebook', label: Text('FB')),
                      ButtonSegment(value: 'Instagram', label: Text('IG')),
                      ButtonSegment(value: 'TikTok', label: Text('TK')),
                    ],
                    selected: {platform},
                    onSelectionChanged: (val) =>
                        setDialogState(() => platform = val.first),
                  ),
                  const SizedBox(height: 24),
                  if (isGenerating)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ))
                  else if (generatedContent.isEmpty)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setDialogState(() => isGenerating = true);
                          final ai = context.read<AiChatService>();
                          final post = await ai.generateSocialMediaPosts(
                            title: _currentActivity.title,
                            description: _currentActivity.description,
                            platform: platform,
                          );
                          setDialogState(() {
                            generatedContent = post;
                            isGenerating = false;
                          });
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const AiTranslatedText('Gerar Conteúdo com IA'),
                      ),
                    )
                  else ...[
                    const AiTranslatedText('Conteúdo Proposto:',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller:
                          TextEditingController(text: generatedContent),
                      onChanged: (val) => generatedContent = val,
                      maxLines: 6,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (generatedContent.isNotEmpty) ...[
              IconButton(
                onPressed: () async {
                  try {
                    await MarketingExportHelper.downloadPdf(_currentActivity, platform, generatedContent);
                  } catch (e) {
                    debugPrint('Erro a gerar PDF: $e');
                  }
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                tooltip: 'Download Relatório PDF',
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await MarketingExportHelper.downloadZip(_currentActivity, platform, generatedContent);
                  } catch (e) {
                    debugPrint('Erro a gerar ZIP: $e');
                  }
                },
                icon: const Icon(Icons.folder_zip, color: Colors.orangeAccent),
                tooltip: 'Download Arquivo Completo (.zip)',
              ),
            ],
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white70))),
            if (generatedContent.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: generatedContent));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: AiTranslatedText(
                          'Texto copiado para a área de transferência! Cole na sua rede social ($platform).'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                child: const AiTranslatedText('Publicar'),
              ),
          ],
        ),
      ),
    );
  }


  // Dialogs & Logic
  
  void _simulateSocialImpact() async {
    final impact = {
      'facebook_reach': 1250,
      'instagram_likes': 345,
      'tiktok_views': 2100,
      'overall_sentiment': 'Muito Positivo',
      'generated_at': DateTime.now().toIso8601String(),
    };
    
    final updated = InstitutionalActivity(
      id: _currentActivity.id,
      title: _currentActivity.title,
      description: _currentActivity.description,
      institutionId: _currentActivity.institutionId,
      startDate: _currentActivity.startDate,
      endDate: _currentActivity.endDate,
      startTime: _currentActivity.startTime,
      endTime: _currentActivity.endTime,
      activityGroup: _currentActivity.activityGroup,
      hasFinancialImpact: _currentActivity.hasFinancialImpact,
      resources: _currentActivity.resources,
      participants: _currentActivity.participants,
      media: _currentActivity.media,
      goals: _currentActivity.goals,
      financials: _currentActivity.financials,
      indicators: _currentActivity.indicators,
      status: _currentActivity.status,
      responsibleName: _currentActivity.responsibleName,
      responsibleEmail: _currentActivity.responsibleEmail,
      responsiblePhone: _currentActivity.responsiblePhone,
      socialMediaImpact: impact,
    );
    
    setState(() => _currentActivity = updated);
    await context.read<FirebaseService>().saveActivity(updated);
    
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Relatório de Impacto (Simulação)', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alcance Facebook: ${impact['facebook_reach']}', style: const TextStyle(color: Colors.white)),
              Text('Likes Instagram: ${impact['instagram_likes']}', style: const TextStyle(color: Colors.white)),
              Text('Views TikTok: ${impact['tiktok_views']}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              const AiTranslatedText('Estes dados foram anexados à atividade e constarão no relatório anual institucional.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const AiTranslatedText('Fechar', style: TextStyle(color: Colors.white70))
            ),
          ],
        ),
      );
    }
  }

  void _showAddGoalDialog() {
    final descController = TextEditingController();
    final targetController = TextEditingController();
    final unitController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Meta Mensurável', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descrição da Meta'), style: const TextStyle(color: Colors.white)),
            TextField(controller: targetController, decoration: const InputDecoration(labelText: 'Valor Alvo'), style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number),
            TextField(controller: unitController, decoration: const InputDecoration(labelText: 'Unidade (ex: Alunos, €, %)'), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.isEmpty || targetController.text.isEmpty) return;
              final goal = ActivityGoal(
                id: const Uuid().v4(),
                description: descController.text,
                targetValue: double.tryParse(targetController.text) ?? 0.0,
                unit: unitController.text,
              );
              final updated = InstitutionalActivity(
                id: _currentActivity.id,
                title: _currentActivity.title,
                description: _currentActivity.description,
                institutionId: _currentActivity.institutionId,
                startDate: _currentActivity.startDate,
                endDate: _currentActivity.endDate,
                startTime: _currentActivity.startTime,
                endTime: _currentActivity.endTime,
                activityGroup: _currentActivity.activityGroup,
                hasFinancialImpact: _currentActivity.hasFinancialImpact,
                resources: _currentActivity.resources,
                participants: _currentActivity.participants,
                media: _currentActivity.media,
                goals: [..._currentActivity.goals, goal],
                financials: _currentActivity.financials,
                indicators: _currentActivity.indicators,
                status: _currentActivity.status,
              );
              await context.read<FirebaseService>().saveActivity(updated);
              Navigator.pop(ctx);
              _refreshActivity();
            },
            child: const AiTranslatedText('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showUpdateGoalProgressDialog(ActivityGoal goal) {
    final progressController = TextEditingController(text: goal.currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Atualizar Progresso', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: progressController,
          decoration: InputDecoration(labelText: 'Valor Atual (${goal.unit})'),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(progressController.text) ?? goal.currentValue;
              final newGoals = _currentActivity.goals.map((g) {
                if (g.id == goal.id) {
                  return ActivityGoal(
                    id: g.id,
                    description: g.description,
                    targetValue: g.targetValue,
                    currentValue: val,
                    unit: g.unit,
                  );
                }
                return g;
              }).toList();

              final updated = InstitutionalActivity(
                id: _currentActivity.id,
                title: _currentActivity.title,
                description: _currentActivity.description,
                institutionId: _currentActivity.institutionId,
                startDate: _currentActivity.startDate,
                endDate: _currentActivity.endDate,
                startTime: _currentActivity.startTime,
                endTime: _currentActivity.endTime,
                activityGroup: _currentActivity.activityGroup,
                hasFinancialImpact: _currentActivity.hasFinancialImpact,
                resources: _currentActivity.resources,
                participants: _currentActivity.participants,
                media: _currentActivity.media,
                goals: newGoals,
                financials: _currentActivity.financials,
                indicators: _currentActivity.indicators,
                status: _currentActivity.status,
              );
              await context.read<FirebaseService>().saveActivity(updated);
              Navigator.pop(ctx);
              _refreshActivity();
            },
            child: const AiTranslatedText('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _showAddResourceDialog() {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    String type = 'human';
    List<Classroom> selectedRooms = [];
    DateTime rStartDate = _currentActivity.startDate;
    DateTime rEndDate = _currentActivity.endDate;
    
    TimeOfDay parseInitialTime(String t) {
      if (t.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
      try {
        final p = t.split(':');
        return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[p.length > 1 ? 1 : 0]));
      } catch (_) {
        return const TimeOfDay(hour: 9, minute: 0);
      }
    }
    
    TimeOfDay rStartTime = parseInitialTime(_currentActivity.startTime);
    TimeOfDay rEndTime = parseInitialTime(_currentActivity.endTime);

    int calcDuration(TimeOfDay start, TimeOfDay end) {
      int sMins = start.hour * 60 + start.minute;
      int eMins = end.hour * 60 + end.minute;
      if (eMins <= sMins) return 60; // fallback
      return eMins - sMins;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Adicionar Recurso', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'human', child: Text('Humano (Colaborador/Prof)')),
                    DropdownMenuItem(value: 'material', child: Text('Material (Equipamento)')),
                    DropdownMenuItem(value: 'consumable', child: Text('Consumível')),
                    DropdownMenuItem(value: 'room', child: Text('Espaço / Sala')),
                  ],
                  onChanged: (val) => setDialogState(() => type = val!),
                  decoration: const InputDecoration(labelText: 'Tipo', labelStyle: TextStyle(color: Colors.white54)),
                ),
                
                if (type == 'room') ...[
                  const SizedBox(height: 16),
                  const AiTranslatedText('Selecione as Salas', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Classroom>>(
                    stream: context.read<FirebaseService>().getClassrooms(widget.institution.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                      final rooms = snapshot.data ?? [];
                      if (rooms.isEmpty) {
                         return const Text("Nenhuma sala disponível. Adicione nas Instalações.", style: TextStyle(color: Colors.redAccent, fontSize: 12));
                      }
                      return Wrap(
                        spacing: 8,
                        children: rooms.map((room) {
                          final isSelected = selectedRooms.any((r) => r.id == room.id);
                          return FilterChip(
                            label: Text(room.name, style: const TextStyle(color: Colors.white)),
                            selected: isSelected,
                            selectedColor: const Color(0xFF7B61FF),
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.white10,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedRooms.add(room);
                                } else {
                                  selectedRooms.removeWhere((r) => r.id == room.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Data Inicial', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text("${rStartDate.day}/${rStartDate.month}/${rStartDate.year}", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: rStartDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) setDialogState(() => rStartDate = date);
                    },
                  ),
                  ListTile(
                    title: const Text('Data Final', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    subtitle: Text("${rEndDate.day}/${rEndDate.month}/${rEndDate.year}", style: const TextStyle(color: Colors.white)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.white54),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: rEndDate,
                        firstDate: rStartDate,
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) setDialogState(() => rEndDate = date);
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Início', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          subtitle: Text(rStartTime.format(context), style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.access_time, color: Colors.white54),
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: rStartTime);
                            if (time != null) setDialogState(() => rStartTime = time);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListTile(
                          title: const Text('Fim', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          subtitle: Text(rEndTime.format(context), style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.access_time, color: Colors.white54),
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: rEndTime);
                            if (time != null) setDialogState(() => rEndTime = time);
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do Recurso/Pessoa'), style: const TextStyle(color: Colors.white)),
                  TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Papel ou Quantidade'), style: const TextStyle(color: Colors.white)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white70))
            ),
            ElevatedButton(
              onPressed: () async {
                final svc = context.read<FirebaseService>();
                List<ActivityResource> newRes = List.from(_currentActivity.resources);
                
                if (type == 'room') {
                  if (selectedRooms.isEmpty) return;
                  
                  for (var room in selectedRooms) {
                    newRes.add(ActivityResource(
                      id: const Uuid().v4(),
                      name: 'Sala/Espaço: ${room.name}',
                      type: 'room',
                      role: 'Reservado: ${rStartDate.day}/${rStartDate.month} a ${rEndDate.day}/${rEndDate.month}',
                    ));
                    
                    DateTime current = DateTime(rStartDate.year, rStartDate.month, rStartDate.day);
                    DateTime end = DateTime(rEndDate.year, rEndDate.month, rEndDate.day);
                    
                    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                      final entry = TimetableEntry(
                        id: const Uuid().v4(),
                        classroomId: room.id,
                        weekday: current.weekday,
                        startTime: '${rStartTime.hour.toString().padLeft(2, '0')}:${rStartTime.minute.toString().padLeft(2, '0')}',
                        durationMinutes: calcDuration(rStartTime, rEndTime),
                        institutionId: _currentActivity.institutionId,
                        customActivityName: 'Atividade: ${_currentActivity.title}',
                        startDate: current,
                        endDate: current,
                      );
                      await svc.saveTimetableEntry(entry);
                      current = current.add(const Duration(days: 1));
                    }
                  }
                } else {
                  if (nameController.text.isEmpty) return;
                  newRes.add(ActivityResource(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    type: type,
                    role: roleController.text,
                  ));
                }
                
                final updated = InstitutionalActivity(
                  id: _currentActivity.id,
                  title: _currentActivity.title,
                  description: _currentActivity.description,
                  institutionId: _currentActivity.institutionId,
                  startDate: _currentActivity.startDate,
                  endDate: _currentActivity.endDate,
                  startTime: _currentActivity.startTime,
                  endTime: _currentActivity.endTime,
                  activityGroup: _currentActivity.activityGroup,
                  hasFinancialImpact: _currentActivity.hasFinancialImpact,
                  resources: newRes,
                  participants: _currentActivity.participants,
                  media: _currentActivity.media,
                  goals: _currentActivity.goals,
                  financials: _currentActivity.financials,
                  indicators: _currentActivity.indicators,
                  status: _currentActivity.status,
                  responsibleName: _currentActivity.responsibleName,
                  responsibleEmail: _currentActivity.responsibleEmail,
                  responsiblePhone: _currentActivity.responsiblePhone,
                  socialMediaImpact: _currentActivity.socialMediaImpact,
                );
                
                await svc.saveActivity(updated);
                
                if (context.mounted) {
                  Navigator.pop(ctx);
                  _refreshActivity();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AiTranslatedText('Recurso(s) gravado(s) e bloqueado(s) no horário com sucesso.'), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: const AiTranslatedText('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeResource(ActivityResource r) async {
    final updated = InstitutionalActivity(
      id: _currentActivity.id,
      title: _currentActivity.title,
      description: _currentActivity.description,
      institutionId: _currentActivity.institutionId,
      startDate: _currentActivity.startDate,
      endDate: _currentActivity.endDate,
      startTime: _currentActivity.startTime,
      endTime: _currentActivity.endTime,
      activityGroup: _currentActivity.activityGroup,
      hasFinancialImpact: _currentActivity.hasFinancialImpact,
      resources: _currentActivity.resources.where((item) => item.name != r.name).toList(),
      participants: _currentActivity.participants,
      media: _currentActivity.media,
      goals: _currentActivity.goals,
      financials: _currentActivity.financials,
      indicators: _currentActivity.indicators,
      status: _currentActivity.status,
    );
    await context.read<FirebaseService>().saveActivity(updated);
    _refreshActivity();
  }

  void _showEditDetailsDialog() {
    final descController = TextEditingController(text: _currentActivity.description);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Editar Objetivos', style: TextStyle(color: Colors.white)),
        content: AiTextField(
          controller: descController,
          maxLines: 5,
          labelText: 'Objetivos da Atividade',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final updated = InstitutionalActivity(
                id: _currentActivity.id,
                title: _currentActivity.title,
                description: descController.text,
                institutionId: _currentActivity.institutionId,
                startDate: _currentActivity.startDate,
                endDate: _currentActivity.endDate,
                startTime: _currentActivity.startTime,
                endTime: _currentActivity.endTime,
                activityGroup: _currentActivity.activityGroup,
                hasFinancialImpact: _currentActivity.hasFinancialImpact,
                resources: _currentActivity.resources,
                participants: _currentActivity.participants,
                media: _currentActivity.media,
                goals: _currentActivity.goals,
                financials: _currentActivity.financials,
                indicators: _currentActivity.indicators,
                status: _currentActivity.status,
              );
              await context.read<FirebaseService>().saveActivity(updated);
              Navigator.pop(ctx);
              _refreshActivity();
            },
            child: const AiTranslatedText('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMedia(ActivityMedia media) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Confirmar Eliminação'),
        content: AiTranslatedText('Deseja eliminar o ficheiro "${media.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<FirebaseService>().removeActivityMedia(_currentActivity.id, media);
      _refreshActivity();
    }
  }

  void _confirmBulkDelete() async {
    final count = _selectedMediaIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Confirmar Eliminação'),
        content: AiTranslatedText('Deseja eliminar os $count ficheiros selecionados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const AiTranslatedText('Eliminar Todos', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      final mediaToDelete = _currentActivity.media.where((m) => _selectedMediaIds.contains(m.id)).toList();
      await context.read<FirebaseService>().bulkRemoveActivityMedia(_currentActivity.id, mediaToDelete);
      setState(() {
        _isSelectionMode = false;
        _selectedMediaIds.clear();
      });
      _refreshActivity();
    }
  }

  void _handleFileUpload() async {
    // 1. Visivilidade Selector
    ActivityVisibility? visibility = await showDialog<ActivityVisibility>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Quem pode visualizar?',
            style: TextStyle(color: Colors.white)),
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

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null) {
      final service = context.read<FirebaseService>();
      for (var file in result.files) {
        Uint8List? fileBytes;
        if (kIsWeb) {
          fileBytes = file.bytes;
        } else {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null) {
          final downloadUrl = await service.uploadContentFile(fileBytes, file.name);
          if (downloadUrl != null) {
            String type = 'other';
            final ext = file.extension?.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) type = 'image';
            else if (['mp4', 'mov', 'avi'].contains(ext)) type = 'video';
            else if (['mp3', 'wav', 'm4a'].contains(ext)) type = 'audio';
            else if (ext == 'pdf') type = 'pdf';

            final newMedia = ActivityMedia(
              id: const Uuid().v4(),
              name: file.name,
              url: downloadUrl,
              type: type,
              visibility: visibility,
              uploadedAt: DateTime.now(),
            );
            await service.updateActivityMedia(_currentActivity.id, newMedia);
          }
        }
      }
      _refreshActivity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Upload concluído.')));
      }
    }
  }

  void _showInviteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Convidar por Grupo',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInviteOption(Icons.person, 'Pessoal Docente',
                () => _showSpecializedSelector(ParticipantGroupType.docentes)),
            _buildInviteOption(Icons.people_outline, 'Pessoal Não Docente',
                () => _showSpecializedSelector(ParticipantGroupType.naoDocentes)),
            _buildInviteOption(Icons.groups, 'Membros de Orgãos',
                () => _showSpecializedSelector(ParticipantGroupType.orgaos)),
            _buildInviteOption(Icons.school, 'Alunos',
                () => _showSpecializedSelector(ParticipantGroupType.alunos)),
            _buildInviteOption(Icons.family_restroom, 'Encarregados',
                () => _showSpecializedSelector(ParticipantGroupType.encarregados)),
            _buildInviteOption(Icons.business, 'Toda a Instituição',
                () => _inviteAllInstitution()),
            _buildInviteOption(
                Icons.school, 'Por Curso (Legacy)', () => _showCourseSelector()),
            _buildInviteOption(
                Icons.book, 'Por Disciplina (Legacy)', () => _showSubjectSelector()),
          ],
        ),
      ),
    );
  }

  void _showSpecializedSelector(ParticipantGroupType type) async {
    final List<String>? selectedEmails = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => ParticipantSelectorDialog(
        institutionId: widget.institution.id,
        initialSelectedEmails: _currentActivity.participants.map((p) => p.email).toList(),
      ),
    );

    if (selectedEmails != null && selectedEmails.isNotEmpty) {
      final service = context.read<FirebaseService>();
      // We need to fetch the UserModels for these emails to invite them properly
      // Or we can add a service method that accepts emails
      final allMembers = await service.getAllInstitutionMembers(widget.institution.id);
      final selectedUsers = allMembers.where((u) => selectedEmails.contains(u.email)).toList();
      
      await service.inviteGroupToActivity(
        _currentActivity.id, 
        'group_${type.name}', 
        type.name, 
        selectedUsers
      );
      _refreshActivity();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: AiTranslatedText(
                'Convidados ${selectedUsers.length} participantes.')));
      }
    }
  }

  Widget _buildInviteOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF7B61FF)),
      title:
          AiTranslatedText(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _inviteAllInstitution() async {
    final service = context.read<FirebaseService>();
    final members =
        await service.getAllInstitutionMembers(widget.institution.id);
    await service.inviteGroupToActivity(
        _currentActivity.id, 'institution', widget.institution.id, members);
    _refreshActivity();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: AiTranslatedText(
            'Convitados ${members.length} membros da instituição.')));
  }

  void _showCourseSelector() {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Selecionar Curso',
            style: TextStyle(color: Colors.white)),
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
                  title: Text(courses[index].name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const AiTranslatedText('Confirmar Convite',
                            style: TextStyle(color: Colors.white)),
                        content: AiTranslatedText(
                            'Deseja convidar todos os membros do curso ${courses[index].name}?',
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const AiTranslatedText('Cancelar',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const AiTranslatedText('Convidar',
                                style: TextStyle(color: Colors.blueAccent)),
                          ),
                        ],
                      ),
                    );
                    if (!mounted || confirm != true) return;
                    final members = await service.getCourseMembers(
                        widget.institution.id, courses[index].id);
                    await service.inviteGroupToActivity(_currentActivity.id,
                        'course', courses[index].id, members);
                    _refreshActivity();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: AiTranslatedText(
                  'Convitados ${members.length} membros do curso ${courses[index].name}.')));
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
        title: const AiTranslatedText('Selecionar Disciplina',
            style: TextStyle(color: Colors.white)),
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
                  title: Text(subjects[index].name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final members = await service.getSubjectMembers(
                        widget.institution.id, subjects[index].id);
                    await service.inviteGroupToActivity(_currentActivity.id,
                        'subject', subjects[index].id, members);
                    _refreshActivity();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: AiTranslatedText(
                              'Convitados ${members.length} membros da disciplina ${subjects[index].name}.')));
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

  Widget _buildSectionTitle(String title) {
    return AiTranslatedText(title,
        style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiTranslatedText(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(value,
                  style: TextStyle(
                      color: color ?? Colors.white,
                      fontSize: 14,
                      fontWeight: color != null ? FontWeight.bold : null)),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getMediaIcon(String type) {
    if (type == 'image') return Icons.image;
    if (type == 'video') return Icons.videocam;
    if (type == 'audio') return Icons.audiotrack;
    if (type == 'pdf') return Icons.picture_as_pdf;
    return Icons.description;
  }

  IconData _getVisibilityIcon(ActivityVisibility v) {
    if (v == ActivityVisibility.public) return Icons.public;
    if (v == ActivityVisibility.wholeInstitution) return Icons.business;
    return Icons.lock;
  }

  Widget _buildWallTab() {
    return const Center(
        child: AiTranslatedText('Mural de Comunicação - Em breve',
            style: TextStyle(color: Colors.white54)));
  }

  Widget _buildFinancialsTab() {
    final income = _currentActivity.financials
        .where((f) => f.type == 'income')
        .fold(0.0, (sum, f) => sum + f.amount);
    final expenses = _currentActivity.financials
        .where((f) => f.type == 'expense')
        .fold(0.0, (sum, f) => sum + f.amount);
    final balance = income - expenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Resumo Financeiro'),
              TextButton.icon(
                onPressed: () => _showAddFinancialRecordDialog(),
                icon: const Icon(Icons.add),
                label: const AiTranslatedText('Adicionar Lançamento'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFinancialSummary(income, expenses, balance),
          const SizedBox(height: 32),
          _buildSectionTitle('Lançamentos'),
          const SizedBox(height: 12),
          if (_currentActivity.financials.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Nenhum movimento registado.',
                  style: TextStyle(color: Colors.white24)),
            )),
          ..._currentActivity.financials
              .map((f) => _buildFinancialRecordCard(f)),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(
      double income, double expenses, double balance) {
    return Row(
      children: [
        Expanded(
            child: _buildSummaryCard(
                'Receitas', income, Colors.greenAccent, Icons.trending_up)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildSummaryCard(
                'Gastos', expenses, Colors.redAccent, Icons.trending_down)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildSummaryCard(
                'Resultado',
                balance,
                balance >= 0 ? Colors.blueAccent : Colors.orangeAccent,
                Icons.account_balance_wallet)),
      ],
    );
  }

  Widget _buildSummaryCard(
      String label, double value, Color color, IconData icon) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
            const SizedBox(height: 8),
            AiTranslatedText(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                '${value.toStringAsFixed(2)} €',
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRecordCard(ActivityFinancialRecord record) {
    final isIncome = record.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isIncome ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isIncome ? Colors.greenAccent : Colors.redAccent,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.category,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Text(record.description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? "+" : "-"}${record.amount.toStringAsFixed(2)} €',
                style: TextStyle(
                  color: isIncome ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white24, size: 20),
                onPressed: () => _removeFinancialRecord(record),
              ),
            ],
          ),
          if (record.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.comment,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (record.documentUrl != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // TODO: Open document
              },
              icon: const Icon(Icons.description, size: 14),
              label: const Text('Ver Documento', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7B61FF),
                  padding: EdgeInsets.zero),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddFinancialRecordDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final commentController = TextEditingController();
    final originController = TextEditingController();
    String type = 'expense';
    String category = 'Consumíveis';
    String? selectedDocUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Novo Lançamento',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'income',
                        label: Text('Receita'),
                        icon: Icon(Icons.trending_up)),
                    ButtonSegment(
                        value: 'expense',
                        label: Text('Gasto'),
                        icon: Icon(Icons.trending_down)),
                  ],
                  selected: {type},
                  onSelectionChanged: (val) =>
                      setDialogState(() => type = val.first),
                ),
                const SizedBox(height: 16),
                if (type == 'expense')
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                          value: 'Consumíveis', child: Text('Consumíveis')),
                      DropdownMenuItem(
                          value: 'Subcontratação',
                          child: Text('Subcontratação')),
                      DropdownMenuItem(
                          value: 'Alugueres', child: Text('Alugueres')),
                      DropdownMenuItem(
                          value: 'Transportes', child: Text('Transportes')),
                      DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                    ],
                    onChanged: (val) => setDialogState(() => category = val!),
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  )
                else
                  TextField(
                    controller: originController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        labelText: 'Origem da Receita',
                        hintText: 'Ex: Bilheteira, Patrocínio...'),
                  ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Valor (€)', prefixText: '€ '),
                ),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      const InputDecoration(labelText: 'Descrição/Explicação'),
                ),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Comentário'),
                ),
                const SizedBox(height: 16),
                if (_currentActivity.media.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedDocUrl,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    hint: const Text('Anexar Documento',
                        style: TextStyle(color: Colors.white54)),
                    items: _currentActivity.media
                        .map((m) => DropdownMenuItem(
                            value: m.url, child: Text(m.name)))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedDocUrl = val),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isEmpty) return;
                final record = ActivityFinancialRecord(
                  id: const Uuid().v4(),
                  type: type,
                  category: type == 'income'
                      ? (originController.text.isEmpty
                          ? 'Receita'
                          : originController.text)
                      : category,
                  amount: double.tryParse(amountController.text) ?? 0.0,
                  description: descController.text,
                  comment: commentController.text,
                  documentUrl: selectedDocUrl,
                  date: DateTime.now(),
                );
                final updated = InstitutionalActivity(
                  id: _currentActivity.id,
                  title: _currentActivity.title,
                  description: _currentActivity.description,
                  institutionId: _currentActivity.institutionId,
                  startDate: _currentActivity.startDate,
                  endDate: _currentActivity.endDate,
                  startTime: _currentActivity.startTime,
                  endTime: _currentActivity.endTime,
                  activityGroup: _currentActivity.activityGroup,
                  hasFinancialImpact: _currentActivity.hasFinancialImpact,
                  resources: _currentActivity.resources,
                  participants: _currentActivity.participants,
                  media: _currentActivity.media,
                  goals: _currentActivity.goals,
                  financials: [..._currentActivity.financials, record],
                  indicators: _currentActivity.indicators,
                  status: _currentActivity.status,
                );
                await context.read<FirebaseService>().saveActivity(updated);
                Navigator.pop(ctx);
                _refreshActivity();
              },
              child: const AiTranslatedText('Registar'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeFinancialRecord(ActivityFinancialRecord record) async {
    final updated = InstitutionalActivity(
      id: _currentActivity.id,
      title: _currentActivity.title,
      description: _currentActivity.description,
      institutionId: _currentActivity.institutionId,
      startDate: _currentActivity.startDate,
      endDate: _currentActivity.endDate,
      startTime: _currentActivity.startTime,
      endTime: _currentActivity.endTime,
      activityGroup: _currentActivity.activityGroup,
      hasFinancialImpact: _currentActivity.hasFinancialImpact,
      resources: _currentActivity.resources,
      participants: _currentActivity.participants,
      media: _currentActivity.media,
      goals: _currentActivity.goals,
      financials:
          _currentActivity.financials.where((f) => f.id != record.id).toList(),
      indicators: _currentActivity.indicators,
      status: _currentActivity.status,
    );
    await context.read<FirebaseService>().saveActivity(updated);
    _refreshActivity();
  }
}
