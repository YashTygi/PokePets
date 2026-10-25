/* The move list. Each script follows the app's own routine for that move (Pikachu.swift, Gengar.swift,
   Companion.swift): the same animations, the same order, the same lines. `st` is the stage (see stage.js). */
(function () {
  'use strict';
  const { rand, pick, EASE, REDUCED } = PokeEngine;

  const VOICE = {
    pichu: {
      woke: ['*yawn* Fully charged!', '{cry}! Good nap!'], petted: ['{cry}~ ♥ That feels nice!', 'Hehe! My cheeks are sparking!'],
      deleted: ['Zap! Did you see that?!', '{cry}! Gone in a flash!'], celebrate: ['{cry} {cry}! We did it!'],
      failed: ['{cry}… ugh… we\'ll get it next time.'], done: ['All done! Great job, partner!'], hello: ['{cry}! Hi there!'],
      playing: ['{cry}! Watch this!', 'Hehe, this is fun!'], ate: ['Yum! That hit the spot!', '{cry}! Delicious!'],
      ateFavourite: ['My favourite!! {cry} {cry}! ♥'], hot: ['So hot… I\'m overheating…'], offline: ['Huh? The signal\'s gone…'],
      online: ['Phew! Back online!'], userBack: ['{cry}! You\'re back! I missed you!'], curious: ['{cry}? What\'s that? What\'s that?'],
      pickedUp: ['{cry} {cry}! Wheee!', 'Higher! Higher!'], droppedHard: ['Ow… that really hurt…'],
    },
    gastly: {
      woke: ['*yawn* Time to haunt!'], petted: ['{cry}… that tickles!', 'Hehe, your hand went right through me!'],
      deleted: ['Gone! Into the shadows!', '{cry}… swallowed whole!'], celebrate: ['{cry}! We did it!'],
      failed: ['{cry}… cursed. Definitely cursed.'], done: ['Done! Now let\'s go prank someone.'], hello: ['{cry}! Boo!'],
      playing: ['{cry}! Watch this!', 'Can\'t catch me!'], ate: ['Mmm! Berries taste better in the dark.'],
      ateFavourite: ['{cry}!! My favourite! ♥'], hot: ['Too hot… I\'m a cold-blooded ghost!'],
      offline: ['The internet vanished… it wasn\'t me!'], online: ['It\'s back! Okay… maybe it WAS me.'],
      userBack: ['{cry}… you\'re back. I hid all your stuff. Just kidding!'], curious: ['Hm? What\'s that? What\'s that?'],
      pickedUp: ['Hey! You can\'t hold a ghost! …Wheee!', '{cry}! I\'m flying!'], droppedHard: ['Ow… wait, ghosts don\'t feel pain. …Ow anyway.'],
    },
  };
  const line = (a, key) => pick(VOICE[a.info.line === 'gastly' ? 'gastly' : 'pichu'][key] || ['…']).replace(/\{cry\}/g, a.info.cry);
  const speak = (a, key, secs) => a.say(line(a, key), secs);

  const sit = (a, secs) => { a.play('idle'); return a.wait(secs); };
  const clampX = (st, x, pad = 0) => Math.min(Math.max(x, st.bounds().x1 + pad), st.bounds().x2 - pad);
  const vanish = (g, after, secs, shrink = true) => setTimeout(() => {
    if (!g.el.isConnected) return;
    g.el.animate([{ opacity: g.el.style.opacity || 1 }, { opacity: 0 }], { duration: secs * 1000, fill: 'forwards' });
    if (shrink) g.lift.animate([{ transform: 'scaleY(1)' }, { transform: 'scaleY(.1)' }], { duration: secs * 1000, fill: 'forwards' });
    setTimeout(() => g.dispose(), secs * 1000 + 30);
  }, after * 1000);
  /** Fades the sprite (the end value stays in its style, so nothing is left running). */
  const fade = (a, from, to, ms) => new Promise((done) => {
    a.spr.style.opacity = to;
    a.spr.animate([{ opacity: from }, { opacity: to }], { duration: ms }).finished.then(done, done);
  });
  /** Slides the sprite up or down inside its clip (sinking into, or rising out of, an edge). */
  const rise = (a, from, to, ms, easing = 'ease-out') => new Promise((done) => {
    a.lift.style.transform = `translateY(${to}px)`;
    if (!ms) return done();
    a.lift.animate([{ transform: `translateY(${from}px)` }, { transform: `translateY(${to}px)` }], { duration: ms, easing }).finished.then(done, done);
  });
  const T = (p, s) => `translate(${p.x}px,${p.y}px) scale(${s})`;
  const curve = (a, c, b, t) => ({ x: (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * b.x, y: (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * b.y });
  /** Animates an effect element along a quadratic arc. */
  const along = (el, a, c, b, secs, { ease = EASE.in, s0 = 1, s1 = 1 } = {}) => {
    const frames = [];
    for (let i = 0; i <= 14; i++) { const t = i / 14, p = curve(a, c, b, ease(t)); frames.push({ transform: T(p, s0 + (s1 - s0) * t) }); }
    return el.animate(frames, { duration: secs * 1000, easing: 'linear', fill: 'forwards' });
  };

  /* ------------------------------------------------------------ everyday */

  const everyday = {
    walkabout: async (a, st) => {
      const x = clampX(st, st.bounds().x1 + rand(0.1, 0.9) * (st.bounds().x2 - st.bounds().x1), 40);
      await a.walk(x, { speed: a.form === 'pichu' ? 70 : 56 });
      await sit(a, rand(1.5, 3));
    },

    nap: async (a) => {
      a.hush();
      const zzz = a.world.pix('zzz', a.x + a.dir * 10 * a.S, a.y - (a.artH || 40) - 4 * a.S, a.S);
      a.transient(() => zzz.remove());
      await a.stay('nap', 4.5);
      zzz.remove();
      await a.once('wake');
      speak(a, 'woke', 2.2);
      await a.once('stretch');
    },

    pet: async (a) => {
      a.hearts();
      speak(a, 'petted', 2.4);
      a.play('pose', { times: 1 });
      await a.wait(0.4);
      a.hearts();
      await a.wait(1.2);
    },

    climb: async (a, st) => {
      const f = st.nextFile(a, true);
      if (!f) { a.say('Nothing to climb. Put a file back!', 2.4); return; }
      const leaps = a.info.line === 'pichu' && a.form !== 'pichu' && a.form !== 'raichu-alola';
      if (!a.floats) await a.walk(f.x - (f.x > a.x ? 1 : -1) * 34 * a.S / 2, { speed: 70 });
      a.faceToward(f.x);
      if (leaps) a.sparks(0.7, 20);                        // Quick Attack: a leap with a spark trail
      if (a.floats) await a.arc(f.x, f.top, { speed: 200, bob: false });
      else await a.jump(f.x, f.top, { anim: leaps ? 'leap' : 'hop' });
      speak(a, 'curious', 2.4);
      await a.stay('idle', 2.4);
      await a.land();
      a.play('idle');
    },

    berry: async (a, st) => {
      const kind = a.info.line === 'pichu' ? 'pecha' : 'oran';       // Pecha is Pichu's favourite
      const x = clampX(st, a.x + (Math.random() < 0.5 ? -1 : 1) * rand(70, 130), 50);
      const gy = st.world.support(x, 0);
      const berry = st.world.pix(kind, x, 0, a.S * 1.5);
      a.transient(() => berry.remove());
      st.world.glide(berry, { x, y: gy - 6 * a.S }, 0.5, { from: { x, y: -20 }, easing: 'cubic-bezier(.5,0,1,.6)' });
      await a.wait(0.55);
      a.faceToward(x);
      await a.walk(x - Math.sign(x - a.x) * 12 * a.S, { speed: 60 });
      a.faceToward(x);
      const eatAnim = a.resolve('Eat') ? 'Eat' : 'Lick';
      for (let bite = 0; bite < 3; bite++) {
        await a.once(eatAnim, { times: 1 });
        berry.style.transform = berry.style.transform.replace(/ scale\([^)]*\)/, '') + ` scale(${1 - 0.3 * (bite + 1)})`;
      }
      berry.remove();
      a.hearts();
      speak(a, a.info.line === 'pichu' ? 'ateFavourite' : 'ate', 2.6);
      await a.once('pose');
    },

    hold: async (a, st) => {
      // Picked up and set down from a height: dangling legs, then the fall (floaters drift down instead).
      const top = { x: clampX(st, st.bounds().x1 + (st.bounds().x2 - st.bounds().x1) * 0.5, 40), y: st.world.size().h * 0.2 };
      a.say('…Wheee!', 1.5);
      a.play('hurt', { frame: 0 });
      await a._move(top.x, top.y, 0.45, { ease: EASE.out });
      await a.wait(0.8);
      speak(a, 'pickedUp', 1.6);
      await a.land();
      if (!a.floats) speak(a, 'droppedHard', 2.2);
      await sit(a, 1);
    },
  };

  /* ------------------------------------------------------------ the Pichu line */

  const sparky = {
    spark: async (a) => {
      const ability = a.form === 'raichu-alola' ? 'Surge Surfer' : 'Lightning Rod';
      a.say(`${ability} is drawing in the power!`, 3);
      a.sparks(0.5, 24);
      await a.once('shock', { times: 2 });
      const stop = a.sparks(null, 6);
      await a.stay('charge', 1.0);
      stop();
      await a.once('shock');
      await a.once('pose');
    },

    thunderbolt: async (a, st) => {
      const f = st.nextFile(a);
      const body = { x: a.x, y: a.y - 16 * a.S };
      const target = f ? { x: f.x, y: f.y } : { x: a.x + a.dir * 30 * a.S, y: a.y - 6 * a.S };
      const big = a.form !== 'pichu';
      a.faceToward(target.x);
      a.say(big ? 'Thunderbolt!' : 'Thunder Shock!', 1.5);
      const stop = a.sparks(null, 10);
      await a.stay('charge', 0.5);
      stop();
      const shocking = a.once('shock', { times: 3 });
      await a.world.bolt(body, target, big ? 2 : 1);
      if (f) st.trash(f, a);
      await shocking;
      // after a zap: thrilled, it trots out and back with a little hop
      speak(a, 'deleted', 2.5);
      a.sparks(0.4, 16);
      await a.once('pose');
      const out = clampX(st, a.x + a.dir * 90, 40), home = a.x;
      await a.walk(out, { speed: 140, rate: 1.6 });
      await a.walk(home, { speed: 140, rate: 1.6 });
      await a.once('pose');
    },

    play: async (a) => {
      speak(a, 'playing', 2);
      const pickOne = pick(['twirl', 'tumble', 'dance', 'stretch']);
      await a.once(pickOne, { times: pickOne === 'dance' ? 1 : 2 });
      await sit(a, 1);
    },
  };

  /* ------------------------------------------------------------ the Gastly line */

  /** Hangs in the air, bobbing, facing you with its tongue out. */
  const hover = async (a, secs) => {
    a.play('idle', { front: true });
    a.startBob();
    await a.wait(secs);
    a.stopBob();
  };

  const spooky = {
    fly: async (a, st) => {
      const hops = Math.floor(rand(2, 5));
      for (let i = 0; i < hops; i++) {
        const p = st.airSpot();
        const d = Math.hypot(p.x - a.x, p.y - a.y);
        const speed = rand(220, 340);
        if (a.form === 'gengar' && d > 160 && !REDUCED) {      // Gengar's shadow clones trail behind it on long flights
          const secs = Math.max(0.55, d / (speed * a.S / 2));
          for (let k = 1; k <= 4; k++) a.later((secs * k) / 5, () => {
            const t = a.shade(a.x, a.y, { opacity: 0.4 });
            vanish(t, 0, 0.5, false);
          });
        }
        await a.arc(p.x, p.y, { speed, bob: true });
        await hover(a, rand(0.8, 2.2));
      }
      await a.land();
      await sit(a, rand(1.5, 2.5));
    },

    shadowball: async (a, st) => {
      const f = st.nextFile(a);
      const target = f ? { x: f.x, y: f.y } : { x: a.x + a.dir * 50 * a.S, y: a.y - 12 * a.S };
      a.faceToward(target.x);
      const dir = a.dir, S = a.S;
      a.say('Shadow Ball!', 1.6);
      a.play('charge');
      const hand = { x: a.x + dir * 13 * S, y: a.y - 14 * S };
      const body = Pix.img('shadowBall', S);                       // the orb is a wrapper that travels; the art inside it spins
      body.style.cssText = `position:absolute;left:0;top:0;margin:${-body.height / 2}px 0 0 ${-body.width / 2}px`;
      const orb = document.createElement('div');
      orb.className = 'orb';
      orb.style.cssText = `position:absolute;left:0;top:0;width:0;height:0;transform:${T(hand, 0.15)}`;
      orb.append(body);
      a.world.fx.append(orb);
      a.transient(() => orb.remove());
      orb.animate([{ transform: T(hand, 0.15) }, { transform: T(hand, 0.6), offset: 0.25 }, { transform: T(hand, 0.5), offset: 0.4 },
        { transform: T(hand, 0.9), offset: 0.7 }, { transform: T(hand, 1) }], { duration: 900, fill: 'forwards' });
      const spin = body.animate([{ transform: 'rotate(0deg)' }, { transform: 'rotate(360deg)' }], { duration: 600, iterations: Infinity, easing: 'steps(8)' });
      await a.wait(0.9);
      a.play('throw', { times: 1 });
      const lift = Math.max(40, Math.hypot(target.x - hand.x, target.y - hand.y) * 0.25);
      const ctrl = { x: (hand.x + target.x) / 2, y: Math.min(hand.y, target.y) - lift };
      along(orb, hand, ctrl, target, 0.45, { s0: 1, s1: 1 });
      await a.wait(0.45);
      // it lands: the file is sucked into the shadow and goes to the Trash
      a.world.flash(target.x, target.y, '#8c40e6', 26);
      if (f) {
        const ghost = st.ghost(f);
        a.transient(() => ghost && ghost.remove());
        if (ghost) {
          ghost.animate([{ transform: ghost.dataset.at + ' scale(1) rotate(0deg)', opacity: 1 }, { transform: ghost.dataset.at + ' scale(.05) rotate(-720deg)', opacity: 0 }],
            { duration: 700, easing: 'ease-in', fill: 'forwards' }).finished.then(() => ghost.remove(), () => ghost.remove());
        }
        st.trash(f, a);
      }
      orb.animate([{ transform: T(target, 1) }, { transform: T(target, 2.2) }], { duration: 350, fill: 'forwards' });
      spin.playbackRate = 2.4;
      await a.wait(0.75);
      // only a wisp is left: it drifts back to be eaten
      const mouth = { x: a.x + dir * 6 * S, y: a.y - 16 * S };
      along(orb, target, { x: (target.x + mouth.x) / 2, y: Math.min(target.y, mouth.y) - 60 }, mouth, 0.6, { ease: EASE.inout, s0: 0.35, s1: 0.35 });
      await a.wait(0.6);
      orb.remove();
      a.hearts();
      await a.once(a.resolve('Eat') ? 'Eat' : 'Lick', { times: 2 });
      speak(a, 'deleted', 2.5);
      await a.once('lick', { front: true });
    },

    clone: async (a, st) => {
      const here = { x: a.x, y: a.y }, S = a.S;
      a.face(1);
      a.play('idle', { front: true });
      a.say('Which one\'s the real me?', 3);
      const offsets = [-1, 1, Math.random() < 0.5 ? -2 : 2].slice(0, Math.random() < 0.5 ? 2 : 3).map((k) => k * 34 * S);
      const spots = offsets.map((o) => ({ x: clampX(st, here.x + o, 30), y: here.y + rand(-6, 6) * S }));
      const shades = spots.map((p) => {
        const g = a.shade(here.x, here.y, { opacity: 0.8, front: true, anim: 'Idle' });
        g.slide(p.x, p.y, 0.35);
        return g;
      });
      await a.wait(2.6);
      if (Math.random() < 0.5) {                                  // the switcheroo
        const i = Math.floor(Math.random() * spots.length);
        shades[i].slide(here.x, here.y, 0.4);
        await a._move(spots[i].x, spots[i].y, 0.4, { ease: EASE.inout });
      }
      await a.wait(1.4);
      shades.forEach((g, i) => vanish(g, i * 0.15, 0.3));
      await a.wait(0.5);
      a.say('Hehe!', 1.5);
      await a.once('lick', { front: true });
      await sit(a, 1.2);
    },

    shadowgag: async (a, st) => {
      const here = { x: a.x, y: a.y }, S = a.S, b = st.bounds();
      const dir = here.x < (b.x1 + b.x2) / 2 ? 1 : -1;
      const away = { x: clampX(st, here.x + dir * 45 * S, 40), y: here.y };
      a.face(-dir);
      a.play('idle', { frame: 0 });
      let sh = a.shade(here.x, here.y, { opacity: 0.6, anim: 'Walk', dir, front: false });
      await a.wait(0.8);
      sh.slide(away.x, away.y, 1.4);                              // it sneaks off
      await a.wait(1.5);
      sh.dispose();
      sh = a.shade(away.x, away.y, { opacity: 0.6, anim: 'Lick', front: true });   // turns and blows a raspberry
      a.face(dir);
      a.say('Hey! Come back!', 2.2);
      if (a.resolve('flinch').name !== 'Idle') await a.once('flinch'); else await a.wait(0.6);
      sh.dispose();
      sh = a.shade(away.x, away.y, { opacity: 0.6, anim: 'Walk', dir: -dir, front: false });   // the chase: they cross over
      sh.slide(here.x, here.y, 0.9);
      await a.walk(away.x, { speed: 140 });
      vanish(sh, 0.2, 0.6);
      a.face(-dir);
      a.say('…Which of us was the shadow?', 3);
      await a.wait(1);
      await sit(a, 2);
    },

    lick: async (a, st) => {
      const c = st.cursorPos(), S = a.S, b = st.bounds(), h = st.world.size().h;
      const spot = { x: clampX(st, c.x + rand(-80, 80), 70), y: Math.min(Math.max(c.y - 70, h * 0.45), h * 0.62) };
      await a.arc(spot.x, spot.y, { speed: 160, bob: true });
      a.stopBob();
      a.say('*lick*', 2);
      a.play('lick', { front: true });
      a.zoom(1.8, 0.35);                                          // leans in to the glass
      const mouth = () => ({ x: a.x, y: a.y - (a.artH || 40) * 0.2 * 1.8 });
      a.later(0.45, () => a.world.saliva(mouth().x, mouth().y));
      const lickLen = a.length('lick');
      a.later(0.45 + lickLen, () => { if (Math.random() < 0.5) a.world.saliva(mouth().x + rand(-12, 12), mouth().y); });
      await a.wait(lickLen * 3);
      a.zoom(1, 0.35);
      await a.wait(0.5);
      a.say('Hehe.', 1.5);
      await a.arc(clampX(st, a.x + (Math.random() < 0.5 ? 1 : -1) * 34 * S, 40), a.y, { speed: 120, bob: true });
      a.stopBob();
      await a.land();
      await sit(a, 1.2);
    },

    boo: async (a, st) => {
      const w = st.windowRect(), S = a.S;
      const x = rand(w.x1 + 60, w.x2 - 60);
      a.hush();
      await fade(a, 1, 0, 160);
      a.place(x, w.y1);                                            // pops up right below the window's top edge
      a.face(1);
      a.play('peek', { front: true });
      const depth = (a.artH || 40) + 2 * S;
      a.clip.classList.add('on');
      a.transient(() => { a.clip.classList.remove('on'); a.lift.style.transform = ''; a.spr.style.opacity = ''; });
      rise(a, depth, depth, 0);
      a.spr.style.opacity = 1;
      rise(a, depth, 0, 350);
      a.say('Boo!', 2);
      st.windowStart();
      await a.wait(rand(1.8, 2.6));
      rise(a, 0, depth, 500, 'ease-in');
      await a.wait(0.55);
      a.spr.style.opacity = 0;
      await a.wait(0.2);
    },

    phase: async (a, st) => {
      const w = st.windowRect(), S = a.S;
      const x1 = rand(w.x1 + 70, w.x2 - 70);
      await a.arc(x1, w.y1, { speed: 190, bob: false });
      a.stopBob();
      // sinks down into the edge it is standing on
      a.clip.classList.add('on');
      a.transient(() => { a.clip.classList.remove('on'); a.lift.style.transform = ''; a.spr.style.opacity = ''; });
      const depth = (a.artH || 40) + 2 * S;
      if (a.resolve('sink')) {
        a.play('sink', { times: 1, frame: 0 });
        rise(a, 0, depth, 900, 'ease-in');
        await a.wait(0.95);
      } else {
        await fade(a, 1, 0, 700);
      }
      a.spr.style.opacity = 0;
      st.windowStart();
      await a.wait(1.2);
      // peeks out of a different spot, grinning
      const x2 = clampX(st, w.x1 + (w.x2 - w.x1) * (x1 - w.x1 > (w.x2 - w.x1) / 2 ? rand(0.15, 0.4) : rand(0.6, 0.85)));
      a.place(x2, w.y1);
      a.play('idle', { front: true });
      rise(a, depth, depth, 0);
      a.spr.style.opacity = 1;
      a.say('Hehe…', 2.2);
      await rise(a, depth, depth * 0.3, 600);
      await a.wait(2.4);
      await rise(a, depth * 0.3, 0, 500);
      a.clip.classList.remove('on');                               // climbs all the way out
      await sit(a, 0.6);
      await a.land();
      await sit(a, 1);
    },

    snatch: async (a, st) => {
      const c = st.cursorPos(), S = a.S;
      await a.arc(clampX(st, c.x - 18 * S, 50), Math.max(c.y - 4 * S, 50), { speed: 220, bob: true });
      a.stopBob();
      a.faceToward(c.x);
      a.play('pull', { times: 3 });
      a.say('Got it!', 1.6);
      await a.wait(a.length('pull') * 3);
      st.cursor.grab(a);                                           // your real cursor is hidden; Gengar carries a fake one
      a.say('Kekeke… your cursor, my cursor.', 3);
      for (let i = 0; i < 2; i++) {
        const p = st.airSpot();
        await a.arc(p.x, p.y, { speed: 200, bob: true });
        await hover(a, rand(1, 1.6));
      }
      st.cursor.giveBack(a, true);
      await a.land();
      await sit(a, 1);
    },

    prank: async (a, st) => {
      const choices = ['tickle', 'tug', 'hands'];
      const which = pick(choices);
      const S = a.S;
      if (which === 'tickle') {
        const d = st.dockRect();
        const spot = { x: rand(d.x1 + 40, d.x2 - 40), y: d.y1 + 2 * S };
        await a.arc(spot.x, spot.y, { speed: 160, bob: true });
        a.stopBob();
        a.say('Tickle tickle!', 2.5);
        st.dockJiggle();
        a.world.hearts(a.x, a.y - 40);
        await a.once('swing', { times: 3 });
      } else if (which === 'tug') {
        const w = st.windowRect(), right = Math.random() < 0.5;
        await a.arc(right ? w.x2 - 6 * S : w.x1 + 6 * S, w.y1 - 2 * S, { speed: 170, bob: true });
        a.stopBob();
        a.face(right ? 1 : -1);
        a.say('Nngh… come… here…!', 3);
        st.windowTug();
        await a.once('pull', { times: 3 });
        a.say('Oof! Too heavy.', 2.5);
        await a.once('trip');
      } else {
        const c = st.cursorPos(), b = st.bounds();
        const startX = clampX(st, c.x - 80, 60), y = Math.max(60, Math.min(c.y, st.world.size().h * 0.6));
        const dir = startX < (b.x1 + b.x2) / 2 ? 1 : -1, count = Math.floor(rand(4, 7));
        await a.arc(startX, y, { speed: 170, bob: true });
        a.stopBob();
        a.say('Pat pat pat…', 2.5);
        for (let i = 0; i < count; i++) {
          const p = { x: startX + dir * i * 16 * S, y: y + 6 * S + (i % 2 === 0 ? 4 : -4) * S };
          const hand = a.world.pix('handprint', p.x, p.y, S);
          if (i % 2) hand.style.transform += ' scaleX(-1)';
          hand.animate([{ opacity: 0 }, { opacity: 0.85 }], { duration: 120, fill: 'forwards' });
          a.world.flash(p.x, p.y, '#9070d8', 10);
          setTimeout(() => hand.animate([{ opacity: 0.85 }, { opacity: 0 }], { duration: 1500, fill: 'forwards' }).finished.then(() => hand.remove(), () => hand.remove()), 3200);
          await a.wait(0.22);
        }
        await a.wait(0.6);
      }
      a.say('Hehehe!', 2);
      await a.once('lick', { front: true });
      await a.land();
      await sit(a, 1);
    },
  };

  /* ------------------------------------------------------------ hooks (`pokepets celebrate` …) */

  const hooks = {
    celebrate: async (a) => {
      speak(a, 'celebrate', 2.4);
      if (a.info.line === 'pichu') {
        a.sparks(0.6, 24);
        await a.once('shock', { times: 2 });
      } else a.hearts();
      await a.once('pose');
    },
    fail: async (a, st) => {
      speak(a, 'failed', 3);
      st.mood.fainted = true;
      await a.land();
      await a.once('faint');
      await a.wait(5);
      await st.recover(a);
    },
    done: async (a) => {
      speak(a, 'done', 2.4);
      a.hearts();
      await a.once('pose');
      await sit(a, 2);
    },
    hello: async (a) => {
      speak(a, 'hello', 2.2);
      a.hearts();
      await a.once('pose');
    },
  };

  /* ------------------------------------------------------------ your Mac */

  const mac = {
    charger: async (a, st) => {
      st.mood.fainted = false;
      if (a.info.line === 'pichu') return sparky.spark(a, st);
      a.say('Ooh, power!', 2);
      await a.once('pose');
    },
    lowbattery: async (a, st) => {
      a.say('So… tired…', 2);
      await a.land();
      await a.once('pain');
      st.mood.fainted = true;
      await a.once('faint');
    },
    hot: async (a) => {
      speak(a, 'hot', 3);
      a.play('hurt', { frame: 0 });
      await a.wait(1.6);
      await sit(a, 1);
    },
    offline: async (a) => {
      speak(a, 'offline', 3);
      a.play('hurt', { frame: 0 });
      await a.wait(1.8);
    },
    online: async (a) => {
      speak(a, 'online', 2.4);
      a.hearts();
      await a.once('pose');
    },
    away: async (a) => {
      a.hush();
      await a.land();
      const zzz = a.world.pix('zzz', a.x + a.dir * 10 * a.S, a.y - (a.artH || 40) - 4 * a.S, a.S);
      a.transient(() => zzz.remove());
      a.play('sleep');
      await a.wait(3600);                                          // stays curled up until you are back (the stage cancels this)
    },
    back: async (a) => {
      await a.once('wake');
      speak(a, 'userBack', 3);
      a.hearts();
      await a.once('stretch');
    },
    music: async (a) => {
      const note = a.world.pix('note', a.x + 14 * a.S, a.y - (a.artH || 40) - 2 * a.S, a.S);
      a.transient(() => note.remove());
      await a.once('dance', { times: 2 });
      note.remove();
      await a.once('twirl');
    },
  };

  const LISTS = {
    pichu: [
      { id: 'spark', label: 'Spark', hint: 'Cheeks crackle, then it charges up', run: sparky.spark },
      { id: 'thunderbolt', label: 'Thunderbolt', hint: 'Zaps a file into the Trash', run: sparky.thunderbolt, fileMove: true,
        label_pichu: 'Thunder Shock' },
      { id: 'play', label: 'Play', hint: 'Twirl, tumble or dance', run: sparky.play },
      { id: 'float', label: 'Float', hint: 'Drifts about in the air', run: spooky.fly, only: ['raichu-alola'] },
    ],
    gastly: [
      { id: 'shadowball', label: 'Shadow Ball', hint: 'Swallows a file into the Trash', run: spooky.shadowball, fileMove: true },
      { id: 'clone', label: 'Clone', hint: 'Shadow copies, one is real', run: spooky.clone },
      { id: 'fly', label: 'Fly', hint: 'Levitate: anywhere on screen', run: spooky.fly },
      { id: 'lick', label: 'Lick', hint: 'Licks your screen', run: spooky.lick },
      { id: 'boo', label: 'Boo!', hint: 'Head pops out of a window', run: spooky.boo },
      { id: 'phase', label: 'Phase', hint: 'Sinks into a window and back', run: spooky.phase },
      { id: 'snatch', label: 'Steal cursor', hint: 'Needs Gengar', run: spooky.snatch, only: ['gengar'] },
      { id: 'shadowgag', label: 'Shadow', hint: 'Its shadow runs off', run: spooky.shadowgag },
      { id: 'prank', label: 'Prank', hint: 'Dock, window or handprints', run: spooky.prank },
    ],
  };

  window.PokeMoves = { everyday, hooks, mac, LISTS, VOICE, line, speak };
})();
