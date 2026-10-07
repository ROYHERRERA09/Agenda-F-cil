// ARCHIVO PROVISIONAL.
//
// Mientras no configures Firebase, la app funciona solo con datos locales.
// Cuando ejecutes `flutterfire configure` (ver README.md), este archivo se
// reemplaza automáticamente por el real y la sincronización se activa sola.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase aún no está configurado. Ejecuta: flutterfire configure',
    );
  }
}
