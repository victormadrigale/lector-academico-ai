import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

class TtsProgress {
  final int start;
  final int end;
  final String word;

  const TtsProgress(this.start, this.end, this.word);
}

class TtsVoiceOption {
  final String name;
  final String locale;
  final bool requiresNetwork;

  const TtsVoiceOption({
    required this.name,
    required this.locale,
    required this.requiresNetwork,
  });

  String get displayName {
    String region = locale;

    if (locale.toLowerCase() == 'es-cr') {
      region = 'Español · Costa Rica';
    } else if (locale.toLowerCase() == 'es-419') {
      region = 'Español · Latinoamérica';
    } else if (locale.toLowerCase().startsWith('es-mx')) {
      region = 'Español · México';
    } else if (locale.toLowerCase().startsWith('es-us')) {
      region = 'Español · Estados Unidos';
    } else if (locale.toLowerCase().startsWith('es-es')) {
      region = 'Español · España';
    } else if (locale.toLowerCase().startsWith('es')) {
      region = 'Español · $locale';
    }

    return '$region · ${requiresNetwork ? 'Online' : 'Offline'}';
  }
}

class TtsService {
  final FlutterTts _tts = FlutterTts();

  void Function(TtsProgress progress)? onProgress;
  void Function()? onCompleted;

  List<Map<dynamic, dynamic>>? _voices;
  bool? _preferOnline;

  TtsVoiceOption? _selectedVoice;

  TtsVoiceOption? get selectedVoice => _selectedVoice;

  Future<void> init() async {
    await _setBestSpanishLanguage();

    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setProgressHandler((text, startOffset, endOffset, word) {
      onProgress?.call(
        TtsProgress(
          startOffset,
          endOffset,
          word,
        ),
      );
    });

    _tts.setCompletionHandler(() {
      onCompleted?.call();
    });
  }

  Future<void> _setBestSpanishLanguage() async {
    for (final locale in [
      'es-CR',
      'es-419',
      'es-MX',
      'es-US',
      'es-ES',
    ]) {
      try {
        final available = await _tts.isLanguageAvailable(locale);

        if (available == true) {
          await _tts.setLanguage(locale);
          return;
        }
      } catch (_) {
        // Prueba el siguiente idioma.
      }
    }

    await _tts.setLanguage('es-ES');
  }

  Future<List<TtsVoiceOption>> getSpanishVoices() async {
    try {
      final dynamic raw = await _tts.getVoices;

      _voices =
          (raw as List)
              .whereType<Map>()
              .cast<Map<dynamic, dynamic>>()
              .toList();

      final voices = _voices!
          .where((voice) {
            final locale =
                '${voice['locale'] ?? ''}'.toLowerCase();

            return locale.startsWith('es');
          })
          .map((voice) {
            return TtsVoiceOption(
              name:
                  voice['name']?.toString() ??
                  'Voz',
              locale:
                  voice['locale']?.toString() ??
                  'es-ES',
              requiresNetwork:
                  _requiresNetwork(voice),
            );
          })
          .toList();

      voices.sort((a, b) {
        final scoreA = _voiceScore(a);
        final scoreB = _voiceScore(b);

        return scoreB.compareTo(scoreA);
      });

      return voices;
    } catch (_) {
      return [];
    }
  }

  int _voiceScore(TtsVoiceOption voice) {
    int score = 0;

    final locale = voice.locale.toLowerCase();
    final name = voice.name.toLowerCase();

    if (locale == 'es-cr') {
      score += 100;
    }

    if (locale == 'es-419') {
      score += 90;
    }

    if (locale.startsWith('es-mx')) {
      score += 80;
    }

    if (locale.startsWith('es-us')) {
      score += 70;
    }

    if (locale.startsWith('es-es')) {
      score += 50;
    }

    if (name.contains('natural')) {
      score += 40;
    }

    if (name.contains('neural')) {
      score += 40;
    }

    if (name.contains('premium')) {
      score += 30;
    }

    if (name.contains('enhanced')) {
      score += 25;
    }

    if (!voice.requiresNetwork) {
      score += 10;
    }

    return score;
  }

  bool _requiresNetwork(
    Map<dynamic, dynamic> voice,
  ) {
    final value = voice['network_required'];

    if (value is bool) {
      return value;
    }

    return '$value'.toLowerCase() == 'true';
  }

  Future<void> selectVoice(
    TtsVoiceOption voice,
  ) async {
    try {
      await _tts.setVoice({
        'name': voice.name,
        'locale': voice.locale,
      });

      _selectedVoice = voice;
    } catch (_) {
      // Se mantiene la voz actual.
    }
  }

  Future<void> previewVoice(
    TtsVoiceOption voice,
  ) async {
    await stop();

    await selectVoice(voice);

    await _tts.speak(
      'Hola. Esta es una prueba de lectura. '
      'Puedes utilizar esta voz para escuchar tus documentos académicos.',
    );
  }

  Future<void> preferConnectivity(
    bool online,
  ) async {
    if (_selectedVoice != null) {
      return;
    }

    if (_preferOnline == online) {
      return;
    }

    _preferOnline = online;

    if (!Platform.isAndroid) {
      return;
    }

    try {
      final voices =
          await getSpanishVoices();

      if (voices.isEmpty) {
        return;
      }

      final preferred = voices
          .where(
            (voice) =>
                voice.requiresNetwork == online,
          )
          .toList();

      final chosen =
          preferred.isNotEmpty
          ? preferred.first
          : voices.first;

      await selectVoice(chosen);
    } catch (_) {
      // La voz actual continúa funcionando.
    }
  }

  Future<void> setRate(
    double value,
  ) async {
    final normalized =
        (0.32 +
                (value - 0.75) * 0.20)
            .clamp(
              0.25,
              0.8,
            );

    await _tts.setSpeechRate(
      normalized.toDouble(),
    );
  }

  Future<void> speak(
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return;
    }

    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
 
