import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/financial_report_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/finance_service.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinanceReportsTab extends StatefulWidget {
  final InstitutionModel institution;

  const FinanceReportsTab({super.key, required this.institution});

  @override
  State<FinanceReportsTab> createState() => _FinanceReportsTabState();
}

class _FinanceReportsTabState extends State<FinanceReportsTab> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final financeService = context.read<FinanceService>();

    return Column(
      children: [
        _buildPeriodSelector(),
        Expanded(
          child: StreamBuilder<List<FinancialReport>>(
            stream: financeService.getReports(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final reports = snapshot.data!;

              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AiTranslatedText('Nenhum relatório gerado ainda.', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _createNewReport(context),
                        icon: const Icon(Icons.add_chart),
                        label: const AiTranslatedText('Gerar Primeiro Relatório'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF85), foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: reports.length,
                itemBuilder: (context, index) => _buildReportCard(reports[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white.withOpacity(0.05),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => _selectDate(true),
              icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF00FF85)),
              label: Text(DateFormat('dd/MM/yyyy').format(_startDate), style: const TextStyle(color: Colors.white)),
            ),
          ),
          const Icon(Icons.arrow_forward, size: 16, color: Colors.white24),
          Expanded(
            child: TextButton.icon(
              onPressed: () => _selectDate(false),
              icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF00FF85)),
              label: Text(DateFormat('dd/MM/yyyy').format(_endDate), style: const TextStyle(color: Colors.white)),
            ),
          ),
          IconButton(
            onPressed: () => _createNewReport(context),
            icon: const Icon(Icons.add_circle, color: Color(0xFF00FF85), size: 32),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildReportCard(FinancialReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        child: ExpansionTile(
          collapsedTextColor: Colors.white,
          textColor: Colors.white,
          iconColor: const Color(0xFF00FF85),
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              const Icon(Icons.article_outlined, color: Color(0xFF00FF85), size: 20),
              const SizedBox(width: 12),
              Text(
                'Relatório: ${DateFormat('dd/MM/yy').format(report.startDate)} a ${DateFormat('dd/MM/yy').format(report.endDate)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const AiTranslatedText('Lucro Líquido: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                Text('€ ${report.netProfit.toStringAsFixed(2)}', 
                    style: TextStyle(color: report.netProfit >= 0 ? const Color(0xFF00FF85) : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildFinancialRow('Receitas Atividades', report.revenueActivities, Colors.greenAccent),
                  _buildFinancialRow('Receitas Inventário', report.revenueInventory, Colors.greenAccent),
                  _buildFinancialRow('Outros Rendimentos', report.otherIncome, Colors.greenAccent),
                  const Divider(color: Colors.white10),
                  _buildFinancialRow('Custos Operacionais', report.costActivities, Colors.redAccent),
                  _buildFinancialRow('Custos Inventário (FIFO)', report.costInventory, Colors.redAccent),
                  _buildFinancialRow('Ajustes de Inventário', report.inventoryAdjustments, report.inventoryAdjustments >= 0 ? Colors.greenAccent : Colors.redAccent),
                  _buildFinancialRow('Outras Despesas', report.otherExpenses, Colors.redAccent),
                  const Divider(color: Colors.white24),
                  _buildFinancialRow('RESULTADO LÍQUIDO', report.netProfit, report.netProfit >= 0 ? const Color(0xFF00FF85) : Colors.redAccent, isTotal: true),
                  
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.pie_chart_outline, color: Colors.orangeAccent, size: 18),
                      SizedBox(width: 8),
                      AiTranslatedText('Insights Visuais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Charts Section
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(child: _buildRevenuePieChart(report)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildComparisonBarChart(report)),
                      ],
                    ),
                  ),
                  
                  if (report.notes.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AiTranslatedText('Notas do Administrador:', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(report.notes, style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportToPdf(report),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const AiTranslatedText('Exportar PDF'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.blueAccent),
                      ),
                      IconButton(
                        onPressed: () => context.read<FinanceService>().deleteReport(widget.institution.id, report.id),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Eliminar Relatório',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenuePieChart(FinancialReport report) {
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: [
                if (report.revenueActivities > 0)
                  PieChartSectionData(value: report.revenueActivities, color: Colors.blueAccent, radius: 40, showTitle: false),
                if (report.revenueInventory > 0)
                  PieChartSectionData(value: report.revenueInventory, color: Colors.greenAccent, radius: 40, showTitle: false),
                if (report.otherIncome > 0)
                  PieChartSectionData(value: report.otherIncome, color: Colors.orangeAccent, radius: 40, showTitle: false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const AiTranslatedText('Mix de Receitas', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildLegendItem('Atividades', Colors.blueAccent),
        _buildLegendItem('Inventário', Colors.greenAccent),
        _buildLegendItem('Outros', Colors.orangeAccent),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          AiTranslatedText(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildComparisonBarChart(FinancialReport report) {
    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: report.totalRevenue > report.totalCost ? report.totalRevenue * 1.2 : report.totalCost * 1.2,
              barTouchData: BarTouchData(enabled: false),
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: report.totalRevenue, color: Colors.greenAccent, width: 25, borderRadius: BorderRadius.circular(4))]),
                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: report.totalCost, color: Colors.redAccent, width: 25, borderRadius: BorderRadius.circular(4))]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const AiTranslatedText('Receita vs Custos', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildLegendItem('Receitas', Colors.greenAccent),
        _buildLegendItem('Custos', Colors.redAccent),
      ],
    );
  }

  Future<void> _exportToPdf(FinancialReport report) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(widget.institution.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Relatório Financeiro Profissional', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Emitido em: ${formatter.format(DateTime.now())}'),
                      pw.Text('ID: ${report.id.substring(0, 8).toUpperCase()}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PERÍODO ANALISADO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${formatter.format(report.startDate)} a ${formatter.format(report.endDate)}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              
              pw.Text('DEMONSTRAÇÃO DE RESULTADOS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              _buildPdfRow('Receitas de Atividades', report.revenueActivities),
              _buildPdfRow('Receitas de Inventário', report.revenueInventory),
              _buildPdfRow('Outros Rendimentos', report.otherIncome),
              pw.Divider(),
              _buildPdfRow('TOTAL DE RECEITAS', report.totalRevenue, isBold: true),
              
              pw.SizedBox(height: 20),
              
              _buildPdfRow('Custos de Atividades', report.costActivities),
              _buildPdfRow('Custos de Inventário (FIFO)', report.costInventory),
              _buildPdfRow('Outras Despesas', report.otherExpenses),
              pw.Divider(),
              _buildPdfRow('TOTAL DE CUSTOS', report.totalCost, isBold: true),
              
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: report.netProfit >= 0 ? PdfColors.green100 : PdfColors.red100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('RESULTADO LÍQUIDO DO PERÍODO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('EUR ${report.netProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: report.netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
                  ],
                ),
              ),
              
              if (report.notes.isNotEmpty) ...[
                pw.SizedBox(height: 40),
                pw.Text('NOTAS E OBSERVAÇÕES', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text(report.notes, style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              ],
              
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 40),
                      pw.SizedBox(width: 150, child: pw.Divider()),
                      pw.Text('Assinatura do Responsável', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Text('Gerado por EduGaming Finance 360', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Relatorio_Financeiro_${DateFormat('yyyyMMdd').format(report.startDate)}.pdf');
  }

  pw.Widget _buildPdfRow(String label, double value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('EUR ${value.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double value, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AiTranslatedText(label, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 14 : 13)),
          Text('€ ${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 13)),
        ],
      ),
    );
  }

  Future<void> _createNewReport(BuildContext context) async {
    final financeService = context.read<FinanceService>();
    final procurementService = context.read<ProcurementService>();
    final currentUser = context.read<FirebaseService>().currentUserModel!;

    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // Pre-calculate values
      final revActivities = await financeService.getTotalIncomeForPeriod(widget.institution.id, _startDate, _endDate);
      final costActivities = await financeService.getTotalExpenseForPeriod(widget.institution.id, _startDate, _endDate);
      final revInv = await procurementService.getInventoryRevenueForPeriod(widget.institution.id, _startDate, _endDate);
      final costInv = await procurementService.getInventoryCostForPeriod(widget.institution.id, _startDate, _endDate);
      final adjInv = await procurementService.getInventoryRegularizationValueForPeriod(widget.institution.id, _startDate, _endDate);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Controllers for manual editing
      final revActivitiesCtrl = TextEditingController(text: revActivities.toStringAsFixed(2));
      final costActivitiesCtrl = TextEditingController(text: costActivities.toStringAsFixed(2));
      final revInvCtrl = TextEditingController(text: revInv.toStringAsFixed(2));
      final costInvCtrl = TextEditingController(text: costInv.toStringAsFixed(2));
      final otherIncCtrl = TextEditingController(text: '0.00');
      final otherExpCtrl = TextEditingController(text: '0.00');
      final adjInvCtrl = TextEditingController(text: adjInv.toStringAsFixed(2));
      final notesCtrl = TextEditingController();

      if (!mounted) return;
      _showReportEditDialog(
        context, 
        financeService,
        currentUser,
        revActivitiesCtrl, 
        costActivitiesCtrl, 
        revInvCtrl, 
        costInvCtrl, 
        otherIncCtrl, 
        otherExpCtrl, 
        adjInvCtrl,
        notesCtrl,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar relatório: $e')),
        );
      }
    }
  }

  void _showReportEditDialog(
    BuildContext context, 
    FinanceService financeService,
    UserModel currentUser,
    TextEditingController revActivitiesCtrl,
    TextEditingController costActivitiesCtrl,
    TextEditingController revInvCtrl,
    TextEditingController costInvCtrl,
    TextEditingController otherIncCtrl,
    TextEditingController otherExpCtrl,
    TextEditingController adjInvCtrl,
    TextEditingController notesCtrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            final double r1 = double.tryParse(revActivitiesCtrl.text) ?? 0;
            final double r2 = double.tryParse(revInvCtrl.text) ?? 0;
            final double r3 = double.tryParse(otherIncCtrl.text) ?? 0;
            final double c1 = double.tryParse(costActivitiesCtrl.text) ?? 0;
            final double c2 = double.tryParse(costInvCtrl.text) ?? 0;
            final double c3 = double.tryParse(otherExpCtrl.text) ?? 0;
            final double adj = double.tryParse(adjInvCtrl.text) ?? 0;
            
            // Adjustments: Positive = Surplus (increases net), Negative = Loss (decreases net)
            final double totalR = r1 + r2 + r3 + (adj > 0 ? adj : 0);
            final double totalC = c1 + c2 + c3 + (adj < 0 ? adj.abs() : 0);
            final double net = totalR - totalC;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                controller: scrollController,
                children: [
                  const AiTranslatedText('Novo Relatório Financeiro', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AiTranslatedText('Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} a ${DateFormat('dd/MM/yyyy').format(_endDate)}', 
                      style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  
                  // Summary Preview
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                    child: Column(
                      children: [
                        const AiTranslatedText('RESULTADO ESTIMADO', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('€ ${net.toStringAsFixed(2)}', style: TextStyle(color: net >= 0 ? const Color(0xFF00FF85) : Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 20,
                              sections: [
                                if (r1 > 0) PieChartSectionData(value: r1, color: Colors.blueAccent, radius: 15, showTitle: false),
                                if (r2 > 0) PieChartSectionData(value: r2, color: Colors.greenAccent, radius: 15, showTitle: false),
                                if (r3 > 0) PieChartSectionData(value: r3, color: Colors.orangeAccent, radius: 15, showTitle: false),
                                if (totalR == 0) PieChartSectionData(value: 1, color: Colors.white10, radius: 15, showTitle: false),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  _buildEditSection('RECEITAS', [
                    _buildEditField('Receitas de Atividades', revActivitiesCtrl, (v) => setModalState(() {})),
                    _buildEditField('Receitas de Inventário', revInvCtrl, (v) => setModalState(() {})),
                    _buildEditField('Outros Rendimentos', otherIncCtrl, (v) => setModalState(() {})),
                  ], Colors.greenAccent),
                  
                  const SizedBox(height: 24),
                  
                  _buildEditSection('CUSTOS', [
                    _buildEditField('Custos de Atividades', costActivitiesCtrl, (v) => setModalState(() {})),
                    _buildEditField('Custos de Inventário (FIFO)', costInvCtrl, (v) => setModalState(() {})),
                    _buildEditField('Outras Despesas', otherExpCtrl, (v) => setModalState(() {})),
                    _buildEditField('Ajustes Inventário (Sobras/Perdas)', adjInvCtrl, (v) => setModalState(() {})),
                  ], Colors.redAccent),
                  
                  const SizedBox(height: 24),
                  
                  const AiTranslatedText('Notas do Administrador', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: 'Observações sobre o desempenho financeiro...',
                      hintStyle: const TextStyle(color: Colors.white24),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  ElevatedButton(
                    onPressed: () async {
                      final report = FinancialReport(
                        id: const Uuid().v4(),
                        institutionId: widget.institution.id,
                        startDate: _startDate,
                        endDate: _endDate,
                        revenueActivities: r1,
                        revenueInventory: r2,
                        costActivities: c1,
                        costInventory: c2,
                        otherIncome: r3,
                        otherExpenses: c3,
                        inventoryAdjustments: adj,
                        notes: notesCtrl.text,
                        createdAt: DateTime.now(),
                        createdById: currentUser.id,
                      );
                      
                      await financeService.saveReport(report);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF85),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const AiTranslatedText('Confirmar e Guardar Relatório'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildEditSection(String title, List<Widget> fields, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiTranslatedText(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...fields,
      ],
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, Function(String)? onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixText: '€ ',
          prefixStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
