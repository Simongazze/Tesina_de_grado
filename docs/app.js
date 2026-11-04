'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const families = {
    rapm: { name: 'RAPM', description: 'Plus-minus ajustado regularizado. Aporte estimado del jugador.', prefix: 'RAPM' },
    epts: { name: 'EPTS', description: 'Puntos esperados en ataque y defensa.', prefix: 'epts' },
    wepts: { name: 'wEPTS', description: 'Puntos esperados ponderados en ataque y defensa.', prefix: 'w_epts' },
    descriptivas: { name: 'Descriptivas', description: 'El rendimiento observado con el jugador en cancha.' }
  };
  const descriptive = {
    pm100: { name: 'Plus-minus por 100 posesiones', components: ['total'], fields: { total: 'plus_minus_100' }, digits: 2, unit: 'puntos / 100 posesiones' },
    pm: { name: 'Plus-minus acumulado', components: ['total'], fields: { total: 'plus_minus_total' }, digits: 0, unit: 'puntos' },
    ppp: { name: 'Puntos por posesión', components: ['off', 'def'], fields: { off: 'pts_realizad_por_pos', def: 'pts_recib_por_pos' }, digits: 4, unit: 'puntos / posesión' },
    std: { name: 'Estandarizadas por equipo', components: ['off', 'def'], fields: { off: 'pts_realiz_estand_median', def: 'pts_recib_estand_median' }, digits: 3, unit: 'escala estandarizada' }
  };
  const components = { off: 'ofensivo', def: 'defensivo', total: 'total' };
  const regularizations = { enet: 'Elastic Net', ridge: 'Ridge', lasso: 'Lasso' };
  const teamNames = { 'LA UNION FSA.': 'La Unión (Fsa.)', 'ZARATE BASKET': 'Zárate Basket', 'SAN MARTIN': 'San Martín', 'OLIMPICO': 'Olímpico', 'OBERA': 'Oberá', 'UNION': 'Unión', 'PEÑAROL': 'Peñarol' };
  const state = { family: 'wepts', variant: 'enet', descriptive: 'pm100', component: 'total', search: '', team: '', minimum: 500, page: 1, size: 20 };
  let rows = [], filtered = [], loaded = false, currentMetric;
  const fmtInt = new Intl.NumberFormat('es-AR');
  const titleCase = text => text.toLocaleLowerCase('es-AR').replace(/(^|[\s,-])\p{L}/gu, char => char.toLocaleUpperCase('es-AR')).replace(/\bIii\b/g, 'III').replace(/\bIi\b/g, 'II');
  const teamLabel = team => teamNames[team] || titleCase(team);
  const normalize = text => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase('es-AR').trim();
  const escapeHTML = text => String(text).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));

  // CSV parser that preserves quoted commas, line breaks and escaped quotes.
  function parseCSV(text) {
    const records = []; let row = [], value = '', quoted = false;
    text = text.replace(/^\uFEFF/, '');
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      if (char === '"') {
        if (quoted && text[i + 1] === '"') { value += '"'; i++; }
        else quoted = !quoted;
      } else if (!quoted && (char === ',' || char === '\n' || char === '\r')) {
        row.push(value); value = '';
        if (char !== ',') { if (row.some(Boolean)) records.push(row); row = []; if (char === '\r' && text[i + 1] === '\n') i++; }
      } else value += char;
    }
    if (quoted) throw new Error('El CSV tiene comillas sin cerrar.');
    if (value.length || row.length) { row.push(value); if (row.some(Boolean)) records.push(row); }
    const headers = records.shift();
    if (!headers || !headers.includes('jugador') || !headers.includes('equipo_del_jugador') || !headers.includes('posesiones_totales')) throw new Error('Faltan columnas de identificación en el CSV.');
    return records.map((values, index) => {
      if (values.length !== headers.length) throw new Error(`Fila ${index + 2}: cantidad de columnas inesperada.`);
      const item = Object.fromEntries(headers.map((header, i) => [header, values[i]]));
      item._search = normalize(item.jugador); item._index = index;
      return item;
    });
  }
  function numeric(row, field) {
    const raw = row[field];
    return raw === undefined || raw.trim() === '' || raw === 'NA' ? null : Number.isFinite(Number(raw)) ? Number(raw) : null;
  }
  function metric() {
    const { family, variant, component } = state;
    if (family === 'descriptivas') {
      const config = descriptive[state.descriptive];
      const reverseDefense = state.descriptive === 'ppp' && component === 'def';
      return { ...config, field: config.fields[component], label: config.name, lower: reverseDefense, multiplier: reverseDefense ? -1 : 1,
        note: reverseDefense ? 'Menor valor = mejor defensa · puntos recibidos en positivo' : 'Mayor valor = mejor rendimiento',
        formula: state.descriptive === 'std' ? 'Las medidas estandarizadas se comparan dentro de cada equipo.' : '' };
    }
    const name = families[family].name;
    const field = family === 'rapm' ? `${component === 'off' ? 'ORAPM' : component === 'def' ? 'DRAPM' : 'RAPM_total'}_${variant}` : `${families[family].prefix}_${component}_${variant}`;
    const lower = component === 'def' && family !== 'rapm';
    return { field, label: `${name} ${components[component]}`, lower, multiplier: 1, digits: 4, unit: family === 'rapm' ? 'coeficiente original' : 'puntos / posesión',
      note: `${lower ? 'Menor valor = mejor defensa' : 'Mayor valor = mejor rendimiento'} · ${regularizations[variant]}`,
      formula: component === 'total' ? (family === 'rapm' ? 'Total = ataque + defensa' : 'Total = ataque − defensa') : '' };
  }
  function updateConfiguration() {
    $('metric-title').textContent = families[state.family].name;
    $('metric-description').textContent = families[state.family].description;
    const isDescriptive = state.family === 'descriptivas';
    const options = isDescriptive ? Object.entries(descriptive).map(([value, config]) => [value, config.name]) : Object.entries(regularizations);
    $('variant-control').querySelector('label').textContent = isDescriptive ? 'Medida descriptiva' : 'Regularización';
    $('variant').innerHTML = options.map(([value, label]) => `<option value="${value}">${label}</option>`).join('');
    $('variant').value = isDescriptive ? state.descriptive : state.variant;
    const allowed = isDescriptive ? descriptive[state.descriptive].components : ['off', 'def', 'total'];
    if (!allowed.includes(state.component)) state.component = allowed[0];
    document.querySelectorAll('[data-family]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.family === state.family)));
    document.querySelectorAll('[data-component]').forEach(button => {
      button.disabled = !allowed.includes(button.dataset.component);
      button.setAttribute('aria-pressed', String(button.dataset.component === state.component));
      button.title = button.disabled ? 'Esta medida no tiene esa dimensión en la base publicada.' : '';
    });
    render();
  }
  function render() {
    currentMetric = metric();
    const m = currentMetric;
    $('ranking-title').textContent = `Ranking ${components[state.component]}`;
    $('ranking-note').textContent = [m.note, m.formula].filter(Boolean).join(' · ');
    $('table-caption').textContent = `${m.label}. ${m.note}. Posiciones dentro de los filtros actuales.`;
    $('value-heading').textContent = `${m.label.toLocaleUpperCase('es-AR')} ${m.lower ? '↑' : '↓'}`;
    if (!loaded) return;
    const query = normalize(state.search);
    const selected = rows.filter(row => (!query || row._search.includes(query)) && (!state.team || row.equipo_del_jugador === state.team) && numeric(row, 'posesiones_totales') !== null && numeric(row, 'posesiones_totales') >= state.minimum);
    filtered = selected.map(row => ({ row, value: numeric(row, m.field) })).filter(item => item.value !== null).map(item => ({ ...item, value: item.value * m.multiplier }));
    filtered.sort((a, b) => (m.lower ? a.value - b.value : b.value - a.value) || a.row.jugador.localeCompare(b.row.jugador, 'es') || a.row.equipo_del_jugador.localeCompare(b.row.equipo_del_jugador, 'es'));
    let rank = 0;
    filtered.forEach((item, i) => { if (!i || Math.abs(item.value - filtered[i - 1].value) > 1e-12) rank = i + 1; item.rank = rank; });
    const size = state.size === 'all' ? Math.max(1, filtered.length) : state.size;
    const totalPages = Math.max(1, Math.ceil(filtered.length / size));
    state.page = Math.max(1, Math.min(state.page, totalPages));
    const start = (state.page - 1) * size, shown = filtered.slice(start, start + size);
    const playerCount = new Set(filtered.map(item => item.row.jugador)).size;
    const missing = selected.length - filtered.length;
    $('results-count').textContent = `${fmtInt.format(filtered.length)} ${filtered.length === 1 ? 'registro' : 'registros'} · ${fmtInt.format(playerCount)} ${playerCount === 1 ? 'jugador' : 'jugadores'} · ${state.team ? teamLabel(state.team) : 'Todos los equipos'} · Mínimo ${fmtInt.format(state.minimum)} posesiones${missing ? ` · ${missing} registros sin valor para esta medida` : ''}`;
    const format = new Intl.NumberFormat('es-AR', { minimumFractionDigits: m.digits, maximumFractionDigits: m.digits });
    const display = value => format.format(Math.abs(value) < .5 * 10 ** -m.digits ? 0 : value);
    $('ranking-body').innerHTML = shown.length ? shown.map(({ row, value, rank }) => `<tr><td class="position ${rank <= 3 ? 'top' : ''}"><span>${rank}</span></td><td class="player-name">${escapeHTML(titleCase(row.jugador))}</td><td><span class="team-label">${escapeHTML(teamLabel(row.equipo_del_jugador))}</span></td><td class="number">${fmtInt.format(numeric(row, 'posesiones_totales'))}</td><td class="number value ${value < 0 ? 'negative' : ''}" title="${escapeHTML(String(value))}">${display(value)}<span>${escapeHTML(m.unit)}</span></td></tr>`).join('') : '<tr><td colspan="5" class="empty-state"><strong>No hay jugadores para estos filtros.</strong>Probá con otro nombre, equipo o mínimo de posesiones.<br><button type="button" id="empty-reset">Restablecer filtros</button></td></tr>';
    $('empty-reset')?.addEventListener('click', reset);
    $('page-info').textContent = filtered.length ? `${start + 1}–${Math.min(start + size, filtered.length)} de ${filtered.length}` : '0 resultados';
    $('previous').disabled = state.page <= 1; $('next').disabled = state.page >= totalPages;
    $('download').disabled = !filtered.length;
  }
  function reset() {
    state.search = ''; state.team = ''; state.minimum = 500; state.page = 1;
    $('search').value = ''; $('team').value = ''; $('minimum').value = 500; render();
  }
  document.querySelectorAll('[data-family]').forEach(button => button.addEventListener('click', () => { state.family = button.dataset.family; state.page = 1; updateConfiguration(); }));
  document.querySelectorAll('[data-component]').forEach(button => button.addEventListener('click', () => { state.component = button.dataset.component; state.page = 1; updateConfiguration(); }));
  $('variant').addEventListener('change', event => { state[state.family === 'descriptivas' ? 'descriptive' : 'variant'] = event.target.value; state.page = 1; updateConfiguration(); });
  $('search').addEventListener('input', event => { state.search = event.target.value; state.page = 1; render(); });
  $('team').addEventListener('change', event => { state.team = event.target.value; state.page = 1; render(); });
  $('minimum').addEventListener('input', event => { state.minimum = Math.max(0, Math.floor(Number(event.target.value) || 0)); state.page = 1; render(); });
  $('page-size').addEventListener('change', event => { state.size = event.target.value === 'all' ? 'all' : Number(event.target.value); state.page = 1; render(); });
  $('previous').addEventListener('click', () => { state.page--; render(); });
  $('next').addEventListener('click', () => { state.page++; render(); });
  $('reset').addEventListener('click', reset);
  $('download').addEventListener('click', () => {
    // Prefix spreadsheet formula triggers in names; raw source CSV remains unchanged.
    const cell = value => '"' + String(value).replace(/^[=+@\t\r]/, char => "'" + char).replace(/"/g, '""') + '"';
    const header = ['posicion', 'jugador', 'equipo_del_jugador', 'posesiones_totales', 'familia', 'regularizacion_o_medida', 'dimension', 'columna_origen', 'valor_origen', 'valor_mostrado'];
    const body = filtered.map(({ row, rank, value }) => [rank, row.jugador, row.equipo_del_jugador, row.posesiones_totales, families[state.family].name, state.family === 'descriptivas' ? descriptive[state.descriptive].name : regularizations[state.variant], components[state.component], currentMetric.field, row[currentMetric.field], value]);
    const blob = new Blob(['\uFEFF' + [header, ...body].map(row => row.map(cell).join(',')).join('\r\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob), link = document.createElement('a');
    link.href = url; link.download = `ranking-${state.family}-${state.component}-${state.family === 'descriptivas' ? state.descriptive : state.variant}.csv`;
    document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  updateConfiguration();
  fetch('rankings.csv', { cache: 'no-cache' }).then(response => { if (!response.ok) throw new Error(`HTTP ${response.status}`); return response.text(); }).then(text => {
    rows = parseCSV(text);
    const required = ['plus_minus_total', 'plus_minus_100', 'pts_realizad_por_pos', 'pts_recib_por_pos', 'pts_realiz_estand_median', 'pts_recib_estand_median'];
    for (const variant of Object.keys(regularizations)) required.push(`ORAPM_${variant}`, `DRAPM_${variant}`, `RAPM_total_${variant}`, ...['epts', 'w_epts'].flatMap(prefix => ['off', 'def', 'total'].map(component => `${prefix}_${component}_${variant}`)));
    if (rows.length && required.some(field => !(field in rows[0]))) throw new Error('Faltan columnas de métricas. Revisá el formato de rankings.csv.');
    const teams = [...new Set(rows.map(row => row.equipo_del_jugador))].sort((a,b) => teamLabel(a).localeCompare(teamLabel(b), 'es'));
    for (const team of teams) { const option = document.createElement('option'); option.value = team; option.textContent = teamLabel(team); $('team').appendChild(option); }
    $('season-stats').innerHTML = `<span><strong>${new Set(rows.map(row => row.jugador)).size}</strong> jugadores</span><span><strong>${teams.length}</strong> equipos</span><span><strong>${rows.length}</strong> registros</span>`;
    loaded = true; render();
  }).catch(error => {
    console.error('No se pudieron cargar los rankings:', error);
    $('results-count').textContent = 'No se pudieron cargar los datos.';
    $('ranking-body').innerHTML = '<tr><td colspan="5" class="empty-state"><strong>No pudimos abrir la base de rankings.</strong>Recargá la página o <a href="rankings.csv">descargá el CSV</a> para consultar los datos.</td></tr>';
  });
})();
