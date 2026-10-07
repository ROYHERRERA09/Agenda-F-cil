import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'firebase_options.dart';
import 'planner_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si Firebase no está configurado todavía, la app sigue funcionando en local.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  final controller = PlannerController();
  await controller.init(firebaseReady: firebaseReady);

  runApp(EasyNotesApp(controller: controller));
}

class EasyNotesApp extends StatelessWidget {
  final PlannerController controller;
  const EasyNotesApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyNotes Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: accent,
        scaffoldBackgroundColor: paper,
        dividerColor: line,
      ),
      home: PlannerScreen(controller: controller),
    );
  }
}
