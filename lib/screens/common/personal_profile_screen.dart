import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../models/institution_model.dart';
import 'package:image_picker/image_picker.dart';

class PersonalProfileScreen extends StatefulWidget {
  final UserModel user;
  const PersonalProfileScreen({super.key, required this.user});

  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  late List<String> _tempInterests;
  final TextEditingController _interestController = TextEditingController();

  final List<String> _suggestions = [
    'História', 'Literatura', 'Música', 'Desporto', 'IA', 'Sustentabilidade'
  ];
  
  final _nameController = TextEditingController();
  final _nifController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String? _signatureUrl;
  bool _isUploading = false;
  InstitutionModel? _institution;

  @override
  void initState() {
    super.initState();
    _tempInterests = List.from(widget.user.interests);
    _nameController.text = widget.user.name;
    _nifController.text = widget.user.nif ?? '';
    _addressController.text = widget.user.address ?? '';
    _postalCodeController.text = widget.user.postalCode ?? '';
    _signatureUrl = widget.user.signatureUrl;
    
    if (widget.user.role == UserRole.institution && widget.user.institutionId != null) {
      _loadInstitution();
    }
  }

  Future<void> _loadInstitution() async {
    final service = context.read<FirebaseService>();
    final inst = await service.getInstitution(widget.user.institutionId!);
    if (inst != null) {
      setState(() {
        _institution = inst;
        _nameController.text = inst.name;
        _nifController.text = inst.nif;
        _addressController.text = inst.address;
        _signatureUrl = inst.signatureUrl;
      });
    }
  }

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final bytes = await image.readAsBytes();
        final service = context.read<FirebaseService>();
        final url = await service.uploadSignature(widget.user.id, bytes);
        setState(() {
          _signatureUrl = url;
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar assinatura: $e')),
          );
        }
      }
    }
  }

  void _addInterest(String interest) {
    if (interest.isNotEmpty && !_tempInterests.contains(interest)) {
      setState(() {
        _tempInterests.add(interest);
        _interestController.clear();
      });
    }
  }

  Future<void> _save() async {
    final service = context.read<FirebaseService>();
    
    if (widget.user.role == UserRole.institution && _institution != null) {
      await service.updateInstitutionProfile(_institution!.id, {
        'name': _nameController.text,
        'nif': _nifController.text,
        'address': _addressController.text,
        'signatureUrl': _signatureUrl,
      });
    } else {
      await service.updateUserProfile(widget.user.id, {
        'name': _nameController.text,
        'nif': _nifController.text,
        'address': _addressController.text,
        'postalCode': _postalCodeController.text,
        'signatureUrl': _signatureUrl,
        'interests': _tempInterests,
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Área Pessoal')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Dados Pessoais / Fiscais',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Nome Completo / Social', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nifController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'NIF', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Morada', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _postalCodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Código Postal', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Assinatura Digital',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          if (_signatureUrl != null)
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white24),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: Image.network(_signatureUrl!, fit: BoxFit.contain),
                            )
                          else
                            const Text('Nenhuma assinatura carregada', style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 12),
                          if (_isUploading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton.icon(
                              onPressed: _pickSignature,
                              icon: const Icon(Icons.upload),
                              label: const Text('Carregar Assinatura'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Os Meus Interesses',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _interestController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Ex: Robótica, Piano...',
                              hintStyle: TextStyle(color: Colors.white24),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: _addInterest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () => _addInterest(_interestController.text),
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _suggestions.where((s) => !_tempInterests.contains(s)).map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        onPressed: () => _addInterest(s),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        labelStyle: const TextStyle(color: Colors.white70),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tempInterests.map((interest) => Chip(
                            label: Text(interest, style: const TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFF7B61FF).withOpacity(0.2),
                            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                            onDeleted: () => setState(() => _tempInterests.remove(interest)),
                          )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: const Color(0xFF7B61FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Guardar Alterações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
