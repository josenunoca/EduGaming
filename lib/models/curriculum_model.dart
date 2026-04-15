class CurriculumModel {
  final String? cvFileUrl;
  final String? academicQualifications;
  final String? courseArea;
  final String? professionalQualifications;
  final String? awards;
  final String? experience;
  final String? publications;
  final String? otherInterests;
  final DateTime? lastUpdated;

  CurriculumModel({
    this.cvFileUrl,
    this.academicQualifications,
    this.courseArea,
    this.professionalQualifications,
    this.awards,
    this.experience,
    this.publications,
    this.otherInterests,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      if (cvFileUrl != null) 'cvFileUrl': cvFileUrl,
      if (academicQualifications != null) 'academicQualifications': academicQualifications,
      if (courseArea != null) 'courseArea': courseArea,
      if (professionalQualifications != null) 'professionalQualifications': professionalQualifications,
      if (awards != null) 'awards': awards,
      if (experience != null) 'experience': experience,
      if (publications != null) 'publications': publications,
      if (otherInterests != null) 'otherInterests': otherInterests,
      if (lastUpdated != null) 'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory CurriculumModel.fromMap(Map<String, dynamic> map) {
    return CurriculumModel(
      cvFileUrl: map['cvFileUrl'],
      academicQualifications: map['academicQualifications'],
      courseArea: map['courseArea'],
      professionalQualifications: map['professionalQualifications'],
      awards: map['awards'],
      experience: map['experience'],
      publications: map['publications'],
      otherInterests: map['otherInterests'],
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : null,
    );
  }
}
