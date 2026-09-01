import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/bookmark.dart';
import '../models/document_item.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService db;
  const ExportService(this.db);

  Future<File> exportNotes(DocumentItem doc, List<ReaderBookmark> marks) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${p.basenameWithoutExtension(doc.title)}_marcadores.txt'));
    final out = StringBuffer('Marcadores - ${doc.title}\n\n');
    for (final m in marks) {
      out.writeln('Página ${m.page} · ${m.category}');
      out.writeln('Fragmento: ${m.excerpt}');
      out.writeln('Nota: ${m.note}');
      out.writeln();
    }
    await file.writeAsString(out.toString());
    return file;
  }

  /// Genera una COPIA DE LECTURA anotada, sin modificar el original.
  /// Conserva la numeración de páginas y coloca los marcadores en la página
  /// correspondiente. Es 100 % local y usa una librería open-source.
  Future<File> exportAnnotatedReadingCopy(DocumentItem doc, List<ReaderBookmark> marks) async {
    final rows = doc.id == null ? <PageTextRow>[] : await db.documentPageTexts(doc.id!);
    final byPage = <int, List<ReaderBookmark>>{};
    for (final m in marks) {
      byPage.putIfAbsent(m.page, () => []).add(m);
    }

    final pdf = pw.Document(title: '${doc.title} - copia anotada');
    for (final row in rows) {
      final pageMarks = byPage[row.page] ?? const <ReaderBookmark>[];
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (_) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text(doc.title, style: const pw.TextStyle(fontSize: 9))),
              pw.Text('Página ${row.page} de ${doc.totalPages}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          build: (_) => [
            pw.Text(row.text.isEmpty ? '[Página sin texto extraíble]' : row.text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 3)),
            if (pageMarks.isNotEmpty) pw.SizedBox(height: 14),
            if (pageMarks.isNotEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MARCADORES DE ESTA PÁGINA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ...pageMarks.map((m) => pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 7),
                          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text('${m.category}: ${m.note}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Fragmento: ${m.excerpt}', style: const pw.TextStyle(fontSize: 9)),
                          ]),
                        )),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${p.basenameWithoutExtension(doc.title)}_copia_anotada.pdf'));
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  Future<void> shareFile(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
