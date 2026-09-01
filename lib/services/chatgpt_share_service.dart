import 'package:share_plus/share_plus.dart';

/// No usa API ni credenciales. Abre la hoja de compartir del sistema para que
/// el usuario elija ChatGPT (si está instalado) y use su propia sesión.
class ChatGptShareService {
  Future<void> sharePrompt(String prompt) async {
    await SharePlus.instance.share(
      ShareParams(
        text: prompt,
        subject: 'Consulta académica para ChatGPT',
      ),
    );
  }
}
