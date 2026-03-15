import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../models/credit_transaction.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:intl/intl.dart';

class InstitutionCreditManagementScreen extends StatefulWidget {
  final InstitutionModel institution;
  const InstitutionCreditManagementScreen({super.key, required this.institution});

  @override
  State<InstitutionCreditManagementScreen> createState() => _InstitutionCreditManagementScreenState();
}

class _InstitutionCreditManagementScreenState extends State<InstitutionCreditManagementScreen> {

  Future<void> _showSetLimitDialog(UserModel user) async {
    final controller = TextEditingController(text: user.aiCreditLimit?.toString() ?? '');
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText('Definir Limite para ${user.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Créditos Máximos (Vazio = Sem limite)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final limit = int.tryParse(controller.text);
              await context.read<FirebaseService>().setUserCreditLimit(user.id, limit);
              if (mounted) Navigator.pop(context);
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkLimitDialog(UserRole role) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText('Limitar todos os ${role == UserRole.teacher ? 'Professores' : 'Alunos'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Limite Uniforme'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final limit = int.tryParse(controller.text);
              await context.read<FirebaseService>().setBulkCreditLimit(widget.institution.id, role, limit);
              if (mounted) Navigator.pop(context);
            },
            child: const AiTranslatedText('Aplicar a Todos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const AiTranslatedText('Gestão de Créditos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceHero(widget.institution),
            const SizedBox(height: 32),
            _buildStatsSection(service),
            const SizedBox(height: 32),
            _buildLimitsSection(service),
            const SizedBox(height: 32),
            _buildTransactionHistory(service),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHero(InstitutionModel inst) {
    return GlassCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          children: [
            const AiTranslatedText('Créditos Disponíveis', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.token, color: Colors.amber, size: 32),
                const SizedBox(width: 12),
                Text('${inst.aiCredits}', 
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            AiTranslatedText('Total Carregado: ${inst.totalCreditsRecharged}', 
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(FirebaseService service) {
    return FutureBuilder<Map<String, List<UserModel>>>(
      future: service.getTopConsumptionStats(widget.institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('Análise de Consumo (Top Utilização)', 
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatList('Alunos (Mais Ativos)', stats['top_students']!)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatList('Professores (Mais Ativos)', stats['top_teachers']!)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatList(String title, List<UserModel> users) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiTranslatedText(title, style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (users.isEmpty) const AiTranslatedText('Sem dados', style: TextStyle(color: Colors.white24)),
            ...users.map((u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Text('${u.totalCreditsConsumed}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsSection(FirebaseService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText('Gestão de Limites', 
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showBulkLimitDialog(UserRole.student),
              icon: const Icon(Icons.people),
              label: const AiTranslatedText('Limitar Todos Alunos'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showBulkLimitDialog(UserRole.teacher),
              icon: const Icon(Icons.school),
              label: const AiTranslatedText('Limitar Todos Professores'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1FF)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<UserModel>>(
          stream: service.getUsers(),
          builder: (context, snapshot) {
            final members = (snapshot.data ?? []).where((u) => u.institutionId == widget.institution.id).toList();
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index];
                  return ListTile(
                    title: Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: AiTranslatedText('Limite: ${m.aiCreditLimit ?? 'Ilimitado'}', 
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.white54),
                      onPressed: () => _showSetLimitDialog(m),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionHistory(FirebaseService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText('Histórico de Transações', 
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<List<CreditTransaction>>(
          stream: service.getInstitutionTransactions(widget.institution.id),
          builder: (context, snapshot) {
            final txs = snapshot.data ?? [];
            if (txs.isEmpty) return const AiTranslatedText('Sem transações registadas.');
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txs.length,
              itemBuilder: (context, index) {
                final tx = txs[index];
                return ListTile(
                  leading: Icon(
                    tx.type == TransactionType.recharge ? Icons.add_circle : Icons.remove_circle,
                    color: tx.type == TransactionType.recharge ? Colors.green : Colors.red,
                  ),
                  title: AiTranslatedText(tx.description, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(tx.timestamp), 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Text('${tx.amount}', 
                    style: TextStyle(color: tx.type == TransactionType.recharge ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
