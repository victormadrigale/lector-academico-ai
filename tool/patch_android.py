from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()
permissions = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.RECORD_AUDIO" />',
]
for permission in permissions:
    if permission not in text:
        text = text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission)
manifest.write_text(text)

# Give the app a user-facing Spanish name.
if 'android:label="lector_academico_ai"' in text:
    text = manifest.read_text().replace('android:label="lector_academico_ai"', 'android:label="Lector Académico"')
    manifest.write_text(text)

# Android 11+ must be able to discover installed TTS services.
text = manifest.read_text()
if 'android.intent.action.TTS_SERVICE' not in text:
    queries = """
    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
"""
    text = text.replace('    <application', queries + '    <application')
    manifest.write_text(text)
