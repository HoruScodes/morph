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
  const steps = [...demo.querySelectorAll('.steps li')];
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const dir = 'images/app/';
  const kinds = {
    photo: { shot: 'photo', name: 'Beach day.heic', top: 30.62, gap: 12.375, height: 9.01, actions: [['imageToJPG', 'Convert to JPG'], ['imageToPNG', 'Convert to PNG'], ['shrinkImage', 'Make smaller'], ['imagesToPDF', 'Turn into a PDF']] },
    pdfs: { shot: 'pdfs', name: 'three PDFs', top: 47.45, gap: 11.41, height: 8.31, actions: [['shrinkPDF', 'Make smaller'], ['mergePDFs', 'Combine into one PDF'], ['pdfToJPG', 'Save pages as JPG']] },
    video: { shot: 'video', name: 'Birthday.mov', top: 48.7, gap: 0, height: 14.34, actions: [['shrinkVideo', 'Make smaller']] },
  };
  let timer = 0;
  let mood = 'idle';

  const show = (shot, alt) => { img.src = `${dir}${shot}.png`; img.alt = alt; };
  const setMood = (next) => { mood = next; face.dataset.mood = next; };
  const setStep = (index) => steps.forEach((li, i) => (i === index ? li.setAttribute('aria-current', 'step') : li.removeAttribute('aria-current')));
  const spot = (label, top, height, left, width, onPress) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('aria-label', label);
    Object.assign(b.style, { top: `${top}%`, height: `${height}%`, left: `${left}%`, width: `${width}%` });
    b.addEventListener('click', onPress);
    hot.append(b);
  };
  img.addEventListener('load', () => { hot.style.aspectRatio = `${img.naturalWidth} / ${img.naturalHeight}`; });

  const reset = () => {
    clearTimeout(timer);
    hot.replaceChildren();
    setMood('idle');
    setStep(0);
    show('empty', 'Morph\u2019s window saying Feed me a file');
    status.textContent = 'Morph is waiting for a file.';
  };
  const finish = (action, title) => {
    setMood('happy');
    show(`done-${action}`, `Morph\u2019s window after ${title}, showing the size before and after`);
    spot('Morph something else', 72, 9.5, 28, 44, reset);
    status.textContent = `Done: ${title}. The new file sits next to the original.`;
  };
  const run = (action, title) => {
    hot.replaceChildren();
    setMood('busy');
    setStep(2);
    show(`working-${action}`, `Morph\u2019s window working: ${title}`);
    status.textContent = `Morphing: ${title}.`;
    timer = setTimeout(() => finish(action, title), still ? 300 : 1500);
  };
  const feed = (kind) => {
    const k = kinds[kind];
    clearTimeout(timer);
    hot.replaceChildren();
    setMood('idle');
    setStep(1);
    show(k.shot, `Morph\u2019s window asking what to do with ${k.name}`);
    k.actions.forEach(([action, title], i) => spot(title, k.top + i * k.gap, k.height, 5, 89.9, () => run(action, title)));
    status.textContent = `Morph asks what to do with ${k.name}. Pick a button.`;
    k.actions.forEach(([action]) => { new Image().src = `${dir}working-${action}.png`; new Image().src = `${dir}done-${action}.png`; });
  };

  const over = (x, y) => {
    const a = face.getBoundingClientRect(), b = img.getBoundingClientRect();
    return x > Math.min(a.left, b.left) - 24 && x < Math.max(a.right, b.right) + 24 && y > a.top - 24 && y < b.bottom + 24;
  };
  demo.querySelectorAll('.chip').forEach((chip) => {
    let start = null, dragged = false, resting = 'idle';
    chip.addEventListener('pointerdown', (e) => { start = { x: e.clientX, y: e.clientY }; dragged = false; resting = mood; chip.setPointerCapture(e.pointerId); });
    chip.addEventListener('pointermove', (e) => {
      if (!start) return;
      const dx = e.clientX - start.x, dy = e.clientY - start.y;
      if (!dragged && Math.hypot(dx, dy) < 6) return;
      dragged = true;
      chip.classList.add('is-dragging');
      chip.style.translate = `${dx}px ${dy}px`;
      face.dataset.mood = over(e.clientX, e.clientY) ? 'hungry' : resting;
    });
    const drop = (e) => {
      if (!start) return;
      const hit = dragged && over(e.clientX, e.clientY);
      start = null;
      chip.classList.remove('is-dragging');
      chip.style.translate = '';
      if (hit) feed(chip.dataset.kind); else if (dragged) face.dataset.mood = resting;
    };
    chip.addEventListener('pointerup', drop);
    chip.addEventListener('pointercancel', drop);
    chip.addEventListener('click', () => { if (dragged) { dragged = false; return; } feed(chip.dataset.kind); });
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
