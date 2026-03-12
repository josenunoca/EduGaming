import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/firebase_service.dart';
import '../../../models/institution_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class AdminRevenueDashboard extends StatelessWidget {
  const AdminRevenueDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Dashboard Financeiro & SaaS',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: service.getAdminRevenueStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRevenueSummary(stats),
                const SizedBox(height: 32),
                const AiTranslatedText('Gestão de Instituições',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 16),
                _buildInstitutionList(service),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueSummary(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Receita Est. (Mensal)',
            '€${stats['estimatedRevenue']?.toStringAsFixed(2) ?? '0.00'}',
            Icons.payments,
            const Color(0xFF00D1FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Inscrições Ativas',
            stats['activeEnrollments']?.toString() ?? '0',
            Icons.people,
            const Color(0xFF7B61FF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            AiTranslatedText(label,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildInstitutionList(FirebaseService service) {
    return StreamBuilder<List<InstitutionModel>>(
      stream: service.getInstitutions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final institutions = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: institutions.length,
          itemBuilder: (context, index) {
            final inst = institutions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: ListTile(
                  title: Text(inst.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      _buildPlanBadge(inst.subscriptionPlan),
                      const SizedBox(width: 12),
                      const Icon(Icons.token, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text('${inst.aiCredits} cr.',
                          style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                  trailing: const Icon(Icons.settings, color: Colors.white24),
                  onTap: () => _showPlanSettings(context, service, inst),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlanBadge(String plan) {
    Color color;
    switch (plan) {
      case 'pro':
        color = const Color(0xFF00D1FF);
        break;
      case 'enterprise':
        color = const Color(0xFF7B61FF);
        break;
      default:
        color = Colors.white24;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(plan.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showPlanSettings(
      BuildContext context, FirebaseService service, InstitutionModel inst) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiTranslatedText('Gestão de Plano: ${inst.name}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const AiTranslatedText('Alterar Plano SaaS',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            _buildPlanOption(context, service, inst, 'base', 'Gestão Simples'),
            _buildPlanOption(context, service, inst, 'pro', 'IA & DocTalk'),
            _buildPlanOption(
                context, service, inst, 'enterprise', 'White Label'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addCredits(context, service, inst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const AiTranslatedText('Adicionar Créditos IA'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOption(BuildContext context, FirebaseService service,
      InstitutionModel inst, String plan, String description) {
    final isSelected = inst.subscriptionPlan == plan;
    return GestureDetector(
      onTap: () async {
        await service.updateInstitutionPlan(inst.id, plan);
        if (context.mounted) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7B61FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B61FF) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text(description,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF7B61FF)),
          ],
        ),
      ),
    );
  }

  void _addCredits(
      BuildContext context, FirebaseService service, InstitutionModel inst) {
    final controller = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Adicionar Créditos',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Quantidade',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                await service.addAiCredits(inst.id, 'institution', amount);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close bottom sheet
                }
              }
            },
            child: const AiTranslatedText('Confirmar'),
          ),
        ],
      ),
    );
  }
}
