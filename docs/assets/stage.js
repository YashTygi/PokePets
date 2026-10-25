/* The controlled environment: a sample desktop, one Pokémon, and every move it can be asked for.
   Everything here is labelled a web sample; the real app does the same things on your actual desktop. */
(function () {
  'use strict';
  const { World, Actor, FORMS, EASE, REDUCED, rand, pick, preload } = PokeEngine;
  const { everyday, hooks, mac, LISTS, speak } = PokeMoves;
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  const desk = $('#desk');
  if (!desk) return;
  const S = 2;                                   // screen pixels per art pixel: whole numbers keep the art crisp
  const m = { w: 0, h: 0, ground: 0 };

  /* ------------------------------------------------------------ the desktop */

  const files = $$('.file', desk).map((el) => ({ id: el.dataset.id, name: el.dataset.name, el, trashed: false }));
  const trashIcon = $('.trash', desk);

  const rel = (el) => {
    const r = desk.getBoundingClientRect(), b = el.getBoundingClientRect();
    return { x1: b.left - r.left, x2: b.right - r.left, y1: b.top - r.top, y2: b.bottom - r.top };
  };
  function layout() {
    const r = desk.getBoundingClientRect();
    m.w = r.width;
    m.h = r.height;
    m.dock = rel($('.dock', desk));
    m.win = rel($('#win', desk));
    m.ground = m.dock.y1 + 6;
    files.forEach((f) => {
      const b = rel($('.ficon', f.el));
      Object.assign(f, { x: (b.x1 + b.x2) / 2, y: (b.y1 + b.y2) / 2, x1: b.x1, x2: b.x2, top: b.y1 + 4 });
    });
    m.ball = rel($('.menu-ball', desk));
  }
  layout();

  const world = new World(desk, {
    scale: S,
    size: () => ({ w: m.w, h: m.h }),
    ground: () => m.ground,
    surfaces: () => [{ x1: m.win.x1, x2: m.win.x2, y: m.win.y1 }, ...files.filter((f) => !f.trashed).map((f) => ({ x1: f.x1, x2: f.x2, y: f.top }))],
  });

  /* ------------------------------------------------------------ state */

  const state = {
    out: true, lastAct: 0, snatched: null, ready: false,
    mood: { fainted: false },
    mac: { battery: 86, charging: false, wifi: true, camera: false, away: false, hot: false },
  };
  let actor = null, lastMove = null;

  /** What the moves call on (see moves.js). */
  const st = {
    world, mood: state.mood, cursor: null,
    bounds: () => ({ x1: 28, x2: m.w - 28 }),
    windowRect: () => m.win,
    dockRect: () => m.dock,
    cursorPos: () => (world.cursor.inside ? { x: world.cursor.x, y: world.cursor.y } : { x: m.w * 0.55, y: m.h * 0.45 }),
    airSpot() {
      const b = st.bounds();
      return { x: rand(b.x1 + 40, b.x2 - 40), y: rand(m.h * 0.2, m.ground - 70) };
    },
    nextFile(a) {
      const left = files.filter((f) => !f.trashed);
      if (!left.length) { a.say('No files left. Put some back!', 2.4); return null; }
      return left.sort((p, q) => Math.abs(p.x - a.x) - Math.abs(q.x - a.x))[0];
    },
    trash(f, a) {
      f.trashed = true;
      f.el.classList.add('gone');
      trashIcon.classList.add('full');
      renderFiles();
      log(`${f.name} went to the Trash.`, 'note');
    },
    ghost(f) {
      const g = $('.ficon', f.el).cloneNode(true);
      g.classList.add('ghost');
      const at = `translate(${f.x}px,${f.y}px)`;
      g.dataset.at = at;
      g.style.cssText = `position:absolute;left:0;top:0;margin:-22px 0 0 -18px;transform:${at}`;
      world.fx.append(g);
      return g;
    },
    saliva: (x, y) => world.saliva(x, y),
    windowStart: () => { const w = $('#win'); w.classList.remove('ripple'); void w.offsetWidth; w.classList.add('ripple'); },
    windowTug: () => { const w = $('#win'); w.classList.remove('tug'); void w.offsetWidth; w.classList.add('tug'); },
    dockJiggle: () => { const d = $('.dock'); d.classList.remove('jiggle'); void d.offsetWidth; d.classList.add('jiggle'); },
    async recover(a) {
      if (!state.mood.fainted) return;
      state.mood.fainted = false;
      await a.once('wake');
    },
  };

  /* ------------------------------------------------------------ the log */

  const boxEl = $('#battlebox'), listEl = $('#transcript'), statusEl = $('#status');
  function log(text, kind = 'note') {
    const li = document.createElement('li');
    li.className = kind;
    li.textContent = text;
    listEl.prepend(li);
    while (listEl.children.length > 40) listEl.lastChild.remove();
  }
  function battle(text) {
    boxEl.replaceChildren();
    const t = document.createElement('span');
    t.textContent = text;
    boxEl.append(t);
    boxEl.classList.remove('pop');
    void boxEl.offsetWidth;
    boxEl.classList.add('pop');
  }
  function setStatus(text, busy) {
    statusEl.textContent = text;
    $('#stage').classList.toggle('is-running', !!busy);
  }

  /* ------------------------------------------------------------ the Pokémon */

  actor = new Actor(world, 'gengar', 0, 0);
  actor.onSay = (t) => log(`${actor.info.name}: “${t}”`, 'say');
  actor.onIdle = () => { setStatus(`${actor.info.name} is hanging about`, false); markRunning(null); scheduleAmbient(); };
  function markRunning(id) { $$('[data-move]').forEach((b) => b.classList.toggle('running', b.dataset.move === id)); }

  function placeHome() {
    actor.place(Math.min(Math.max(m.w * 0.42, 60), m.w - 60), m.ground);
    actor.face(1);
    actor.play('idle');
  }
  placeHome();

  function say(name) { return actor.info.name.toUpperCase() + ' used ' + name.toUpperCase() + '!'; }

  /** Runs one thing. `opts.keepDown`: a script that handles a fainted Pokémon itself. */
  function perform(id, run, label, opts = {}) {
    if (!state.ready) return;
    state.lastAct = Date.now();
    clearTimeout(ambientTimer);
    if (state.snatched && !opts.keepSnatch) st.cursor.giveBack(actor, false);
    if (!state.out) { sendOut().then(() => perform(id, run, label, opts)); return; }
    lastMove = { id, run, label, opts };
    markRunning(id);
    if (opts.line) { battle(opts.line); log(opts.line, 'act'); } else { battle(say(label)); log(`${actor.info.name} used ${label}.`, 'act'); }
    setStatus(opts.status || `${actor.info.name} is using ${label}`, true);
    actor.run(async (a) => {
      if (!opts.keepDown) await st.recover(a);
      await a.land();
      await run(a, st);
    });
  }

  /* ------------------------------------------------------------ party */

  function selectForm(form, { silent = false } = {}) {
    if (form === actor.form || !FORMS[form]) return Promise.resolve();
    const before = FORMS[actor.form];
    const after = FORMS[form];
    preload(form);                                              // (everything, so the first move is not waiting on sprites)
    actor.cancel();
    const sameLine = before.line === after.line;
    const x = Math.min(Math.max(actor.x, 70), m.w - 70);
    const swap = async () => {
      actor.setForm(form);
      actor.hush();
      actor.place(x, m.ground);
      actor.face(1);
      actor.play('idle');
      state.mood.fainted = false;
      renderMoves();
      renderParty();
      dispatchEvent(new Event('pokeform'));
      $('#whoLine').textContent = `${after.name} · out on the desktop`;
    };
    if (!state.out) { swap(); return sendOut(); }
    if (sameLine) {                                                // evolving: the white flicker, then the new form
      return new Promise((done) => {
        const glow = actor.clip.animate([{ filter: 'brightness(1)' }, { filter: 'brightness(9)' }, { filter: 'brightness(1)' }, { filter: 'brightness(9)' },
          { filter: 'brightness(1)' }, { filter: 'brightness(9)' }, { filter: 'brightness(9)' }], { duration: 1100, easing: 'steps(1,end)' });
        setTimeout(() => {
          swap();
          world.flash(actor.x, actor.y - 30, '#fff', 48);
          for (let i = 0; i < 6; i++) setTimeout(() => world.spark(actor.x, actor.y - 28, 24), i * 70);
          actor.clip.animate([{ filter: 'brightness(9)' }, { filter: 'brightness(1)' }], { duration: 400 });
          if (!silent) { battle(`${before.name} evolved into ${after.name}!`); log(`${before.name} evolved into ${after.name}.`, 'act'); }
          setTimeout(() => { actor.hearts(); done(); scheduleAmbient(); }, 450);
        }, 1100);
        glow.finished.catch(() => {});
      });
    }
    return recall().then(() => { swap(); return sendOut(); });
  }

  /** Back into the Poké Ball: a flash, then it shrinks away. */
  async function recall() {
    if (!state.out) return;
    state.out = false;
    actor.cancel();
    actor.hush();
    world.flash(actor.x, actor.y - 28, '#fff', 40);
    await actor.clip.animate([{ filter: 'brightness(9)', transform: 'scale(1)', opacity: 1 }, { filter: 'brightness(9)', transform: 'scale(.05)', opacity: 0 }], { duration: 420, easing: 'ease-in', fill: 'forwards' }).finished.catch(() => {});
    actor.el.style.visibility = 'hidden';
    actor.clip.getAnimations().forEach((x) => x.cancel());
    log(`${actor.info.name} came back to its Poké Ball.`, 'note');
  }

  /** Out of the ball: it flies from the menu bar Poké Ball, bursts open, and the Pokémon steps out. */
  async function sendOut() {
    if (state.out) return;
    state.out = true;
    const ball = document.createElement('div');
    ball.className = 'ball';
    desk.append(ball);
    const from = { x: (m.ball.x1 + m.ball.x2) / 2, y: (m.ball.y1 + m.ball.y2) / 2 }, to = { x: actor.x, y: actor.y - 24 };
    const mid = { x: (from.x + to.x) / 2, y: Math.min(from.y, to.y) - 40 };
    const frames = [];
    for (let i = 0; i <= 12; i++) { const t = i / 12, k = EASE.in(t); frames.push({ transform: `translate(${(1 - k) * (1 - k) * from.x + 2 * (1 - k) * k * mid.x + k * k * to.x}px,${(1 - k) * (1 - k) * from.y + 2 * (1 - k) * k * mid.y + k * k * to.y}px) rotate(${t * 540}deg)` }); }
    await ball.animate(frames, { duration: REDUCED ? 200 : 520, easing: 'linear', fill: 'forwards' }).finished.catch(() => {});
    ball.remove();
    world.flash(to.x, to.y, '#fff', 44);
    actor.el.style.visibility = '';
    actor.place(actor.x, m.ground);
    actor.face(1);
    actor.play('idle', { front: true });
    await actor.clip.animate([{ filter: 'brightness(9)', transform: 'scale(.1)', opacity: 0.2 }, { filter: 'brightness(9)', transform: 'scale(1)', opacity: 1, offset: 0.5 }, { filter: 'brightness(1)', transform: 'scale(1)', opacity: 1 }], { duration: REDUCED ? 100 : 600, easing: 'ease-out' }).finished.catch(() => {});
    log(`${actor.info.name} came out of its Poké Ball.`, 'note');
    actor.play('idle');
    scheduleAmbient();
  }

  /* ------------------------------------------------------------ the controls */

  const ICONS = { spark: 'sparkle', thunderbolt: 'bolt', play: 'note', float: 'cloud', shadowball: 'shadowBall', clone: 'ghost', fly: 'cloud',
    lick: 'saliva', boo: 'exclaim', phase: 'window', snatch: 'cursor', shadowgag: 'shade', prank: 'handprint',
    walkabout: 'foot', nap: 'zzz', climb: 'file', berry: 'pecha', pet: 'heart', hold: 'cursor' };
  const SOFT = new Set(['snatch']);
  const NEEDS = { snatch: 'Needs Gengar (Haunter evolves with a Linking Cord)' };
  const EVERYDAY = [
    ['walkabout', 'Wander', (n) => `${n} wanders off.`, everyday.walkabout],
    ['nap', 'Nap', (n) => `${n} has a nap.`, everyday.nap],
    ['climb', 'Climb a file', (n) => `${n} climbs a file.`, everyday.climb],
    ['berry', 'Feed a berry', (n) => `You give ${n} a berry.`, everyday.berry],
    ['pet', 'Pet it', (n) => `You pet ${n}.`, everyday.pet],
    ['hold', 'Pick up', (n) => `You pick ${n} up.`, everyday.hold],
  ];

  function moveButton(id, label, hint, disabled, why) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'move';
    b.dataset.move = id;
    if (disabled) { b.setAttribute('aria-disabled', 'true'); b.title = why || ''; }
    const ico = document.createElement('span');
    ico.className = 'mi';
    ico.append(Pix.img(ICONS[id] || 'sparkle', 3));
    const txt = document.createElement('span');
    txt.className = 'mt';
    txt.innerHTML = `<b></b><small></small>`;
    $('b', txt).textContent = label;
    $('small', txt).textContent = disabled ? why : hint;
    b.append(ico, txt);
    return b;
  }

  function renderMoves() {
    const f = actor.form, line = FORMS[f].line;
    const sig = $('#sigMoves');
    sig.replaceChildren();
    LISTS[line].forEach((mv) => {
      const off = mv.only && !mv.only.includes(f);
      if (off && !SOFT.has(mv.id)) return;
      const label = f === 'pichu' && mv.label_pichu ? mv.label_pichu : mv.label;
      const b = moveButton(mv.id, label, mv.hint, off, NEEDS[mv.id]);
      b.addEventListener('click', () => {
        if (off) { battle(NEEDS[mv.id]); return; }
        perform(mv.id, mv.run, label);
      });
      sig.append(b);
    });
    const ev = $('#dayMoves');
    ev.replaceChildren();
    EVERYDAY.forEach(([id, label, line, run]) => {
      const b = moveButton(id, label, '', false);
      $('small', b).remove();
      b.classList.add('chip');
      b.addEventListener('click', () => perform(id, run, label, { line: line(actor.info.name) }));
      ev.append(b);
    });
    $('#line-tag').textContent = line === 'pichu' ? 'Electric' : 'Ghost / Poison';
  }

  function renderParty() {
    $$('#party-row [data-form]').forEach((b) => b.setAttribute('aria-pressed', b.dataset.form === actor.form ? 'true' : 'false'));
  }

  function renderFiles() {
    const list = $('#fileStates');
    list.replaceChildren();
    files.forEach((f) => {
      const li = document.createElement('li');
      li.className = f.trashed ? 'in-trash' : 'on-desk';
      const name = document.createElement('span');
      name.className = 'fn';
      name.textContent = f.name;
      const pill = document.createElement('span');
      pill.className = 'pill';
      pill.textContent = f.trashed ? 'In the Trash' : 'On the desktop';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'linkbtn';
      btn.textContent = 'Put back';
      btn.hidden = !f.trashed;
      btn.addEventListener('click', () => putBack(f));
      li.append(name, pill, btn);
      list.append(li);
    });
    const any = files.some((f) => f.trashed);
    if (!any) trashIcon.classList.remove('full');
  }

  function putBack(f) {
    f.trashed = false;
    f.el.classList.remove('gone');
    f.el.classList.add('back');
    setTimeout(() => f.el.classList.remove('back'), 500);
    log(`${f.name} was put back.`, 'note');
    renderFiles();
  }

  /* ------------------------------------------------------------ your Mac */

  function renderMac() {
    const ms = state.mac;
    $('.m-batt .pct', desk).textContent = ms.battery + '%';
    $('.m-batt', desk).dataset.state = ms.charging ? 'charging' : ms.battery <= 10 ? 'low' : 'ok';
    $('.m-batt i', desk).style.width = Math.max(6, ms.battery) + '%';
    $('.m-wifi', desk).dataset.state = ms.wifi ? 'on' : 'off';
    $('.m-cam', desk).dataset.state = ms.camera ? 'on' : 'off';
    $('.m-heat', desk).hidden = !ms.hot;
    $$('[data-mac]').forEach((b) => {
      const k = b.dataset.mac;
      const on = { charger: ms.charging, wifi: !ms.wifi, camera: ms.camera, away: ms.away, hot: ms.hot, battery: ms.battery <= 10 }[k];
      if (on !== undefined) b.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    const labels = {
      charger: ms.charging ? 'Unplug the charger' : 'Plug in the charger', wifi: ms.wifi ? 'Drop the Wi-Fi' : 'Wi-Fi comes back',
      camera: ms.camera ? 'Turn the camera off' : 'Turn the camera on', away: ms.away ? 'Back at the Mac' : 'Step away for 5 minutes',
      hot: ms.hot ? 'Let it cool down' : 'Mac runs hot', battery: ms.battery <= 10 ? 'Battery back to 86%' : 'Battery drops to 4%',
    };
    $$('[data-mac]').forEach((b) => { const l = labels[b.dataset.mac]; if (l) $('b', b).textContent = l; });
  }

  const macEvents = {
    charger() {
      state.mac.charging = !state.mac.charging;
      if (state.mac.charging) { state.mac.battery = Math.max(state.mac.battery, 12); renderMac(); perform('charger', mac.charger, 'Charger', { line: 'Charger plugged in.', keepDown: true, status: 'charging' }); }
      else { renderMac(); log('Charger unplugged.', 'note'); battle('Charger unplugged.'); }
    },
    battery() {
      if (state.mac.battery <= 10) { state.mac.battery = 86; renderMac(); log('Battery back to 86%.', 'note'); perform('recover', async (a) => { await st.recover(a); a.hearts(); await a.once('pose'); }, 'Recover', { line: `${actor.info.name} perks up.`, keepDown: true }); return; }
      state.mac.battery = 4;
      state.mac.charging = false;
      renderMac();
      perform('lowbattery', mac.lowbattery, 'Low battery', { line: 'Battery at 4%.', status: 'out of juice' });
    },
    hot() {
      state.mac.hot = !state.mac.hot;
      renderMac();
      if (state.mac.hot) perform('hot', mac.hot, 'Heat', { line: 'The Mac is running hot.' });
      else { log('The Mac cooled down.', 'note'); battle('The Mac cooled down.'); }
    },
    wifi() {
      state.mac.wifi = !state.mac.wifi;
      renderMac();
      if (!state.mac.wifi) perform('offline', mac.offline, 'Offline', { line: 'Wi-Fi dropped.' });
      else perform('online', mac.online, 'Online', { line: 'Wi-Fi is back.' });
    },
    camera() {
      state.mac.camera = !state.mac.camera;
      renderMac();
      if (state.mac.camera) { battle('Camera on. Back into the ball.'); log('Camera turned on.', 'act'); recall(); }
      else { log('Camera turned off.', 'act'); battle('Camera off.'); sendOut(); }
    },
    away() {
      state.mac.away = !state.mac.away;
      renderMac();
      if (state.mac.away) perform('away', mac.away, 'Away', { line: 'You stepped away.', status: 'napping while you are away' });
      else perform('back', mac.back, 'Back', { line: 'You are back at the Mac.', keepDown: true });
    },
    music() { perform('music', mac.music, 'Music', { line: 'Music is playing.' }); },
  };

  /* ------------------------------------------------------------ hooks */

  const termEl = $('#termOut');
  function term(line, cls) {
    const row = document.createElement('div');
    row.className = cls || '';
    row.textContent = line;
    termEl.append(row);
    termEl.scrollTop = termEl.scrollHeight;
  }
  const HOOKS = {
    pass() {
      term('$ make test', 'cmd'); term('all tests passed (sample output)', 'ok'); term('$ pokepets celebrate', 'cmd');
      perform('celebrate', hooks.celebrate, 'celebrate', { line: '$ pokepets celebrate' });
    },
    fail() {
      term('$ make test', 'cmd'); term('make: *** [test] Error 1 (sample output)', 'bad'); term('$ pokepets fail', 'cmd');
      perform('fail', hooks.fail, 'fail', { line: '$ pokepets fail', keepDown: true });
    },
    done() { term('$ pokepets done', 'cmd'); perform('done', hooks.done, 'done', { line: '$ pokepets done' }); },
    hello() { term('$ pokepets hello', 'cmd'); perform('hello', hooks.hello, 'hello', { line: '$ pokepets hello' }); },
  };

  /* ------------------------------------------------------------ the snatched cursor */

  const fakeCursor = () => {
    const el = document.createElement('div');
    el.className = 'fake-cursor';
    el.append(Pix.img('cursor', 3));
    return el;
  };
  st.cursor = {
    grab(a) {
      const el = fakeCursor();
      el.style.cssText = `position:absolute;left:${a.dir * 12 * S}px;top:${-(a.artH || 40) * 0.6}px`;
      a.lift.append(el);
      state.snatched = { el, at: Date.now(), x: world.cursor.x, y: world.cursor.y };
      desk.classList.add('no-cursor');
      a.transient(() => { if (state.snatched && state.snatched.el === el) st.cursor.giveBack(a, false, true); });
    },
    /** Drops the fake cursor where yours is. The real one reappears when you move the mouse. */
    giveBack(a, laughing, quiet) {
      const s = state.snatched;
      if (!s) return;
      state.snatched = null;
      s.el.remove();
      const at = st.cursorPos();
      const drop = fakeCursor();
      drop.style.cssText = `position:absolute;left:0;top:0;transform:translate(${at.x}px,${at.y - 60}px)`;
      world.fx.append(drop);
      drop.animate([{ transform: `translate(${at.x}px,${at.y - 60}px)`, opacity: 0.2 }, { transform: `translate(${at.x}px,${at.y}px)`, opacity: 1 }], { duration: 240, fill: 'forwards' }).finished.then(() => drop.remove(), () => drop.remove());
      if (laughing && !quiet) a.say('Hehe… fine. Move your mouse.', 2.4);
      state.cursorHidden = true;
    },
  };

  /* ------------------------------------------------------------ pointer: hover, pet, pick up */

  let lastPetted = 0;
  desk.addEventListener('pointermove', (e) => {
    const r = desk.getBoundingClientRect();
    world.cursor = { x: e.clientX - r.left, y: e.clientY - r.top, inside: true };
    if (state.cursorHidden && !state.snatched) { state.cursorHidden = false; desk.classList.remove('no-cursor'); }
    if (state.snatched && Date.now() - state.snatched.at > 1400 && Math.hypot(world.cursor.x - state.snatched.x, world.cursor.y - state.snatched.y) > 14) {
      const a = actor;
      a.cancel();
      st.cursor.giveBack(a, true);
      a.run(async (x) => { await x.land(); x.say('Aww, you got it back.', 2); x.play('idle'); });
      return;
    }
    if (!actor.busy && state.out && !drag && !state.mac.away) {
      const now = Date.now();
      if (now - (actor.lastLook || 0) > 400) { actor.lastLook = now; actor.faceToward(world.cursor.x); }
    }
  });
  desk.addEventListener('pointerleave', () => { world.cursor.inside = false; });

  let drag = null;
  actor.spr.addEventListener('pointerenter', () => {
    if (drag || !state.out || state.mood.fainted) return;
    const now = Date.now();
    if (now - lastPetted < 8000) return;
    lastPetted = now;
    actor.hearts();
    if (!actor.busy) { speak(actor, 'petted', 2.2); actor.run(async (a) => { await a.once('pose'); }); }
  });
  actor.spr.addEventListener('pointerdown', (e) => {
    if (!state.out) return;
    e.preventDefault();
    actor.spr.setPointerCapture(e.pointerId);
    clearTimeout(ambientTimer);
    const r = desk.getBoundingClientRect();
    drag = { dx: actor.x - (e.clientX - r.left), dy: actor.y - (e.clientY - r.top), y0: actor.y, moved: false };
    actor.cancel();
    actor.hush();
    actor.play('hurt', { frame: 0 });
    actor.spr.classList.add('held');
    battle(`You pick ${actor.info.name} up.`);
    log(`You picked ${actor.info.name} up.`, 'act');
  });
  actor.spr.addEventListener('pointermove', (e) => {
    if (!drag) return;
    const r = desk.getBoundingClientRect();
    drag.moved = true;
    actor.place(Math.min(Math.max(e.clientX - r.left + drag.dx, 20), m.w - 20), Math.min(Math.max(e.clientY - r.top + drag.dy, 60), m.ground));
  });
  const release = () => {
    if (!drag) return;
    const fall = world.support(actor.x, actor.y) - actor.y;
    drag = null;
    actor.spr.classList.remove('held');
    state.lastAct = Date.now();
    log(`You put ${actor.info.name} down.`, 'act');
    setStatus(`${actor.info.name} is landing`, true);
    actor.run(async (a) => {
      await a.land();
      if (fall > 130 && !a.floats) { speak(a, 'droppedHard', 2.4); await a.once('pain'); }
      else if (fall > 40 && !a.floats) a.say('Whee!', 1.2);
      a.play('idle');
    });
  };
  actor.spr.addEventListener('pointerup', release);
  actor.spr.addEventListener('pointercancel', release);

  /* ------------------------------------------------------------ it has a life of its own */

  let ambientTimer = null;
  const visible = { stage: true };
  function scheduleAmbient() {
    clearTimeout(ambientTimer);
    if (REDUCED || !state.ready) return;
    ambientTimer = setTimeout(ambient, rand(4500, 8500));
  }
  function ambient() {
    if (!visible.stage || document.hidden || actor.busy || !state.out || drag || state.mac.away || state.snatched || state.mood.fainted) return scheduleAmbient();
    if (Date.now() - state.lastAct < 5000) return scheduleAmbient();
    const ghost = FORMS[actor.form].ghost;
    const choice = pick(ghost ? ['walkabout', 'walkabout', 'idle', 'fly', 'nap'] : ['walkabout', 'walkabout', 'idle', 'nap', 'idle']);
    actor.run(async (a) => {
      if (choice === 'idle') { a.play('idle'); a.faceToward(world.cursor.inside ? world.cursor.x : a.x + rand(-1, 1)); await a.wait(rand(2, 4)); }
      else if (choice === 'fly') { const p = st.airSpot(); await a.arc(p.x, p.y, { speed: 180, bob: true }); a.stopBob(); await a.land(); a.play('idle'); }
      else if (choice === 'nap') await everyday.nap(a, st);
      else await everyday.walkabout(a, st);
      a.play('idle');
    });
    setStatus(`${actor.info.name} is hanging about`, false);
  }

  /* ------------------------------------------------------------ wiring */

  $$('#party-row [data-form]').forEach((b) => b.addEventListener('click', () => selectForm(b.dataset.form)));
  $$('[data-mac]').forEach((b) => b.addEventListener('click', () => macEvents[b.dataset.mac] && macEvents[b.dataset.mac]()));
  $$('[data-hook]').forEach((b) => b.addEventListener('click', () => HOOKS[b.dataset.hook]()));
  $('#stop').addEventListener('click', () => {
    actor.cancel();
    if (state.snatched) st.cursor.giveBack(actor, false);
    actor.hush();
    actor.run(async (a) => { await a.land(); a.play('idle'); });
    battle('…');
    log('Stopped. Back to idle.', 'note');
  });
  $('#again').addEventListener('click', () => { if (lastMove) perform(lastMove.id, lastMove.run, lastMove.label, lastMove.opts); });
  $('#restore').addEventListener('click', () => files.filter((f) => f.trashed).forEach(putBack));

  // tabs
  const tabs = $$('[role="tab"]', $('#tabs'));
  tabs.forEach((t) => t.addEventListener('click', () => selectTab(t)));
  $('#tabs').addEventListener('keydown', (e) => {
    const i = tabs.indexOf(document.activeElement);
    if (i < 0 || !['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(e.key)) return;
    e.preventDefault();
    const n = e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 : (i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
    tabs[n].focus();
    selectTab(tabs[n]);
  });
  function selectTab(t) {
    tabs.forEach((x) => { const on = x === t; x.setAttribute('aria-selected', on); x.tabIndex = on ? 0 : -1; $('#' + x.getAttribute('aria-controls')).hidden = !on; });
  }

  // keep everything in place when the stage resizes
  let resizing = null;
  new ResizeObserver(() => {
    clearTimeout(resizing);
    resizing = setTimeout(() => {
      const wasMoving = actor.busy;
      layout();
      if (!wasMoving) actor.place(Math.min(Math.max(actor.x, 40), m.w - 40), world.support(actor.x, actor.y - 6));
    }, 80);
  }).observe(desk);
  new IntersectionObserver((e) => { visible.stage = e[0].isIntersecting; }, { threshold: 0.2 }).observe($('#stage'));

  // sprites first, so the first frame is not blank

  renderMoves();
  renderParty();
  renderFiles();
  renderMac();
  setStatus('Gengar is hanging about', false);
  battle('GENGAR is out and about.');
  log('Gengar is out on the sample desktop.', 'note');
  const startUp = () => { state.ready = true; layout(); scheduleAmbient(); };
  Promise.race([new Promise((r) => setTimeout(r, 900)), new Promise((r) => { const im = new Image(); im.onload = r; im.src = 'assets/sprites/gengar-idle.png'; })]).then(startUp);

  window.PokeStage = {
    st, world, state,
    get actor() { return actor; },
    get form() { return actor.form; },
    select: selectForm,
    perform,
    move(id) {
      const line = FORMS[actor.form].line;
      const mv = (LISTS[line] || []).find((x) => x.id === id);
      if (mv && (!mv.only || mv.only.includes(actor.form))) return perform(mv.id, mv.run, mv.label);
      const ev = EVERYDAY.find((x) => x[0] === id);
      if (ev) return perform(ev[0], ev[3], ev[1], { line: ev[2](actor.info.name) });
      if (HOOKS[id]) return HOOKS[id]();
      if (macEvents[id]) return macEvents[id]();
    },
    layout,
  };
})();
