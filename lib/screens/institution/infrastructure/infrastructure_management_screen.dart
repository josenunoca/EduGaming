import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/infrastructure_model.dart';
import '../../../../models/institution_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../utils/infrastructure_export_helper.dart';
import 'infrastructure_details_screen.dart';

class InfrastructureManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const InfrastructureManagementScreen({super.key, required this.institution});

  @override
  State<InfrastructureManagementScreen> createState() =>
      _InfrastructureManagementScreenState();
}

class _InfrastructureManagementScreenState
    extends State<InfrastructureManagementScreen> {
  void _showAddInfrastructureDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AiTranslatedText('Nova Infraestrutura'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome da Infraestrutura',
            hintText: 'Ex: Pavilhão Gimnodesportivo',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final infra = Infrastructure(
                id: const Uuid().v4(),
                institutionId: widget.institution.id,
                name: nameController.text.trim(),
              );
              await context.read<FirebaseService>().saveInfrastructure(infra);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: AiTranslatedText('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
        title: AiTranslatedText('Gestão de Infraestruturas'),
        actions: [
          StreamBuilder<List<Infrastructure>>(
            stream: service.getInfrastructures(widget.institution.id),
            builder: (context, snapshot) {
              return IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Gerar Relatório Global',
                onPressed: () async {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    await InfrastructureExportHelper.downloadGlobalReport(snapshot.data!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: AiTranslatedText('Nenhuma infraestrutura disponível.'))
                    );
                  }
                },
              );
            }
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AiTranslatedText(
                  'As Suas Infraestruturas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddInfrastructureDialog(context),
                  icon: const Icon(Icons.add),
                  label: AiTranslatedText('Nova Infraestrutura'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Infrastructure>>(
                stream: service.getInfrastructures(widget.institution.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: AiTranslatedText(
                          'Nenhuma infraestrutura cadastrada.'),
                    );
                  }

                  final infras = snapshot.data!;
                  return ListView.builder(
                    itemCount: infras.length,
                    itemBuilder: (context, index) {
                      final infra = infras[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.domain, size: 40),
                          title: Text(infra.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(infra.address.isEmpty
                              ? 'Sem morada'
                              : infra.address),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InfrastructureDetailsScreen(
                                  institution: widget.institution,
                                  infrastructure: infra,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
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
