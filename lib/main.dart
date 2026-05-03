import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'services/firebase_service.dart';
import 'logic/language_provider.dart';
import 'services/ai_translation_service.dart';
import 'services/ai_chat_service.dart';
import 'services/lifestyle_ai_service.dart';
import 'services/finance_service.dart';
import 'services/procurement_service.dart';
import 'logic/theme_provider.dart';
import 'services/institutional_service.dart';
import 'services/notification_service.dart';
import 'services/institutional_knowledge_service.dart';
import 'services/delegation_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: AppConfig.firebaseApiKey,
      authDomain: AppConfig.firebaseAuthDomain,
      databaseURL: AppConfig.firebaseDatabaseURL,
      projectId: AppConfig.firebaseProjectId,
      storageBucket: AppConfig.firebaseStorageBucket,
      messagingSenderId: AppConfig.firebaseMessagingSenderId,
      appId: AppConfig.firebaseAppId,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ProxyProvider<LanguageProvider, AiTranslationService>(
          update: (_, language, __) => AiTranslationService(AppConfig.geminiApiKey),
        ),
        Provider<AiChatService>(create: (_) => AiChatService(apiKey: AppConfig.geminiApiKey)),
        Provider<LifestyleAiService>(create: (_) => LifestyleAiService(AppConfig.geminiApiKey)),
        Provider<InstitutionalService>(create: (_) => InstitutionalService()),
        ProxyProvider<FirebaseService, FinanceService>(
          update: (_, firebase, __) => FinanceService(firebase),
        ),
        Provider<NotificationService>(create: (_) => NotificationService()),
        ProxyProvider2<FirebaseService, NotificationService, ProcurementService>(
          update: (_, firebase, notifications, __) => ProcurementService(firebase, notifications),
        ),
        Provider<InstitutionalKnowledgeService>(create: (_) => InstitutionalKnowledgeService()),
        ProxyProvider<FirebaseService, DelegationService>(
          update: (_, firebase, __) => DelegationService(firebase),
        ),
      ],
      child: const EduGamingApp(),
    ),
  );
}

class EduGamingApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const EduGamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'EduGaming Platform',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const LoginScreen(),
    );
  }
}
