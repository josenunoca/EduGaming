import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import '../models/subject_model.dart';
import '../services/firebase_service.dart';

class ContentUploader extends StatefulWidget {
  final Function(SubjectContent) onUploadComplete;

  const ContentUploader({super.key, required this.onUploadComplete});

  @override
  State<ContentUploader> createState() => _ContentUploaderState();
}

class _ContentUploaderState extends State<ContentUploader> {
  bool _isLoading = false;
  bool _isDragging = false;

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'png',
          'mp4',
          'mp3',
          'pdf',
          'xlsx',
          'csv',
          'pptx'
        ],
      );

      if (result != null) {
        if (!mounted) return;
        PlatformFile file = result.files.first;
        _showCategoryDialog(file);
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final XFile xFile = details.files.first;

      // Basic extension check
      final name = xFile.name;
      final ext = name.split('.').last.toLowerCase();
      final allowed = [
        'jpg',
        'png',
        'mp4',
        'mp3',
        'pdf',
        'xlsx',
        'csv',
        'pptx'
      ];

      if (!allowed.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tipo de ficheiro não suportado: $ext')),
          );
        }
        return;
      }

      final fileBytes = await xFile.readAsBytes();
      final platformFile = PlatformFile(
        name: xFile.name,
        size: fileBytes.length,
        bytes: fileBytes,
        path: xFile.path,
      );

      _showCategoryDialog(platformFile);
    } catch (e) {
      debugPrint('Drop error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCategoryDialog(PlatformFile file) {
    String selectedCategory = 'support';
    final weightController = TextEditingController(text: '0.0');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Configurar Conteúdo',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ficheiro: ${file.name}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration:
                    const InputDecoration(labelText: 'Tipo de Conteúdo'),
                items: const [
                  DropdownMenuItem(
                      value: 'support', child: Text('Material de Apoio')),
                  DropdownMenuItem(value: 'exam', child: Text('Exame / Prova')),
                  DropdownMenuItem(value: 'game', child: Text('Jogo')),
                ],
                onChanged: (v) => setStateDialog(() => selectedCategory = v!),
              ),
              if (selectedCategory != 'support') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Peso / Ponderação',
                    hintText: 'Ex: 1.5',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (file.bytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Erro: Ficheiro inválido (sem conteúdo)')),
                        );
                        return;
                      }

                      setStateDialog(() => _isLoading = true);

                      try {
                        final fs = Provider.of<FirebaseService>(context,
                            listen: false);
                        final downloadUrl =
                            await fs.uploadContentFile(file.bytes!, file.name);

                        if (downloadUrl == null) {
                          throw Exception('Falha ao obter URL');
                        }

                        String type = 'document';
                        final ext = file.extension?.toLowerCase() ?? '';
                        if (['jpg', 'png', 'jpeg'].contains(ext)) {
                          type = 'image';
                        } else if (['mp4', 'mov', 'avi'].contains(ext))
                          type = 'video';
                        else if (['mp3', 'wav', 'aac'].contains(ext))
                          type = 'audio';
                        else if (['xlsx', 'csv', 'xls'].contains(ext))
                          type = 'spreadsheet';
                        else if (['pptx', 'ppt'].contains(ext)) type = 'gamma';

                        final newContent = SubjectContent(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: file.name,
                          url: downloadUrl,
                          type: type,
                          category: selectedCategory,
                          weight: double.tryParse(weightController.text) ?? 0.0,
                        );
                        widget.onUploadComplete(newContent);

                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        debugPrint('Upload final error: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Erro no upload. Tente novamente.')),
                          );
                        }
                      } finally {
                        setStateDialog(() => _isLoading = false);
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: _handleDrop,
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: _isDragging
                ? const Color(0xFF7B61FF).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDragging
                  ? const Color(0xFF00D1FF)
                  : const Color(0xFF7B61FF).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                Icon(
                    _isDragging
                        ? Icons.file_download
                        : Icons.cloud_upload_outlined,
                    size: 48,
                    color: const Color(0xFF00D1FF)),
                const SizedBox(height: 16),
                Text(
                  _isDragging ? 'Largar ficheiro aqui' : 'Carregar Conteúdo',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Clique para selecionar ou arraste o ficheiro para aqui\n(Apoio, Exame ou Jogo)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
