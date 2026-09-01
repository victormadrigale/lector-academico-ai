# 0.3.0

- Reanudación dentro de la oración mediante `current_char_offset`.
- Karaoke con resaltado de palabra activa y auto-seguimiento.
- Flujo de compilación Android reproducible con GitHub Actions.
- Script de bootstrap Android y permisos de micrófono/Internet.
- Ajustes de robustez para DOCX y tipos numéricos.

# Changelog

## 0.2.0
- Eliminada por completo la OpenAI API y cualquier API key.
- Eliminado `syncfusion_flutter_pdf` para respetar el requisito de costo cero.
- Migración PDF a `pdfrx` (visor y extracción) y `pdf` (copia anotada).
- Añadido `LocalAiService`: consulta extractiva local a todo el documento con páginas fuente.
- Añadido “Enviar a ChatGPT” mediante hoja de compartir del sistema, usando la sesión personal del usuario en la app oficial.
- “Preparar para viaje” admite selección múltiple y toda la biblioteca.
- Verificación real de archivo local + texto de todas las páginas.
- La página actual sigue siendo estado persistente principal.
- Añadida política explícita `docs/COSTO_CERO.md`.
