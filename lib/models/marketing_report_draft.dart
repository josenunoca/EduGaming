import 'marketing_event_model.dart';

class MarketingReportDraft {
  String introduction;
  String conclusion;
  List<MarketingReportSection> sections;

  MarketingReportDraft({
    this.introduction = '',
    this.conclusion = '',
    this.sections = const [],
  });

  Map<String, dynamic> toJson() => {
    'introduction': introduction,
    'conclusion': conclusion,
    'sections': sections.map((s) => s.toJson()).toList(),
  };

  factory MarketingReportDraft.fromRawData(List<MarketingEvent> events) {
    // Basic grouping by type as initial structure
    Map<String, List<MarketingEvent>> grouped = {};
    for (var a in events) {
      final type = a.marketingGroup;
      grouped.putIfAbsent(type, () => []).add(a);
    }

    return MarketingReportDraft(
      introduction: 'Aguardando síntese da IA...',
      conclusion: 'Aguardando síntese da IA...',
      sections: grouped.entries.map((e) => MarketingReportSection(
        title: e.key,
        summary: 'Resumo das ${e.value.length} eventos de ${e.key}.',
        events: e.value,
      )).toList(),
    );
  }
}

class MarketingReportSection {
  String title;
  String summary;
  List<MarketingEvent> events;

  MarketingReportSection({
    required this.title,
    required this.summary,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'eventIds': events.map((a) => a.id).toList(),
  };
}

