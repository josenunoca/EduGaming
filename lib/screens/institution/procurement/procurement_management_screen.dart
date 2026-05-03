import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/procurement/procurement_models.dart';
import '../../../../services/procurement_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/procurement_entries_tab.dart';
import 'tabs/procurement_orders_tab.dart';
import 'tabs/procurement_profit_report_tab.dart';
import 'tabs/procurement_alerts_tab.dart';
import 'tabs/procurement_audit_tab.dart';
import 'tabs/purchase_orders_tab.dart';
import 'procurement_item_form_screen.dart';
import 'procurement_stock_entry_screen.dart';
import 'procurement_settings_screen.dart';

class ProcurementManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const ProcurementManagementScreen({super.key, required this.institution});

  @override
  State<ProcurementManagementScreen> createState() => _ProcurementManagementScreenState();
}

class _ProcurementManagementScreenState extends State<ProcurementManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<ProcurementService>();
    final user = context.read<FirebaseService>().currentUserModel!;
    
    final bool canSeeInventory = service.canManageStockGlobally(user, widget.institution) || 
      widget.institution.delegatedRoles.keys.any((k) => k.startsWith('procurement:stock_warehouse:') && widget.institution.delegatedRoles[k]!.contains(user.id));
    final bool canSeeOrders = service.canFulfillOrders(user, widget.institution) || service.canInvoiceOrders(user, widget.institution);
    final bool isStockGlobal = service.canManageStockGlobally(user, widget.institution);

    // Filter available tabs based on permissions
    final List<Map<String, dynamic>> availableTabs = [
      if (canSeeInventory) {'icon': Icons.inventory_2_outlined, 'text': 'Inventário', 'view': InventoryTab(institution: widget.institution)},
      if (canSeeInventory) {'icon': Icons.local_shipping_outlined, 'text': 'Entradas', 'view': ProcurementEntriesTab(institution: widget.institution)},
      if (canSeeOrders) {'icon': Icons.shopping_bag_outlined, 'text': 'Encomendas', 'view': ProcurementOrdersTab(institution: widget.institution)},
      if (canSeeInventory) {'icon': Icons.assignment_outlined, 'text': 'Encomendas Fornec.', 'view': PurchaseOrdersTab(institution: widget.institution)},
      if (isStockGlobal) {'icon': Icons.monetization_on_outlined, 'text': 'Lucros', 'view': ProcurementProfitReportTab(institution: widget.institution)},
      if (canSeeInventory) {'icon': Icons.warning_amber_outlined, 'text': 'Alertas', 'view': ProcurementAlertsTab(institution: widget.institution)},
      if (isStockGlobal) {'icon': Icons.history_outlined, 'text': 'Auditoria', 'view': ProcurementAuditTab(institution: widget.institution)},
    ];

    if (_tabController.length != availableTabs.length) {
      _tabController.dispose();
      _tabController = TabController(length: availableTabs.length, vsync: this);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Aprovisionamento 360º - ${widget.institution.name}'),
        bottom: availableTabs.isEmpty ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFF9F1C),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFFF9F1C),
          tabs: availableTabs.map((t) => Tab(icon: Icon(t['icon']), text: t['text'])).toList(),
        ),
      ),
      body: availableTabs.isEmpty 
        ? const Center(child: AiTranslatedText('Sem permissões para este módulo.', style: TextStyle(color: Colors.white54)))
        : TabBarView(
            controller: _tabController,
            children: availableTabs.map((t) => t['view'] as Widget).toList(),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionMenu,
        backgroundColor: const Color(0xFFFF9F1C),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showQuickActionMenu() {
    final service = context.read<ProcurementService>();
    final user = context.read<FirebaseService>().currentUserModel!;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (service.canManageStockGlobally(user, widget.institution))
              ListTile(
                leading:
                    const Icon(Icons.add_box_outlined, color: Colors.orangeAccent),
                title: const AiTranslatedText('Novo Artigo (Catálogo)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProcurementItemFormScreen(
                          institutionId: widget.institution.id),
                    ),
                  );
                },
              ),
            if (service.canManageStockGlobally(user, widget.institution) || 
                widget.institution.delegatedRoles.keys.any((k) => k.startsWith('procurement:stock_warehouse:') && widget.institution.delegatedRoles[k]!.contains(user.id)))
              ListTile(
                leading:
                    const Icon(Icons.input_rounded, color: Colors.greenAccent),
                title: const AiTranslatedText('Carregar Entrada (Stock +)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProcurementStockEntryScreen(
                          institution: widget.institution),
                    ),
                  );
                },
              ),
            if (service.canManageStockGlobally(user, widget.institution))
              ListTile(
                leading:
                    const Icon(Icons.settings_suggest_outlined, color: Colors.blueAccent),
                title: const AiTranslatedText('Configurações (Famílias/Armazéns)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProcurementSettingsScreen(
                          institutionId: widget.institution.id),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
