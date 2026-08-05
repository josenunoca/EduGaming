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
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/app_config.dart';
import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Global FlutterError: ${details.exception}');
    };

    final localesToInit = [
      'pt_PT', 'pt-PT',
      'pt_BR', 'pt-BR',
      'pt',
      'en_US', 'en-US',
      'en_GB', 'en-GB',
      'en',
      'es_ES', 'es-ES',
      'es',
      'fr_FR', 'fr-FR',
      'fr',
      'de_DE', 'de-DE',
      'de',
    ];
    for (final loc in localesToInit) {
      try {
        await initializeDateFormatting(loc, null);
      } catch (_) {
        // Ignore unsupported or failing locales silently
      }
    }
    Intl.defaultLocale = 'pt_PT';

    try {
      if (Firebase.apps.isEmpty) {
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
      }
    } catch (e) {
      debugPrint('Firebase initialization error on startup: $e');
    }

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
  }, (error, stack) {
    debugPrint('Uncaught async error in runZonedGuarded: $error\n$stack');
  });
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
