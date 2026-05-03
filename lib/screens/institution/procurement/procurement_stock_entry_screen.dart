import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/custom_button.dart';
import '../../../../models/user_model.dart';

class ProcurementStockEntryScreen extends StatefulWidget {
  final InstitutionModel institution;

  const ProcurementStockEntryScreen({super.key, required this.institution});

  @override
  State<ProcurementStockEntryScreen> createState() => _ProcurementStockEntryScreenState();
}

class _ProcurementStockEntryScreenState extends State<ProcurementStockEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedWarehouseId;
  String? _selectedPoId;
  final List<_EntryLine> _lines = [];
  
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _addLine();
  }

  void _addLine() {
    setState(() {
      _lines.add(_EntryLine());
    });
  }

  void _removeLine(int index) {
    if (_lines.length > 1) {
      setState(() {
        _lines.removeAt(index);
      });
    }
  }

  void _duplicateLine(int index) {
    final original = _lines[index];
    setState(() {
      _lines.insert(index + 1, _EntryLine(
        itemId: original.itemId,
        size: original.size,
        color: original.color,
        quantity: original.quantity,
        costPrice: original.costPrice,
      ));
    });
  }

  Future<void> _loadFromPo(PurchaseOrder po) async {
    setState(() {
      _selectedPoId = po.id;
      _supplierController.text = po.supplierName;
      _lines.clear();
      for (var item in po.items) {
        final pending = item.quantity - item.quantityReceived;
        if (pending > 0) {
          _lines.add(_EntryLine(
            itemId: item.itemId,
            size: item.size,
            color: item.color,
            quantity: pending,
            costPrice: item.costPrice ?? 0,
          ));
        }
      }
      if (_lines.isEmpty) _addLine();
    });
  }

  Future<void> _submit() async {
    if (_selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Selecione o armazém de destino.')));
      return;
    }

    final service = context.read<ProcurementService>();
    final allItems = await service.getItems(widget.institution.id).first;
    
    List<OrderItemDetails> entryItems = [];
    
    for (var line in _lines) {
      if (line.itemId == null || line.size == null) continue;
      
      final item = allItems.firstWhere((i) => i.id == line.itemId);
      entryItems.add(OrderItemDetails(
        itemId: item.id,
        itemName: item.name,
        itemReference: item.reference,
        size: line.size!,
        color: line.color ?? 'N/A',
        quantity: line.quantity,
        unitPrice: item.price,
        costPrice: line.costPrice > 0 ? line.costPrice : item.costPrice,
      ));
    }

    if (entryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Adicione pelo menos um artigo válido.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final performer = context.read<FirebaseService>().currentUserModel!;
      
      final entry = SupplyEntry(
        id: const Uuid().v4(),
        institutionId: widget.institution.id,
        supplierName: _supplierController.text.isEmpty ? 'Diversos' : _supplierController.text,
        warehouseId: _selectedWarehouseId!,
        intakeDate: DateTime.now(),
        items: entryItems,
        invoiceNumber: _invoiceController.text,
        purchaseOrderId: _selectedPoId,
      );

      await service.loadSupplyEntry(performer, entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProcurementService>();
    final user = context.read<FirebaseService>().currentUserModel!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Entrada de Stock'),
        actions: [
          TextButton.icon(
            onPressed: () => _showPoPicker(context, service),
            icon: const Icon(Icons.shopping_cart, color: Color(0xFFFF9F1C)),
            label: const AiTranslatedText('Carregar PO', style: TextStyle(color: Color(0xFFFF9F1C))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(service, user),
                        const SizedBox(height: 32),
                        const AiTranslatedText('Artigos e Quantidades', style: TextStyle(color: Color(0xFFFF9F1C), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ...List.generate(_lines.length, (index) => _buildLineItem(index, service)),
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _addLine,
                            icon: const Icon(Icons.add),
                            label: const AiTranslatedText('Adicionar Linha'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
    );
  }

  Widget _buildHeader(ProcurementService service, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Configuração Geral', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          StreamBuilder<List<Warehouse>>(
            stream: service.getWarehouses(widget.institution.id),
            builder: (context, snap) {
              final allWarehouses = snap.data ?? [];
              final allowedWarehouses = allWarehouses.where((w) => 
                service.canManageStockGlobally(user, widget.institution) || 
                service.canManageStockForWarehouse(user, widget.institution, w.id)
              ).toList();

              return DropdownButtonFormField<String>(
                value: _selectedWarehouseId,
                decoration: const InputDecoration(labelText: 'Armazém de Destino', border: OutlineInputBorder()),
                dropdownColor: const Color(0xFF1E293B),
                items: allowedWarehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (v) => setState(() => _selectedWarehouseId = v),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(labelText: 'Fornecedor', border: OutlineInputBorder()),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(labelText: 'Nº Fatura / Guia', border: OutlineInputBorder()),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          if (_selectedPoId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('Vinculado à PO: #${_selectedPoId!.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _selectedPoId = null),
                    child: const Icon(Icons.close, size: 14, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineItem(int index, ProcurementService service) {
    final line = _lines[index];
    
    return StreamBuilder<List<ProcurementItem>>(
      stream: service.getItems(widget.institution.id),
      builder: (context, snap) {
        final items = snap.data ?? [];
        ProcurementItem? selectedItem;
        try {
          selectedItem = items.firstWhere((i) => i.id == line.itemId);
        } catch(_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: line.itemId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Artigo', border: OutlineInputBorder()),
                      dropdownColor: const Color(0xFF1E293B),
                      items: items.map((i) => DropdownMenuItem(value: i.id, child: Text(i.reference.isNotEmpty ? '[${i.reference}] ${i.name}' : i.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() {
                        line.itemId = v;
                        line.size = null;
                        line.color = null;
                        if (v != null) {
                          final it = items.firstWhere((i) => i.id == v);
                          line.costPrice = it.costPrice;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => _duplicateLine(index), icon: const Icon(Icons.copy, color: Colors.blue, size: 20)),
                  IconButton(onPressed: () => _removeLine(index), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)),
                ],
              ),
              if (selectedItem != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: line.size,
                        decoration: const InputDecoration(labelText: 'Tam.', border: OutlineInputBorder()),
                        dropdownColor: const Color(0xFF1E293B),
                        items: selectedItem.availableSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => line.size = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: line.color,
                        decoration: const InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
                        dropdownColor: const Color(0xFF1E293B),
                        items: (selectedItem.availableColors.isEmpty ? ['N/A'] : selectedItem.availableColors).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => line.color = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: line.quantity.toString(),
                        decoration: const InputDecoration(labelText: 'Qtd.', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => setState(() => line.quantity = int.tryParse(v) ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: line.costPrice.toString(),
                        decoration: const InputDecoration(labelText: 'Custo Un.', border: OutlineInputBorder(), prefixText: '€'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => setState(() => line.costPrice = double.tryParse(v) ?? 0.0),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    double total = 0;
    for (var l in _lines) {
      total += (l.quantity * l.costPrice);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AiTranslatedText('Investimento Total Estimado:', style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text(
            '€ ${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: CustomButton(
        label: 'Confirmar Entrada Global', 
        onPressed: _submit,
        height: 56,
      ),
    );
  }

  void _showPoPicker(BuildContext context, ProcurementService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StreamBuilder<List<PurchaseOrder>>(
          stream: service.getPurchaseOrders(widget.institution.id),
          builder: (context, snap) {
            final orders = (snap.data ?? []).where((o) => o.status == 'ordered').toList();
            
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: AiTranslatedText('Selecionar Encomenda Pendente', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: orders.isEmpty 
                    ? const Center(child: AiTranslatedText('Nenhuma encomenda pendente encontrada.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          return ListTile(
                            leading: const CircleAvatar(backgroundColor: Color(0xFFFF9F1C), child: Icon(Icons.assignment, color: Colors.white)),
                            title: Text(o.supplierName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('ID: #${o.id.substring(0, 8).toUpperCase()} - ${o.items.length} artigos', style: const TextStyle(color: Colors.white54)),
                            onTap: () {
                              _loadFromPo(o);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EntryLine {
  String? itemId;
  String? size;
  String? color;
  int quantity;
  double costPrice;

  _EntryLine({
    this.itemId,
    this.size,
    this.color,
    this.quantity = 1,
    this.costPrice = 0,
  });
}
