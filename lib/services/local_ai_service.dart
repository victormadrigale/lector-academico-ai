import '../models/document_item.dart';
import 'database_service.dart';

class LocalAiAnswer {
  final String text;
  final List<int> pages;
  const LocalAiAnswer(this.text, this.pages);
}

/// Capa de consulta 100 % local y sin API.
///
/// Esta primera implementación es extractiva: recupera las oraciones más
/// relacionadas con la pregunta dentro del documento. La interfaz queda
/// preparada para sustituir este motor por un LLM GGUF local sin cambiar la UI.
class LocalAiService {
  final DatabaseService db;
  const LocalAiService(this.db);

  static const _stop = <String>{
    'que','qué','como','cómo','cual','cuál','cuales','cuáles','donde','dónde',
    'para','por','con','sin','del','las','los','una','uno','unos','unas','este',
    'esta','esto','estos','estas','sobre','segun','según','dice','autor','documento',
    'pagina','página','y','o','a','de','el','la','en','es','se','un','al'
  };

  Future<LocalAiAnswer> ask({
    required DocumentItem document,
    required String question,
    required int currentPage,
  }) async {
    if (document.id == null) {
      return const LocalAiAnswer('No se pudo identificar el documento.', []);
    }
    final rows = await db.documentPageTexts(document.id!);
    final terms = _tokens(question).where((t) => t.length > 2 && !_stop.contains(t)).toSet();
    if (terms.isEmpty) {
      return LocalAiAnswer(
        'La pregunta es demasiado general para el buscador local. Prueba incluyendo el concepto o término que quieres localizar.',
        const [],
      );
    }

    final hits = <_Hit>[];
    for (final row in rows) {
      final page = row.page;
      for (final sentence in _sentences(row.text)) {
        final lower = _normalize(sentence);
        var score = 0.0;
        for (final term in terms) {
          if (lower.contains(term)) score += 2;
        }
        if ((page - currentPage).abs() <= 1) score += 0.35;
        if (score > 0.4) hits.add(_Hit(page, sentence.trim(), score));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    final top = hits.take(5).toList();
    if (top.isEmpty) {
      return LocalAiAnswer(
        'No encontré un pasaje claramente relacionado con esa pregunta en el texto extraído. Puedes reformularla o enviarla a ChatGPT desde la app.',
        const [],
      );
    }

    final pages = top.map((e) => e.page).toSet().toList()..sort();
    final out = StringBuffer();
    out.writeln('Resultado local basado únicamente en el documento:');
    out.writeln();
    for (final h in top.take(3)) {
      out.writeln('• Página ${h.page}: ${h.text}');
    }
    out.writeln();
    out.writeln('Páginas más relevantes: ${pages.join(', ')}.');
    out.writeln('Este modo local es extractivo. Para una interpretación más elaborada puedes usar “Enviar a ChatGPT”.');
    return LocalAiAnswer(out.toString().trim(), pages);
  }

  String buildChatGptPrompt({
    required DocumentItem document,
    required int page,
    required String currentContext,
    required String question,
  }) => '''Estoy leyendo el documento "${document.title}". Estoy en la página $page.

Fragmento actual:
$currentContext

Pregunta:
$question

Responde en español. Distingue claramente lo que se desprende del fragmento de cualquier explicación adicional. Si necesitas más contexto del documento, indícamelo.''';

  Iterable<String> _tokens(String value) => _normalize(value).split(RegExp(r'[^a-záéíóúüñ0-9]+')).where((e) => e.isNotEmpty);
  String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  List<String> _sentences(String value) => value
      .replaceAll('\r', ' ')
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((e) => e.trim())
      .where((e) => e.length >= 25)
      .toList();
}

class _Hit {
  final int page;
  final String text;
  final double score;
  const _Hit(this.page, this.text, this.score);
}
