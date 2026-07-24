import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/screens/institution/erp/erp_dashboard.dart');
  var content = file.readAsStringSync();
  
  // Remove import
  content = content.replaceAll("import '../infrastructure/infrastructure_management_screen.dart';", "");
  
  // Remove the module config
  final configStr = '''
        _ModuleConfig(
          title: 'Infraestruturas',
          subtitle: 'Edifícios',
          icon: Icons.business_outlined,
          color: const Color(0xFF7B61FF),
          module: ErpModule.infrastructure,
        ),
''';
  content = content.replaceAll(configStr, "");
  
  // Remove the routing
  final routingStr = '''
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
  content = content.replaceAll(routingStr, "");
  
  file.writeAsStringSync(content);
}
