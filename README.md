# EasyNotes Planner (web)

Página web con **planner semanal por horas**, **tareas con casillas**, **notas por día** y **eventos con colores**. Funciona en el navegador del celular y del computador, se puede instalar como app y guarda todo en tu dispositivo. Con Firebase (opcional) sincroniza entre dispositivos.

No necesitas instalar nada: son archivos HTML, CSS y JavaScript que GitHub Pages publica gratis.

## Cómo usarla

- **Horario:** la cuadrícula va de 6 AM a 12 AM (medianoche) y las horas se muestran en formato AM/PM. Un evento que termina antes de las 6 AM no sale en la cuadrícula, pero sí en el panel del día.
- **Semana:** en el celular se ven los 7 días de la semana a la vez; desliza hacia arriba o abajo para recorrer las horas. Toca un hueco de la cuadrícula para crear un evento a esa hora, o toca un evento para editarlo o eliminarlo.
- **Botón +:** crea un evento en el día seleccionado.
- **Día:** toca el encabezado de un día y abre la pestaña **Día** para ver sus eventos, tareas y notas.
- `Hoy`, `‹` y `›` mueven la semana.
- **Tema:** el botón de la luna/sol (arriba a la derecha) cambia entre tema claro y oscuro. La primera vez usa el tema de tu teléfono o computador, y después recuerda tu elección en ese dispositivo.
- **Nube** (arriba a la derecha): muestra el estado de sincronización y tu código.

En el celular verás dos pestañas abajo (Semana y Día). En un computador o tableta se ve la semana a la izquierda y el panel del día a la derecha.

## Alarmas y avisos

Al crear o editar un evento eliges el **Aviso**: sin aviso, al empezar, o 5, 10, 15, 30 minutos o 1 hora antes. Los eventos nuevos traen 10 minutos por defecto. Los eventos que ya tenías quedan sin aviso hasta que los edites.

**Dentro de la app** la alarma muestra una ventana con el nombre del evento, suena, vibra (en el celular) y tiene dos botones: **Posponer 5 min** y **Descartar**. Si la app está en segundo plano, además sale una notificación del sistema, y al tocarla se abre la app. La primera vez que guardes un evento con aviso, el navegador te pedirá permiso para mostrar notificaciones: acéptalo.

Usa **Probar alarma** en el formulario del evento para oír y ver cómo suena, y para dar el permiso de notificaciones sin esperar.

**Importante:** una página web no puede hacer sonar una alarma si la app está cerrada del todo, porque eso requiere un servidor de pago. Por eso el formulario del evento tiene dos botones para llevarlo al calendario del teléfono, que sí suena con la app cerrada:

- **Google Calendar:** abre Google Calendar (o su app) con el evento ya rellenado: título, día y hora. Solo toca **Guardar** allá. Este enlace no puede fijar el aviso, así que el evento usa el aviso predeterminado de tu calendario; en la descripción queda anotado el aviso que elegiste.
- **Archivo .ics:** descarga un archivo que, al abrirlo, mete el evento con su aviso en otros calendarios (Samsung, Apple, Outlook...). Algunos teléfonos no lo importan solos; si no pasa nada, usa el botón de Google Calendar.

Detalles:
- Cada dispositivo suena por su cuenta. Si tienes la app abierta en el celular y en el computador, sonará en los dos.
- En el iPhone, las notificaciones solo funcionan si instalaste la app en la pantalla de inicio (iOS 16.4 o más reciente). Para alarmas con la app cerrada, usa el calendario.
- Si el navegador bloqueó las notificaciones, el aviso se verá y sonará solo dentro de la app. Para volver a permitirlas, toca el candado junto a la dirección de la página → Permisos.
- Una alarma que se pasó mientras la app estaba cerrada no suena después: solo suenan las que tocan en ese momento o hasta 5 minutos tarde.

## 1. Publicarla con GitHub Pages

1. En tu repositorio `easynotes-planner` entra a **Settings → Pages**.
2. En **Source** deja **Deploy from a branch**.
3. En **Branch** elige **main** y la carpeta **/ (root)**, y pulsa **Save**.
4. Espera 1 o 2 minutos. Tu página quedará en:

```
https://royherrera09.github.io/easynotes-planner/
```

## 2. Instalarla en el celular

- **Android (Chrome):** abre la dirección, pulsa el menú ⋮ y elige **Instalar app** (o **Añadir a la pantalla de inicio**).
- **iPhone (Safari):** abre la dirección, pulsa el botón de compartir y elige **Añadir a pantalla de inicio**.

Queda con su ícono, se abre a pantalla completa y funciona aunque no haya internet.

## 3. Dónde se guardan los datos

Por defecto, **en el navegador de cada dispositivo**. Eso significa que el celular y el computador no comparten datos, y que si borras los datos del navegador, se pierden. Para compartirlos y tener copia en la nube, activa Firebase.

## 4. Activar Firebase (sincronización)

1. Entra a https://console.firebase.google.com y crea un proyecto (por ejemplo `easynotes-planner`).
2. En el proyecto: **Build → Firestore Database → Create database**. Elige una región cercana y empieza en modo de prueba.
3. Registra la app web: en **Project settings** (el engranaje) → pestaña **General** → sección **Your apps** → ícono web `</>`. Ponle un nombre y registra la app (no marques Firebase Hosting).
4. Firebase te muestra un bloque `firebaseConfig`. Cópialo.
5. Abre el archivo `firebase-config.js` y reemplaza `window.FIREBASE_CONFIG = null;` por:

```js
window.FIREBASE_CONFIG = {
  apiKey: "...",
  authDomain: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "..."
};
```

6. Guarda y sube el cambio a GitHub (ver sección 6). Cuando Pages se actualice, la nube de la esquina debe ponerse verde y decir **Sincronizado**.

### Reglas de Firestore

El modo de prueba caduca a los 30 días. Para que siga funcionando, en **Firestore → Rules** usa:

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

Las claves de `firebaseConfig` no son secretas por sí solas, porque van en cualquier página web que use Firebase. La protección real está en las reglas de Firestore.

### Enlazar otro dispositivo

Pulsa la nube, copia tu código y escríbelo en el otro dispositivo con **Usar este código**. Ese dispositivo debe estar vacío o ser el más antiguo, porque gana la versión editada más recientemente.

## 5. Probarla en tu computador (opcional)

Abre `index.html` con doble clic y ya funciona, aunque el modo sin conexión y la instalación solo se activan desde la dirección de GitHub Pages.

## 6. Subir cambios a GitHub

Dentro de la carpeta del proyecto, en Git Bash:

```
git add .
git commit -m "descripción del cambio"
git push
```

La página se actualiza sola en 1 o 2 minutos. Si no ves el cambio, recarga con `Ctrl + F5` (en el celular, cierra y vuelve a abrir la app).

## Estructura

```
index.html            Estructura de la página
styles.css            Estilos (celular y escritorio)
app.js                Lógica: semana, tareas, notas, eventos, sincronización
firebase-config.js    Aquí pegas la configuración de Firebase
manifest.webmanifest  Datos para instalarla como app
sw.js                 Permite abrirla sin conexión
icons/                Íconos de la app
.nojekyll             Le dice a GitHub Pages que sirva los archivos tal cual
```

## Historial

La primera versión de este proyecto fue una app de Flutter. Sigue guardada en el historial de Git (commit `6538504`), por si algún día quieres volver a ella.

## Ideas para después

- Arrastrar eventos para moverlos o cambiar su duración.
- Eventos repetidos (semanales) y recordatorios.
- Autenticación con Firebase para proteger los datos.
- Integrar el editor de notas y PDF de NoteCanvas.
