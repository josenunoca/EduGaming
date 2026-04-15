import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/institution_model.dart';
import '../../../models/erp_record_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class ErpModuleScreen extends StatelessWidget {
  final InstitutionModel institution;
  final ErpModule module;
  final String title;
  final Color themeColor;

  const ErpModuleScreen({
    super.key,
    required this.institution,
    required this.module,
    required this.title,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRecordDialog(context, service),
            tooltip: 'Novo Registo',
          ),
        ],
      ),
      body: StreamBuilder<List<ErpRecord>>(
        stream: service.getErpRecords(institution.id, module: module),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: themeColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const AiTranslatedText('Nenhum registo encontrado.',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return _buildRecordCard(context, service, record);
            },
          );
        },
      ),
    );
  }

  Widget _buildRecordCard(
      BuildContext context, FirebaseService service, ErpRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getStatusIcon(record.status),
                color: _getStatusColor(record.status), size: 20),
          ),
          title: Text(record.title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(record.description,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
          onTap: () => _showRecordDetails(context, service, record),
        ),
      ),
    );
  }

  void _showAddRecordDialog(BuildContext context, FirebaseService service) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: AiTranslatedText('Novo Registo - $title',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Descrição/Notas',
                labelStyle: TextStyle(color: Colors.white54),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final record = ErpRecord(
                  id: const Uuid().v4(),
                  institutionId: institution.id,
                  module: module,
                  title: titleController.text,
                  description: descController.text,
                  createdBy:
                      'admin', // In a real app, this would be the actual user ID
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await service.saveErpRecord(record);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showRecordDetails(
      BuildContext context, FirebaseService service, ErpRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(record.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold))),
                _StatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 16),
            Text(record.description,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(icon: Icons.edit, label: 'Editar', onTap: () {}),
                _ActionButton(
                    icon: Icons.attach_file, label: 'Anexos', onTap: () {}),
                _ActionButton(
                    icon: Icons.delete,
                    label: 'Eliminar',
                    color: Colors.redAccent,
                    onTap: () async {
                      await service.deleteErpRecord(record.id);
                      if (context.mounted) Navigator.pop(context);
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(ErpRecordStatus status) {
    switch (status) {
      case ErpRecordStatus.active:
        return Icons.play_circle_outline;
      case ErpRecordStatus.completed:
        return Icons.check_circle_outline;
      case ErpRecordStatus.pending:
        return Icons.hourglass_empty;
      case ErpRecordStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor(ErpRecordStatus status) {
    switch (status) {
      case ErpRecordStatus.active:
        return Colors.blueAccent;
      case ErpRecordStatus.completed:
        return Colors.greenAccent;
      case ErpRecordStatus.pending:
        return Colors.amberAccent;
      case ErpRecordStatus.cancelled:
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ErpRecordStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(status.name.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(ErpRecordStatus status) {
    switch (status) {
      case ErpRecordStatus.active:
        return Colors.blueAccent;
      case ErpRecordStatus.completed:
        return Colors.greenAccent;
      case ErpRecordStatus.pending:
        return Colors.amberAccent;
      case ErpRecordStatus.cancelled:
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      this.color = Colors.white,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          AiTranslatedText(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
