document.querySelectorAll('[data-switch]').forEach((root) => {
  const tabs = [...root.querySelectorAll('[role="tab"]')];
  const select = (tab, focus) => {
    tabs.forEach((t) => {
      const on = t === tab;
      t.setAttribute('aria-selected', String(on));
      t.tabIndex = on ? 0 : -1;
      document.getElementById(t.getAttribute('aria-controls')).hidden = !on;
    });
    if (focus) tab.focus({ preventScroll: true });
  };
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => select(tab, false));
    tab.addEventListener('keydown', (event) => {
      const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key];
      if (!step) return;
      event.preventDefault();
      select(tabs[(index + step + tabs.length) % tabs.length], true);
    });
  });
});

document.querySelectorAll('[data-loop]').forEach((el) => {
  const btn = el.querySelector('[data-loop-toggle]');
  const s = { seen: false, hover: false, focus: false, held: matchMedia('(prefers-reduced-motion: reduce)').matches };
  const sync = () => {
    const run = s.seen && !s.focus && !s.held;
    el.classList.toggle('is-running', run);
    el.querySelectorAll('video').forEach((v) => (run ? v.play().catch(() => {}) : v.pause()));
    btn.textContent = s.held ? 'Play' : 'Pause';
  };
  btn.addEventListener('click', () => { s.held = !s.held; sync(); });
  el.addEventListener('focusin', (e) => { if (e.target !== btn) { s.focus = true; sync(); } });
  el.addEventListener('focusout', () => { s.focus = false; sync(); });
  new IntersectionObserver(([e]) => { s.seen = e.isIntersecting; sync(); }, { threshold: 0.4 }).observe(el);
});

