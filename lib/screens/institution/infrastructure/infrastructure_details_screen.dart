import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../../models/infrastructure_model.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/activity_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';

class InfrastructureDetailsScreen extends StatefulWidget {
  final InstitutionModel institution;
  final Infrastructure infrastructure;

  const InfrastructureDetailsScreen({
    super.key,
    required this.institution,
    required this.infrastructure,
  });

  @override
  State<InfrastructureDetailsScreen> createState() =>
      _InfrastructureDetailsScreenState();
}

class _InfrastructureDetailsScreenState
    extends State<InfrastructureDetailsScreen> {
  late Infrastructure _currentInfra;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _currentInfra = widget.infrastructure;
  }

  void _refreshInfra() async {
    final service = context.read<FirebaseService>();
    final updated = await service.getInfrastructureById(_currentInfra.id);
    if (updated != null && mounted) {
      setState(() => _currentInfra = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentInfra.name),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: const Icon(Icons.info), child: AiTranslatedText('Detalhes')),
              Tab(icon: const Icon(Icons.attach_money), child: AiTranslatedText('Avaliação Financeira')),
              Tab(icon: const Icon(Icons.photo_library), child: AiTranslatedText('Multimédia')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDetailsTab(),
            _buildFinancialsTab(),
            _buildMultimediaTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AiTranslatedText('Informações da Infraestrutura',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: _showEditDetailsDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.domain, 'Nome', _currentInfra.name),
                  _buildDetailRow(Icons.location_on, 'Morada',
                      _currentInfra.address.isEmpty ? 'Não especificada' : _currentInfra.address),
                  _buildDetailRow(Icons.phone, 'Contacto',
                      _currentInfra.contact.isEmpty ? 'Não especificado' : _currentInfra.contact),
                  const Divider(),
                  AiTranslatedText('Breve Descrição / Resenha Histórica',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_currentInfra.description.isEmpty
                      ? 'Sem descrição'
                      : _currentInfra.description),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: CheckboxListTile(
              title: AiTranslatedText('Incluir no Relatório Global'),
              subtitle: AiTranslatedText(
                  'Marque para exportar esta infraestrutura nos relatórios.'),
              value: _currentInfra.includeInReport,
              onChanged: (val) async {
                final updated = _currentInfra.copyWith(includeInReport: val);
                await context.read<FirebaseService>().saveInfrastructure(updated);
                _refreshInfra();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDetailsDialog() {
    final nameCtrl = TextEditingController(text: _currentInfra.name);
    final addressCtrl = TextEditingController(text: _currentInfra.address);
    final contactCtrl = TextEditingController(text: _currentInfra.contact);
    final descCtrl = TextEditingController(text: _currentInfra.description);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AiTranslatedText('Editar Detalhes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Morada'),
              ),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contacto'),
              ),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Resenha Histórica'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = _currentInfra.copyWith(
                name: nameCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                contact: contactCtrl.text.trim(),
                description: descCtrl.text.trim(),
              );
              await context.read<FirebaseService>().saveInfrastructure(updated);
              _refreshInfra();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText('Valor de Mercado da Infraestrutura',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: AiTranslatedText('Não Aplicável'),
                    subtitle: AiTranslatedText(
                        'Marque se esta infraestrutura não possuir valor de mercado.'),
                    value: _currentInfra.isMarketValueNotApplicable,
                    onChanged: (val) async {
                      final updated = _currentInfra.copyWith(
                          isMarketValueNotApplicable: val);
                      await context
                          .read<FirebaseService>()
                          .saveInfrastructure(updated);
                      _refreshInfra();
                    },
                  ),
                  if (!_currentInfra.isMarketValueNotApplicable) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AiTranslatedText('Valor Atual Registado:',
                                style: TextStyle(color: Colors.grey)),
                            Text(
                              _currentInfra.marketValue != null
                                  ? '€${_currentInfra.marketValue!.toStringAsFixed(2)}'
                                  : 'Sem valor definido',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            if (_currentInfra.marketValueDate != null)
                              Text(
                                  'Atualizado a: ${_dateFormat.format(_currentInfra.marketValueDate!)}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showEditValueDialog,
                          icon: const Icon(Icons.edit),
                          label: AiTranslatedText('Atualizar Valor'),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditValueDialog() {
    final valCtrl = TextEditingController(
        text: _currentInfra.marketValue?.toString() ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AiTranslatedText('Atualizar Valor de Mercado'),
        content: TextField(
          controller: valCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Valor em Euros (€)',
            hintText: 'Ex: 150000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(valCtrl.text.trim());
              if (val != null) {
                final updated = _currentInfra.copyWith(
                  marketValue: val,
                  marketValueDate: DateTime.now(),
                  isMarketValueNotApplicable: false,
                );
                await context
                    .read<FirebaseService>()
                    .saveInfrastructure(updated);
                _refreshInfra();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: AiTranslatedText('Atualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMultimediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AiTranslatedText('Galeria e Anexos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: AiTranslatedText('Carregar'),
                onPressed: _uploadMedia,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentInfra.media.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: AiTranslatedText('Nenhum ficheiro carregado.'),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _currentInfra.media.length,
              itemBuilder: (context, index) =>
                  _buildMediaItem(_currentInfra.media[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(ActivityMedia item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.type == 'image')
            Image.network(item.url, fit: BoxFit.cover)
          else
            const Icon(Icons.insert_drive_file, size: 50, color: Colors.grey),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    item.isAnnualReportSelected ? Icons.star : Icons.star_border,
                    color: item.isAnnualReportSelected ? Colors.amber : Colors.white,
                  ),
                  onPressed: () async {
                    // Remove old item, add updated item
                    final service = context.read<FirebaseService>();
                    await service.removeInfrastructureMedia(_currentInfra.id, item);
                    final updatedItem = ActivityMedia(
                      id: item.id,
                      name: item.name,
                      url: item.url,
                      type: item.type,
                      visibility: item.visibility,
                      uploadedAt: item.uploadedAt,
                      isSocialMediaSelected: item.isSocialMediaSelected,
                      isAnnualReportSelected: !item.isAnnualReportSelected,
                    );
                    await service.updateInfrastructureMedia(
                        _currentInfra.id, updatedItem);
                    _refreshInfra();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await context
                        .read<FirebaseService>()
                        .removeInfrastructureMedia(_currentInfra.id, item);
                    _refreshInfra();
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(4),
              child: Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      final service = context.read<FirebaseService>();
      for (var file in result.files) {
        if (file.bytes != null) {
          final type = file.name.toLowerCase().endsWith('.pdf') ? 'document' : 'image';
          final url = await service.uploadContentFile(file.bytes!, file.name); // Reusing upload bucket path logic
          if (url != null) {
            final item = ActivityMedia(
              id: const Uuid().v4(),
              name: file.name,
              url: url,
              type: type,
              visibility: ActivityVisibility.wholeInstitution,
              uploadedAt: DateTime.now(),
            );
            await service.updateInfrastructureMedia(_currentInfra.id, item);
          }
        }
      }
      _refreshInfra();
    }
  }
}
