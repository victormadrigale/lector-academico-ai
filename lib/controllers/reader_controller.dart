import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/bookmark.dart';
import '../models/document_item.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';

class ReaderController extends ChangeNotifier {
  final DatabaseService db;
  final TtsService tts;
  DocumentItem document;

  String pageText = '';
  List<String> sentences = const [];
  int sentenceIndex = 0;
  int charStart = 0;
  int charEnd = 0;
  int _speakBaseOffset = 0;
  bool playing = false;
  bool loading = false;
  Timer? _saveDebounce;

  ReaderController({required this.db, required this.tts, required this.document});

  int get page => document.currentPage;
  String get currentSentence =>
      sentences.isEmpty ? '' : sentences[sentenceIndex.clamp(0, sentences.length - 1).toInt()];

  Future<void> init() async {
    loading = true;
    notifyListeners();
    await tts.init();
    await tts.setRate(document.speechRate);

    tts.onProgress = (p) {
      charStart = (_speakBaseOffset + p.start).clamp(0, currentSentence.length).toInt();
      charEnd = (_speakBaseOffset + p.end).clamp(charStart, currentSentence.length).toInt();
      _scheduleSave();
      notifyListeners();
    };
    tts.onCompleted = _advance;

    await _loadPage(
      document.currentPage,
      restoreSentence: document.currentSentence,
      restoreCharOffset: document.currentCharOffset,
    );
    loading = false;
    notifyListeners();
  }

  Future<void> _loadPage(
    int page, {
    int restoreSentence = 0,
    int restoreCharOffset = 0,
  }) async {
    pageText = await db.pageText(document.id!, page);
    sentences = _splitSentences(pageText);
    sentenceIndex = sentences.isEmpty ? 0 : restoreSentence.clamp(0, sentences.length - 1).toInt();
    final maxChars = currentSentence.length;
    charStart = restoreCharOffset.clamp(0, maxChars).toInt();
    charEnd = charStart;
    _speakBaseOffset = charStart;
    document = document.copyWith(
      currentPage: page,
      currentSentence: sentenceIndex,
      currentCharOffset: charStart,
      updatedAt: DateTime.now(),
    );
    await _save();
  }

  List<String> _splitSentences(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return [];
    final matches = RegExp(r'.+?(?:[.!?](?=\s|$)|$)').allMatches(normalized);
    return matches
        .map((m) => m.group(0)!.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> play() async {
    if (sentences.isEmpty) return;
    if (charStart >= currentSentence.length) {
      charStart = 0;
      charEnd = 0;
    }
    playing = true;
    _speakBaseOffset = charStart;
    notifyListeners();
    await tts.speak(currentSentence.substring(_speakBaseOffset));
  }

  Future<void> pause() async {
    playing = false;
    await tts.pause();
    await _save();
    notifyListeners();
  }

  Future<void> toggle() => playing ? pause() : play();

  Future<void> _advance() async {
    if (!playing) return;
    if (sentenceIndex + 1 < sentences.length) {
      sentenceIndex++;
      charStart = 0;
      charEnd = 0;
      _speakBaseOffset = 0;
      await _save();
      notifyListeners();
      await tts.speak(currentSentence);
      return;
    }
    if (page < document.totalPages) {
      await _loadPage(page + 1);
      notifyListeners();
      if (currentSentence.isNotEmpty) await tts.speak(currentSentence);
    } else {
      playing = false;
      await _save();
      notifyListeners();
    }
  }

  Future<void> jumpPage(int newPage) async {
    await tts.stop();
    playing = false;
    await _loadPage(newPage.clamp(1, document.totalPages).toInt());
    notifyListeners();
  }

  Future<void> nextSentence() async {
    final wasPlaying = playing;
    await tts.stop();
    if (sentenceIndex + 1 < sentences.length) {
      sentenceIndex++;
      charStart = 0;
      charEnd = 0;
      _speakBaseOffset = 0;
      await _save();
      notifyListeners();
      if (wasPlaying) await play();
    } else if (page < document.totalPages) {
      await _loadPage(page + 1);
      notifyListeners();
      if (wasPlaying) await play();
    }
  }

  Future<void> previousSentence() async {
    final wasPlaying = playing;
    await tts.stop();
    if (sentenceIndex > 0) {
      sentenceIndex--;
      charStart = 0;
      charEnd = 0;
      _speakBaseOffset = 0;
      await _save();
      notifyListeners();
      if (wasPlaying) await play();
    } else if (page > 1) {
      await _loadPage(page - 1);
      sentenceIndex = sentences.isEmpty ? 0 : sentences.length - 1;
      charStart = 0;
      charEnd = 0;
      _speakBaseOffset = 0;
      await _save();
      notifyListeners();
      if (wasPlaying) await play();
    }
  }

  Future<void> setRate(double rate) async {
    document = document.copyWith(speechRate: rate, updatedAt: DateTime.now());
    await tts.setRate(rate);
    await _save();
    notifyListeners();
  }

  ReaderBookmark buildBookmark(String note, String category) => ReaderBookmark(
        documentId: document.id!,
        page: page,
        sentenceIndex: sentenceIndex,
        excerpt: currentSentence,
        note: note,
        category: category,
        createdAt: DateTime.now(),
      );

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final pageFraction = document.totalPages <= 1
        ? 0.0
        : (page - 1) / document.totalPages;
    final sentenceFraction = sentences.isEmpty
        ? 0.0
        : sentenceIndex / sentences.length / document.totalPages;
    document = document.copyWith(
      currentPage: page,
      currentSentence: sentenceIndex,
      currentCharOffset: charStart,
      progress: (pageFraction + sentenceFraction).clamp(0.0, 1.0).toDouble(),
      updatedAt: DateTime.now(),
    );
    await db.updateProgress(document);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    tts.stop();
    super.dispose();
  }
}
