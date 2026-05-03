import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/finance_models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';
import '../../../../services/pdf_service.dart';

class FinanceDashboardTab extends StatelessWidget {
  final InstitutionModel institution;

  const FinanceDashboardTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<FinanceTransaction>>(
      stream: service.getFinanceTransactions(institution.id),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];
        final totalIncome = transactions.where((t) => t.type == TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
        final totalExpense = transactions.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);
        final balance = totalIncome - totalExpense;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSalutation(service),
              const SizedBox(height: 24),
              _buildBalanceCard(balance, totalIncome, totalExpense),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AiTranslatedText(
                    'Tendência Financeira',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                    child: const AiTranslatedText('Últimos 30 Dias', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildChartCard(transactions),
              const SizedBox(height: 32),
              _buildRecentAlerts(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalutation(FirebaseService service) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF00FF85).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF00FF85), size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('Centro de Tesouraria', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            AiTranslatedText('Controlo de Fluxo de Caixa • ${DateFormat('MMMM yyyy').format(DateTime.now())}', 
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const Spacer(),
        _buildActionButton(Icons.picture_as_pdf_outlined, () async {
          final pdfService = PdfService();
          final transactions = await service.getFinanceTransactions(institution.id).first;
          final totalIncome = transactions.where((t) => t.type == TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
          final totalExpense = transactions.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);
          final balance = totalIncome - totalExpense;
          
          await pdfService.generateFinancialReportPDF(
            institution: institution,
            transactions: transactions,
            balance: balance,
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Colors.white10), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double income, double expense) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            const AiTranslatedText('DISPONIBILIDADE LÍQUIDA', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Text(
              '€ ${balance.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildCompactStat('Entradas', income, Colors.greenAccent, Icons.arrow_upward)),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(child: _buildCompactStat('Saídas', expense, Colors.redAccent, Icons.arrow_downward)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, double amount, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withOpacity(0.5), size: 12),
            const SizedBox(width: 4),
            AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text('€ ${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChartCard(List<FinanceTransaction> transactions) {
    // Basic aggregation for chart (last 7 days or points)
    final List<FlSpot> spots = [];
    if (transactions.isEmpty) {
      spots.add(const FlSpot(0, 0));
    } else {
      transactions.sort((a, b) => a.date.compareTo(b.date));
      // Show last 10 transactions as trend
      final recent = transactions.length > 10 ? transactions.sublist(transactions.length - 10) : transactions;
      double runningBalance = 0;
      for (int i = 0; i < recent.length; i++) {
        if (recent[i].type == TransactionType.income) {
          runningBalance += recent[i].amount;
        } else {
          runningBalance -= recent[i].amount;
        }
        spots.add(FlSpot(i.toDouble(), runningBalance));
      }
    }

    return GlassCard(
      child: Container(
        height: 220,
        padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 24),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF00FF85),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FF85).withOpacity(0.2),
                      const Color(0xFF00FF85).withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText(
          'Alertas e Notificações',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildAlertItem('Faturas pendentes para reconciliação', Icons.description_outlined, Colors.orangeAccent),
        _buildAlertItem('Aviso: Baixa liquidez prevista para o final do mês', Icons.speed_outlined, Colors.redAccent),
        _buildAlertItem('Relatórios de Inventário atualizados (FIFO)', Icons.inventory_2_outlined, Colors.blueAccent),
      ],
    );
  }

  Widget _buildAlertItem(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(child: AiTranslatedText(title, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 12),
        ],
      ),
    );
  }
}
