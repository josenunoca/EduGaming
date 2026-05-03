import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/finance_models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class FinanceInvoicesTab extends StatelessWidget {
  final InstitutionModel institution;

  const FinanceInvoicesTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<FinanceInvoice>>(
      stream: service.getFinanceInvoices(institution.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final invoices = snapshot.data ?? [];

        return Column(
          children: [
            _buildInvoiceStats(invoices),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: invoices.length,
                itemBuilder: (context, index) => _buildInvoiceItem(invoices[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInvoiceStats(List<FinanceInvoice> invoices) {
    final pending = invoices.where((i) => i.status == InvoiceStatus.sent).length;
    final paid = invoices.where((i) => i.status == InvoiceStatus.paid).length;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          _buildStatMiniCard('Lançadas', invoices.length.toString(), Colors.blueAccent),
          const SizedBox(width: 12),
          _buildStatMiniCard('Aguarda Pag.', pending.toString(), Colors.orangeAccent),
          const SizedBox(width: 12),
          _buildStatMiniCard('Liquidadas', paid.toString(), Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildStatMiniCard(String label, String value, Color color) {
    return Expanded(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(FinanceInvoice inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          title: Row(
            children: [
              Text(inv.invoiceNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildStatusBadge(inv.status),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(inv.customerName, style: const TextStyle(color: Colors.white70)),
              Text(
                'Vence em: ${DateFormat('dd/MM/yyyy').format(inv.dueDate)}',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
          trailing: Text(
            '€ ${inv.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InvoiceStatus status) {
    Color color;
    switch (status) {
      case InvoiceStatus.paid: color = Colors.green; break;
      case InvoiceStatus.overdue: color = Colors.red; break;
      case InvoiceStatus.sent: color = Colors.orange; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: AiTranslatedText(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
