import 'user_model.dart';

class CreditAction {
  static const String createGame = 'create_game';
  static const String createSubject = 'create_subject';
  static const String registerSyllabus = 'register_syllabus';
  static const String generateCertificate = 'generate_certificate';
  static const String createExam = 'create_exam';
}

class CreditPricing {
  final String id;
  final String action; // e.g., 'create_game'
  final Map<UserRole, int> prices; // Role -> Credit Cost

  CreditPricing({
    required this.id,
    required this.action,
    required this.prices,
  });

  String get actionName {
    switch (action) {
      case CreditAction.createGame:
        return 'Criar Jogo IA';
      case CreditAction.createSubject:
        return 'Criar Disciplina';
      case CreditAction.registerSyllabus:
        return 'Registar Sumário';
      case CreditAction.generateCertificate:
        return 'Gerar Certificado';
      case CreditAction.createExam:
        return 'Criar Exame IA';
      default:
        return action;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'prices': prices.map((k, v) => MapEntry(k.toString().split('.').last, v)),
    };
  }

  factory CreditPricing.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> pricesMap = map['prices'] ?? {};
    final Map<UserRole, int> rolePrices = {};

    for (var role in UserRole.values) {
      final roleKey = role.toString().split('.').last;
      if (pricesMap.containsKey(roleKey)) {
        rolePrices[role] = pricesMap[roleKey] as int;
      } else {
        rolePrices[role] = 0; // Default price
      }
    }

    return CreditPricing(
      id: map['id'] ?? '',
      action: map['action'] ?? '',
      prices: rolePrices,
    );
  }

  static List<CreditPricing> getDefaultPricing() {
    return [
      CreditPricing(
        id: 'create_game',
        action: CreditAction.createGame,
        prices: {
          UserRole.institution: 5,
          UserRole.teacher: 2,
          UserRole.student: 1,
        },
      ),
      CreditPricing(
        id: 'create_subject',
        action: CreditAction.createSubject,
        prices: {
          UserRole.institution: 50,
          UserRole.teacher: 20,
          UserRole.student: 10,
        },
      ),
      CreditPricing(
        id: 'register_syllabus',
        action: CreditAction.registerSyllabus,
        prices: {
          UserRole.institution: 2,
          UserRole.teacher: 1,
          UserRole.student: 0,
        },
      ),
      CreditPricing(
        id: 'generate_certificate',
        action: CreditAction.generateCertificate,
        prices: {
          UserRole.institution: 10,
          UserRole.teacher: 5,
          UserRole.student: 20,
        },
      ),
      CreditPricing(
        id: 'create_exam',
        action: CreditAction.createExam,
        prices: {
          UserRole.institution: 15,
          UserRole.teacher: 8,
          UserRole.student: 5,
        },
      ),
    ];
  }
}
