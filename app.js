/* EasyNotes Planner
 * Planner semanal por horas, tareas, notas por día y eventos con colores.
 * Guarda en el navegador (localStorage) y, si configuras Firebase en
 * firebase-config.js, sincroniza con Firestore usando un código personal.
 */
(function () {
  'use strict';

  // ── Constantes ─────────────────────────────────────────────────────
  var COLORS = ['#2F6FDE', '#0EA5E9', '#4F46E5', '#0F766E', '#1E3A8A', '#7C3AED'];
  var COLOR_NAMES = ['Azul', 'Celeste', 'Índigo', 'Verde azulado', 'Marino', 'Violeta'];
  // Versión más oscura de cada color, para que el texto del evento se lea bien
  var TEXT_COLORS = ['#1F55B8', '#075985', '#3730A3', '#115E59', '#1E3A8A', '#5B21B6'];
  var WD_SHORT = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  var WD_LONG = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  var MONTHS = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var HOUR = 56;      // alto de una hora en píxeles (igual que --hour en el CSS)
  var GUTTER = 54;    // ancho de la columna de horas (igual que --gutter)
  var FIREBASE_VERSION = '10.12.2';
  var ALARM_KEY = 'easynotes.alarms'; // alarmas ya mostradas o pospuestas (por dispositivo)
  var GRACE_MS = 5 * 60000;          // una alarma atrasada se muestra hasta 5 min después del inicio
  var SNOOZE_MIN = 5;                // minutos que se pospone una alarma

  // ── Utilidades ─────────────────────────────────────────────────────
  function $(id) { return document.getElementById(id); }
  function pad(n) { return String(n).padStart(2, '0'); }
  function dateOnly(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
  function dateKey(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function parseKey(k) {
    var p = k.split('-').map(Number);
    return new Date(p[0], p[1] - 1, p[2]);
  }
  function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); }
  function dayIndex(d) { return (d.getDay() + 6) % 7; } // 0 = lunes
  function startOfWeek(d) { return addDays(d, -dayIndex(d)); }
  function sameDay(a, b) { return dateKey(a) === dateKey(b); }
  function fmtMin(m) { return pad(Math.floor(m / 60)) + ':' + pad(m % 60); }
  function toMin(s) {
    var p = String(s).split(':').map(Number);
    return (p[0] || 0) * 60 + (p[1] || 0);
  }
  function newId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 8); }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function rgba(hex, a) {
    var n = parseInt(hex.slice(1), 16);
    return 'rgba(' + (n >> 16) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
  }
  function randomCode() {
    var chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    var out = '';
    var buf = new Uint32Array(10);
    (window.crypto || window.msCrypto).getRandomValues(buf);
    for (var i = 0; i < buf.length; i++) out += chars[buf[i] % chars.length];
    return out;
  }
  function isPhone() { return window.matchMedia('(max-width: 899px)').matches; }

  // ── Estado y guardado local ────────────────────────────────────────
  var state = { events: [], tasks: [], notes: {}, updatedAt: 0, syncCode: '' };
  var weekStart = startOfWeek(new Date());
  var selected = dateOnly(new Date());

  function applyData(o) {
    state.events = Array.isArray(o.events) ? o.events : [];
    state.tasks = Array.isArray(o.tasks) ? o.tasks : [];
    state.notes = o.notes && typeof o.notes === 'object' ? o.notes : {};
  }
  function dataObj() { return { events: state.events, tasks: state.tasks, notes: state.notes }; }

  function loadLocal() {
    try {
      var raw = localStorage.getItem('easynotes.data');
      if (raw) {
        var o = JSON.parse(raw);
        applyData(o);
        state.updatedAt = Number(o.updatedAt) || 0;
      }
    } catch (e) { /* datos dañados: se empieza vacío */ }
    try { state.syncCode = localStorage.getItem('easynotes.syncCode') || ''; } catch (e) { /* sin acceso */ }
    if (!state.syncCode) {
      state.syncCode = randomCode();
      try { localStorage.setItem('easynotes.syncCode', state.syncCode); } catch (e) { /* sin acceso */ }
    }
  }

  function saveLocal() {
    try {
      var o = dataObj();
      o.updatedAt = state.updatedAt;
      localStorage.setItem('easynotes.data', JSON.stringify(o));
    } catch (e) { /* sin acceso o sin espacio */ }
  }

  function changed() {
    state.updatedAt = Date.now();
    saveLocal();
    scheduleCloud();
  }

  // ── Nube (Firebase / Firestore) ────────────────────────────────────
  var cloud = { on: false, status: 'Solo local', db: null, fs: null, unsub: null, timer: null };

  function scheduleCloud() {
    if (!cloud.on) return;
    clearTimeout(cloud.timer);
    cloud.timer = setTimeout(pushCloud, 700);
  }

  function docRef() { return cloud.fs.doc(cloud.db, 'planners', state.syncCode); }

  function initCloud() {
    var cfg = window.FIREBASE_CONFIG;
    if (!cfg || !cfg.apiKey) { renderSyncBadge(); return; }
    var base = 'https://www.gstatic.com/firebasejs/' + FIREBASE_VERSION + '/';
    Promise.all([import(base + 'firebase-app.js'), import(base + 'firebase-firestore.js')])
      .then(function (mods) {
        var app = mods[0].initializeApp(cfg);
        cloud.fs = mods[1];
        cloud.db = cloud.fs.getFirestore(app);
        cloud.on = true;
        cloud.status = 'Conectando...';
        renderSyncBadge();
        listen();
      })
      .catch(function () {
        cloud.status = 'No se pudo cargar Firebase';
        renderSyncBadge();
      });
  }

  function listen() {
    if (cloud.unsub) cloud.unsub();
    cloud.unsub = cloud.fs.onSnapshot(docRef(), function (snap) {
      if (snap.metadata.hasPendingWrites) return;
      if (!snap.exists()) { pushCloud(); return; }
      var d = snap.data();
      var remoteAt = Number(d.updatedAt) || 0;
      if (remoteAt > state.updatedAt) {
        try {
          applyData(JSON.parse(d.json));
          state.updatedAt = remoteAt;
          saveLocal();
          cloud.status = 'Sincronizado';
          renderAll();
          checkAlarms();
        } catch (e) {
          cloud.status = 'Datos de la nube ilegibles';
        }
      } else if (remoteAt < state.updatedAt) {
        pushCloud();
        return;
      } else {
        cloud.status = 'Sincronizado';
      }
      renderSyncBadge();
    }, function () {
      cloud.status = 'Sin conexión a la nube';
      renderSyncBadge();
    });
  }

  function pushCloud() {
    if (!cloud.on) return Promise.resolve();
    cloud.status = 'Sincronizando...';
    renderSyncBadge();
    return cloud.fs.setDoc(docRef(), { json: JSON.stringify(dataObj()), updatedAt: state.updatedAt })
      .then(function () { cloud.status = 'Sincronizado'; })
      .catch(function () { cloud.status = 'Error al sincronizar'; })
      .then(renderSyncBadge);
  }

  // ── Dibujo de la pantalla ──────────────────────────────────────────
  function rangeLabel() {
    var a = weekStart;
    var b = addDays(a, 6);
    var mA = MONTHS[a.getMonth()];
    var mB = MONTHS[b.getMonth()];
    if (a.getMonth() === b.getMonth()) {
      return a.getDate() + ' – ' + b.getDate() + ' de ' + mB + ' de ' + b.getFullYear();
    }
    return a.getDate() + ' de ' + mA.slice(0, 3) + ' – ' + b.getDate() + ' de ' + mB.slice(0, 3) + ' de ' + b.getFullYear();
  }

  function renderSyncBadge() {
    var b = $('syncBtn');
    var ok = cloud.on && cloud.status === 'Sincronizado';
    b.classList.toggle('ok', ok);
    b.title = cloud.status;
    b.innerHTML = '<span class="dot"></span><span>' + esc(cloud.status) + '</span>';
  }

  function renderTop() {
    $('range').textContent = rangeLabel();
    renderSyncBadge();
  }

  /** Reparte en carriles los eventos que se solapan para verlos uno al lado del otro. */
  function layout(evs) {
    evs = evs.slice().sort(function (a, b) { return a.startMin - b.startMin; });
    var result = [];
    var cluster = [];
    var clusterEnd = -1;

    function flush() {
      var n = cluster.reduce(function (m, p) { return Math.max(m, p.lane + 1); }, 0);
      cluster.forEach(function (p) { p.lanes = n; });
      result = result.concat(cluster);
      cluster = [];
      clusterEnd = -1;
    }

    evs.forEach(function (e) {
      if (cluster.length && e.startMin >= clusterEnd) flush();
      var lane = 0;
      while (cluster.some(function (p) { return p.lane === lane && p.ev.endMin > e.startMin; })) lane++;
      cluster.push({ ev: e, lane: lane, lanes: 1 });
      clusterEnd = Math.max(clusterEnd, e.endMin);
    });
    flush();
    return result;
  }

  function renderWeek() {
    var today = new Date();
    var days = [];
    for (var i = 0; i < 7; i++) days.push(addDays(weekStart, i));

    var head = '<div class="wk-head"><div class="gut"></div>';
    days.forEach(function (d) {
      var k = dateKey(d);
      var pend = state.tasks.filter(function (t) { return t.date === k && !t.done; }).length;
      head += '<button type="button" class="dayhead' + (sameDay(d, selected) ? ' sel' : '') +
        (sameDay(d, today) ? ' today' : '') + '" data-day="' + k + '">' +
        '<span class="dn">' + WD_SHORT[dayIndex(d)].toUpperCase() + '</span>' +
        '<span class="dnum">' + d.getDate() + '</span>' +
        '<span class="pend">' + (pend ? pend + (pend === 1 ? ' tarea' : ' tareas') : '') + '</span></button>';
    });
    head += '</div>';

    var body = '<div class="wk-body"><div class="hours">';
    for (var h = 1; h < 24; h++) {
      body += '<span class="hlabel" style="top:' + (h * HOUR) + 'px">' + pad(h) + ':00</span>';
    }
    body += '</div>';

    days.forEach(function (d) {
      var k = dateKey(d);
      var placed = layout(state.events.filter(function (e) { return e.date === k; }));
      body += '<div class="daycol' + (sameDay(d, selected) ? ' sel' : '') + '" data-day="' + k + '">';
      placed.forEach(function (p) {
        var e = p.ev;
        var c = COLORS[e.colorIndex % COLORS.length] || COLORS[0];
        var top = e.startMin / 60 * HOUR + 1;
        var height = Math.max(20, (e.endMin - e.startMin) / 60 * HOUR - 2);
        body += '<div class="ev" data-id="' + esc(e.id) + '" style="top:' + top + 'px;height:' + height +
          'px;left:calc(' + (p.lane / p.lanes * 100) + '% + 2px);width:calc(' + (100 / p.lanes) +
          '% - 4px);--c:' + c + ';--t:' + (TEXT_COLORS[e.colorIndex % TEXT_COLORS.length] || c) + ';background:' + rgba(c, 0.18) + '"><b>' + esc(e.title) + '</b>' +
          (height > 34 ? '<small>' + fmtMin(e.startMin) + ' – ' + fmtMin(e.endMin) + '</small>' : '') + '</div>';
      });
      if (sameDay(d, today)) {
        var nowMin = today.getHours() * 60 + today.getMinutes();
        body += '<div class="nowline" style="top:' + (nowMin / 60 * HOUR - 1) + 'px"></div>';
      }
      body += '</div>';
    });
    body += '</div>';

    $('weekInner').innerHTML = head + body;
  }

  function renderPanel() {
    var k = dateKey(selected);
    var evs = state.events.filter(function (e) { return e.date === k; })
      .sort(function (a, b) { return a.startMin - b.startMin; });
    var tasks = state.tasks.filter(function (t) { return t.date === k; });

    var h = '<h2>' + WD_LONG[dayIndex(selected)] + '</h2><div class="sub">' + selected.getDate() +
      ' de ' + MONTHS[selected.getMonth()] + ' de ' + selected.getFullYear() + '</div>';

    h += '<h3>Eventos</h3>';
    if (!evs.length) h += '<p class="empty">Sin eventos. Toca la cuadrícula o el botón + para crear uno.</p>';
    evs.forEach(function (e) {
      h += '<button type="button" class="evrow" data-edit="' + esc(e.id) + '">' +
        '<i style="background:' + (COLORS[e.colorIndex % COLORS.length] || COLORS[0]) + '"></i>' +
        '<span class="tm">' + fmtMin(e.startMin) + ' – ' + fmtMin(e.endMin) + '</span>' +
        '<span class="tt">' + esc(e.title) + '</span></button>';
    });

    h += '<h3>Tareas</h3>';
    tasks.forEach(function (t) {
      h += '<div class="taskrow' + (t.done ? ' done' : '') + '"><label>' +
        '<input type="checkbox" data-toggle="' + esc(t.id) + '"' + (t.done ? ' checked' : '') + '>' +
        '<span>' + esc(t.title) + '</span></label>' +
        '<button type="button" class="x" data-deltask="' + esc(t.id) + '" aria-label="Borrar tarea">&times;</button></div>';
    });
    h += '<form id="taskForm" class="taskform"><input id="taskInput" type="text" maxlength="200" ' +
      'placeholder="Nueva tarea..." autocomplete="off"><button class="btn" type="submit">Agregar</button></form>';

    h += '<h3>Notas del día</h3><textarea id="noteArea" placeholder="Escribe tus notas aquí...">' +
      esc(state.notes[k] || '') + '</textarea>';

    $('dayPanel').innerHTML = h;
  }

  function renderAll() {
    renderTop();
    renderWeek();
    renderPanel();
  }

  function scrollToSelectedDay() {
    var sc = $('weekScroll');
    if (!sc) return;
    var col = $('weekInner').querySelector('.daycol.sel');
    if (col && isPhone()) sc.scrollLeft = Math.max(0, col.offsetLeft - GUTTER - 8);
  }

  // ── Cambios en los datos ───────────────────────────────────────────
  function saveEvent(ev) {
    var i = state.events.findIndex(function (x) { return x.id === ev.id; });
    if (i >= 0) state.events[i] = ev; else state.events.push(ev);
    changed();
  }

  function deleteEvent(id) {
    state.events = state.events.filter(function (e) { return e.id !== id; });
    changed();
  }

  function refreshAfterEdit() {
    renderWeek();
    renderPanel();
  }

  // ── Diálogo de evento ──────────────────────────────────────────────
  var editingId = null;
  var curColor = 0;

  function setColor(i) {
    curColor = i;
    Array.prototype.forEach.call($('swatches').children, function (b, j) {
      b.classList.toggle('on', j === i);
      b.textContent = j === i ? '✓' : '';
    });
  }

  function setRemind(v) {
    var sel = $('evRemind');
    sel.value = String(v);
    if (sel.value !== String(v)) sel.value = '-1';
  }

  function updateRemindHint() {
    var t = 'La alarma suena mientras la app esté abierta. Para que suene con la app cerrada, usa «Google Calendar» (o «.ics» si usas otro calendario).';
    try {
      if ('Notification' in window && Notification.permission === 'denied') {
        t += ' Las notificaciones están bloqueadas en este navegador, así que el aviso solo se verá dentro de la app.';
      }
    } catch (e) { /* sin notificaciones */ }
    $('remindHint').textContent = t;
  }

  function openEvent(ev, dayKey, startMin) {
    editingId = ev ? ev.id : null;
    $('evHeading').textContent = ev ? 'Editar evento' : 'Nuevo evento';
    $('evTitle').value = ev ? ev.title : '';
    $('evDate').value = ev ? ev.date : dayKey;
    $('evStart').value = fmtMin(ev ? ev.startMin : startMin);
    $('evEnd').value = fmtMin(ev ? ev.endMin : Math.min(startMin + 60, 1439));
    setColor(ev ? ev.colorIndex : 0);
    setRemind(ev ? (typeof ev.remind === 'number' ? ev.remind : -1) : 10);
    updateRemindHint();
    $('evDelete').hidden = !ev;
    $('eventDlg').showModal();
    if (!ev && !isPhone()) $('evTitle').focus();
  }

  /** Lee el formulario y devuelve el evento (corrigiendo horas imposibles). */
  function formEvent() {
    var start = toMin($('evStart').value || '09:00');
    var end = toMin($('evEnd').value || '10:00');
    if (end <= start) {
      end = start + 60;
      if (end > 1439) { end = 1439; start = Math.min(start, 1438); }
    }
    var r = parseInt($('evRemind').value, 10);
    return {
      id: editingId || newId(),
      title: $('evTitle').value.trim() || 'Sin título',
      date: $('evDate').value || dateKey(selected),
      startMin: start,
      endMin: end,
      colorIndex: curColor,
      remind: isNaN(r) ? -1 : r
    };
  }

  function submitEvent(e) {
    e.preventDefault();
    var ev = formEvent();
    saveEvent(ev);
    if (ev.remind >= 0) { unlockAudio(); ensureNotifPermission(); }
    $('eventDlg').close();
    selected = parseKey(ev.date);
    weekStart = startOfWeek(selected);
    renderAll();
    checkAlarms();
  }

  // ── Alarmas ────────────────────────────────────────────────────────
  var alarms = {};          // clave -> { done: true } | { until: ms }
  var alarmQueue = [];
  var currentAlarm = null;
  var audioCtx = null;
  var soundTimer = null;
  var soundStop = null;

  function loadAlarms() {
    try { alarms = JSON.parse(localStorage.getItem(ALARM_KEY)) || {}; } catch (e) { alarms = {}; }
    // Limpia las de hace más de 3 días
    var limit = dateKey(addDays(new Date(), -3));
    Object.keys(alarms).forEach(function (k) {
      var d = k.split('|')[1];
      if (!d || d < limit) delete alarms[k];
    });
  }

  function saveAlarms() {
    try { localStorage.setItem(ALARM_KEY, JSON.stringify(alarms)); } catch (e) { /* sin acceso */ }
  }

  function alarmKey(e) { return e.id + '|' + e.date + '|' + e.startMin + '|' + e.remind; }

  function eventTs(e, min) {
    var d = parseKey(e.date);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, min).getTime();
  }

  function describeWhen(e) {
    var m = Math.round((eventTs(e, e.startMin) - Date.now()) / 60000);
    var rel = m > 0 ? 'Empieza en ' + m + ' min' : (m === 0 ? 'Empieza ahora' : 'Empezó hace ' + (-m) + ' min');
    return fmtMin(e.startMin) + ' – ' + fmtMin(e.endMin) + ' · ' + rel;
  }

  function enqueueAlarm(a) { alarmQueue.push(a); }

  /** Revisa los eventos y dispara las alarmas que ya toca mostrar. */
  function checkAlarms() {
    var now = Date.now();
    var touched = false;
    state.events.forEach(function (e) {
      var r = typeof e.remind === 'number' ? e.remind : -1;
      if (r < 0) return;
      var key = alarmKey(e);
      var st = alarms[key];
      var start = eventTs(e, e.startMin);
      var due = false;
      if (!st) due = now >= start - r * 60000 && now <= start + GRACE_MS;
      else if (st.until) due = now >= st.until && now < eventTs(e, e.endMin);
      if (!due) return;
      alarms[key] = { done: true };
      touched = true;
      enqueueAlarm({ key: key, title: e.title, ev: e });
    });
    if (touched) saveAlarms();
    showNextAlarm();
  }

  function showNextAlarm() {
    if (currentAlarm || !alarmQueue.length) return;
    currentAlarm = alarmQueue.shift();
    var a = currentAlarm;
    var when = a.when || describeWhen(a.ev);
    $('alarmTitle').textContent = a.title;
    $('alarmWhen').textContent = when;
    $('alarmSnooze').hidden = !!a.test;
    startSound();
    var away = document.hidden || (document.hasFocus && !document.hasFocus());
    if (a.test || away) showSystemNotification(a.title, when, a.key);
    if (!$('alarmDlg').open) $('alarmDlg').showModal();
  }

  function closeAlarm(snooze) {
    var a = currentAlarm;
    if (!a) return;
    currentAlarm = null;
    stopSound();
    if (snooze && !a.test) {
      alarms[a.key] = { until: Date.now() + SNOOZE_MIN * 60000 };
      saveAlarms();
    }
    var dlg = $('alarmDlg');
    if (dlg.open) dlg.close();
    showNextAlarm();
  }

  // Sonido y vibración (el navegador exige un toque previo del usuario para permitir audio)
  function unlockAudio() {
    try {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      if (!audioCtx) audioCtx = new AC();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch (e) { /* sin audio */ }
  }

  function beepAt(t0, freq) {
    var o = audioCtx.createOscillator();
    var g = audioCtx.createGain();
    o.type = 'sine';
    o.frequency.value = freq;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(0.4, t0 + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.22);
    o.connect(g);
    g.connect(audioCtx.destination);
    o.start(t0);
    o.stop(t0 + 0.25);
  }

  function ringTick() {
    try {
      if (audioCtx && audioCtx.state === 'running') {
        var t = audioCtx.currentTime + 0.05;
        for (var i = 0; i < 3; i++) beepAt(t + i * 0.32, 988);
      }
    } catch (e) { /* sin audio */ }
    try { if (navigator.vibrate) navigator.vibrate([300, 150, 300]); } catch (e) { /* sin vibración */ }
  }

  function startSound() {
    stopSound();
    unlockAudio();
    ringTick();
    soundTimer = setInterval(ringTick, 1500);
    soundStop = setTimeout(stopSound, 60000); // se calla sola al minuto
  }

  function stopSound() {
    clearInterval(soundTimer);
    clearTimeout(soundStop);
    soundTimer = null;
    soundStop = null;
    try { if (navigator.vibrate) navigator.vibrate(0); } catch (e) { /* sin vibración */ }
  }

  // Notificación del sistema (útil cuando la app está en segundo plano)
  function ensureNotifPermission() {
    try {
      if ('Notification' in window && Notification.permission === 'default') Notification.requestPermission();
    } catch (e) { /* sin notificaciones */ }
  }

  function showSystemNotification(title, body, tag) {
    try {
      if (!('Notification' in window) || Notification.permission !== 'granted') return;
      var opts = {
        body: body,
        tag: tag,
        icon: 'icons/icon-192.png',
        badge: 'icons/icon-192.png',
        requireInteraction: true,
        vibrate: [300, 150, 300, 150, 300]
      };
      var fallback = function () { try { new Notification(title, opts); } catch (e) { /* sin notificaciones */ } };
      if ('serviceWorker' in navigator && navigator.serviceWorker.getRegistration) {
        navigator.serviceWorker.getRegistration().then(function (reg) {
          if (reg && reg.showNotification) reg.showNotification(title, opts); else fallback();
        }).catch(fallback);
      } else {
        fallback();
      }
    } catch (e) { /* sin notificaciones */ }
  }

  // ── Exportar a calendario (.ics) ───────────────────────────────────
  function icsEscape(s) {
    return String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
  }

  function icsLocal(dateStr, min) {
    var p = dateStr.split('-');
    return p[0] + p[1] + p[2] + 'T' + pad(Math.floor(min / 60)) + pad(min % 60) + '00';
  }

  function utcStamp() {
    var d = new Date();
    return d.getUTCFullYear() + pad(d.getUTCMonth() + 1) + pad(d.getUTCDate()) + 'T' +
      pad(d.getUTCHours()) + pad(d.getUTCMinutes()) + pad(d.getUTCSeconds()) + 'Z';
  }

  function buildIcs(ev) {
    var lines = [
      'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//EasyNotes Planner//ES', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:' + ev.id + '@easynotes-planner',
      'DTSTAMP:' + utcStamp(),
      'DTSTART:' + icsLocal(ev.date, ev.startMin),
      'DTEND:' + icsLocal(ev.date, ev.endMin),
      'SUMMARY:' + icsEscape(ev.title)
    ];
    if (ev.remind >= 0) {
      lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', 'DESCRIPTION:' + icsEscape(ev.title),
        'TRIGGER:' + (ev.remind === 0 ? 'PT0S' : '-PT' + ev.remind + 'M'), 'END:VALARM');
    }
    lines.push('END:VEVENT', 'END:VCALENDAR');
    return lines.join('\r\n') + '\r\n';
  }

  function slug(s) {
    return String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'evento';
  }

  function downloadIcs(ev) {
    var blob = new Blob([buildIcs(ev)], { type: 'text/calendar;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = slug(ev.title) + '.ics';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
  }

  // ── Google Calendar (enlace con el evento ya rellenado) ────────────
  function remindLabel(r) {
    if (r < 0) return '';
    if (r === 0) return 'al empezar';
    if (r === 60) return '1 hora antes';
    return r + ' minutos antes';
  }

  function googleCalUrl(ev) {
    var details = 'Creado en EasyNotes Planner.';
    if (ev.remind >= 0) details += '\nAviso sugerido: ' + remindLabel(ev.remind) + '.';
    return 'https://calendar.google.com/calendar/render?action=TEMPLATE' +
      '&text=' + encodeURIComponent(ev.title) +
      '&dates=' + icsLocal(ev.date, ev.startMin) + '/' + icsLocal(ev.date, ev.endMin) +
      '&details=' + encodeURIComponent(details);
  }

  // ── Diálogo de sincronización ──────────────────────────────────────
  function openSync() {
    $('syncStatus').textContent = 'Estado: ' + cloud.status;
    $('syncOn').hidden = !cloud.on;
    $('syncUse').hidden = !cloud.on;
    $('syncCopy').hidden = !cloud.on;
    $('syncOff').hidden = cloud.on;
    $('syncError').hidden = true;
    $('syncCodeInput').value = state.syncCode;
    $('syncDlg').showModal();
  }

  function useSyncCode() {
    var code = $('syncCodeInput').value.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
    if (code.length < 6) {
      $('syncError').textContent = 'El código debe tener al menos 6 letras o números.';
      $('syncError').hidden = false;
      return;
    }
    if (code !== state.syncCode) {
      state.syncCode = code;
      try { localStorage.setItem('easynotes.syncCode', code); } catch (e) { /* sin acceso */ }
      cloud.status = 'Conectando...';
      renderSyncBadge();
      listen();
    }
    $('syncDlg').close();
  }

  function copySyncCode() {
    var done = function () { $('syncCopy').textContent = 'Copiado'; };
    try {
      navigator.clipboard.writeText(state.syncCode).then(done, function () {
        $('syncCodeInput').select();
      });
    } catch (e) { $('syncCodeInput').select(); }
  }

  // ── Pestañas (teléfono) ────────────────────────────────────────────
  var lastScroll = { top: 7 * HOUR, left: 0 };

  function setTab(tab) {
    var sc = $('weekScroll');
    if (document.body.dataset.tab === 'week' && sc.clientHeight > 0) {
      lastScroll = { top: sc.scrollTop, left: sc.scrollLeft };
    }
    document.body.dataset.tab = tab;
    Array.prototype.forEach.call(document.querySelectorAll('.tabs button'), function (b) {
      b.classList.toggle('on', b.dataset.tab === tab);
    });
    if (tab === 'week') {
      sc.scrollTop = lastScroll.top;
      sc.scrollLeft = lastScroll.left;
    } else {
      $('dayPanel').scrollTop = 0;
    }
  }

  // ── Eventos de la interfaz ─────────────────────────────────────────
  function bind() {
    $('prevWeek').addEventListener('click', function () {
      weekStart = addDays(weekStart, -7);
      selected = addDays(selected, -7);
      renderAll();
    });
    $('nextWeek').addEventListener('click', function () {
      weekStart = addDays(weekStart, 7);
      selected = addDays(selected, 7);
      renderAll();
    });
    $('todayBtn').addEventListener('click', function () {
      selected = dateOnly(new Date());
      weekStart = startOfWeek(selected);
      renderAll();
      scrollToSelectedDay();
    });

    function newEventHere() { openEvent(null, dateKey(selected), 9 * 60); }
    $('newEventBtn').addEventListener('click', newEventHere);
    $('fab').addEventListener('click', newEventHere);

    $('syncBtn').addEventListener('click', openSync);
    $('syncClose').addEventListener('click', function () { $('syncDlg').close(); });
    $('syncUse').addEventListener('click', useSyncCode);
    $('syncCopy').addEventListener('click', copySyncCode);

    Array.prototype.forEach.call(document.querySelectorAll('.tabs button'), function (b) {
      b.addEventListener('click', function () { setTab(b.dataset.tab); });
    });

    // Colores del diálogo
    var sw = $('swatches');
    COLORS.forEach(function (c, i) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'swatch';
      b.style.setProperty('--c', c);
      b.title = COLOR_NAMES[i];
      b.setAttribute('aria-label', COLOR_NAMES[i]);
      b.addEventListener('click', function () { setColor(i); });
      sw.appendChild(b);
    });

    $('evForm').addEventListener('submit', submitEvent);
    $('evCancel').addEventListener('click', function () { $('eventDlg').close(); });
    $('evTest').addEventListener('click', function () {
      unlockAudio();
      ensureNotifPermission();
      enqueueAlarm({ key: 'test|' + Date.now(), title: $('evTitle').value.trim() || 'Alarma de prueba', when: 'Así sonará tu aviso', test: true });
      showNextAlarm();
    });
    $('evGcal').addEventListener('click', function () { window.open(googleCalUrl(formEvent()), '_blank', 'noopener'); });
    $('evIcs').addEventListener('click', function () { downloadIcs(formEvent()); });
    $('alarmSnooze').addEventListener('click', function () { closeAlarm(true); });
    $('alarmDismiss').addEventListener('click', function () { closeAlarm(false); });
    $('alarmDlg').addEventListener('close', function () { if (!$('alarmDlg').open) closeAlarm(false); });
    ['pointerdown', 'keydown', 'touchstart'].forEach(function (n) {
      document.addEventListener(n, unlockAudio, { passive: true });
    });
    document.addEventListener('visibilitychange', function () { if (!document.hidden) checkAlarms(); });
    window.addEventListener('focus', checkAlarms);
    $('evDelete').addEventListener('click', function () {
      if (editingId) deleteEvent(editingId);
      $('eventDlg').close();
      refreshAfterEdit();
    });

    // Semana: elegir día, editar evento o crear uno tocando la cuadrícula
    $('weekInner').addEventListener('click', function (e) {
      var head = e.target.closest('.dayhead');
      if (head) {
        selected = parseKey(head.dataset.day);
        refreshAfterEdit();
        return;
      }
      var evEl = e.target.closest('.ev');
      if (evEl) {
        var obj = state.events.find(function (x) { return x.id === evEl.dataset.id; });
        if (obj) {
          selected = parseKey(obj.date);
          refreshAfterEdit();
          openEvent(obj, obj.date, obj.startMin);
        }
        return;
      }
      var col = e.target.closest('.daycol');
      if (col) {
        var rect = col.getBoundingClientRect();
        var hour = Math.max(0, Math.min(23, Math.floor((e.clientY - rect.top) / HOUR)));
        selected = parseKey(col.dataset.day);
        refreshAfterEdit();
        openEvent(null, col.dataset.day, hour * 60);
      }
    });

    // Panel del día
    var panel = $('dayPanel');
    panel.addEventListener('click', function (e) {
      var ed = e.target.closest('[data-edit]');
      if (ed) {
        var obj = state.events.find(function (x) { return x.id === ed.dataset.edit; });
        if (obj) openEvent(obj, obj.date, obj.startMin);
        return;
      }
      var del = e.target.closest('[data-deltask]');
      if (del) {
        state.tasks = state.tasks.filter(function (t) { return t.id !== del.dataset.deltask; });
        changed();
        refreshAfterEdit();
      }
    });
    panel.addEventListener('change', function (e) {
      var id = e.target.dataset && e.target.dataset.toggle;
      if (!id) return;
      var t = state.tasks.find(function (x) { return x.id === id; });
      if (t) { t.done = !t.done; changed(); refreshAfterEdit(); }
    });
    panel.addEventListener('submit', function (e) {
      if (e.target.id !== 'taskForm') return;
      e.preventDefault();
      var v = $('taskInput').value.trim();
      if (!v) return;
      state.tasks.push({ id: newId(), title: v, date: dateKey(selected), done: false });
      changed();
      refreshAfterEdit();
      $('taskInput').focus();
    });
    panel.addEventListener('input', function (e) {
      if (e.target.id !== 'noteArea') return;
      var k = dateKey(selected);
      var v = e.target.value;
      if (v.trim()) state.notes[k] = v; else delete state.notes[k];
      changed();
    });
  }

  // ── Inicio ─────────────────────────────────────────────────────────
  loadLocal();
  bind();
  renderAll();
  $('weekScroll').scrollTop = 7 * HOUR;
  scrollToSelectedDay();
  lastScroll = { top: $('weekScroll').scrollTop, left: $('weekScroll').scrollLeft };
  initCloud();
  loadAlarms();
  checkAlarms();
  setInterval(checkAlarms, 10000);

  if ('serviceWorker' in navigator && /^https?:$/.test(location.protocol)) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () { /* sin modo sin conexión */ });
    });
  }
})();
