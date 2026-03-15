import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/credit_pricing_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class CreditPricingAdminScreen extends StatefulWidget {
  const CreditPricingAdminScreen({super.key});

  @override
  State<CreditPricingAdminScreen> createState() =>
      _CreditPricingAdminScreenState();
}

class _CreditPricingAdminScreenState extends State<CreditPricingAdminScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Tabela de Preços de Créditos'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<CreditPricing>>(
        stream: _firebaseService.getCreditPricingStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Erro: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent)));
          }

          final pricingList = snapshot.data ?? [];
          // Ensure all actions are present
          final defaultPricing = CreditPricing.getDefaultPricing();
          for (var dp in defaultPricing) {
            if (!pricingList.any((p) => p.id == dp.id)) {
              pricingList.add(dp);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF00D1FF)),
                      SizedBox(width: 12),
                      Expanded(
                        child: AiTranslatedText(
                          'Como administrador, pode definir quantos créditos cada ação consome para cada tipo de utilizador. Os valores são guardados em tempo real.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.05)),
                      columnSpacing: 32,
                      columns: [
                        const DataColumn(
                            label: AiTranslatedText('Ação / Funcionalidade',
                                style: TextStyle(color: Colors.white54))),
                        ...[
                          UserRole.institution,
                          UserRole.teacher,
                          UserRole.student
                        ].map((role) => DataColumn(
                              label: AiTranslatedText(
                                role.toString().split('.').last.toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF00D1FF), fontSize: 12),
                              ),
                            )),
                      ],
                      rows: pricingList
                          .map((pricing) => DataRow(
                                cells: [
                                  DataCell(
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AiTranslatedText(
                                              _getActionLabel(pricing.action),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          Text(pricing.action,
                                              style: const TextStyle(
                                                  color: Colors.white24,
                                                  fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ...[
                                    UserRole.institution,
                                    UserRole.teacher,
                                    UserRole.student
                                  ].map((role) => DataCell(
                                        _buildPriceCell(pricing, role),
                                      )),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceCell(CreditPricing pricing, UserRole role) {
    final currentPrice = pricing.prices[role] ?? 0;
    return InkWell(
      onTap: () => _editPrice(pricing, role),
      child: Container(
        width: 60,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$currentPrice',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _editPrice(CreditPricing pricing, UserRole role) {
    final controller =
        TextEditingController(text: (pricing.prices[role] ?? 0).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(
            'Editar Preço: ${_getActionLabel(pricing.action)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiTranslatedText(
                'Utilizador: ${role.toString().split('.').last.toUpperCase()}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Créditos',
                labelStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white10)),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newPrice = int.tryParse(controller.text);
              if (newPrice != null) {
                Navigator.pop(context);
                setState(() => _isSaving = true);
                try {
                  final newPrices = Map<UserRole, int>.from(pricing.prices);
                  newPrices[role] = newPrice;
                  final updated = CreditPricing(
                      id: pricing.id,
                      action: pricing.action,
                      prices: newPrices);
                  await _firebaseService.saveCreditPricing(updated);
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              }
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  String _getActionLabel(String action) {
    switch (action) {
      case CreditAction.createGame:
        return 'Criar Jogo IA';
      case CreditAction.createSubject:
        return 'Criar Disciplina';
      case CreditAction.registerSyllabus:
        return 'Registar Sumário';
      case CreditAction.generateCertificate:
        return 'Gerar Certificado';
      case CreditAction.createExam:
        return 'Criar Exame/Prova';
      default:
        return action;
    }
  }
}
