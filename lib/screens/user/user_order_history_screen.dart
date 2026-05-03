import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/procurement/procurement_models.dart';
import '../../services/procurement_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

import '../../models/institution_model.dart';
import '../../models/user_model.dart';

class UserOrderHistoryScreen extends StatelessWidget {
  final InstitutionModel institution;
  final UserModel user;

  const UserOrderHistoryScreen({
    super.key,
    required this.institution,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const AiTranslatedText('Minhas Encomendas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Em Curso'),
              Tab(text: 'Finalizadas'),
            ],
            indicatorColor: Color(0xFFFF9F1C),
            labelColor: Color(0xFFFF9F1C),
            unselectedLabelColor: Colors.white54,
          ),
        ),
        body: StreamBuilder<List<ProcurementOrder>>(
          stream: FirebaseFirestore.instance
              .collection('institutions')
              .doc(institution.id)
              .collection('procurement_orders')
              .where('customerId', isEqualTo: user.id)
              .orderBy('orderDate', descending: true)
              .snapshots()
              .map((snap) => snap.docs.map((doc) => ProcurementOrder.fromMap(doc.id, doc.data())).toList()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return const Center(
                child: AiTranslatedText('Ainda não realizou nenhuma encomenda.', style: TextStyle(color: Colors.white54)),
              );
            }

            final activeOrders = orders.where((o) => [OrderStatus.pending, OrderStatus.preparing, OrderStatus.ready].contains(o.status)).toList();
            final finishedOrders = orders.where((o) => [OrderStatus.delivered, OrderStatus.cancelled].contains(o.status)).toList();

            return TabBarView(
              children: [
                _buildOrderList(context, activeOrders),
                _buildOrderList(context, finishedOrders),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(BuildContext context, List<ProcurementOrder> orders) {
    if (orders.isEmpty) {
      return const Center(child: AiTranslatedText('Sem encomendas nesta categoria.', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
    );
  }

  Widget _buildOrderCard(BuildContext context, ProcurementOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              Text(DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate), style: const TextStyle(color: Colors.white24, fontSize: 12)),
              const Divider(color: Colors.white10, height: 32),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${item.quantity}x ${item.itemName}', style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Text('€ ${(item.unitPrice * item.quantity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
              )),
              const Divider(color: Colors.white10, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AiTranslatedText('TOTAL', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('€ ${order.totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              if (order.invoiceNumber != null || order.invoiceNotes != null || order.invoiceAmount != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_shipping, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 8),
                          AiTranslatedText('Informação de Entrega:', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (order.invoiceNumber != null)
                        Text('Guia/Fatura Nº: ${order.invoiceNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (order.invoiceAmount != null)
                        Text('Valor Liquidado: € ${order.invoiceAmount!.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00FF85), fontSize: 12, fontWeight: FontWeight.bold)),
                      if (order.invoiceNotes != null) ...[
                        const SizedBox(height: 4),
                        Text(order.invoiceNotes!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
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

  Widget _buildStatusBadge(OrderStatus status) {
    Color color;
    switch (status) {
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
