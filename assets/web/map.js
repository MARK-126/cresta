// Motor de mapa de Cresta: MapLibre GL JS dentro de un WebView.
// Flutter llama a window.cresta.<método>(...) y recibe eventos por el canal CrestaBridge.
(() => {
  'use strict';

  const ORIGIN = location.origin;
  const WIDE = [-98.82, 18.92, -98.46, 19.24];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const emit = (type, data = {}) => {
    const msg = JSON.stringify({ type, ...data });
    if (window.CrestaBridge) window.CrestaBridge.postMessage(msg);
    else console.log('[bridge]', msg);
  };

  // --- Geometría
  const toRad = (d) => d * Math.PI / 180;
  const offset = ([lon, lat], km, deg) => {
    const a = toRad(90 - deg);
    return [lon + (km / (111.32 * Math.cos(toRad(lat)))) * Math.cos(a), lat + (km / 110.57) * Math.sin(a)];
  };
  const circle = (c, km, n = 96) => Array.from({ length: n + 1 }, (_, i) => offset(c, km, (360 * i) / n));
  const wedge = (c, km, from, to) => {
    const out = [c];
    for (let d = from; d <= to; d += 3) out.push(offset(c, km, d));
    out.push(c);
    return out;
  };
  const bearing = (a, b) => {
    const y = Math.sin(toRad(b[0] - a[0])) * Math.cos(toRad(b[1]));
    const x = Math.cos(toRad(a[1])) * Math.sin(toRad(b[1])) - Math.sin(toRad(a[1])) * Math.cos(toRad(b[1])) * Math.cos(toRad(b[0] - a[0]));
    return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
  };

  let route = null; // { coordinates, distances, elevations }
  function along(m) {
    const { coordinates: c, distances: d, elevations: e } = route;
    const total = d[d.length - 1];
    m = Math.max(0, Math.min(total, m));
    let i = 1;
    while (i < d.length - 1 && d[i] < m) i++;
    const t = (m - d[i - 1]) / Math.max(1, d[i] - d[i - 1]);
    return {
      pt: [c[i - 1][0] + (c[i][0] - c[i - 1][0]) * t, c[i - 1][1] + (c[i][1] - c[i - 1][1]) * t],
      ele: e[i - 1] + (e[i] - e[i - 1]) * t,
    };
  }

  // --- Mapa
  const empty = { type: 'FeatureCollection', features: [] };
  const map = new maplibregl.Map({
    container: 'map',
    style: {
      version: 8,
      sources: {
        sat: { type: 'raster', tiles: [`${ORIGIN}/tiles/sat/{z}/{x}/{y}`], tileSize: 256, maxzoom: 17, attribution: 'Imagen © Esri, Maxar, Earthstar Geographics' },
        dem: { type: 'raster-dem', tiles: [`${ORIGIN}/tiles/dem/{z}/{x}/{y}`], tileSize: 256, maxzoom: 12, encoding: 'terrarium', attribution: 'Relieve: Mapzen Terrain Tiles' },
        hs: { type: 'raster-dem', tiles: [`${ORIGIN}/tiles/dem/{z}/{x}/{y}`], tileSize: 256, maxzoom: 12, encoding: 'terrarium' },
        contours: { type: 'geojson', data: `${ORIGIN}/data/contours.geojson` },
        trails: { type: 'geojson', data: `${ORIGIN}/data/trails.geojson`, attribution: '© colaboradores de OpenStreetMap' },
        route: { type: 'geojson', data: empty },
        zones: { type: 'geojson', data: empty },
        ash: { type: 'geojson', data: empty },
        evac: { type: 'geojson', data: empty },
      },
      layers: [
        { id: 'bg', type: 'background', paint: { 'background-color': '#1d2426' } },
        { id: 'sat', type: 'raster', source: 'sat', paint: { 'raster-fade-duration': 0 } },
        { id: 'hillshade', type: 'hillshade', source: 'hs', layout: { visibility: 'none' }, paint: { 'hillshade-exaggeration': 0.75, 'hillshade-shadow-color': '#2b3a40', 'hillshade-highlight-color': '#ffffff', 'hillshade-accent-color': '#5d6b5b' } },
        { id: 'zones-fill', type: 'fill', source: 'zones', layout: { visibility: 'none' }, paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.24 } },
        { id: 'zones-line', type: 'line', source: 'zones', layout: { visibility: 'none' }, paint: { 'line-color': ['get', 'color'], 'line-width': 2 } },
        { id: 'ash', type: 'fill', source: 'ash', layout: { visibility: 'none' }, paint: { 'fill-color': '#6d7378', 'fill-opacity': 0.35, 'fill-outline-color': '#3e4347' } },
        { id: 'contours', type: 'line', source: 'contours', layout: { 'line-join': 'round' }, paint: { 'line-color': '#f3e6c4', 'line-opacity': ['case', ['get', 'idx'], 0.85, 0.45], 'line-width': ['case', ['get', 'idx'], 1.4, 0.6] } },
        { id: 'trails', type: 'line', source: 'trails', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#ffd23f', 'line-width': 1.6, 'line-dasharray': [2, 1.5], 'line-opacity': 0.9 } },
        { id: 'evac', type: 'line', source: 'evac', layout: { visibility: 'none', 'line-cap': 'round' }, paint: { 'line-color': '#22c06a', 'line-width': 4, 'line-dasharray': [1.5, 1] } },
        { id: 'route-casing', type: 'line', source: 'route', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#ffffff', 'line-width': 6.5, 'line-opacity': 0.85 } },
        { id: 'route', type: 'line', source: 'route', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#d0245a', 'line-width': 3.5 } },
      ],
      terrain: { source: 'dem', exaggeration: 1.4 },
      sky: { 'sky-color': '#8ec1ea', 'horizon-color': '#e8f1f7', 'fog-color': '#dbe6ec', 'sky-horizon-blend': 0.6, 'horizon-fog-blend': 0.6, 'fog-ground-blend': 0.4 },
    },
    center: [-98.655, 19.125], zoom: 11.6, pitch: 62, bearing: 158,
    minZoom: 8, maxZoom: 17, maxPitch: 82,
    attributionControl: false,
  });
  // Arriba a la izquierda: abajo la tapa el panel de Flutter
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'top-left');

  // Capas lógicas (las que ve el usuario) → capas de MapLibre o grupos de marcadores
  const LAYER_MAP = {
    route: { layers: ['route', 'route-casing'] },
    trails: { layers: ['trails'] },
    contours: { layers: ['contours'] },
    hillshade: { layers: ['hillshade'] },
    zones: { layers: ['zones-fill', 'zones-line'] },
    ash: { layers: ['ash'] },
    evac: { layers: ['evac'] },
    peaks: { markers: 'peaks' },
    members: { markers: 'members' },
    shelters: { markers: 'shelters' },
    reports: { markers: 'reports' },
  };
  const markers = { peaks: [], members: [], shelters: [], reports: [] };
  const visible = {};
  let styleReady = false;
  const pending = [];
  const whenReady = (fn) => (styleReady ? fn() : pending.push(fn));
  map.once('style.load', () => { styleReady = true; pending.splice(0).forEach((fn) => fn()); });

  const mk = (el, at, anchor = 'bottom') => new maplibregl.Marker({ element: el, anchor }).setLngLat(at);
  const tappable = (el, kind, id) => el.addEventListener('click', (e) => { e.stopPropagation(); emit('markerTap', { kind, id }); });

  function setLayer(id, on) {
    visible[id] = on;
    const def = LAYER_MAP[id];
    if (!def) return;
    if (def.layers) whenReady(() => def.layers.forEach((l) => map.setLayoutProperty(l, 'visibility', on ? 'visible' : 'none')));
    if (def.markers) markers[def.markers].forEach((m) => (on ? m.addTo(map) : m.remove()));
  }

  // --- Carga de datos
  async function loadJson(path) {
    const r = await fetch(`${ORIGIN}/data/${path}`);
    if (!r.ok) throw new Error(`No se pudo cargar ${path}: ${r.status}`);
    return r.json();
  }

  async function loadData() {
    const [routeData, peaks, civil] = await Promise.all([
      loadJson('arista_del_sol.json'), loadJson('peaks.json'), loadJson('civil_demo.json'),
    ]);
    route = routeData;
    whenReady(() => map.getSource('route').setData({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: route.coordinates } }));

    for (const p of peaks) {
      const closed = p.name === 'Popocatépetl';
      const el = document.createElement('div');
      el.className = `mk ${p.kind === 'alpine_hut' ? 'hut' : p.kind === 'trailhead' ? 'trailhead' : ''}${closed ? ' closed' : ''}`;
      const label = p.name.replace(' Iztaccíhuatl (Cumbre)', ' · cumbre').replace(' Iztaccíhuatl', '');
      el.innerHTML = `<div class="lbl">${label}${p.ele ? `<em>${Number(p.ele).toLocaleString('es-MX')} m</em>` : ''}</div><div class="stem"></div><div class="tri"></div>`;
      tappable(el, 'peak', p.name);
      markers.peaks.push(mk(el, [p.lon, p.lat]));
    }

    const c = civil.volcano.center;
    const rings = [...civil.zones].sort((a, b) => a.radiusKm - b.radiusKm);
    const zoneFeatures = rings.map((z, i) => ({
      type: 'Feature', properties: { level: z.level, color: z.color },
      geometry: { type: 'Polygon', coordinates: i === 0 ? [circle(c, z.radiusKm)] : [circle(c, z.radiusKm), circle(c, rings[i - 1].radiusKm).reverse()] },
    }));
    const p = civil.ashPlume;
    whenReady(() => {
      map.getSource('zones').setData({ type: 'FeatureCollection', features: zoneFeatures });
      map.getSource('ash').setData({ type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: [wedge(c, p.lengthKm, p.fromBearing, p.toBearing)] } });
      map.getSource('evac').setData({ type: 'Feature', properties: {}, geometry: { type: 'MultiLineString', coordinates: civil.evacuationRoutes } });
    });
    for (const s of civil.shelters) {
      const el = document.createElement('div');
      el.className = 'shelter'; el.textContent = 'A';
      tappable(el, 'shelter', s.id);
      markers.shelters.push(mk(el, s.at, 'center'));
    }
    for (const r of civil.reports) {
      const el = document.createElement('div');
      el.className = 'report'; el.style.background = r.color; el.dataset.id = r.id;
      tappable(el, 'report', r.id);
      markers.reports.push(mk(el, r.at, 'center'));
    }
    // Reaplica la visibilidad pedida antes de que llegaran los datos
    Object.entries(visible).forEach(([id, on]) => setLayer(id, on));
  }

  // --- Cámara
  const ms = (d) => (reduceMotion ? 0 : d);
  let padding = { top: 40, bottom: 40, left: 40, right: 40 };
  let is3d = true;
  let exaggeration = 1.4;

  function fitRoute() {
    if (!route) return;
    const b = new maplibregl.LngLatBounds(route.coordinates[0], route.coordinates[0]);
    route.coordinates.forEach((pt) => b.extend(pt));
    map.fitBounds(b, { padding, pitch: is3d ? 60 : 0, bearing: is3d ? 160 : 0, duration: ms(1800) });
  }

  let flying = null;
  function stopFly() {
    if (!flying) return;
    cancelAnimationFrame(flying);
    flying = null;
    emit('flyEnd');
  }
  function flyRoute(durationMs = 38000) {
    if (!route) return;
    stopFly();
    if (!is3d) api.set3d(true);
    const total = route.distances[route.distances.length - 1];
    let t0 = null;
    let brg = map.getBearing();
    const step = (ts) => {
      if (t0 === null) t0 = ts;
      const k = Math.min(1, (ts - t0) / durationMs);
      const m = k * total;
      const a = along(m);
      const target = bearing(a.pt, along(m + 700).pt);
      brg += (((target - brg + 540) % 360) - 180) * 0.03;
      map.jumpTo({ center: a.pt, zoom: 14.3, pitch: 68, bearing: brg });
      showCursorAt(a.pt);
      emit('flyProgress', { meters: Math.round(m) });
      if (k < 1) flying = requestAnimationFrame(step);
      else { flying = null; emit('flyEnd'); }
    };
    flying = requestAnimationFrame(step);
  }
  map.on('dragstart', stopFly);

  const cursorEl = document.createElement('div');
  cursorEl.className = 'cursor-mk';
  const cursor = new maplibregl.Marker({ element: cursorEl });
  const showCursorAt = (pt) => cursor.setLngLat(pt).addTo(map);

  let me = null;
  const memberMarkers = new Map();

  // --- API pública para Flutter
  const api = {
    setPadding(p) { padding = p; },
    setLayer,
    setLayers(states) { Object.entries(states).forEach(([id, on]) => setLayer(id, on)); },
    setBase(base) {
      whenReady(() => {
        map.setLayoutProperty('sat', 'visibility', base === 'sat' ? 'visible' : 'none');
        map.setPaintProperty('contours', 'line-color', base === 'sat' ? '#f3e6c4' : '#9a6b3c');
        map.setPaintProperty('bg', 'background-color', base === 'sat' ? '#1d2426' : '#e9e6dc');
      });
    },
    set3d(on) {
      is3d = on;
      whenReady(() => map.setTerrain(on ? { source: 'dem', exaggeration } : null));
      map.easeTo({ pitch: on ? 62 : 0, bearing: on ? map.getBearing() : 0, duration: ms(900) });
    },
    setExaggeration(x) {
      exaggeration = x;
      if (is3d) whenReady(() => map.setTerrain({ source: 'dem', exaggeration }));
    },
    fitRoute,
    flyRoute,
    stopFly,
    flyTo(lng, lat, zoom = 13.5, pitch = 55, bearingDeg) {
      stopFly();
      map.flyTo({ center: [lng, lat], zoom, pitch: is3d ? pitch : 0, ...(bearingDeg == null ? {} : { bearing: bearingDeg }), duration: ms(1600) });
    },
    showCursorAtMeters(m) { if (route) showCursorAt(along(m).pt); },
    hideCursor() { cursor.remove(); },
    setMembers(list) {
      for (const p of list) {
        let m = memberMarkers.get(p.id);
        if (!m) {
          const el = document.createElement('div');
          el.className = 'member'; el.style.background = p.color; el.style.setProperty('--c', p.color);
          el.textContent = p.initials;
          tappable(el, 'member', p.id);
          m = mk(el, [p.lng, p.lat], 'center');
          memberMarkers.set(p.id, m);
          markers.members.push(m);
          if (visible.members) m.addTo(map);
        }
        m.setLngLat([p.lng, p.lat]);
      }
    },
    setMyLocation(lng, lat) {
      if (!me) {
        const el = document.createElement('div');
        el.className = 'me';
        me = mk(el, [lng, lat], 'center').addTo(map);
      }
      me.setLngLat([lng, lat]);
    },
    pulseReport(id) {
      const el = document.querySelector(`.report[data-id="${id}"]`);
      if (!el) return;
      el.classList.remove('pulse'); void el.offsetWidth; el.classList.add('pulse');
    },
  };
  window.cresta = api;

  map.on('load', () => {
    // Créditos plegados al inicio (botón ⓘ) para no tapar los controles
    document.querySelector('.maplibregl-ctrl-attrib')?.classList.remove('maplibregl-compact-show');
    emit('ready');
  });
  map.on('error', (e) => emit('error', { message: String(e.error && e.error.message) }));
  loadData().catch((e) => emit('error', { message: e.message }));
})();
