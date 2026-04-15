import 'package:flutter/material.dart';
import '../../widgets/ai_translated_text.dart';
import '../../services/firebase_service.dart';
import '../../models/organ_document_model.dart';
import '../../models/institutional_organ_model.dart';
import 'package:provider/provider.dart';

class OtherDashboard extends StatelessWidget {
  const OtherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AiTranslatedText('Painel de Membro Externo'),
        actions: [
          Tooltip(
            message: 'Sair da aplicação e voltar ao login',
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Bem-vindo ao seu espaço de trabalho.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const AiTranslatedText(
              'Aqui poderá consultar as atas e documentos dos órgãos sociais a que pertence.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _DashboardCard(
                    icon: Icons.description,
                    title: 'Atas e Documentos',
                    onTap: () => _showOrgansAndDocuments(context),
                  ),
                  _DashboardCard(
                    icon: Icons.mail,
                    title: 'Correspondência',
                    onTap: () {
                      // Implement messaging
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.person,
                    title: 'Dados Pessoais',
                    onTap: () {
                      // Implement profile edit
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrgansAndDocuments(BuildContext context) {
    final service = context.read<FirebaseService>();
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E2E),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Os Meus Órgãos e Documentos',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<List<InstitutionalOrgan>>(
                        stream: service.getInstitutionalOrgans(
                            'default_institution'), // Placeholder
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          final organs = snapshot.data!;
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: organs.length,
                            itemBuilder: (context, index) {
                              final organ = organs[index];
                              return ExpansionTile(
                                title: Text(organ.name,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                children: [
                                  StreamBuilder<List<OrganDocument>>(
                                    stream: service.getDocumentsForMember(
                                        organ.id, "current_user", false),
                                    builder: (context, docSnapshot) {
                                      if (!docSnapshot.hasData)
                                        return const SizedBox.shrink();
                                      final docs = docSnapshot.data!;
                                      if (docs.isEmpty)
                                        return const Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Text(
                                                'Nenhum documento disponível.',
                                                style: TextStyle(
                                                    color: Colors.white54)));
                                      return Column(
                                        children: docs
                                            .map((doc) => ListTile(
                                                  leading: const Icon(
                                                      Icons.file_present,
                                                      color: Colors.white38),
                                                  title: Text(doc.title,
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.white70)),
                                                  subtitle: Text(
                                                      doc.type.name
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                          color: Colors.white24,
                                                          fontSize: 10)),
                                                  onTap: () {},
                                                ))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        });
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Clique para abrir $title',
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF7B61FF)),
              const SizedBox(height: 12),
              AiTranslatedText(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              AiTranslatedText(
                'Abrir $title',
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
