import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/finance/finance_models.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/finance_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';
import 'tabs/finance_dashboard_tab.dart';
import 'tabs/finance_transactions_tab.dart';
import 'tabs/finance_invoices_tab.dart';
import 'tabs/finance_budgets_tab.dart';
import 'tabs/finance_reports_tab.dart';

class FinanceManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const FinanceManagementScreen({super.key, required this.institution});

  @override
  State<FinanceManagementScreen> createState() => _FinanceManagementScreenState();
}

class _FinanceManagementScreenState extends State<FinanceManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Financeiro 360º - ${widget.institution.name}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF00FF85),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFF00FF85),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Transações'),
            Tab(icon: Icon(Icons.description_outlined), text: 'Faturação'),
            Tab(icon: Icon(Icons.pie_chart_outline), text: 'Orçamentos'),
            Tab(icon: Icon(Icons.assessment_outlined), text: 'Relatórios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FinanceDashboardTab(institution: widget.institution),
          FinanceTransactionsTab(institution: widget.institution),
          FinanceInvoicesTab(institution: widget.institution),
          FinanceBudgetsTab(institution: widget.institution),
          FinanceReportsTab(institution: widget.institution),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionMenu,
        backgroundColor: const Color(0xFF00FF85),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showQuickActionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.green),
              title: const AiTranslatedText('Nova Receita'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
              title: const AiTranslatedText('Nova Despesa'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const AiTranslatedText('Emitir Fatura'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.auto_fix_high, color: Colors.amber),
              title: const AiTranslatedText('Faturação Automática (Mensalidade)'),
              subtitle: const AiTranslatedText('Gera faturas para todos os alunos ativa automaticamente.', style: TextStyle(fontSize: 10, color: Colors.white38)),
              onTap: () async {
                final fService = context.read<FinanceService>();
                Navigator.pop(context);
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final count = await fService.generateMonthlyTuitionInvoices(widget.institution.id, 150.0, 'Abril 2026');
                
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: AiTranslatedText('$count faturas geradas com sucesso!')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined, color: Colors.purpleAccent),
              title: const AiTranslatedText('Delegar Gestor Financeiro'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
