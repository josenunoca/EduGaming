import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/finance_models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class FinanceBudgetsTab extends StatelessWidget {
  final InstitutionModel institution;

  const FinanceBudgetsTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<FinanceBudget>>(
      stream: service.getFinanceBudgets(institution.id, DateTime.now().year),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final budgets = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: budgets.length,
          itemBuilder: (context, index) => _buildBudgetCard(budgets[index]),
        );
      },
    );
  }

  Widget _buildBudgetCard(FinanceBudget budget) {
    final percent = budget.targetAmount > 0 ? (budget.spentAmount / budget.targetAmount) : 0.0;
    final isOverBudget = percent > 1.0;
    final color = isOverBudget ? Colors.redAccent : const Color(0xFF00FF85);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AiTranslatedText(
                    budget.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AiTranslatedText(
                budget.category.name.toUpperCase(),
                style: const TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(10),
                minHeight: 10,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBudgetInfo('Gasto', '€ ${budget.spentAmount.toStringAsFixed(2)}'),
                  _buildBudgetInfo('Objetivo', '€ ${budget.targetAmount.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
