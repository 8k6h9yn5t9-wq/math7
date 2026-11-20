(function () {
  'use strict';
  const { UNITS, pacedUnit, checkNum } = window.M7;
  const $app = document.getElementById('app');
  const SESSION_LEN = 10;

  // ---------- storage ----------
  const KEY = 'm7-data-v1';
  const fresh = () => ({ settings: { pin: null, goal: 10, unitOverride: null, name: '' }, skills: {}, days: {}, log: [], sessions: [] });
  let data;
  try { data = Object.assign(fresh(), JSON.parse(localStorage.getItem(KEY)) || {}); } catch (e) { data = fresh(); }
  data.settings = Object.assign(fresh().settings, data.settings);
  function save() { try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (e) { /* storage full or blocked */ } }
  if (navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});

  const SKILL = {}; const UNIT = {}; const SKILL_UNIT = {};
  UNITS.forEach((u, i) => { u.n = i + 1; UNIT[u.id] = u; u.skills.forEach((s) => { SKILL[s.id] = s; SKILL_UNIT[s.id] = u; }); });

  const todayKey = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const sk = (id) => (data.skills[id] = data.skills[id] || { hist: [], att: 0, cor: 0, level: 1, run: 0 });
  function mastery(id) { const s = data.skills[id]; if (!s || !s.hist.length) return null; return s.hist.reduce((a, b) => a + b, 0) / s.hist.length; }
  function unitMastery(u) {
    // average over all skills; unpracticed skills count as 0 so the bar reflects coverage too
    const vals = u.skills.map((s) => { const m = mastery(s.id); const att = (data.skills[s.id] || {}).att || 0; return m == null ? 0 : m * Math.min(1, att / 5); });
    return vals.reduce((a, b) => a + b, 0) / vals.length;
  }
  function unitAttempts(u) { return u.skills.reduce((a, s) => a + ((data.skills[s.id] || {}).att || 0), 0); }
  const currentUnitId = () => data.settings.unitOverride || pacedUnit();
  function streak() {
    let n = 0; const d = new Date(); const goal = data.settings.goal;
    const met = (k) => (data.days[k] || {}).n >= goal;
    if (!met(todayKey(d))) d.setDate(d.getDate() - 1); // today not done yet doesn't break the streak
    while (met(todayKey(d))) { n++; d.setDate(d.getDate() - 1); }
    return n;
  }
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const plain = (html) => { const d = document.createElement('div'); d.innerHTML = html.replace(/<span class="fr"><span>(.*?)<\/span><span>(.*?)<\/span><\/span>/g, '($1/$2)').replace(/<br>/g, ' ').replace(/<div class="fig">[\s\S]*<\/div>/, ' [figure]'); return d.textContent.replace(/\s+/g, ' ').trim(); };

  // ---------- picking problems ----------
  function weightFor(id) { const m = mastery(id); const att = (data.skills[id] || {}).att || 0; return 1 + (m == null ? 1.5 : (1 - m) * 3) + (att < 3 ? 1 : 0); }
  function weightedPick(ids, avoid) {
    const pool = ids.length > 1 ? ids.filter((i) => i !== avoid) : ids;
    const ws = pool.map(weightFor); let t = ws.reduce((a, b) => a + b, 0) * Math.random();
    for (let i = 0; i < pool.length; i++) { t -= ws[i]; if (t <= 0) return pool[i]; }
    return pool[pool.length - 1];
  }
  function reviewPool() {
    const cur = UNIT[currentUnitId()].n; const ids = [];
    UNITS.forEach((u) => { if (u.n < cur || (u.n === cur)) u.skills.forEach((s) => ids.push(s.id)); });
    return ids;
  }
  function makeProblem(skillId) {
    const s = sk(skillId); const p = SKILL[skillId].gen(s.level || 1); p.skill = skillId; p.level = s.level || 1; return p;
  }

  // ---------- router / views ----------
  let view = { name: 'home' };
  let session = null; // active practice session
  function go(v) { view = v; render(); window.scrollTo(0, 0); }
  function render() {
    if (view.name === 'home') return renderHome();
    if (view.name === 'unit') return renderUnit();
    if (view.name === 'practice') return renderPractice();
    if (view.name === 'summary') return renderSummary();
    if (view.name === 'parent') return renderParent();
  }
  function toast(msg) { const t = document.createElement('div'); t.className = 'toast'; t.textContent = msg; document.body.appendChild(t); setTimeout(() => t.remove(), 1800); }

  // ---------- home ----------
  function renderHome() {
    const cur = UNIT[currentUnitId()]; const today = data.days[todayKey()] || { n: 0, c: 0 };
    const goal = data.settings.goal; const pct = Math.min(100, Math.round(today.n / goal * 100)); const st = streak();
    const standalone = window.navigator.standalone || window.matchMedia('(display-mode: standalone)').matches;
    const isIPad = /iPad|Macintosh/.test(navigator.userAgent) && 'ontouchend' in document;
    const reviewIds = reviewPool().filter((id) => SKILL_UNIT[id].n < cur.n);
    $app.innerHTML = `
      ${!standalone && isIPad ? `<div class="install">📲 <b>Tip:</b> tap the Share button, then <b>Add to Home Screen</b>, to use this like an app (works offline too).</div>` : ''}
      <div class="topbar">
        <div><h1>${data.settings.name ? `Hi, ${esc(data.settings.name)}!` : 'Math 7 Practice'}</h1><div class="muted">${pct >= 100 ? 'Daily goal done. Nice work!' : `Today: ${today.n} of ${goal} problems`}</div></div>
        <div class="row">
          <div class="pill" title="Days in a row reaching the daily goal">🔥 ${st} day${st === 1 ? '' : 's'}</div>
          <div class="ring" style="--p:${pct}"><span>${today.n}/${goal}</span></div>
        </div>
      </div>
      <div class="hero">
        <div><div class="label">In class now · Unit ${cur.n}</div><h2>${cur.name}</h2><div style="opacity:.9">${cur.short}</div></div>
        <button class="btn" data-act="start-unit" data-unit="${cur.id}">▶ Practice ${SESSION_LEN}</button>
      </div>
      <div class="grid section" style="margin-top:14px">
        ${reviewIds.length ? `<button class="card unit" data-act="start-review"><div class="ic">↻</div><div><h3>Review mix</h3><div class="muted">Earlier units, weakest skills first</div></div></button>` : ''}
        <button class="card unit" data-act="start-weak"><div class="ic">🎯</div><div><h3>Fix my mistakes</h3><div class="muted">Skills with the lowest scores</div></div></button>
      </div>
      <div class="section"><h2>All units</h2>
        <div class="grid">
          ${UNITS.map((u) => { const m = unitMastery(u); const att = unitAttempts(u); return `
            <button class="card unit ${u.id === cur.id ? 'now' : ''}" data-act="open-unit" data-unit="${u.id}">
              <div class="ic">${u.icon}</div>
              <div style="flex:1;min-width:0"><h3>${u.n}. ${u.name} ${u.id === cur.id ? '<span class="tag">Now</span>' : m >= 0.8 ? '<span class="tag done">★ Mastered</span>' : ''}</h3>
                <div class="muted" style="font-size:14px">${att ? `${Math.round(m * 100)}% mastery · ${att} solved` : u.short}</div>
                <div class="bar"><i style="width:${Math.round(m * 100)}%"></i></div></div>
            </button>`; }).join('')}
        </div>
      </div>
      <div class="section row spread wrap"><span class="muted" style="font-size:14px">Units follow the class pacing. A parent can change the current unit.</span><button class="btn small" data-act="parent">🔒 Parent</button></div>`;
  }

  function renderUnit() {
    const u = UNIT[view.unit];
    $app.innerHTML = `
      <div class="topbar"><button class="btn small" data-act="home">‹ Back</button><div></div></div>
      <div class="card"><div class="row spread wrap"><div><div class="muted">Unit ${u.n}</div><h1>${u.name}</h1><div class="muted">${u.short}</div></div>
        <button class="btn primary" data-act="start-unit" data-unit="${u.id}">▶ Practice whole unit</button></div></div>
      <div class="section"><h2>Skills</h2><div class="grid">
        ${u.skills.map((s) => { const m = mastery(s.id); const st = data.skills[s.id]; return `
          <button class="card unit" data-act="start-skill" data-skill="${s.id}">
            <div style="flex:1"><h3>${s.name}</h3><div class="muted" style="font-size:14px">${st && st.att ? `${Math.round(m * 100)}% recently · level ${st.level} · ${st.att} tried` : 'Not started yet'}</div>
            <div class="bar"><i style="width:${Math.round((m || 0) * 100)}%"></i></div></div><div class="muted">▶</div>
          </button>`; }).join('')}
      </div></div>`;
  }

  // ---------- practice ----------
  function startSession(kind, arg) {
    let ids, title;
    if (kind === 'unit') { ids = UNIT[arg].skills.map((s) => s.id); title = `Unit ${UNIT[arg].n}: ${UNIT[arg].name}`; }
    else if (kind === 'skill') { ids = [arg]; title = SKILL[arg].name; }
    else if (kind === 'review') { ids = reviewPool().filter((id) => SKILL_UNIT[id].n < UNIT[currentUnitId()].n); title = 'Review mix'; }
    else { // weakest skills that have been practiced; fall back to current unit
      const tried = Object.keys(data.skills).filter((id) => SKILL[id] && data.skills[id].att > 0).sort((a, b) => mastery(a) - mastery(b));
      ids = tried.slice(0, 5); if (!ids.length) ids = UNIT[currentUnitId()].skills.map((s) => s.id); title = 'Fix my mistakes';
    }
    session = { kind, arg, ids, title, i: 0, results: [], start: Date.now(), last: null };
    nextProblem();
    go({ name: 'practice' });
  }
  function nextProblem() {
    const id = weightedPick(session.ids, session.last); session.last = id;
    session.cur = { p: makeProblem(id), input: '', tries: 0, status: 'ask', picked: [], shownAt: Date.now() };
  }
  function record(ok) {
    const c = session.cur; if (c.recorded) return; c.recorded = true;
    const s = sk(c.p.skill); s.att++; if (ok) s.cor++;
    s.hist.push(ok ? 1 : 0); if (s.hist.length > 10) s.hist.shift();
    s.run = (s.run || 0) + 1;
    if (s.run >= 5) { const last5 = s.hist.slice(-5); const acc = last5.reduce((a, b) => a + b, 0) / last5.length; if (acc >= 0.8 && s.level < 3) { s.level++; s.run = 0; } else if (acc <= 0.4 && s.level > 1) { s.level--; s.run = 0; } }
    const k = todayKey(); const d = (data.days[k] = data.days[k] || { n: 0, c: 0, secs: 0 }); d.n++; if (ok) d.c++;
    const a = c.p.a;
    data.log.push({ t: Date.now(), skill: c.p.skill, lvl: c.p.level, ok, tries: c.tries, q: plain(c.p.q), given: c.firstGiven || '', correct: plain(a.type === 'mc' ? a.choices[a.correct] : (a.unit === '$' ? '$' : '') + a.show + (a.unit && a.unit !== '$' ? ' ' + a.unit : '')) });
    if (data.log.length > 400) data.log.splice(0, data.log.length - 400);
    session.results.push(ok);
    save();
  }
  function submitNum() {
    const c = session.cur; if (c.status === 'right' || c.status === 'shown') return;
    if (!c.input || c.input === '-') return;
    c.tries++; if (c.tries === 1) c.firstGiven = c.input.replace(/-/g, '−');
    if (checkNum(c.input, c.p.a)) { c.status = 'right'; record(c.tries === 1); }
    else if (c.tries >= 2) { c.status = 'shown'; c.wrongInput = c.input; record(false); }
    else { c.status = 'wrong'; c.wrongInput = c.input; c.input = ''; }
    renderPractice(true);
  }
  function pickChoice(i) {
    const c = session.cur; if (c.status === 'right' || c.status === 'shown' || c.picked.includes(i)) return;
    c.tries++; c.picked.push(i); if (c.tries === 1) c.firstGiven = plain(c.p.a.choices[i]);
    if (i === c.p.a.correct) { c.status = 'right'; record(c.tries === 1); }
    else if (c.tries >= 2 || c.p.a.choices.length === 2) { c.status = 'shown'; record(false); }
    else c.status = 'wrong';
    renderPractice(true);
  }
  function showMe() { const c = session.cur; if (c.status === 'right' || c.status === 'shown') return; c.status = 'shown'; record(false); renderPractice(true); }
  function advance() {
    session.i++;
    if (session.i >= SESSION_LEN) return finishSession();
    nextProblem(); clearScratch(); renderPractice();
  }
  function finishSession() {
    const secs = Math.round((Date.now() - session.start) / 1000);
    const k = todayKey(); (data.days[k] = data.days[k] || { n: 0, c: 0, secs: 0 }).secs += secs;
    const c = session.results.filter(Boolean).length;
    data.sessions.push({ t: Date.now(), title: session.title, n: session.results.length, c, secs });
    if (data.sessions.length > 200) data.sessions.shift();
    save();
    session.done = { c, n: session.results.length, secs };
    go({ name: 'summary' });
  }
  function keyPress(k) {
    const c = session && session.cur; if (!c || c.p.a.type !== 'num') return;
    if (c.status === 'right' || c.status === 'shown') { if (k === 'enter') advance(); return; }
    let s = c.input;
    if (k === 'enter') return submitNum();
    if (k === 'back') s = s.slice(0, -1);
    else if (k === 'clear') s = '';
    else if (k === '-') s = s.startsWith('-') ? s.slice(1) : '-' + s;
    else if (k === '/') { if (!s.includes('/') && /\d$/.test(s)) s += '/'; }
    else if (k === '.') { const part = s.split('/').pop(); if (!part.includes('.')) s += (/\d$/.test(s) ? '' : '0') + '.'; }
    else if (/^\d$/.test(k)) { if (s.replace(/[^0-9]/g, '').length < 9) s += k; }
    if (c.status === 'wrong' && s !== c.input) c.status = 'retry';
    c.input = s; updateAnswerBox();
  }
  function answerHTML(c) {
    const a = c.p.a; const s = c.input;
    if (!s) return `<span class="ph">${c.status === 'wrong' ? 'Try again' : 'Type your answer'}</span>`;
    let body;
    if (s.includes('/')) { const [n, d] = s.split('/'); const neg = n.startsWith('-'); body = `${neg ? '−' : ''}<span class="fr" style="font-size:.75em"><span>${esc(neg ? n.slice(1) : n) || '&nbsp;'}</span><span>${esc(d) || '&nbsp;'}</span></span>`; }
    else body = esc(s.replace(/-/g, '−'));
    return `${a.unit === '$' ? '$' : ''}${body}${a.unit && a.unit !== '$' ? `<span class="muted" style="font-size:.6em;margin-left:6px">${a.unit}</span>` : ''}`;
  }
  function updateAnswerBox() { const el = document.getElementById('ans'); if (el) el.innerHTML = answerHTML(session.cur); }

  function renderPractice(keepScratch) {
    const c = session.cur; const a = c.p.a; const done = c.status === 'right' || c.status === 'shown';
    const saved = keepScratch ? snapshotScratch() : null;
    const dots = Array.from({ length: SESSION_LEN }, (_, i) => `<span class="dot ${i < session.results.length ? (session.results[i] ? 'ok' : 'no') : i === session.i ? 'cur' : ''}"></span>`).join('');
    const unitName = SKILL[c.p.skill].name;
    let answerArea = '';
    if (a.type === 'num') {
      const cls = c.status === 'right' ? 'ok' : c.status === 'shown' ? 'no' : 'focus';
      const shownVal = c.status === 'shown' ? `<span style="text-decoration:line-through;opacity:.6;margin-right:14px">${esc((c.wrongInput || '').replace(/-/g, '−'))}</span>` : '';
      answerArea = `<div class="answer ${cls}" id="ans">${c.status === 'shown' ? shownVal + `<span>${a.unit === '$' ? '$' : ''}${a.show}${a.unit && a.unit !== '$' ? ' ' + a.unit : ''}</span>` : answerHTML(c)}</div>`;
      if (!done) answerArea += `<div class="keypad">
        ${['7', '8', '9', 'back', '4', '5', '6', '-', '1', '2', '3', '/', '0', '.', 'clear', 'enter'].map((k) => {
          const label = { back: '⌫', '-': '±', '/': 'a/b', clear: 'C', enter: 'Check', '.': '.' }[k] || k;
          const cls = k === 'enter' ? 'go' : /\d/.test(k) ? '' : 'op';
          return `<button class="key ${cls}" data-key="${k}" aria-label="${k}">${label}</button>`; }).join('')}
      </div>`;
    } else {
      answerArea = `<div class="choices">${a.choices.map((ch, i) => {
        let cls = ''; if (c.picked.includes(i)) cls = i === a.correct ? 'ok' : 'no'; if (done && i === a.correct) cls = 'ok';
        return `<button class="choice ${cls}" data-choice="${i}" ${done || c.picked.includes(i) ? 'disabled' : ''}>${ch}</button>`; }).join('')}</div>`;
    }
    let fb = '';
    if (c.status === 'right') fb = `<div class="feedback ok pop">${c.tries === 1 ? pick(['✅ Correct!', '✅ Nice!', '✅ You got it!', '✅ Great job!']) : '✅ Got it on the second try!'}</div>`;
    else if (c.status === 'wrong' || c.status === 'retry') fb = `<div class="feedback no">Not quite. Try once more.</div>${c.p.hint ? `<div class="feedback hint">💡 ${c.p.hint}</div>` : ''}`;
    else if (c.status === 'shown') fb = `<div class="feedback no">Here's how to solve it:</div>`;
    const steps = (c.status === 'shown' || (c.status === 'right' && c.showSteps)) ? `<div class="steps"><b>Step by step</b><ol>${c.p.steps.map((s) => `<li>${s}</li>`).join('')}</ol></div>` : '';
    const controls = done
      ? `<div class="row wrap" style="margin-top:14px">${c.status === 'right' && !c.showSteps ? '<button class="btn" data-act="steps">Show steps</button>' : ''}<button class="btn primary" data-act="next" style="flex:1">${session.i + 1 >= SESSION_LEN ? 'Finish' : 'Next ›'}</button></div>`
      : `<div class="row" style="margin-top:12px;justify-content:flex-end"><button class="btn ghost small" data-act="showme">Show me how</button></div>`;
    $app.innerHTML = `
      <div class="topbar">
        <button class="btn small" data-act="quit">✕ Stop</button>
        <div class="dots">${dots}</div>
        <div class="muted" style="font-size:14px;text-align:right">${session.i + 1} / ${SESSION_LEN}</div>
      </div>
      <div class="practice">
        <div>
          <div class="card qcard">
            <div class="muted" style="font-size:14px;font-weight:650;margin-bottom:6px">${esc(unitName)} · ${'●'.repeat(c.p.level)}${'○'.repeat(3 - c.p.level)}</div>
            <div class="qtext">${c.p.q}</div>
            ${answerArea}${fb}${steps}${controls}
          </div>
        </div>
        <div class="card scratch">
          <div class="row spread" style="margin-bottom:8px"><b>Scratch work ✏️</b>
            <div class="row" style="gap:6px">
              <button class="tool ${scratch.tool === 'pen' ? 'on' : ''}" data-tool="pen">Pen</button>
              <button class="tool ${scratch.tool === 'eraser' ? 'on' : ''}" data-tool="eraser">Eraser</button>
              <button class="tool" data-tool="clear">Clear</button>
            </div></div>
          <canvas id="pad"></canvas>
        </div>
      </div>`;
    setupScratch(saved);
  }
  const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

  // ---------- scratchpad (Apple Pencil or finger) ----------
  const scratch = { tool: 'pen', penSeen: false, strokes: [] };
  function clearScratch() { scratch.strokes = []; }
  function snapshotScratch() { return scratch.strokes; }
  function setupScratch() {
    const cv = document.getElementById('pad'); if (!cv) return;
    const ctx = cv.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const fit = () => { const r = cv.getBoundingClientRect(); cv.width = Math.round(r.width * dpr); cv.height = Math.round(r.height * dpr); redraw(); };
    const ink = () => getComputedStyle(document.documentElement).getPropertyValue('--ink').trim() || '#1b2333';
    function drawStroke(st) {
      if (st.pts.length < 1) return;
      ctx.save(); ctx.scale(dpr, dpr); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      ctx.globalCompositeOperation = st.erase ? 'destination-out' : 'source-over';
      ctx.strokeStyle = ink();
      for (let i = 1; i < st.pts.length; i++) {
        const p0 = st.pts[i - 1], p1 = st.pts[i];
        ctx.lineWidth = st.erase ? 26 : 1.4 + 2.6 * (p1.p || 0.5);
        ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
      }
      if (st.pts.length === 1 && !st.erase) { const p = st.pts[0]; ctx.fillStyle = ink(); ctx.beginPath(); ctx.arc(p.x, p.y, 1.8, 0, 7); ctx.fill(); }
      ctx.restore();
    }
    function redraw() { ctx.clearRect(0, 0, cv.width, cv.height); scratch.strokes.forEach(drawStroke); }
    let cur = null;
    const pt = (e) => { const r = cv.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top, p: e.pointerType === 'pen' ? e.pressure : 0.5 }; };
    cv.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'pen') scratch.penSeen = true;
      if (scratch.penSeen && e.pointerType === 'touch') return; // palm rejection once a Pencil has been used
      e.preventDefault(); cv.setPointerCapture(e.pointerId);
      cur = { erase: scratch.tool === 'eraser', pts: [pt(e)], id: e.pointerId }; scratch.strokes.push(cur); drawStroke(cur);
    });
    cv.addEventListener('pointermove', (e) => {
      if (!cur || e.pointerId !== cur.id) return; e.preventDefault();
      const evs = e.getCoalescedEvents ? e.getCoalescedEvents() : [e];
      for (const ev of evs) cur.pts.push(pt(ev));
      const n = cur.pts.length; drawStroke({ erase: cur.erase, pts: cur.pts.slice(Math.max(0, n - evs.length - 1)) });
    });
    const end = (e) => { if (cur && e.pointerId === cur.id) cur = null; };
    cv.addEventListener('pointerup', end); cv.addEventListener('pointercancel', end);
    requestAnimationFrame(fit);
    window.onresize = () => { if (document.getElementById('pad')) fit(); };
  }

  // ---------- summary ----------
  function renderSummary() {
    const d = session.done; const pct = d.n ? Math.round(d.c / d.n * 100) : 0;
    const msg = pct === 100 ? 'Perfect score! 🏆' : pct >= 80 ? 'Excellent work! 🌟' : pct >= 60 ? 'Good effort, keep going! 💪' : 'Every mistake is practice. Try again! 🌱';
    const today = data.days[todayKey()] || { n: 0 };
    $app.innerHTML = `
      <div class="card center" style="max-width:560px;margin:30px auto;padding:30px">
        <div class="muted">${esc(session.title)}</div>
        <div class="big" style="margin:16px 0 6px">${d.c} / ${d.n}</div>
        <h2>${msg}</h2>
        <div class="muted">${Math.floor(d.secs / 60)} min ${d.secs % 60} s · ${today.n} problems today · 🔥 ${streak()} day streak</div>
        <div class="dots" style="justify-content:center;margin:18px 0">${session.results.map((r) => `<span class="dot ${r ? 'ok' : 'no'}"></span>`).join('')}</div>
        <div class="row" style="justify-content:center;gap:12px;flex-wrap:wrap">
          <button class="btn" data-act="home">Home</button>
          <button class="btn primary" data-act="again">Practice again</button>
        </div>
      </div>`;
  }

  // ---------- parent view ----------
  let parentOK = false; let pinEntry = ''; let pinStage = null; let pinFirst = '';
  function renderParent() {
    if (!parentOK) return renderPin();
    const s = data.settings; const cur = currentUnitId(); const auto = pacedUnit();
    const days = []; for (let i = 13; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); days.push([d, data.days[todayKey(d)] || { n: 0, c: 0, secs: 0 }]); }
    const max = Math.max(5, ...days.map(([, v]) => v.n));
    const week = days.slice(7); const wn = week.reduce((a, [, v]) => a + v.n, 0), wc = week.reduce((a, [, v]) => a + v.c, 0), ws = week.reduce((a, [, v]) => a + (v.secs || 0), 0);
    const mistakes = data.log.filter((l) => !l.ok).slice(-15).reverse();
    const fmtDate = (t) => new Date(t).toLocaleString([], { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
    $app.innerHTML = `
      <div class="topbar"><button class="btn small" data-act="home">‹ Done</button><h1>Parent view</h1><button class="btn small" data-act="lock">🔒 Lock</button></div>
      <div class="card"><div class="kpis">
        <div class="kpi"><div class="v">${wn}</div><div class="l">Problems, last 7 days</div></div>
        <div class="kpi"><div class="v">${wn ? Math.round(wc / wn * 100) + '%' : '—'}</div><div class="l">Correct on first try</div></div>
        <div class="kpi"><div class="v">${Math.round(ws / 60)} min</div><div class="l">Practice time, 7 days</div></div>
        <div class="kpi"><div class="v">🔥 ${streak()}</div><div class="l">Day streak (goal ${s.goal}/day)</div></div>
      </div>
      <div class="chart" style="margin-top:16px">${days.map(([d, v]) => `<div class="col" title="${v.n} problems, ${v.c} correct"><div class="b ${v.n ? '' : 'zero'}" style="height:${Math.round(v.n / max * 100)}%"></div><small>${'SMTWTFS'[d.getDay()]}</small></div>`).join('')}</div>
      <div class="muted" style="font-size:13px">Problems per day, last 14 days</div></div>

      <div class="card section"><h2>Settings</h2>
        <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(240px,1fr))">
          <label><div class="muted" style="font-size:14px;margin-bottom:4px">Current class unit</div>
            <select id="unitSel"><option value="">Auto: follow class pacing (now Unit ${UNIT[auto].n})</option>
              ${UNITS.map((u) => `<option value="${u.id}" ${s.unitOverride === u.id ? 'selected' : ''}>Unit ${u.n}: ${u.name}</option>`).join('')}</select></label>
          <label><div class="muted" style="font-size:14px;margin-bottom:4px">Daily goal</div>
            <select id="goalSel">${[5, 10, 15, 20, 30].map((g) => `<option ${s.goal === g ? 'selected' : ''} value="${g}">${g} problems</option>`).join('')}</select></label>
          <label><div class="muted" style="font-size:14px;margin-bottom:4px">Student's name (optional)</div>
            <input type="text" id="nameIn" value="${esc(s.name)}" placeholder="Name" maxlength="20"></label>
        </div>
        <div class="muted" style="font-size:13px;margin-top:10px">Auto pacing follows the teacher's 2026–27 slides through Unit 5. Later units use last year's dates. Choose a unit here if the class moves faster or slower.</div>
      </div>

      <div class="card section"><h2>Skills by unit</h2>
        <table class="stats"><tr><th>Skill</th><th class="num">Tried</th><th class="num">Recent</th><th class="num">Level</th></tr>
        ${UNITS.map((u) => `<tr><td colspan="4" style="padding-top:16px"><b>Unit ${u.n}: ${u.name}</b> ${u.id === cur ? '<span class="tag">Now</span>' : ''}</td></tr>` + u.skills.map((sv) => { const st = data.skills[sv.id]; const m = mastery(sv.id);
          const col = m == null ? '' : m >= 0.8 ? 'color:var(--good)' : m < 0.5 ? 'color:var(--bad)' : 'color:var(--warn)';
          return `<tr><td>${sv.name}</td><td class="num">${st ? st.att : 0}</td><td class="num" style="${col};font-weight:700">${m == null ? '—' : Math.round(m * 100) + '%'}</td><td class="num">${st ? st.level : 1}</td></tr>`; }).join('')).join('')}
        </table>
        <div class="muted" style="font-size:13px;margin-top:8px">"Recent" is the share correct on the first try over the last 10 problems. Level (1–3) goes up or down automatically.</div>
      </div>

      <div class="card section"><h2>Recent mistakes</h2>
        ${mistakes.length ? mistakes.map((l) => `<div class="mistake"><div class="muted" style="font-size:13px">${fmtDate(l.t)} · ${SKILL[l.skill] ? SKILL[l.skill].name : l.skill}</div><div class="q">${esc(l.q)}</div><div>Answered: <b style="color:var(--bad)">${esc(l.given || '(asked for help)')}</b> · Correct: <b style="color:var(--good)">${esc(l.correct)}</b></div></div>`).join('') : '<div class="muted">No mistakes yet.</div>'}
      </div>

      <div class="card section"><h2>Recent sessions</h2>
        ${data.sessions.length ? `<table class="stats"><tr><th>When</th><th>Practice</th><th class="num">Score</th><th class="num">Time</th></tr>${data.sessions.slice(-10).reverse().map((x) => `<tr><td>${fmtDate(x.t)}</td><td>${esc(x.title)}</td><td class="num">${x.c}/${x.n}</td><td class="num">${Math.round(x.secs / 60)} min</td></tr>`).join('')}</table>` : '<div class="muted">No sessions yet.</div>'}
      </div>

      <div class="card section"><h2>Data</h2>
        <div class="muted" style="font-size:14px;margin-bottom:10px">Progress is saved on this iPad only. Make a backup now and then.</div>
        <div class="row wrap">
          <button class="btn small" data-act="export">⬇ Back up progress</button>
          <label class="btn small">⬆ Restore backup<input type="file" id="importIn" accept="application/json,.json" style="display:none"></label>
          <button class="btn small" data-act="changepin">Change PIN</button>
          <button class="btn small danger" data-act="reset">Reset all progress</button>
        </div>
      </div>`;
    document.getElementById('unitSel').onchange = (e) => { s.unitOverride = e.target.value || null; save(); toast('Current unit updated'); renderParent(); };
    document.getElementById('goalSel').onchange = (e) => { s.goal = Number(e.target.value); save(); toast('Daily goal updated'); };
    document.getElementById('nameIn').onchange = (e) => { s.name = e.target.value.trim().slice(0, 20); save(); toast('Name saved'); };
    document.getElementById('importIn').onchange = (e) => {
      const f = e.target.files[0]; if (!f) return; const r = new FileReader();
      r.onload = () => { try { const d = JSON.parse(r.result); if (!d.skills || !d.settings) throw 0; data = Object.assign(fresh(), d); save(); toast('Backup restored'); renderParent(); } catch (err) { toast('That file is not a valid backup'); } };
      r.readAsText(f);
    };
  }
  function renderPin() {
    if (!pinStage) pinStage = data.settings.pin ? 'enter' : 'create';
    const title = { enter: 'Enter parent PIN', create: 'Create a 4-digit parent PIN', confirm: 'Enter the PIN again' }[pinStage];
    $app.innerHTML = `
      <div class="topbar"><button class="btn small" data-act="home">‹ Back</button><div></div></div>
      <div class="card pinbox"><h2>🔒 ${title}</h2>
        ${pinStage === 'create' ? '<div class="muted" style="font-size:14px">This keeps the parent view and settings private.</div>' : ''}
        <div class="pindots">${[0, 1, 2, 3].map((i) => `<i class="${i < pinEntry.length ? 'f' : ''}"></i>`).join('')}</div>
        <div class="keypad" style="grid-template-columns:repeat(3,1fr)">
          ${['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'].map((k) => k ? `<button class="key" data-pin="${k}">${k === 'back' ? '⌫' : k}</button>` : '<span></span>').join('')}
        </div>
        ${pinStage === 'enter' ? '<div class="muted" style="font-size:13px;margin-top:12px">Forgot it? Hold the lock button on the home screen for 5 seconds to reset the PIN (progress is kept).</div>' : ''}
      </div>`;
  }
  async function hash(s) {
    try { const b = await crypto.subtle.digest('SHA-256', new TextEncoder().encode('m7:' + s)); return Array.from(new Uint8Array(b)).map((x) => x.toString(16).padStart(2, '0')).join(''); }
    catch (e) { return 'p' + s; } // crypto.subtle needs https; fallback for local testing
  }
  async function pinKey(k) {
    if (k === 'back') pinEntry = pinEntry.slice(0, -1); else if (pinEntry.length < 4) pinEntry += k;
    renderPin();
    if (pinEntry.length < 4) return;
    const entered = pinEntry; pinEntry = '';
    if (pinStage === 'create') { pinFirst = entered; pinStage = 'confirm'; return renderPin(); }
    if (pinStage === 'confirm') {
      if (entered !== pinFirst) { pinStage = 'create'; toast("PINs didn't match. Try again."); return renderPin(); }
      data.settings.pin = await hash(entered); save(); parentOK = true; pinStage = null; return renderParent();
    }
    if (await hash(entered) === data.settings.pin) { parentOK = true; pinStage = null; renderParent(); }
    else { toast('Wrong PIN'); renderPin(); }
  }
  function confirmBox(text, okLabel, onOk) {
    const m = document.createElement('div'); m.className = 'modal';
    m.innerHTML = `<div class="card"><h2>${text}</h2><div class="row" style="justify-content:flex-end;margin-top:16px"><button class="btn" data-x="no">Cancel</button><button class="btn danger" data-x="yes">${okLabel}</button></div></div>`;
    m.onclick = (e) => { const x = e.target.dataset.x; if (x === 'yes') onOk(); if (x || e.target === m) m.remove(); };
    document.body.appendChild(m);
  }

  // ---------- events ----------
  $app.addEventListener('click', (e) => {
    const t = e.target.closest('[data-act],[data-key],[data-choice],[data-tool],[data-pin]'); if (!t) return;
    if (t.dataset.key) return keyPress(t.dataset.key);
    if (t.dataset.choice != null) return pickChoice(Number(t.dataset.choice));
    if (t.dataset.pin) return pinKey(t.dataset.pin);
    if (t.dataset.tool) {
      if (t.dataset.tool === 'clear') { clearScratch(); const cv = document.getElementById('pad'); cv.getContext('2d').clearRect(0, 0, cv.width, cv.height); return; }
      scratch.tool = t.dataset.tool; document.querySelectorAll('[data-tool]').forEach((b) => b.classList.toggle('on', b.dataset.tool === scratch.tool)); return;
    }
    switch (t.dataset.act) {
      case 'home': session = null; return go({ name: 'home' });
      case 'open-unit': return go({ name: 'unit', unit: t.dataset.unit });
      case 'start-unit': return startSession('unit', t.dataset.unit);
      case 'start-skill': return startSession('skill', t.dataset.skill);
      case 'start-review': return startSession('review');
      case 'start-weak': return startSession('weak');
      case 'next': return advance();
      case 'showme': return showMe();
      case 'steps': session.cur.showSteps = true; return renderPractice(true);
      case 'quit':
        if (session.results.length) return finishSession();
        session = null; return go({ name: 'home' });
      case 'again': { const { kind, arg } = session; clearScratch(); return startSession(kind, arg); }
      case 'parent': pinEntry = ''; pinStage = null; return go({ name: 'parent' });
      case 'lock': parentOK = false; return go({ name: 'home' });
      case 'changepin': parentOK = true; data.settings.pin = null; pinStage = 'create'; pinEntry = ''; parentOK = false; return renderPin();
      case 'export': {
        const blob = new Blob([JSON.stringify(data, null, 1)], { type: 'application/json' });
        const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = `math7-progress-${todayKey()}.json`; document.body.appendChild(a); a.click(); a.remove();
        return;
      }
      case 'reset': return confirmBox('Erase all progress? Settings and PIN are kept.', 'Erase', () => { const st = data.settings; data = fresh(); data.settings = st; save(); toast('Progress erased'); renderParent(); });
    }
  });
  // Hold the parent button 5 s to reset a forgotten PIN.
  let holdT = null;
  $app.addEventListener('pointerdown', (e) => { const t = e.target.closest('[data-act="parent"]'); if (!t) return; holdT = setTimeout(() => { data.settings.pin = null; save(); toast('Parent PIN cleared. Create a new one.'); }, 5000); });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((ev) => $app.addEventListener(ev, () => clearTimeout(holdT)));

  document.addEventListener('keydown', (e) => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT') return;
    if (view.name === 'practice' && session) {
      const c = session.cur;
      if (c.p.a.type === 'mc') { const n = Number(e.key); if (n >= 1 && n <= c.p.a.choices.length) pickChoice(n - 1); else if (e.key === 'Enter' && (c.status === 'right' || c.status === 'shown')) advance(); return; }
      const map = { Backspace: 'back', Enter: 'enter', '-': '-', '/': '/', '.': '.', Escape: 'clear' };
      const k = /^\d$/.test(e.key) ? e.key : map[e.key]; if (k) { e.preventDefault(); keyPress(k); }
    } else if (view.name === 'parent' && !parentOK) { if (/^\d$/.test(e.key)) pinKey(e.key); else if (e.key === 'Backspace') pinKey('back'); }
  });

  if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
  render();
})();
