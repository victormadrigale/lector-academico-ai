import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../controllers/reader_controller.dart';
import '../models/document_item.dart';
import '../services/chatgpt_share_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/local_ai_service.dart';
import '../services/speech_input_service.dart';
import '../services/tts_service.dart';
import '../widgets/karaoke_text.dart';

class ReaderScreen extends StatefulWidget {
  final DocumentItem document;
  const ReaderScreen({super.key, required this.document});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final ReaderController controller;
  final connectivity = ConnectivityService();
  final speech = SpeechInputService();
  late final ExportService exporter;
  late final LocalAiService localAi;
  final chatGpt = ChatGptShareService();
  final pdfViewerController = PdfViewerController();
  bool online = false;
  bool originalPage = false;
  int? _lastViewerPage;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService.instance;
    exporter = ExportService(db);
    localAi = LocalAiService(db);
    controller = ReaderController(db: db, tts: TtsService(), document: widget.document)..addListener(_changed);
    controller.init();
    connectivity.start().then((_) async {
      online = connectivity.online;
      await controller.tts.preferConnectivity(online);
      if (mounted) setState(() {});
    });
    connectivity.changes.listen((v) async {
      online = v;
      await controller.tts.preferConnectivity(v);
      if (mounted) setState(() {});
    });
    pdfViewerController.addListener(_pdfChanged);
  }

  void _pdfChanged() {
    if (!originalPage || !pdfViewerController.isReady) return;
    final p = pdfViewerController.pageNumber;
    if (p != null && p != _lastViewerPage && p != controller.page) {
      _lastViewerPage = p;
      controller.jumpPage(p);
    }
  }

  void _changed() {
    if (originalPage && pdfViewerController.isReady && pdfViewerController.pageNumber != controller.page) {
      pdfViewerController.goToPage(pageNumber: controller.page, duration: const Duration(milliseconds: 250));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    connectivity.dispose();
    pdfViewerController.removeListener(_pdfChanged);
    
    super.dispose();
  }

  Future<String?> _askText(String title, {bool voice = false}) async {
    if (voice) return speech.listenOnce();
    final text = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: text, autofocus: true, minLines: 2, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  Future<void> _question(bool voice) async {
    await controller.pause();
    final q = await _askText(voice ? 'Pregunta por voz' : 'Escribe tu pregunta', voice: voice);
    if (q == null || q.isEmpty) return;
    final result = await localAi.ask(document: controller.document, question: q, currentPage: controller.page);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respuesta local · página ${controller.page}'),
        content: SingleChildScrollView(child: Text(result.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          TextButton.icon(
            onPressed: () async {
              final prompt = localAi.buildChatGptPrompt(
                document: controller.document,
                page: controller.page,
                currentContext: controller.pageText,
                question: q,
              );
              await chatGpt.sharePrompt(prompt);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Enviar a ChatGPT'),
          ),
          FilledButton.icon(onPressed: () => controller.tts.speak(result.text), icon: const Icon(Icons.volume_up), label: const Text('Escuchar')),
        ],
      ),
    );
  }

  Future<void> _bookmark(bool voice) async {
    final note = await _askText(voice ? 'Dictar marcador' : 'Escribir marcador', voice: voice);
    if (note == null || note.isEmpty) return;
    final category = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Categoría'),
            children: ['Importante', 'Cita', 'Duda', 'Metodología', 'Resultado']
                .map((x) => SimpleDialogOption(onPressed: () => Navigator.pop(context, x), child: Text(x)))
                .toList(),
          ),
        ) ??
        'Importante';
    await DatabaseService.instance.addBookmark(controller.buildBookmark(note, category));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Marcador guardado en página ${controller.page}')));
  }

  Future<void> _export(bool annotated) async {
    final marks = await DatabaseService.instance.bookmarks(controller.document.id!);
    final File file = annotated
        ? await exporter.exportAnnotatedReadingCopy(controller.document, marks)
        : await exporter.exportNotes(controller.document, marks);
    await exporter.shareFile(file);
  }

  @override
  Widget build(BuildContext context) {
    final d = controller.document;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
          Text('Página ${controller.page} de ${d.totalPages}', style: Theme.of(context).textTheme.labelSmall),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Chip(avatar: Icon(online ? Icons.cloud_done : Icons.phone_android, size: 16), label: Text(online ? 'Online' : 'Offline')),
          ),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'notes') _export(false); if (v == 'annotated') _export(true); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'annotated', child: Text('Exportar copia anotada PDF')),
              PopupMenuItem(value: 'notes', child: Text('Exportar marcadores')),
            ],
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              LinearProgressIndicator(value: d.progress),
              if (d.extension == 'pdf')
                SegmentedButton<bool>(
                  segments: const [ButtonSegment(value: false, label: Text('Karaoke')), ButtonSegment(value: true, label: Text('Página original'))],
                  selected: {originalPage},
                  onSelectionChanged: (v) => setState(() {
                    originalPage = v.first;
                    if (originalPage && pdfViewerController.isReady) {
                      pdfViewerController.goToPage(pageNumber: controller.page, duration: Duration.zero);
                    }
                  }),
                ),
              Expanded(
                child: originalPage && d.extension == 'pdf'
                    ? PdfViewer.file(
                        d.localPath,
                        controller: pdfViewerController,
                        initialPageNumber: controller.page,
                      )
                    : KaraokeText(
                        sentences: controller.sentences,
                        currentIndex: controller.sentenceIndex,
                        wordStart: controller.charStart,
                        wordEnd: controller.charEnd,
                      ),
              ),
            ]),
      bottomSheet: SafeArea(
        child: Material(
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.filledTonal(onPressed: controller.previousSentence, icon: const Icon(Icons.replay_10)),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(onPressed: controller.toggle, icon: Icon(controller.playing ? Icons.pause : Icons.play_arrow), label: Text(controller.playing ? 'Pausar' : 'Continuar')),
                const SizedBox(width: 12),
                IconButton.filledTonal(onPressed: controller.nextSentence, icon: const Icon(Icons.forward_10)),
              ]),
              Row(children: [
                const Text('Velocidad'),
                Expanded(child: Slider(value: d.speechRate.clamp(0.75, 2.0).toDouble(), min: 0.75, max: 2.0, divisions: 5, label: '${d.speechRate.toStringAsFixed(2)}x', onChanged: controller.setRate)),
                Text('${d.speechRate.toStringAsFixed(2)}x'),
              ]),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: () => _question(true), icon: const Icon(Icons.mic), label: const Text('Preguntar voz'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(onPressed: () => _question(false), icon: const Icon(Icons.keyboard), label: const Text('Preguntar texto'))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: FilledButton.tonalIcon(onPressed: () => _bookmark(true), icon: const Icon(Icons.bookmark_add), label: const Text('Marcar voz'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(onPressed: () => _bookmark(false), icon: const Icon(Icons.edit_note), label: const Text('Marcar texto'))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
