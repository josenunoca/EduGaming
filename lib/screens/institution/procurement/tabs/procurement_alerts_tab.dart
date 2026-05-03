import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class ProcurementAlertsTab extends StatefulWidget {
  final InstitutionModel institution;

  const ProcurementAlertsTab({super.key, required this.institution});

  @override
  State<ProcurementAlertsTab> createState() => _ProcurementAlertsTabState();
}

class _ProcurementAlertsTabState extends State<ProcurementAlertsTab> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final service = context.read<ProcurementService>();
    final alerts = await service.getLowStockAlerts(widget.institution.id);
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (_alerts.isNotEmpty) 
          _buildActionHeader()
        else
          const Expanded(child: Center(child: AiTranslatedText('Todo o stock está acima do nível de segurança. ✅', style: TextStyle(color: Colors.white54)))),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _alerts.length,
            itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionHeader() {
    final critical = _alerts.where((a) => a['type'] == 'critical').length;
    final warnings = _alerts.where((a) => a['type'] == 'warning').length;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GlassCard(
        color: critical > 0 ? Colors.redAccent : Colors.orangeAccent,
        opacity: 0.1,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                critical > 0 ? Icons.dangerous_outlined : Icons.warning_amber_rounded, 
                color: critical > 0 ? Colors.redAccent : Colors.orangeAccent
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AiTranslatedText(
                      'Resumo de Alertas de Stock',
                      style: TextStyle(color: critical > 0 ? Colors.redAccent : Colors.orangeAccent, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$critical Críticos • $warnings Próximos do Limite',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _generateSuggestedPO,
                icon: const Icon(Icons.assignment_add),
                label: const AiTranslatedText('Gerar Nota de Encomenda Sugerida'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final ProcurementItem item = alert['item'];
    final String size = alert['size'];
    final String color = alert['color'] ?? 'N/A';
    final double stock = alert['currentStock'];
    final bool isCritical = alert['type'] == 'critical';
    final double safetyStock = item.variantSafetyStocks["${size}_$color"] ?? item.minSafetyStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(size, style: TextStyle(color: isCritical ? Colors.redAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
          ),
          title: Text('${item.name} ($color)', style: const TextStyle(color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AiTranslatedText('Stock: ${stock.toInt()} (Segurança: ${safetyStock.toInt()})'),
                  const SizedBox(width: 8),
                  if (!isCritical) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                      child: const AiTranslatedText('Próximo do Limite', style: TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                    ),
                ],
              ),
              if (alert['onOrder'] > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Colors.blueAccent, size: 14),
                      const SizedBox(width: 4),
                      AiTranslatedText('Encomendado: ${alert['onOrder']} unidades a caminho', style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          trailing: Icon(isCritical ? Icons.error_outline : Icons.warning_amber_rounded, color: isCritical ? Colors.redAccent : Colors.orangeAccent),
        ),
      ),
    );
  }

  void _generateSuggestedPO() {
    final List<OrderItemDetails> orderItems = _alerts.map((a) {
      final ProcurementItem item = a['item'];
      return OrderItemDetails(
        itemId: item.id,
        itemName: item.name,
        itemReference: item.reference,
        size: a['size'],
        color: a['color'] ?? 'N/A',
        quantity: (a['suggestedOrder'] as double).toInt(),
        unitPrice: item.costPrice,
      );
    }).toList();

    showDialog(
      context: context,
      builder: (context) => _POEditorDialog(
        initialItems: orderItems,
        institution: widget.institution,
        onSubmit: (order) async {
          await context.read<ProcurementService>().savePurchaseOrder(order);
          _loadAlerts(); // Refresh
        },
      ),
    );
  }
}

class _POEditorDialog extends StatefulWidget {
  final List<OrderItemDetails> initialItems;
  final InstitutionModel institution;
  final Function(PurchaseOrder) onSubmit;

  const _POEditorDialog({required this.initialItems, required this.institution, required this.onSubmit});

  @override
  State<_POEditorDialog> createState() => _POEditorDialogState();
}

class _POEditorDialogState extends State<_POEditorDialog> {
  late List<OrderItemDetails> _editableItems;
  String _supplier = 'Fornecedor Principal';
  DateTime? _deliveryDate;

  @override
  void initState() {
    super.initState();
    _editableItems = List.from(widget.initialItems);
    _deliveryDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const AiTranslatedText('Nota de Encomenda Sugerida'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Fornecedor', border: OutlineInputBorder()),
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => _supplier = v,
              controller: TextEditingController(text: _supplier),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const AiTranslatedText('Prazo de Entrega Estimado', style: TextStyle(color: Colors.white70)),
              subtitle: Text(_deliveryDate == null ? 'Não definido' : DateFormat('dd/MM/yyyy').format(_deliveryDate!), style: const TextStyle(color: Colors.blueAccent)),
              trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _deliveryDate = date);
              },
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _editableItems.length,
                itemBuilder: (context, index) {
                  final item = _editableItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${item.itemName} (${item.size} / ${item.color})', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(suffixText: 'uni'),
                            style: const TextStyle(color: Colors.orangeAccent),
                            controller: TextEditingController(text: item.quantity.toString()),
                            onChanged: (val) {
                              final qty = int.tryParse(val) ?? 0;
                              _editableItems[index] = item.copyWith(quantity: qty);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _editableItems.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
        ElevatedButton.icon(
          onPressed: () {
            final total = _editableItems.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity));
            final order = PurchaseOrder(
              id: const Uuid().v4(),
              institutionId: widget.institution.id,
              supplierName: _supplier,
              orderDate: DateTime.now(),
              negotiatedDeliveryDate: _deliveryDate,
              items: _editableItems,
              status: 'ordered',
              totalAmount: total,
            );
            widget.onSubmit(order);
            Navigator.pop(context);
            context.read<ProcurementService>().generatePurchaseOrderPdf(order, widget.institution.name);
          },
          icon: const Icon(Icons.print),
          label: const AiTranslatedText('Adjudicar e Gerar PDF'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
        ),
      ],
    );
  }
}

extension on OrderItemDetails {
  OrderItemDetails copyWith({int? quantity}) {
    return OrderItemDetails(
      itemId: itemId,
      itemName: itemName,
      itemReference: itemReference,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
      quantityReceived: quantityReceived,
      unitPrice: unitPrice,
      costPrice: costPrice,
    );
  }
}
