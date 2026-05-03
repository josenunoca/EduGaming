import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/ai_translation_service.dart';
import '../../../../widgets/ai_translated_text.dart';

class ProcurementAuditTab extends StatelessWidget {
  final InstitutionModel institution;

  const ProcurementAuditTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final procurementService = Provider.of<ProcurementService>(context, listen: false);

    return StreamBuilder<List<InventoryAuditLog>>(
      stream: procurementService.getAuditLogs(institution.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF9F1C)));
        }

        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                AiTranslatedText('Sem registos de auditoria disponíveis.',
                  style: TextStyle(color: Colors.white54, fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _AuditLogTile(log: log);
          },
        );
      },
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final InventoryAuditLog log;

  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _getActionColor(log.action);
    final icon = _getActionIcon(log.action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                log.itemName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            _buildBadge(_getActionLabel(log.action), color),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AiTranslatedText('Tam: ${log.size} / ${log.color}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM HH:mm').format(log.timestamp),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person, size: 12, color: Colors.blueAccent),
                const SizedBox(width: 4),
                Text(log.userName, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        expandedAlignment: Alignment.topLeft,
        children: [
          _buildDetailRow(Icons.person_outline, 'Responsável:', log.userName),
          _buildDetailRow(Icons.swap_vert, 'Variação:', '${log.quantityChanged > 0 ? '+' : ''}${log.quantityChanged.toInt()} un'),
          _buildDetailRow(Icons.account_balance_wallet_outlined, 'Stock Resultante:', '${log.resultingStock.toInt()} un'),
          if (log.itemReference != null)
            _buildDetailRow(Icons.tag, 'Referência:', log.itemReference!),
          if (log.referenceId != null)
            _buildDetailRow(Icons.document_scanner_outlined, 'ID Documento:', log.referenceId!),
          if (log.notes != null && log.notes!.isNotEmpty)
            _buildDetailRow(Icons.notes, 'Notas:', log.notes!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 8),
          AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: AiTranslatedText(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getActionColor(InventoryAction action) {
    switch (action) {
      case InventoryAction.entry:
        return const Color(0xFF10B981); // Emerald
      case InventoryAction.sale:
        return const Color(0xFF3B82F6); // Blue
      case InventoryAction.adjustment:
        return const Color(0xFFF59E0B); // Amber
      case InventoryAction.fulfillment:
        return const Color(0xFF8B5CF6); // Violet
      case InventoryAction.cancellation:
        return const Color(0xFFEF4444); // Red
      case InventoryAction.closing:
        return const Color(0xFF6366F1); // Indigo
      case InventoryAction.regularization:
        return const Color(0xFF10B981); // Emerald
    }
  }

  String _getActionLabel(InventoryAction action) {
    switch (action) {
      case InventoryAction.entry:
        return 'COMPRA';
      case InventoryAction.sale:
        return 'VENDA';
      case InventoryAction.adjustment:
        return 'REGULARIZAÇÃO';
      case InventoryAction.fulfillment:
        return 'ENTREGA';
      case InventoryAction.cancellation:
        return 'ANULAÇÃO';
      case InventoryAction.closing:
        return 'FECHO';
      case InventoryAction.regularization:
        return 'REGULARIZAÇÃO';
    }
  }

  IconData _getActionIcon(InventoryAction action) {
    switch (action) {
      case InventoryAction.entry:
        return Icons.add_business_outlined;
      case InventoryAction.sale:
        return Icons.shopping_basket_outlined;
      case InventoryAction.adjustment:
        return Icons.edit_note_outlined;
      case InventoryAction.fulfillment:
        return Icons.done_all_outlined;
      case InventoryAction.cancellation:
        return Icons.cancel_outlined;
      case InventoryAction.closing:
        return Icons.lock_outline;
      case InventoryAction.regularization:
        return Icons.assignment_turned_in_outlined;
    }
  }
}
