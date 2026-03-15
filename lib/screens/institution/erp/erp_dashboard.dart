import 'package:flutter/material.dart';
import '../../../models/institution_model.dart';
import '../../../models/erp_record_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import 'erp_module_screen.dart';

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
        subtitle: 'Carreiras, Colaboradores e Salários',
        icon: Icons.people_outline,
        color: const Color(0xFF00D1FF),
        module: ErpModule.hr,
      ),
      _ModuleConfig(
        title: 'Financeiro & Contas',
        subtitle: 'Faturação, Cobranças e Tesouraria',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF00FF85),
        module: ErpModule.finance,
      ),
      _ModuleConfig(
        title: 'Aprovisionamento',
        subtitle: 'Compras, Inventário e Manutenção',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFFFFB800),
        module: ErpModule.procurement,
      ),
      _ModuleConfig(
        title: 'Marketing & Expansão',
        subtitle: 'Campanhas e Internacionalização',
        icon: Icons.campaign_outlined,
        color: const Color(0xFFFF4D4D),
        module: ErpModule.marketing,
      ),
      _ModuleConfig(
        title: 'Infraestruturas',
        subtitle: 'Gestão de Edifícios e Equipamentos',
        icon: Icons.business_outlined,
        color: const Color(0xFF7B61FF),
        module: ErpModule.infrastructure,
      ),
      _ModuleConfig(
        title: 'Jurídico & Compliance',
        subtitle: 'Contratos e Proteção de Dados',
        icon: Icons.gavel_outlined,
        color: Colors.grey,
        module: ErpModule.legal,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final config = modules[index];
        return _ErpModuleCard(config: config, institution: institution);
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

  _ModuleConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.module,
  });
}

class _ErpModuleCard extends StatelessWidget {
  final _ModuleConfig config;
  final InstitutionModel institution;

  const _ErpModuleCard({required this.config, required this.institution});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
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
      borderRadius: BorderRadius.circular(20),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(config.icon, size: 40, color: config.color),
              ),
              const SizedBox(height: 16),
              AiTranslatedText(
                config.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              AiTranslatedText(
                config.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
