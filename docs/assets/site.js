/* Page glue: pixel icons, tabs, copy buttons, deep-linked FAQ, and the buttons that ask the sample to do something. */
(function () {
  'use strict';
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // the app's pixel art, wherever the markup asks for it
  $$('[data-pix]').forEach((el) => el.append(Pix.img(el.dataset.pix, +el.dataset.scale || 3)));

  // the little "audience" tabs: same tablist pattern as the sample's
  function tablist(list) {
    const tabs = $$('[role="tab"]', list);
    const select = (t) => tabs.forEach((x) => { const on = x === t; x.setAttribute('aria-selected', on); x.tabIndex = on ? 0 : -1; $('#' + x.getAttribute('aria-controls')).hidden = !on; });
    tabs.forEach((t) => t.addEventListener('click', () => select(t)));
    list.addEventListener('keydown', (e) => {
      const i = tabs.indexOf(document.activeElement);
      if (i < 0 || !['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(e.key)) return;
      e.preventDefault();
      const n = e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 : (i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
      tabs[n].focus();
      select(tabs[n]);
    });
    return select;
  }
  const selectAud = tablist($('#audTabs'));
  const selectInst = tablist($('#instTabs'));
  const audHash = { '#hooks-script': 'a-script', '#hooks-hack': 'a-hack' };

  // copy buttons
  $$('.copy').forEach((b) => b.addEventListener('click', async () => {
    const text = b.dataset.copy.replace(/&#10;/g, '\n');
    try { await navigator.clipboard.writeText(text); b.textContent = 'Copied'; } catch (e) { b.textContent = 'Press ⌘C'; }
    setTimeout(() => { b.textContent = 'Copy'; }, 1600);
  }));

  // FAQ: open the answer a link points at
  function openFaq() {
    const el = location.hash && document.getElementById(location.hash.slice(1));
    if (el && el.tagName === 'DETAILS') el.open = true;
    const key = audHash[location.hash];
    if (key) selectAud($('#' + key));
  }
  addEventListener('hashchange', openFaq);
  openFaq();

  // buttons that ask the sample desktop to do something
  const stageEl = $('#stage');
  function showStage() {
    const r = stageEl.getBoundingClientRect();
    if (r.top < 60 || r.bottom > innerHeight + 40 || r.top > innerHeight * 0.4) stageEl.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
  }
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  async function ask(id, { form } = {}) {
    showStage();
    if (form && PokeStage.form !== form) { await PokeStage.select(form); await wait(250); }
    PokeStage.move(id);
  }
  const zapMove = () => (PokeEngine.FORMS[PokeStage.form].line === 'pichu' ? 'thunderbolt' : 'shadowball');

  $$('[data-trick]').forEach((b) => b.addEventListener('click', () => ask(b.dataset.trick, { form: 'gengar' })));
  $$('[data-send]').forEach((b) => b.addEventListener('click', async () => { showStage(); await PokeStage.select(b.dataset.send); }));
  $$('[data-focus-stage]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); showStage(); }));
  $$('[data-demo]').forEach((b) => b.addEventListener('click', () => {
    const d = b.dataset.demo;
    if (d === 'zap') return ask(zapMove());
    if (d === 'restore') { showStage(); return $('#restore').click(); }
    if (d === 'mac') { showStage(); return $('#t-mac').click(); }
    if (['pass', 'fail', 'done', 'hello'].includes(d)) { $('#t-hooks').click(); return ask(d); }
    return ask(d);
  }));

  // links into a specific install tab (the FAQ points at the DMG steps)
  $$('[data-install-tab]').forEach((a) => a.addEventListener('click', (e) => {
    e.preventDefault();
    selectInst($('#' + a.dataset.installTab));
    $('#install').scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
  }));

  // DMG links show the "macOS will stop it once" steps first; the dialog's own button does the download
  const gk = $('#gk');
  if (gk && gk.showModal) {
    let filled = false;
    $$('a[data-dmg]').forEach((a) => a.addEventListener('click', (e) => {
      e.preventDefault();
      if (!filled) { const steps = $('#dmgSteps').cloneNode(true); steps.removeAttribute('id'); $('#gk-steps').append(steps); filled = true; }
      gk.showModal();
      $('.gk-in', gk).scrollTop = 0;
    }));
    $('#gk-close').addEventListener('click', () => gk.close());
    $('#gk-go').addEventListener('click', () => setTimeout(() => gk.close(), 400));
    gk.addEventListener('click', (e) => { if (e.target === gk) gk.close(); });
  }
})();
