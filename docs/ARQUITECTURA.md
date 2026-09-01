# Arquitectura funcional v0.2

## Reglas principales

1. **Estado y contenido local-first.**
2. **Lectura nunca depende de Internet.**
3. **Costo obligatorio de uso: $0.**
4. **Página física del PDF siempre identificable.**
5. **Cada documento mantiene su progreso independiente.**
6. **El original nunca se modifica.**

## Estado persistente por documento

- archivo local
- extensión
- total de páginas
- página actual
- oración actual
- offset actual
- porcentaje
- velocidad
- estado “preparado offline”
- fecha de última lectura
- marcadores vinculados a página/oración/fragmento

## Flujo de lectura

1. Abrir documento.
2. Recuperar página/oración guardadas.
3. Mostrar “Página X de Y”.
4. Leer oración con TTS local.
5. Resaltar oración activa (karaoke).
6. Guardar progreso en pausa, salto y mediante debounce.
7. Cambiar de página automáticamente.

## Preparar para viaje

Se puede seleccionar uno, varios o toda la biblioteca. Para cada documento se valida:

- archivo presente en almacenamiento local;
- texto extraído de todas las páginas;
- estado persistente disponible;
- TTS local del sistema disponible en el dispositivo.

## Preguntas

### Modo local obligatorio

`LocalAiService` recupera pasajes relevantes en todas las páginas usando coincidencia léxica ponderada. Devuelve siempre los números de página. No usa Internet.

### ChatGPT opcional

`ChatGptShareService` crea un prompt con título, página, fragmento y pregunta y lo envía a la hoja de compartir del sistema. El usuario puede elegir ChatGPT y usar la sesión personal de la aplicación oficial. No hay OAuth privado, lectura de cuenta ni API key.

### Evolución futura

La interfaz permite añadir un `LocalLlmProvider` basado en GGUF/llama.cpp. El modelo sería opcional y descargable por el usuario, sujeto a compatibilidad del teléfono y licencia del modelo.

## Exportación

- TXT con marcadores.
- PDF “copia de lectura anotada”, generado localmente desde el texto extraído y los marcadores por página.
- El archivo fuente queda intacto.

## Conectividad

La UI puede mostrar Online/Offline, pero el reproductor no cambia de estado por una pérdida de red. Si futuras mejoras online se añaden, deberán degradarse silenciosamente a la capacidad local.
