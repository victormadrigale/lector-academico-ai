import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

class TtsProgress {
  final int start;
  final int end;
  final String word;
  const TtsProgress(this.start, this.end, this.word);
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  void Function(TtsProgress progress)? onProgress;
  void Function()? onCompleted;
  List<Map<dynamic, dynamic>>? _voices;
  bool? _preferOnline;

  Future<void> init() async {
    await _setBestSpanishLanguage();
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setProgressHandler((text, startOffset, endOffset, word) {
      onProgress?.call(TtsProgress(startOffset, endOffset, word));
    });
    _tts.setCompletionHandler(() => onCompleted?.call());
  }

  Future<void> _setBestSpanishLanguage() async {
    for (final locale in ['es-CR', 'es-419', 'es-ES']) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true) {
          await _tts.setLanguage(locale);
          return;
        }
      } catch (_) {
        // Prueba el siguiente locale.
      }
    }
    await _tts.setLanguage('es-ES');
  }

  /// En Android, flutter_tts expone `network_required` en la metadata de voz.
  /// Si hay Internet se prefiere una voz española de red cuando exista; sin
  /// Internet se selecciona una voz española local. El cambio se aplica al
  /// siguiente segmento hablado y no detiene el reproductor.
  Future<void> preferConnectivity(bool online) async {
    if (_preferOnline == online) return;
    _preferOnline = online;
    if (!Platform.isAndroid) return;

    try {
      final dynamic raw = await _tts.getVoices;
      _voices ??= (raw as List).whereType<Map>().cast<Map<dynamic, dynamic>>().toList();
      final spanish = _voices!.where((v) {
        final locale = '${v['locale'] ?? ''}'.toLowerCase();
        return locale.startsWith('es');
      }).toList();
      if (spanish.isEmpty) return;

      bool requiresNetwork(Map<dynamic, dynamic> voice) {
        final value = voice['network_required'];
        if (value is bool) return value;
        return '$value'.toLowerCase() == 'true';
      }

      final preferred = spanish.where((v) => requiresNetwork(v) == online).toList();
      final chosen = (preferred.isNotEmpty ? preferred.first : spanish.first);
      final name = chosen['name']?.toString();
      final locale = chosen['locale']?.toString();
      if (name != null && locale != null) {
        await _tts.setVoice({'name': name, 'locale': locale});
      }
    } catch (_) {
      // La voz por defecto continúa funcionando. No se interrumpe la lectura.
    }
  }

  Future<void> setRate(double value) async {
    final normalized = (0.32 + (value - 0.75) * 0.20).clamp(0.25, 0.8);
    await _tts.setSpeechRate(normalized.toDouble());
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> pause() async => _tts.pause();
  Future<void> stop() async => _tts.stop();
}
