import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';

class DocumentRepositoryScreen extends StatelessWidget {
  final InstitutionModel institution;
  const DocumentRepositoryScreen({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Repositório Documental'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Regulamentos e Manuais',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file,
                        color: Color(0xFF00FF85))),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<InstitutionalDocument>>(
                stream: service.getDocuments(institution.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!;
                  if (docs.isEmpty)
                    return const Center(
                        child: AiTranslatedText('Nenhum documento disponível.',
                            style: TextStyle(color: Colors.white54)));

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) =>
                        _DocumentCard(doc: docs[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final InstitutionalDocument doc;
  const _DocumentCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
        title: Text(doc.title, style: const TextStyle(color: Colors.white)),
        subtitle: AiTranslatedText(
            '${doc.proposals.length} Propostas de Alteração',
            style: const TextStyle(color: Colors.white54, fontSize: 10)),
        trailing: const Icon(Icons.download, color: Colors.white24),
        onTap: () {
          // Open document or proposals
        },
      ),
    );
  }
}
