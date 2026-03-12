import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'logic/language_provider.dart';
import 'services/ai_translation_service.dart';
import 'services/ai_chat_service.dart';

import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBCZTup0m_BF0eZhSRTpWQkMmlJvPAqLJA",
      authDomain: "pagina-relato-financeiro.firebaseapp.com",
      databaseURL:
          "https://pagina-relato-financeiro-default-rtdb.europe-west1.firebasedatabase.app",
      projectId: "pagina-relato-financeiro",
      storageBucket: "pagina-relato-financeiro.firebasestorage.app",
      messagingSenderId: "442675059778",
      appId: "1:442675059778:web:22a6cab9539cc0d9c321db",
    ),
  );

  // Chave dedicada ao Gemini AI (EduGaming Platform - AI Studio)
  const geminiApiKey = "AIzaSyDkk9Bo7YXbfBFaJDBE89AE0ZbVLhiiu7E";

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ProxyProvider<LanguageProvider, AiTranslationService>(
          update: (_, language, __) => AiTranslationService(geminiApiKey),
        ),
        Provider<AiChatService>(
          create: (_) => AiChatService(geminiApiKey),
        ),
      ],
      child: const EduGamingApp(),
    ),
  );
}

class EduGamingApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  const EduGamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'EduGaming Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF7B61FF),
          secondary: const Color(0xFF00D1FF),
          surface: const Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7B61FF)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
