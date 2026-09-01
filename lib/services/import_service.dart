import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import '../models/document_item.dart';
import 'database_service.dart';

class ImportService {
  final DatabaseService db;
  ImportService(this.db);

  Future<int> importMultiple() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    if (result == null) return 0;
    var imported = 0;
    for (final file in result.files) {
      if (file.path == null) continue;
      await _import(File(file.path!));
      imported++;
    }
    return imported;
  }

  Future<void> _import(File source) async {
    final extension = p.extension(source.path).toLowerCase().replaceFirst('.', '');
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'library'));
    await docsDir.create(recursive: true);
    final safeName = '${DateTime.now().microsecondsSinceEpoch}_${p.basename(source.path)}';
    final local = await source.copy(p.join(docsDir.path, safeName));

    if (extension == 'pdf') {
      await _importPdf(local);
    } else if (extension == 'docx') {
      await _importDocx(local);
    } else {
      throw UnsupportedError('Formato no compatible: $extension');
    }
  }

  Future<void> _importPdf(File file) async {
    final pdf = await PdfDocument.openFile(file.path);
    final pages = pdf.pages.length;
    final id = await db.insertDocument(DocumentItem(
      title: p.basename(file.path).replaceFirst(RegExp(r'^\d+_'), ''),
      localPath: file.path,
      extension: 'pdf',
      totalPages: pages,
      updatedAt: DateTime.now(),
    ));
    for (var i = 0; i < pages; i++) {
      final raw = await pdf.pages[i].loadText();
      await db.savePageText(id, i + 1, raw?.fullText.trim() ?? '');
    }
    await pdf.dispose();
    await db.setOfflinePrepared(id, true);
  }

  Future<void> _importDocx(File file) async {
    final input = InputFileStream(file.path);
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } finally {
      input.closeSync();
    }
    final documentXml = archive.findFile('word/document.xml');
    if (documentXml == null) throw StateError('DOCX sin word/document.xml');
    final xmlText = String.fromCharCodes(documentXml.content as List<int>);
    final xml = XmlDocument.parse(xmlText);

    final paragraphs = <String>[];
    for (final pNode in xml.findAllElements('w:p')) {
      final text = pNode.findAllElements('w:t').map((e) => e.innerText).join();
      if (text.trim().isNotEmpty) paragraphs.add(text.trim());
    }

    // DOCX no conserva una paginación universal fuera de Word. Se crean
    // páginas de lectura estables para mantener una referencia clara.
    const charsPerPage = 3500;
    final pages = <String>[];
    var buffer = StringBuffer();
    for (final paragraph in paragraphs) {
      if (buffer.length + paragraph.length > charsPerPage && buffer.isNotEmpty) {
        pages.add(buffer.toString().trim());
        buffer = StringBuffer();
      }
      buffer.writeln(paragraph);
      buffer.writeln();
    }
    if (buffer.isNotEmpty) pages.add(buffer.toString().trim());
    if (pages.isEmpty) pages.add('');

    final id = await db.insertDocument(DocumentItem(
      title: p.basename(file.path).replaceFirst(RegExp(r'^\d+_'), ''),
      localPath: file.path,
      extension: 'docx',
      totalPages: pages.length,
      updatedAt: DateTime.now(),
    ));
    for (var i = 0; i < pages.length; i++) {
      await db.savePageText(id, i + 1, pages[i]);
    }
    await db.setOfflinePrepared(id, true);
  }

  Future<bool> verifyOffline(DocumentItem doc) async {
    if (doc.id == null || !await File(doc.localPath).exists()) return false;
    final count = await db.pageTextCount(doc.id!);
    final ready = count >= doc.totalPages;
    await db.setOfflinePrepared(doc.id!, ready);
    return ready;
  }
}
