// Problem generators for Math 7 practice.
// Each skill: gen(level 1..3) -> { q: html, a: answer, steps: [html], hint?: html }
// answer: { type:'num', value:Number, show:html, tol?:Number, unit?:string }
//      or { type:'mc', choices:[html], correct:index }
(function (global) {
  'use strict';

  // ---------- helpers ----------
  const R = (a, b) => Math.floor(Math.random() * (b - a + 1)) + a;
  const pick = (arr) => arr[R(0, arr.length - 1)];
  const nz = (a, b) => { let x; do { x = R(a, b); } while (x === 0); return x; };
  const gcd = (a, b) => { a = Math.abs(a); b = Math.abs(b); while (b) { [a, b] = [b, a % b]; } return a || 1; };
  const lcm = (a, b) => Math.abs(a * b) / gcd(a, b);
  const round = (x, p = 6) => { const m = Math.pow(10, p); return Math.round(x * m) / m; };
  const shuffle = (arr) => { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = R(0, i); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const MINUS = '−';

  function simp(n, d) { if (d < 0) { n = -n; d = -d; } const g = gcd(n, d); return [n / g, d / g]; }
  function num(x) { // format a number (int or decimal) with a real minus sign
    const r = round(x, 6);
    return r < 0 ? MINUS + Math.abs(r) : String(r);
  }
  const P = (x) => (x < 0 ? '(' + num(x) + ')' : num(x)); // parenthesize negatives
  function money(x) { return '$' + x.toFixed(2); }
  function frac(n, d) {
    [n, d] = simp(n, d);
    if (d === 1) return num(n);
    const s = n < 0 ? MINUS : '';
    return `${s}<span class="fr"><span>${Math.abs(n)}</span><span>${d}</span></span>`;
  }
  const Pf = (n, d) => (n * d < 0 ? '(' + frac(n, d) + ')' : frac(n, d));
  // linear expression ax + b
  function lin(a, b, v = 'x') {
    let s = '';
    if (a !== 0) s = (a === 1 ? '' : a === -1 ? MINUS : num(a)) + `<i>${v}</i>`;
    if (b !== 0) {
      if (s) s += b < 0 ? ` ${MINUS} ${Math.abs(b)}` : ` + ${b}`;
      else s = num(b);
    }
    return s || '0';
  }
  function term(a, v) { return (a === 1 ? '' : a === -1 ? MINUS : num(a)) + `<i>${v}</i>`; }
  function numAns(value, opts = {}) { return Object.assign({ type: 'num', value: round(value, 9), show: opts.show || num(value) }, opts); }
  function fracAns(n, d) { const [a, b] = simp(n, d); return { type: 'num', value: a / b, show: frac(a, b), isFrac: b !== 1 }; }
  function mc(correct, distractors) {
    const seen = new Set([correct]);
    const ds = [];
    for (const d of distractors) { if (!seen.has(d)) { seen.add(d); ds.push(d); } if (ds.length === 3) break; }
    const choices = shuffle([correct, ...ds]);
    return { type: 'mc', choices, correct: choices.indexOf(correct) };
  }
  function numberLineSVG(k, closed, dirRight) {
    // number line from k-5 to k+5
    const W = 360, H = 70, x0 = 20, x1 = W - 20, lo = k - 5, hi = k + 5;
    const X = (v) => x0 + (v - lo) * (x1 - x0) / (hi - lo);
    let ticks = '';
    for (let v = lo; v <= hi; v++) {
      ticks += `<line x1="${X(v)}" y1="30" x2="${X(v)}" y2="40" stroke="currentColor" stroke-width="1.5"/>`;
      ticks += `<text x="${X(v)}" y="58" text-anchor="middle" font-size="13" fill="currentColor">${v < 0 ? MINUS + Math.abs(v) : v}</text>`;
    }
    const xs = X(k), xe = dirRight ? x1 - 4 : x0 + 4;
    return `<svg class="nl" viewBox="0 0 ${W} ${H}" width="100%" style="max-width:420px">
      <line x1="${x0 - 8}" y1="35" x2="${x1 + 8}" y2="35" stroke="currentColor" stroke-width="2"/>
      ${ticks}
      <line x1="${xs}" y1="35" x2="${xe}" y2="35" stroke="#2f7de1" stroke-width="7" stroke-linecap="round"/>
      <polygon points="${dirRight ? `${x1 + 10},35 ${x1 - 2},28 ${x1 - 2},42` : `${x0 - 10},35 ${x0 + 2},28 ${x0 + 2},42`}" fill="#2f7de1"/>
      <circle cx="${xs}" cy="35" r="8" fill="${closed ? '#2f7de1' : 'white'}" stroke="#2f7de1" stroke-width="3"/>
    </svg>`;
  }

  // ---------- Unit 1: integers & rational numbers (add/subtract) ----------
  const absval = (L) => {
    if (L === 1) { const a = nz(-30, 30); return { q: `Evaluate |${num(a)}|`, a: numAns(Math.abs(a)), steps: [`Absolute value is the distance from 0, so it is never negative.`, `|${num(a)}| = <b>${Math.abs(a)}</b>`] }; }
    if (L === 2) { const a = nz(-20, 20), b = nz(-20, 20); const v = Math.abs(a) - Math.abs(b); return { q: `Evaluate |${num(a)}| ${MINUS} |${num(b)}|`, a: numAns(v), steps: [`|${num(a)}| = ${Math.abs(a)} and |${num(b)}| = ${Math.abs(b)}`, `${Math.abs(a)} ${MINUS} ${Math.abs(b)} = <b>${num(v)}</b>`] }; }
    const a = nz(-15, 15), b = nz(-15, 15); const v = -Math.abs(a - b);
    return { q: `Evaluate ${MINUS}|${num(a)} ${MINUS} ${P(b)}|`, a: numAns(v), steps: [`Inside first: ${num(a)} ${MINUS} ${P(b)} = ${num(a - b)}`, `|${num(a - b)}| = ${Math.abs(a - b)}`, `The negative sign outside stays: <b>${num(v)}</b>`] };
  };
  const order = (L) => {
    const vals = new Set();
    while (vals.size < 4) {
      let v = L === 1 ? nz(-12, 12) : L === 2 ? R(-90, 90) / 10 : pick([R(-90, 90) / 10, R(-12, 12) / 4]);
      vals.add(round(v, 4));
    }
    const arr = [...vals];
    const fmt = (a) => a.map(num).join(', ');
    const sorted = arr.slice().sort((a, b) => a - b);
    const byAbs = arr.slice().sort((a, b) => Math.abs(a) - Math.abs(b) || a - b);
    const desc = sorted.slice().reverse();
    const swapped = sorted.slice(); [swapped[0], swapped[1]] = [swapped[1], swapped[0]];
    const swapped2 = sorted.slice(); [swapped2[2], swapped2[3]] = [swapped2[3], swapped2[2]];
    return { q: `Which list orders ${fmt(shuffle(arr))} from <b>least to greatest</b>?`, a: mc(fmt(sorted), [fmt(byAbs), fmt(desc), fmt(swapped), fmt(swapped2)]), steps: [`On a number line, numbers farther left are smaller. Negative numbers with bigger absolute value are farther left.`, `Least to greatest: <b>${fmt(sorted)}</b>`] };
  };
  const addInt = (L) => {
    const m = [12, 30, 120][L - 1]; const a = nz(-m, m), b = nz(-m, m); const v = a + b;
    const same = (a > 0) === (b > 0);
    return { q: `${num(a)} + ${P(b)} = ?`, a: numAns(v), steps: [same ? `Same signs: add the absolute values (${Math.abs(a)} + ${Math.abs(b)} = ${Math.abs(v)}) and keep the sign.` : `Different signs: subtract the absolute values (${Math.max(Math.abs(a), Math.abs(b))} ${MINUS} ${Math.min(Math.abs(a), Math.abs(b))} = ${Math.abs(v)}) and keep the sign of the number with the bigger absolute value.`, `Answer: <b>${num(v)}</b>`] };
  };
  const subInt = (L) => {
    const m = [12, 30, 120][L - 1]; const a = nz(-m, m), b = nz(-m, m); const v = a - b;
    return { q: `${num(a)} ${MINUS} ${P(b)} = ?`, a: numAns(v), steps: [`Subtracting is adding the opposite: ${num(a)} ${MINUS} ${P(b)} = ${num(a)} + ${P(-b)}`, `${num(a)} + ${P(-b)} = <b>${num(v)}</b>`], hint: `Change subtraction to adding the opposite.` };
  };
  const addSubFrac = (L) => {
    let d1, d2;
    if (L === 1) { d1 = d2 = pick([3, 4, 5, 6, 8, 10]); }
    else if (L === 2) { d1 = pick([2, 3, 4, 6]); d2 = pick([2, 3, 4, 6, 8, 12].filter((x) => x !== d1)); }
    else { d1 = pick([3, 4, 5, 6, 8, 9]); d2 = pick([2, 4, 5, 6, 10, 12].filter((x) => x !== d1)); }
    const n1 = nz(-(L === 3 ? 2 * d1 : d1 - 1 || 1), L === 3 ? 2 * d1 : d1 - 1 || 1);
    const n2 = nz(-(L === 3 ? 2 * d2 : d2 - 1 || 1), L === 3 ? 2 * d2 : d2 - 1 || 1);
    const op = pick(['+', MINUS]);
    const D = lcm(d1, d2), a1 = n1 * D / d1, a2 = n2 * D / d2;
    const tn = op === '+' ? a1 + a2 : a1 - a2;
    const steps = [];
    if (d1 !== d2) steps.push(`Common denominator ${D}: ${frac(n1, d1)} = ${a1}/${D}, ${frac(n2, d2)} = ${a2}/${D}`);
    steps.push(`${num(a1)} ${op} ${P(a2)} = ${num(tn)}, so the result is ${num(tn)}/${D}`);
    steps.push(`Simplified: <b>${frac(tn, D)}</b>`);
    return { q: `${frac(n1, d1)} ${op} ${Pf(n2, d2)} = ?`, a: fracAns(tn, D), steps, hint: `Get a common denominator, then add or subtract the numerators.` };
  };
  const addSubDec = (L) => {
    const p = L === 1 ? 1 : 2; const m = Math.pow(10, p);
    const a = nz(-[50, 150, 999][L - 1], [50, 150, 999][L - 1]) / m, b = nz(-[50, 150, 999][L - 1], [50, 150, 999][L - 1]) / m;
    const op = pick(['+', MINUS]); const v = op === '+' ? a + b : a - b;
    return { q: `${num(a)} ${op} ${P(b)} = ?`, a: numAns(v), steps: [op === MINUS ? `Add the opposite: ${num(a)} + ${P(-b)}` : `Line up the decimal points.`, `Answer: <b>${num(v)}</b>`] };
  };
  const distance = (L) => {
    const m = [10, 25, 9][L - 1];
    let a = nz(-m, m), b = nz(-m, m); while (b === a) b = nz(-m, m);
    if (L === 3) { a = R(-90, 90) / 10; b = R(-90, 90) / 10; if (a === b) b += 1.5; }
    const v = Math.abs(a - b);
    return { q: `What is the distance between ${num(a)} and ${num(b)} on a number line?`, a: numAns(v), steps: [`Distance = |${num(a)} ${MINUS} ${P(b)}|`, `= |${num(a - b)}| = <b>${num(v)}</b>`] };
  };

  // ---------- Unit 2: multiply & divide rational numbers ----------
  const mulDivInt = (L) => {
    const m = [9, 12, 25][L - 1]; const a = nz(-m, m), b = nz(-m, m);
    const sign = (x, y) => ((x < 0) !== (y < 0) ? 'Different signs give a negative.' : 'Same signs give a positive.');
    if (Math.random() < 0.5) return { q: `${num(a)} × ${P(b)} = ?`, a: numAns(a * b), steps: [sign(a, b), `${Math.abs(a)} × ${Math.abs(b)} = ${Math.abs(a * b)}, so the answer is <b>${num(a * b)}</b>`] };
    return { q: `${num(a * b)} ÷ ${P(b)} = ?`, a: numAns(a), steps: [sign(a * b, b), `${Math.abs(a * b)} ÷ ${Math.abs(b)} = ${Math.abs(a)}, so the answer is <b>${num(a)}</b>`] };
  };
  const mulDivFrac = (L) => {
    const ds = L === 1 ? [2, 3, 4, 5] : [2, 3, 4, 5, 6, 8, 9, 10];
    const d1 = pick(ds), d2 = pick(ds); const n1 = nz(-(L === 3 ? 12 : d1), L === 3 ? 12 : d1), n2 = nz(-(L === 3 ? 12 : d2), L === 3 ? 12 : d2);
    if (Math.random() < 0.5) {
      return { q: `${frac(n1, d1)} × ${Pf(n2, d2)} = ?`, a: fracAns(n1 * n2, d1 * d2), steps: [`Multiply numerators and denominators: (${num(n1)} × ${num(n2)}) / (${d1} × ${d2}) = ${num(n1 * n2)}/${d1 * d2}`, `Simplified: <b>${frac(n1 * n2, d1 * d2)}</b>`] };
    }
    return { q: `${frac(n1, d1)} ÷ ${Pf(n2, d2)} = ?`, a: fracAns(n1 * d2, d1 * n2), steps: [`Dividing is multiplying by the reciprocal: ${frac(n1, d1)} × ${Pf(d2, n2)}`, `= ${num(n1 * d2)}/${num(d1 * n2)} = <b>${frac(n1 * d2, d1 * n2)}</b>`], hint: `Keep, change, flip.` };
  };
  const mulDivDec = (L) => {
    const a = nz(-90, 90) / 10, b = L === 1 ? nz(-9, 9) : nz(-40, 40) / 10;
    if (Math.random() < 0.55) return { q: `${num(a)} × ${P(b)} = ?`, a: numAns(a * b), steps: [`Multiply as whole numbers, then count decimal places.`, `Sign: ${(a < 0) !== (b < 0) ? 'negative' : 'positive'}. Answer: <b>${num(a * b)}</b>`] };
    const prod = round(a * b, 4);
    return { q: `${num(prod)} ÷ ${P(b)} = ?`, a: numAns(a), steps: [`Move the decimal so the divisor is a whole number, then divide.`, `Sign: ${(prod < 0) !== (b < 0) ? 'negative' : 'positive'}. Answer: <b>${num(a)}</b>`] };
  };
  const orderOps = (L) => {
    const t = L === 1 ? R(0, 1) : L === 2 ? R(0, 3) : R(2, 5);
    const a = nz(-9, 9), b = nz(-6, 6), c = nz(-5, 5), k = R(2, 6);
    switch (t) {
      case 0: return { q: `${num(a)} + ${P(b)} × ${P(c)} = ?`, a: numAns(a + b * c), steps: [`Multiply first: ${P(b)} × ${P(c)} = ${num(b * c)}`, `${num(a)} + ${P(b * c)} = <b>${num(a + b * c)}</b>`] };
      case 1: return { q: `(${num(a)} + ${P(b)}) × ${P(c)} = ?`, a: numAns((a + b) * c), steps: [`Parentheses first: ${num(a)} + ${P(b)} = ${num(a + b)}`, `${P(a + b)} × ${P(c)} = <b>${num((a + b) * c)}</b>`] };
      case 2: return { q: `${MINUS}${k}<sup>2</sup> + ${P(a)} = ?`, a: numAns(-k * k + a), steps: [`The exponent applies only to ${k}, not the negative sign: ${MINUS}${k}<sup>2</sup> = ${MINUS}${k * k}`, `${MINUS}${k * k} + ${P(a)} = <b>${num(-k * k + a)}</b>`], hint: `Is the negative sign inside parentheses?` };
      case 3: return { q: `(${MINUS}${k})<sup>2</sup> ${MINUS} ${P(b)} = ?`, a: numAns(k * k - b), steps: [`(${MINUS}${k})<sup>2</sup> = (${MINUS}${k}) × (${MINUS}${k}) = ${k * k}`, `${k * k} ${MINUS} ${P(b)} = <b>${num(k * k - b)}</b>`] };
      case 4: { const v = a - b * b; return { q: `${num(a)} ${MINUS} ${P(b)}<sup>2</sup> = ?`, a: numAns(v), steps: [`Exponent first: ${P(b)}<sup>2</sup> = ${b * b}`, `${num(a)} ${MINUS} ${b * b} = <b>${num(v)}</b>`] }; }
      default: { const d = nz(-4, 4); const top = d * c * 2; const v = top / d + a * b; return { q: `${num(top)} ÷ ${P(d)} + ${P(a)} × ${P(b)} = ?`, a: numAns(v), steps: [`Divide and multiply left to right: ${num(top)} ÷ ${P(d)} = ${num(top / d)} and ${P(a)} × ${P(b)} = ${num(a * b)}`, `${num(top / d)} + ${P(a * b)} = <b>${num(v)}</b>`] }; }
    }
  };

  // ---------- Unit 3: expressions & equations ----------
  const likeTerms = (L) => {
    const a = nz(-9, 9), b = nz(-9, 9), c = nz(-12, 12), d = nz(-12, 12);
    let A = a + b, B = c + d; if (A === 0) return likeTerms(L);
    const v = pick(['x', 'n', 'y']);
    const expr = `${lin(a, c, v)} ${b < 0 ? MINUS : '+'} ${term(Math.abs(b), v)} ${d < 0 ? MINUS : '+'} ${Math.abs(d)}`;
    return { q: `Simplify: ${expr}`, a: mc(lin(A, B, v), [lin(a - b, B, v), lin(A, c - d, v), lin(-A, B, v), lin(A + B, 0, v), lin(A, -B, v)]), steps: [`Group like terms: (${term(a, v)} ${b < 0 ? MINUS : '+'} ${term(Math.abs(b), v)}) + (${num(c)} ${d < 0 ? MINUS : '+'} ${Math.abs(d)})`, `= <b>${lin(A, B, v)}</b>`] };
  };
  const evaluate = (L) => {
    const x = nz(-6, 6), y = nz(-6, 6), a = nz(-7, 7), b = nz(-7, 7);
    if (L === 1) { const c = nz(-10, 10); return { q: `Evaluate ${lin(a, c)} when <i>x</i> = ${num(x)}`, a: numAns(a * x + c), steps: [`Substitute: ${num(a)}${P(x)} + ${P(c)}`, `= ${num(a * x)} + ${P(c)} = <b>${num(a * x + c)}</b>`] }; }
    if (L === 2) { const v = a * x + b * y; return { q: `Evaluate ${term(a, 'x')} ${b < 0 ? MINUS : '+'} ${term(Math.abs(b), 'y')} when <i>x</i> = ${num(x)} and <i>y</i> = ${num(y)}`, a: numAns(v), steps: [`Substitute: ${num(a)}${P(x)} ${b < 0 ? MINUS : '+'} ${Math.abs(b)}${P(y)}`, `= ${num(a * x)} + ${P(b * y)} = <b>${num(v)}</b>`] }; }
    const v = x * x + a * y;
    return { q: `Evaluate <i>x</i><sup>2</sup> ${a < 0 ? MINUS : '+'} ${term(Math.abs(a), 'y')} when <i>x</i> = ${num(x)} and <i>y</i> = ${num(y)}`, a: numAns(v), steps: [`Substitute: ${P(x)}<sup>2</sup> ${a < 0 ? MINUS : '+'} ${Math.abs(a)}${P(y)}`, `= ${x * x} + ${P(a * y)} = <b>${num(v)}</b>`] };
  };
  const distribute = (L) => {
    const k = L === 1 ? R(2, 9) : nz(-9, 9), a = nz(-8, 8), b = nz(-10, 10);
    if (Math.abs(k) === 1) return distribute(L);
    const inner = lin(a, b);
    return { q: `Expand: ${num(k)}(${inner})`, a: mc(lin(k * a, k * b), [lin(k * a, b), lin(k * a, -k * b), lin(-k * a, k * b), lin(k + a, k * b), lin(a, k * b)]), steps: [`Multiply ${num(k)} by each term: ${num(k)} · ${term(a, 'x')} = ${term(k * a, 'x')} and ${num(k)} · ${P(b)} = ${num(k * b)}`, `= <b>${lin(k * a, k * b)}</b>`] };
  };
  const factorGCF = (L) => {
    const g = R(2, L === 1 ? 6 : 9); let a = R(1, 9), b = R(1, 9) * (L === 3 && Math.random() < 0.5 ? -1 : 1);
    while (gcd(a, b) !== 1) { a = R(1, 9); }
    const e = lin(g * a, g * b);
    const correct = `${g}(${lin(a, b)})`;
    const dis = [];
    const sub = [2, 3].find((s) => g % s === 0 && s !== g);
    if (sub) dis.push(`${sub}(${lin(g * a / sub, g * b / sub)})`);
    dis.push(`${g}(${lin(a, g * b)})`, `${g}(${lin(g * a, b)})`, `${g * a}(${lin(1, b)})`, `${g}(${lin(a, -b)})`);
    return { q: `Factor out the greatest common factor: ${e}`, a: mc(correct, dis), steps: [`The GCF of ${g * a} and ${Math.abs(g * b)} is ${g}.`, `${g * a} ÷ ${g} = ${a} and ${num(g * b)} ÷ ${g} = ${num(b)}`, `= <b>${correct}</b>`] };
  };
  const twoStep = (L) => {
    const x = nz(-12, 12);
    if (L < 3) {
      const a = L === 1 ? R(2, 9) : nz(-9, 9), b = nz(-20, 20); const c = a * x + b;
      if (Math.abs(a) === 1) return twoStep(L);
      return { q: `Solve for <i>x</i>: ${lin(a, b)} = ${num(c)}`, a: numAns(x), steps: [`${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} on both sides: ${term(a, 'x')} = ${num(c - b)}`, `Divide both sides by ${num(a)}: <i>x</i> = <b>${num(x)}</b>`, `Check: ${num(a)}${P(x)} + ${P(b)} = ${num(c)} ✓`] };
    }
    const a = pick([2, 3, 4, 5]), b = nz(-10, 10), q = nz(-6, 6), xx = a * q; const c = q + b;
    return { q: `Solve for <i>x</i>: <span class="fr"><span><i>x</i></span><span>${a}</span></span> ${b < 0 ? MINUS : '+'} ${Math.abs(b)} = ${num(c)}`, a: numAns(xx), steps: [`${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)}: <i>x</i>/${a} = ${num(c - b)}`, `Multiply both sides by ${a}: <i>x</i> = <b>${num(xx)}</b>`] };
  };

  // ---------- Unit 4: inequalities ----------
  const SYM = { '<': '&lt;', '>': '&gt;', '<=': '≤', '>=': '≥' };
  const FLIP = { '<': '>', '>': '<', '<=': '>=', '>=': '<=' };
  const ineqSolve = (L) => {
    const k = nz(-10, 10); const s = pick(['<', '>', '<=', '>=']);
    let a, b;
    if (L === 1) { a = 1; b = nz(-12, 12); }
    else if (L === 2) { a = R(2, 8); b = nz(-15, 15); }
    else { a = -R(2, 8); b = nz(-15, 15); }
    const c = a * k + b; const res = a < 0 ? FLIP[s] : s;
    const show = (sym, val) => `<i>x</i> ${SYM[sym]} ${num(val)}`;
    const steps = [];
    if (b !== 0) steps.push(`${b > 0 ? 'Subtract' : 'Add'} ${Math.abs(b)} on both sides: ${term(a, 'x')} ${SYM[s]} ${num(c - b)}`);
    if (a !== 1) steps.push(`Divide by ${num(a)}${a < 0 ? ' — dividing by a negative <b>flips</b> the inequality sign' : ''}.`);
    steps.push(`<b>${show(res, k)}</b>`);
    return { q: `Solve: ${lin(a, b)} ${SYM[s]} ${num(c)}`, a: mc(show(res, k), [show(FLIP[res], k), show(res, -k), show(FLIP[res], -k), show(res, k + 1)]), steps, hint: a < 0 ? `What happens to the sign when you divide by a negative?` : undefined };
  };
  const ineqGraph = (L) => {
    const k = R(-6, 6); const closed = Math.random() < 0.5, right = Math.random() < 0.5;
    const s = right ? (closed ? '>=' : '>') : (closed ? '<=' : '<');
    const show = (sym) => `<i>x</i> ${SYM[sym]} ${num(k)}`;
    const others = ['<', '>', '<=', '>='].filter((t) => t !== s).map(show);
    return { q: `Which inequality does this graph show?<div class="fig">${numberLineSVG(k, closed, right)}</div>`, a: mc(show(s), others), steps: [`${closed ? 'A filled circle means the number is included (≤ or ≥).' : 'An open circle means the number is not included (&lt; or &gt;).'}`, `Shading to the ${right ? 'right means greater than' : 'left means less than'}.`, `<b>${show(s)}</b>`] };
  };

  // ---------- Unit 5: ratios, rates & proportions ----------
  const unitRate = (L) => {
    const ctx = pick([
      () => { const n = R(3, 12), up = R(L === 1 ? 2 : 101, L === 1 ? 9 : 899) / (L === 1 ? 1 : 100); return { q: `${n} notebooks cost ${money(n * up)}. What is the cost per notebook?`, v: up, unit: '$', s: `${money(n * up)} ÷ ${n}` }; },
      () => { const h = R(2, 6), r = R(35, 70) + (L > 1 ? R(0, 9) / 10 : 0); return { q: `A car travels ${num(round(h * r, 2))} miles in ${h} hours. How many miles per hour?`, v: r, unit: 'mph', s: `${num(round(h * r, 2))} ÷ ${h}` }; },
      () => { const lb = L === 1 ? R(2, 6) : R(3, 9) / 2, up = R(119, 499) / 100; const tot = round(lb * up, 2); const u = round(tot / lb, 4); return { q: `${num(lb)} pounds of apples cost ${money(tot)}. What is the price per pound? (Round to the nearest cent.)`, v: round(u, 2), unit: '$', s: `${money(tot)} ÷ ${num(lb)}`, tol: 0.006 }; },
      () => { const m = R(3, 8), w = R(30, 75); return { q: `Maya types ${m * w} words in ${m} minutes. How many words per minute?`, v: w, unit: 'wpm', s: `${m * w} ÷ ${m}` }; },
    ])();
    return { q: ctx.q, a: numAns(ctx.v, { tol: ctx.tol || 1e-6, unit: ctx.unit }), steps: [`Unit rate = total ÷ number of units`, `${ctx.s} = <b>${num(ctx.v)}</b>`] };
  };
  const unitRateFrac = (L) => {
    const ds = L === 1 ? [2, 4] : [2, 3, 4, 5, 6, 8];
    const d1 = pick(ds), d2 = pick(ds); const n1 = R(1, L === 3 ? 2 * d1 : d1), n2 = R(1, d2 - 1 || 1);
    const ctx = pick([
      [`walks ${frac(n1, d1)} mile in ${frac(n2, d2)} hour`, 'miles per hour'],
      [`paints ${frac(n1, d1)} of a wall in ${frac(n2, d2)} hour`, 'walls per hour'],
      [`uses ${frac(n1, d1)} cup of sugar for ${frac(n2, d2)} of a batch`, 'cups per batch'],
    ]);
    const who = pick(['Jordan', 'Ava', 'Leo', 'Priya', 'Sam']);
    return { q: `${who} ${ctx[0]}. What is the unit rate in ${ctx[1]}?`, a: fracAns(n1 * d2, d1 * n2), steps: [`Unit rate = ${frac(n1, d1)} ÷ ${frac(n2, d2)}`, `= ${frac(n1, d1)} × ${frac(d2, n2)} = <b>${frac(n1 * d2, d1 * n2)}</b>`, `(You can type a fraction like 8/3 or a decimal.)`], hint: `Divide the first quantity by the second. Dividing by a fraction means multiplying by its reciprocal.` };
  };
  const compareRates = (L) => {
    // realistic price per item in cents for each product; the two stores differ by up to about 30%
    const [item, lo, hi] = pick([['granola bars', 50, 125], ['juice boxes', 40, 100], ['pencils', 15, 60], ['cans of soup', 100, 250], ['bottles of water', 50, 150]]);
    let a, b, pa, pb;
    do {
      a = R(3, 12); b = R(3, 12);
      const base = R(lo, hi);
      pa = round(Math.round(base * (R(85, 115) / 100)) * a / 100, 2);
      pb = round(Math.round(base * (R(85, 115) / 100)) * b / 100, 2);
    } while (a === b || Math.abs(pa / a - pb / b) < 0.02);
    const ua = pa / a, ub = pb / b; const best = ua < ub ? 'A' : 'B';
    const ca = `Store A: ${a} ${item} for ${money(pa)}`, cb = `Store B: ${b} ${item} for ${money(pb)}`;
    return { q: `Which is the better buy?<br>${ca}<br>${cb}`, a: { type: 'mc', choices: ['Store A', 'Store B'], correct: best === 'A' ? 0 : 1 }, steps: [`Find each unit price. A: ${money(pa)} ÷ ${a} ≈ ${money(round(ua, 3))} each`, `B: ${money(pb)} ÷ ${b} ≈ ${money(round(ub, 3))} each`, `The lower unit price is the better buy: <b>Store ${best}</b>`] };
  };
  const fdp = (L) => {
    const pool = L === 1 ? [[1, 2], [1, 4], [3, 4], [1, 5], [2, 5], [3, 10], [7, 10]] : L === 2 ? [[1, 8], [3, 8], [5, 8], [3, 20], [7, 25], [9, 20], [11, 50], [4, 5]] : [[1, 3], [2, 3], [1, 6], [5, 6], [7, 8], [13, 40], [5, 4], [9, 8]];
    const [n, d] = pick(pool); const dec = n / d; const pct = round(dec * 100, 4);
    const kind = R(0, 3);
    const repeating = d % 3 === 0;
    if (kind === 0) return { q: `Write ${frac(n, d)} as a decimal.${repeating ? ' (Round to the nearest hundredth.)' : ''}`, a: numAns(repeating ? round(dec, 2) : dec, { tol: repeating ? 0.006 : 1e-6 }), steps: [`Divide the numerator by the denominator: ${n} ÷ ${d} = ${repeating ? num(round(dec, 4)) + '…' : num(dec)}`, `<b>${num(repeating ? round(dec, 2) : dec)}</b>`] };
    if (kind === 1) return { q: `Write ${frac(n, d)} as a percent. (Type just the number.${repeating ? ' Round to the nearest tenth.' : ''})`, a: numAns(repeating ? round(pct, 1) : pct, { tol: repeating ? 0.06 : 1e-6, unit: '%' }), steps: [`${frac(n, d)} = ${n} ÷ ${d} = ${repeating ? num(round(dec, 4)) + '…' : num(dec)}`, `Multiply by 100: <b>${num(repeating ? round(pct, 1) : pct)}%</b>`] };
    if (kind === 2 && !repeating) return { q: `Write ${num(dec)} as a percent. (Type just the number.)`, a: numAns(pct, { unit: '%' }), steps: [`Multiply by 100 (move the decimal point two places right).`, `<b>${num(pct)}%</b>`] };
    if (!repeating) return { q: `Write ${num(pct)}% as a fraction in simplest form.`, a: fracAns(n, d), steps: [`${num(pct)}% = ${num(pct)}/100`, `Simplify: <b>${frac(n, d)}</b>`] };
    return fdp(L);
  };
  const proportion = (L) => {
    const a = R(2, 9); let b = R(2, 12); while (b === a) b = R(2, 12); const k = L === 1 ? R(2, 6) : L === 2 ? pick([1.5, 2.5, 3, 4, 5, 0.5]) : R(2, 12) / pick([2, 4]);
    const c = round(a * k, 4), d = round(b * k, 4);
    const where = R(0, 1); const left = `<span class="fr"><span>${a}</span><span>${b}</span></span>`;
    if (where === 0) return { q: `Solve the proportion: ${left} = <span class="fr"><span>${num(c)}</span><span><i>x</i></span></span>`, a: numAns(d), steps: [`Cross-multiply: ${a} · <i>x</i> = ${b} · ${num(c)} = ${num(round(b * c, 4))}`, `<i>x</i> = ${num(round(b * c, 4))} ÷ ${a} = <b>${num(d)}</b>`] };
    return { q: `Solve the proportion: ${left} = <span class="fr"><span><i>x</i></span><span>${num(d)}</span></span>`, a: numAns(c), steps: [`Cross-multiply: ${b} · <i>x</i> = ${a} · ${num(d)} = ${num(round(a * d, 4))}`, `<i>x</i> = ${num(round(a * d, 4))} ÷ ${b} = <b>${num(c)}</b>`] };
  };
  const constProp = (L) => {
    const k = L === 1 ? R(2, 9) : L === 2 ? pick([1.5, 2.5, 0.5, 3.5, 1.25, 0.75]) : pick([[1, 3], [2, 3], [3, 4], [5, 2], [4, 3]]);
    const kv = Array.isArray(k) ? k[0] / k[1] : k;
    const step = Array.isArray(k) ? k[1] : 1;
    const mult = L === 1 ? 1 : 2;
    const xs = [1, 2, 3, 4].map((i) => i * step * mult);
    const rows = xs.map((x) => `<tr><td>${x}</td><td>${num(round(x * kv, 4))}</td></tr>`).join('');
    const table = `<table class="tbl"><tr><th><i>x</i></th><th><i>y</i></th></tr>${rows}</table>`;
    const kShow = Array.isArray(k) ? frac(k[0], k[1]) : num(k);
    if (Math.random() < 0.5) return { q: `The table shows a proportional relationship. What is the constant of proportionality <i>k</i>?<div class="fig">${table}</div>`, a: Array.isArray(k) ? fracAns(k[0], k[1]) : numAns(kv), steps: [`<i>k</i> = <i>y</i> ÷ <i>x</i> for any row: ${num(round(xs[0] * kv, 4))} ÷ ${xs[0]}`, `<i>k</i> = <b>${kShow}</b>`] };
    const eq = (v) => `<i>y</i> = ${v}<i>x</i>`;
    const wrong = Array.isArray(k) ? frac(k[1], k[0]) : num(round(1 / kv, 3));
    return { q: `Which equation represents the table?<div class="fig">${table}</div>`, a: mc(eq(kShow), [eq(wrong), `<i>y</i> = <i>x</i> + ${num(round(xs[0] * kv - xs[0], 4))}`, eq(num(round(kv * 2, 4))), `<i>y</i> = ${kShow}<i>x</i> + 1`]), steps: [`<i>k</i> = <i>y</i> ÷ <i>x</i> = ${kShow}`, `Proportional relationships have the form <i>y</i> = <i>kx</i>: <b>${eq(kShow)}</b>`] };
  };

  // ---------- Unit 6: percents ----------
  const percentOf = (L) => {
    const p = L === 1 ? pick([10, 20, 25, 50, 75]) : L === 2 ? pick([5, 15, 30, 35, 40, 60, 12]) : pick([2.5, 12.5, 7, 18, 120, 150, 0.5]);
    const n = L === 1 ? R(2, 20) * 4 : R(4, 40) * 5;
    const v = round(p / 100 * n, 4);
    return { q: `What is ${num(p)}% of ${n}?`, a: numAns(v), steps: [`${num(p)}% = ${num(p / 100)}`, `${num(p / 100)} × ${n} = <b>${num(v)}</b>`] };
  };
  const percentFind = (L) => {
    const p = L === 1 ? pick([10, 20, 25, 50, 75]) : pick([5, 15, 30, 40, 60, 80, 12.5, 150]);
    const whole = R(2, 16) * (L === 1 ? 4 : 8); const part = round(p / 100 * whole, 4);
    return { q: `${num(part)} is what percent of ${whole}? (Type just the number.)`, a: numAns(p, { unit: '%' }), steps: [`part ÷ whole = ${num(part)} ÷ ${whole} = ${num(round(part / whole, 4))}`, `× 100 = <b>${num(p)}%</b>`] };
  };
  const taxTip = (L) => {
    const cost = R(800, 8000) / 100; const isTip = Math.random() < 0.5;
    const p = isTip ? pick([15, 18, 20, 25]) : pick([4, 5, 6, 7.5, 8.25]);
    const add = round(cost * p / 100, 4); const total = round(cost + add, 2);
    const what = L === 1 ? 'amount' : 'total';
    const v = what === 'amount' ? round(add, 2) : total;
    return { q: `A ${isTip ? 'restaurant bill' : 'video game'} costs ${money(cost)}. ${isTip ? `You leave a ${p}% tip` : `Sales tax is ${num(p)}%`}. What is the ${what === 'amount' ? (isTip ? 'tip' : 'tax') : 'total cost'}? (Round to the nearest cent.)`, a: numAns(v, { tol: 0.011, unit: '$' }), steps: [`${isTip ? 'Tip' : 'Tax'} = ${num(p / 100)} × ${money(cost)} ≈ ${money(round(add, 2))}`, what === 'amount' ? `<b>${money(v)}</b>` : `Total = ${money(cost)} + ${money(round(add, 2))} = <b>${money(v)}</b>`] };
  };
  const discount = (L) => {
    const price = R(10, 120) + (L > 1 ? pick([0, 0.5, 0.99, 0.25]) : 0); const p = pick([10, 15, 20, 25, 30, 40, 50]);
    const isMarkup = L === 3 && Math.random() < 0.5;
    const change = round(price * p / 100, 4); const v = round(isMarkup ? price + change : price - change, 2);
    const item = pick(['jacket', 'pair of shoes', 'skateboard', 'backpack']);
    return { q: isMarkup ? `A store buys a ${item} for ${money(price)} and marks it up ${p}%. What is the selling price? (Nearest cent.)` : `A ${item} costs ${money(price)} and is ${p}% off. What is the sale price? (Nearest cent.)`, a: numAns(v, { tol: 0.011, unit: '$' }), steps: [`${isMarkup ? 'Markup' : 'Discount'} = ${num(p / 100)} × ${money(price)} ≈ ${money(round(change, 2))}`, `${money(price)} ${isMarkup ? '+' : MINUS} ${money(round(change, 2))} = <b>${money(v)}</b>`, isMarkup ? `Shortcut: ${money(price)} × ${num(1 + p / 100)}` : `Shortcut: ${money(price)} × ${num(1 - p / 100)}`] };
  };
  const percentChange = (L) => {
    const a = R(2, 20) * 5; const p = pick([10, 20, 25, 40, 50, 60, 75]); const up = Math.random() < 0.5 || L === 1;
    const b = round(a * (1 + (up ? p : -p) / 100), 4);
    return { q: `A value changes from ${num(a)} to ${num(b)}. What is the percent ${up ? 'increase' : 'decrease'}? (Type just the number.)`, a: numAns(p, { unit: '%' }), steps: [`Change = ${num(b)} ${MINUS} ${num(a)} = ${num(round(b - a, 4))}`, `Percent change = change ÷ original = ${num(Math.abs(round(b - a, 4)))} ÷ ${num(a)} = ${num(p / 100)}`, `<b>${p}%</b> ${up ? 'increase' : 'decrease'}`] };
  };

  // ---------- Unit 7: angles, triangles, scale drawings ----------
  const anglePairs = (L) => {
    const type = pick(['complementary', 'supplementary', 'vertical']); const tot = type === 'complementary' ? 90 : 180;
    if (L < 3 || type === 'vertical') {
      const a = type === 'complementary' ? R(10, 80) : R(20, 160);
      if (type === 'vertical') return { q: `Two angles are vertical angles. One measures ${a}°. What is the other angle?`, a: numAns(a, { unit: '°' }), steps: [`Vertical angles are equal.`, `<b>${a}°</b>`] };
      return { q: `Two angles are ${type}. One measures ${a}°. What is the other angle?`, a: numAns(tot - a, { unit: '°' }), steps: [`${type[0].toUpperCase() + type.slice(1)} angles add to ${tot}°.`, `${tot} ${MINUS} ${a} = <b>${tot - a}°</b>`] };
    }
    let p, q, r, x;
    do { p = R(2, 5); q = R(1, 4); x = R(5, 30); r = tot - (p + q) * x; } while (r < -20 || r > 40 || r === 0 || p * x + r <= 0);
    return { q: `Angles measuring (${lin(p, r)})° and ${term(q, 'x')}° are ${type}. Find <i>x</i>.`, a: numAns(x), steps: [`${type[0].toUpperCase() + type.slice(1)}: ${lin(p, r)} + ${term(q, 'x')} = ${tot}`, `${lin(p + q, r)} = ${tot}, so ${term(p + q, 'x')} = ${tot - r}`, `<i>x</i> = <b>${num(x)}</b>`] };
  };
  const triangleSum = (L) => {
    const a = R(20, 100), b = R(15, 160 - a - 5); const c = 180 - a - b;
    if (L < 3) return { q: `A triangle has angles of ${a}° and ${b}°. What is the third angle?`, a: numAns(c, { unit: '°' }), steps: [`Angles in a triangle add to 180°.`, `180 ${MINUS} ${a} ${MINUS} ${b} = <b>${c}°</b>`] };
    let x, m; do { m = R(2, 4); x = R(10, 40); } while (180 - m * x - x <= 10);
    const third = 180 - m * x - x;
    return { q: `A triangle has angles of <i>x</i>°, ${m}<i>x</i>°, and ${third}°. Find <i>x</i>.`, a: numAns(x), steps: [`<i>x</i> + ${m}<i>x</i> + ${third} = 180`, `${m + 1}<i>x</i> = ${180 - third}`, `<i>x</i> = <b>${x}</b>`] };
  };
  const scaleDrawing = (L) => {
    const s = pick([2, 4, 5, 8, 10, 12, 20]); const unit = pick(['ft', 'm']);
    const d = L === 1 ? R(2, 9) : R(3, 19) / 2;
    if (L === 3 && Math.random() < 0.5) {
      const actual = round(d * s, 4);
      return { q: `A map uses the scale 1 in : ${s} ${unit}. A real distance is ${num(actual)} ${unit}. How long is it on the map, in inches?`, a: numAns(d), steps: [`Divide by the scale: ${num(actual)} ÷ ${s}`, `= <b>${num(d)} in</b>`] };
    }
    return { q: `A blueprint uses the scale 1 in : ${s} ${unit}. A wall is ${num(d)} in long on the blueprint. How long is the real wall, in ${unit}?`, a: numAns(d * s, { unit }), steps: [`Each inch stands for ${s} ${unit}.`, `${num(d)} × ${s} = <b>${num(round(d * s, 4))} ${unit}</b>`] };
  };

  // ---------- Unit 8: probability ----------
  const bag = () => { const r = R(1, 8), b = R(1, 8), g = R(1, 8); return { r, b, g, t: r + b + g, txt: `A bag has ${r} red, ${b} blue, and ${g} green marbles.` }; };
  const simpleProb = (L) => {
    const B = bag(); const which = pick([['red', B.r], ['blue', B.b], ['green', B.g]]);
    if (L === 1) return { q: `${B.txt} You pick one without looking. What is P(${which[0]})?`, a: fracAns(which[1], B.t), steps: [`P = favorable ÷ total = ${which[1]} ÷ ${B.t}`, `<b>${frac(which[1], B.t)}</b>`] };
    return { q: `${B.txt} You pick one without looking. What is P(not ${which[0]})?`, a: fracAns(B.t - which[1], B.t), steps: [`Not ${which[0]}: ${B.t} ${MINUS} ${which[1]} = ${B.t - which[1]} marbles`, `P = ${B.t - which[1]}/${B.t} = <b>${frac(B.t - which[1], B.t)}</b>`] };
  };
  const compound = (L) => {
    const t = L === 1 ? 0 : R(0, 2);
    if (t === 0) { const f = R(1, 6); return { q: `You flip a coin and roll a number cube (1–6). What is P(heads and ${f})?`, a: fracAns(1, 12), steps: [`Independent events: multiply. P(heads) = 1/2, P(${f}) = 1/6`, `1/2 × 1/6 = <b>${frac(1, 12)}</b>`] }; }
    if (t === 1) { const s = R(2, 12); const ways = 6 - Math.abs(7 - s); return { q: `You roll two number cubes. What is the probability the sum is ${s}?`, a: fracAns(ways, 36), steps: [`There are 6 × 6 = 36 equally likely outcomes.`, `Count the ways to make ${s}: ${ways}`, `P = ${ways}/36 = <b>${frac(ways, 36)}</b>`] }; }
    const B = bag(); const a = pick([['red', B.r], ['blue', B.b]]);
    return { q: `${B.txt} You pick one, put it back, then pick again. What is P(${a[0]}, then ${a[0]})?`, a: fracAns(a[1] * a[1], B.t * B.t), steps: [`With replacement the picks are independent.`, `${frac(a[1], B.t)} × ${frac(a[1], B.t)} = <b>${frac(a[1] * a[1], B.t * B.t)}</b>`] };
  };
  const sampleSpace = (L) => {
    if (L === 1 || Math.random() < 0.4) { const s = R(2, 6), p = R(2, 5), h = L === 3 ? R(2, 4) : 1; return { q: `You have ${s} shirts and ${p} pairs of pants${h > 1 ? ` and ${h} hats` : ''}. How many different outfits can you make?`, a: numAns(s * p * h), steps: [`Multiply the number of choices (counting principle).`, `${s} × ${p}${h > 1 ? ` × ${h}` : ''} = <b>${s * p * h}</b>`] }; }
    const n = pick([20, 30, 40, 60, 80, 120]); const [a, b] = pick([[1, 2], [1, 4], [1, 5], [3, 4], [1, 3], [2, 5], [1, 6]]);
    if (n * a % b !== 0) return sampleSpace(L);
    return { q: `The probability of winning a game is ${frac(a, b)}. If you play ${n} times, about how many times should you expect to win?`, a: numAns(n * a / b), steps: [`Expected = probability × number of trials`, `${frac(a, b)} × ${n} = <b>${n * a / b}</b>`] };
  };
  const experimental = (L) => {
    const total = pick([20, 25, 40, 50]); const k = R(2, total - 2);
    const event = pick(['the spinner landed on blue', 'the free throw went in', 'the coin landed heads']);
    return { q: `In ${total} trials, ${event} ${k} times. What is the experimental probability? (Fraction or decimal.)`, a: fracAns(k, total), steps: [`Experimental probability = times it happened ÷ total trials`, `${k}/${total} = <b>${frac(k, total)}</b> (= ${num(round(k / total, 4))})`] };
  };

  // ---------- Unit 9: circles & area ----------
  const circumference = (L) => {
    const r = L === 1 ? R(1, 10) : R(2, 25); const useD = Math.random() < 0.5;
    const v = round(2 * 3.14 * r, 2);
    return { q: `A circle has a ${useD ? `diameter of ${2 * r}` : `radius of ${r}`} cm. Find the circumference. (Use π ≈ 3.14.)`, a: numAns(v, { tol: 0.011, unit: 'cm' }), steps: [`C = π${useD ? 'd' : ' × 2r'}`, useD ? `C = 3.14 × ${2 * r} = <b>${num(v)} cm</b>` : `C = 3.14 × 2 × ${r} = <b>${num(v)} cm</b>`] };
  };
  const circleArea = (L) => {
    const r = L === 1 ? R(1, 10) : R(2, 20); const useD = L === 3 && Math.random() < 0.6;
    const v = round(3.14 * r * r, 2);
    return { q: `A circle has a ${useD ? `diameter of ${2 * r}` : `radius of ${r}`} in. Find its area. (Use π ≈ 3.14.)`, a: numAns(v, { tol: 0.011, unit: 'in²' }), steps: [useD ? `The radius is half the diameter: r = ${r}` : `A = πr²`, `A = 3.14 × ${r}² = 3.14 × ${r * r} = <b>${num(v)} in²</b>`], hint: useD ? `Area uses the radius, not the diameter.` : undefined };
  };
  const compositeArea = (L) => {
    const w = R(4, 14), h = R(3, 10);
    if (L < 3 || Math.random() < 0.5) {
      const th = R(2, 8); const v = w * h + w * th / 2;
      return { q: `A shape is a ${w} m by ${h} m rectangle with a triangle on top. The triangle's base is ${w} m and its height is ${th} m. What is the total area?`, a: numAns(v, { unit: 'm²' }), steps: [`Rectangle: ${w} × ${h} = ${w * h}`, `Triangle: ½ × ${w} × ${th} = ${num(w * th / 2)}`, `Total: <b>${num(v)} m²</b>`] };
    }
    const d = w % 2 === 0 ? w : w + 1; const v = round(d * h + 3.14 * (d / 2) * (d / 2) / 2, 2);
    return { q: `A shape is a ${d} ft by ${h} ft rectangle with a semicircle on the ${d} ft side. What is the total area? (Use π ≈ 3.14.)`, a: numAns(v, { tol: 0.011, unit: 'ft²' }), steps: [`Rectangle: ${d} × ${h} = ${d * h}`, `Semicircle radius = ${d / 2}: ½ × 3.14 × ${d / 2}² = ${num(round(3.14 * (d / 2) * (d / 2) / 2, 2))}`, `Total: <b>${num(v)} ft²</b>`] };
  };

  // ---------- Unit 10: surface area & volume ----------
  const prismVolume = (L) => {
    if (L < 3 || Math.random() < 0.5) { const l = R(2, 12), w = R(2, 10), h = R(2, 10); return { q: `Find the volume of a rectangular prism ${l} cm long, ${w} cm wide, and ${h} cm tall.`, a: numAns(l * w * h, { unit: 'cm³' }), steps: [`V = l × w × h`, `${l} × ${w} × ${h} = <b>${l * w * h} cm³</b>`] }; }
    const b = R(2, 10) * 2, th = R(2, 9), len = R(3, 12); const v = b * th / 2 * len;
    return { q: `A triangular prism has a triangle base with base ${b} in and height ${th} in. The prism is ${len} in long. Find its volume.`, a: numAns(v, { unit: 'in³' }), steps: [`Base area = ½ × ${b} × ${th} = ${b * th / 2}`, `V = base area × length = ${b * th / 2} × ${len} = <b>${v} in³</b>`] };
  };
  const cylinderVolume = (L) => {
    const r = R(1, L === 1 ? 5 : 10), h = R(2, 12); const v = round(3.14 * r * r * h, 2);
    return { q: `Find the volume of a cylinder with radius ${r} cm and height ${h} cm. (Use π ≈ 3.14.)`, a: numAns(v, { tol: 0.011, unit: 'cm³' }), steps: [`V = πr²h`, `3.14 × ${r}² × ${h} = 3.14 × ${r * r} × ${h} = <b>${num(v)} cm³</b>`] };
  };
  const surfaceArea = (L) => {
    const l = R(2, 10), w = R(2, 8), h = R(2, 9); const v = 2 * (l * w + l * h + w * h);
    return { q: `Find the surface area of a rectangular prism ${l} ft by ${w} ft by ${h} ft.`, a: numAns(v, { unit: 'ft²' }), steps: [`Three pairs of faces: ${l}×${w} = ${l * w}, ${l}×${h} = ${l * h}, ${w}×${h} = ${w * h}`, `SA = 2(${l * w} + ${l * h} + ${w * h}) = <b>${v} ft²</b>`] };
  };
  const pyramidVolume = (L) => {
    const s = R(2, 10); const h = s % 3 === 0 ? R(2, 12) : R(1, 4) * 3;
    const v = s * s * h / 3;
    return { q: `A square pyramid has base edges of ${s} m and a height of ${h} m. Find its volume.`, a: numAns(v, { unit: 'm³' }), steps: [`V = ⅓ × base area × height`, `Base area = ${s} × ${s} = ${s * s}`, `⅓ × ${s * s} × ${h} = <b>${num(v)} m³</b>`] };
  };

  // ---------- catalog ----------
  const UNITS = [
    { id: 'u1', name: 'Integers & Rational Numbers', short: 'Add & subtract signed numbers', icon: '±', skills: [
      { id: 'absval', name: 'Absolute value', gen: absval },
      { id: 'order', name: 'Ordering numbers', gen: order },
      { id: 'addint', name: 'Adding integers', gen: addInt },
      { id: 'subint', name: 'Subtracting integers', gen: subInt },
      { id: 'addsubfrac', name: 'Adding & subtracting fractions', gen: addSubFrac },
      { id: 'addsubdec', name: 'Adding & subtracting decimals', gen: addSubDec },
      { id: 'distance', name: 'Distance on a number line', gen: distance } ] },
    { id: 'u2', name: 'Multiply & Divide', short: 'Signed numbers, order of operations', icon: '×', skills: [
      { id: 'muldivint', name: 'Multiplying & dividing integers', gen: mulDivInt },
      { id: 'muldivfrac', name: 'Multiplying & dividing fractions', gen: mulDivFrac },
      { id: 'muldivdec', name: 'Multiplying & dividing decimals', gen: mulDivDec },
      { id: 'orderops', name: 'Order of operations & exponents', gen: orderOps } ] },
    { id: 'u3', name: 'Expressions & Equations', short: 'Like terms, distributing, two-step equations', icon: 'x', skills: [
      { id: 'liketerms', name: 'Combining like terms', gen: likeTerms },
      { id: 'evaluate', name: 'Evaluating expressions', gen: evaluate },
      { id: 'distribute', name: 'Distributive property', gen: distribute },
      { id: 'factorgcf', name: 'Factoring out the GCF', gen: factorGCF },
      { id: 'twostep', name: 'Two-step equations', gen: twoStep } ] },
    { id: 'u4', name: 'Inequalities', short: 'Graph, write and solve', icon: '<', skills: [
      { id: 'ineqgraph', name: 'Graphing inequalities', gen: ineqGraph },
      { id: 'ineqsolve', name: 'Solving inequalities', gen: ineqSolve } ] },
    { id: 'u5', name: 'Ratios, Rates & Proportions', short: 'Unit rates, conversions, proportions', icon: '÷', skills: [
      { id: 'unitrate', name: 'Unit rates', gen: unitRate },
      { id: 'unitratefrac', name: 'Unit rates with fractions', gen: unitRateFrac },
      { id: 'comparerates', name: 'Comparing rates', gen: compareRates },
      { id: 'fdp', name: 'Fractions, decimals & percents', gen: fdp },
      { id: 'proportion', name: 'Solving proportions', gen: proportion },
      { id: 'constprop', name: 'Constant of proportionality', gen: constProp } ] },
    { id: 'u6', name: 'Percents', short: 'Tax, tip, discount, percent change', icon: '%', skills: [
      { id: 'percentof', name: 'Percent of a number', gen: percentOf },
      { id: 'percentfind', name: 'Finding the percent', gen: percentFind },
      { id: 'taxtip', name: 'Tax & tip', gen: taxTip },
      { id: 'discount', name: 'Discount & markup', gen: discount },
      { id: 'percentchange', name: 'Percent change', gen: percentChange } ] },
    { id: 'u7', name: 'Angles & Scale Drawings', short: 'Angle pairs, triangles, scale', icon: '∠', skills: [
      { id: 'anglepairs', name: 'Angle relationships', gen: anglePairs },
      { id: 'trianglesum', name: 'Triangle angle sum', gen: triangleSum },
      { id: 'scale', name: 'Scale drawings', gen: scaleDrawing } ] },
    { id: 'u8', name: 'Probability', short: 'Simple, compound, expected', icon: '🎲', skills: [
      { id: 'simpleprob', name: 'Simple probability', gen: simpleProb },
      { id: 'compound', name: 'Compound events', gen: compound },
      { id: 'samplespace', name: 'Counting & expected results', gen: sampleSpace },
      { id: 'experimental', name: 'Experimental probability', gen: experimental } ] },
    { id: 'u9', name: 'Circles & Area', short: 'Circumference, area, composite shapes', icon: '◯', skills: [
      { id: 'circumference', name: 'Circumference', gen: circumference },
      { id: 'circlearea', name: 'Area of a circle', gen: circleArea },
      { id: 'compositearea', name: 'Composite area', gen: compositeArea } ] },
    { id: 'u10', name: 'Surface Area & Volume', short: 'Prisms, cylinders, pyramids', icon: '▣', skills: [
      { id: 'prismvol', name: 'Volume of prisms', gen: prismVolume },
      { id: 'cylvol', name: 'Volume of cylinders', gen: cylinderVolume },
      { id: 'surfarea', name: 'Surface area', gen: surfaceArea },
      { id: 'pyrvol', name: 'Volume of pyramids', gen: pyramidVolume } ] },
  ];

  // Class pacing for 2026–27, from the teacher's daily slides (Units 1–5 actual,
  // later units estimated from last year's dates). [unitId, month, day] = start date.
  const PACING = [
    ['u1', 8, 1], ['u2', 9, 21], ['u3', 10, 9], ['u4', 11, 1], ['u5', 11, 14],
    ['u6', 1, 21], ['u7', 2, 9], ['u8', 3, 2], ['u9', 4, 1], ['u10', 4, 21],
  ];
  function pacedUnit(date = new Date()) {
    const m = date.getMonth() + 1, d = date.getDate();
    // school-year ordinal: Aug=0 ... Jul=11
    const ord = (mm, dd) => ((mm + 4) % 12) * 40 + dd;
    const now = ord(m, d);
    let cur = PACING[0][0];
    for (const [u, mm, dd] of PACING) if (ord(mm, dd) <= now) cur = u;
    return cur;
  }

  // Parse a typed answer: integer, decimal, or fraction (a/b), optional leading minus.
  function parseAnswer(s) {
    if (s == null) return NaN;
    s = String(s).replace(/−/g, '-').replace(/\s+/g, '').replace(/[%$°]/g, '');
    if (!s) return NaN;
    if (/^-?\d+\/\d+$/.test(s) || /^-?\d*\.?\d+\/\d*\.?\d+$/.test(s)) {
      const [n, d] = s.split('/').map(Number); return d === 0 ? NaN : n / d;
    }
    if (/^-?(\d+\.?\d*|\.\d+)$/.test(s)) return Number(s);
    return NaN;
  }
  function checkNum(input, a) {
    const v = parseAnswer(input); if (isNaN(v)) return false;
    let tol = a.tol || 1e-6;
    // allow a rounded decimal for non-terminating fraction answers
    if (a.isFrac && !String(input).includes('/')) tol = Math.max(tol, 0.006);
    return Math.abs(v - a.value) <= tol + 1e-9;
  }

  global.M7 = { UNITS, PACING, pacedUnit, parseAnswer, checkNum, _h: { frac, num, R } };
})(typeof window !== 'undefined' ? window : globalThis);
