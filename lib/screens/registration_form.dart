import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../widgets/ai_translated_text.dart';

class RegistrationForm extends StatefulWidget {
  final UserRole initialRole;

  const RegistrationForm({super.key, required this.initialRole});

  @override
  State<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nifController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _adConsent = false;
  bool _dataConsent = false;
  late UserRole _selectedRole;
  String? _selectedInstitutionId;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Registo de Utilizador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crie a sua conta',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(labelText: 'Tipo de Conta'),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.toString().split('.').last.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedRole = v!;
                  _selectedInstitutionId = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_selectedRole == UserRole.teacher) ...[
                StreamBuilder<List<InstitutionModel>>(
                  stream: service.getInstitutions(),
                  builder: (context, snapshot) {
                    final institutions = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedInstitutionId,
                      decoration: const InputDecoration(
                          labelText: 'Selecione a sua Instituição'),
                      items: institutions.map((inst) {
                        return DropdownMenuItem(
                            value: inst.id, child: Text(inst.name));
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedInstitutionId = v),
                      validator: (v) =>
                          (v == null) ? 'Selecione uma instituição' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome Completo'),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nifController,
                decoration: const InputDecoration(labelText: 'NIF'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Email inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              if (_selectedRole == UserRole.other) ...[
                const AiTranslatedText(
                  'Este perfil é destinado a membros externos de conselhos e órgãos sociais.',
                  style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
              ],
              if (_selectedRole == UserRole.institution) ...[
                const Text('Níveis de Ensino:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const _LevelCheckbox('Creche'),
                const _LevelCheckbox('Pré-Escolar'),
                const _LevelCheckbox('1.º Ciclo'),
                const _LevelCheckbox('Ensino Superior'),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text(
                    'Autorizo a utilização dos meus dados para fins educativos e melhoria da experiência.'),
                value: _dataConsent,
                onChanged: (v) => setState(() => _dataConsent = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text(
                    'Autorizo a receção de publicidade e novidades da plataforma.'),
                value: _adConsent,
                onChanged: (v) => setState(() => _adConsent = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_dataConsent)
                    ? () async {
                        if (_formKey.currentState!.validate()) {
                          final creds = await service.signUpWithEmail(
                              _emailController.text, _passwordController.text);

                          if (creds != null) {
                            final newUser = UserModel(
                              id: creds.user!.uid,
                              email: _emailController.text,
                              name: _nameController.text,
                              role: _selectedRole,
                              institutionId: _selectedInstitutionId,
                              nif: _nifController.text,
                              adConsent: _adConsent,
                              dataConsent: _dataConsent,
                            );
                            await service.saveUser(newUser);

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Conta criada com sucesso!')),
                            );
                            if (!mounted) return;
    Navigator.pop(context);
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Erro ao criar conta. Tente outro email.')),
                            );
                          }
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF7B61FF),
                ),
                child: const Text('Confirmar Inscrição',
                    style: TextStyle(color: Colors.white)),
              ),
              if (!_dataConsent)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    '* Deve autorizar a utilização dos dados para prosseguir.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCheckbox extends StatefulWidget {
  final String label;
  const _LevelCheckbox(this.label);

  @override
  State<_LevelCheckbox> createState() => _LevelCheckboxState();
}

class _LevelCheckboxState extends State<_LevelCheckbox> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(widget.label),
      value: _checked,
      onChanged: (v) => setState(() => _checked = v!),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}
