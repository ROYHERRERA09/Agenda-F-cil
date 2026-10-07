import 'dart:math';

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';

// ── Estilo (mismo aire cálido que NoteCanvas) ───────────────────────
const Color accent = Color(0xFFD9622B);
const Color paper = Color(0xFFF6F3EE);
const Color card = Color(0xFFFFFFFF);
const Color ink = Color(0xFF1C1B18);
const Color muted = Color(0xFF8A857B);
const Color line = Color(0xFFE6E1D8);

const double hourH = 56;
const double gutterW = 54;

class PlannerScreen extends StatefulWidget {
  final PlannerController controller;
  const PlannerScreen({super.key, required this.controller});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _weekStart = startOfWeek(DateTime.now());
  late DateTime _selected = dateOnly(DateTime.now());
  final ScrollController _scroll = ScrollController(initialScrollOffset: 7 * hourH);

  // Modo teléfono: pestaña activa (0 = Semana, 1 = Día) y ancho de cada día.
  int _tab = 0;
  static const double _phoneColW = 112;
  final ScrollController _hScroll = ScrollController(
    initialScrollOffset: (DateTime.now().weekday - 1) * _phoneColW,
  );

  PlannerController get c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  String get _rangeLabel {
    final a = _weekStart;
    final b = addDays(a, 6);
    final mA = monthNames[a.month - 1];
    final mB = monthNames[b.month - 1];
    if (a.month == b.month) return '${a.day} – ${b.day} de $mB de ${b.year}';
    return '${a.day} de ${mA.substring(0, 3)} – ${b.day} de ${mB.substring(0, 3)} de ${b.year}';
  }

  void _goToWeek(DateTime anyDay) {
    setState(() {
      _weekStart = startOfWeek(anyDay);
      _selected = dateOnly(anyDay);
    });
  }

  void _shiftWeek(int n) {
    setState(() {
      _weekStart = addDays(_weekStart, 7 * n);
      _selected = addDays(_selected, 7 * n);
    });
  }

