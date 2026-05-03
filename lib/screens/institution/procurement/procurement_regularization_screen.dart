import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../models/procurement/procurement_models.dart';
import '../../../services/procurement_service.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';

class ProcurementRegularizationScreen extends StatefulWidget {
  final InstitutionModel institution;
  final InventoryRegularization? regularization;

  const ProcurementRegularizationScreen({super.key, required this.institution, this.regularization});

  @override
  State<ProcurementRegularizationScreen> createState() => _ProcurementRegularizationScreenState();
}

class _ProcurementRegularizationScreenState extends State<ProcurementRegularizationScreen> {
  late DateTime _selectedDate;
  late String _selectedReason;
  String? _selectedWarehouseId;
  List<RegularizationItem> _items = [];
  bool _isLoading = false;

  final List<String> _reasons = ['Quebra', 'Roubo', 'Oferta', 'Sobra', 'Consumo Interno', 'Outros'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.regularization?.date ?? DateTime.now();
    _selectedReason = widget.regularization?.reason ?? 'Quebra';
    _selectedWarehouseId = widget.regularization?.warehouseId;
    _items = widget.regularization?.items != null ? List.from(widget.regularization!.items) : [];
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();
    final firebaseService = context.read<FirebaseService>();
    final user = firebaseService.currentUserModel!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AiTranslatedText(widget.regularization == null ? 'Nova Regularização' : 'Editar Regularização', style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          if (widget.regularization?.status != 'finalized')
            TextButton(
              onPressed: _isLoading ? null : () => _save(service, isDraft: true),
              child: const AiTranslatedText('Guardar Rascunho', style: TextStyle(color: Colors.blueAccent)),
            ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildItemsList(service),
                const SizedBox(height: 32),
                if (widget.regularization?.status != 'finalized')
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF85),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _items.isEmpty || _selectedWarehouseId == null ? null : () => _save(service, isDraft: false, user: user),
                      child: const AiTranslatedText('Finalizar e Imprimir', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
      floatingActionButton: widget.regularization?.status == 'finalized' ? null : FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: _selectedWarehouseId == null 
          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Selecione primeiro um armazém')))
          : () => _addItem(service),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Data', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                        child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Armazém', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Warehouse>>(
                      stream: context.read<ProcurementService>().getWarehouses(widget.institution.id),
                      builder: (context, snap) {
                        final warehouses = snap.data ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWarehouseId,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white),
                              isExpanded: true,
                              hint: const AiTranslatedText('Selecionar', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                              onChanged: widget.regularization?.status == 'finalized' ? null : (v) => setState(() => _selectedWarehouseId = v),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AiTranslatedText('Motivo da Regularização', style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) => ChoiceChip(
              label: AiTranslatedText(r, style: const TextStyle(fontSize: 10)),
              selected: _selectedReason == r,
              onSelected: widget.regularization?.status == 'finalized' ? null : (val) { if (val) setState(() => _selectedReason = r); },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedColor: Colors.orangeAccent.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: _selectedReason == r ? Colors.orangeAccent : Colors.white60),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ProcurementService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AiTranslatedText('Artigos a Regularizar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: AiTranslatedText('Nenhum artigo adicionado', style: TextStyle(color: Colors.white24)),
          ))
        else
          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('${item.size} / ${item.color}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (widget.regularization?.status != 'finalized')
                        IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 20), onPressed: () => setState(() => _items.removeAt(idx))),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEditableField(
                          label: 'Quantidade',
                          value: item.quantity.toInt().toString(),
                          onChanged: (v) {
                            final q = double.tryParse(v) ?? 0;
                            setState(() => _items[idx] = RegularizationItem(
                              itemId: item.itemId,
                              itemName: item.itemName,
                              itemReference: item.itemReference,
                              size: item.size,
                              color: item.color,
                              quantity: q,
                              unitCost: item.unitCost,
                            ));
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEditableField(
                          label: 'Custo FIFO',
                          value: item.unitCost.toStringAsFixed(2),
                          prefix: '€ ',
                          onChanged: (v) {
                            final c = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                            setState(() => _items[idx] = RegularizationItem(
                              itemId: item.itemId,
                              itemName: item.itemName,
                              itemReference: item.itemReference,
                              size: item.size,
                              color: item.color,
                              quantity: item.quantity,
                              unitCost: c,
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEditableField({required String label, required String value, String? prefix, required Function(String) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiTranslatedText(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: value)..selection = TextSelection.fromPosition(TextPosition(offset: value.length)),
          enabled: widget.regularization?.status != 'finalized',
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixText: prefix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
      ],
    );
  }

  void _addItem(ProcurementService service) async {
    // Show Article Picker
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _ArticlePicker(institutionId: widget.institution.id, warehouseId: _selectedWarehouseId!),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final cost = await service.getAverageCost(widget.institution.id, result['item'].id, result['variant'].size, result['variant'].color, _selectedWarehouseId!);
        setState(() {
          _items.add(RegularizationItem(
            itemId: result['item'].id,
            itemName: result['item'].name,
            itemReference: result['item'].reference,
            size: result['variant'].size,
            color: result['variant'].color,
            quantity: -1, // Default to removal
            unitCost: cost,
          ));
        });
      } catch (e) {
        debugPrint('Error getting cost: $e');
        // Add with default cost if query fails
        setState(() {
          _items.add(RegularizationItem(
            itemId: result['item'].id,
            itemName: result['item'].name,
            itemReference: result['item'].reference,
            size: result['variant'].size,
            color: result['variant'].color,
            quantity: -1,
            unitCost: result['item'].costPrice ?? 0.0,
          ));
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _save(ProcurementService service, {required bool isDraft, UserModel? user}) async {
    if (_selectedWarehouseId == null) return;
    
    setState(() => _isLoading = true);
    
    final reg = InventoryRegularization(
      id: widget.regularization?.id ?? const Uuid().v4(),
      institutionId: widget.institution.id,
      warehouseId: _selectedWarehouseId!,
      date: _selectedDate,
      reason: _selectedReason,
      items: _items,
      status: isDraft ? 'draft' : 'finalized',
      performedById: user?.id ?? widget.regularization?.performedById,
      performedByName: user?.name ?? widget.regularization?.performedByName,
      createdAt: widget.regularization?.createdAt ?? DateTime.now(),
    );

    try {
      if (isDraft) {
        await service.saveRegularization(reg);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Rascunho guardado')));
      } else {
        await service.finalizeRegularization(reg, user!);
        await service.generateRegularizationPdf(widget.institution.name, reg);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Regularização finalizada e PDF gerado')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _ArticlePicker extends StatefulWidget {
  final String institutionId;
  final String warehouseId;

  const _ArticlePicker({required this.institutionId, required this.warehouseId});

  @override
  State<_ArticlePicker> createState() => _ArticlePickerState();
}

class _ArticlePickerState extends State<_ArticlePicker> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Pesquisar artigo...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ProcurementItem>>(
              stream: service.getItems(widget.institutionId),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!.where((i) => i.name.toLowerCase().contains(_search) || (i.reference?.toLowerCase().contains(_search) ?? false)).toList();

                return ListView.builder(
                  controller: scrollController,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return ExpansionTile(
                      title: Text(item.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(item.reference ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      children: item.variants.map((v) => ListTile(
                        title: Text('${v.size} / ${v.color}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        onTap: () => Navigator.pop(context, {'item': item, 'variant': v}),
                      )).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
