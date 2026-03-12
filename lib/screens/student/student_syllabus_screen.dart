import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentSyllabusScreen extends StatelessWidget {
  final Subject subject;
  const StudentSyllabusScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final finalizedSessions = subject.sessions.where((s) => s.isFinalized).toList();
    finalizedSessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

    final indicativeSessions = List<SyllabusSession>.from(subject.sessions);
    indicativeSessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: AiTranslatedText('Download do programa em desenvolvimento.'))
              );
            },
            icon: const Icon(Icons.download),
            label: const AiTranslatedText('Download Programa da Disciplina'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(child: AiTranslatedText('Programa Indicativo')),
                    Tab(child: AiTranslatedText('Sumários das Aulas')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildIndicativeProgram(context, indicativeSessions),
                      _buildSummariesList(context, finalizedSessions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicativeProgram(BuildContext context, List<SyllabusSession> sessions) {
    if (sessions.isEmpty) {
      return const Center(child: AiTranslatedText('Nenhum programa disponível.', style: TextStyle(color: Colors.white54)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          columns: const [
            DataColumn(label: AiTranslatedText('Sessão')),
            DataColumn(label: AiTranslatedText('Data')),
            DataColumn(label: AiTranslatedText('Tópico')),
            DataColumn(label: AiTranslatedText('Materiais')),
          ],
          rows: sessions.map((s) {
            return DataRow(cells: [
              DataCell(Text(s.sessionNumber.toString())),
              DataCell(Text(DateFormat('dd/MM/yyyy').format(s.date))),
              DataCell(SizedBox(width: 200, child: Text(s.topic, maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white54),
                  onPressed: () => _showSessionDetails(context, s),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummariesList(BuildContext context, List<SyllabusSession> sessions) {
    if (sessions.isEmpty) {
      return const Center(child: AiTranslatedText('Nenhum sumário finalizado.', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF7B61FF).withOpacity(0.2),
                      child: Text(session.sessionNumber.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF7B61FF), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    AiTranslatedText(DateFormat('dd/MM/yyyy').format(session.date), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                AiTranslatedText(session.topic, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 32, color: Colors.white10),
                const AiTranslatedText('SUMÁRIO:', style: TextStyle(color: Color(0xFF00D1FF), fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(session.finalSummary ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                if (session.materialIds.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const AiTranslatedText('MATERIAIS DA SESSÃO:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: session.materialIds.map((id) {
                      final content = subject.contents.firstWhere((c) => c.id == id, orElse: () => SubjectContent(id: '', name: 'Desconhecido', url: '', type: ''));
                      if (content.id.isEmpty) return const SizedBox();
                      return ActionChip(
                        label: Text(content.name, style: const TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final uri = Uri.tryParse(content.url);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        backgroundColor: Colors.white.withOpacity(0.05),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSessionDetails(BuildContext context, SyllabusSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText('Sessão ${session.sessionNumber}: ${session.topic}', style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('Data:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text(DateFormat('dd/MM/yyyy').format(session.date), style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            const AiTranslatedText('Bibliografia Recomendada:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text(session.bibliography, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Fechar')),
        ],
      ),
    );
  }
}
