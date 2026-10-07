import 'dart:math';

import 'package:flutter/material.dart';

// ── Colores de eventos ──────────────────────────────────────────────
const List<Color> eventColors = [
  Color(0xFFD9622B), // naranja
  Color(0xFF3B62D4), // azul
  Color(0xFF2E7D32), // verde
  Color(0xFF8E24AA), // morado
  Color(0xFFC62828), // rojo
  Color(0xFF00838F), // turquesa
];

const List<String> eventColorNames = [
  'Naranja',
  'Azul',
  'Verde',
  'Morado',
  'Rojo',
  'Turquesa',
];

// ── Nombres en español ──────────────────────────────────────────────
const List<String> weekdayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const List<String> weekdayLong = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const List<String> monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// ── Utilidades de fechas ────────────────────────────────────────────
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Lunes de la semana que contiene [d].
DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday - 1));

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String formatMinutes(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

final Random _rng = Random();

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${_rng.nextInt(9999)}';

// ── Modelos ─────────────────────────────────────────────────────────
class PlannerEvent {
  final String id;
  final String title;
  final String date; // yyyy-MM-dd
  final int startMin; // minutos desde medianoche
  final int endMin;
  final int colorIndex;

  const PlannerEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.colorIndex,
  });

  Color get color => eventColors[colorIndex % eventColors.length];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'startMin': startMin,
        'endMin': endMin,
        'colorIndex': colorIndex,
      };

  factory PlannerEvent.fromJson(Map<String, dynamic> j) => PlannerEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        date: j['date'] as String,
        startMin: (j['startMin'] as num).toInt(),
        endMin: (j['endMin'] as num).toInt(),
        colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
      );
}

class PlannerTask {
  final String id;
  final String title;
  final String date; // yyyy-MM-dd
  final bool done;

  const PlannerTask({
    required this.id,
    required this.title,
    required this.date,
    this.done = false,
  });

  PlannerTask copyWith({bool? done}) => PlannerTask(
        id: id,
        title: title,
        date: date,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'done': done,
      };

  factory PlannerTask.fromJson(Map<String, dynamic> j) => PlannerTask(
        id: j['id'] as String,
        title: j['title'] as String,
        date: j['date'] as String,
        done: j['done'] as bool? ?? false,
      );
}
