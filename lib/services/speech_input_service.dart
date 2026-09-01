import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  final SpeechToText _speech = SpeechToText();

  Future<String?> listenOnce({String localeId = 'es_CR'}) async {
    final available = await _speech.initialize();
    if (!available) return null;
    String finalText = '';
    await _speech.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) => finalText = result.recognizedWords,
    );
    await Future<void>.delayed(const Duration(seconds: 6));
    await _speech.stop();
    return finalText.trim().isEmpty ? null : finalText.trim();
  }
}
