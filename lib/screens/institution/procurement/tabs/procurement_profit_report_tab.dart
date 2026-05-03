import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class ProcurementProfitReportTab extends StatelessWidget {
  final InstitutionModel institution;

  const ProcurementProfitReportTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return FutureBuilder<List<ArticleProfit>>(
      future: service.getProfitReport(institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final profits = snapshot.data!;
        
        if (profits.isEmpty) {
          return const Center(child: AiTranslatedText('Sem dados de vendas para calcular lucro.'));
        }

        final totalProfit = profits.fold(0.0, (sum, p) => sum + p.netProfit);
        final totalRevenue = profits.fold(0.0, (sum, p) => sum + p.totalRevenue);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryHeader(totalProfit, totalRevenue),
              const SizedBox(height: 32),
              _buildProfitChart(profits),
              const SizedBox(height: 32),
              const AiTranslatedText('Detalhamento por Artigo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...profits.map((p) => _buildProfitRow(p)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader(double totalProfit, double totalRevenue) {
    final margin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
    
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const AiTranslatedText('Lucro Total Líquido', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('€ ${totalProfit.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FF85), fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const AiTranslatedText('Margem Média', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${margin.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfitChart(List<ArticleProfit> profits) {
    final sections = profits.where((p) => p.netProfit > 0).map((p) {
      final color = Colors.primaries[profits.indexOf(p) % Colors.primaries.length];
      return PieChartSectionData(
        value: p.netProfit,
        title: '${p.profitMargin.toInt()}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return GlassCard(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 4,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: profits.take(4).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(
                        color: Colors.primaries[profits.indexOf(p) % Colors.primaries.length],
                        shape: BoxShape.circle,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.itemName, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitRow(ArticleProfit p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          title: Text(p.itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: AiTranslatedText(
            'Qtd: ${p.quantitySold.toInt()} | Custo Médio: € ${p.averageCost.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('€ ${p.netProfit.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${p.profitMargin.toStringAsFixed(1)}% margem', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
