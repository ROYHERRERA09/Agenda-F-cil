# EasyNotes Planner (Android e iOS)

App de Flutter para teléfono con **planner semanal por horas**, **tareas con casillas**, **notas por día** y **eventos con colores**. Guarda todo en el teléfono y, si configuras Firebase, lo sincroniza con la nube. El mismo código sirve para Android e iOS.

## Cómo usarla

- **Semana:** desliza de lado para ver los 7 días. Toca un hueco para crear un evento a esa hora, o un evento para editarlo.
- **Botón +:** crea un evento en el día seleccionado.
- **Día:** toca el encabezado de un día en Semana y luego abre la pestaña Día para ver sus eventos, tareas y notas.
- `Hoy`, `‹` y `›` mueven la semana.
- La nube (arriba a la derecha) muestra el estado de sincronización y tu código.

En una tableta o pantalla ancha se ve la semana completa y el panel del día lado a lado.

## Qué necesitas según la plataforma

| | Android | iOS |
|---|---|---|
| Computador | Windows, Mac o Linux | **Solo Mac** |
| Herramienta | Android Studio (SDK de Android) | Xcode + CocoaPods |
| Cuenta | Ninguna | Apple ID (gratis para probar en tu iPhone; Apple Developer de pago, unos 99 USD al año, para TestFlight o App Store) |

Apple no permite compilar apps de iPhone desde Windows. Si solo tienes Windows, puedes usar un servicio de compilación en la nube (por ejemplo Codemagic) o pedir prestado un Mac. Android sí lo puedes hacer todo desde Windows.

## 1. Preparar el proyecto

Dentro de esta carpeta, genera las carpetas de las plataformas que uses:

```
flutter create --platforms=android,ios .
flutter pub get
```

`flutter create .` solo agrega `android/` e `ios/`; no toca tu código. Puedes borrar la carpeta `test/` que genera, porque apunta a una app de ejemplo que ya no existe. Si solo usas una plataforma, deja solo esa en `--platforms`.

### Ajustes de Android

**a) Versión mínima.** En `android/app/build.gradle.kts` (o `build.gradle` en proyectos antiguos) cambia `minSdk` a 23:

```
minSdk = 23
```

Si ves `minSdk = flutter.minSdkVersion`, reemplázalo por `minSdk = 23`.

**b) Permiso de internet.** En `android/app/src/main/AndroidManifest.xml` agrega esta línea dentro de `<manifest>`, antes de `<application>`:

```
<uses-permission android:name="android.permission.INTERNET"/>
```

Sin esto la app funciona en modo debug pero no sincroniza cuando la instalas como versión final.

Para correrla: conecta el teléfono con **depuración USB** activada (o abre un emulador) y ejecuta `flutter devices` y luego `flutter run`.

### Ajustes de iOS (en el Mac)

**a) Versión mínima.** Abre `ios/Podfile` y asegúrate de que la primera línea útil diga (quita el `#` si está comentada):

```
platform :ios, '13.0'
```

Firebase exige iOS 13 o superior. Si más adelante `pod install` pide una versión mayor, usa esa.

**b) Firma.** Abre `ios/Runner.xcworkspace` con Xcode (el `.xcworkspace`, no el `.xcodeproj`). En **Runner → Signing & Capabilities**:

- Elige tu **Team** (tu Apple ID personal sirve para probar).
- Cambia el **Bundle Identifier** por uno único, por ejemplo `com.tunombre.easynotesplanner`.

Usa el mismo identificador cuando ejecutes `flutterfire configure` en el paso 2.

**c) Correrla.**

- Simulador: `open -a Simulator` y luego `flutter run`.
- iPhone real: conéctalo, desbloquéalo y confía en el Mac. Ejecuta `flutter run`. La primera vez, en el iPhone ve a **Ajustes → General → VPN y gestión de dispositivos** y confía en tu perfil de desarrollador. Con Apple ID gratis, la app caduca a los 7 días y hay que volver a instalarla.

La primera compilación con Firebase en iOS tarda varios minutos porque descarga y compila los pods. Es normal. Si falla con errores de CocoaPods, prueba:

```
cd ios
pod repo update
pod install
cd ..
```

Sin Firebase configurado, la app ya funciona y guarda los datos en el teléfono.

## 2. Activar Firebase (sincronización)

