import 'activity_model.dart';

class AnnualReportDraft {
  String introduction;
  String conclusion;
  List<ReportSection> sections;

  AnnualReportDraft({
    this.introduction = '',
    this.conclusion = '',
    this.sections = const [],
  });

  Map<String, dynamic> toJson() => {
    'introduction': introduction,
    'conclusion': conclusion,
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  factory AnnualReportDraft.fromRawData(List<InstitutionalActivity> activities) {
    // Basic grouping by type as initial structure
    Map<String, List<InstitutionalActivity>> grouped = {};
    for (var a in activities) {
      final type = a.activityGroup;
      grouped.putIfAbsent(type, () => []).add(a);
    }

    return AnnualReportDraft(
      introduction: 'Aguardando síntese da IA...',
      conclusion: 'Aguardando síntese da IA...',
      sections: grouped.entries.map((e) => ReportSection(
        title: e.key,
        summary: 'Resumo das ${e.value.length} atividades de ${e.key}.',
        activities: e.value,
      )).toList(),
    );
  }
}

class ReportSection {
  String title;
  String summary;
  List<InstitutionalActivity> activities;

  ReportSection({
    required this.title,
    required this.summary,
    required this.activities,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'activityIds': activities.map((a) => a.id).toList(),
  };
}
