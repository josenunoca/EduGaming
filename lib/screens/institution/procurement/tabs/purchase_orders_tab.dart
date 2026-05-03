import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class PurchaseOrdersTab extends StatefulWidget {
  final InstitutionModel institution;

  const PurchaseOrdersTab({super.key, required this.institution});

  @override
  State<PurchaseOrdersTab> createState() => _PurchaseOrdersTabState();
}

class _PurchaseOrdersTabState extends State<PurchaseOrdersTab> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: StreamBuilder<List<PurchaseOrder>>(
            stream: service.getPurchaseOrders(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final orders = snapshot.data!;

              if (orders.isEmpty) {
                return const Center(child: AiTranslatedText('Nenhuma nota de encomenda registada.', style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: orders.length,
                itemBuilder: (context, index) => _buildPOCard(context, service, orders[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AiTranslatedText('Notas de Encomenda (Fornecedores)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: () => _createNewPO(context),
            icon: const Icon(Icons.add),
            label: const AiTranslatedText('Nova Encomenda'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPOCard(BuildContext context, ProcurementService service, PurchaseOrder order) {
    final color = _getStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: ExpansionTile(
          collapsedTextColor: Colors.white,
          textColor: Colors.white,
          iconColor: Colors.blueAccent,
          collapsedIconColor: Colors.white54,
          title: Row(
            children: [
              Text('PO #${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.5))),
                child: Text(order.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.supplierName} • ${DateFormat('dd/MM/yyyy').format(order.orderDate)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (order.status != 'draft' && order.status != 'cancelled') ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.inventory_2, size: 10, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Satisfação: ${order.items.fold<int>(0, (acc, i) => acc + i.quantityReceived)} / ${order.items.fold<int>(0, (acc, i) => acc + i.quantity)} unidades',
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('€${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.print, color: Colors.white70), onPressed: () => service.generatePurchaseOrderPdf(order, widget.institution.name)),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(context, service, order)),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.negotiatedDeliveryDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available, color: Colors.blueAccent, size: 16),
                          const SizedBox(width: 8),
                          AiTranslatedText('Prazo de Entrega: ${DateFormat('dd/MM/yyyy').format(order.negotiatedDeliveryDate!)}', style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ...order.items.map((item) {
                    final progress = item.quantity > 0 ? item.quantityReceived / item.quantity : 0.0;
                    final isFulfilled = item.quantityReceived >= item.quantity;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(isFulfilled ? Icons.check_circle : Icons.radio_button_unchecked, 
                                   color: isFulfilled ? Colors.greenAccent : Colors.white24, size: 14),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${item.itemName} (${item.size}/${item.color})', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                              Text('${item.quantityReceived} / ${item.quantity}', style: TextStyle(color: isFulfilled ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(isFulfilled ? Colors.greenAccent : Colors.orangeAccent),
                              minHeight: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (order.status == 'draft' || order.status == 'ordered')
                        TextButton.icon(
                          onPressed: () => _markAsStatus(context, service, order, 'cancelled'),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                          label: const AiTranslatedText('Anular', style: TextStyle(color: Colors.redAccent)),
                        ),
                      const SizedBox(width: 8),
                      if (order.status == 'draft' || order.status == 'ordered')
                        TextButton.icon(
                          onPressed: () => _showMergeDialog(context, service, order),
                          icon: const Icon(Icons.merge_type, color: Colors.blueAccent, size: 18),
                          label: const AiTranslatedText('Juntar', style: TextStyle(color: Colors.blueAccent)),
                        ),
                      const SizedBox(width: 8),
                      if (order.status == 'draft')
                        ElevatedButton.icon(
                          onPressed: () => _markAsStatus(context, service, order, 'ordered'),
                          icon: const Icon(Icons.send),
                          label: const AiTranslatedText('Adjudicar'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2), foregroundColor: Colors.greenAccent),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft': return Colors.grey;
      case 'ordered': return Colors.blueAccent;
      case 'received': return Colors.greenAccent;
      case 'cancelled': return Colors.redAccent;
      default: return Colors.white;
    }
  }

  void _createNewPO(BuildContext context) {
     showDialog(
      context: context,
      builder: (context) => _POEditorDialog(
        institution: widget.institution,
        onSubmit: (order) => context.read<ProcurementService>().savePurchaseOrder(order),
      ),
    );
  }

  void _markAsStatus(BuildContext context, ProcurementService service, PurchaseOrder order, String status) {
    final updated = PurchaseOrder(
      id: order.id,
      institutionId: order.institutionId,
      supplierName: order.supplierName,
      orderDate: order.orderDate,
      negotiatedDeliveryDate: order.negotiatedDeliveryDate,
      items: order.items,
      status: status,
      totalAmount: order.totalAmount,
    );
    service.savePurchaseOrder(updated);
  }

  void _showMergeDialog(BuildContext context, ProcurementService service, PurchaseOrder sourceOrder) async {
    final orders = await service.getPurchaseOrders(widget.institution.id).first;
    final otherOrders = orders.where((o) => o.id != sourceOrder.id && o.status == 'draft' && o.supplierName == sourceOrder.supplierName).toList();

    if (otherOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Não existem outras encomendas em rascunho deste fornecedor para juntar.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Juntar Encomendas'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Selecione a encomenda para onde quer mover estes artigos:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ...otherOrders.map((target) => ListTile(
                title: Text('PO #${target.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.white)),
                subtitle: Text('${target.items.length} artigos • Total: €${target.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent),
                onTap: () {
                  _mergeOrders(service, sourceOrder, target);
                  Navigator.pop(context);
                },
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _mergeOrders(ProcurementService service, PurchaseOrder source, PurchaseOrder target) {
    final List<OrderItemDetails> newItems = List.from(target.items);
    
    for (var sItem in source.items) {
      final existingIndex = newItems.indexWhere((tItem) => tItem.itemId == sItem.itemId && tItem.size == sItem.size && tItem.color == sItem.color);
      if (existingIndex != -1) {
        final existing = newItems[existingIndex];
        newItems[existingIndex] = existing.copyWith(
          quantity: existing.quantity + sItem.quantity,
          quantityReceived: existing.quantityReceived + sItem.quantityReceived,
        );
      } else {
        newItems.add(sItem);
      }
    }

    final newTotal = newItems.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity));
    
    final updatedTarget = PurchaseOrder(
      id: target.id,
      institutionId: target.institutionId,
      supplierName: target.supplierName,
      orderDate: target.orderDate,
      negotiatedDeliveryDate: target.negotiatedDeliveryDate,
      items: newItems,
      status: target.status,
      totalAmount: newTotal,
    );

    service.savePurchaseOrder(updatedTarget);
    service.deletePurchaseOrder(source.institutionId, source.id);
  }

  void _confirmDelete(BuildContext context, ProcurementService service, PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar Encomenda?'),
        content: const AiTranslatedText('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () {
            service.deletePurchaseOrder(widget.institution.id, order.id);
            Navigator.pop(context);
          }, child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}

class _POEditorDialog extends StatefulWidget {
  final InstitutionModel institution;
  final PurchaseOrder? existingOrder;
  final List<OrderItemDetails>? initialItems;
  final Function(PurchaseOrder) onSubmit;

  const _POEditorDialog({required this.institution, this.existingOrder, this.initialItems, required this.onSubmit});

  @override
  State<_POEditorDialog> createState() => _POEditorDialogState();
}

class _POEditorDialogState extends State<_POEditorDialog> {
  late List<OrderItemDetails> _items;
  late TextEditingController _supplierController;
  DateTime? _deliveryDate;
  
  @override
  void initState() {
    super.initState();
    _items = widget.existingOrder?.items ?? widget.initialItems ?? [];
    _supplierController = TextEditingController(text: widget.existingOrder?.supplierName ?? 'Fornecedor Principal');
    _deliveryDate = widget.existingOrder?.negotiatedDeliveryDate;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: AiTranslatedText(widget.existingOrder == null ? 'Nova Nota de Encomenda' : 'Editar Nota de Encomenda'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supplierController,
                    decoration: const InputDecoration(labelText: 'Fornecedor', border: OutlineInputBorder()),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setState(() => _deliveryDate = date);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_deliveryDate == null ? 'Definir Entrega' : DateFormat('dd/MM/yyyy').format(_deliveryDate!)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Artigos na Encomenda', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _addItem(service),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const AiTranslatedText('Adicionar Artigo'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(item.itemName, style: const TextStyle(color: Colors.white, fontSize: 13))),
                        Expanded(flex: 2, child: Text('${item.size} / ${item.color}', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'Qtd'),
                            style: const TextStyle(color: Colors.orangeAccent),
                            onChanged: (v) => _items[index] = item.copyWith(quantity: int.tryParse(v) ?? 0),
                            controller: TextEditingController(text: item.quantity.toString()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(hintText: 'Custo', prefixText: '€'),
                            style: const TextStyle(color: Colors.greenAccent),
                            onChanged: (v) => _items[index] = item.copyWith(unitPrice: double.tryParse(v) ?? 0.0),
                            controller: TextEditingController(text: item.unitPrice.toString()),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _items.removeAt(index))),
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
        ElevatedButton(
          onPressed: () {
            final total = _items.fold<double>(0, (sum, item) => sum + (item.unitPrice * item.quantity));
            final order = PurchaseOrder(
              id: widget.existingOrder?.id ?? const Uuid().v4(),
              institutionId: widget.institution.id,
              supplierName: _supplierController.text,
              orderDate: widget.existingOrder?.orderDate ?? DateTime.now(),
              negotiatedDeliveryDate: _deliveryDate,
              items: _items,
              status: widget.existingOrder?.status ?? 'draft',
              totalAmount: total,
            );
            widget.onSubmit(order);
            Navigator.pop(context);
          },
          child: const AiTranslatedText('Guardar Encomenda'),
        ),
      ],
    );
  }

  void _addItem(ProcurementService service) async {
    // Show a search/select dialog for items
    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ItemSelectorDialog(institutionId: widget.institution.id),
    );

    if (item != null) {
      setState(() {
        _items.add(OrderItemDetails(
          itemId: item['item'].id,
          itemName: item['item'].name,
          itemReference: item['item'].reference,
          size: item['size'],
          color: item['color'] ?? 'N/A',
          quantity: 10,
          unitPrice: item['item'].costPrice,
        ));
      });
    }
  }
}

class _ItemSelectorDialog extends StatefulWidget {
  final String institutionId;
  const _ItemSelectorDialog({required this.institutionId});

  @override
  State<_ItemSelectorDialog> createState() => _ItemSelectorDialogState();
}

class _ItemSelectorDialogState extends State<_ItemSelectorDialog> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const AiTranslatedText('Selecionar Artigo'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Pesquisar...', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<ProcurementItem>>(
                stream: service.getItems(widget.institutionId),
                builder: (context, snapshot) {
                  final items = (snapshot.data ?? []).where((i) => i.name.toLowerCase().contains(_search.toLowerCase())).toList();
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ExpansionTile(
                        title: Text(item.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(item.reference, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        children: item.availableSizes.map((size) => ExpansionTile(
                          title: Text('Tamanho $size', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                          children: item.availableColors.map((color) => ListTile(
                            title: Text('Cor: $color', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            onTap: () => Navigator.pop(context, {'item': item, 'size': size, 'color': color}),
                            dense: true,
                          )).toList(),
                        )).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on OrderItemDetails {
  OrderItemDetails copyWith({int? quantity, int? quantityReceived, double? unitPrice}) {
    return OrderItemDetails(
      itemId: itemId,
      itemName: itemName,
      itemReference: itemReference,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice,
    );
  }
}
