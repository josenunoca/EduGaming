enum UserRole {
  admin,
  institution,
  teacher,
  student,
  parent,
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? institutionId;
  final List<String>? educationLevels; // For institutions
  final String? nif;
  final String? phone;
  final String? address;
  final String? postalCode;
  final DateTime? birthDate; // For students
  final String? parentId; // For minor students
  final bool adConsent;
  final bool dataConsent;
  final bool isPaymentVerified;
  final bool hasManualAccess;
  final bool isSuspended;
  final String? signatureUrl;
  final List<String> interests;
  final int aiCredits; // Credits for AI operations (games, chat)
  final int? aiCreditLimit; // Weekly/Monthly limit set by institution
  final int totalCreditsConsumed; // Total historical consumption
  final String? preferredLanguage; // Support for localization strategy

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.institutionId,
    this.educationLevels,
    this.nif,
    this.phone,
    this.address,
    this.postalCode,
    this.birthDate,
    this.parentId,
    required this.adConsent,
    required this.dataConsent,
    this.isPaymentVerified = false,
    this.hasManualAccess = false,
    this.isSuspended = false,
    this.signatureUrl,
    this.interests = const [],
    this.aiCredits = 10, // Default signup credits
    this.aiCreditLimit,
    this.totalCreditsConsumed = 0,
    this.preferredLanguage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'institutionId': institutionId,
      'educationLevels': educationLevels,
      'nif': nif,
      'phone': phone,
      'address': address,
      'postalCode': postalCode,
      'birthDate': birthDate?.toIso8601String(),
      'parentId': parentId,
      'adConsent': adConsent,
      'dataConsent': dataConsent,
      'isPaymentVerified': isPaymentVerified,
      'hasManualAccess': hasManualAccess,
      'isSuspended': isSuspended,
      if (signatureUrl != null) 'signatureUrl': signatureUrl,
      'interests': interests,
      'aiCredits': aiCredits,
      if (aiCreditLimit != null) 'aiCreditLimit': aiCreditLimit,
      'totalCreditsConsumed': totalCreditsConsumed,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      name: map['name'],
      role: UserRole.values
          .firstWhere((e) => e.toString().split('.').last == map['role']),
      institutionId: map['institutionId'],
      educationLevels: map['educationLevels'] != null
          ? List<String>.from(map['educationLevels'])
          : null,
      nif: map['nif'],
      phone: map['phone'],
      address: map['address'],
      postalCode: map['postalCode'],
      birthDate:
          map['birthDate'] != null ? DateTime.parse(map['birthDate']) : null,
      parentId: map['parentId'],
      adConsent: map['adConsent'] ?? false,
      dataConsent: map['dataConsent'] ?? false,
      isPaymentVerified: map['isPaymentVerified'] ?? false,
      hasManualAccess: map['hasManualAccess'] ?? false,
      isSuspended: map['isSuspended'] ?? false,
      signatureUrl: map['signatureUrl'],
      interests: List<String>.from(map['interests'] ?? []),
      aiCredits: map['aiCredits'] ?? 10,
      aiCreditLimit: map['aiCreditLimit'],
      totalCreditsConsumed: map['totalCreditsConsumed'] ?? 0,
      preferredLanguage: map['preferredLanguage'],
    );
  }
}
