/* PokéPets on the web: the sprite player and the little world it stands in.
   Same idea as the app: every frame flip and every move is a browser animation (Web Animations API),
   so nothing here runs a per-frame loop. A script is an async function; cancelling an actor rejects
   whatever it is awaiting, which unwinds the script and cleans up after it. */
(function () {
  'use strict';
  const SHEETS = window.POKE_SHEETS;
  const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = (list) => list[Math.floor(Math.random() * list.length)];
  const EASE = { inout: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2), in: (t) => t * t, out: (t) => 1 - (1 - t) * (1 - t), lin: (t) => t };

  class Cancelled extends Error {}

  /** What each engine role plays, first one the form has wins (the app's `Sheets`). */
  const ROLES = {
    walk: ['Walk'], idle: ['Idle'], sleep: ['Sleep', 'Idle'], hop: ['Hop', 'Idle'], charge: ['Charge', 'Idle'],
    shock: ['Shock', 'Shoot', 'Attack'], pose: ['Pose', 'Idle'], hurt: ['Hurt', 'Idle'], eat: ['Eat', 'Pose', 'Idle'],
    faint: ['Faint', 'Sleep', 'Idle'], wake: ['Wake', 'Idle'], leap: ['LeapForth', 'Hop', 'Idle'],
    tumble: ['Tumble', 'Rotate', 'Idle'], twirl: ['Rotate', 'Idle'], pain: ['Pain', 'Hurt', 'Idle'],
    stretch: ['DeepBreath', 'Pose', 'Idle'], dance: ['Double', 'Idle'], glide: ['Walk'], peek: ['Idle'], throw: ['Attack', 'Shock'],
    nap: ['Sleep', 'Idle'], flinch: ['Hurt', 'Idle'], lick: ['Lick', 'Idle'], swing: ['Swing', 'Strike', 'Shock'],
    pull: ['Pull', 'Attack', 'Shock'], trip: ['TumbleBack', 'Trip', 'Hurt'], sink: ['Sink'],
  };
  const GHOST_ROLES = {
    glide: ['Float', 'Walk'], peek: ['Head', 'Idle'], nap: ['EventSleep', 'Sleep', 'Idle'], flinch: ['Cringe', 'Hurt'],
    throw: ['MultiStrike', 'Attack', 'Shock'],
  };

  /** Pokédex facts, as the app's species data has them. `floats`: never falls (Levitate, or Alolan Raichu's tail). */
  const FORMS = {
    pichu: { name: 'Pichu', line: 'pichu', dex: 172, type: 'Electric', cry: 'Pichu', floats: false, ghost: false },
    pikachu: { name: 'Pikachu', line: 'pichu', dex: 25, type: 'Electric', cry: 'Pika', floats: false, ghost: false },
    raichu: { name: 'Raichu', line: 'pichu', dex: 26, type: 'Electric', cry: 'Rai', floats: false, ghost: false },
    'raichu-alola': { name: 'Alolan Raichu', line: 'pichu', dex: 26, type: 'Electric / Psychic', cry: 'Rai rai', floats: true, ghost: false },
    gastly: { name: 'Gastly', line: 'gastly', dex: 92, type: 'Ghost / Poison', cry: 'Gas…', floats: true, ghost: true },
    haunter: { name: 'Haunter', line: 'gastly', dex: 93, type: 'Ghost / Poison', cry: 'Hehehe', floats: true, ghost: true },
    gengar: { name: 'Gengar', line: 'gastly', dex: 94, type: 'Ghost / Poison', cry: 'Kekeke', floats: true, ghost: true },
  };

  const CORE = ['Idle', 'Walk', 'Hop', 'Pose', 'Hurt', 'Sleep', 'Float', 'Charge', 'Shock', 'Shoot', 'Attack', 'Eat', 'Wake'];
  const cached = new Map();
  /** Starts fetching a form's sheets (or just the named animations). */
  function preload(form, names) {
    const sheets = SHEETS[form] || {};
    (names || Object.keys(sheets)).forEach((n) => {
      const a = sheets[n];
      if (!a || cached.has(a.f)) return;
      const im = new Image();
      im.src = `assets/sprites/${a.f}.png`;
      cached.set(a.f, im);
    });
  }

  function h(tag, cls, parent) {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (parent) parent.append(el);
    return el;
  }

  /* ---------------------------------------------------------------- the world */

  class World {
    /** `opts`: scale (screen px per art px), size() → {w,h}, ground() → y of the floor, surfaces() → [{x1,x2,y}] */
    constructor(el, opts) {
      this.el = el;
      this.S = opts.scale;
      this.size = opts.size;
      this.ground = opts.ground;
      this.surfaces = opts.surfaces || (() => []);
      this.actors = h('div', 'w-actors', el);
      this.fx = h('div', 'w-fx', el);
      this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
      this.svg.setAttribute('class', 'w-svg');
      this.svg.setAttribute('aria-hidden', 'true');
      el.append(this.svg);
      this.cursor = { x: 0, y: 0, inside: false };
    }

    /** y of the highest surface at or below `y` under `x`. */
    support(x, y) {
      let best = this.ground();
      for (const s of this.surfaces()) if (x >= s.x1 && x <= s.x2 && s.y >= y - 2 && s.y < best) best = s.y;
      return best;
    }

    /** A piece of the app's pixel art centred on (x, y). */
    pix(name, x, y, scale, cls) {
      const el = Pix.img(name, scale || this.S, cls);
      el.style.cssText = `position:absolute;left:0;top:0;margin:${-el.height / 2}px 0 0 ${-el.width / 2}px;transform:translate(${x}px,${y}px)`;
      this.fx.append(el);
      return el;
    }

    /** Moves an effect element from its current spot; resolves when done. */
    glide(el, to, secs, opts = {}) {
      const from = opts.from || to;
      const scale = (v) => (v == null ? '' : ` scale(${v})`);
      const a = el.animate(
        [{ transform: `translate(${from.x}px,${from.y}px)${scale(opts.s0)}`, opacity: opts.o0 ?? 1 },
          { transform: `translate(${to.x}px,${to.y}px)${scale(opts.s1)}`, opacity: opts.o1 ?? 1 }],
        { duration: secs * 1000, easing: opts.easing || 'ease-out', fill: 'forwards' });
      return a.finished.catch(() => {});
    }

    hearts(x, y, n = 4) {
      for (let i = 0; i < n; i++) {
        const el = this.pix('heart', x, y, this.S);
        setTimeout(() => {
          const dx = rand(-14, 14) * this.S / 2;
          const a = this.glide(el, { x: x + dx, y: y - rand(22, 40) * this.S / 2 }, 1.1, { from: { x: x + dx / 3, y }, easing: 'ease-out', o1: 0 });
          a.then(() => el.remove());
        }, i * 130);
      }
    }

    flash(x, y, color, r = 22) {
      const el = h('div', 'w-flash', this.fx);
      el.style.cssText = `left:${x}px;top:${y}px;width:${r * 2}px;height:${r * 2}px;margin:${-r}px 0 0 ${-r}px;background:${color}`;
      el.animate([{ transform: 'scale(.2)', opacity: 0.95 }, { transform: 'scale(1.3)', opacity: 0 }], { duration: 380, easing: 'ease-out' }).finished.then(() => el.remove(), () => el.remove());
    }

    /** A burst of the app's four-point twinkles around (x, y). */
    spark(x, y, spread = 16) {
      const base = { x: x + rand(-spread, spread) * this.S / 2, y: y + rand(-spread, spread) * this.S / 2 };
      const el = this.pix('sparkle', base.x, base.y, this.S);
      const to = { x: base.x + rand(-12, 12) * this.S / 2, y: base.y - rand(6, 20) * this.S / 2 };
      this.glide(el, to, rand(0.35, 0.6), { from: base, o1: 0 }).then(() => el.remove());
    }

    /** A wet lick mark on the "glass" with a few drips, fading after a few seconds. */
    saliva(x, y) {
      const smear = this.pix('saliva', x, y, this.S);
      smear.style.opacity = 0.75;
      smear.animate([{ transform: smear.style.transform + ' scale(.6)' }, { transform: smear.style.transform }], { duration: 150 });
      const parts = [smear];
      const drips = 2 + Math.floor(Math.random() * 2);
      for (let i = 0; i < drips; i++) {
        const from = { x: x + rand(-5, 5) * this.S, y: y - 1 * this.S };
        const d = this.pix('drip', from.x, from.y, this.S);
        d.style.opacity = 0.75;
        parts.push(d);
        setTimeout(() => this.glide(d, { x: from.x, y: from.y + rand(18, 40) * this.S / 2 }, rand(2, 3.2), { from, o0: 0.75, o1: 0.75 }), 400 + i * 500);
      }
      setTimeout(() => parts.forEach((el) => el.animate([{ opacity: 0.75 }, { opacity: 0 }], { duration: 1500, fill: 'forwards' })), 4000);
      setTimeout(() => parts.forEach((el) => el.remove()), 5700);
    }

    /** A crackling zigzag from a to b, flickering. Resolves the moment it lands. */
    bolt(a, b, thick = 1) {
      const NS = 'http://www.w3.org/2000/svg';
      const glow = document.createElementNS(NS, 'path');
      const core = document.createElementNS(NS, 'path');
      glow.setAttribute('class', 'w-bolt-glow');
      core.setAttribute('class', 'w-bolt-core');
      glow.style.strokeWidth = 6 * this.S / 3 * thick + 'px';
      core.style.strokeWidth = 1.8 * this.S / 3 * thick + 'px';
      this.svg.append(glow, core);
      const zigzag = () => {
        const dx = b.x - a.x, dy = b.y - a.y, len = Math.max(1, Math.hypot(dx, dy));
        const nx = -dy / len, ny = dx / len, segs = Math.max(4, Math.round(len / 28));
        let d = `M${a.x} ${a.y}`;
        for (let i = 1; i < segs; i++) {
          const t = i / segs, j = rand(-7, 7) * this.S / 3;
          d += ` L${a.x + dx * t + nx * j} ${a.y + dy * t + ny * j}`;
        }
        return d + ` L${b.x} ${b.y}`;
      };
      [0, 60, 120, 200].forEach((ms, i) => setTimeout(() => {
        const d = zigzag();
        glow.setAttribute('d', d);
        core.setAttribute('d', d);
        glow.style.opacity = core.style.opacity = i === 3 ? 0.5 : 1;
      }, ms));
      setTimeout(() => { glow.remove(); core.remove(); }, 330);
      return new Promise((done) => setTimeout(() => { this.flash(b.x, b.y, '#ffe14d'); done(); }, 80));
    }
  }

  /* ---------------------------------------------------------------- one Pokémon */

  class Actor {
    constructor(world, form, x, y) {
      this.world = world;
      this.S = world.S;
      this.dir = 1;
      this.token = 0;
      this.aborts = new Set();
      this.cleanups = new Set();
      this.el = h('div', 'actor', world.actors);
      this.shadow = h('div', 'a-shadow', this.el);
      this.clip = h('div', 'a-clip', this.el);
      this.lift = h('div', 'a-lift', this.clip);
      this.spr = h('div', 'a-spr', this.lift);
      this.dialog = h('div', 'a-dialog', this.el);
      this.setForm(form);
      this.place(x, y);
      this.play('idle');
    }

    setForm(form) {
      this.form = form;
      this.info = FORMS[form];
      this.roles = this.info.ghost ? GHOST_ROLES : {};
      this.floats = this.info.floats;
      this.shadow.style.width = (this.info.ghost ? 20 : 17) * this.S + 'px';
      this.shadow.style.height = 6 * this.S + 'px';
      this.shadow.style.margin = `${-3 * this.S}px 0 0 ${-(this.info.ghost ? 10 : 8.5) * this.S}px`;
      preload(form, CORE);                                     // the everyday animations now, the rest once the page is idle
      setTimeout(() => preload(form), 2500);
    }

    /** The first animation of `spec` (a role, or an exact SpriteCollab name) this form has. */
    resolve(spec) {
      const sheets = SHEETS[this.form];
      const names = this.roles[spec] || ROLES[spec] || [spec];
      for (const n of names) if (sheets[n]) return { name: n, a: sheets[n] };
      return null;
    }

    place(x, y) {
      this.x = x;
      this.y = y;
      this.el.style.transform = `translate3d(${x}px,${y}px,0)`;
    }

    face(dir) {
      this.dir = dir < 0 ? -1 : 1;
      if (!this.front) this.spr.style.transform = this.dir < 0 ? 'scaleX(-1)' : '';
    }
    faceToward(x) { if (Math.abs(x - this.x) > 3) this.face(x < this.x ? -1 : 1); }

    /* ------ frames */

    /** Plays an animation: `times` loops (default forever), `front` faces you (the Down row), `frame` holds one frame.
        Returns a promise that resolves when it has played `times` times. */
    play(spec, { times = Infinity, rate = 1, front = false, frame = null } = {}) {
      const r = this.resolve(spec) || this.resolve('idle');
      const a = r.a, S = this.S, n = a.t.length, rows = a.rows;
      const row = front ? 0 : rows > 2 ? 2 : 0;
      const ext = front ? a.down : a.right;
      const st = this.spr.style;
      st.width = a.w * S + 'px';
      st.height = a.h * S + 'px';
      st.left = (-a.w * S) / 2 + 'px';
      st.top = -ext[1] * S + 'px';
      st.backgroundImage = `url(assets/sprites/${a.f}.png)`;
      st.backgroundSize = `${a.w * n * S}px ${rows * a.h * S}px`;
      this.front = front;
      this.spr.style.transform = front || this.dir > 0 ? '' : 'scaleX(-1)';
      this.artH = (ext[1] - ext[0]) * S;
      this.dialog.style.top = -(this.artH + 6 * S) + 'px';
      if (this.flip) this.flip.cancel();
      this.flip = null;
      this.current = r.name;
      const y = -row * a.h * S;
      if (frame != null || n === 1) {
        st.backgroundPosition = `${-(frame || 0) * a.w * S}px ${y}px`;
        return Promise.resolve();
      }
      const total = a.t.reduce((s, v) => s + v, 0);
      let at = 0;
      const frames = a.t.map((ticks, i) => {
        const k = { offset: at / total, backgroundPosition: `${-i * a.w * S}px ${y}px`, easing: 'step-end' };
        at += ticks;
        return k;
      });
      frames.push({ offset: 1, backgroundPosition: `${-(n - 1) * a.w * S}px ${y}px` });
      st.backgroundPosition = frames[0].backgroundPosition;
      this.flip = this.spr.animate(frames, { duration: (total / 60) * 1000 / rate, iterations: times, fill: 'both' });
      return this.flip.finished.then(() => {}, () => {});
    }

    /** Seconds one pass of an animation takes. */
    length(spec, rate = 1) {
      const r = this.resolve(spec);
      return r ? r.a.t.reduce((s, v) => s + v, 0) / 60 / rate : 1;
    }

    /* ------ scripts */

    /** Runs a script (an async function of this actor), replacing whatever it was doing. */
    run(script) {
      this.cancel();
      const id = ++this.token;
      this.busy = true;
      return script(this)
        .catch((e) => { if (!(e instanceof Cancelled)) console.error(e); })
        .finally(() => { if (this.token === id) { this.busy = false; this.endTransients(); if (this.onIdle) this.onIdle(); } });
    }

    /** Stops the current script: whatever it awaits rejects, its effects are cleaned up. */
    cancel() {
      this.token++;
      const aborts = [...this.aborts];
      this.aborts.clear();
      aborts.forEach((f) => f());
      this.stopMove();
      this.endTransients();
      this.busy = false;
    }

    /** Runs `fn` in `secs`, unless the script is cut short first. */
    later(secs, fn) {
      const off = () => { clearTimeout(id); this.cleanups.delete(off); };
      const id = setTimeout(() => { this.cleanups.delete(off); fn(); }, secs * 1000);
      this.transient(off);
    }

    /** Leans in to (or back from) the glass: scales about its feet. */
    zoom(to, secs) {
      const from = this.zoomed || 1;
      this.zoomed = to;
      if (this.zoomAnim) this.zoomAnim.cancel();
      this.lift.style.transform = `scale(${to})`;
      this.zoomAnim = this.lift.animate([{ transform: `scale(${from})` }, { transform: `scale(${to})` }], { duration: secs * 1000, easing: 'ease-in-out' });
      this.transient(() => { this.zoomed = 1; this.lift.style.transform = ''; });
    }

    /** Moves in a straight, eased line (no animation of its own). */
    moveTo(x, y, secs, opts) { return this._move(x, y, secs, opts); }

    /** Registers something to undo when the script ends or is cut short (a shade, a clip, a zoom). */
    transient(undo) { this.cleanups.add(undo); return undo; }
    endTransients() {
      const all = [...this.cleanups];
      this.cleanups.clear();
      all.forEach((f) => f());
    }

    /** A promise that rejects as Cancelled if the script is cut short. `setup(done)` returns its own cleanup. */
    _p(setup) {
      return new Promise((resolve, reject) => {
        let off = null;
        const abort = () => { if (off) off(); reject(new Cancelled()); };
        this.aborts.add(abort);
        off = setup(() => { this.aborts.delete(abort); resolve(); });
      });
    }

    wait(secs) { return this._p((done) => { const id = setTimeout(done, secs * 1000); return () => clearTimeout(id); }); }

    /** Plays an animation `times` times and waits for it; leaves its last frame up. */
    once(spec, { times = 1, rate = 1, front = false } = {}) {
      const finished = this.play(spec, { times, rate, front });
      return this._p((done) => { finished.then(done); return null; });
    }

    /** Loops an animation for `secs`. */
    stay(spec, secs, opts = {}) {
      this.play(spec, opts);
      return this.wait(secs);
    }

    /* ------ moving */

    _move(x, y, secs, { arc = 0, ease = EASE.inout } = {}) {
      const from = { x: this.x, y: this.y };
      const path = (t) => { const k = ease(t); return { x: from.x + (x - from.x) * k, y: from.y + (y - from.y) * k - arc * 4 * k * (1 - k) }; };
      const steps = arc || ease !== EASE.lin ? 18 : 1;
      const frames = [];
      for (let i = 0; i <= steps; i++) { const p = path(i / steps); frames.push({ transform: `translate3d(${p.x}px,${p.y}px,0)` }); }
      const anim = this.el.animate(frames, { duration: Math.max(60, secs * 1000), easing: 'linear', fill: 'forwards' });
      this.mv = { anim, path };
      return this._p((done) => {
        anim.finished.then(() => { if (this.mv && this.mv.anim === anim) { this.mv = null; this.place(x, y); anim.cancel(); done(); } }, () => {});
        return null;
      });
    }

    stopMove() {
      if (!this.mv) return;
      const { anim, path } = this.mv;
      this.mv = null;
      const t = anim.effect.getComputedTiming();
      const p = path(Math.min(1, Math.max(0, t.progress == null ? 0 : t.progress)));
      anim.cancel();
      this.place(p.x, p.y);
    }

    /** Walks along the surface to x. */
    async walk(x, { speed = 56, rate = 1 } = {}) {
      this.stopBob();
      this.faceToward(x);
      const secs = Math.abs(x - this.x) / (speed * this.S / 2);
      if (secs < 0.05) return;
      this.play('walk', { rate });
      await this._move(x, this.y, secs, { ease: EASE.lin });
    }

    /** One arc through the air (flying, floating, or a leap). Plays `anim` meanwhile. */
    async arc(x, y, { speed = 160, lift = null, anim = 'glide', rate = 1.4, bob = false, minSecs = 0.55 } = {}) {
      this.faceToward(x);
      const d = Math.hypot(x - this.x, y - this.y);
      const secs = Math.max(minSecs, d / (speed * this.S / 2));
      this.play(anim, { rate });
      if (bob) this.startBob();
      this.shadow.style.opacity = 0;
      await this._move(x, y, secs, { arc: lift == null ? Math.min(70, Math.max(16, d * 0.3)) * this.S / 2 : lift });
    }

    startBob() {
      if (this.bob || REDUCED) return;
      this.bob = this.lift.animate([{ transform: 'translateY(0)' }, { transform: `translateY(${-3 * this.S}px)` }, { transform: 'translateY(0)' }], { duration: 1100, iterations: Infinity, easing: 'ease-in-out' });
      this.transient(() => this.stopBob());
    }
    stopBob() { if (this.bob) { this.bob.cancel(); this.bob = null; } }

    /** Back down onto whatever is below: a fall for ground Pokémon, a slow drift for floaters. */
    async land({ squash = true } = {}) {
      const ground = this.world.support(this.x, this.y);
      this.stopBob();
      if (this.y < ground - 2) {
        const drop = ground - this.y;
        if (this.floats) {
          this.play('glide', { rate: 1 });
          await this._move(this.x, ground, 0.5 + drop / (90 * this.S / 2), { ease: EASE.out });
        } else {
          this.play('hurt', { frame: 0 });
          await this._move(this.x, ground, Math.sqrt((2 * drop) / (1500 * this.S / 2)) + 0.05, { ease: EASE.in });
          if (squash) this.squash();
        }
      }
      this.shadow.style.opacity = '';
    }

    squash() {
      if (REDUCED) return;
      this.lift.animate([{ transform: 'scale(1.12,.8)' }, { transform: 'scale(.96,1.05)', offset: 0.6 }, { transform: 'none' }], { duration: 260, easing: 'ease-out' });
    }

    /** Hop or leap to a spot (a ledge, a file). */
    async jump(x, y, { rate = null, anim = 'hop' } = {}) {
      this.faceToward(x);
      const d = Math.hypot(x - this.x, y - this.y);
      const secs = Math.max(0.5, 0.35 + d / (260 * this.S / 2));
      this.play(anim, { times: 1, rate: rate || this.length(anim) / secs });
      this.shadow.style.opacity = 0;
      await this._move(x, y, secs, { arc: Math.max(24, Math.abs(y - this.y) * 0.5 + 24) * this.S / 2 });
      this.shadow.style.opacity = '';
      this.squash();
    }

    /** Shows what it says in the dialogue box above its head. */
    say(text, secs = 2.6) {
      const d = this.dialog;
      d.textContent = text;
      d.classList.add('on');
      d.style.marginLeft = '0px';
      const box = d.getBoundingClientRect(), wr = this.world.el.getBoundingClientRect();
      const over = Math.max(0, wr.left + 8 - box.left) - Math.max(0, box.right - (wr.right - 8));
      d.style.marginLeft = over + 'px';
      clearTimeout(this.sayTimer);
      this.sayTimer = setTimeout(() => d.classList.remove('on'), secs * 1000);
      if (this.onSay) this.onSay(text);
    }
    hush() { clearTimeout(this.sayTimer); this.dialog.classList.remove('on'); }

    hearts() { this.world.hearts(this.x, this.y - (this.artH || 40) * 0.8); }

    /** Twinkles around the body for `secs`; returns a stopper. */
    sparks(secs, rate = 14) {
      const body = () => ({ x: this.x, y: this.y - (this.artH || 40) / 2 });
      const id = setInterval(() => { const b = body(); this.world.spark(b.x, b.y, (this.artH || 40) / this.S * 0.6); }, 1000 / rate);
      const stop = () => { clearInterval(id); this.cleanups.delete(stop); };
      this.transient(stop);
      if (secs) setTimeout(stop, secs * 1000);
      return stop;
    }

    /** A flat dark copy of the current frame (Gengar's shadow clones). `anim`/`front` default to the current one. */
    shade(x, y, { opacity = 0.8, front = this.front, anim = this.current, dir = this.dir } = {}) {
      const g = new Actor(this.world, this.form, x, y);
      g.el.classList.add('shade');
      g.el.style.opacity = opacity;
      g.shadow.remove();
      g.dialog.remove();
      g.face(dir);
      g.play(anim, { front });
      this.transient(() => g.dispose());
      g.owner = this;
      return g;
    }

    dispose() {
      this.cancel();
      this.hush();
      this.el.remove();
    }

    /** Slides this actor (a shade, usually) on its own; nobody waits for it. */
    slide(x, y, secs) { this._move(x, y, secs, { ease: EASE.inout }).catch(() => {}); }
  }

  window.PokeEngine = { World, Actor, FORMS, ROLES, EASE, Cancelled, preload, rand, pick, REDUCED };
})();
