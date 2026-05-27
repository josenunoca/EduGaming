import 'activity_model.dart';

class Infrastructure {
  final String id;
  final String institutionId;
  final String name;
  final String address;
  final String contact;
  final String description;
  final double? marketValue;
  final DateTime? marketValueDate;
  final bool isMarketValueNotApplicable;
  final bool includeInReport;
  final List<ActivityMedia> media;

  Infrastructure({
    required this.id,
    required this.institutionId,
    required this.name,
    this.address = '',
    this.contact = '',
    this.description = '',
    this.marketValue,
    this.marketValueDate,
    this.isMarketValueNotApplicable = false,
    this.includeInReport = false,
    this.media = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'institutionId': institutionId,
      'name': name,
      'address': address,
      'contact': contact,
      'description': description,
      'marketValue': marketValue,
      'marketValueDate': marketValueDate?.toIso8601String(),
      'isMarketValueNotApplicable': isMarketValueNotApplicable,
      'includeInReport': includeInReport,
      'media': media.map((x) => x.toMap()).toList(),
    };
  }

  factory Infrastructure.fromMap(Map<String, dynamic> map) {
    return Infrastructure(
      id: map['id'] ?? '',
      institutionId: map['institutionId'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      contact: map['contact'] ?? '',
      description: map['description'] ?? '',
      marketValue: map['marketValue']?.toDouble(),
      marketValueDate: map['marketValueDate'] != null
          ? DateTime.parse(map['marketValueDate'])
          : null,
      isMarketValueNotApplicable: map['isMarketValueNotApplicable'] ?? false,
      includeInReport: map['includeInReport'] ?? false,
      media: map['media'] != null
          ? List<ActivityMedia>.from(
              map['media']?.map((x) => ActivityMedia.fromMap(x)))
          : [],
    );
  }

  Infrastructure copyWith({
    String? id,
    String? institutionId,
    String? name,
    String? address,
    String? contact,
    String? description,
    double? marketValue,
    DateTime? marketValueDate,
    bool? isMarketValueNotApplicable,
    bool? includeInReport,
    List<ActivityMedia>? media,
  }) {
    return Infrastructure(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      name: name ?? this.name,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      description: description ?? this.description,
      marketValue: isMarketValueNotApplicable == true ? null : (marketValue ?? this.marketValue),
      marketValueDate: marketValueDate ?? this.marketValueDate,
      isMarketValueNotApplicable:
          isMarketValueNotApplicable ?? this.isMarketValueNotApplicable,
      includeInReport: includeInReport ?? this.includeInReport,
      media: media ?? this.media,
    );
  }
}
