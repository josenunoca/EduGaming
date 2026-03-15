import 'package:flutter/material.dart';

class SignatureDialog extends StatefulWidget {
  final String docTitle;
  final String userName;

  const SignatureDialog({
    super.key,
    required this.docTitle,
    required this.userName,
  });

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  String _signatureType = 'electronic'; // electronic, citizen_card, biometric
  bool _isSigning = false;
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Row(
        children: [
          Icon(Icons.draw, color: Color(0xFF7B61FF)),
          SizedBox(width: 8),
          Text('Assinatura Digital', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documento: ${widget.docTitle}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Selecione o método de assinatura:',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            _buildSignOption(
              'electronic',
              'Assinatura Eletrónica Simples',
              'Validação rápida via conta EduGaming',
              Icons.fingerprint,
            ),
            _buildSignOption(
              'citizen_card',
              'Cartão de Cidadão',
              'Utilização de certificado digital (Chave Móvel Digital)',
              Icons.credit_card,
            ),
            _buildSignOption(
              'biometric',
              'Reconhecimento Biométrico',
              'Validação via FaceID ou Impressão Digital',
              Icons.face,
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Confirmo que li o documento e autorizo a aposição da minha assinatura digital nos termos da lei vigente.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              value: _agreedToTerms,
              activeColor: const Color(0xFF7B61FF),
              onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (_isSigning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Color(0xFF7B61FF)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_agreedToTerms && !_isSigning) ? _handleSign : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B61FF),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Assinar Documento'),
        ),
      ],
    );
  }

  Widget _buildSignOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _signatureType == value;
    return GestureDetector(
      onTap: () => setState(() => _signatureType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B61FF).withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF7B61FF) : Colors.white10,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF7B61FF) : Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF7B61FF), size: 20),
          ],
        ),
      ),
    );
  }

  void _handleSign() async {
    setState(() => _isSigning = true);
    
    // Simulate complex signing process
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.pop(context, _signatureType);
    }
  }
}
