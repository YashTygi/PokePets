/* The Pokémon you were playing with follows you down the page, like it follows you around the desktop:
   it wanders along the bottom of the window and hops up onto cards. Off under reduced motion (it just naps). */
(function () {
  'use strict';
  const root = document.getElementById('roam');
  const toggle = document.getElementById('companionToggle');
  if (!root || !window.PokeStage || !toggle) return;
  const { World, Actor, FORMS, REDUCED, rand, pick } = PokeEngine;
  const S = 2;

  let enabled = true;
  try { enabled = localStorage.getItem('pokepets.companion') !== 'off'; } catch (e) { /* private window: carry on */ }
  const stageEl = document.getElementById('stage');
  let stageInView = true, out = false, perch = null, timer = null, actor = null;

  const perches = () => [...document.querySelectorAll('.lineCard, .mod, .vs, .flow, .trickList li, .installGrid aside, .tableWrap, .promises, .faq details')]
    .map((el) => ({ el, r: el.getBoundingClientRect() }))
    .filter(({ r }) => r.width >= 160 && r.top > 110 && r.top < innerHeight - 90);

  const world = new World(root, {
    scale: S,
    size: () => ({ w: innerWidth, h: innerHeight }),
    ground: () => innerHeight - 4,
    surfaces: () => perches().map(({ r }) => ({ x1: r.left + 8, x2: r.right - 8, y: r.top })),
  });

  function make() {
    actor = new Actor(world, PokeStage.form, Math.min(Math.max(innerWidth * rand(0.2, 0.8), 60), innerWidth - 60), innerHeight - 4);
    actor.el.style.visibility = 'hidden';
    actor.onIdle = () => schedule();
    actor.spr.addEventListener('pointerenter', pet);
    actor.spr.addEventListener('click', pet);
  }

  let lastPet = 0;
  function pet() {
    if (Date.now() - lastPet < 3000 || !out) return;
    lastPet = Date.now();
    actor.hearts();
    if (!actor.busy) actor.run(async (a) => { PokeMoves.speak(a, 'petted', 2); await a.once('pose'); });
  }

  async function appear() {
    if (out || !enabled) return;
    out = true;
    if (actor.form !== PokeStage.form) { actor.setForm(PokeStage.form); }
    actor.place(Math.min(Math.max(actor.x, 60), innerWidth - 60), innerHeight - 4);
    actor.el.style.visibility = '';
    actor.play(REDUCED ? 'sleep' : 'idle');
    if (!REDUCED) {
      world.flash(actor.x, actor.y - 28, '#fff', 34);
      actor.clip.animate([{ filter: 'brightness(9)', transform: 'scale(.1)' }, { filter: 'brightness(1)', transform: 'scale(1)' }], { duration: 450, easing: 'ease-out' });
    }
    schedule();
  }

  async function disappear() {
    if (!out) return;
    out = false;
    perch = null;
    clearTimeout(timer);
    actor.cancel();
    if (!REDUCED) {
      world.flash(actor.x, actor.y - 28, '#fff', 30);
      await actor.clip.animate([{ filter: 'brightness(9)', transform: 'scale(1)', opacity: 1 }, { filter: 'brightness(9)', transform: 'scale(.05)', opacity: 0 }], { duration: 320, easing: 'ease-in' }).finished.catch(() => {});
    }
    actor.el.style.visibility = 'hidden';
  }

  function sync() {
    const want = enabled && !stageInView && !document.hidden;
    if (want) appear(); else disappear();
    toggle.setAttribute('aria-pressed', enabled ? 'true' : 'false');
    toggle.querySelector('.cmp-label').textContent = enabled ? 'Companion on' : 'Companion off';
  }

  function schedule() {
    clearTimeout(timer);
    if (REDUCED || !out) return;
    timer = setTimeout(act, rand(2500, 6000));
  }

  /** What it does next: wander, sit, nap, or hop up onto a card. */
  function act() {
    if (!out || actor.busy || document.hidden) return schedule();
    const options = perches();
    const roll = Math.random();
    if (perch) { descend(); return; }
    if (roll < 0.38 && options.length) {
      const pick1 = pick(options);
      const x = Math.min(Math.max(pick1.r.left + rand(0.2, 0.8) * pick1.r.width, 40), innerWidth - 40);
      actor.run(async (a) => {
        if (!a.floats) await a.walk(Math.min(Math.max(x + rand(-80, 80), 40), innerWidth - 40), { speed: 70 });
        if (a.floats) await a.arc(x, pick1.r.top, { speed: 170, bob: false });
        else await a.jump(x, pick1.r.top, { anim: 'hop' });
        perch = { el: pick1.el, dx: x - pick1.r.left };
        a.play('idle');
        await a.wait(rand(5, 9));
        await descendNow(a);
      });
    } else if (roll < 0.62) {
      actor.run(async (a) => { await a.walk(Math.min(Math.max(a.x + rand(-260, 260), 40), innerWidth - 40), { speed: 60 }); a.play('idle'); await a.wait(rand(1, 3)); });
    } else if (roll < 0.8) {
      actor.run(async (a) => { await PokeMoves.everyday.nap(a, { world }); });
    } else {
      actor.run(async (a) => { a.play('idle'); a.faceToward(a.x + rand(-1, 1)); await a.wait(rand(2, 4)); });
    }
  }

  async function descendNow(a) {
    perch = null;
    await a.land();
    a.play('idle');
  }
  function descend() { actor.run(async (a) => { await descendNow(a); }); }

  // while it sits on a card, it rides along as the page scrolls; if the card leaves, it hops back down
  let ticking = false;
  addEventListener('scroll', () => {
    if (!out || !perch || ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      if (!perch || !out) return;
      if (actor.busy && actor.mv) return;
      const r = perch.el.getBoundingClientRect();
      if (r.top < 90 || r.top > innerHeight - 60 || !actor.busy) {
        if (r.top < 90 || r.top > innerHeight - 60) { descend(); return; }
      }
      actor.place(r.left + perch.dx, r.top);
    });
  }, { passive: true });

  addEventListener('resize', () => { if (out && !actor.mv) actor.place(Math.min(actor.x, innerWidth - 40), world.support(actor.x, actor.y - 6)); });
  document.addEventListener('visibilitychange', sync);
  addEventListener('pokeform', () => { if (!actor) return; actor.setForm(PokeStage.form); if (out) actor.play('idle'); });

  toggle.addEventListener('click', () => {
    enabled = !enabled;
    try { localStorage.setItem('pokepets.companion', enabled ? 'on' : 'off'); } catch (e) { /* fine */ }
    sync();
  });

  new IntersectionObserver((e) => { stageInView = e[0].intersectionRatio > 0.35; sync(); }, { threshold: [0, 0.35, 0.7] }).observe(stageEl);

  make();
  sync();
})();
