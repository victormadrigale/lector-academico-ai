# Validación necesaria en dispositivo

Este repositorio no se ha compilado dentro del entorno de generación porque aquí no está instalado Flutter/Android SDK/Xcode.

Al abrirlo en una máquina con Flutter, ejecutar en este orden:

1. `flutter create .`
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test`
5. `flutter run` en Android físico.
6. Importar un PDF de 100+ páginas.
7. Cerrar/reabrir y verificar reanudación exacta.
8. Activar modo avión durante lectura y comprobar continuidad.
9. Preparar 5+ documentos simultáneamente.
10. Crear marcadores por texto y voz y exportar copia anotada.
11. Preguntar offline y comprobar páginas fuente.
12. Usar “Enviar a ChatGPT” y seleccionar ChatGPT en la hoja de compartir.

## Integraciones de producción aún pendientes
- MediaSession/audio_service para controles de pantalla bloqueada y Bluetooth.
- Modelo GGUF generativo opcional, después de medir RAM/velocidad en teléfonos reales.
- Superposición visual de marcadores sobre la maquetación original del PDF; la v0.2 genera una copia textual anotada por páginas.
- Pruebas específicas iOS.
