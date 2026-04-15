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
  final String? logoUrl;
  final Map<String, String>? socialMediaLinks;
  final Map<String, List<String>> delegatedRoles; // module key -> List of userIds

  final bool isVerified;
  final bool isSuspended;
  final DateTime createdAt;

  final String? scheduleStartTime; // e.g., "08:00"
  final String? scheduleEndTime; // e.g., "18:00"

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
    this.logoUrl,
    this.socialMediaLinks,
    this.delegatedRoles = const {},
    required this.createdAt,
    this.scheduleStartTime = '08:00',
    this.scheduleEndTime = '18:00',
  });

  InstitutionModel copyWith({
    String? id,
    String? name,
    String? nif,
    String? address,
    String? email,
    String? phone,
    List<String>? educationLevels,
    List<String>? authorizedProfessorIds,
    String? mbwayPhone,
    String? paymentEntity,
    String? paymentReference,
    String? signatureUrl,
    String? subscriptionPlan,
    int? aiCredits,
    int? totalCreditsRecharged,
    Map<String, dynamic>? whiteLabelSettings,
    String? logoUrl,
    Map<String, String>? socialMediaLinks,
    Map<String, List<String>>? delegatedRoles,
    bool? isVerified,
    bool? isSuspended,
    DateTime? createdAt,
    String? scheduleStartTime,
    String? scheduleEndTime,
  }) {
    return InstitutionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nif: nif ?? this.nif,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      educationLevels: educationLevels ?? this.educationLevels,
      authorizedProfessorIds: authorizedProfessorIds ?? this.authorizedProfessorIds,
      mbwayPhone: mbwayPhone ?? this.mbwayPhone,
      paymentEntity: paymentEntity ?? this.paymentEntity,
      paymentReference: paymentReference ?? this.paymentReference,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      aiCredits: aiCredits ?? this.aiCredits,
      totalCreditsRecharged: totalCreditsRecharged ?? this.totalCreditsRecharged,
      whiteLabelSettings: whiteLabelSettings ?? this.whiteLabelSettings,
      logoUrl: logoUrl ?? this.logoUrl,
      socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
      delegatedRoles: delegatedRoles ?? this.delegatedRoles,
      isVerified: isVerified ?? this.isVerified,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt ?? this.createdAt,
      scheduleStartTime: scheduleStartTime ?? this.scheduleStartTime,
      scheduleEndTime: scheduleEndTime ?? this.scheduleEndTime,
    );
  }

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
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (socialMediaLinks != null) 'socialMediaLinks': socialMediaLinks,
      'delegatedRoles': delegatedRoles,
      'createdAt': createdAt.toIso8601String(),
      'scheduleStartTime': scheduleStartTime,
      'scheduleEndTime': scheduleEndTime,
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
      logoUrl: map['logoUrl'],
      socialMediaLinks: map['socialMediaLinks'] != null
          ? Map<String, String>.from(map['socialMediaLinks'])
          : null,
      delegatedRoles: map['delegatedRoles'] != null 
          ? (map['delegatedRoles'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, List<String>.from(v as List)))
          : {},
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      scheduleStartTime: map['scheduleStartTime'] ?? '08:00',
      scheduleEndTime: map['scheduleEndTime'] ?? '18:00',
    );
  }
}
