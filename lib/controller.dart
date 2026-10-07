import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Guarda todo en el equipo (shared_preferences) y, si Firebase está
/// configurado, lo sincroniza con Firestore usando un "código de sincronización".
class PlannerController extends ChangeNotifier {
  final List<PlannerEvent> events = [];
  final List<PlannerTask> tasks = [];
  final Map<String, String> notes = {};

  int updatedAt = 0;
  String syncCode = '';
  bool cloudEnabled = false;
  String status = 'Solo local';

  SharedPreferences? _prefs;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _pushTimer;

  // ── Inicio ────────────────────────────────────────────────────────
  Future<void> init({required bool firebaseReady}) async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    syncCode = prefs.getString('syncCode') ?? _randomCode();
    await prefs.setString('syncCode', syncCode);

    updatedAt = prefs.getInt('updatedAt') ?? 0;
    final raw = prefs.getString('data');
    if (raw != null) {
      try {
        _loadMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // datos locales dañados: se empieza vacío
      }
    }

    cloudEnabled = firebaseReady;
    if (cloudEnabled) {
      status = 'Conectando...';
      _listen();
    }
    notifyListeners();
  }

  String _randomCode() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ── Consultas ─────────────────────────────────────────────────────
  List<PlannerEvent> eventsOn(DateTime d) {
    final k = dateKey(d);
    return events.where((e) => e.date == k).toList();
  }

  List<PlannerTask> tasksOn(DateTime d) {
    final k = dateKey(d);
    return tasks.where((t) => t.date == k).toList();
  }

  String noteOn(DateTime d) => notes[dateKey(d)] ?? '';

  // ── Cambios ───────────────────────────────────────────────────────
  void saveEvent(PlannerEvent e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _changed();
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _changed();
  }

  void addTask(DateTime day, String title) {
    final t = title.trim();
    if (t.isEmpty) return;
    tasks.add(PlannerTask(id: newId(), title: t, date: dateKey(day)));
    _changed();
  }

  void toggleTask(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i] = tasks[i].copyWith(done: !tasks[i].done);
    _changed();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _changed();
  }

  void setNote(DateTime day, String text) {
    final k = dateKey(day);
    if (text.trim().isEmpty) {
      notes.remove(k);
    } else {
      notes[k] = text;
    }
    _changed();
  }

  // ── Persistencia ──────────────────────────────────────────────────
  Map<String, dynamic> _toMap() => {
        'events': events.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'notes': notes,
      };

  void _loadMap(Map<String, dynamic> m) {
    events
      ..clear()
      ..addAll((m['events'] as List? ?? [])
          .map((e) => PlannerEvent.fromJson(Map<String, dynamic>.from(e as Map))));
    tasks
      ..clear()
      ..addAll((m['tasks'] as List? ?? [])
          .map((t) => PlannerTask.fromJson(Map<String, dynamic>.from(t as Map))));
    notes
      ..clear()
      ..addAll(Map<String, String>.from((m['notes'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), v.toString()))));
  }

  void _changed() {
    updatedAt = DateTime.now().millisecondsSinceEpoch;
    _saveLocal();
    notifyListeners();
    if (cloudEnabled) {
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(milliseconds: 700), _pushCloud);
    }
  }

  Future<void> _saveLocal() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('data', jsonEncode(_toMap()));
    await p.setInt('updatedAt', updatedAt);
  }

  // ── Firebase ──────────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('planners').doc(syncCode);

  void _listen() {
    _sub?.cancel();
    _sub = _doc.snapshots().listen((snap) {
      if (snap.metadata.hasPendingWrites) return;
      final d = snap.data();
      if (d == null) {
        _pushCloud();
        return;
      }
      final remoteAt = (d['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteAt > updatedAt) {
        try {
          _loadMap(jsonDecode(d['json'] as String) as Map<String, dynamic>);
          updatedAt = remoteAt;
          _saveLocal();
          status = 'Sincronizado';
        } catch (_) {
          status = 'Datos de la nube ilegibles';
        }
        notifyListeners();
      } else if (remoteAt < updatedAt) {
        _pushCloud();
      } else {
        status = 'Sincronizado';
        notifyListeners();
      }
    }, onError: (Object e) {
      status = 'Sin conexión a la nube';
      notifyListeners();
    });
  }

  Future<void> _pushCloud() async {
    if (!cloudEnabled) return;
    try {
      status = 'Sincronizando...';
      notifyListeners();
      await _doc.set({
        'json': jsonEncode(_toMap()),
        'updatedAt': updatedAt,
      });
      status = 'Sincronizado';
    } catch (_) {
      status = 'Error al sincronizar';
    }
    notifyListeners();
  }

  /// Cambia el código para enlazar otro dispositivo con los mismos datos.
  Future<void> changeSyncCode(String code) async {
    final c = code.trim().toLowerCase();
    if (c.isEmpty || c == syncCode) return;
    syncCode = c;
    await _prefs?.setString('syncCode', syncCode);
    if (cloudEnabled) {
      status = 'Conectando...';
      _listen();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pushTimer?.cancel();
    super.dispose();
  }
}
