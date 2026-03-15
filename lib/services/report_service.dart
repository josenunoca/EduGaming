import '../models/activity_model.dart';

class ReportService {
  static String generateAnnualReport(List<InstitutionalActivity> activities) {
    int totalParticipants = activities.fold(0, (sum, a) => sum + a.participants.length);
    int totalMedia = activities.fold(0, (sum, a) => sum + a.media.length);
    
    // Simple qualitative analysis
    String qualitative = "Durante o ano letivo, foram realizadas ${activities.length} atividades de relevo, "
        "envolvendo um total de $totalParticipants participantes. A dinâmica institucional foi enriquecida "
        "com a partilha de $totalMedia conteúdos multimédia.";

    // Simple statistics by status
    int completed = activities.where((a) => a.status == 'completed').length;
    int planned = activities.where((a) => a.status == 'planned').length;

    String report = """
# Relatório Anual de Atividades Institucionais
## Indicadores Quantitativos
- Total de Atividades: ${activities.length}
- Total de Participantes: $totalParticipants
- Atividades Concluídas: $completed
- Atividades Planeadas: $planned
- Recursos Utilizados: ${_countResources(activities)}

## Indicadores Qualitativos
$qualitative

## Indicadores Estatísticos
- Média de Participantes por Atividade: ${(totalParticipants / (activities.isEmpty ? 1 : activities.length)).toStringAsFixed(1)}
- Engajamento de Media: ${(totalMedia / (activities.isEmpty ? 1 : activities.length)).toStringAsFixed(1)} itens/atividades

## Detalhe de Atividades
${activities.map((a) => "- **${a.title}**: ${a.description} (${a.participants.length} participantes)").join("\n")}
""";
    return report;
  }

  static String _countResources(List<InstitutionalActivity> activities) {
    Map<String, int> counts = {};
    for (var a in activities) {
      for (var r in a.resources) {
        counts[r.name] = (counts[r.name] ?? 0) + 1;
      }
    }
    return counts.entries.map((e) => "${e.key} (${e.value})").join(", ");
  }
}
