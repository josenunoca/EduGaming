import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../widgets/glass_card.dart';
import 'registration_form.dart';
import 'admin/admin_dashboard.dart';
import 'teacher/teacher_dashboard.dart';
import 'student/student_dashboard.dart';
import 'institution/institution_dashboard.dart';
import 'parent/parent_dashboard.dart';
import '../logic/language_provider.dart';
import '../widgets/ai_translated_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AiTranslatedText(
                    'EduGaming Platform',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AiTranslatedText(
                    'A vanguarda da educação',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LanguageSelector(),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      label: const AiTranslatedText('Email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      label: const AiTranslatedText('Senha'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isLoading 
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Por favor, preencha o email e a senha.')),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          final service = context.read<FirebaseService>();
                          try {
                            final creds = await service.signInWithEmail(
                              _emailController.text.trim(), 
                              _passwordController.text
                            );
                            
                            if (creds != null) {
                              final userProfile = await service.getUserModel(creds.user!.uid);
                              
                              if (userProfile == null) {
                                if (_emailController.text.trim() == 'josenunoca@gmail.com') {
                                  final adminUser = UserModel(
                                    id: creds.user!.uid,
                                    email: _emailController.text.trim(),
                                    name: 'Administrador Principal',
                                    role: UserRole.admin,
                                    adConsent: true,
                                    dataConsent: true,
                                  );
                                  await service.saveUser(adminUser);
                                  _navigateToDashboard(adminUser.role);
                                } else {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Perfil não encontrado. Por favor, registe-se.')),
                                  );
                                }
                              } else {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Login efetuado com sucesso!')),
                                );
                                _navigateToDashboard(userProfile.role);
                              }
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Credenciais inválidas ou serviço desativado no Firebase.')),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erro inesperado: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF7B61FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const AiTranslatedText('Entrar', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: AiTranslatedText('ou entrar com', style: TextStyle(color: Colors.white54)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: Icons.g_mobiledata,
                        label: 'Google',
                        onPressed: () async {
                          final service = context.read<FirebaseService>();
                          final creds = await service.signInWithGoogle();
                          if (creds != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Login com Google bem-sucedido!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Configuração de Google Sign-In pendente.')),
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        onPressed: () async {
                          final service = context.read<FirebaseService>();
                          final creds = await service.signInWithFacebook();
                          if (creds != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Login com Facebook bem-sucedido!')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Configuração de Facebook Auth pendente.')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegistrationForm(initialRole: UserRole.student)),
                      );
                    },
                    child: const AiTranslatedText('Não tem uma conta? Registe-se', style: TextStyle(color: Color(0xFF00D1FF))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDashboard(UserRole role) {
    Widget target;
    switch (role) {
      case UserRole.admin:
        target = const AdminDashboard();
        break;
      case UserRole.teacher:
        target = const TeacherDashboard();
        break;
      case UserRole.student:
        target = const StudentDashboard();
        break;
      case UserRole.institution:
        target = const InstitutionDashboard();
        break;
      case UserRole.parent:
        target = const ParentDashboard();
        break;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => target),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LanguageProvider>();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: provider.currentLanguage,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.language, color: Color(0xFF7B61FF), size: 18),
          items: AppLanguage.values.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(lang.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) provider.setLanguage(lang);
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: AiTranslatedText(label, style: const TextStyle(color: Colors.white)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
