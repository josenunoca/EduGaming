import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';
import '../procurement_item_form_screen.dart';
import '../procurement_regularization_screen.dart';
import '../../../../models/user_model.dart';

class InventoryTab extends StatefulWidget {
  final InstitutionModel institution;

  const InventoryTab({super.key, required this.institution});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  String _searchQuery = '';
  String? _filterFamilyId;
  String? _filterSubfamilyId;
  String _filterReference = '';

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return Column(
      children: [
        _buildStockValuationSummary(context, service),
        _buildSearchBar(context, service),
        Expanded(
          child: StreamBuilder<List<ProcurementItem>>(
            stream: service.getItems(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final allItems = snapshot.data!;
              final filteredItems = allItems.where((item) {
                final matchesName = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchesRef = _filterReference.isEmpty || item.reference.toLowerCase().contains(_filterReference.toLowerCase());
                final matchesFamily = _filterFamilyId == null || item.familyId == _filterFamilyId;
                final matchesSubfamily = _filterSubfamilyId == null || item.subfamilyId == _filterSubfamilyId;
                
                return matchesName && matchesRef && matchesFamily && matchesSubfamily;
              }).toList();

              if (filteredItems.isEmpty) {
                return const Center(child: AiTranslatedText('Nenhum artigo encontrado', style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) => _buildItemCard(context, service, filteredItems[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStockValuationSummary(BuildContext context, ProcurementService service) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: service.getInventorySummaryStream(widget.institution.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro ao carregar resumo: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
          );
        }
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data!;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: GlassCard(
            color: const Color(0xFF00FF85).withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics, color: Color(0xFF00FF85), size: 20),
                      SizedBox(width: 12),
                      AiTranslatedText('Resumo de Inventário (Total)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildValuationItem('Quantidade', '${(data['totalQty'] as double).toInt()}', Icons.inventory_2),
                      _buildValuationItem('Valor Custo', '€ ${(data['totalCost'] as double).toStringAsFixed(2)}', Icons.euro_symbol),
                      _buildValuationItem('Valor Venda', '€ ${(data['totalSale'] as double).toStringAsFixed(2)}', Icons.sell),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildValuationItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white24),
        const SizedBox(height: 4),
        AiTranslatedText(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, ProcurementService service) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Procurar por nome...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _showAdvancedFilter(context, service),
            icon: Icon(Icons.filter_list, color: (_filterFamilyId != null || _filterSubfamilyId != null || _filterReference.isNotEmpty) ? const Color(0xFFFF9F1C) : Colors.white54),
            tooltip: 'Filtro Avançado',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            onSelected: (value) {
              if (value == 'report_total') service.generateStockReportPdf(institutionId: widget.institution.id, institutionName: widget.institution.name, showTotalWithWarehouses: true);
              if (value == 'report_warehouse') _showWarehouseReportPicker(context, service);
              if (value == 'closing') _showClosingDialog(context, service);
              if (value == 'new_regularization') _createNewRegularization(context);
              if (value == 'list_regularizations') _showRegularizationsList(context, service);
              if (value == 'regularizations') _showRegularizationHistory(context, service);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'report_total', child: Row(children: [Icon(Icons.print, size: 18), SizedBox(width: 8), AiTranslatedText('Relatório Total (c/ Detalhe)')])),
              const PopupMenuItem(value: 'report_warehouse', child: Row(children: [Icon(Icons.warehouse, size: 18), SizedBox(width: 8), AiTranslatedText('Relatório por Armazém')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'closing', child: Row(children: [Icon(Icons.lock, size: 18, color: Colors.orangeAccent), SizedBox(width: 8), AiTranslatedText('Fechar Inventário')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'new_regularization', child: Row(children: [Icon(Icons.add_moderator, size: 18, color: Color(0xFF00FF85)), SizedBox(width: 8), AiTranslatedText('Nova Regularização')])),
              const PopupMenuItem(value: 'list_regularizations', child: Row(children: [Icon(Icons.assignment_outlined, size: 18), SizedBox(width: 8), AiTranslatedText('Listar Regularizações')])),
              const PopupMenuItem(value: 'regularizations', child: Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), AiTranslatedText('Audit Log (Ajustes)')])),
            ],
          ),
        ],
      ),
    );
  }

  void _showWarehouseReportPicker(BuildContext context, ProcurementService service) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<Warehouse>>(
        stream: service.getWarehouses(widget.institution.id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final warehouses = snap.data!;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const AiTranslatedText('Escolher Armazém', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: warehouses.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(warehouses[i].name, style: const TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    service.generateStockReportPdf(
                      institutionId: widget.institution.id,
                      institutionName: widget.institution.name,
                      warehouseId: warehouses[i].id,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showClosingDialog(BuildContext context, ProcurementService service) {
    final counterController = TextEditingController();
    final approverController = TextEditingController();
    DateTime closingDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Fechar Inventário', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Esta ação irá congelar o inventário na data selecionada. Movimentos anteriores não serão permitidos.', 
                style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 16),
              ListTile(
                title: const AiTranslatedText('Data de Fecho', style: TextStyle(color: Colors.white70)),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(closingDate), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.calendar_today, color: Colors.white24),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: closingDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => closingDate = picked);
                },
              ),
              TextField(
                controller: counterController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Responsável Contagem', labelStyle: TextStyle(color: Colors.white54)),
              ),
              TextField(
                controller: approverController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Responsável Aprovação', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (counterController.text.isEmpty || approverController.text.isEmpty) return;
                try {
                  await service.closeInventory(
                    institutionId: widget.institution.id,
                    closingDate: closingDate,
                    counterName: counterController.text,
                    approverName: approverController.text,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Inventário fechado com sucesso!')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const AiTranslatedText('Confirmar Fecho'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegularizationHistory(BuildContext context, ProcurementService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const AiTranslatedText('Histórico de Regularizações', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<InventoryAuditLog>>(
                stream: service.getAuditLogs(widget.institution.id, action: InventoryAction.adjustment),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final logs = snap.data!;
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      return ListTile(
                        leading: Icon(log.quantityChanged > 0 ? Icons.add_circle : Icons.remove_circle, 
                          color: log.quantityChanged > 0 ? Colors.greenAccent : Colors.redAccent),
                        title: Text(log.itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${log.notes}\n${DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp)}', 
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        trailing: Text('${log.quantityChanged.toInt()}', 
                          style: TextStyle(color: log.quantityChanged > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
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

  void _showAdvancedFilter(BuildContext context, ProcurementService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiTranslatedText('Filtro Avançado', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                onChanged: (v) => _filterReference = v,
                controller: TextEditingController(text: _filterReference)..selection = TextSelection.collapsed(offset: _filterReference.length),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Referência / SKU', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<ProcurementFamily>>(
                stream: service.getFamilies(widget.institution.id),
                builder: (context, snap) {
                  final families = snap.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _filterFamilyId,
                    decoration: const InputDecoration(labelText: 'Família', border: OutlineInputBorder()),
                    dropdownColor: const Color(0xFF1E293B),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas as Famílias')),
                      ...families.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))),
                    ],
                    onChanged: (v) {
                      setModalState(() {
                        _filterFamilyId = v;
                        _filterSubfamilyId = null;
                      });
                      setState(() {});
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_filterFamilyId != null)
                StreamBuilder<List<ProcurementSubfamily>>(
                  stream: service.getSubfamilies(widget.institution.id, _filterFamilyId!),
                  builder: (context, snap) {
                    final subs = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _filterSubfamilyId,
                      decoration: const InputDecoration(labelText: 'Subfamília', border: OutlineInputBorder()),
                      dropdownColor: const Color(0xFF1E293B),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas as Subfamílias')),
                        ...subs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (v) {
                        setModalState(() => _filterSubfamilyId = v);
                        setState(() {});
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterFamilyId = null;
                          _filterSubfamilyId = null;
                          _filterReference = '';
                        });
                        Navigator.pop(context);
                      },
                      child: const AiTranslatedText('Limpar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C)),
                      child: const AiTranslatedText('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, ProcurementService service, ProcurementItem item) {
    final firebaseService = context.read<FirebaseService>();
    final user = firebaseService.currentUserModel!;
    final canEdit = service.canManageStockGlobally(user, widget.institution);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.imageUrl != null 
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.inventory_2, color: Colors.white24),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  if (item.isDiscontinued)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                      child: const AiTranslatedText('DESCONTINUADO', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Text(item.reference.isNotEmpty ? 'Ref: ${item.reference}' : item.composition, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              trailing: canEdit ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.blueAccent),
                    tooltip: 'Duplicar',
                    onPressed: () => _navigateForm(context, item, isDuplicate: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.white38),
                    onPressed: () => _navigateForm(context, item),
                  ),
                ],
              ) : null,
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AiTranslatedText('Resumo de Stock:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      TextButton.icon(
                        onPressed: () => _showWarehouseDetails(context, service, item),
                        icon: const Icon(Icons.warehouse_outlined, size: 16),
                        label: const AiTranslatedText('Ver por Armazém', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.availableSizes.map((size) => _buildSizeStockBadge(service, item.id, size)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateForm(BuildContext context, ProcurementItem item, {bool isDuplicate = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcurementItemFormScreen(
          institutionId: widget.institution.id,
          item: item,
          isDuplicate: isDuplicate,
        ),
      ),
    );
  }

  Widget _buildSizeStockBadge(ProcurementService service, String itemId, String size) {
    return StreamBuilder<double>(
      stream: service.getStockLevel(widget.institution.id, itemId, size: size),
      builder: (context, snapshot) {
        final stock = snapshot.data ?? 0.0;
        final color = stock > 5 ? Colors.greenAccent : (stock > 0 ? Colors.orangeAccent : Colors.redAccent);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(size, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(width: 6),
              Text(stock.toInt().toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  void _showWarehouseDetails(BuildContext context, ProcurementService service, ProcurementItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            AiTranslatedText('Stock Detalhado: ${item.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<ProcurementStock>>(
                stream: service.getStockStream(widget.institution.id, itemId: item.id),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final stocks = snap.data!;
                  
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: stocks.length,
                    itemBuilder: (context, index) {
                      final s = stocks[index];
                      final costValuation = s.quantity * item.costPrice;
                      final saleValuation = s.quantity * item.price;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warehouse_outlined, color: Colors.white24),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      StreamBuilder<List<Warehouse>>(
                                        stream: service.getWarehouses(widget.institution.id),
                                        builder: (context, wSnap) {
                                          final w = wSnap.data?.firstWhere((wh) => wh.id == s.warehouseId, orElse: () => Warehouse(id: '', institutionId: '', name: 'Armazém Desconhecido'));
                                          return Text(w?.name ?? '...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                                        },
                                      ),
                                      Text('Tamanho: ${s.size} | Cor: ${s.color}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(s.quantity.toInt().toString(), style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.settings_backup_restore, color: Colors.orangeAccent, size: 20),
                                  tooltip: 'Regularizar Stock',
                                  onPressed: () => _showAdjustmentDialog(context, service, item, s),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AiTranslatedText('Valor Custo', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                    Text('€ ${costValuation.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const AiTranslatedText('Valor Venda', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                    Text('€ ${saleValuation.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
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

  void _showAdjustmentDialog(BuildContext context, ProcurementService service, ProcurementItem item, ProcurementStock stock) {
    final firebaseService = context.read<FirebaseService>();
    final user = firebaseService.currentUserModel!;
    final qtyController = TextEditingController();
    final notesController = TextEditingController();
    String reason = 'Quebra';
    final reasons = ['Quebra', 'Roubo', 'Oferta', 'Sobra', 'Consumo Interno', 'Outros'];
    bool isAddition = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: AiTranslatedText('Regularizar Stock: ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${stock.size} / ${stock.color}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const AiTranslatedText('Saída (-)'),
                        selected: !isAddition,
                        onSelected: (val) => setState(() => isAddition = !val),
                        selectedColor: Colors.redAccent.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const AiTranslatedText('Entrada (+)'),
                        selected: isAddition,
                        onSelected: (val) => setState(() => isAddition = val),
                        selectedColor: Colors.greenAccent.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const AiTranslatedText('Motivo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: reasons.map((r) => ChoiceChip(
                    label: AiTranslatedText(r, style: const TextStyle(fontSize: 10)),
                    selected: reason == r,
                    onSelected: (val) { if (val) setState(() => reason = r); },
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    selectedColor: Colors.orangeAccent.withValues(alpha: 0.2),
                    labelStyle: TextStyle(color: reason == r ? Colors.orangeAccent : Colors.white60),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                FutureBuilder<double>(
                  future: service.getFIFOCostPrice(
                    institutionId: widget.institution.id,
                    itemId: item.id,
                    size: stock.size,
                    color: stock.color,
                    warehouseId: stock.warehouseId,
                  ),
                  builder: (context, costSnap) {
                    final cost = costSnap.data ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AiTranslatedText('Custo FIFO Sugerido:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text('€ ${cost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Observações (Opcional)', border: OutlineInputBorder()),
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                // Use absolute value to avoid issues with user entering negative numbers for "Saída"
                final qty = (double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0).abs();
                if (qty == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AiTranslatedText('Por favor, insira uma quantidade válida.')),
                  );
                  return;
                }
                
                try {
                  await service.adjustStock(
                    institutionId: widget.institution.id,
                    itemId: item.id,
                    itemName: item.name,
                    size: stock.size,
                    color: stock.color,
                    warehouseId: stock.warehouseId,
                    quantityDelta: isAddition ? qty : -qty,
                    reason: reason,
                    notes: notesController.text,
                    userId: user.id,
                    userName: user.name,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AiTranslatedText('Stock regularizado com sucesso.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9F1C),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const AiTranslatedText('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewRegularization(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProcurementRegularizationScreen(institution: widget.institution),
      ),
    );
  }

  void _showRegularizationsList(BuildContext context, ProcurementService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const AiTranslatedText('Regularizações de Inventário', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<InventoryRegularization>>(
                stream: service.getRegularizations(widget.institution.id),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Erro: ${snap.error}', style: const TextStyle(color: Colors.redAccent)));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final regs = snap.data!;
                  if (regs.isEmpty) return const Center(child: AiTranslatedText('Nenhuma regularização encontrada', style: TextStyle(color: Colors.white24)));
                  
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: regs.length,
                    itemBuilder: (context, i) {
                      final reg = regs[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('dd/MM/yyyy').format(reg.date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    Text(reg.reason, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: reg.status == 'finalized' ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.orangeAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    reg.status.toUpperCase(),
                                    style: TextStyle(color: reg.status == 'finalized' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (reg.status == 'draft') IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProcurementRegularizationScreen(institution: widget.institution, regularization: reg)));
                                  },
                                ),
                                if (reg.status == 'finalized') IconButton(
                                  icon: const Icon(Icons.print, color: Colors.white54, size: 20),
                                  onPressed: () => service.generateRegularizationPdf(widget.institution.name, reg),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _confirmDeleteRegularization(context, service, reg),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  void _confirmDeleteRegularization(BuildContext context, ProcurementService service, InventoryRegularization reg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar Regularização?', style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText('Esta ação não pode ser desfeita.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(
            onPressed: () async {
              await service.deleteRegularization(widget.institution.id, reg.id);
              Navigator.pop(context);
            },
            child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
