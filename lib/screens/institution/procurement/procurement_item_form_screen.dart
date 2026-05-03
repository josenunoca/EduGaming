import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../models/user_model.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/custom_button.dart';

class ProcurementItemFormScreen extends StatefulWidget {
  final String institutionId;
  final ProcurementItem? item;
  final bool isDuplicate;

  const ProcurementItemFormScreen({super.key, required this.institutionId, this.item, this.isDuplicate = false});

  @override
  State<ProcurementItemFormScreen> createState() => _ProcurementItemFormScreenState();
}

class _ProcurementItemFormScreenState extends State<ProcurementItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _compController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _minStockController;
  late TextEditingController _refController;
  
  ProcurementCategory _category = ProcurementCategory.uniform;
  String? _familyId;
  String? _subfamilyId;
  final List<String> _sizes = [];
  final List<String> _colors = [];
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isDiscontinued = false;
  final Map<String, double> _variantSafetyStocks = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _descController = TextEditingController(text: widget.item?.description);
    _compController = TextEditingController(text: widget.item?.composition);
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '0.0');
    _costController = TextEditingController(text: widget.item?.costPrice.toString() ?? '0.0');
    _minStockController = TextEditingController(text: widget.item?.minSafetyStock.toString() ?? '5.0');
    _refController = TextEditingController(text: widget.item?.reference);
    if (widget.item != null) {
      _category = widget.item!.category;
      _familyId = widget.item!.familyId;
      _subfamilyId = widget.item!.subfamilyId;
      _colors.clear();
      _colors.addAll(widget.item!.availableColors);
      _sizes.clear();
      _sizes.addAll(widget.item!.availableSizes);
      _isDiscontinued = widget.item!.isDiscontinued;
      _variantSafetyStocks.addAll(widget.item?.variantSafetyStocks ?? {});
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final service = context.read<ProcurementService>();
      String? imageUrl = widget.item?.imageUrl;
      final itemId = (widget.item != null && !widget.isDuplicate) ? widget.item!.id : const Uuid().v4();

      if (_imageBytes != null) {
        imageUrl = await service.uploadItemImage(widget.institutionId, itemId, _imageBytes!);
      }
      
      final item = ProcurementItem(
        id: itemId,
        institutionId: widget.institutionId,
        name: _nameController.text,
        description: _descController.text,
        composition: _compController.text,
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        costPrice: double.parse(_costController.text.replaceAll(',', '.')),
        category: _category,
        familyId: _familyId,
        subfamilyId: _subfamilyId,
        availableColors: _colors,
        availableSizes: _sizes,
        minSafetyStock: double.tryParse(_minStockController.text.replaceAll(',', '.')) ?? 5.0,
        variantSafetyStocks: _variantSafetyStocks,
        imageUrl: imageUrl,
        reference: _refController.text,
        isDiscontinued: _isDiscontinued,
      );

      await service.saveItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('Artigo gravado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProcurementService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: AiTranslatedText(widget.item == null || widget.isDuplicate ? 'Novo Artigo' : 'Editar Artigo')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                          image: _imageBytes != null 
                              ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover) 
                              : (widget.item?.imageUrl != null ? DecorationImage(image: NetworkImage(widget.item!.imageUrl!), fit: BoxFit.cover) : null),
                        ),
                        child: (_imageBytes == null && widget.item?.imageUrl == null) ? const Icon(Icons.add_a_photo, color: Colors.white54, size: 40) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _refController,
                    decoration: const InputDecoration(labelText: 'Referência / SKU', border: OutlineInputBorder()),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome do Artigo', border: OutlineInputBorder()),
                    style: const TextStyle(color: Colors.white),
                    validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Descrição Comercial', border: OutlineInputBorder()),
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _compController,
                    decoration: const InputDecoration(labelText: 'Composição / Materiais', border: OutlineInputBorder()),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Preço Venda (€)', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null) ? 'Preço inválido' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(labelText: 'Custo Médio (€)', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null) ? 'Custo inválido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock de Segurança (Mínimo)',
                      helperText: 'Avisar quando o stock for igual ou inferior a este valor.',
                      helperStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder()
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.orangeAccent),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Valor inválido' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ProcurementCategory>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Categoria Base', border: OutlineInputBorder()),
                    dropdownColor: const Color(0xFF1E293B),
                    items: ProcurementCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<ProcurementFamily>>(
                    stream: service.getFamilies(widget.institutionId),
                    builder: (context, snap) {
                      final families = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: _familyId,
                        decoration: const InputDecoration(labelText: 'Família', border: OutlineInputBorder()),
                        dropdownColor: const Color(0xFF1E293B),
                        items: families.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                        onChanged: (v) => setState(() {
                          _familyId = v;
                          _subfamilyId = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_familyId != null)
                    StreamBuilder<List<ProcurementSubfamily>>(
                      stream: service.getSubfamilies(widget.institutionId, _familyId!),
                      builder: (context, snap) {
                        final subfamilies = snap.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: _subfamilyId,
                          decoration: const InputDecoration(labelText: 'Subfamília', border: OutlineInputBorder()),
                          dropdownColor: const Color(0xFF1E293B),
                          items: subfamilies.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (v) => setState(() => _subfamilyId = v),
                        );
                      },
                    ),
                   const Divider(color: Colors.white24),
                   const SizedBox(height: 8),
                   const Text('Controlo de Segurança por Variante', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                   const Text('Define níveis específicos para combinações de cor/tamanho (opcional).', style: TextStyle(color: Colors.white54, fontSize: 11)),
                   const SizedBox(height: 16),
                   if (_sizes.isEmpty || _colors.isEmpty)
                     const Text('Adicione tamanhos e cores primeiro para gerir stocks por variante.', style: TextStyle(color: Colors.white38, fontSize: 12))
                   else
                     ..._sizes.expand((size) => _colors.map((color) {
                       final key = "${size}_$color";
                       return Padding(
                         padding: const EdgeInsets.only(bottom: 8.0),
                         child: Row(
                           children: [
                             Expanded(flex: 2, child: Text("$size / $color", style: const TextStyle(color: Colors.white70, fontSize: 13))),
                             Expanded(
                               flex: 1,
                               child: TextFormField(
                                 initialValue: _variantSafetyStocks[key]?.toString(),
                                 decoration: const InputDecoration(suffixText: 'uni', isDense: true, border: OutlineInputBorder()),
                                 keyboardType: TextInputType.number,
                                 style: const TextStyle(color: Colors.white),
                                 onChanged: (val) {
                                   final d = double.tryParse(val);
                                   if (d != null) {
                                     _variantSafetyStocks[key] = d;
                                   } else {
                                     _variantSafetyStocks.remove(key);
                                   }
                                 },
                               ),
                             ),
                           ],
                         ),
                       );
                     })).toList(),
                   const SizedBox(height: 24),
                  const SizedBox(height: 24),
                  const AiTranslatedText('Cores Disponíveis', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._colors.map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => setState(() => _colors.remove(c)),
                      )),
                      ActionChip(
                        label: const Icon(Icons.add, size: 16),
                        onPressed: _showAddColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const AiTranslatedText('Tamanhos Disponíveis', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      ..._sizes.map((s) => Chip(
                        label: Text(s),
                        onDeleted: () => setState(() => _sizes.remove(s)),
                      )),
                      ActionChip(
                        label: const Icon(Icons.add, size: 16),
                        onPressed: _showAddSize,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const AiTranslatedText('Artigo Descontinuado', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const AiTranslatedText('Se descontinuado, não poderá haver mais entradas ou saídas.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    value: _isDiscontinued,
                    activeColor: Colors.redAccent,
                    onChanged: (v) => setState(() => _isDiscontinued = v),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(label: 'Guardar Artigo', onPressed: _save),
                  if (widget.item != null && !widget.isDuplicate) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const AiTranslatedText('Eliminar Artigo'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Eliminar Artigo'),
        content: const AiTranslatedText('Tem a certeza? Esta ação só é possível se não houver movimentos associados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final service = context.read<ProcurementService>();
        await service.deleteItem(widget.institutionId, widget.item!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Artigo eliminado com sucesso!')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showAddColor() {
    String color = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Adicionar Cor'),
        content: TextField(onChanged: (v) => color = v, decoration: const InputDecoration(hintText: 'ex: Azul Marinho')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () {
            if (color.isNotEmpty) setState(() => _colors.add(color));
            Navigator.pop(context);
          }, child: const AiTranslatedText('Adicionar')),
        ],
      ),
    );
  }

  void _showAddSize() {
     String size = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Adicionar Tamanho'),
        content: TextField(onChanged: (v) => size = v, decoration: const InputDecoration(hintText: 'ex: L, 38, 12 Anos')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () {
            if (size.isNotEmpty) setState(() => _sizes.add(size));
            Navigator.pop(context);
          }, child: const AiTranslatedText('Adicionar')),
        ],
      ),
    );
  }
}
