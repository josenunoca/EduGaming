import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class ProcurementOrdersTab extends StatelessWidget {
  final InstitutionModel institution;

  const ProcurementOrdersTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return StreamBuilder<List<ProcurementOrder>>(
      stream: FirebaseFirestore.instance
          .collection('institutions')
          .doc(institution.id)
          .collection('procurement_orders')
          .orderBy('orderDate', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) => ProcurementOrder.fromMap(doc.id, doc.data())).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(context, service, orders[index]),
        );
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, ProcurementService service, ProcurementOrder order) {
    final firebaseService = context.read<FirebaseService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pedido #${order.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(order.customerName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate), style: const TextStyle(color: Colors.white24, fontSize: 12)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    AiTranslatedText('${item.quantity}x ${item.itemName}', style: const TextStyle(color: Colors.white)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                      child: Text('${item.size} / ${item.color}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ),
                    const SizedBox(width: 12),
                    Text('€ ${(item.unitPrice * item.quantity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )),
              const Divider(color: Colors.white10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AiTranslatedText('TOTAL A PAGAR', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('€ ${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              if (order.status == OrderStatus.pending && service.canFulfillOrders(firebaseService.currentUserModel!, institution)) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showFulfillmentDialog(context, service, order, firebaseService),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF85),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const AiTranslatedText('Satisfazer e Entregar'),
                  ),
                ),
              ] else if (order.status == OrderStatus.delivered) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => service.generateDeliveryNotePdf(order, institution.name),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const AiTranslatedText('Guia Entrega PDF', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (service.canInvoiceOrders(firebaseService.currentUserModel!, institution)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showInvoicingDialog(context, service, order, firebaseService),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const AiTranslatedText('Registar Faturação', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF9F1C),
                            side: const BorderSide(color: Color(0xFFFF9F1C)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else if (order.status == OrderStatus.invoiced) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AiTranslatedText('Encomenda Faturada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Fatura: ${order.invoiceNumber} | € ${order.invoiceAmount?.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white70),
                        onPressed: () => service.generateInvoicePdf(order, institution.name),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showFulfillmentDialog(BuildContext context, ProcurementService service, ProcurementOrder order, FirebaseService firebaseService) {
    String? selectedWarehouseId;
    final invoiceController = TextEditingController();
    final notesController = TextEditingController();
    double? order_invoice_amount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Satisfazer Encomenda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AiTranslatedText('Armazém de saída:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                StreamBuilder<List<Warehouse>>(
                  stream: service.getWarehouses(institution.id),
                  builder: (context, snap) {
                    final warehouses = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedWarehouseId,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (v) => setDialogState(() => selectedWarehouseId = v),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const AiTranslatedText('Nº da Guia / Fatura (Opcional):', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: invoiceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: FT 2024/123',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                const AiTranslatedText('Valor da Fatura (Opcional):', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: ''), 
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => order_invoice_amount = double.tryParse(v),
                  decoration: InputDecoration(
                    hintText: 'Ex: 45.00',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                const AiTranslatedText('Notas Adicionais (Opcional):', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Notas adicionais...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: selectedWarehouseId == null ? null : () async {
                Navigator.pop(context);
                await service.fulfillOrder(
                  institution.id, 
                  order.id, 
                  selectedWarehouseId!, 
                  firebaseService.currentUserModel!,
                  invoiceNumber: invoiceController.text.isEmpty ? null : invoiceController.text,
                  invoiceNotes: notesController.text.isEmpty ? null : notesController.text,
                  invoiceAmount: order_invoice_amount,
                );
                // Auto generate PDF after fulfillment
                await service.generateInvoicePdf(order, institution.name);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF85), foregroundColor: Colors.black),
              child: const AiTranslatedText('Confirmar Entrega'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoicingDialog(BuildContext context, ProcurementService service, ProcurementOrder order, FirebaseService firebaseService) {
    final invoiceController = TextEditingController(text: order.invoiceNumber);
    final amountController = TextEditingController(text: order.invoiceAmount?.toString() ?? order.totalAmount.toString());
    final notesController = TextEditingController(text: order.invoiceNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Registar Faturação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiTranslatedText('Introduza os dados da fatura emitida no software externo.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: invoiceController,
              decoration: const InputDecoration(labelText: 'Número da Fatura', border: OutlineInputBorder()),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Valor Total Faturado (€)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas / Observações', border: OutlineInputBorder()),
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (invoiceController.text.isEmpty) return;
              await service.invoiceOrder(
                institution.id, 
                order.id, 
                firebaseService.currentUserModel!,
                invoiceNumber: invoiceController.text,
                invoiceAmount: double.tryParse(amountController.text),
                invoiceNotes: notesController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C)),
            child: const AiTranslatedText('Confirmar e Finalizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    switch (status) {
      case OrderStatus.invoiced: color = Colors.green; break;
      case OrderStatus.delivered: color = Colors.greenAccent; break;
      case OrderStatus.pending: color = Colors.orangeAccent; break;
      case OrderStatus.cancelled: color = Colors.redAccent; break;
      default: color = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: AiTranslatedText(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
