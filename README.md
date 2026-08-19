# AquaFast — App Móvil

Aplicación móvil desarrollada en Flutter para gestionar pedidos de bidones de agua a domicilio en el mercado ecuatoriano.

## Entorno de desarrollo

| Herramienta | Versión |
|---|---|
| Flutter | 3.47.0 |
| Dart | incluido con Flutter |
| Android Studio | Quail 3 2026.1.3 |
| Android SDK | 36.0.0 |
| Emulador | Pixel 6 API 33 (Android 13) |
| Sistema operativo | Windows 11 Home 64-bit |

## Requisitos previos

- Flutter SDK instalado en `C:\flutter`
- Android Studio con Android SDK instalado
- Emulador Android configurado (API 33)
- Backend AquaFast corriendo en `http://localhost:3000`

## Pasos para configurar el entorno

**1. Verificar Flutter**
```bash
flutter doctor
```

**2. Instalar dependencias**
```bash
flutter pub get
```

**3. Ejecutar la app**
```bash
flutter run
```

## Conexión con el backend

La app se comunica con el backend mediante HTTP. En el emulador Android se usa la dirección `10.0.2.2` para apuntar al `localhost` de la computadora host.

```dart
final String baseUrl = 'http://10.0.2.2:3000';
```

## Dependencias principales

- `http: ^1.6.0` — solicitudes HTTP hacia la API REST
- `flutter_dotenv: ^6.0.1` — manejo de variables de entorno

## Verificación del entorno

Ejecutar `flutter doctor` debe mostrar sin hallazgos pendientes para Android:

```
[✓] Flutter (Channel stable, 3.47.0)
[✓] Android toolchain
[✓] Chrome
[✓] Connected device
```