# Lector Académico — MVP móvil gratuito

Proyecto Flutter pensado primero para Android/iPhone. Su objetivo es escuchar PDF/DOCX durante viajes, mantener siempre visible la página actual, recordar el punto exacto de lectura, permitir preguntas y marcadores por voz o texto, y seguir funcionando cuando desaparece Internet.

## Principio económico

**Costo de uso obligatorio: $0.**

- No usa OpenAI API ni requiere API keys.
- No incorpora servicios cloud de pago obligatorios.
- La lectura, biblioteca, progreso, marcadores y exportación son locales.
- El modo de consulta local actual es extractivo y funciona sin Internet.
- “Enviar a ChatGPT” usa la hoja de compartir del teléfono. El usuario selecciona la app oficial de ChatGPT y utiliza su propia sesión; la aplicación no accede a sus credenciales ni a su cuenta.
- No se incluyen modelos GGUF con licencias o tamaños desconocidos dentro del repositorio. La arquitectura permite añadir posteriormente un LLM local opcional.

## Fases implementadas

1. **Biblioteca multidocumento**: selección múltiple de PDF/DOCX, copia local y progreso independiente.
2. **Preparar para viaje**: selección de uno, varios o todos los documentos. Se verifica que el archivo y el texto por página estén localmente disponibles.
3. **Lectura**: TTS del dispositivo, navegación por oración/página, velocidad y modo karaoke.
4. **Página visible**: “Página X de Y” siempre aparece. Para PDF existe vista de página original sincronizada.
5. **Memoria**: SQLite guarda página, oración, offset, velocidad y porcentaje. Al reabrir, continúa desde el punto guardado.
6. **Online/offline**: el estado de red es informativo; la lectura local no depende de Internet.
7. **Preguntar por voz o texto**: recuperación local de pasajes relevantes en todo el documento, indicando las páginas fuente.
8. **ChatGPT opcional**: la pregunta y el fragmento se pueden compartir a ChatGPT mediante el sistema operativo, sin API.
9. **Marcadores**: voz o texto, categoría, fragmento, página y oración.
10. **Exportación**: listado de marcadores y copia de lectura en PDF con marcadores visibles por página. El original nunca se modifica.

## PDF sin licencias comerciales

El proyecto usa `pdfrx` para visualización/extracción de PDF y `pdf` para crear la copia anotada. Se eliminó `syncfusion_flutter_pdf` para evitar depender de una licencia comercial.

La copia anotada actual reconstruye el contenido textual de cada página e incorpora los marcadores de esa página. No intenta modificar el PDF original ni garantizar una réplica visual exacta de su maquetación. Preservar el diseño original y superponer comentarios físicamente sobre él se considera una mejora posterior.

## IA local

`LocalAiService` funciona sin modelo generativo: localiza las oraciones más relacionadas con la pregunta en todas las páginas extraídas y devuelve los pasajes con números de página. Esto garantiza una función de consulta útil incluso en teléfonos modestos y sin descargar modelos grandes.

La interfaz está separada del motor, por lo que posteriormente puede añadirse un proveedor GGUF/llama.cpp local sin cambiar las pantallas, la base de datos o el sistema de preguntas.

## Crear Android/iOS

En un equipo con Flutter instalado:

```bash
flutter create .
flutter pub get
flutter run
```

Agregar los permisos indicados en `docs/PERMISOS.md`.

## Limitaciones conocidas del MVP

- En DOCX no existe una paginación física universal fuera de Word. Se generan páginas de lectura estables de aproximadamente 3.500 caracteres. Para conservar páginas físicas exactas, el usuario debería trabajar preferiblemente con PDF.
- Los controles multimedia completos desde pantalla bloqueada/Bluetooth requieren integrar una MediaSession/audio service en una siguiente iteración.
- El cambio entre voz cloud y local no se implementa porque la arquitectura de costo cero no usa actualmente una voz cloud de pago. El TTS local garantiza continuidad offline.
- El modo de IA local incluido es recuperación extractiva, no un LLM generativo. Esto es intencional para mantener el MVP pequeño, gratuito y usable sin modelos adicionales.
