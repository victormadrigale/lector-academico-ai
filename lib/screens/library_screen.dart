import 'package:flutter/material.dart';

import '../models/document_item.dart';
import '../services/database_service.dart';
import '../services/import_service.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final db = DatabaseService.instance;
  late final ImportService importer = ImportService(db);
  List<DocumentItem> docs = [];
  bool busy = false;
  final selected = <int>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    docs = await db.documents();
    if (mounted) setState(() {});
  }

  Future<void> _import() async {
    setState(() => busy = true);
    try {
      await importer.importMultiple();
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _prepare(Iterable<DocumentItem> items) async {
    setState(() => busy = true);
    var ready = 0;
    for (final doc in items) {
      if (await importer.verifyOffline(doc)) ready++;
    }
    selected.clear();
    await _refresh();
    if (mounted) {
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$ready documento(s) listos para viajar sin Internet.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDocs = docs.where((d) => d.id != null && selected.contains(d.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi biblioteca'),
        actions: [
          if (selected.isNotEmpty)
            TextButton.icon(
              onPressed: busy ? null : () => _prepare(selectedDocs),
              icon: const Icon(Icons.offline_pin),
              label: Text('Preparar (${selected.length})'),
            ),
          if (docs.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'all') _prepare(docs); },
              itemBuilder: (_) => const [PopupMenuItem(value: 'all', child: Text('Preparar toda la biblioteca'))],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : _import,
        icon: const Icon(Icons.add),
        label: Text(busy ? 'Procesando…' : 'Agregar documentos'),
      ),
      body: docs.isEmpty
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Agrega varios PDF o DOCX. Cada documento guardará su página, progreso y marcadores de forma independiente.', textAlign: TextAlign.center),
            ))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final d = docs[i];
                final checked = d.id != null && selected.contains(d.id);
                return Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: checked,
                      onChanged: d.id == null ? null : (v) => setState(() => v == true ? selected.add(d.id!) : selected.remove(d.id!)),
                    ),
                    title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Página ${d.currentPage} de ${d.totalPages} · ${(d.progress * 100).toStringAsFixed(0)}% · ${d.preparedOffline ? '✓ Listo offline' : 'Preparación pendiente'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(document: d)));
                      await _refresh();
                    },
                  ),
                );
              },
            ),
    );
  }
}
