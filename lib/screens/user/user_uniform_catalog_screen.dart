import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/institution_model.dart';
import '../../models/procurement/procurement_models.dart';
import '../../services/procurement_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import 'user_order_history_screen.dart';

import '../../models/user_model.dart';

class UserUniformCatalogScreen extends StatefulWidget {
  final InstitutionModel institution;
  final UserModel user;

  const UserUniformCatalogScreen({
    super.key, 
    required this.institution,
    required this.user,
  });

  @override
  State<UserUniformCatalogScreen> createState() => _UserUniformCatalogScreenState();
}

class _UserUniformCatalogScreenState extends State<UserUniformCatalogScreen> {
  // itemId -> { "size_color" -> quantity }
  final Map<String, Map<String, int>> _cart = {}; 
  bool _isOrdering = false;

  int _getTotalItems() {
    int total = 0;
    _cart.forEach((_, options) {
      options.forEach((_, qty) => total += qty);
    });
    return total;
  }

  void _updateQuantity(String itemId, String key, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart[itemId]?.remove(key);
        if (_cart[itemId]?.isEmpty ?? false) _cart.remove(itemId);
      } else {
        if (!_cart.containsKey(itemId)) _cart[itemId] = {};
        _cart[itemId]![key] = quantity;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Loja de Uniformes'),
        actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserOrderHistoryScreen(
                      institution: widget.institution,
                      user: widget.user,
                    ),
                  ),
                ),
                tooltip: 'Histórico de Encomendas',
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: _cart.isEmpty ? null : _showCartSummary,
                  ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      _getTotalItems().toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ProcurementItem>>(
              stream: service.getItems(widget.institution.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final items = snapshot.data!.where((i) => i.category == ProcurementCategory.uniform).toList();

                if (items.isEmpty) {
                  return const Center(child: AiTranslatedText('Nenhum uniforme disponível no momento.', style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildProductCard(service, items[index]),
                );
              },
            ),
          ),
          if (_cart.isNotEmpty) _buildCheckoutBar(),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProcurementService service, ProcurementItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      image: item.imageUrl != null 
                        ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: item.imageUrl == null ? const Icon(Icons.shopping_bag, color: Colors.white24, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        if (item.composition.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.composition, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                        const SizedBox(height: 12),
                        Text('€ ${item.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AiTranslatedText('Selecionar Opções (Tamanho / Cor):', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildOptionsGrid(service, item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsGrid(ProcurementService service, ProcurementItem item) {
    final colors = item.availableColors.isEmpty ? ['Padrão'] : item.availableColors;
    
    return Column(
      children: item.availableSizes.map((size) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors.map((color) => _buildOptionChip(service, item, size, color)).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionChip(ProcurementService service, ProcurementItem item, String size, String color) {
    final key = '${size}_$color';
    return StreamBuilder<double>(
      stream: service.getAvailableStockLevel(widget.institution.id, item.id, size: size, color: color == 'Padrão' ? 'N/A' : color),
      builder: (context, snapshot) {
        final stock = snapshot.data ?? 0.0;
        final selectedQty = _cart[item.id]?[key] ?? 0;
        final selected = selectedQty > 0;
        final hasStock = stock > 0;

        return GestureDetector(
          onTap: hasStock ? () => _showQuantityDialog(item, key, stock.toInt()) : null,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFF9F1C) : (hasStock ? Colors.white.withValues(alpha: 0.05) : Colors.black26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? Colors.orange : (hasStock ? Colors.white10 : Colors.transparent)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$size / $color', style: TextStyle(color: selected ? Colors.black : (hasStock ? Colors.white : Colors.white24), fontSize: 13, fontWeight: FontWeight.bold)),
                    if (hasStock)
                      Text('Stock: ${stock.toInt()}', style: TextStyle(color: selected ? Colors.black54 : Colors.white38, fontSize: 10)),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle, size: 16, color: Colors.black87),
                  const SizedBox(width: 4),
                  Text('$selectedQty', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ],
                if (!hasStock) ...[
                  const SizedBox(width: 8),
                  const AiTranslatedText('Esgotado', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(ProcurementItem item, String key, int maxStock) {
    int currentQty = _cart[item.id]?[key] ?? 0;
    if (currentQty == 0 && maxStock > 0) currentQty = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('${item.name} (${key.replaceAll('_', ' / ')})', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Escolha a quantidade:', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 32),
                    onPressed: currentQty > 0 ? () => setModalState(() => currentQty--) : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$currentQty', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF9F1C), size: 32),
                    onPressed: currentQty < maxStock ? () => setModalState(() => currentQty++) : null,
                  ),
                ],
              ),
              if (currentQty >= maxStock)
                const Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: AiTranslatedText('Stock máximo atingido', style: TextStyle(color: Colors.orange, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateQuantity(item.id, key, currentQty);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: AiTranslatedText('Carrinho atualizado!'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFFF9F1C),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C)),
              child: const AiTranslatedText('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartSummary() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final service = context.read<ProcurementService>();
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                const AiTranslatedText('O seu Carrinho', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<List<ProcurementItem>>(
                    stream: service.getItems(widget.institution.id),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final allItems = snap.data!;
                      
                      final cartList = <Map<String, dynamic>>[];
                      double total = 0;

                      _cart.forEach((itemId, options) {
                        final item = allItems.firstWhere((i) => i.id == itemId);
                        options.forEach((key, qty) {
                          cartList.add({'item': item, 'key': key, 'qty': qty});
                          total += item.price * qty;
                        });
                      });

                      if (cartList.isEmpty) {
                        return const Center(child: AiTranslatedText('O carrinho está vazio', style: TextStyle(color: Colors.white54)));
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: cartList.length,
                              itemBuilder: (context, index) {
                                final entry = cartList[index];
                                final ProcurementItem item = entry['item'];
                                final String key = entry['key'];
                                final int qty = entry['qty'];
                                final parts = key.split('_');

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                        child: item.imageUrl != null ? Image.network(item.imageUrl!, fit: BoxFit.cover) : const Icon(Icons.shopping_bag, size: 20),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            Text('${parts[0]} / ${parts[1]}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('€ ${(item.price * qty).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF9F1C), fontWeight: FontWeight.bold)),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white24),
                                                onPressed: () {
                                                  _updateQuantity(item.id, key, qty - 1);
                                                  setModalState(() {});
                                                },
                                              ),
                                              Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFFFF9F1C)),
                                                onPressed: () {
                                                  _updateQuantity(item.id, key, qty + 1);
                                                  setModalState(() {});
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const AiTranslatedText('Total:', style: TextStyle(color: Colors.white54, fontSize: 16)),
                                    Text('€ ${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isOrdering ? null : () {
                                      Navigator.pop(context);
                                      _handleCheckout();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF9F1C),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _isOrdering 
                                      ? const CircularProgressIndicator(color: Colors.black)
                                      : const AiTranslatedText('Finalizar e Pagar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutBar() {
    int totalItems = _getTotalItems();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Artigos no carrinho:', style: TextStyle(color: Colors.white54)),
              Text(totalItems.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _showCartSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const AiTranslatedText('Ver Carrinho e Finalizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
    setState(() => _isOrdering = true);
    
    try {
      final service = context.read<ProcurementService>();
      final items = await service.getItems(widget.institution.id).first;
      
      final orderItems = <OrderItemDetails>[];
      double totalAmount = 0;

      _cart.forEach((itemId, options) {
        final item = items.firstWhere((i) => i.id == itemId);
        options.forEach((key, qty) {
          final parts = key.split('_');
          final size = parts[0];
          final color = parts[1];

          orderItems.add(OrderItemDetails(
            itemId: item.id,
            itemName: item.name,
            itemReference: item.reference,
            size: size,
            color: color == 'Padrão' ? 'N/A' : color,
            quantity: qty,
            unitPrice: item.price,
          ));
          totalAmount += item.price * qty;
        });
      });

      final order = ProcurementOrder(
        id: const Uuid().v4(),
        institutionId: widget.institution.id,
        customerId: widget.user.id,
        customerName: widget.user.name,
        orderDate: DateTime.now(),
        items: orderItems,
        status: OrderStatus.pending,
        totalAmount: totalAmount,
      );

      await service.placeOrder(order);

      if (mounted) {
        _showPaymentInstructions(totalAmount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao processar encomenda: $e')));
      }
    } finally {
      if (mounted) setState(() => _isOrdering = false);
    }
  }

  void _showPaymentInstructions(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const AiTranslatedText('Sucesso!', style: TextStyle(color: Color(0xFF00FF85))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('A sua encomenda foi registada com sucesso.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Total a Pagar:', style: TextStyle(color: Colors.white54)),
                Text('€ ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 24),
            const AiTranslatedText('Métodos de Pagamento:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            if (widget.institution.mbwayPhone != null) ...[
              _buildPaymentOption(Icons.phone_android, 'MBWay', widget.institution.mbwayPhone!, Colors.pinkAccent),
            ],
            if (widget.institution.iban != null) ...[
              const SizedBox(height: 8),
              _buildPaymentOption(Icons.account_balance, 'IBAN', widget.institution.iban!, Colors.blueAccent),
            ],
          ],
        ),
        actions: [
          CustomButton(
            label: 'Concluído', 
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                SelectableText(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
