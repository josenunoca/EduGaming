import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../widgets/glass_card.dart';
import 'registration_form.dart';
import 'admin/admin_dashboard.dart';
import 'coordinator/coordinator_dashboard.dart';
import 'teacher/teacher_dashboard.dart';
import 'student/student_dashboard.dart';
import 'institution/institution_dashboard.dart';
import 'parent/parent_dashboard.dart';
import '../logic/language_provider.dart';
import '../widgets/ai_translated_text.dart';
import 'other/other_dashboard.dart';
import 'specialist/health_specialist_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 800;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Dynamic Modern Background Gradient ─────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF070B19), // Deep rich midnight navy
                  Color(0xFF0F172A), // Slate navy
                  Color(0xFF1E1B4B), // Rich indigo accent
                ],
              ),
            ),
          ),

          // ─── Ambient Glow Blobs ──────────────────────────────────────────
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7B61FF).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D1FF).withValues(alpha: 0.15),
              ),
            ),
          ),

          // ─── Main Content ────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 480 : 420,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ─── Official Logo Display ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D1FF).withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/edugaming_official_logo.png',
                            height: isDesktop ? 180 : 150,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Web asset fallback
                              return Image.network(
                                'assets/assets/edugaming_official_logo.png',
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, st) => Column(
                                  children: [
                                    const Icon(Icons.school, size: 70, color: Color(0xFF00D1FF)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'EDUGAMING',
                                      style: GoogleFonts.outfit(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Language Selector Chip ──────────────────────────
                      _LanguageSelector(),
                      const SizedBox(height: 24),

                      // ─── Glassmorphism Login Card ───────────────────────
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bem-vindo de Volta',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Aceda à sua conta institucional',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Email Input Field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'E-mail',
                                labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00D1FF), size: 20),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF00D1FF), width: 1.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Password Input Field
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7B61FF), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.8),
                                ),
                              ),
                            ),
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text(
                                  'Esqueceu-se da palavra-passe?',
                                  style: TextStyle(
                                      color: Color(0xFF00D1FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Submit Button
                            _isLoading
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(color: Color(0xFF00D1FF)),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7B61FF), Color(0xFF00D1FF)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7B61FF).withValues(alpha: 0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _performLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        minimumSize: const Size(double.infinity, 52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Entrar na Plataforma',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                            const SizedBox(height: 24),

                            // Divider
                            const Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white12)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: Text('ou continuar com',
                                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                                ),
                                Expanded(child: Divider(color: Colors.white12)),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Social Login Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _SocialButton(
                                    icon: Icons.g_mobiledata,
                                    label: 'Google',
                                    onPressed: _loginWithGoogle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialButton(
                                    icon: Icons.facebook,
                                    label: 'Facebook',
                                    onPressed: _loginWithFacebook,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Registration Prompt Link
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistrationForm(
                                initialRole: UserRole.student,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Não tem uma conta? Registe-se agora',
                          style: TextStyle(
                            color: Color(0xFF00D1FF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'EduGaming © 2026 — Plataforma de Gestão Académica e Organizacional',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: Color(0xFF00D1FF)),
            SizedBox(width: 10),
            Text('Recuperar Palavra-passe',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insira o seu email de registo. Enviaremos um link seguro para redefinir a sua palavra-passe.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Endereço de E-mail',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00D1FF)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Enviar Link'),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, introduza um endereço de e-mail válido.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              try {
                final service = context.read<FirebaseService>();
                await service.sendPasswordResetEmail(email);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Email de redefinição enviado com sucesso para $email!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao enviar email: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performLogin() async {
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
        _passwordController.text,
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
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    final service = context.read<FirebaseService>();
    try {
      final creds = await service.signInWithGoogle();
      if (!mounted) return;
      if (creds != null) {
        final userProfile = await service.getUserModel(creds.user!.uid);
        final role = userProfile?.role ?? UserRole.other;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login com Google bem-sucedido!'),
              backgroundColor: Colors.green),
        );
        _navigateToDashboard(role);
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      final msg = errorStr.contains('operation-not-allowed')
          ? 'O login com Google precisa de ser ativado no Firebase Console > Authentication > Sign-in method.'
          : 'Erro ao iniciar sessão com Google: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFacebook() async {
    setState(() => _isLoading = true);
    final service = context.read<FirebaseService>();
    try {
      final creds = await service.signInWithFacebook();
      if (!mounted) return;
      if (creds != null) {
        final userProfile = await service.getUserModel(creds.user!.uid);
        final role = userProfile?.role ?? UserRole.other;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Login com Facebook bem-sucedido!'),
              backgroundColor: Colors.green),
        );
        _navigateToDashboard(role);
      }
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      final msg = errorStr.contains('operation-not-allowed')
          ? 'O login com Facebook precisa de ser ativado no Firebase Console > Authentication > Sign-in method.'
          : 'Erro ao iniciar sessão com Facebook: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      case UserRole.courseCoordinator:
        target = const CoordinatorDashboard();
        break;
      case UserRole.healthSpecialist:
        target = const HealthSpecialistDashboard();
        break;
      case UserRole.other:
        target = const OtherDashboard();
        break;
    }
    if (!mounted) return;
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: provider.currentLanguage,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.language, color: Color(0xFF00D1FF), size: 18),
          items: AppLanguage.values.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    lang.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
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

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