document.querySelectorAll('[data-demo]').forEach((demo) => {
  const face = demo.querySelector('.morph');
  const img = demo.querySelector('.demo__screen img');
  const hot = demo.querySelector('.demo__hot');
  const status = demo.querySelector('[role="status"]');
  const label = demo.querySelector('#tray-label');
  const chips = [...demo.querySelectorAll('.chip')];
  let touched = false;
  const say = (text) => { label.textContent = text; };
  const focusOn = (el) => { if (touched && el) el.focus({ preventScroll: true }); };
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dir = 'images/app/';
  const kinds = {
    photo: { shot: 'photo', name: 'Beach day.heic', over: [79.5, 6], top: 30.62, gap: 12.375, height: 9.01, actions: [['imageToJPG', 'Convert to JPG'], ['imageToPNG', 'Convert to PNG'], ['shrinkImage', 'Make smaller'], ['imagesToPDF', 'Turn into a PDF']] },
    pdfs: { shot: 'pdfs', name: 'three PDFs', over: [81, 6], top: 47.45, gap: 11.41, height: 8.31, actions: [['shrinkPDF', 'Make smaller'], ['mergePDFs', 'Combine into one PDF'], ['pdfToJPG', 'Save pages as JPG']] },
    video: { shot: 'video', name: 'Birthday.mov', over: [67.5, 9], top: 48.7, gap: 0, height: 14.34, actions: [['shrinkVideo', 'Make smaller']] },
  };
  let timer = 0;
  let mood = 'idle';

  const show = (shot, alt) => { img.src = `${dir}${shot}.png`; img.alt = alt; };
  const setMood = (next) => { mood = next; face.dataset.mood = next; };
  const spot = (label, top, height, left, width, onPress) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('aria-label', label);
    Object.assign(b.style, { top: `${top}%`, height: `${height}%`, left: `${left}%`, width: `${width}%` });
    b.addEventListener('click', () => { touched = true; onPress(); });
    hot.append(b);
    return b;
  };
  img.addEventListener('load', () => { hot.style.aspectRatio = `${img.naturalWidth} / ${img.naturalHeight}`; });

  const reset = () => {
    clearTimeout(timer);
    hot.replaceChildren();
    setMood('idle');
    show('empty', 'Morph\u2019s window saying Feed me a file');
    spot('Choose files', 68.91, 11.62, 32.4, 35.31, () => eat(chips[0], chips[0].dataset.kind, { x: 0, y: 0 }));
    say('Feed the Morph');
    status.textContent = 'Morph is waiting for a file.';
    focusOn(chips[0]);
  };
  const finish = (action, title) => {
    setMood('happy');
    show(`done-${action}`, `Morph\u2019s window after ${title}, showing the size before and after`);
    spot('Show in Finder', 60, 12, 31.8, 36.6, () => say('On your Mac this opens the folder with the new file'));
    const again = spot('Morph something else', 72.5, 9.5, 28, 44, reset);
    say('Done. Feed it another');
    status.textContent = `Done: ${title}. The new file sits next to the original.`;
    focusOn(again);
  };
  const run = (action, title) => {
    hot.replaceChildren();
    setMood('busy');
    show(`working-${action}`, `Morph\u2019s window working: ${title}`);
    say('Morphing\u2026');
    status.textContent = `Morphing: ${title}.`;
    timer = setTimeout(() => finish(action, title), still ? 300 : 1500);
  };
  const feed = (kind) => {
    const k = kinds[kind];
    clearTimeout(timer);
    hot.replaceChildren();
    setMood('idle');
    show(k.shot, `Morph\u2019s window asking what to do with ${k.name}`);
    const pitch = k.gap || k.height;
    const first = k.actions.map(([action, title], i) => spot(title, k.top + i * k.gap - (pitch - k.height) / 2, pitch, 5, 89.9, () => run(action, title)))[0];
    spot('Start over', k.over[0], k.over[1], 4, 20, reset);
    say('Now pick a button');
    status.textContent = `Morph asks what to do with ${k.name}. Pick a button.`;
    focusOn(first);
    k.actions.forEach(([action]) => { new Image().src = `${dir}working-${action}.png`; new Image().src = `${dir}done-${action}.png`; });
  };

  let eating = false;
  const eat = (chip, kind, from) => {
    if (eating) return;
    touched = true;
    if (still) { chip.style.translate = ''; feed(kind); return; }
    eating = true;
    clearTimeout(timer);
    hot.replaceChildren();
    const c = chip.getBoundingClientRect(), f = face.getBoundingClientRect();
    const dx = from.x + (f.left + f.width / 2) - (c.left + c.width / 2);
    const dy = from.y + (f.top + f.height * 0.68) - (c.top + c.height / 2);
    face.dataset.mood = 'hungry';
    chip.classList.add('is-eaten');
    chip.style.translate = `${dx}px ${dy}px`;
    chip.style.scale = '0.12';
    chip.style.opacity = '0';
    say('Yum');
    status.textContent = `Morph is eating ${kinds[kind].name}.`;
    setTimeout(() => { face.dataset.mood = 'chew'; }, 340);
    setTimeout(() => {
      chip.classList.remove('is-eaten');
      chip.style.transition = 'none';
      chip.style.translate = '';
      chip.style.scale = '';
      void chip.offsetWidth;
      chip.style.transition = '';
      chip.style.opacity = '';
      eating = false;
      feed(kind);
    }, 1020);
  };

  const over = (x, y) => {
    const a = face.getBoundingClientRect(), b = img.getBoundingClientRect();
    return x > Math.min(a.left, b.left) - 24 && x < Math.max(a.right, b.right) + 24 && y > a.top - 24 && y < b.bottom + 24;
  };
  chips.forEach((chip) => {
    let start = null, dragged = false, resting = 'idle', at = { x: 0, y: 0 };
    chip.addEventListener('pointerdown', (e) => { if (e.pointerType === 'touch') return; start = { x: e.clientX, y: e.clientY }; dragged = false; resting = mood; chip.setPointerCapture(e.pointerId); });
    chip.addEventListener('pointermove', (e) => {
      if (!start) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      if (!dragged && Math.hypot(dx, dy) < 6) return;
      dragged = true;
      chip.classList.add('is-dragging');
      at = { x: dx, y: dy };
      chip.style.translate = `${dx}px ${dy}px`;
      face.dataset.mood = over(e.clientX, e.clientY) ? 'hungry' : resting;
    });
    const drop = (e) => {
      if (!start) return;
      const hit = dragged && over(e.clientX, e.clientY);
      start = null;
      chip.classList.remove('is-dragging');
      if (hit) { eat(chip, chip.dataset.kind, at); return; }
      chip.style.translate = '';
      if (dragged) face.dataset.mood = resting;
    };
    chip.addEventListener('pointerup', drop);
    chip.addEventListener('pointercancel', drop);
    chip.addEventListener('click', () => { if (dragged) { dragged = false; return; } eat(chip, chip.dataset.kind, { x: 0, y: 0 }); });
  });

  if (!still) {
    let frame = 0;
    addEventListener('pointermove', (e) => {
      if (frame) return;
      frame = requestAnimationFrame(() => {
        frame = 0;
        const r = face.getBoundingClientRect();
        const dx = e.clientX - (r.left + r.width / 2), dy = e.clientY - (r.top + r.height / 2);
        const reach = Math.min(1, Math.hypot(dx, dy) / 260), angle = Math.atan2(dy, dx);
        face.style.setProperty('--ex', (Math.cos(angle) * reach * 4.5).toFixed(2));
        face.style.setProperty('--ey', (Math.sin(angle) * reach * 4).toFixed(2));
        face.style.setProperty('--lx', (Math.cos(angle) * reach * 7).toFixed(2));
        face.style.setProperty('--ly', (Math.sin(angle) * reach * 5).toFixed(2));
      });
    }, { passive: true });
  }
  reset();
});
