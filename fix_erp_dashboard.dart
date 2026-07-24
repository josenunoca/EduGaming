import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/screens/institution/erp/erp_dashboard.dart');
  var content = file.readAsStringSync();
  
  // Add import if not present
  if (!content.contains("import '../infrastructure/infrastructure_management_screen.dart';")) {
    content = content.replaceFirst(
      "import '../marketing/marketing_management_screen.dart';",
      "import '../marketing/marketing_management_screen.dart';\nimport '../infrastructure/infrastructure_management_screen.dart';"
    );
  }
  
  // Add navigation logic
  final replaceStr = '''
            if (config.module == ErpModule.marketing) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketingManagementScreen(institution: institution),
                ),
              );
              return;
            }
            if (config.module == ErpModule.infrastructure) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InfrastructureManagementScreen(institution: institution),
                ),
              );
              return;
            }
''';

  content = content.replaceAll('''
            if (config.module == ErpModule.marketing) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MarketingManagementScreen(institution: institution),
                ),
              );
              return;
            }
''', replaceStr);
  
  file.writeAsStringSync(content);
}
