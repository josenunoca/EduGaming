import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class ProcurementEntriesTab extends StatelessWidget {
  final InstitutionModel institution;

  const ProcurementEntriesTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();
    return StreamBuilder<List<SupplyEntry>>(
      stream: service.getSupplyEntries(institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: entries.length,
          itemBuilder: (context, index) => _buildEntryCard(context, entries[index]),
        );
      },
    );
  }

  Widget _buildEntryCard(BuildContext context, SupplyEntry entry) {
    final totalValue = entry.items.fold<double>(0, (sum, item) => sum + ((item.costPrice ?? 0.0) * item.quantity));
    final totalQty = entry.items.fold<double>(0, (sum, item) => sum + item.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: ExpansionTile(
          collapsedTextColor: Colors.white,
          textColor: Colors.white,
          iconColor: Colors.orangeAccent,
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Fatura: ${entry.invoiceNumber.isEmpty ? "S/N" : entry.invoiceNumber} • ${entry.supplierName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '€${totalValue.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('dd/MM/yyyy').format(entry.intakeDate)} • ${totalQty.toInt()} unidades',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                entry.items.map((i) => '${i.itemName} (${i.size})').join(', '),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.blueAccent),
            onPressed: () => _showEditEntryDialog(context, entry),
            tooltip: 'Editar Entrada',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(color: Colors.white10),
                  ...entry.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              item.size,
                              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${item.itemReference ?? "-"} • Cor: ${item.color}',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.quantity.toInt()} uni x €${(item.costPrice ?? 0.0).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              '€${((item.costPrice ?? 0.0) * item.quantity).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEntryDialog(BuildContext context, SupplyEntry entry) {
    final service = context.read<ProcurementService>();
    final firebaseService = context.read<FirebaseService>();
    final performer = firebaseService.currentUserModel!;
    
    DateTime selectedDate = entry.intakeDate;
    final Map<String, TextEditingController> qtyControllers = {};
    final Map<String, TextEditingController> costControllers = {};
    
    for (var item in entry.items) {
      final key = '${item.itemId}_${item.size}_${item.color}';
      qtyControllers[key] = TextEditingController(text: item.quantity.toString());
      costControllers[key] = TextEditingController(text: (item.costPrice ?? 0.0).toString());
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Editar Entrada de Stock'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const AiTranslatedText('Data de Entrada', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, color: Colors.orangeAccent, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => selectedDate = picked);
                    },
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  ...entry.items.map((item) {
                    final key = '${item.itemId}_${item.size}_${item.color}';
                    final qty = double.tryParse(qtyControllers[key]!.text) ?? 0.0;
                    final cost = double.tryParse(costControllers[key]!.text) ?? 0.0;
                    final total = qty * cost;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.itemName}${item.itemReference != null ? " [${item.itemReference}]" : ""} - ${item.size} / ${item.color}', 
                            style: const TextStyle(color: Color(0xFFFF9F1C), fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: qtyControllers[key],
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Qtd',
                                    labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: costControllers[key],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Preço Custo',
                                    labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                    prefixText: '€',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 80,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                                child: Column(
                                  children: [
                                    const AiTranslatedText('Total', style: TextStyle(color: Colors.white38, fontSize: 9)),
                                    Text('€${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final List<OrderItemDetails> updatedItems = [];
                for (var item in entry.items) {
                  final key = '${item.itemId}_${item.size}_${item.color}';
                  updatedItems.add(OrderItemDetails(
                    itemId: item.itemId,
                    itemName: item.itemName,
                    itemReference: item.itemReference,
                    size: item.size,
                    color: item.color,
                    quantity: int.tryParse(qtyControllers[key]!.text) ?? 0,
                    unitPrice: item.unitPrice,
                    costPrice: double.tryParse(costControllers[key]!.text) ?? 0.0,
                  ));
                }

                final updatedEntry = SupplyEntry(
                  id: entry.id,
                  institutionId: entry.institutionId,
                  supplierName: entry.supplierName,
                  warehouseId: entry.warehouseId,
                  intakeDate: selectedDate,
                  items: updatedItems,
                  invoiceNumber: entry.invoiceNumber,
                );

                await service.updateSupplyEntry(performer, updatedEntry);
                if (context.mounted) Navigator.pop(context);
              },
              child: const AiTranslatedText('Guardar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
