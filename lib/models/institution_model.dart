class InstitutionModel {
  final String id;
  final String name;
  final String nif;
  final String address;
  final String email;
  final String phone;
  final List<String> educationLevels;
  final List<String>
      authorizedProfessorIds; // UIDs of professors approved for this institution

  // Payment Information
  final String? mbwayPhone;
  final String? paymentEntity;
  final String? paymentReference;
  final String? signatureUrl;

  // Monetization & SaaS
  final String subscriptionPlan; // 'base', 'pro', 'enterprise'
  final int aiCredits;
  final int totalCreditsRecharged;
  final Map<String, dynamic>?
      whiteLabelSettings; // logoUrl, customColors, domain

  final bool isVerified;
  final bool isSuspended;
  final DateTime createdAt;

  InstitutionModel({
    required this.id,
    required this.name,
    required this.nif,
    required this.address,
    required this.email,
    required this.phone,
    required this.educationLevels,
    this.authorizedProfessorIds = const [],
    this.mbwayPhone,
    this.paymentEntity,
    this.paymentReference,
    this.isVerified = false,
    this.isSuspended = false,
    this.signatureUrl,
    this.subscriptionPlan = 'base',
    this.aiCredits = 0,
    this.totalCreditsRecharged = 0,
    this.whiteLabelSettings,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nif': nif,
      'address': address,
      'email': email,
      'phone': phone,
      'educationLevels': educationLevels,
      'authorizedProfessorIds': authorizedProfessorIds,
      'mbwayPhone': mbwayPhone,
      'paymentEntity': paymentEntity,
      'paymentReference': paymentReference,
      'isVerified': isVerified,
      'isSuspended': isSuspended,
      if (signatureUrl != null) 'signatureUrl': signatureUrl,
      'subscriptionPlan': subscriptionPlan,
      'aiCredits': aiCredits,
      'totalCreditsRecharged': totalCreditsRecharged,
      if (whiteLabelSettings != null) 'whiteLabelSettings': whiteLabelSettings,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InstitutionModel.fromMap(Map<String, dynamic> map) {
    return InstitutionModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nif: map['nif'] ?? '',
      address: map['address'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      educationLevels: List<String>.from(map['educationLevels'] ?? []),
      authorizedProfessorIds:
          List<String>.from(map['authorizedProfessorIds'] ?? []),
      mbwayPhone: map['mbwayPhone'],
      paymentEntity: map['paymentEntity'],
      paymentReference: map['paymentReference'],
      isVerified: map['isVerified'] ?? false,
      isSuspended: map['isSuspended'] ?? false,
      signatureUrl: map['signatureUrl'],
      subscriptionPlan: map['subscriptionPlan'] ?? 'base',
      aiCredits: map['aiCredits'] ?? 0,
      totalCreditsRecharged: map['totalCreditsRecharged'] ?? 0,
      whiteLabelSettings: map['whiteLabelSettings'] != null
          ? Map<String, dynamic>.from(map['whiteLabelSettings'])
          : null,
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
