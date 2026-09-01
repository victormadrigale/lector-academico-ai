# Estado v0.3

## Mejoras incorporadas

- Reanudación por documento, página, oración y posición dentro de la oración.
- Karaoke con oración activa y palabra activa cuando TTS entrega offsets.
- Auto-seguimiento del bloque activo en pantalla.
- Biblioteca multidocumento y preparación offline múltiple.
- Preguntas por voz y texto.
- Consulta local extractiva sin API.
- Envío opcional de la consulta a ChatGPT mediante hoja de compartir del sistema.
- Marcadores por voz y texto, ligados a página y fragmento.
- Exportación de marcadores y copia PDF de lectura anotada.
- Flujo reproducible para generar APK con GitHub Actions.
- Sin OpenAI API ni SDK PDF comercial.

## Aún requiere prueba en dispositivo real

- Comportamiento TTS específico de cada fabricante Android.
- Reconocimiento de voz offline según paquetes de idioma instalados.
- Controles de pantalla bloqueada/Bluetooth.
- Integración de un LLM local generativo GGUF opcional.
- Validación con PDFs escaneados sin capa de texto (OCR aún no incluido).
