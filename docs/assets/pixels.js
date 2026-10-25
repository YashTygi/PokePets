/* The app's own hand-drawn pixel art (PokePets/Effects.swift, `Pixels`), drawn here from the same
   character grids and palette so the effects on this page are the ones in the app. */
(function () {
  'use strict';
  const PALETTE = {
    k: '#181010', r: '#F83850', p: '#F898B0', w: '#FFFFFF', y: '#F8E800', l: '#FFF8A8', d: '#A81830', g: '#C0C0C8',
    b: '#4880F0', n: '#2848A8', v: '#58B840', P: '#F898C0', Q: '#D05888', R: '#F04030', S: '#A82018', c: '#FFF4D6',
    C: '#E0CC98', U: '#7058D0', V: '#483090', T: '#58C8D8', W: '#2C8898', Y: '#F8E070', Z: '#C0A030', G: '#50C058',
    H: '#2C7838', L: '#9070D8', M: '#5838A0', N: '#F8C838', D: '#281038', E: '#6030A0', F: '#B060F0', I: '#E8C8FF',
    A: '#98CCF0', B: '#D8F0FF',
  };
  const egg = [
    '....kkkk....', '..kkwccckk..', '.kwwccyycck.', '.kwcccyyyck.', 'kwccccccyyck', 'kccyycccccCk', 'kcyyyccccCCk',
    'kccyccccccCk', 'kcccccyyccCk', 'kccccyyyycCk', 'kCcccccccCCk', '.kCcccccCCk.', '.kCCccccCCk.', '..kkCCCCkk..', '....kkkk....',
  ];
  const ART = {
    heart: ['.kk.kk.', 'kwrkrrk', 'krrrrpk', '.krrpk.', '..kpk..', '...k...'],
    oran: ['...kvk..', '..kvvk..', '.kkbbkk.', 'kbwbbbbk', 'kbbbbbbk', 'kbbbbbnk', '.knbbnk.', '..kkkk..'],
    pecha: ['....kv..', '...kvk..', '.kkPPkk.', 'kPwPPPPk', 'kPPPPPQk', 'kPPPPPQk', '.kQPPQk.', '..kkkk..'],
    cheri: ['...kvk..', '..kvvk..', '.kkRRkk.', 'kRwRRRRk', 'kRRRRRRk', 'kRRRRRSk', '.kSRRSk.', '..kkkk..'],
    chesto: ['...kvk..', '..kvvk..', '.kkUUkk.', 'kUwUUUUk', 'kUUUUUVk', 'kUUUUUVk', '.kVUUVk.', '..kkkk..'],
    rawst: ['..kvvk..', '.kvTTvk.', 'kTwTTTTk', 'kTTTTTWk', 'kTTTTTWk', '.kTTTWk.', '..kWWk..', '...kk...'],
    aspear: ['...kvk..', '...kYk..', '..kYYYk.', '.kYwYYYk', 'kYYYYYZk', 'kYYYYYZk', '.kZYYZk.', '..kkkk..'],
    thunderStone: ['...kk...', '..kGGk..', '.kGGyGk.', 'kGGyyGGk', 'kGyyGGHk', '.kGyGHk.', '..kGHk..', '...kk...'],
    linkingCord: ['..kkk...', '.kLLMk..', 'kLk.kMk.', 'kLk..kNk', '.kMk.kNk', '..kMkNk.', '...kNk..', '....k...'],
    shadowBall: ['...kkkk...', '.kkFEEFkk.', '.kFEIDEFk.', 'kFEIDDDEFk', 'kEDDDDDDEk', 'kEDDDDDDEk', 'kFEDDDDEFk', '.kFEDDEFk.', '.kkFEEFkk.', '...kkkk...'],
    saliva: ['....AAAAAAA.....', '..AABBBBBBBAAA..', '.ABBwwBBBBBBBBA.', 'ABBwBBBBBBBBBBBA', 'ABBBBBBBBBBBwBBA', '.ABBBBBBBBBBBBA.', '..AABBBAABBBAA..', '....AAA..AAA....'],
    drip: ['.A.', 'ABA', 'ABA', 'AwA', '.A.'],
    handprint: ['..k.k.k..', '.kLkLkLk.', '.kLkLkLk.', '.kLLLLLk.', 'kkLLLLLk.', 'kLLLLLMk.', '.kLLLLMk.', '..kLLMk..', '...kkk...'],
    egg,
    question: ['.kkk.', 'k...k', '....k', '..kk.', '..k..', '.....', '..k..'],
    exclaim: ['kk', 'kk', 'kk', 'kk', '..', 'kk'],
    zzz: ['kkkk...', '...k...', '..k.kkk', '.k....k', 'kkkk.k.', '....kkk'],
    note: ['...kkk', '...k.k', '...k.k', '.kkk.k', 'kkkk.k', '.kk.kk', '...kkk'],
    file: ['kkkkk..', 'kwwwkk.', 'kwkkwkk', 'kwwwwwk', 'kwkkkwk', 'kwwwwwk', 'kwkkkwk', 'kwwwwwk', 'kkkkkkk'],
    cloud: ['..kkk....', '.kwwwkkk..', 'kwwwwwwwk.', 'kwwwwwwwwk', '.kkkkkkkk.'],
    ghost: ['..kkkkk..', '.kLLLLLk.', 'kLwkLwkLk', 'kLLLLLLLk', 'kLLLkLLLk', 'kLLLLLLLk', 'kLkLLLkLk', '.k.kLk.k.'],
    shade: ['..kkkkk..', '.kEEEEEk.', 'kEEDEEDEk', 'kEEEEEEEk', 'kEEEDEEEk', 'kEEEEEEEk', 'kEkEEEkEk', '.k.kEk.k.'],
    window: ['kkkkkkkkk', 'kwwwwwwwk', 'kkkkkkkkk', 'kwwkwwwwk', 'kwwkwwwwk', 'kwwkwwwwk', 'kkkkkkkkk'],
    cursor: ['k.......', 'kk......', 'kwk.....', 'kwwk....', 'kwwwk...', 'kwwwwk..', 'kwwkkkk.', 'kkwk....', '..kwk...', '..kk....'],
    foot: ['..kkkk..', '.kwwwwk.', '.kwwwwk.', '.kwwwwk.', '..kkkk..', '..kwwk..', '..kwwk..', '...kk...'],
    sparkle: ['..y..', '..l..', 'ylwly', '..l..', '..y..'],
    bolt: ['...ky', '..kyk', '.kyyk', 'kyyyk', '.kyk.', 'kyk..', 'yk...'],
  };

  const cache = {};
  /** A data: URL of one piece of art at 1 px per pixel (scale it with CSS and `image-rendering: pixelated`). */
  function url(name) {
    if (cache[name]) return cache[name];
    const rows = ART[name];
    const c = document.createElement('canvas');
    c.width = rows[0].length;
    c.height = rows.length;
    const g = c.getContext('2d');
    rows.forEach((line, y) => [...line].forEach((ch, x) => {
      if (PALETTE[ch]) { g.fillStyle = PALETTE[ch]; g.fillRect(x, y, 1, 1); }
    }));
    return (cache[name] = c.toDataURL());
  }
  const size = (name) => ({ w: ART[name][0].length, h: ART[name].length });

  /** An <img> of the art, `scale` screen pixels per art pixel. */
  function img(name, scale, className) {
    const el = new Image();
    const s = size(name);
    el.src = url(name);
    el.alt = '';
    el.width = s.w * scale;
    el.height = s.h * scale;
    el.className = 'pix' + (className ? ' ' + className : '');
    el.draggable = false;
    return el;
  }

  window.Pix = { url, size, img, names: Object.keys(ART) };
})();
