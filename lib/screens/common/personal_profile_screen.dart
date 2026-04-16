import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../models/institution_model.dart';
import '../../models/credit_pricing_model.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../user/theme_settings_screen.dart';
import '../user/user_lifestyle_screen.dart';
import '../../services/cv_ai_service.dart';
import '../../models/curriculum_model.dart';
import '../../config/app_config.dart';

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
    'História',
    'Literatura',
    'Música',
    'Desporto',
    'IA',
    'Sustentabilidade'
  ];

  final _nameController = TextEditingController();
  final _nifController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String? _signatureUrl;
  bool _isUploading = false;
  bool _isProcessingCv = false;
  InstitutionModel? _institution;
  CurriculumModel? _curriculum;

  // Controllers for CV Manual Editing
  final _cvAcademicController = TextEditingController();
  final _cvAreaController = TextEditingController();
  final _cvProfController = TextEditingController();
  final _cvAwardsController = TextEditingController();
  final _cvExpController = TextEditingController();
  final _cvPubController = TextEditingController();
  final _cvOtherController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _tempInterests = List.from(widget.user.interests);
    _nameController.text = widget.user.name;
    _nifController.text = widget.user.nif ?? '';
    _phoneController.text = widget.user.phone ?? '';
    _addressController.text = widget.user.address ?? '';
    _postalCodeController.text = widget.user.postalCode ?? '';
    _signatureUrl = widget.user.signatureUrl;
    
    if (widget.user.curriculum != null) {
      _loadCurriculumToControllers(widget.user.curriculum!);
    }

    if (widget.user.role == UserRole.institution &&
        widget.user.institutionId != null) {
      _loadInstitution();
    }
  }

  void _loadCurriculumToControllers(CurriculumModel cv) {
    _curriculum = cv;
    _cvAcademicController.text = cv.academicQualifications ?? '';
    _cvAreaController.text = cv.courseArea ?? '';
    _cvProfController.text = cv.professionalQualifications ?? '';
    _cvAwardsController.text = cv.awards ?? '';
    _cvExpController.text = cv.experience ?? '';
    _cvPubController.text = cv.publications ?? '';
    _cvOtherController.text = cv.otherInterests ?? '';
  }

  void _updateCurriculumFromControllers() {
    _curriculum = CurriculumModel(
      cvFileUrl: _curriculum?.cvFileUrl,
      academicQualifications: _cvAcademicController.text.trim(),
      courseArea: _cvAreaController.text.trim(),
      professionalQualifications: _cvProfController.text.trim(),
      awards: _cvAwardsController.text.trim(),
      experience: _cvExpController.text.trim(),
      publications: _cvPubController.text.trim(),
      otherInterests: _cvOtherController.text.trim(),
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> _loadInstitution() async {
    final service = context.read<FirebaseService>();
    final inst = await service.getInstitution(widget.user.institutionId!);
    if (!mounted) return;
    if (inst != null) {
      setState(() {
        _institution = inst;
        _nameController.text = inst.name;
        _nifController.text = inst.nif;
        _phoneController.text = inst.phone;
        _addressController.text = inst.address;
        _signatureUrl = inst.signatureUrl;
      });
    }
  }

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final service = context.read<FirebaseService>();
      setState(() => _isUploading = true);
      try {
        final bytes = await image.readAsBytes();
        final url = await service.uploadSignature(widget.user.id, bytes);
        if (!mounted) return;
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

  Future<void> _uploadAndProcessCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _isProcessingCv = true);
      final pdfBytes = result.files.single.bytes!;
      
      try {
        final cvAiService = CvAiService(apiKey: AppConfig.geminiApiKey);
        final extractedCv = await cvAiService.parseCvPdf(pdfBytes);
        
        final service = context.read<FirebaseService>();
        final fileUrl = await service.uploadInstitutionLogo(widget.user.id + '_cv', pdfBytes); // Reuse upload method or create new one

        if (!mounted) return;
        setState(() {
          _loadCurriculumToControllers(extractedCv);
          _curriculum = CurriculumModel(
            cvFileUrl: fileUrl,
            academicQualifications: extractedCv.academicQualifications,
            courseArea: extractedCv.courseArea,
            professionalQualifications: extractedCv.professionalQualifications,
            awards: extractedCv.awards,
            experience: extractedCv.experience,
            publications: extractedCv.publications,
            otherInterests: extractedCv.otherInterests,
            lastUpdated: DateTime.now(),
          );
          _isProcessingCv = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV importado e processado com IA com sucesso! Reveja os dados abaixo.')),
        );
      } catch (e) {
        setState(() => _isProcessingCv = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao processar o CV: $e')),
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
        'phone': _phoneController.text,
        'address': _addressController.text,
        'signatureUrl': _signatureUrl,
      });
    } else {
      _updateCurriculumFromControllers();
      await service.updateUserProfile(widget.user.id, {
        'name': _nameController.text,
        'nif': _nifController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'postalCode': _postalCodeController.text,
        'signatureUrl': _signatureUrl,
        'interests': _tempInterests,
        if (_curriculum != null) 'curriculum': _curriculum!.toMap(),
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
    final service = context.read<FirebaseService>();
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
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Nome Completo / Social',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nifController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'NIF', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Telefone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Morada', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _postalCodeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: 'Código Postal',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Assinatura Digital',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              child: Image.network(
                                _signatureUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline,
                                              color: Colors.redAccent),
                                          SizedBox(height: 4),
                                          Text(
                                            'Erro ao carregar (CORS)',
                                            style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            const Text('Nenhuma assinatura carregada',
                                style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 12),
                          if (_isUploading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton.icon(
                              onPressed: _pickSignature,
                              icon: const Icon(Icons.upload),
                              label: const Text('Carregar Assinatura'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Os Meus Interesses',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
                          onPressed: () =>
                              _addInterest(_interestController.text),
                          icon: const Icon(Icons.add),
                          style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF7B61FF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: _suggestions
                          .where((s) => !_tempInterests.contains(s))
                          .map((s) => ActionChip(
                                label: Text(s,
                                    style: const TextStyle(fontSize: 11)),
                                onPressed: () => _addInterest(s),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.05),
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tempInterests
                          .map((interest) => Chip(
                                label: Text(interest,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: const Color(0xFF7B61FF)
                                    .withValues(alpha: 0.2),
                                deleteIcon: const Icon(Icons.close,
                                    size: 14, color: Colors.white70),
                                onDeleted: () => setState(
                                    () => _tempInterests.remove(interest)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 32),
                    const AiTranslatedText(
                      'Curriculum Vitae',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    if (_isProcessingCv)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Color(0xFF7B61FF)),
                              SizedBox(height: 16),
                              Text('A processar documento com Inteligência Artificial...',
                                style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ElevatedButton.icon(
                        onPressed: _uploadAndProcessCv,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const AiTranslatedText('Fazer Upload e Auto-preencher CV (PDF)'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D1FF),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 48)),
                      ),
                      const SizedBox(height: 16),
                      // CV Fields manually editable
                      TextField(
                        controller: _cvAcademicController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Habilitações Académicas', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvAreaController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Área do Curso', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvProfController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Habilitações Profissionais', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvAwardsController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Prémios e Reconhecimentos', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvExpController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Experiência Profissional', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvPubController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Publicações', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cvOtherController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                            labelText: 'Outros Assuntos de Interesse', border: OutlineInputBorder()),
                      ),
                    ],
                    const SizedBox(height: 32),
                    const AiTranslatedText(
                      'Créditos e Tabela de Preços',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<UserModel?>(
                        stream: service.getUserStream(widget.user.id),
                        builder: (context, snapshot) {
                          final user = snapshot.data ?? widget.user;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D1FF)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF00D1FF)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AiTranslatedText(
                                        'Créditos Disponíveis',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                    Text('${user.aiCredits}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // Placeholder for recharging credits
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: AiTranslatedText(
                                                'Funcionalidade de recarga em breve.')));
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00D1FF)),
                                  child: const AiTranslatedText(
                                      'Comprar Créditos'),
                                )
                              ],
                            ),
                          );
                        }),
                    const SizedBox(height: 24),
                    const AiTranslatedText(
                      'Preçário (Consumo por Ação)',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<CreditPricing>>(
                      stream: service.getCreditPricingStream(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final pricing = snapshot.data!;

                        return Theme(
                          data: Theme.of(context)
                              .copyWith(cardColor: Colors.transparent),
                          child: DataTable(
                            horizontalMargin: 0,
                            columnSpacing: 10,
                            columns: const [
                              DataColumn(
                                  label: AiTranslatedText('Ação',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12))),
                              DataColumn(
                                  label: AiTranslatedText('Custo (Créditos)',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12))),
                            ],
                            rows: pricing.map((p) {
                              final price = p.prices[widget.user.role] ?? 0;
                              return DataRow(cells: [
                                DataCell(AiTranslatedText(p.actionName,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12))),
                                DataCell(Text('$price',
                                    style: const TextStyle(
                                        color: Color(0xFF00D1FF),
                                        fontWeight: FontWeight.bold))),
                              ]);
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Preferências e Bem-estar',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading:
                          const Icon(Icons.palette, color: Colors.amberAccent),
                      title: const Text('Personalização Visual',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text(
                          'Escolha o seu padrão de cores favorito',
                          style: TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white24),
                      tileColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ThemeSettingsScreen())),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading:
                          const Icon(Icons.favorite, color: Colors.pinkAccent),
                      title: const Text('Meu Estilo de Vida',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Questionários e dicas de saúde',
                          style: TextStyle(color: Colors.white54)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white24),
                      tileColor: Colors.white.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UserLifestyleScreen())),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: const Color(0xFF7B61FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Guardar Alterações',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
