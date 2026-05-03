import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/finance_models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class FinanceTransactionsTab extends StatelessWidget {
  final InstitutionModel institution;

  const FinanceTransactionsTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<FinanceTransaction>>(
      stream: service.getFinanceTransactions(institution.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final transactions = snapshot.data ?? [];

        return Column(
          children: [
            _buildSearchAndFilters(),
            Expanded(
              child: transactions.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) => _buildTransactionItem(transactions[index]),
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquisar transação...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.filter_list, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(FinanceTransaction tx) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? const Color(0xFF00FF85) : const Color(0xFFFF4D4D);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 20),
          ),
          title: Text(tx.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${DateFormat('dd MMM yyyy').format(tx.date)} • ${tx.category.name.toUpperCase()}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'} € ${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const AiTranslatedText('Nenhuma transação registada.', style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }
}
