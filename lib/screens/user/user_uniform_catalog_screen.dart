import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';


import '../../models/institution_model.dart';
import '../../models/procurement/procurement_models.dart';
import '../../models/user_model.dart';
import '../../services/procurement_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import 'user_order_history_screen.dart';

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

  double _getTotalPrice(List<ProcurementItem> allItems) {
    double total = 0;
    _cart.forEach((itemId, options) {
      final item = allItems.firstWhere((i) => i.id == itemId, orElse: () => throw Exception('Item not found'));
      options.forEach((_, qty) => total += item.price * qty);
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
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildCatalogList(service),
        ],
      ),
      bottomNavigationBar: _buildAnimatedCheckoutBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.8),
      flexibleSpace: FlexibleSpaceBar(
        title: const AiTranslatedText('Loja de Uniformes', 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E293B).withValues(alpha: 0.5),
                const Color(0xFF0F172A),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserOrderHistoryScreen(
                institution: widget.institution,
                user: widget.user,
              ),
            ),
          ),
          tooltip: 'Histórico',
        ),
        _buildCartBadge(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCartBadge() {
    final total = _getTotalItems();
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: _cart.isEmpty ? null : _showCartSummary,
        ),
        if (total > 0)
          Positioned(
            right: 8,
            top: 8,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFFFF9F1C), shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    total.toString(),
                    style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCatalogList(ProcurementService service) {
    return StreamBuilder<List<ProcurementItem>>(
      stream: service.getItems(widget.institution.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }
        
        final items = snapshot.data!.where((i) => i.category == ProcurementCategory.uniform).toList();

        if (items.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.white10, size: 64),
                  SizedBox(height: 16),
                  AiTranslatedText('Nenhum uniforme disponível.', style: TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(service, items[index]),
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(ProcurementService service, ProcurementItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImage(item),
                  const SizedBox(width: 16),
                  Expanded(child: _buildProductHeader(item)),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AiTranslatedText('Escolha as suas opções:', 
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 16),
                  _buildOptionsGrid(service, item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(ProcurementItem item) {
    return Hero(
      tag: 'item_${item.id}',
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
          ],
          image: item.imageUrl != null 
            ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover)
            : null,
        ),
        child: item.imageUrl == null 
          ? const Icon(Icons.shopping_bag_outlined, color: Colors.white24, size: 28) 
          : null,
      ),
    );
  }

  Widget _buildProductHeader(ProcurementItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, 
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)
        ),
        if (item.composition.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(item.composition, 
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9F1C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('€ ${item.price.toStringAsFixed(2)}', 
            style: const TextStyle(color: Color(0xFFFF9F1C), fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsGrid(ProcurementService service, ProcurementItem item) {
    final colors = item.availableColors.isEmpty ? ['Padrão'] : item.availableColors;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: item.availableSizes.map((size) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: Colors.white24, size: 14),
                  const SizedBox(width: 8),
                  Text('Tamanho $size', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: colors.map((color) => _buildOptionChip(service, item, size, color)).toList(),
              ),
            ],
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

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: hasStock ? () => _showQuantityDialog(item, key, stock.toInt()) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected 
                    ? const Color(0xFFFF9F1C) 
                    : (hasStock ? Colors.white.withValues(alpha: 0.05) : Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.orange : (hasStock ? Colors.white10 : Colors.transparent),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(color, 
                      style: TextStyle(
                        color: selected ? Colors.black : (hasStock ? Colors.white : Colors.white24), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, size: 14, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text('$selectedQty', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                    if (!hasStock) ...[
                      const SizedBox(width: 8),
                      const AiTranslatedText('Esgotado', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(ProcurementItem item, String key, int maxStock) {
    int currentQty = _cart[item.id]?[key] ?? 0;
    if (currentQty == 0 && maxStock > 0) currentQty = 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(key.replaceAll('_', ' / '), style: const TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQtyAction(Icons.remove_rounded, currentQty > 0 ? () => setModalState(() => currentQty--) : null),
                  Container(
                    width: 80,
                    alignment: Alignment.center,
                    child: Text('$currentQty', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  ),
                  _buildQtyAction(Icons.add_rounded, currentQty < maxStock ? () => setModalState(() => currentQty++) : null, isAdd: true),
                ],
              ),
              const SizedBox(height: 8),
              Text('Stock disponível: $maxStock', style: const TextStyle(color: Colors.white24, fontSize: 12)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    _updateQuantity(item.id, key, currentQty);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9F1C),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const AiTranslatedText('Confirmar Seleção', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyAction(IconData icon, VoidCallback? onTap, {bool isAdd = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAdd ? const Color(0xFFFF9F1C).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: isAdd ? const Color(0xFFFF9F1C).withValues(alpha: 0.2) : Colors.white10),
          ),
          child: Icon(icon, color: isAdd ? const Color(0xFFFF9F1C) : Colors.white54, size: 28),
        ),
      ),
    );
  }

  void _showCartSummary() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final service = context.read<ProcurementService>();
              return StreamBuilder<List<ProcurementItem>>(
                stream: service.getItems(widget.institution.id),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final allItems = snap.data!;
                  final cartList = <Map<String, dynamic>>[];
                  
                  _cart.forEach((itemId, options) {
                    final item = allItems.firstWhere((i) => i.id == itemId);
                    options.forEach((key, qty) {
                      cartList.add({'item': item, 'key': key, 'qty': qty});
                    });
                  });

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: AiTranslatedText('O seu Carrinho', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cartList.length,
                          itemBuilder: (context, index) => _buildCartItem(cartList[index], setModalState),
                        ),
                      ),
                      _buildCartFooter(allItems),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> entry, StateSetter setModalState) {
    final ProcurementItem item = entry['item'];
    final String key = entry['key'];
    final int qty = entry['qty'];
    final parts = key.split('_');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: Colors.white10, 
              borderRadius: BorderRadius.circular(12),
              image: item.imageUrl != null ? DecorationImage(image: NetworkImage(item.imageUrl!), fit: BoxFit.cover) : null,
            ),
            child: item.imageUrl == null ? const Icon(Icons.shopping_bag_outlined, size: 24, color: Colors.white24) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${parts[0]} / ${parts[1]}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('€ ${(item.price * qty).toStringAsFixed(2)}', 
                style: const TextStyle(color: Color(0xFFFF9F1C), fontWeight: FontWeight.bold, fontSize: 15)
              ),
              const SizedBox(height: 4),
              _buildCompactQtySelector(item, key, qty, setModalState),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQtySelector(ProcurementItem item, String key, int qty, StateSetter setModalState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 14, color: Colors.white54),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              _updateQuantity(item.id, key, qty - 1);
              setModalState(() {});
            },
          ),
          Text('$qty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          IconButton(
            icon: const Icon(Icons.add, size: 14, color: Color(0xFFFF9F1C)),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              _updateQuantity(item.id, key, qty + 1);
              setModalState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartFooter(List<ProcurementItem> allItems) {
    final total = _getTotalPrice(allItems);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Total Estimado:', style: TextStyle(color: Colors.white54, fontSize: 15)),
              Text('€ ${total.toStringAsFixed(2)}', 
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1)
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isOrdering ? null : () {
                Navigator.pop(context);
                _handleCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isOrdering 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const AiTranslatedText('Finalizar Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCheckoutBar() {
    final totalItems = _getTotalItems();
    return AnimatedSlide(
      offset: totalItems > 0 ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AiTranslatedText('No carrinho:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('$totalItems artigos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showCartSummary,
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
              label: const AiTranslatedText('Ver Carrinho'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
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
          orderItems.add(OrderItemDetails(
            itemId: item.id,
            itemName: item.name,
            itemReference: item.reference,
            size: parts[0],
            color: parts[1] == 'Padrão' ? 'N/A' : parts[1],
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
      if (mounted) _showPaymentInstructions(totalAmount);
      setState(() => _cart.clear());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const AiTranslatedText('Pedido Registado!', style: TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('A sua encomenda foi submetida com sucesso.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const AiTranslatedText('Total:', style: TextStyle(color: Colors.white54)),
                Text('€ ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
              ],
            ),
            const SizedBox(height: 24),
            const AiTranslatedText('Pagamento via:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
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
            label: 'Ver Encomendas', 
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserOrderHistoryScreen(institution: widget.institution, user: widget.user)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                SelectableText(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
