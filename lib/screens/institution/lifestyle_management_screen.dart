import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/firebase_service.dart';
import '../../services/lifestyle_ai_service.dart';
import '../../models/questionnaire_model.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';

class LifestyleManagementScreen extends StatefulWidget {
  const LifestyleManagementScreen({super.key});

  @override
  State<LifestyleManagementScreen> createState() =>
      _LifestyleManagementScreenState();
}

class _LifestyleManagementScreenState extends State<LifestyleManagementScreen> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gestão de Estilo de Vida'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showAssignSpecialistDialog,
            icon: const Icon(Icons.medical_services_outlined,
                color: Colors.blueAccent),
            tooltip: 'Nomear Especialista de Saúde',
          ),
          IconButton(
            onPressed: () => setState(() => _isCreating = true),
            icon: const Icon(Icons.add_chart),
            tooltip: 'Novo Questionário',
          ),
        ],
      ),
      body: _isCreating ? _buildCreationUI() : _buildListUI(),
    );
  }

  Widget _buildListUI() {
    final service = context.read<FirebaseService>();
    return StreamBuilder<List<Questionnaire>>(
      stream: service.getQuestionnaires('inst_default'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final q = list[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: q.isSensitive
                    ? const Icon(Icons.shield, color: Colors.amber)
                    : const Icon(Icons.assignment),
                title: Text(q.title),
                subtitle: Text('Até: ${DateFormat('dd/MM').format(q.endDate)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.analytics, color: Colors.blueAccent),
                      onPressed: () => _showAnalytics(q),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                      onPressed: () => _showReopenDialog(q),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCreationUI() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));
    List<String> targetRoles = ['student'];
    bool isSensitive = false;

    return StatefulBuilder(builder: (context, setInternalState) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configurar Novo Inquérito',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título do Inquérito'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição/Objetivo'),
            ),
            const SizedBox(height: 24),
            _buildTargetingSection(targetRoles, setInternalState),
            const SizedBox(height: 24),
            _buildDatePicker(context, 'Início', startDate, (d) {
              setInternalState(() => startDate = d);
            }),
            _buildDatePicker(context, 'Fim', endDate, (d) {
              setInternalState(() => endDate = d);
            }),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Conteúdo Sensível (Saúde/Privacidade)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Ativa a Blindagem de Dados (RGPD) e exige consentimento para partilha com o especialista.'),
              value: isSensitive,
              activeThumbColor: Colors.amber,
              onChanged: (v) => setInternalState(() => isSensitive = v),
            ),
            const SizedBox(height: 32),
            Center(
              child: CustomButton(
                onPressed: () async {
                  final q = Questionnaire(
                    id: const Uuid().v4(),
                    title: titleController.text,
                    description: descController.text,
                    questions: [
                      Question(
                          id: 'q1',
                          text: 'Como avalia o seu sono?',
                          type: QuestionType.selection,
                          options: ['Péssimo', 'Médio', 'Ótimo']),
                      Question(
                          id: 'q2',
                          text: 'Descreva a sua alimentação diária',
                          type: QuestionType.audio),
                    ],
                    institutionId: 'inst_default',
                    targetRoles: targetRoles,
                    startDate: startDate,
                    endDate: endDate,
                    isSensitive: isSensitive,
                  );
                  await context.read<FirebaseService>().saveQuestionnaire(q);
                  if (!mounted) return;
                  setState(() => _isCreating = false);
                },
                icon: Icons.save,
                label: 'Publicar e Notificar',
                isFullWidth: true,
              ),
            ),
            TextButton(
                onPressed: () => setState(() => _isCreating = false),
                child: const Center(child: Text('Cancelar')))
          ],
        ),
      );
    });
  }

  Widget _buildTargetingSection(
      List<String> targets, StateSetter setInternalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Destinatários',
            style: TextStyle(fontWeight: FontWeight.bold)),
        CheckboxListTile(
          title: const Text('Alunos'),
          value: targets.contains('student'),
          onChanged: (v) => setInternalState(
              () => v! ? targets.add('student') : targets.remove('student')),
        ),
        CheckboxListTile(
          title: const Text('Professores'),
          value: targets.contains('teacher'),
          onChanged: (v) => setInternalState(
              () => v! ? targets.add('teacher') : targets.remove('teacher')),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context, String label, DateTime current,
      Function(DateTime) onSelection) {
    return ListTile(
      title: Text('$label: ${DateFormat('dd/MM/yyyy').format(current)}'),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onSelection(d);
      },
    );
  }

  void _showAssignSpecialistDialog() {
    final service = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Nomear Especialista de Saúde',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<UserModel>>(
            stream: service.getUsers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final specialists = snapshot.data!
                  .where((u) => u.role == UserRole.healthSpecialist)
                  .toList();

              if (specialists.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                      'Nenhum utilizador com perfil "Especialista de Saúde" encontrado.',
                      style: TextStyle(color: Colors.white70)),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: specialists.length,
                itemBuilder: (context, index) {
                  final spec = specialists[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(spec.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(spec.email,
                        style: const TextStyle(color: Colors.white54)),
                    onTap: () async {
                      await service.assignHealthSpecialist(
                          'inst_default', spec.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Especialista de Saúde nomeado com sucesso!')));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showReopenDialog(Questionnaire q) {
    DateTime newEnd = q.endDate.add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reabrir Questionário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecione a nova data de encerramento.'),
            const SizedBox(height: 16),
            _buildDatePicker(context, 'Novo Fim', newEnd, (d) => newEnd = d),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          CustomButton(
            onPressed: () async {
              final fbService = context.read<FirebaseService>();
              await fbService.reopenQuestionnaire(
                  q.id, newEnd, 'Reabertura solicitada');
              if (!mounted) return;
              Navigator.pop(context);
            },
            label: 'Confirmar Reabertura',
          ),
        ],
      ),
    );
  }

  void _showAnalytics(Questionnaire q) async {
    final aiService = context.read<LifestyleAiService>();
    final fbService = context.read<FirebaseService>();

    final responses = await fbService.getQuestionnaireResponses(q.id).first;
    final analysis = await aiService.analyzeResults(q, responses);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Análise Estatística IA',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(q.title, style: const TextStyle(color: Colors.white70)),
              const Divider(height: 48),
              _buildStatsCard('Histograma de Distribuição',
                  'Frequência de Bem-estar'),
              const SizedBox(height: 24),
              _buildStatsCard('Diagrama de Extremos e Quartis',
                  'Distribuição de Qualidade de Vida'),
              const SizedBox(height: 32),
              Text('Análise Qualitativa',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(analysis['qualitativeAnalysis'] ?? 'Gerando...',
                  style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 32),
              Text('Estratégias Propostas',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: Colors.greenAccent)),
              const SizedBox(height: 12),
              ...(analysis['strategies'] as List? ?? []).map((s) => ListTile(
                    leading: const Icon(Icons.lightbulb, color: Colors.amber),
                    title: Text(s.toString()),
                  )),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                barGroups: [
                  BarChartGroupData(
                      x: 0,
                      barRods: [BarChartRodData(toY: 8, color: Colors.blueAccent)]),
                  BarChartGroupData(
                      x: 1,
                      barRods: [BarChartRodData(toY: 15, color: Colors.blueAccent)]),
                  BarChartGroupData(
                      x: 2,
                      barRods: [BarChartRodData(toY: 10, color: Colors.blueAccent)]),
                  BarChartGroupData(
                      x: 3,
                      barRods: [BarChartRodData(toY: 5, color: Colors.blueAccent)]),
                ],
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