  Future<void> _openEventDialog(PlannerEvent? existing, DateTime day, int startMin) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EventDialog(
        existing: existing,
        day: day,
        startMin: startMin,
        onSave: c.saveEvent,
        onDelete: c.deleteEvent,
      ),
    );
  }

  Future<void> _openSyncDialog() {
    return showDialog<void>(
      context: context,
      builder: (_) => _SyncDialog(controller: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, box) {
          return box.maxWidth >= 900 ? _tabletLayout() : _phoneLayout();
        });
      },
    );
  }

  Widget _dayPanel(EdgeInsets margin) => _DayPanel(
        key: ValueKey(dateKey(_selected)),
        controller: c,
        day: _selected,
        margin: margin,
        onEditEvent: (e) => _openEventDialog(e, parseKey(e.date), e.startMin),
      );

  /// Pantallas anchas (tableta): semana a la izquierda y panel del día a la derecha.
  Widget _tabletLayout() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _weekCard()),
                  SizedBox(width: 330, child: _dayPanel(const EdgeInsets.fromLTRB(0, 12, 12, 12))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teléfono: barra compacta, pestañas Semana / Día y botón + para eventos.
  Widget _phoneLayout() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _compactTopBar(),
            const Divider(height: 1),
            Expanded(
              child: IndexedStack(
                index: _tab,
                sizing: StackFit.expand,
                children: [
                  _weekCard(fixedColW: _phoneColW),
                  _dayPanel(const EdgeInsets.all(12)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        tooltip: 'Nuevo evento',
        onPressed: () => _openEventDialog(null, _selected, 9 * 60),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: 'Semana',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Día',
          ),
        ],
      ),
    );
  }

  // ── Barra superior ────────────────────────────────────────────────
  Widget _topBar() {
    final synced = c.cloudEnabled && c.status == 'Sincronizado';
    return Container(
      color: card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
              children: [
                TextSpan(text: 'Easy'),
                TextSpan(text: 'Notes', style: TextStyle(color: accent)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Semana anterior',
            onPressed: () => _shiftWeek(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          OutlinedButton(
            onPressed: () => _goToWeek(DateTime.now()),
            child: const Text('Hoy'),
          ),
          IconButton(
            tooltip: 'Semana siguiente',
            onPressed: () => _shiftWeek(1),
            icon: const Icon(Icons.chevron_right),
          ),
          Text(
            _rangeLabel,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => _openEventDialog(null, _selected, 9 * 60),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo evento'),
          ),
          TextButton.icon(
            onPressed: _openSyncDialog,
            icon: Icon(
              synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              size: 18,
              color: synced ? const Color(0xFF2E7D32) : muted,
            ),
            label: Text(
              c.status,
              style: TextStyle(color: synced ? const Color(0xFF2E7D32) : muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra superior compacta (teléfono) ────────────────────────────
  Widget _compactTopBar() {
    final synced = c.cloudEnabled && c.status == 'Sincronizado';
    return Container(
      color: card,
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Column(
        children: [
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
                  children: [
                    TextSpan(text: 'Easy'),
                    TextSpan(text: 'Notes', style: TextStyle(color: accent)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: c.status,
                onPressed: _openSyncDialog,
                icon: Icon(
                  synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: synced ? const Color(0xFF2E7D32) : muted,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Semana anterior',
                onPressed: () => _shiftWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              OutlinedButton(
                onPressed: () => _goToWeek(DateTime.now()),
                child: const Text('Hoy'),
              ),
              IconButton(
                tooltip: 'Semana siguiente',
                onPressed: () => _shiftWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _rangeLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Calendario semanal ────────────────────────────────────────────
  Widget _weekCard({double? fixedColW}) {
    final days = List.generate(7, (i) => addDays(_weekStart, i));
    final content = Column(
        children: [
          // Encabezado de días
          Row(
            children: [
              const SizedBox(width: gutterW),
              for (final d in days) Expanded(child: _dayHeader(d)),
            ],
          ),
          const Divider(height: 1),
          // Cuadrícula por horas
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: SizedBox(
                height: 24 * hourH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: gutterW, child: _timeGutter()),
                    for (final d in days) Expanded(child: _dayColumn(d)),
                  ],
                ),
              ),
            ),
          ),
        ],
    );
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: fixedColW == null
          ? content
          : SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: gutterW + 7 * fixedColW, child: content),
            ),
    );
  }

  Widget _dayHeader(DateTime d) {
    final isToday = sameDay(d, DateTime.now());
    final isSel = sameDay(d, _selected);
    final pending = c.tasksOn(d).where((t) => !t.done).length;
    return InkWell(
      onTap: () => setState(() => _selected = d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: isSel ? accent.withAlpha(18) : Colors.transparent,
        child: Column(
          children: [
            Text(
              weekdayShort[d.weekday - 1].toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isToday ? accent : muted,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday ? accent : Colors.transparent,
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.white : ink,
                ),
              ),
            ),
            SizedBox(
              height: 14,
              child: pending > 0
                  ? Text('$pending ${pending == 1 ? 'tarea' : 'tareas'}',
                      style: const TextStyle(fontSize: 10, color: muted))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeGutter() {
    return Stack(
      children: [
        for (var h = 1; h < 24; h++)
          Positioned(
            top: h * hourH - 7,
            left: 0,
            right: 6,
            child: Text(
              formatMinutes(h * 60),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _dayColumn(DateTime day) {
    final isSel = sameDay(day, _selected);
    final isToday = sameDay(day, DateTime.now());
    final placed = _layout(c.eventsOn(day));
    final now = DateTime.now();
    final nowTop = (now.hour * 60 + now.minute) / 60 * hourH;

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final hour = (d.localPosition.dy / hourH).floor().clamp(0, 23);
          setState(() => _selected = day);
          _openEventDialog(null, day, hour * 60);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSel ? accent.withAlpha(10) : Colors.transparent,
            border: const Border(left: BorderSide(color: line)),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var h = 0; h < 24; h++)
                Positioned(
                  top: h * hourH,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: const ColoredBox(color: line),
                ),
              for (final p in placed) _eventBlock(p, w),
              if (isToday)
                Positioned(
                  top: nowTop - 1,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: const ColoredBox(color: Color(0xFFE53935)),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _eventBlock(_Placed p, double colWidth) {
    final e = p.event;
    final top = e.startMin / 60 * hourH + 1;
    final height = max(20.0, (e.endMin - e.startMin) / 60 * hourH - 2);
    final laneW = colWidth / p.lanes;
    return Positioned(
      top: top,
      height: height,
      left: laneW * p.lane + 2,
      width: max(10.0, laneW - 4),
      child: GestureDetector(
        onTap: () {
          setState(() => _selected = parseKey(e.date));
          _openEventDialog(e, parseKey(e.date), e.startMin);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: e.color.withAlpha(45),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: e.color, width: 3)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: e.color),
              ),
              if (height > 34)
                Text(
                  '${formatMinutes(e.startMin)} – ${formatMinutes(e.endMin)}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reparte en carriles los eventos que se solapan para que se vean uno al lado del otro.
  List<_Placed> _layout(List<PlannerEvent> evs) {
    evs.sort((a, b) => a.startMin.compareTo(b.startMin));
    final result = <_Placed>[];
    var cluster = <_Placed>[];
    var clusterEnd = -1;

    void flush() {
      final n = cluster.fold<int>(0, (m, p) => max(m, p.lane + 1));
      for (final p in cluster) {
        p.lanes = n;
      }
      result.addAll(cluster);
      cluster = <_Placed>[];
      clusterEnd = -1;
    }

    for (final e in evs) {
      if (cluster.isNotEmpty && e.startMin >= clusterEnd) flush();
      var lane = 0;
      while (cluster.any((p) => p.lane == lane && p.event.endMin > e.startMin)) {
        lane++;
      }
      cluster.add(_Placed(e, lane));
      clusterEnd = max(clusterEnd, e.endMin);
    }
    flush();
    return result;
  }
}

class _Placed {
  final PlannerEvent event;
  final int lane;
  int lanes = 1;
  _Placed(this.event, this.lane);
}

// ═══════════════════════════════════════════════════════════════════
//  Panel del día: eventos, tareas con casillas y notas
// ═══════════════════════════════════════════════════════════════════
class _DayPanel extends StatefulWidget {
  final PlannerController controller;
  final DateTime day;
  final void Function(PlannerEvent) onEditEvent;
  final EdgeInsets margin;

  const _DayPanel({
    super.key,
    required this.controller,
    required this.day,
    required this.onEditEvent,
    required this.margin,
  });

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  late final TextEditingController _noteCtl =
      TextEditingController(text: widget.controller.noteOn(widget.day));
  final TextEditingController _taskCtl = TextEditingController();

  @override
  void dispose() {
    _noteCtl.dispose();
    _taskCtl.dispose();
    super.dispose();
  }

  void _addTask() {
    widget.controller.addTask(widget.day, _taskCtl.text);
    _taskCtl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final d = widget.day;
    final evs = c.eventsOn(d)..sort((a, b) => a.startMin.compareTo(b.startMin));
    final tasks = c.tasksOn(d);

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 72),
        children: [
          Text(
            weekdayLong[d.weekday - 1],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
          ),
          Text(
            '${d.day} de ${monthNames[d.month - 1]} de ${d.year}',
            style: const TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Eventos'),
          if (evs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('Sin eventos. Toca la cuadrícula para crear uno.',
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
          for (final e in evs)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => widget.onEditEvent(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatMinutes(e.startMin)} – ${formatMinutes(e.endMin)}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: ink)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          _sectionTitle('Tareas'),
          for (final t in tasks)
            Row(
              children: [
                Checkbox(
                  value: t.done,
                  activeColor: accent,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => c.toggleTask(t.id),
                ),
                Expanded(
                  child: Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: t.done ? muted : ink,
                      decoration: t.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar tarea',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  color: muted,
                  onPressed: () => c.deleteTask(t.id),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          TextField(
            controller: _taskCtl,
            onSubmitted: (_) => _addTask(),
            decoration: InputDecoration(
              hintText: 'Nueva tarea...',
              isDense: true,
              prefixIcon: const Icon(Icons.add, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Agregar',
                onPressed: _addTask,
                icon: const Icon(Icons.check, size: 18),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),

          _sectionTitle('Notas del día'),
          TextField(
            controller: _noteCtl,
            minLines: 6,
            maxLines: null,
            onChanged: (v) => c.setNote(d, v),
            decoration: InputDecoration(
              hintText: 'Escribe tus notas aquí...',
              filled: true,
              fillColor: const Color(0xFFFFFBEA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: line),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: muted,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════
//  Diálogo para crear / editar un evento
// ═══════════════════════════════════════════════════════════════════
class _EventDialog extends StatefulWidget {
  final PlannerEvent? existing;
  final DateTime day;
  final int startMin;
  final void Function(PlannerEvent) onSave;
  final void Function(String id) onDelete;

  const _EventDialog({
    required this.existing,
    required this.day,
    required this.startMin,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late DateTime _date = widget.existing != null ? parseKey(widget.existing!.date) : widget.day;
  late int _start = widget.existing?.startMin ?? widget.startMin;
  late int _end = widget.existing?.endMin ?? min(widget.startMin + 60, 1439);
  late int _color = widget.existing?.colorIndex ?? 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (p != null) setState(() => _date = p);
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (isStart) {
        _start = m;
      } else {
        _end = m;
      }
    });
  }

  void _save() {
    var start = _start;
    var end = _end;
    if (end <= start) {
      end = start + 60;
      if (end > 1439) {
        end = 1439;
        start = min(start, 1438);
      }
    }
    final title = _title.text.trim().isEmpty ? 'Sin título' : _title.text.trim();
    widget.onSave(PlannerEvent(
      id: widget.existing?.id ?? newId(),
      title: title,
      date: dateKey(_date),
      startMin: start,
      endMin: end,
      colorIndex: _color,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Editar evento' : 'Nuevo evento'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                        '${weekdayShort[_date.weekday - 1]} ${_date.day}/${_date.month}/${_date.year}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text('Inicio ${formatMinutes(_start)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text('Fin ${formatMinutes(_end)}'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                children: [
                  for (var i = 0; i < eventColors.length; i++)
                    Tooltip(
                      message: eventColorNames[i],
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: eventColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == i ? ink : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: _color == i
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () {
              widget.onDelete(widget.existing!.id);
              Navigator.of(context).pop();
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFE53935))),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Diálogo de sincronización
// ═══════════════════════════════════════════════════════════════════
class _SyncDialog extends StatefulWidget {
  final PlannerController controller;
  const _SyncDialog({required this.controller});

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  late final TextEditingController _code =
      TextEditingController(text: widget.controller.syncCode);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AlertDialog(
      title: const Text('Sincronización'),
      content: SizedBox(
        width: 380,
        child: c.cloudEnabled
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado: ${c.status}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Tu código de sincronización. Escríbelo igual en otro dispositivo '
                    'para ver los mismos datos. No lo compartas con nadie.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: 'Código'),
                  ),
                ],
              )
            : const Text(
                'Firebase todavía no está configurado, así que tus datos se guardan '
                'solo en este equipo.\n\nSigue la guía del README (flutterfire configure) '
                'para activar la sincronización.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        if (c.cloudEnabled)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              await c.changeSyncCode(_code.text);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Usar este código'),
          ),
      ],
    );
  }
}
