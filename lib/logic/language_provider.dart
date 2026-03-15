import 'package:flutter/material.dart';

enum AppLanguage {
  pt('Português', '🇵🇹'),
  en('English', '🇬🇧'),
  fr('Français', '🇫🇷'),
  es('Español', '🇪🇸'),
  de('Deutsch', '🇩🇪');

  final String name;
  final String flag;
  const AppLanguage(this.name, this.flag);

  String get code => name.toLowerCase().substring(0, 2);
}

class LanguageProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.pt;

  AppLanguage get currentLanguage => _currentLanguage;

  void setLanguage(AppLanguage language) {
    debugPrint('LanguageProvider: Setting language to ${language.name}');
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  String get languageCode {
    final code = _currentLanguage == AppLanguage.pt
        ? 'pt'
        : _currentLanguage == AppLanguage.en
            ? 'en'
            : _currentLanguage == AppLanguage.fr
                ? 'fr'
                : _currentLanguage == AppLanguage.es
                    ? 'es'
                    : 'de';
    debugPrint('LanguageProvider: current languageCode is $code');
    return code;
  }
}
