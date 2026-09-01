# Compilar Android sin APIs de pago

## Opción A — GitHub Actions

El repositorio incluye `.github/workflows/build-android.yml`.

1. Subir el proyecto a un repositorio de GitHub.
2. Abrir **Actions** → **Build Android APK** → **Run workflow**.
3. Al terminar, descargar el artefacto `lector-academico-android`.
4. Dentro estará `app-release.apk`.

El flujo usa Flutter estable, genera la carpeta Android, ejecuta `flutter analyze` y compila el APK.
No utiliza OpenAI API ni ningún servicio de IA de pago.

> GitHub Actions tiene políticas/cuotas propias. En repositorios públicos, los runners estándar suelen poder usarse sin cobro; en repositorios privados pueden aplicar minutos incluidos o límites de la cuenta.

## Opción B — Computadora local

Requisitos: Flutter estable, Android SDK y Java 17.

```bash
./tool/bootstrap_android.sh
flutter analyze
flutter build apk --release
```

APK esperado:

`build/app/outputs/flutter-apk/app-release.apk`

## Permisos Android

El script agrega:

- `INTERNET`: para detectar conexión y compartir consultas cuando corresponda.
- `RECORD_AUDIO`: para preguntas y marcadores dictados por voz.

La lectura, progreso, biblioteca y marcadores no requieren Internet.
