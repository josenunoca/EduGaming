import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import '../../../widgets/ai_translated_text.dart';

class HRAttendanceScanner extends StatefulWidget {
  final Function(String code) onScan;

  const HRAttendanceScanner({super.key, required this.onScan});

  @override
  State<HRAttendanceScanner> createState() => _HRAttendanceScannerState();
}

class _HRAttendanceScannerState extends State<HRAttendanceScanner> {
  bool _scanned = false;
  final _manualCodeController = TextEditingController();

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImageQr() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final code = 'DYNAMIC_QR_${file.name}_${DateTime.now().millisecondsSinceEpoch}';
      if (!_scanned) {
        _scanned = true;
        widget.onScan(code);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Código do QR Code Dinâmico',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: _manualCodeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ex: ATTENDANCE_2026_ENTRY',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D1FF),
                foregroundColor: Colors.black),
            onPressed: () {
              final val = _manualCodeController.text.trim();
              if (val.isNotEmpty && !_scanned) {
                _scanned = true;
                Navigator.pop(context); // close alert
                Navigator.pop(this.context); // close scanner
                widget.onScan(val);
              }
            },
            child: const AiTranslatedText('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const AiTranslatedText('Leitor de QR Code Dinâmico'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Color(0xFF00D1FF)),
            tooltip: 'Carregar Foto do QR Code',
            onPressed: _pickImageQr,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard, color: Colors.white70),
            tooltip: 'Introduzir Código Manual',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _scanned = true;
                  widget.onScan(barcode.rawValue!);
                  Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00D1FF), width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D1FF).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const AiTranslatedText(
                  'Aponte para o QR Code Dinâmico de Entrada/Saída',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImageQr,
                      icon: const Icon(Icons.image, size: 18, color: Color(0xFF00D1FF)),
                      label: const AiTranslatedText('Foto do QR',
                          style: TextStyle(color: Color(0xFF00D1FF), fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00D1FF)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                      label: const AiTranslatedText('Código Manual',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
