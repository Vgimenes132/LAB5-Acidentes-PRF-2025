/* Painel de acidentes PRF 2025.
   Lê window.DADOS (gerado a partir da base tratada) e desenha tudo em HTML/SVG/canvas,
   sem bibliotecas externas: funciona offline e no GitHub Pages. */
(function () {
  'use strict';
  const D = window.DADOS;
  if (!D) { document.body.insertAdjacentHTML('afterbegin', '<p style="padding:16px">Não foi possível carregar os dados (dados.js).</p>'); return; }

  // utilitários
  const $ = (id) => document.getElementById(id);
  const fmt = (n) => Math.round(n).toLocaleString('pt-BR');
  const fmt1 = (n) => n.toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
  const pct = (n) => fmt1(n) + '%';
  const taxa = (m, a) => (a ? (100 * m) / a : 0);
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const MESES = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  const MES_AB = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
  const DIAS = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
  const DIAS_AB = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  const FAIXAS = [['Madrugada (0h a 5h)', 0, 5], ['Manhã (6h a 11h)', 6, 11], ['Tarde (12h a 17h)', 12, 17], ['Noite (18h a 23h)', 18, 23]];
  const RAMP_LIGHT = ['#cde2fb', '#9ec5f4', '#6da7ec', '#3987e5', '#256abf', '#184f95', '#0d366b'];
  const RAMP_DARK = ['#104281', '#184f95', '#1c5cab', '#256abf', '#3987e5', '#6da7ec', '#9ec5f4'];

  // estado
  const estado = { uf: 'BR', medida: 'a' };   // medida: 'a' acidentes | 'm' mortes
  const MI = () => (estado.medida === 'a' ? 0 : 1);   // índice em [a, m, f]
  const nomeMedida = (plural = true) => (estado.medida === 'a' ? (plural ? 'acidentes' : 'acidente') : (plural ? 'mortes' : 'morte'));

  // dados
  function normaliza(u, sigla) {
    const idxMap = (arr) => { const m = new Map(); (arr || []).forEach(([i, a, mo, f]) => m.set(i, [a, mo, f])); return m; };
    return {
      tot: u.tot.slice(),
      mes: u.mes.map((v) => v.slice()),
      sh: u.sh.map((v) => v.slice()),
      causa: idxMap(u.causa), tipo: idxMap(u.tipo), meteo: idxMap(u.meteo), fase: idxMap(u.fase),
      pista: idxMap(u.pista), trac: idxMap(u.trac),
      solo: Object.assign({}, u.solo), cls: Object.assign({}, u.cls), fds: Object.assign({}, u.fds),
      trecho: u.trecho.map(([br, km, a, m, f]) => ({ br, km, uf: sigla, a, m, f })),
      muni: u.muni.map(([i, a, m, f]) => ({ nome: D.muni[i], uf: sigla, a, m, f })),
      grid: u.grid.map(([y, x, a, m]) => [y, x, a, m]),
    };
  }
  function soma(lista) {
    const r = normaliza({ tot: [0, 0, 0, 0, 0, 0, 0], mes: Array.from({ length: 12 }, () => [0, 0, 0]), sh: Array.from({ length: 168 }, () => [0, 0, 0]),
      causa: [], tipo: [], meteo: [], fase: [], pista: [], trac: [], solo: {}, cls: {}, fds: {}, trecho: [], muni: [], grid: [] }, 'BR');
    const addMap = (dst, src) => src.forEach((v, k) => { const d = dst.get(k) || [0, 0, 0]; d[0] += v[0]; d[1] += v[1]; d[2] += v[2]; dst.set(k, d); });
    const addObj = (dst, src) => Object.keys(src).forEach((k) => { const d = dst[k] || (dst[k] = [0, 0, 0]); d[0] += src[k][0]; d[1] += src[k][1]; d[2] += src[k][2]; });
    const g = new Map();
    lista.forEach((u) => {
      u.tot.forEach((v, i) => (r.tot[i] += v));
      u.mes.forEach((v, i) => { r.mes[i][0] += v[0]; r.mes[i][1] += v[1]; r.mes[i][2] += v[2]; });
      u.sh.forEach((v, i) => { r.sh[i][0] += v[0]; r.sh[i][1] += v[1]; r.sh[i][2] += v[2]; });
      ['causa', 'tipo', 'meteo', 'fase', 'pista', 'trac'].forEach((k) => addMap(r[k], u[k]));
      ['solo', 'cls', 'fds'].forEach((k) => addObj(r[k], u[k]));
      r.trecho.push(...u.trecho); r.muni.push(...u.muni);
      u.grid.forEach(([y, x, a, m]) => { const k = y + '|' + x; const d = g.get(k); if (d) { d[2] += a; d[3] += m; } else g.set(k, [y, x, a, m]); });
    });
    r.grid = [...g.values()];
    return r;
  }
  const SIGLAS = Object.keys(D.ufs).sort((a, b) => D.ufs[a].nome.localeCompare(D.ufs[b].nome, 'pt-BR'));
  const VIEW = {};
  SIGLAS.forEach((s) => (VIEW[s] = normaliza(D.ufs[s], s)));
  VIEW.BR = soma(SIGLAS.map((s) => VIEW[s]));
  const nomeRecorte = () => (estado.uf === 'BR' ? 'no Brasil' : 'em ' + D.ufs[estado.uf].nome);

  // tooltip
  const tip = $('tip');
  function mostraTip(html, x, y) {
    tip.innerHTML = html; tip.style.opacity = '1';
    const r = tip.getBoundingClientRect();
    let left = x + 14, top = y + 14;
    if (left + r.width > window.innerWidth - 8) left = x - r.width - 14;
    if (top + r.height > window.innerHeight - 8) top = y - r.height - 14;
    tip.style.left = Math.max(8, left) + 'px'; tip.style.top = Math.max(8, top) + 'px';
  }
  const escondeTip = () => (tip.style.opacity = '0');
  document.addEventListener('mousemove', (e) => {
    const el = e.target.closest && e.target.closest('[data-tip]');
    if (el) mostraTip(el.getAttribute('data-tip'), e.clientX, e.clientY);
    else if (!e.target.closest || !e.target.closest('#mapa')) escondeTip();
  });
  document.addEventListener('focusin', (e) => {
    const el = e.target.closest && e.target.closest('[data-tip]');
    if (el) { const r = el.getBoundingClientRect(); mostraTip(el.getAttribute('data-tip'), r.left + Math.min(r.width, 160), r.top); }
  });
  document.addEventListener('focusout', escondeTip);
  window.addEventListener('scroll', escondeTip, { passive: true });
  const linhaTip = (rot, val) => `<div class="r"><span>${rot}</span><span>${val}</span></div>`;
  const tipPadrao = (titulo, a, m, f) =>
    `<b>${esc(titulo)}</b>` + linhaTip('Acidentes', fmt(a)) + linhaTip('Mortes', fmt(m)) +
    (f !== undefined ? linhaTip('Feridos', fmt(f)) : '') + linhaTip('Mortes a cada 100 acidentes', fmt1(taxa(m, a)));

  // componentes
  function barras(el, itens, opts = {}) {
    // itens: {nome, valor, rotulo, tip}
    const max = Math.max(1, ...itens.map((i) => i.valor));
    el.innerHTML = itens.map((i) =>
      `<div class="hbar" tabindex="0" data-tip="${esc(i.tip)}" aria-label="${esc(i.nome)}: ${esc(i.rotulo)}">
         <span class="nm" title="${esc(i.nome)}">${esc(i.nome)}</span><span class="val">${esc(i.rotulo)}</span>
         <span class="track"><span class="fill${opts.alt ? ' alt' : ''}" style="display:block;width:${(100 * i.valor) / max}%"></span></span>
       </div>`).join('') || '<p class="empty">Sem registros neste recorte.</p>';
  }
  function tabela(el, cab, linhas, numericas) {
    el.innerHTML = '<table><thead><tr>' + cab.map((c, i) => `<th${numericas.includes(i) ? ' class="n"' : ''}>${esc(c)}</th>`).join('') +
      '</tr></thead><tbody>' + linhas.map((l) => '<tr>' + l.map((c, i) => `<td${numericas.includes(i) ? ' class="n"' : ''}>${esc(c)}</td>`).join('') + '</tr>').join('') + '</tbody></table>';
  }
  const ordenaMedida = (arr) => arr.sort((x, y) => (estado.medida === 'a' ? y.a - x.a || y.m - x.m : y.m - x.m || y.a - x.a));
  const deMapa = (mapa, nomes) => [...mapa.entries()].map(([i, v]) => ({ nome: nomes[i], a: v[0], m: v[1], f: v[2] }));
  const valorDe = (o) => (estado.medida === 'a' ? o.a : o.m);

  function niceMax(v) {
    if (v <= 0) return 1;
    const p = Math.pow(10, Math.floor(Math.log10(v)));
    for (const s of [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) if (s * p >= v) return s * p;
    return 10 * p;
  }
  const temaEscuro = () => {
    const t = document.documentElement.getAttribute('data-theme');
    return t ? t === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
  };
  const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
  const rampa = () => (temaEscuro() ? RAMP_DARK : RAMP_LIGHT);
  function legendaRampa(el, rotMin, rotMax) {
    el.innerHTML = `<span>${esc(rotMin)}</span><span class="sw">${rampa().map((c) => `<span style="background:${c}"></span>`).join('')}</span><span>${esc(rotMax)}</span>`;
  }

  // seções
  function kpis(v) {
    const [a, m, f, g, , , fatais] = v.tot;
    const br = VIEW.BR.tot;
    const share = estado.uf === 'BR' ? '' : `<p class="ctx">${pct((100 * a) / br[0])} dos acidentes do país</p>`;
    const comp = (val, ref, txt) => estado.uf === 'BR' ? '' : `<p class="ctx">Brasil: ${txt(ref)}</p>`;
    $('kpis').innerHTML = `
      <div class="card stat hero"><p class="label">Acidentes atendidos pela PRF ${esc(nomeRecorte())}</p><p class="value">${fmt(a)}</p>${share || '<p class="ctx">em 2025, nas rodovias federais</p>'}</div>
      <div class="card stat"><p class="label">Pessoas mortas</p><p class="value">${fmt(m)}</p><p class="ctx">${fmt1(m / 365)} por dia, em média</p></div>
      <div class="card stat"><p class="label">Pessoas feridas</p><p class="value">${fmt(f)}</p><p class="ctx">${fmt(g)} com ferimentos graves</p></div>
      <div class="card stat"><p class="label">Mortes a cada 100 acidentes</p><p class="value">${fmt1(taxa(m, a))}</p>${comp(m, br, (r) => fmt1(taxa(r[1], r[0]))) || '<p class="ctx">mede a gravidade dos acidentes</p>'}</div>
      <div class="card stat"><p class="label">Acidentes com morte</p><p class="value">${pct((100 * fatais) / Math.max(1, a))}</p>${comp(0, br, (r) => pct((100 * r[6]) / r[0])) || `<p class="ctx">${fmt(fatais)} ocorrências</p>`}</div>`;
  }

  function destaques(v) {
    const out = [];
    const mi = MI();
    // mês
    let im = 0; v.mes.forEach((x, i) => { if (x[mi] > v.mes[im][mi]) im = i; });
    out.push(['Mês com mais ' + nomeMedida(), MESES[im], `${fmt(v.mes[im][mi])} ${nomeMedida()} ${estado.medida === 'a' ? '' : '(' + fmt(v.mes[im][0]) + ' acidentes)'}`]);
    // dia e hora
    let ih = 0; v.sh.forEach((x, i) => { if (x[mi] > v.sh[ih][mi]) ih = i; });
    const d = Math.floor(ih / 24), h = ih % 24;
    out.push(['Momento com mais ' + nomeMedida(), `${DIAS[d]}, ${h}h às ${h + 1}h`, `${fmt(v.sh[ih][mi])} ${nomeMedida()} nessa hora ao longo do ano`]);
    // madrugada x manhã
    const fx = FAIXAS.map(([n, i0, i1]) => { let a = 0, m = 0; for (let dd = 0; dd < 7; dd++) for (let hh = i0; hh <= i1; hh++) { a += v.sh[dd * 24 + hh][0]; m += v.sh[dd * 24 + hh][1]; } return { n, a, m }; });
    out.push(['A madrugada é mais grave', `${fmt1(taxa(fx[0].m, fx[0].a))} mortes a cada 100 acidentes`, `contra ${fmt1(taxa(fx[1].m, fx[1].a))} pela manhã`]);
    // causa
    const causas = ordenaMedida(deMapa(v.causa, D.causa));
    if (causas.length) { const c = causas[0]; out.push(['Causa mais registrada', c.nome, `${pct((100 * valorDe(c)) / Math.max(1, v.tot[mi]))} dos ${nomeMedida()}`]); }
    // tipo mais letal
    const letal = deMapa(v.tipo, D.tipo).filter((t) => t.a >= 30).sort((x, y) => taxa(y.m, y.a) - taxa(x.m, x.a));
    if (letal.length) out.push(['Tipo mais letal', letal[0].nome, `${fmt1(taxa(letal[0].m, letal[0].a))} mortes a cada 100 ocorrências`]);
    // trecho
    const tr = ordenaMedida(v.trecho.slice())[0];
    if (tr) out.push(['Trecho mais crítico', `BR-${String(tr.br).padStart(3, '0')} / ${tr.uf}, km ${tr.km} a ${tr.km + 10}`, `${fmt(tr.a)} acidentes e ${fmt(tr.m)} mortes`]);
    $('destaques').innerHTML = out.map(([t, val, dsc]) => `<div class="hl"><p class="t">${esc(t)}</p><p class="v">${esc(val)}</p><p class="d">${esc(dsc)}</p></div>`).join('');
    $('dest-sub').textContent = `Os pontos que mais chamam atenção ${nomeRecorte()}, em 2025.`;
  }

  function graficoMes(v) {
    const el = $('c-mes');
    const mi = MI();
    const W = Math.max(300, el.clientWidth), H = 260, ml = 48, mr = 8, mt = 22, mb = 28;
    const pw = W - ml - mr, ph = H - mt - mb;
    const vals = v.mes.map((x) => x[mi]);
    const ymax = niceMax(Math.max(...vals));
    const band = pw / 12, bw = Math.min(24, band * 0.6);
    const y = (val) => mt + ph - (val / ymax) * ph;
    const grid = [0, 0.25, 0.5, 0.75, 1].map((k) => {
      const val = ymax * k, yy = y(val);
      return `<line x1="${ml}" x2="${W - mr}" y1="${yy}" y2="${yy}" stroke="${k === 0 ? css('--axis') : css('--grid')}" stroke-width="1"/>
              <text x="${ml - 8}" y="${yy + 4}" text-anchor="end" font-size="12" fill="${css('--text-muted')}">${fmt(val)}</text>`;
    }).join('');
    const imax = vals.indexOf(Math.max(...vals));
    const cols = vals.map((val, i) => {
      const x = ml + band * i + (band - bw) / 2, yy = y(val), h = mt + ph - yy, r = Math.min(4, h, bw / 2);
      const path = h > 0 ? `M${x},${yy + h}V${yy + r}Q${x},${yy} ${x + r},${yy}H${x + bw - r}Q${x + bw},${yy} ${x + bw},${yy + r}V${yy + h}Z` : '';
      const m = v.mes[i];
      return `<g class="col" tabindex="0" data-tip="${esc(tipPadrao(MESES[i] + ' de 2025', m[0], m[1], m[2]))}" aria-label="${MESES[i]}: ${fmt(val)} ${nomeMedida()}">
          <rect x="${ml + band * i}" y="${mt}" width="${band}" height="${ph}" fill="transparent"/>
          <path d="${path}" fill="${css('--series-1')}"/>
          ${i === imax ? `<text x="${x + bw / 2}" y="${yy - 6}" text-anchor="middle" font-size="12" font-weight="600" fill="${css('--text-primary')}">${fmt(val)}</text>` : ''}
          <text x="${x + bw / 2}" y="${H - 8}" text-anchor="middle" font-size="12" fill="${css('--text-secondary')}">${band >= 34 ? MES_AB[i] : (i % 2 === 0 ? MES_AB[i] : '')}</text></g>`;
    }).join('');
    el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="Gráfico de colunas: ${nomeMedida()} por mês">${grid}${cols}</svg>`;
    $('t-mes').textContent = (estado.medida === 'a' ? 'Acidentes' : 'Mortes') + ' por mês';
    $('st-mes').textContent = `Total de ${nomeMedida()} registrados em cada mês de 2025 ${nomeRecorte()}. Passe o mouse sobre as colunas para ver os detalhes.`;
    tabela($('tb-mes'), ['Mês', 'Acidentes', 'Mortes', 'Feridos', 'Mortes/100 acidentes'],
      v.mes.map((m, i) => [MESES[i], fmt(m[0]), fmt(m[1]), fmt(m[2]), fmt1(taxa(m[1], m[0]))]), [1, 2, 3, 4]);
  }

  function mapaCalor(v) {
    const mi = MI();
    const vals = v.sh.map((x) => x[mi]);
    const max = Math.max(1, ...vals);
    const R = rampa(), vazio = css('--surface-2');
    let html = '<span></span>' + Array.from({ length: 24 }, (_, h) => `<span class="cl">${h % 3 === 0 ? h + 'h' : ''}</span>`).join('');
    for (let d = 0; d < 7; d++) {
      html += `<span class="rl">${DIAS_AB[d]}</span>`;
      for (let h = 0; h < 24; h++) {
        const x = v.sh[d * 24 + h], val = x[mi];
        const cor = val === 0 ? vazio : R[Math.min(6, Math.floor((val / max) * 7))];
        html += `<span class="cell" tabindex="-1" style="background:${cor}" data-tip="${esc(tipPadrao(`${DIAS[d]}, ${h}h às ${h + 1}h`, x[0], x[1], x[2]))}"></span>`;
      }
    }
    $('c-heat').innerHTML = html;
    $('c-heat').setAttribute('aria-label', `Mapa de calor de ${nomeMedida()} por dia da semana e hora. A tabela abaixo traz os mesmos números.`);
    $('t-heat').textContent = `${estado.medida === 'a' ? 'Acidentes' : 'Mortes'}: dia da semana × hora do dia`;
    legendaRampa($('lg-heat'), 'menos', 'mais ' + nomeMedida());
    tabela($('tb-heat'), ['Hora', ...DIAS_AB],
      Array.from({ length: 24 }, (_, h) => [h + 'h', ...DIAS_AB.map((_, d) => fmt(v.sh[d * 24 + h][mi]))]), [1, 2, 3, 4, 5, 6, 7]);
  }

  function gravidadePeriodo(v) {
    const fx = FAIXAS.map(([n, i0, i1]) => { let a = 0, m = 0, f = 0; for (let d = 0; d < 7; d++) for (let h = i0; h <= i1; h++) { const x = v.sh[d * 24 + h]; a += x[0]; m += x[1]; f += x[2]; } return { n, a, m, f }; });
    barras($('c-faixa'), fx.map((x) => ({ nome: x.n, valor: taxa(x.m, x.a), rotulo: fmt1(taxa(x.m, x.a)), tip: tipPadrao(x.n, x.a, x.m, x.f) })), { alt: true });
    const s = v.fds.S || [0, 0, 0], n = v.fds.N || [0, 0, 0];
    barras($('c-fds'), [
      { nome: 'Sábado e domingo', valor: taxa(s[1], s[0]), rotulo: fmt1(taxa(s[1], s[0])), tip: tipPadrao('Sábado e domingo', s[0], s[1], s[2]) },
      { nome: 'Segunda a sexta', valor: taxa(n[1], n[0]), rotulo: fmt1(taxa(n[1], n[0])), tip: tipPadrao('Segunda a sexta', n[0], n[1], n[2]) },
    ], { alt: true });
    const porDiaFds = s[0] / 104, porDiaUtil = n[0] / 261;
    $('n-fds').textContent = `Em média, ${fmt(porDiaFds)} acidentes por dia no fim de semana e ${fmt(porDiaUtil)} por dia útil.`;
  }

  // mapa (canvas)
  let mapaGeo = null;   // projeção atual para o hover
  function mapa(v) {
    const cv = $('mapa');
    const mi = estado.medida === 'a' ? 2 : 3;
    const sel = v.grid, base = VIEW.BR.grid;
    let y0, y1, x0, x1;
    if (estado.uf === 'BR') { y0 = -340; y1 = 53; x0 = -740; x1 = -345; }
    else {
      y0 = Math.min(...sel.map((c) => c[0])); y1 = Math.max(...sel.map((c) => c[0])) + 1;
      x0 = Math.min(...sel.map((c) => c[1])); x1 = Math.max(...sel.map((c) => c[1])) + 1;
      const pad = Math.max(3, Math.round(Math.max(y1 - y0, x1 - x0) * 0.08)); y0 -= pad; y1 += pad; x0 -= pad; x1 += pad;
    }
    const cosl = Math.cos((((y0 + y1) / 2) / 10) * Math.PI / 180);
    const larg = cv.clientWidth || 600, dpr = window.devicePixelRatio || 1;
    const alt = Math.min(640, Math.max(260, larg * ((y1 - y0) / ((x1 - x0) * cosl))));
    cv.width = Math.round(larg * dpr); cv.height = Math.round(alt * dpr); cv.style.height = alt + 'px';
    const ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = css('--surface-1'); ctx.fillRect(0, 0, larg, alt);
    const esc = Math.min(larg / ((x1 - x0) * cosl), alt / (y1 - y0));
    const ox = (larg - (x1 - x0) * cosl * esc) / 2, oy = (alt - (y1 - y0) * esc) / 2;
    const px = (x) => ox + (x - x0) * cosl * esc, py = (y) => oy + (y1 - y - 1) * esc;
    const tam = Math.max(2.4, cosl * esc), tamY = Math.max(2.4, esc);
    // contexto: todas as áreas com acidente, em cinza
    ctx.fillStyle = css('--grid');
    base.forEach(([y, x]) => ctx.fillRect(px(x), py(y), tam, tamY));
    // recorte, colorido por quantidade (escala logarítmica, 7 classes)
    const R = rampa();
    const max = Math.max(1, ...sel.map((c) => c[mi]));
    const lmax = Math.log(max + 1);
    const ordenado = sel.filter((c) => c[mi] > 0).sort((p, q) => p[mi] - q[mi]);
    ordenado.forEach((c) => {
      ctx.fillStyle = R[Math.min(6, Math.floor((Math.log(c[mi] + 1) / lmax) * 7))];
      ctx.fillRect(px(c[1]), py(c[0]), tam, tamY);
    });
    const idx = new Map(sel.map((c) => [c[0] + '|' + c[1], c]));
    mapaGeo = { x0, y1, ox, oy, cosl, esc, idx };
    $('t-mapa').textContent = estado.medida === 'a' ? 'Mapa dos acidentes' : 'Mapa das mortes';
    $('st-mapa').textContent = estado.uf === 'BR'
      ? 'Áreas mais escuras concentram mais ' + nomeMedida() + '.'
      : `${D.ufs[estado.uf].nome} em destaque; em cinza, áreas com acidentes nos estados vizinhos.`;
    legendaRampa($('lg-mapa'), `1 ${nomeMedida(false)}`, `${fmt(max)} ${nomeMedida()} na mesma área`);
  }
  $('mapa').addEventListener('mousemove', (e) => {
    if (!mapaGeo) return;
    const r = e.currentTarget.getBoundingClientRect();
    const g = mapaGeo;
    const gx = Math.floor((e.clientX - r.left - g.ox) / (g.cosl * g.esc) + g.x0);
    const gy = Math.floor(g.y1 - 1 - (e.clientY - r.top - g.oy) / g.esc);
    let c = null;
    for (let dy = -1; dy <= 1 && !c; dy++) for (let dx = -1; dx <= 1 && !c; dx++) c = g.idx.get((gy + dy) + '|' + (gx + dx)) || null;
    if (c) mostraTip(`<b>Área perto de ${fmt1(Math.abs(c[0] / 10))}° S, ${fmt1(Math.abs(c[1] / 10))}° O</b>` + linhaTip('Acidentes', fmt(c[2])) + linhaTip('Mortes', fmt(c[3])), e.clientX, e.clientY);
    else escondeTip();
  });
  $('mapa').addEventListener('mouseleave', escondeTip);

  function ranking(v) {
    let itens;
    if (estado.uf === 'BR') {
      itens = ordenaMedida(SIGLAS.map((s) => { const t = VIEW[s].tot; return { nome: D.ufs[s].nome, a: t[0], m: t[1], f: t[2] }; }));
      $('t-rank').textContent = 'Os 12 estados com mais ' + nomeMedida();
      $('st-rank').textContent = 'Estados com mais quilômetros de rodovia federal e mais trânsito tendem a ter mais registros. Os 27 estados estão na tabela.';
    } else {
      itens = ordenaMedida(v.muni.slice());
      $('t-rank').textContent = 'Os 12 municípios com mais ' + nomeMedida();
      $('st-rank').textContent = `Municípios de ${D.ufs[estado.uf].nome} com mais ${nomeMedida()} nas rodovias federais. A tabela traz todos os ${itens.length}.`;
    }
    barras($('c-rank'), itens.slice(0, 12).map((i) => ({ nome: i.nome, valor: valorDe(i), rotulo: fmt(valorDe(i)), tip: tipPadrao(i.nome, i.a, i.m, i.f) })));
    tabela($('tb-rank'), [estado.uf === 'BR' ? 'Estado' : 'Município', 'Acidentes', 'Mortes', 'Feridos', 'Mortes/100'],
      itens.map((i) => [i.nome, fmt(i.a), fmt(i.m), fmt(i.f), fmt1(taxa(i.m, i.a))]), [1, 2, 3, 4]);
  }

  function trechos(v) {
    const top = ordenaMedida(v.trecho.slice()).slice(0, 10);
    tabela($('c-trecho'), ['#', 'Rodovia', 'Estado', 'Trecho', 'Acidentes', 'Mortes', 'Feridos', 'Mortes/100'],
      top.map((t, i) => [i + 1, 'BR-' + String(t.br).padStart(3, '0'), t.uf, `km ${t.km} a ${t.km + 10}`, fmt(t.a), fmt(t.m), fmt(t.f), fmt1(taxa(t.m, t.a))]), [0, 4, 5, 6, 7]);
    $('st-trecho').textContent = `Os 10 trechos de 10 km com mais ${nomeMedida()} ${nomeRecorte()}.`;
  }

  // busca de município
  function listaMunicipios() {
    const fonte = estado.uf === 'BR' ? VIEW.BR.muni : VIEW[estado.uf].muni;
    $('l-muni').innerHTML = fonte.slice().sort((p, q) => p.nome.localeCompare(q.nome, 'pt-BR'))
      .map((m) => `<option value="${esc(m.nome + ' (' + m.uf + ')')}"></option>`).join('');
  }
  function buscaMunicipio() {
    const q = $('f-muni').value.trim().toUpperCase();
    const out = $('muni-out');
    if (!q) { out.innerHTML = '<p class="empty">Nenhum município escolhido.</p>'; return; }
    const todos = VIEW.BR.muni;
    let achados = todos.filter((m) => (m.nome + ' (' + m.uf + ')') === q);
    if (!achados.length) achados = todos.filter((m) => m.nome === q && (estado.uf === 'BR' || m.uf === estado.uf));
    if (!achados.length) { out.innerHTML = '<p class="empty">Município não encontrado nas rodovias federais. Escolha um nome da lista.</p>'; return; }
    out.innerHTML = achados.slice(0, 3).map((m) => {
      const doUf = ordenaMedida(VIEW[m.uf].muni.slice()); const pos = doUf.indexOf(m) + 1;
      return `<p style="margin:16px 0 0;font-weight:600">${esc(m.nome)} (${m.uf}) · ${pos}º com mais ${nomeMedida()} em ${esc(D.ufs[m.uf].nome)}, entre ${doUf.length} municípios</p>
        <div class="muni-result">
          <div class="stat"><p class="label">Acidentes</p><p class="value">${fmt(m.a)}</p></div>
          <div class="stat"><p class="label">Mortes</p><p class="value">${fmt(m.m)}</p></div>
          <div class="stat"><p class="label">Feridos</p><p class="value">${fmt(m.f)}</p></div>
        </div>`;
    }).join('');
  }
  $('f-muni').addEventListener('input', buscaMunicipio);

  function porque(v) {
    const total = v.tot[MI()] || 1;
    const causas = ordenaMedida(deMapa(v.causa, D.causa));
    barras($('c-causa'), causas.slice(0, 10).map((c) => ({ nome: c.nome, valor: valorDe(c), rotulo: `${fmt(valorDe(c))} · ${pct((100 * valorDe(c)) / total)}`, tip: tipPadrao(c.nome, c.a, c.m, c.f) })));
    $('t-causa').textContent = estado.medida === 'a' ? 'As 10 causas mais registradas' : 'As 10 causas com mais mortes';
    $('st-causa').textContent = `Causa principal apontada pela PRF. O percentual é a parte do total de ${nomeMedida()} ${nomeRecorte()}.`;
    tabela($('tb-causa'), ['Causa', 'Acidentes', 'Mortes', 'Feridos', 'Mortes/100'], causas.map((c) => [c.nome, fmt(c.a), fmt(c.m), fmt(c.f), fmt1(taxa(c.m, c.a))]), [1, 2, 3, 4]);

    const tipos = ordenaMedida(deMapa(v.tipo, D.tipo));
    barras($('c-tipo'), tipos.map((t) => ({ nome: t.nome, valor: valorDe(t), rotulo: fmt(valorDe(t)), tip: tipPadrao(t.nome, t.a, t.m, t.f) })));
    $('t-tipo').textContent = estado.medida === 'a' ? 'Tipos de acidente' : 'Mortes por tipo de acidente';
    $('st-tipo').textContent = `Quantidade de ${nomeMedida()} por tipo de acidente.`;
    tabela($('tb-tipo'), ['Tipo', 'Acidentes', 'Mortes', 'Feridos', 'Mortes/100'], tipos.map((t) => [t.nome, fmt(t.a), fmt(t.m), fmt(t.f), fmt1(taxa(t.m, t.a))]), [1, 2, 3, 4]);

    const letal = deMapa(v.tipo, D.tipo).filter((t) => t.a >= 30).sort((x, y) => taxa(y.m, y.a) - taxa(x.m, x.a)).slice(0, 8);
    barras($('c-letal'), letal.map((t) => ({ nome: t.nome, valor: taxa(t.m, t.a), rotulo: fmt1(taxa(t.m, t.a)), tip: tipPadrao(t.nome, t.a, t.m, t.f) })), { alt: true });

    const meteo = ordenaMedida(deMapa(v.meteo, D.meteo));
    barras($('c-meteo'), meteo.map((t) => ({ nome: t.nome, valor: valorDe(t), rotulo: `${fmt(valorDe(t))} · ${pct((100 * valorDe(t)) / total)}`, tip: tipPadrao(t.nome, t.a, t.m, t.f) })));
    $('t-meteo').textContent = 'Condição do tempo';
    $('st-meteo').textContent = `${estado.medida === 'a' ? 'Acidentes' : 'Mortes'} por condição do tempo no momento da ocorrência.`;

    const trac = ordenaMedida(deMapa(v.trac, D.tracado));
    barras($('c-trac'), trac.map((t) => ({ nome: t.nome, valor: valorDe(t), rotulo: `${fmt(valorDe(t))} · ${pct((100 * valorDe(t)) / total)}`, tip: tipPadrao(t.nome, t.a, t.m, t.f) })));
    $('st-trac').textContent = `${estado.medida === 'a' ? 'Acidentes' : 'Mortes'} em trechos com cada característica.`;
  }

  // inicialização
  function render() {
    const v = VIEW[estado.uf];
    kpis(v); destaques(v); graficoMes(v); mapaCalor(v); gravidadePeriodo(v);
    mapa(v); ranking(v); trechos(v); porque(v); buscaMunicipio();
  }

  // filtros
  const selUf = $('f-uf');
  selUf.innerHTML = '<option value="BR">Brasil (todos os estados)</option>' + SIGLAS.map((s) => `<option value="${s}">${esc(D.ufs[s].nome)} (${s})</option>`).join('');
  selUf.addEventListener('change', () => { estado.uf = selUf.value; listaMunicipios(); render(); salva(); });
  document.querySelectorAll('#f-medida button').forEach((b) => b.addEventListener('click', () => {
    estado.medida = b.dataset.v;
    document.querySelectorAll('#f-medida button').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    render(); salva();
  }));
  $('tema').addEventListener('click', () => {
    const novo = temaEscuro() ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', novo);
    try { localStorage.setItem('painel-tema', novo); } catch (e) { /* armazenamento indisponível */ }
    render();
  });
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', render);
  let tmr; window.addEventListener('resize', () => { clearTimeout(tmr); tmr = setTimeout(() => { graficoMes(VIEW[estado.uf]); mapa(VIEW[estado.uf]); }, 150); });

  // preferências do visitante (filtro e tema) e link compartilhável (#SP)
  function salva() {
    try { localStorage.setItem('painel-estado', JSON.stringify(estado)); } catch (e) { /* ignora */ }
    history.replaceState(null, '', estado.uf === 'BR' ? location.pathname : '#' + estado.uf);
  }
  try {
    const t = localStorage.getItem('painel-tema'); if (t) document.documentElement.setAttribute('data-theme', t);
    const s = JSON.parse(localStorage.getItem('painel-estado') || 'null');
    if (s && (s.uf === 'BR' || D.ufs[s.uf])) estado.uf = s.uf;
    if (s && (s.medida === 'a' || s.medida === 'm')) estado.medida = s.medida;
  } catch (e) { /* ignora */ }
  const hash = location.hash.replace('#', '').toUpperCase();
  if (D.ufs[hash]) estado.uf = hash;
  selUf.value = estado.uf;
  document.querySelectorAll('#f-medida button').forEach((x) => x.setAttribute('aria-pressed', String(x.dataset.v === estado.medida)));
  listaMunicipios();
  render();
})();
