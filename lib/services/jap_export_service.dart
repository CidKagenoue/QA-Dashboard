import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';
import 'dart:typed_data';
import '../models/jap_gpp_entry.dart';

extension JapPriorityExt on JapPriority {
  String toLabel() {
    switch (this) {
      case JapPriority.high:
        return 'Hoog';
      case JapPriority.medium:
        return 'Middel';
      case JapPriority.low:
        return 'Laag';
    }
  }
}

extension JapRealisationExt on JapRealisation {
  String toLabel() {
    switch (this) {
      case JapRealisation.completed:
        return 'Uitgevoerd';
      case JapRealisation.notYetCompleted:
        return 'Nog niet';
      case JapRealisation.inProgress:
        return 'In Uitvoering';
      case JapRealisation.fillIn:
        return 'Vul aan';
    }
  }
}

class JapExportService {
  /// Export a single year's JAP entries as PDF
  static Future<void> exportJapForYear(int year, List<JapEntry> entries) async {
    try {
      final pdf = _generateYearPdf(year, entries);
      final pdfBytes = await pdf.save();
      
      // Use printing plugin to display PDF with print/save options
      await Printing.layoutPdf(
        onLayout: (pageFormat) async => pdfBytes,
        name: 'JAP_$year.pdf',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Export all JAP entries organized by year as a zip file with folder structure
  static Future<Uint8List> exportJapAsZip(List<JapEntry> entries) async {
    final archive = Archive();
    
    // Group entries by year
    final entriesByYear = <int, List<JapEntry>>{};
    for (final entry in entries) {
      entriesByYear.putIfAbsent(entry.year, () => []).add(entry);
    }
    
    // Create PDF for each year and add to archive
    for (final year in entriesByYear.keys.toList()..sort()) {
      final yearEntries = entriesByYear[year]!;
      final pdf = _generateYearPdf(year, yearEntries);
      final pdfBytes = await pdf.save();
      
      // Add PDF to zip with folder structure: JAP_2024/JAP_2024.pdf, JAP_2025/JAP_2025.pdf, etc.
      archive.addFile(
        ArchiveFile(
          'JAP_$year/JAP_$year.pdf',
          pdfBytes.length,
          pdfBytes,
        ),
      );
    }
    
    // Create zip file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    return zipBytes != null ? Uint8List.fromList(zipBytes) : Uint8List(0);
  }

  /// Export all JAP entries by year - for backward compatibility
  static Future<void> exportJapByYear(List<JapEntry> entries) async {
    // Group JAP entries by year
    final entriesByYear = <int, List<JapEntry>>{};
    for (final entry in entries) {
      entriesByYear.putIfAbsent(entry.year, () => []).add(entry);
    }

    // Sort years
    final years = entriesByYear.keys.toList()..sort();

    if (years.isEmpty) return;

    // Generate PDF for each year
    for (final year in years) {
      final yearEntries = entriesByYear[year]!;
      await exportJapForYear(year, yearEntries);
    }
  }

  static pw.Document _generateYearPdf(int year, List<JapEntry> entries) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Jaarlijks Actieplan (JAP)',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Jaar $year',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                  pw.Divider(color: PdfColors.grey300, thickness: 1),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
            // Summary stats
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBox('Totaal Acties', entries.length.toString()),
                  _buildStatBox('Voltooid', entries.where((e) => e.realisation == 'uitgevoerd').length.toString()),
                  _buildStatBox('In Uitvoering', entries.where((e) => e.realisation == 'in_uitvoering').length.toString()),
                  _buildStatBox('Nog niet', entries.where((e) => e.realisation == 'neg_niet_uitgevoerd').length.toString()),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Summary table
            pw.TableHelper.fromTextArray(
              headers: [
                'Doelstelling',
                'Domein',
                'Prioriteit',
                'Realisatie',
                'Uitvoerder',
              ],
              data: entries.map((e) => [
                e.goalMeasure.length > 50 ? '${e.goalMeasure.substring(0, 47)}...' : e.goalMeasure,
                e.domain,
                e.priority.toLabel(),
                e.realisation.toLabel(),
                e.executor.isEmpty ? '-' : e.executor,
              ]).toList(),
              cellStyle: pw.TextStyle(fontSize: 9),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue700),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey300, thickness: 2),
            pw.SizedBox(height: 20),
            // Detailed entries
            pw.Text(
              'Gedetailleerde Acties',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Column(
              children: entries.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final jap = entry.value;
                return pw.Column(
                  children: [
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        color: PdfColors.grey50,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '$index. ${jap.goalMeasure}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Domein: ${jap.domain}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Jaar: $year', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Prioriteit: ${jap.priority.toLabel()}', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Realisatie: ${jap.realisation.toLabel()}', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          if (jap.executor.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Uitvoerder: ${jap.executor}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                          if (jap.resourcesBudget.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Middelen/Budget: ${jap.resourcesBudget}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                          if (jap.remark.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text('Opmerking:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text(jap.remark, style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            // Footer
            pw.SizedBox(height: 20),
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Dit document is automatisch gegenereerd.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    );
  }
}
