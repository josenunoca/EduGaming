enum CouncilRequestStatus { pending, approved, rejected, inAgenda }

class CouncilRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterRole; // 'teacher' or 'student'
  final String institutionId;
  final String organId; // ID of the InstitutionalOrgan
  final String title;
  final String description;
  final String? fileUrl;
  final String? fileName;
  final CouncilRequestStatus status;
  final String? meetingId;
  final DateTime createdAt;

  CouncilRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.institutionId,
    required this.organId,
    required this.title,
    required this.description,
    this.fileUrl,
    this.fileName,
    this.status = CouncilRequestStatus.pending,
    this.meetingId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterRole': requesterRole,
      'institutionId': institutionId,
      'organId': organId,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'status': status.name,
      'meetingId': meetingId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CouncilRequest.fromMap(Map<String, dynamic> map) {
    return CouncilRequest(
      id: map['id'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? '',
      requesterRole: map['requesterRole'] ?? '',
      institutionId: map['institutionId'] ?? '',
      organId: map['organId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      fileUrl: map['fileUrl'],
      fileName: map['fileName'],
      status: CouncilRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => CouncilRequestStatus.pending,
      ),
      meetingId: map['meetingId'],
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
