import 'package:flutter/material.dart';
import '../../../models/institution_model.dart';
import '../../../models/erp_record_model.dart';
import '../../../widgets/app_tile.dart';
import '../../../widgets/ai_translated_text.dart';
import 'erp_module_screen.dart';
import '../hr/hr_management_screen.dart';
import '../finance/finance_management_screen.dart';
import '../procurement/procurement_management_screen.dart';

class ErpDashboard extends StatelessWidget {
  final InstitutionModel institution;

  const ErpDashboard({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Administração ERP 360º - ${institution.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Gestão Centralizada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const AiTranslatedText(
              'Explore e gira todos os departamentos da sua organização.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            _buildErpGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErpGrid(BuildContext context) {
    final modules = [
      _ModuleConfig(
        title: 'Recursos Humanos',
        subtitle: 'Colaboradores',
        icon: Icons.people_outline,
        color: const Color(0xFF00D1FF),
        module: ErpModule.hr,
      ),
      _ModuleConfig(
        title: 'Financeiro & Contas',
        subtitle: 'Contabilidade',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF00FF85),
        module: ErpModule.finance,
      ),
      _ModuleConfig(
        title: 'Aprovisionamento',
        subtitle: 'Inventário',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFFFB800),
        module: ErpModule.procurement,
      ),
      _ModuleConfig(
        title: 'Marketing',
        subtitle: 'Expansão',
        icon: Icons.campaign_outlined,
        color: const Color(0xFFFF4D4D),
        module: ErpModule.marketing,
      ),
      _ModuleConfig(
        title: 'Infraestruturas',
        subtitle: 'Edifícios',
        icon: Icons.business_outlined,
        color: const Color(0xFF7B61FF),
        module: ErpModule.infrastructure,
      ),
      _ModuleConfig(
        title: 'Jurídico',
        subtitle: 'Compliance',
        icon: Icons.gavel_outlined,
        color: Colors.grey,
        module: ErpModule.legal,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 160,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final config = modules[index];
        return AppTile(
          label: config.title,
          subtitle: config.subtitle,
          icon: config.icon,
          photoUrl: config.photoUrl,
          color: config.color,
          onTap: () {
            if (config.module == ErpModule.hr) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HRManagementScreen(institution: institution),
                ),
              );
              return;
            }
            if (config.module == ErpModule.finance) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FinanceManagementScreen(institution: institution),
                ),
              );
              return;
            }
            if (config.module == ErpModule.procurement) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcurementManagementScreen(institution: institution),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ErpModuleScreen(
                  institution: institution,
                  module: config.module,
                  title: config.title,
                  themeColor: config.color,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final ErpModule module;
  final String? photoUrl;

  _ModuleConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.module,
    this.photoUrl,
  });
}
