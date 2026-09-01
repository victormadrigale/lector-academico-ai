# Permisos móviles

## Android
Agregar según la versión/plantilla de Flutter:
- `android.permission.INTERNET`
- `android.permission.RECORD_AUDIO` para preguntas/marcadores por voz.
- Permisos de notificación/media si se integra reproducción real en background con MediaSession.

Los archivos se eligen mediante el selector del sistema; no se requiere pedir acceso indiscriminado al almacenamiento.

## iOS
Agregar a `Info.plist`:
- `NSMicrophoneUsageDescription`: "Usamos el micrófono para preguntas y marcadores por voz."
- `NSSpeechRecognitionUsageDescription`: "Usamos reconocimiento de voz para convertir tus preguntas y notas en texto."

Para audio real con pantalla apagada, habilitar Background Modes > Audio y configurar una sesión de audio apropiada.
