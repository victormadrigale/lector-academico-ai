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

  const ReaderScreen({
    super.key,
    required this.document,
  });

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

    controller = ReaderController(
      db: db,
      tts: TtsService(),
      document: widget.document,
    )..addListener(_changed);

    controller.init();

    connectivity.start().then((_) async {
      online = connectivity.online;

      await controller.tts.preferConnectivity(
        online,
      );

      if (mounted) {
        setState(() {});
      }
    });

    connectivity.changes.listen((value) async {
      online = value;

      await controller.tts.preferConnectivity(
        value,
      );

      if (mounted) {
        setState(() {});
      }
    });

    pdfViewerController.addListener(
      _pdfChanged,
    );
  }

  void _pdfChanged() {
    if (!originalPage ||
        !pdfViewerController.isReady) {
      return;
    }

    final page =
        pdfViewerController.pageNumber;

    if (page != null &&
        page != _lastViewerPage &&
        page != controller.page) {
      _lastViewerPage = page;
      controller.jumpPage(page);
    }
  }

  void _changed() {
    if (originalPage &&
        pdfViewerController.isReady &&
        pdfViewerController.pageNumber !=
            controller.page) {
      pdfViewerController.goToPage(
        pageNumber: controller.page,
        duration:
            const Duration(
              milliseconds: 250,
            ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();

    connectivity.dispose();

    pdfViewerController.removeListener(
      _pdfChanged,
    );

    super.dispose();
  }

  Future<String?> _askText(
    String title, {
    bool voice = false,
  }) async {
    if (voice) {
      return speech.listenOnce();
    }

    final text = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: text,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  text.text.trim(),
                );
              },
              child:
                  const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _question(
    bool voice,
  ) async {
    await controller.pause();

    final question = await _askText(
      voice
          ? 'Pregunta por voz'
          : 'Escribe tu pregunta',
      voice: voice,
    );

    if (question == null ||
        question.isEmpty) {
      return;
    }

    final result = await localAi.ask(
      document: controller.document,
      question: question,
      currentPage: controller.page,
    );

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Respuesta local · página ${controller.page}',
          ),
          content: SingleChildScrollView(
            child: Text(result.text),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
                  const Text('Cerrar'),
            ),
            TextButton.icon(
              onPressed: () async {
                final prompt =
                    localAi.buildChatGptPrompt(
                  document:
                      controller.document,
                  page: controller.page,
                  currentContext:
                      controller.pageText,
                  question: question,
                );

                await chatGpt.sharePrompt(
                  prompt,
                );
              },
              icon: const Icon(
                Icons.open_in_new,
              ),
              label: const Text(
                'Enviar a ChatGPT',
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                controller.tts.speak(
                  result.text,
                );
              },
              icon: const Icon(
                Icons.volume_up,
              ),
              label:
                  const Text('Escuchar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bookmark(
    bool voice,
  ) async {
    final note = await _askText(
      voice
          ? 'Dictar marcador'
          : 'Escribir marcador',
      voice: voice,
    );

    if (note == null ||
        note.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    final category =
        await showDialog<String>(
          context: context,
          builder: (context) {
            return SimpleDialog(
              title:
                  const Text('Categoría'),
              children: [
                'Importante',
                'Cita',
                'Duda',
                'Metodología',
                'Resultado',
              ].map((item) {
                return SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      item,
                    );
                  },
                  child: Text(item),
                );
              }).toList(),
            );
          },
        ) ??
        'Importante';

    await DatabaseService.instance
        .addBookmark(
      controller.buildBookmark(
        note,
        category,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Marcador guardado en página ${controller.page}',
          ),
        ),
      );
    }
  }

  Future<void> _export(
    bool annotated,
  ) async {
    final marks =
        await DatabaseService.instance
            .bookmarks(
      controller.document.id!,
    );

    final File file = annotated
        ? await exporter
            .exportAnnotatedReadingCopy(
            controller.document,
            marks,
          )
        : await exporter.exportNotes(
            controller.document,
            marks,
          );

    await exporter.shareFile(file);
  }

  Future<void> _showVoicePicker() async {
    await controller.pause();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: FutureBuilder<
              List<TtsVoiceOption>>(
            future: controller.tts
                .getSpanishVoices(),
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              final voices =
                  snapshot.data ?? [];

              if (voices.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No se encontraron voces en español instaladas en este dispositivo.',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      20,
                      0,
                      20,
                      12,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Seleccionar voz',
                          style:
                              Theme.of(
                            context,
                          )
                                  .textTheme
                                  .titleLarge,
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        const Text(
                          'Puedes probar las voces disponibles antes de elegir. Las voces Offline funcionan sin Internet.',
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                  ),
                  Expanded(
                    child:
                        ListView.separated(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        12,
                        8,
                        12,
                        24,
                      ),
                      itemCount:
                          voices.length,
                      separatorBuilder:
                          (_, __) =>
                              const Divider(
                        height: 1,
                      ),
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        final voice =
                            voices[index];

                        final selected =
                            controller
                                    .tts
                                    .selectedVoice
                                    ?.name ==
                                voice.name;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              voice
                                      .requiresNetwork
                                  ? Icons
                                      .cloud_outlined
                                  : Icons
                                      .download_done,
                            ),
                          ),
                          title: Text(
                            voice.displayName,
                          ),
                          subtitle: Text(
                            voice.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons
                                      .check_circle,
                                )
                              : null,
                          onTap: () async {
                            await controller
                                .tts
                                .previewVoice(
                              voice,
                            );
                          },
                          onLongPress:
                              () async {
                            await controller
                                .tts
                                .selectVoice(
                              voice,
                            );

                            if (sheetContext
                                .mounted) {
                              Navigator.pop(
                                sheetContext,
                              );
                            }

                            if (mounted) {
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      16,
                      8,
                      16,
                      16,
                    ),
                    child: Text(
                      'Toca una voz para escucharla. Mantén pulsada una voz para seleccionarla.',
                      textAlign:
                          TextAlign.center,
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildBottomControls() {
    final document =
        controller.document;

    final selectedVoice =
        controller.tts.selectedVoice;

    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            10,
            8,
            10,
            8,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: controller
                        .previousSentence,
                    tooltip:
                        'Anterior',
                    icon: const Icon(
                      Icons.replay_10,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        controller.toggle,
                    icon: Icon(
                      controller.playing
                          ? Icons.pause
                          : Icons
                              .play_arrow,
                    ),
                    label: Text(
                      controller.playing
                          ? 'Pausar'
                          : 'Continuar',
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  IconButton.filledTonal(
                    onPressed: controller
                        .nextSentence,
                    tooltip:
                        'Siguiente',
                    icon: const Icon(
                      Icons.forward_10,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Velocidad',
                  ),
                  Expanded(
                    child: Slider(
                      value: document
                          .speechRate
                          .clamp(
                            0.75,
                            2.0,
                          )
                          .toDouble(),
                      min: 0.75,
                      max: 2.0,
                      divisions: 5,
                      label:
                          '${document.speechRate.toStringAsFixed(2)}x',
                      onChanged:
                          controller.setRate,
                    ),
                  ),
                  Text(
                    '${document.speechRate.toStringAsFixed(2)}x',
                  ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _showVoicePicker,
                  icon: const Icon(
                    Icons.record_voice_over,
                  ),
                  label: Text(
                    selectedVoice ==
                            null
                        ? 'Elegir voz'
                        : selectedVoice
                            .displayName,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                  ),
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        FilledButton.icon(
                      onPressed: () {
                        _question(true);
                      },
                      icon: const Icon(
                        Icons.mic,
                      ),
                      label: const Text(
                        'Preguntar voz',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        _question(false);
                      },
                      icon: const Icon(
                        Icons.keyboard,
                      ),
                      label: const Text(
                        'Preguntar texto',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 6,
              ),
              Row(
                children: [
                  Expanded(
                    child:
                        FilledButton
                            .tonalIcon(
                      onPressed: () {
                        _bookmark(true);
                      },
                      icon: const Icon(
                        Icons.bookmark_add,
                      ),
                      label: const Text(
                        'Marcar voz',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        _bookmark(false);
                      },
                      icon: const Icon(
                        Icons.edit_note,
                      ),
                      label: const Text(
                        'Marcar texto',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final document =
        controller.document;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 15,
              ),
            ),
            Text(
              'Página ${controller.page} de ${document.totalPages}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets.only(
              right: 4,
            ),
            child: Chip(
              avatar: Icon(
                online
                    ? Icons.cloud_done
                    : Icons.phone_android,
                size: 16,
              ),
              label: Text(
                online
                    ? 'Online'
                    : 'Offline',
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'notes') {
                _export(false);
              }

              if (value ==
                  'annotated') {
                _export(true);
              }

              if (value == 'voice') {
                _showVoicePicker();
              }
            },
            itemBuilder: (_) {
              return const [
                PopupMenuItem(
                  value: 'voice',
                  child: Text(
                    'Seleccionar voz',
                  ),
                ),
                PopupMenuItem(
                  value: 'annotated',
                  child: Text(
                    'Exportar copia anotada PDF',
                  ),
                ),
                PopupMenuItem(
                  value: 'notes',
                  child: Text(
                    'Exportar marcadores',
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: controller.loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Column(
              children: [
                LinearProgressIndicator(
                  value:
                      document.progress,
                ),
                if (document.extension ==
                    'pdf')
                  Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      8,
                      4,
                      8,
                      4,
                    ),
                    child:
                        SegmentedButton<
                            bool>(
                      segments:
                          const [
                        ButtonSegment(
                          value: false,
                          label: Text(
                            'Karaoke',
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(
                            'Página original',
                          ),
                        ),
                      ],
                      selected: {
                        originalPage,
                      },
                      onSelectionChanged:
                          (value) {
                        setState(() {
                          originalPage =
                              value.first;

                          if (originalPage &&
                              pdfViewerController
                                  .isReady) {
                            pdfViewerController
                                .goToPage(
                              pageNumber:
                                  controller
                                      .page,
                              duration:
                                  Duration
                                      .zero,
                            );
                          }
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: originalPage &&
                          document
                                  .extension ==
                              'pdf'
                      ? PdfViewer.file(
                          document
                              .localPath,
                          controller:
                              pdfViewerController,
                          initialPageNumber:
                              controller
                                  .page,
                        )
                      : KaraokeText(
                          sentences:
                              controller
                                  .sentences,
                          currentIndex:
                              controller
                                  .sentenceIndex,
                          wordStart:
                              controller
                                  .charStart,
                          wordEnd:
                              controller
                                  .charEnd,
                        ),
                ),
              ],
            ),
      bottomNavigationBar:
          controller.loading
              ? null
              : _buildBottomControls(),
    );
  }
}
