import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/questionnaire_model.dart';
import 'package:intl/intl.dart';

class HealthSpecialistDashboard extends StatelessWidget {
  const HealthSpecialistDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    // specialistId is retrieved for future filtering audit
    // final specialistId = service.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Portal do Especialista de Saúde'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 32),
            Text('Questionários com Consentimento Ativo',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            StreamBuilder<List<Questionnaire>>(
              stream: service.getQuestionnaires('inst_default'), // Simplified for MVP
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final sensitiveQs = snapshot.data!.where((q) => q.isSensitive).toList();

                if (sensitiveQs.isEmpty) {
                  return const Center(child: Text('Nenhum dado sensível autorizado no momento.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sensitiveQs.length,
                  itemBuilder: (context, index) {
                    final q = sensitiveQs[index];
                    return _buildQuestionnaireDataCard(context, q);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.health_and_safety, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bem-vindo, Especialista',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const Text(
                    'Monitorização proativa segura sob proteção Privacy Shield.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireDataCard(BuildContext context, Questionnaire q) {
    final service = context.read<FirebaseService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.shield_moon, color: Colors.blueAccent),
        title: Text(q.title),
        subtitle: const Text('Acesso autorizado pelo RGPD',
            style: TextStyle(fontSize: 12, color: Colors.greenAccent)),
        children: [
          StreamBuilder<List<QuestionnaireResponse>>(
            stream: service.getSpecialistAccessibleResponses(q.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final responses = snapshot.data!;

              if (responses.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Sem respostas com consentimento explícito.'),
                );
              }

              return Column(
                children: responses.map((r) => _buildResponseRow(context, r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResponseRow(BuildContext context, QuestionnaireResponse r) {
    return ListTile(
      title: Text('Colaborador ID: ${r.userId.substring(0, 8)}'),
      subtitle: Text('Data Consentimento: ${DateFormat('dd/MM HH:mm').format(r.rgpdConsentDate ?? r.timestamp)}'),
      trailing: ElevatedButton(
        onPressed: () => _showAdviceDialog(context, r.userId),
        child: const Text('Enviar Conselho'),
      ),
    );
  }

  void _showAdviceDialog(BuildContext context, String userId) {
    final adviceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar Conselho Proativo'),
        content: TextField(
          controller: adviceController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escreva a sua recomendação técnica...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              // Logic to send internal message/notification
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conselho enviado com sucesso!')));
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