1. Entra a https://console.firebase.google.com y crea un proyecto (por ejemplo `easynotes-planner`).
2. En el proyecto: **Build → Firestore Database → Create database**. Elige una región cercana y empieza en modo de prueba.
3. Instala las herramientas (una sola vez; necesitas Node.js):

```
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```

4. En la carpeta del proyecto:

```
flutterfire configure
```

   Elige tu proyecto y marca **android** y/o **ios**. Esto reemplaza `lib/firebase_options.dart` por el archivo real y agrega `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist`.

5. Ejecuta de nuevo `flutter run`. La nube debe mostrarse en verde (**Sincronizado**).

Si en Android el build se queja de `google-services`, revisa que el plugin esté aplicado: `flutterfire configure` normalmente lo agrega solo, pero en algunos proyectos hay que añadir `id("com.google.gms.google-services")` en `android/app/build.gradle.kts` y la versión del plugin en `android/settings.gradle.kts`. La guía oficial está en https://firebase.google.com/docs/flutter/setup.

### Reglas de Firestore

El modo de prueba caduca a los 30 días. Para que siga funcionando, en **Firestore → Reglas** usa:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /planners/{code} {
      allow read, write: if true;
    }
  }
}
```

Ojo con esto: la app no usa cuentas de usuario. Cada persona se identifica solo con su **código de sincronización** (10 caracteres al azar), así que quien conozca el código puede leer y editar esos datos. Está bien para uso personal. Si algún día la compartes con otras personas, el siguiente paso es agregar Firebase Authentication y restringir las reglas por usuario.

### Enlazar otro dispositivo (también entre Android e iPhone)

Abre la nube, copia tu código y escríbelo en el otro dispositivo con **Usar este código**. Ese dispositivo debe estar vacío o ser el más antiguo, porque gana la versión editada más recientemente.

## 3. Instalarla como app normal

**Android:** `flutter build apk --release` deja el archivo en `build/app/outputs/flutter-apk/app-release.apk`. Cópialo al teléfono y ábrelo (Android te pedirá permitir instalar apps de esa fuente), o usa `flutter install` con el teléfono conectado.

**iOS:** `flutter build ipa` genera el paquete para subir a TestFlight o App Store, y necesita la cuenta de pago de Apple Developer. Para uso personal sin pagar, basta con `flutter run --release` en tu iPhone conectado (caduca a los 7 días).

## 4. Subirla a GitHub

Este proyecto ya viene con Git inicializado y el primer commit hecho en la rama `main`. Solo falta conectarlo a tu repositorio:

1. Crea un repositorio **vacío** en https://github.com/new con el nombre `easynotes-planner`. No marques README, .gitignore ni licencia.
2. Abre una terminal dentro de la carpeta del proyecto. En Windows: clic derecho en un espacio vacío de la carpeta y elige **Git Bash Here** (o **Abrir en Terminal** en Windows 11).
3. Escribe estos dos comandos, uno por uno:

```
git remote add origin https://github.com/royherrera09/easynotes-planner.git
git push -u origin main
```

GitHub te pedirá iniciar sesión (o un token si tienes verificación en dos pasos).

Para guardar cambios más adelante:

```
git add .
git commit -m "descripción del cambio"
git push
```

Notas:

- El `.gitignore` ya excluye `build/`, `.dart_tool/`, `pubspec.lock` y los archivos de CocoaPods.
- `lib/firebase_options.dart`, `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist` contienen claves de cliente de Firebase. No son secretas por sí solas (la seguridad real está en las reglas de Firestore), pero si el repositorio es público conviene tener las reglas bien puestas.
- Nunca subas un archivo `.jks`, `key.properties` ni certificados o perfiles de Apple (`.p12`, `.mobileprovision`).

## Estructura

```
lib/
  main.dart              Arranque, tema, inicialización de Firebase
  models.dart            Eventos, tareas y utilidades de fechas
  controller.dart        Estado, guardado local y sincronización
  planner_screen.dart    Pantalla: semana por horas, panel del día, diálogos
  firebase_options.dart  Provisional hasta ejecutar flutterfire configure
```

## Ideas para después

- Arrastrar eventos para moverlos o cambiar su duración.
- Eventos repetidos (semanales) y recordatorios con notificación.
- Autenticación con Firebase para proteger los datos.
- Integrar el editor de notas y PDF de NoteCanvas dentro de esta app.
