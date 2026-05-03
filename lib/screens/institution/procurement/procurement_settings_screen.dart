import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class ProcurementSettingsScreen extends StatefulWidget {
  final String institutionId;

  const ProcurementSettingsScreen({super.key, required this.institutionId});

  @override
  State<ProcurementSettingsScreen> createState() => _ProcurementSettingsScreenState();
}

class _ProcurementSettingsScreenState extends State<ProcurementSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProcurementService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const AiTranslatedText('Definições de Inventário')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Armazéns / Localizações'),
          StreamBuilder<List<Warehouse>>(
            stream: service.getWarehouses(widget.institutionId),
            builder: (context, snap) {
              final warehouses = snap.data ?? [];
              return Column(
                children: [
                  ...warehouses.map((w) => ListTile(
                    title: Text(w.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(w.location, style: const TextStyle(color: Colors.white24)),
                    trailing: const Icon(Icons.edit, color: Colors.white10),
                  )),
                  ListTile(
                    leading: const Icon(Icons.add, color: Color(0xFF00FF85)),
                    title: const AiTranslatedText('Adicionar Armazém'),
                    onTap: _showAddWarehouse,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Famílias de Artigos'),
          StreamBuilder<List<ProcurementFamily>>(
            stream: service.getFamilies(widget.institutionId),
            builder: (context, snap) {
              final families = snap.data ?? [];
              return Column(
                children: [
                  ...families.map((f) => ExpansionTile(
                    title: Text(f.name, style: const TextStyle(color: Colors.white)),
                    children: [
                      StreamBuilder<List<ProcurementSubfamily>>(
                        stream: service.getSubfamilies(widget.institutionId, f.id),
                        builder: (context, subSnap) {
                          final subs = subSnap.data ?? [];
                          return Column(
                            children: [
                              ...subs.map((s) => ListTile(title: Text(s.name, style: const TextStyle(color: Colors.white70)))),
                              ListTile(
                                leading: const Icon(Icons.add, size: 18),
                                title: const AiTranslatedText('Nova Subfamília'),
                                onTap: () => _showAddSubfamily(f.id),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  )),
                  ListTile(
                    leading: const Icon(Icons.add, color: Color(0xFFFF9F1C)),
                    title: const AiTranslatedText('Adicionar Família'),
                    onTap: _showAddFamily,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AiTranslatedText(title, style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  void _showAddWarehouse() {
    String name = '';
    String location = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Novo Armazém'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(onChanged: (v) => name = v, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(onChanged: (v) => location = v, decoration: const InputDecoration(labelText: 'Localização')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () async {
            if (name.isNotEmpty) {
              try {
                await context.read<ProcurementService>().saveWarehouse(Warehouse(
                  id: const Uuid().v4(),
                  institutionId: widget.institutionId,
                  name: name,
                  location: location,
                ));
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao criar armazém: $e')),
                  );
                }
              }
            } else {
              Navigator.pop(context);
            }
          }, child: const AiTranslatedText('Criar')),
        ],
      ),
    );
  }

  void _showAddFamily() {
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Nova Família'),
        content: TextField(onChanged: (v) => name = v, decoration: const InputDecoration(labelText: 'Nome da Família')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () async {
            if (name.isNotEmpty) {
              try {
                await context.read<ProcurementService>().saveFamily(ProcurementFamily(
                  id: const Uuid().v4(),
                  institutionId: widget.institutionId,
                  name: name,
                ));
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao criar família: $e')),
                  );
                }
              }
            } else {
              Navigator.pop(context);
            }
          }, child: const AiTranslatedText('Criar')),
        ],
      ),
    );
  }

  void _showAddSubfamily(String familyId) {
    String name = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Nova Subfamília'),
        content: TextField(onChanged: (v) => name = v, decoration: const InputDecoration(labelText: 'Nome da Subfamília')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () async {
            if (name.isNotEmpty) {
              try {
                await context.read<ProcurementService>().saveSubfamily(widget.institutionId, ProcurementSubfamily(
                  id: const Uuid().v4(),
                  familyId: familyId,
                  name: name,
                ));
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao criar subfamília: $e')),
                  );
                }
              }
            } else {
              Navigator.pop(context);
            }
          }, child: const AiTranslatedText('Criar')),
        ],
      ),
    );
  }
}
