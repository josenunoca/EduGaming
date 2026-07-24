import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Update Tab length from 3 to 4
  content = content.replaceAll("length: 3,", "length: 4,");
  
  // 2. Add Tab header
  content = content.replaceAll(
    "Tab(icon: const Icon(Icons.photo_library), child: AiTranslatedText('Multimédia')),",
    "Tab(icon: const Icon(Icons.photo_library), child: AiTranslatedText('Multimédia')),\n              Tab(icon: const Icon(Icons.build_circle), child: AiTranslatedText('Manutenções')),"
  );
  
  // 3. Add TabView content (temporarily a placeholder, we will build a dedicated widget below)
  content = content.replaceAll(
    "_buildMediaTab(context, service),",
    "_buildMediaTab(context, service),\n              _buildMaintenancesTab(context, service),"
  );
  
  // 4. Add the `_buildMaintenancesTab` and helper methods at the end of the class
  final methods = '''
  Widget _buildMaintenancesTab(BuildContext context, FirebaseService service) {
    if (_currentInfra.maintenances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const AiTranslatedText('Nenhuma manutenção registada.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddMaintenanceSheet(context, service),
              icon: const Icon(Icons.add),
              label: const AiTranslatedText('Adicionar Manutenção'),
            )
          ],
        ),
      );
    }
    
    // Sort maintenances by start date descending
    final sortedMaintenances = List<InfrastructureMaintenance>.from(_currentInfra.maintenances)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final totalCost = sortedMaintenances.fold<double>(0, (sum, m) => sum + m.cost);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AiTranslatedText('Histórico de Manutenções', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                onPressed: () => _showAddMaintenanceSheet(context, service),
                icon: const Icon(Icons.add),
                label: const AiTranslatedText('Adicionar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const AiTranslatedText('Custo Acumulado', style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 8),
                        Text('€\${totalCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const AiTranslatedText('Total de Intervenções', style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 8),
                        Text('\${sortedMaintenances.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedMaintenances.length,
            itemBuilder: (context, index) {
              final m = sortedMaintenances[index];
              return GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.build, color: Colors.amber),
                  title: Text(m.description, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('\${_formatDate(m.startDate)} - \${_formatDate(m.endDate)}\\nCusto: €\${m.cost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m.documentUrl != null)
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.blueAccent),
                          onPressed: () {
                             // Assuming DownloadHelper exists or will show a snackbar
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: AiTranslatedText('Download não implementado neste ecrã. Pode ser acedido via Web.')));
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteMaintenance(context, service, m),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _deleteMaintenance(BuildContext context, FirebaseService service, InfrastructureMaintenance m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Confirmar Eliminação', style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText('Tem a certeza que deseja remover este registo de manutenção?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const AiTranslatedText('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      await service.removeInfrastructureMaintenance(_currentInfra.id, m);
      setState(() {
        _currentInfra = _currentInfra.copyWith(
          maintenances: _currentInfra.maintenances.where((x) => x.id != m.id).toList(),
        );
      });
    }
  }

  void _showAddMaintenanceSheet(BuildContext context, FirebaseService service) {
    final descCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    PlatformFile? selectedFile;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AiTranslatedText('Nova Manutenção', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Descrição da Intervenção', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (d != null) setSheetState(() => start = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data Início', labelStyle: TextStyle(color: Colors.white54)),
                            child: Text(_formatDate(start), style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (d != null) setSheetState(() => end = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Data Conclusão', labelStyle: TextStyle(color: Colors.white54)),
                            child: Text(_formatDate(end), style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: costCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Custo Financeiro (€)', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'png']);
                            if (result != null) {
                              setSheetState(() => selectedFile = result.files.first);
                            }
                          },
                          icon: const Icon(Icons.attach_file),
                          label: Text(selectedFile?.name ?? 'Anexar Fatura/Relatório'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF), padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () async {
                        if (descCtrl.text.trim().isEmpty || costCtrl.text.trim().isEmpty) return;
                        
                        String? docUrl;
                        if (selectedFile != null && selectedFile!.bytes != null) {
                          docUrl = await service.uploadContentFile(selectedFile!.bytes!, selectedFile!.name);
                        }

                        final cost = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        
                        final m = InfrastructureMaintenance(
                          id: const Uuid().v4(),
                          description: descCtrl.text.trim(),
                          startDate: start,
                          endDate: end,
                          cost: cost,
                          documentName: selectedFile?.name,
                          documentUrl: docUrl,
                        );

                        await service.addInfrastructureMaintenance(_currentInfra.id, m);
                        setState(() {
                          _currentInfra = _currentInfra.copyWith(
                            maintenances: [..._currentInfra.maintenances, m],
                          );
                        });

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const AiTranslatedText('Guardar Manutenção'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
''';

  content = content.replaceFirst("  // Helpers", methods + "\n  // Helpers");
  
  file.writeAsStringSync(content);
}
