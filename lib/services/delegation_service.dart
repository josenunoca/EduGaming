import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/institution_model.dart';
import '../models/user_model.dart';
import '../models/delegation_event_model.dart';
import 'firebase_service.dart';

class DelegationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseService _firebaseService;

  DelegationService(this._firebaseService);

  /// Main method to update delegation and record history
  Future<void> updateDelegation({
    required InstitutionModel institution,
    required String moduleKey,
    required String moduleLabel,
    required List<String> newUserIds,
    required List<UserModel> allCollaborators,
  }) async {
    final currentUser = _firebaseService.currentUserModel!;
    final oldUserIds = institution.delegatedRoles[moduleKey] ?? [];

    // Identify added and removed users
    final addedIds = newUserIds.where((id) => !oldUserIds.contains(id)).toList();
    final removedIds = oldUserIds.where((id) => !newUserIds.contains(id)).toList();

    final batch = _db.batch();

    // 1. Update Institution delegatedRoles (Current State)
    final updatedRoles = Map<String, List<String>>.from(institution.delegatedRoles);
    updatedRoles[moduleKey] = newUserIds;
    batch.update(_db.collection('institutions').doc(institution.id), {'delegatedRoles': updatedRoles});

    final now = DateTime.now();

    // 2. Handle Added Delegations (New Events)
    for (var userId in addedIds) {
      final delegate = allCollaborators.firstWhere((u) => u.id == userId);
      final eventRef = _db.collection('institutions').doc(institution.id).collection('delegation_history').doc();
      
      final event = DelegationEvent(
        id: eventRef.id,
        institutionId: institution.id,
        moduleKey: moduleKey,
        moduleLabel: moduleLabel,
        delegateId: userId,
        delegateName: delegate.name,
        assignedById: currentUser.id,
        assignedByName: currentUser.name,
        startDate: now,
      );
      batch.set(eventRef, event.toMap());
    }

    // 3. Handle Removed Delegations (Close Events)
    for (var userId in removedIds) {
      final activeEvents = await _db
          .collection('institutions')
          .doc(institution.id)
          .collection('delegation_history')
          .where('moduleKey', isEqualTo: moduleKey)
          .where('delegateId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in activeEvents.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'endDate': Timestamp.fromDate(now),
        });
      }
    }

    await batch.commit();
  }

  Stream<List<DelegationEvent>> getDelegationHistory(String institutionId) {
    return _db
        .collection('institutions')
        .doc(institutionId)
        .collection('delegation_history')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DelegationEvent.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> generateAuditPdf(InstitutionModel institution, List<DelegationEvent> history) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final activeDelegations = history.where((e) => e.isActive).toList();
    final pastDelegations = history.where((e) => !e.isActive).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(institution),
            pw.SizedBox(height: 24),
            _buildTitle('REGISTO DE DELEGAÇÕES DE RESPONSABILIDADE'),
            pw.SizedBox(height: 8),
            pw.Text('Este documento constitui o registo oficial de delegações da instituição, servindo para apuramento de responsabilidades e controlo de alterações.',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 24),
            
            _buildSectionHeader('DELEGAÇÕES EM CURSO (ATIVAS)'),
            _buildDelegationTable(activeDelegations, true),
            
            pw.SizedBox(height: 32),
            
            _buildSectionHeader('HISTÓRICO DE DELEGAÇÕES (CONCLUÍDAS)'),
            _buildDelegationTable(pastDelegations, false),
            
            pw.Spacer(),
            _buildFooter(institution),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Auditoria_Delegacoes_${institution.name}_${DateTime.now().toString().split(' ')[0]}.pdf',
    );
  }

  pw.Widget _buildHeader(InstitutionModel institution) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(institution.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('NIF: ${institution.nif}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(institution.address, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        if (institution.logoUrl != null)
          pw.Text('LOGO', style: const pw.TextStyle(color: PdfColors.grey300)) // In a real app we'd load the image
      ],
    );
  }

  pw.Widget _buildTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      child: pw.Center(
        child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ),
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Divider(color: PdfColors.blue900, thickness: 1),
        ],
      ),
    );
  }

  pw.Widget _buildDelegationTable(List<DelegationEvent> events, bool isActive) {
    if (events.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text('Nenhuma delegação registada neste estado.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey500)),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Módulo / Tarefa', 'Delegado', 'Atribuído Por', 'Início', if (!isActive) 'Fim'],
      data: events.map((e) => [
        e.moduleLabel,
        e.delegateName,
        e.assignedByName,
        _formatDate(e.startDate),
        if (!isActive) _formatDate(e.endDate!),
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 20,
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _buildFooter(InstitutionModel institution) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 150, height: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                pw.Text('Assinatura do Responsável', style: const pw.TextStyle(fontSize: 8)),
                pw.Text(DateTime.now().toString().split('.')[0], style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
