// Motor de mapa de Cresta: MapLibre GL JS dentro de un WebView.
// Flutter llama a window.cresta.<método>(...) y recibe eventos por el canal CrestaBridge.
// Todo se pide al servidor local (127.0.0.1), que responde con lo descargado o, si hay red, lo trae.
(() => {
  'use strict';

  const ORIGIN = location.origin;
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const emit = (type, data = {}) => {
    const msg = JSON.stringify({ type, ...data });
    if (window.CrestaBridge) window.CrestaBridge.postMessage(msg);
    else console.log('[bridge]', msg);
  };
  window.addEventListener('error', (e) => emit('error', { message: `${e.message} (${e.filename}:${e.lineno})` }));
  window.addEventListener('unhandledrejection', (e) => emit('error', { message: String(e.reason && (e.reason.stack || e.reason)) }));

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
  const bboxPolygon = ([w, s, e, n]) => [[[w, s], [e, s], [e, n], [w, n], [w, s]]];

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

  // --- Curvas de nivel calculadas en el teléfono a partir del relieve (sirven en cualquier zona descargada)
  const demSource = new mlcontour.DemSource({ url: `${ORIGIN}/tiles/dem/{z}/{x}/{y}`, encoding: 'terrarium', maxzoom: 12, worker: true });
  demSource.setupMaplibre(maplibregl);
  const contourTiles = demSource.contourProtocolUrl({
    thresholds: { 10: [200, 1000], 11: [200, 1000], 12: [100, 500], 13: [100, 500], 14: [50, 250], 15: [20, 100] },
    elevationKey: 'ele', levelKey: 'level', contourLayer: 'contours',
  });

  // --- Pendiente del terreno calculada en el teléfono a partir del relieve (sin conexión, en cualquier zona
  // descargada). slope://<modo>/z/x/y: "slope" colorea por grados; "flat" solo marca lo casi plano.
  // El relieve es de ~30 m por píxel: suaviza escalones cortos y no ve rellanos de pocos metros.
  const SLOPE_CLASSES = {
    slope: [[10, [76, 175, 80, 90]], [20, [240, 200, 60, 115]], [30, [245, 140, 50, 130]], [40, [220, 60, 50, 140]], [91, [120, 50, 140, 150]]],
    flat: [[5, [70, 234, 229, 150]], [10, [70, 234, 229, 80]], [91, [0, 0, 0, 0]]],
  };
  const demUrl = (z, x, y) => `${ORIGIN}/tiles/dem/${z}/${x}/${y}`;
  const slopeCache = new Map(); // grados por píxel de los mosaicos de relieve ya leídos

  /// Grados de pendiente de cada píxel de un mosaico de relieve (null si no está descargado).
  async function slopeGrid(z, x, y, signal) {
    const key = `${z}/${x}/${y}`;
    if (slopeCache.has(key)) return slopeCache.get(key);
    const res = await fetch(demUrl(z, x, y), { signal });
    if (!res.ok || res.status === 204) return null;
    const bmp = await createImageBitmap(await res.blob());
    const n = bmp.width;
    const ctx = new OffscreenCanvas(n, n).getContext('2d', { willReadFrequently: true });
    ctx.drawImage(bmp, 0, 0);
    const px = ctx.getImageData(0, 0, n, n).data;
    const ele = new Float32Array(n * n);
    for (let i = 0; i < n * n; i++) ele[i] = px[i * 4] * 256 + px[i * 4 + 1] + px[i * 4 + 2] / 256 - 32768;
    // Metros por píxel a la latitud del centro del mosaico (Web Mercator)
    const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * (y + 0.5) / 2 ** z)));
    const m = 40075016.686 * Math.cos(lat) / (n * 2 ** z);
    const deg = new Float32Array(n * n);
    for (let r = 0; r < n; r++) {
      for (let c = 0; c < n; c++) {
        // Diferencias centrales; en el borde, de un solo lado (no se piden los mosaicos vecinos)
        const c0 = Math.max(0, c - 1), c1 = Math.min(n - 1, c + 1), r0 = Math.max(0, r - 1), r1 = Math.min(n - 1, r + 1);
        const dx = (ele[r * n + c1] - ele[r * n + c0]) / ((c1 - c0) * m);
        const dy = (ele[r1 * n + c] - ele[r0 * n + c]) / ((r1 - r0) * m);
        deg[r * n + c] = Math.atan(Math.hypot(dx, dy)) * 180 / Math.PI;
      }
    }
    const grid = { n, deg };
    if (slopeCache.size > 64) slopeCache.delete(slopeCache.keys().next().value);
    slopeCache.set(key, grid);
    return grid;
  }

  /// El mosaico pedido o, si no está (p. ej. zona Básica sin z12), el ancestro más cercano y qué parte usar.
  async function slopeSource(z, x, y, signal) {
    for (let k = 0; z - k >= 8; k++) {
      const grid = await slopeGrid(z - k, x >> k, y >> k, signal);
      if (grid) {
        const size = grid.n >> k;
        return { grid, sx: (x - ((x >> k) << k)) * size, sy: (y - ((y >> k) << k)) * size, size: Math.max(1, size) };
      }
    }
    return null;
  }

  maplibregl.addProtocol('slope', async (params, abort) => {
    const [, mode, z, x, y] = params.url.match(/^slope:\/\/(\w+)\/(\d+)\/(\d+)\/(\d+)/).map((v, i) => (i > 1 ? +v : v));
    const src = await slopeSource(z, x, y, abort.signal);
    if (!src) throw new Error('sin relieve');
    const { grid, sx, sy, size } = src;
    const classes = SLOPE_CLASSES[mode];
    const img = new ImageData(size, size);
    for (let r = 0; r < size; r++) {
      for (let c = 0; c < size; c++) {
        const d = grid.deg[(sy + r) * grid.n + sx + c];
        const rgba = classes.find(([max]) => d < max)[1];
        img.data.set(rgba, (r * size + c) * 4);
      }
    }
    const small = new OffscreenCanvas(size, size);
    small.getContext('2d').putImageData(img, 0, 0);
    const out = new OffscreenCanvas(256, 256);
    const octx = out.getContext('2d');
    octx.imageSmoothingEnabled = false; // clases nítidas al ampliar un mosaico padre
    octx.drawImage(small, 0, 0, 256, 256);
    return { data: await (await out.convertToBlob({ type: 'image/png' })).arrayBuffer() };
  });

  // --- Estilo. Capas base (cambian con el mapa base) y capas superpuestas (las enciende el usuario).
  const C = {
    land: '#f2efe6', wood: '#cfe1bd', grass: '#e3ebcb', rock: '#e2ddd5', ice: '#fbfdff', sand: '#efe5c6', wetland: '#d3e6df',
    residential: '#e9e2d8', water: '#a8cbe6', waterway: '#7eafd9', contour: '#a9825a', road: '#ffffff', roadCase: '#c9c1b6',
    major: '#f3c56d', track: '#8a6236', path: '#c4342c', label: '#2a2a28', halo: 'rgba(255,255,255,0.9)',
  };
  const empty = { type: 'FeatureCollection', features: [] };
  // Mismos tipos que PoiKind en Dart
  const POI_COLORS = ['water', '#5aa9e6', 'camp', '#f0bf63', 'shelter', '#d69a5c', 'summit', '#46eae5', 'noReturn', '#ffa089', 'danger', '#ff5f52'];
  // Íconos de lugares (como Gaia o Wikiloc): un círculo de color con un emoji del sistema,
  // dibujados en el teléfono (sin descargar nada; funcionan sin señal)
  const POI_ICONS = {
    water: ['💧', '#2f7fc4'], hut: ['🏠', '#9a5f33'], camp: ['⛺', '#3a8a48'], food: ['🍴', '#d9682a'],
    lodging: ['🛏', '#7552b8'], health: ['✚', '#cf3d3d'], police: ['🚓', '#34539c'], parking: ['P', '#2f62c4'],
    toilets: ['🚻', '#56636e'], view: ['🔭', '#22827d'], shop: ['🛒', '#b26f1f'], fuel: ['⛽', '#b8402f'],
    bus: ['🚌', '#2f62c4'], culture: ['🏛', '#8a4fa3'], info: ['ℹ', '#2f62c4'], sport: ['⚽', '#3a8a48'],
    photo: ['📷', '#00a8a3'], // fotos del recorrido
  };
  // Tipo de ícono según la clase de OpenMapTiles; '' = sin ícono
  const POI_KIND = ['match', ['get', 'subclass'],
    ['drinking_water', 'spring', 'water_point'], 'water',
    ['alpine_hut', 'shelter', 'wilderness_hut'], 'hut',
    ['camp_site', 'caravan_site'], 'camp',
    ['viewpoint'], 'view',
    ['toilets'], 'toilets',
    ['parking'], 'parking',
    ['hospital', 'clinic', 'doctors', 'pharmacy'], 'health',
    ['police'], 'police',
    ['fuel'], 'fuel',
    ['bus_station', 'bus_stop'], 'bus',
    ['museum', 'attraction', 'artwork', 'theatre'], 'culture',
    ['information'], 'info',
    ['match', ['get', 'class'],
      ['restaurant', 'cafe', 'fast_food', 'bar', 'beer', 'ice_cream', 'bakery'], 'food',
      ['lodging'], 'lodging',
      ['grocery', 'shop', 'alcohol_shop', 'clothing_store'], 'shop',
      ['sports_centre', 'stadium', 'pitch'], 'sport',
      '']];
  // Lo que importa en la montaña se ve desde más lejos; lo de ciudad, solo de muy cerca (desde z16:
  // en z15 la comida y las farmacias tapaban las calles, revisión del 14 nov 2026)
  // Las farmacias, aunque son "salud", solo de cerca: en la ciudad hay una por cuadra
  const POI_FAR = ['all', ['match', POI_KIND, ['water', 'hut', 'camp', 'health', 'toilets', 'view'], true, false],
    ['!=', ['get', 'subclass'], 'pharmacy']];
  function poiImage(glyph, color) {
    const r = devicePixelRatio || 2, size = Math.round(26 * r), c = document.createElement('canvas');
    c.width = c.height = size;
    const g = c.getContext('2d');
    g.beginPath(); g.arc(size / 2, size / 2, size / 2 - 1.5 * r, 0, Math.PI * 2);
    g.fillStyle = color; g.fill(); g.lineWidth = 2 * r; g.strokeStyle = '#ffffff'; g.stroke();
    const ascii = /^[\x20-\x7e✚ℹ]$/.test(glyph);
    g.font = `${ascii ? 'bold ' : ''}${Math.round((ascii ? 14 : 13) * r)}px sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#ffffff';
    g.fillText(glyph, size / 2, size / 2 + r);
    return { image: g.getImageData(0, 0, size, size), pixelRatio: r };
  }
  const font = (w) => [w === 'bold' ? 'Noto Sans Bold' : w === 'italic' ? 'Noto Sans Italic' : 'Noto Sans Regular'];
  const roadClass = (...c) => ['match', ['get', 'class'], c, true, false];

  const BASE_LAYERS = {
    topo: ['bg-topo', 'landcover', 'landuse', 'park', 'water', 'waterway', 'buildings'],
    sat: ['sat'],
    relief: ['bg-relief', 'water', 'waterway'],
    night: ['bg-topo', 'landcover', 'landuse', 'park', 'water', 'waterway', 'buildings'],
  };
  // "Noche": el topográfico con los colores oscuros de Cresta (mismos datos, nada que descargar)
  const NIGHT = {
    'bg-topo': { 'background-color': '#141c1f' },
    landcover: { 'fill-color': ['match', ['get', 'class'], 'wood', '#1c2e26', 'grass', '#1f2b25', 'rock', '#262c2e', 'ice', '#33434a', 'sand', '#2e2a20', 'wetland', '#1b2d2e', '#1f2b25'] },
    landuse: { 'fill-color': '#1d2528' },
    park: { 'line-color': '#4f7d43' },
    water: { 'fill-color': '#12313f' },
    waterway: { 'line-color': '#2b6684' },
    buildings: { 'fill-color': '#2a3438' },
    'buildings-3d': { 'fill-extrusion-color': '#33434a' },
    'roads-case': { 'line-color': '#0a0f11' },
    roads: { 'line-color': ['match', ['get', 'class'], ['motorway', 'trunk', 'primary', 'secondary'], '#b98d42', '#45535a'] },
    tracks: { 'line-color': '#9a7650' },
    trails: { 'line-color': '#e0675d' },
    contours: { 'line-color': '#8a7458' },
    'contour-labels': { 'text-color': '#b49f82', 'text-halo-color': 'rgba(8,12,14,0.9)' },
    hillshade: { 'hillshade-shadow-color': '#020405', 'hillshade-highlight-color': '#5a6a70', 'hillshade-accent-color': '#2a2f28' },
    boundaries: { 'line-color': '#8e80a0' },
  };
  const dayPaint = {};
  function paintNight(on) {
    Object.entries(NIGHT).forEach(([id, props]) => {
      if (!map.getLayer(id)) return;
      Object.entries(props).forEach(([p, v]) => {
        const key = `${id}|${p}`;
        if (!(key in dayPaint)) dayPaint[key] = map.getPaintProperty(id, p);
        map.setPaintProperty(id, p, on ? v : dayPaint[key]);
      });
    });
  }

  const map = new maplibregl.Map({
    container: 'map',
    style: {
      version: 8,
      glyphs: `${ORIGIN}/fonts/{fontstack}/{range}.pbf`,
      sources: {
        sat: { type: 'raster', tiles: [`${ORIGIN}/tiles/sat/{z}/{x}/{y}`], tileSize: 256, maxzoom: 14, attribution: 'Sentinel-2 cloudless 2024 © EOX (datos Copernicus)' },
        dem: { type: 'raster-dem', tiles: [`${ORIGIN}/tiles/dem/{z}/{x}/{y}`], tileSize: 256, maxzoom: 12, encoding: 'terrarium', attribution: 'Relieve: Mapzen Terrain Tiles' },
        hs: { type: 'raster-dem', tiles: [`${ORIGIN}/tiles/dem/{z}/{x}/{y}`], tileSize: 256, maxzoom: 12, encoding: 'terrarium' },
        topo: { type: 'vector', tiles: [`${ORIGIN}/tiles/topo/{z}/{x}/{y}`], maxzoom: 14, attribution: '© OpenMapTiles © colaboradores de OpenStreetMap' },
        contours: { type: 'vector', tiles: [contourTiles], maxzoom: 15 },
        slope: { type: 'raster', tiles: ['slope://slope/{z}/{x}/{y}'], tileSize: 256, minzoom: 8, maxzoom: 12 },
        flat: { type: 'raster', tiles: ['slope://flat/{z}/{x}/{y}'], tileSize: 256, minzoom: 8, maxzoom: 12 },
        route: { type: 'geojson', data: empty },
        compare: { type: 'geojson', data: empty },
        plan: { type: 'geojson', data: empty },
        'plan-pts': { type: 'geojson', data: empty },
        pois: { type: 'geojson', data: empty },
        found: { type: 'geojson', data: empty },
        track: { type: 'geojson', data: empty },
        'track-ends': { type: 'geojson', data: empty },
        'video-track': { type: 'geojson', data: empty, lineMetrics: true },
        'video-streets': { type: 'geojson', data: empty },
        'track-hidden': { type: 'geojson', data: empty },
        photos: { type: 'geojson', data: empty },
        regions: { type: 'geojson', data: empty },
        zones: { type: 'geojson', data: empty },
        ash: { type: 'geojson', data: empty },
        evac: { type: 'geojson', data: empty },
      },
      layers: [
        // Base: topográfico
        { id: 'bg-topo', type: 'background', paint: { 'background-color': C.land } },
        { id: 'bg-relief', type: 'background', layout: { visibility: 'none' }, paint: { 'background-color': '#ece8df' } },
        { id: 'landcover', type: 'fill', source: 'topo', 'source-layer': 'landcover', paint: {
          'fill-color': ['match', ['get', 'class'], 'wood', C.wood, 'grass', C.grass, 'rock', C.rock, 'ice', C.ice, 'sand', C.sand, 'wetland', C.wetland, C.grass],
          'fill-opacity': 0.85 } },
        { id: 'landuse', type: 'fill', source: 'topo', 'source-layer': 'landuse', filter: roadClass('residential', 'suburb', 'neighbourhood', 'commercial', 'industrial'), paint: { 'fill-color': C.residential } },
        { id: 'park', type: 'line', source: 'topo', 'source-layer': 'park', paint: { 'line-color': '#5c8f4a', 'line-width': 1.5, 'line-dasharray': [3, 2], 'line-opacity': 0.7 } },
        // Base: satélite
        { id: 'sat', type: 'raster', source: 'sat', layout: { visibility: 'none' }, paint: { 'raster-fade-duration': 0 } },
        // Sombreado (en relieve siempre; en topográfico opcional)
        { id: 'hillshade', type: 'hillshade', source: 'hs', paint: { 'hillshade-exaggeration': 0.6, 'hillshade-shadow-color': '#3d4a4f', 'hillshade-highlight-color': '#ffffff', 'hillshade-accent-color': '#6b6b55' } },
        { id: 'water', type: 'fill', source: 'topo', 'source-layer': 'water', paint: { 'fill-color': C.water } },
        { id: 'waterway', type: 'line', source: 'topo', 'source-layer': 'waterway', paint: { 'line-color': C.waterway, 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 0.5, 15, 2] } },
        { id: 'buildings', type: 'fill', source: 'topo', 'source-layer': 'building', minzoom: 13, paint: { 'fill-color': '#d6cdbf' } },
        // Superpuestas
        { id: 'slope', type: 'raster', source: 'slope', layout: { visibility: 'none' }, paint: { 'raster-fade-duration': 0 } },
        { id: 'flat', type: 'raster', source: 'flat', layout: { visibility: 'none' }, paint: { 'raster-fade-duration': 0 } },
        { id: 'zones-fill', type: 'fill', source: 'zones', layout: { visibility: 'none' }, paint: { 'fill-color': ['get', 'color'], 'fill-opacity': 0.24 } },
        { id: 'zones-line', type: 'line', source: 'zones', layout: { visibility: 'none' }, paint: { 'line-color': ['get', 'color'], 'line-width': 2 } },
        { id: 'ash', type: 'fill', source: 'ash', layout: { visibility: 'none' }, paint: { 'fill-color': '#6d7378', 'fill-opacity': 0.35, 'fill-outline-color': '#3e4347' } },
        { id: 'contours', type: 'line', source: 'contours', 'source-layer': 'contours', layout: { 'line-join': 'round' }, paint: {
          'line-color': C.contour, 'line-opacity': ['case', ['>', ['get', 'level'], 0], 0.8, 0.45], 'line-width': ['case', ['>', ['get', 'level'], 0], 1.1, 0.5] } },
        { id: 'contour-labels', type: 'symbol', source: 'contours', 'source-layer': 'contours', filter: ['>', ['get', 'level'], 0], layout: {
          'symbol-placement': 'line', 'text-field': ['concat', ['number-format', ['get', 'ele'], {}], ' m'], 'text-font': font(), 'text-size': 10 },
          paint: { 'text-color': '#7a5a38', 'text-halo-color': C.halo, 'text-halo-width': 1.2 } },
        { id: 'roads-case', type: 'line', source: 'topo', 'source-layer': 'transportation', filter: roadClass('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'minor'), layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': C.roadCase, 'line-width': ['interpolate', ['linear'], ['zoom'], 9, 1, 15, 7] } },
        { id: 'roads', type: 'line', source: 'topo', 'source-layer': 'transportation', filter: roadClass('motorway', 'trunk', 'primary', 'secondary', 'tertiary', 'minor'), layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': ['match', ['get', 'class'], ['motorway', 'trunk', 'primary', 'secondary'], C.major, C.road], 'line-width': ['interpolate', ['linear'], ['zoom'], 9, 0.5, 15, 5] } },
        { id: 'tracks', type: 'line', source: 'topo', 'source-layer': 'transportation', filter: roadClass('track', 'service'), layout: { 'line-join': 'round' },
          paint: { 'line-color': C.track, 'line-width': ['interpolate', ['linear'], ['zoom'], 11, 0.8, 15, 2.2], 'line-dasharray': [3, 1.5] } },
        { id: 'trails', type: 'line', source: 'topo', 'source-layer': 'transportation', filter: roadClass('path'), layout: { 'line-join': 'round' },
          paint: { 'line-color': C.path, 'line-width': ['interpolate', ['linear'], ['zoom'], 11, 1, 15, 2.4], 'line-dasharray': [2, 1.2] } },
        // Límites de países y estados
        { id: 'boundaries', type: 'line', source: 'topo', 'source-layer': 'boundary', filter: ['all', ['<=', ['get', 'admin_level'], 4], ['!=', ['get', 'maritime'], 1]],
          layout: { 'line-join': 'round' }, paint: {
          'line-color': '#7d6f8c', 'line-opacity': 0.75, 'line-dasharray': [4, 2, 1, 2],
          'line-width': ['interpolate', ['linear'], ['zoom'], 3, ['match', ['get', 'admin_level'], 2, 1, 0.5], 10, ['match', ['get', 'admin_level'], 2, 2.2, 1.4]] } },
        // Edificios en volumen (altura de OpenStreetMap; sin dato, OpenMapTiles pone ~5 m). Solo de cerca
        { id: 'buildings-3d', type: 'fill-extrusion', source: 'topo', 'source-layer': 'building', minzoom: 14, layout: { visibility: 'none' }, paint: {
          'fill-extrusion-color': '#ddd3c5', 'fill-extrusion-opacity': 0.85,
          'fill-extrusion-height': ['coalesce', ['get', 'render_height'], 5], 'fill-extrusion-base': ['coalesce', ['get', 'render_min_height'], 0] } },
        // Nombres de calles, caminos y senderos (a lo largo de la línea). Las grandes desde zoom 12, el resto desde 14
        { id: 'road-names', type: 'symbol', source: 'topo', 'source-layer': 'transportation_name', minzoom: 12,
          filter: ['any', ['match', ['get', 'class'], ['motorway', 'trunk', 'primary', 'secondary'], true, false], ['>=', ['zoom'], 14]],
          layout: { 'symbol-placement': 'line', 'symbol-spacing': 320, 'text-field': ['get', 'name'], 'text-font': font(),
            'text-size': ['interpolate', ['linear'], ['zoom'], 12, 10.5, 16, 13.5], 'text-max-angle': 30, 'text-padding': 4,
            // En 3D, de frente a la pantalla y no tumbados sobre el terreno (se leían "planos")
            'text-pitch-alignment': 'viewport' },
          paint: { 'text-color': ['match', ['get', 'class'], 'path', '#8f2a24', 'track', '#6b4a2b', '#4a4540'], 'text-halo-color': C.halo, 'text-halo-width': 1.4 } },
        { id: 'regions-line', type: 'line', source: 'regions', paint: { 'line-color': ['case', ['get', 'complete'], '#00a8a3', '#c99630'], 'line-width': 2, 'line-dasharray': [4, 2] } },
        { id: 'route-casing', type: 'line', source: 'route', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#0e1416', 'line-width': 7, 'line-opacity': 0.75 } },
        { id: 'route', type: 'line', source: 'route', filter: ['!=', ['get', 'snapped'], false], layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#46eae5', 'line-width': 4 } },
        // Tramos sin sendero (línea recta): punteados y con etiqueta
        { id: 'route-straight', type: 'line', source: 'route', filter: ['==', ['get', 'snapped'], false], layout: { 'line-join': 'round' }, paint: { 'line-color': '#46eae5', 'line-width': 3.5, 'line-dasharray': [1.6, 1.2] } },
        { id: 'route-straight-label', type: 'symbol', source: 'route', filter: ['==', ['get', 'snapped'], false], layout: {
          'symbol-placement': 'line', 'symbol-spacing': 260, 'text-field': 'sin sendero', 'text-font': font(), 'text-size': 11 },
          paint: { 'text-color': '#ffa089', 'text-halo-color': '#0e1416', 'text-halo-width': 1.6 } },
        // Comparar rutas: varias líneas, cada una con su color
        { id: 'compare-casing', type: 'line', source: 'compare', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#0e1416', 'line-width': 8, 'line-opacity': 0.75 } },
        { id: 'compare', type: 'line', source: 'compare', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': ['get', 'color'], 'line-width': 4.5 } },
        // Planificador: tramos ajustados a sendero en teal continuo (el color de la app); los rectos, punteados
        { id: 'plan-casing', type: 'line', source: 'plan', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#0e1416', 'line-width': 7, 'line-opacity': 0.75 } },
        { id: 'plan-snapped', type: 'line', source: 'plan', filter: ['==', ['get', 'snapped'], true], layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#46eae5', 'line-width': 4 } },
        { id: 'plan-straight', type: 'line', source: 'plan', filter: ['==', ['get', 'snapped'], false], layout: { 'line-join': 'round' }, paint: { 'line-color': '#46eae5', 'line-width': 3.5, 'line-dasharray': [1.6, 1.2] } },
        { id: 'plan-pts', type: 'circle', source: 'plan-pts', paint: {
          'circle-radius': ['match', ['get', 'role'], 'start', 7, 'end', 7, 5],
          'circle-color': ['match', ['get', 'role'], 'start', '#f0bf63', 'end', '#ffa089', '#e8f1f7'],
          'circle-stroke-color': '#0e1416', 'circle-stroke-width': 2.5 } },
        // Puntos de interés de la ruta (agua, campamento, punto de no retorno…)
        { id: 'pois-dot', type: 'circle', source: 'pois', paint: {
          'circle-radius': 7, 'circle-color': ['match', ['get', 'kind'], ...POI_COLORS, '#bacac8'],
          'circle-stroke-color': '#0e1416', 'circle-stroke-width': 2.5 } },
        { id: 'pois-label', type: 'symbol', source: 'pois', layout: {
          'text-field': ['get', 'name'], 'text-font': font('bold'), 'text-size': 11.5, 'text-offset': [0, 1.2], 'text-anchor': 'top', 'text-optional': true },
          paint: { 'text-color': '#0e1416', 'text-halo-color': 'rgba(255,255,255,0.92)', 'text-halo-width': 1.4 } },
        // Recorte para compartir: lo que no se mostrará, gris y punteado bajo el recorrido
        { id: 'track-hidden', type: 'line', source: 'track-hidden', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#9aa5a8', 'line-width': 4, 'line-opacity': 0.85, 'line-dasharray': [1.2, 1.4] } },
        // Recorrido grabado en teal, el color de la app (pedido del usuario, 14 nov 2026; antes coral). Con un
        // recorrido encima, la ruta planeada se atenúa (setTrack) para no confundirlas
        { id: 'track-casing', type: 'line', source: 'track', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#0e1416', 'line-width': 8, 'line-opacity': 0.8 } },
        { id: 'track', type: 'line', source: 'track', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#46eae5', 'line-width': 4.5 } },
        // Traza del video: se pinta con un degradado según el avance (sin recalcular la geometría)
        { id: 'video-casing', type: 'line', source: 'video-track', layout: { visibility: 'none', 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-width': 10, 'line-gradient': ['step', ['line-progress'], 'rgba(0,0,0,0)', 1, 'rgba(0,0,0,0)'] } },
        { id: 'video-line', type: 'line', source: 'video-track', layout: { visibility: 'none', 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-width': 6, 'line-gradient': ['step', ['line-progress'], 'rgba(0,0,0,0)', 1, 'rgba(0,0,0,0)'] } },
        // Nombres de las calles cercanas en el video: solo el pedazo de cada calle a ~200 m del recorrido
        { id: 'video-streets', type: 'symbol', source: 'video-streets', layout: { visibility: 'none', 'symbol-placement': 'line', 'symbol-spacing': 260,
          'text-field': ['get', 'name'], 'text-font': font(), 'text-size': 13, 'text-max-angle': 30, 'text-padding': 4, 'text-pitch-alignment': 'viewport' },
          paint: { 'text-color': '#4a4540', 'text-halo-color': C.halo, 'text-halo-width': 1.4 } },
        // Inicio y fin del recorrido (el fin, solo al verlo terminado: grabando, el fin eres tú)
        { id: 'track-ends', type: 'circle', source: 'track-ends', paint: {
          'circle-radius': ['match', ['get', 'role'], 'head', 8, 7], 'circle-color': ['match', ['get', 'role'], 'start', '#f0bf63', '#ffa089'],
          'circle-stroke-color': '#0e1416', 'circle-stroke-width': 2.5 } },
        { id: 'track-ends-label', type: 'symbol', source: 'track-ends', layout: {
          'text-field': ['match', ['get', 'role'], 'start', 'Inicio', 'end', 'Fin', ''], 'text-font': font('bold'), 'text-size': 12,
          'text-offset': [0, 1.3], 'text-anchor': 'top', 'text-allow-overlap': true },
          paint: { 'text-color': '#0e1416', 'text-halo-color': 'rgba(255,255,255,0.95)', 'text-halo-width': 1.6 } },
        { id: 'evac', type: 'line', source: 'evac', layout: { visibility: 'none', 'line-cap': 'round' }, paint: { 'line-color': '#22c06a', 'line-width': 4, 'line-dasharray': [1.5, 1] } },
        // Nombres
        { id: 'water-names', type: 'symbol', source: 'topo', 'source-layer': 'water_name', layout: { 'text-field': ['get', 'name'], 'text-font': font('italic'), 'text-size': 11 },
          paint: { 'text-color': '#3a6f9c', 'text-halo-color': C.halo, 'text-halo-width': 1.2 } },
        { id: 'peaks-dot', type: 'circle', source: 'topo', 'source-layer': 'mountain_peak', filter: roadClass('peak', 'volcano'),
          paint: { 'circle-radius': 3.5, 'circle-color': '#6b4a2b', 'circle-stroke-color': '#fff', 'circle-stroke-width': 1.2 } },
        { id: 'peaks', type: 'symbol', source: 'topo', 'source-layer': 'mountain_peak', filter: roadClass('peak', 'volcano'), layout: {
          'text-field': ['format', ['get', 'name'], { 'text-font': ['literal', font('bold')] }, ['case', ['has', 'ele'], ['concat', '\n', ['number-format', ['get', 'ele'], {}], ' m'], ''], {}],
          'text-font': font(), 'text-size': 11, 'text-anchor': 'top', 'text-offset': [0, 0.6], 'text-optional': true },
          paint: { 'text-color': C.label, 'text-halo-color': C.halo, 'text-halo-width': 1.4 } },
        // Íconos de lugares: agua, refugios, camping, comida, salud…
        { id: 'poi-icons', type: 'symbol', source: 'topo', 'source-layer': 'poi', minzoom: 13,
          // Sin nombre solo lo útil aunque no lo tenga (agua, baños…): estatuas y monumentos sin nombre ensuciaban el mapa
          filter: ['all', ['!=', POI_KIND, ''], ['any', ['>=', ['zoom'], 16], POI_FAR],
            ['any', ['has', 'name'], ['match', POI_KIND, ['water', 'toilets', 'parking', 'hut', 'camp', 'health'], true, false]]],
          layout: { 'icon-image': ['concat', 'poi-', POI_KIND], 'symbol-sort-key': ['get', 'rank'],
            'text-field': ['step', ['zoom'], '', 15, ['get', 'name']], 'text-font': font('bold'), 'text-size': 11.5,
            'text-offset': [0, 1.25], 'text-anchor': 'top', 'text-optional': true, 'text-max-width': 8 },
          paint: { 'text-color': '#3b3530', 'text-halo-color': C.halo, 'text-halo-width': 1.6 } },
        // Colonias, barrios y parajes: solo de cerca, en versales grises para no competir con los pueblos
        { id: 'places-minor', type: 'symbol', source: 'topo', 'source-layer': 'place', minzoom: 12, filter: roadClass('suburb', 'quarter', 'neighbourhood', 'isolated_dwelling', 'locality'), layout: {
          'text-field': ['get', 'name'], 'text-font': font(), 'text-size': 10.5, 'text-transform': 'uppercase', 'text-letter-spacing': 0.08, 'text-max-width': 8 },
          paint: { 'text-color': '#5f5850', 'text-halo-color': C.halo, 'text-halo-width': 1.4 } },
        // Países y estados (en español si el mapa lo trae): de lejos, hasta que aparecen los pueblos
        { id: 'places-region', type: 'symbol', source: 'topo', 'source-layer': 'place', maxzoom: 10, filter: roadClass('country', 'state', 'province'), layout: {
          'text-field': ['coalesce', ['get', 'name:es'], ['get', 'name']], 'text-font': font('bold'), 'text-transform': 'uppercase',
          'text-size': ['match', ['get', 'class'], 'country', 14, 11.5], 'text-letter-spacing': 0.12, 'text-max-width': 7 },
          paint: { 'text-color': '#5b4f6b', 'text-halo-color': C.halo, 'text-halo-width': 1.6 } },
        { id: 'places', type: 'symbol', source: 'topo', 'source-layer': 'place', filter: roadClass('city', 'town', 'village', 'hamlet'), layout: {
          'text-field': ['get', 'name'], 'text-font': font('bold'),
          'text-size': ['match', ['get', 'class'], 'city', 15, 'town', 13, 'village', 12, 11] },
          paint: { 'text-color': C.label, 'text-halo-color': C.halo, 'text-halo-width': 1.6 } },
        // Fotos del recorrido: un ícono de cámara donde se tomó cada una (tocarla la abre);
        // encima de la traza y de sus marcas de inicio y fin
        { id: 'photos', type: 'symbol', source: 'photos', layout: { 'icon-image': 'poi-photo', 'icon-size': 1.15, 'icon-allow-overlap': true } },
        // Lugar encontrado con la búsqueda: encima de todo, con su nombre siempre visible
        { id: 'found-ring', type: 'circle', source: 'found', paint: {
          'circle-radius': 15, 'circle-color': 'rgba(240,191,99,0.25)', 'circle-stroke-color': '#f0bf63', 'circle-stroke-width': 2 } },
        { id: 'found-dot', type: 'circle', source: 'found', paint: {
          'circle-radius': 6, 'circle-color': '#f0bf63', 'circle-stroke-color': '#0e1416', 'circle-stroke-width': 2.5 } },
        { id: 'found-label', type: 'symbol', source: 'found', layout: {
          'text-field': ['get', 'name'], 'text-font': font('bold'), 'text-size': 13, 'text-offset': [0, 1.5], 'text-anchor': 'top',
          'text-allow-overlap': true, 'text-ignore-placement': true },
          paint: { 'text-color': '#0e1416', 'text-halo-color': 'rgba(255,255,255,0.95)', 'text-halo-width': 1.6 } },
      ],
      terrain: { source: 'dem', exaggeration: 1.4 },
      sky: { 'sky-color': '#8ec1ea', 'horizon-color': '#e8f1f7', 'fog-color': '#dbe6ec', 'sky-horizon-blend': 0.6, 'horizon-fog-blend': 0.6, 'fog-ground-blend': 0.4 },
    },
    center: [-98.655, 19.125], zoom: 10, pitch: 0,
    minZoom: 2, maxZoom: 17, maxPitch: 82,
    attributionControl: false,
  });
  // Arriba a la izquierda: abajo la tapa el panel de Flutter
  map.addControl(new maplibregl.AttributionControl({ compact: true }), 'top-left');

  // Capas lógicas (las que ve el usuario) → capas de MapLibre o grupos de marcadores
  const LAYER_MAP = {
    route: { layers: ['route', 'route-casing', 'route-straight', 'route-straight-label', 'pois-dot', 'pois-label'] },
    track: { layers: ['track', 'track-casing'] },
    trails: { layers: ['trails', 'tracks'] },
    buildings3d: { layers: ['buildings-3d'] },
    contours: { layers: ['contours', 'contour-labels'] },
    labels: { layers: ['peaks', 'peaks-dot', 'places', 'places-minor', 'places-region', 'road-names', 'water-names', 'boundaries', 'poi-icons'] },
    hillshade: { layers: ['hillshade'] },
    slope: { layers: ['slope'] },
    flat: { layers: ['flat'] },
    regions: { layers: ['regions-line'] },
    zones: { layers: ['zones-fill', 'zones-line'] },
    ash: { layers: ['ash'] },
    evac: { layers: ['evac'] },
    members: { markers: 'members' },
    shelters: { markers: 'shelters' },
    reports: { markers: 'reports' },
  };
  const markers = { members: [], shelters: [], reports: [] };
  const visible = {};
  let base = 'topo';
  let styleReady = false;
  const pending = [];
  const whenReady = (fn) => (styleReady ? fn() : pending.push(fn));
  map.once('style.load', () => { styleReady = true; pending.splice(0).forEach((fn) => fn()); });

  const mk = (el, at, anchor = 'bottom') => new maplibregl.Marker({ element: el, anchor }).setLngLat(at);
  const tappable = (el, kind, id) => el.addEventListener('click', (e) => { e.stopPropagation(); emit('markerTap', { kind, id }); });
  const show = (id, on) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', on ? 'visible' : 'none');

  function setLayer(id, on) {
    visible[id] = on;
    const def = LAYER_MAP[id];
    if (!def) return;
    if (def.layers) whenReady(() => def.layers.forEach((l) => show(l, on || (id === 'hillshade' && base === 'relief'))));
    if (def.markers) markers[def.markers].forEach((m) => (on ? m.addTo(map) : m.remove()));
  }

  // Nombres del mapa: sobre el satélite, letras blancas con borde oscuro (como Google); con
  // fondo oscuro de por medio, las letras oscuras con borde blanco no se leían
  const NAME_LAYERS = ['peaks', 'places', 'places-minor', 'places-region', 'road-names', 'water-names', 'poi-icons'];
  const namePaint = {};
  function paintNames() {
    const sat = base === 'sat' || base === 'night';
    NAME_LAYERS.forEach((id) => {
      if (!map.getLayer(id)) return;
      namePaint[id] ??= { color: map.getPaintProperty(id, 'text-color'), halo: map.getPaintProperty(id, 'text-halo-color') };
      map.setPaintProperty(id, 'text-color', sat ? '#ffffff' : namePaint[id].color);
      map.setPaintProperty(id, 'text-halo-color', sat ? 'rgba(8,12,14,0.92)' : namePaint[id].halo);
      map.setPaintProperty(id, 'text-halo-width', sat ? 1.8 : 1.5);
    });
  }

  function setBase(next) {
    base = next;
    whenReady(() => {
      const all = new Set(Object.values(BASE_LAYERS).flat());
      all.forEach((l) => show(l, BASE_LAYERS[base].includes(l)));
      paintNight(base === 'night');
      paintNames();
      show('hillshade', base === 'relief' || !!visible.hillshade);
      map.setPaintProperty('hillshade', 'hillshade-exaggeration', base === 'relief' ? 0.85 : 0.5);
    });
  }

  // --- Cámara
  const ms = (d) => (reduceMotion ? 0 : d);
  let padding = { top: 40, bottom: 40, left: 40, right: 40 };
  let is3d = true;
  let exaggeration = 1.4;

  function fitBounds(w, s, e, n, opts = {}) {
    map.fitBounds([[w, s], [e, n]], { padding, pitch: is3d ? 55 : 0, bearing: 0, duration: ms(1200), maxZoom: 14, ...opts });
  }

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
      // A zoom ~13.4 se aprovecha el detalle descargado (relieve z12, mapa z14) sin verse borroso
      map.jumpTo({ center: a.pt, zoom: 13.4, pitch: 66, bearing: brg });
      showCursorAt(a.pt);
      emit('flyProgress', { meters: Math.round(m) });
      if (k < 1) flying = requestAnimationFrame(step);
      else { flying = null; emit('flyEnd'); }
    };
    flying = requestAnimationFrame(step);
  }
  // --- Video del recorrido
  // Se genera cuadro por cuadro (WebCodecs + mp4-muxer), no se graba "en vivo": cada cuadro espera
  // a que cargue lo visible y lleva su tiempo exacto, así sale fluido aunque los mosaicos tarden
  // (13 nov 2026: grabando en vivo salían 6–10 cuadros/s y saltos de cámara). El video se manda a
  // Flutter en pedazos ('videoChunk', luego 'videoEnd'): un solo mensaje de varios MB no pasa.
  let videoJob = null;
  function sendVideo(blob, type) {
    const reader = new FileReader();
    reader.onload = () => {
      const b64 = String(reader.result).split(',')[1] || '';
      const size = 256 * 1024;
      const n = Math.ceil(b64.length / size);
      for (let i = 0; i < n; i++) emit('videoChunk', { i, n, data: b64.slice(i * size, (i + 1) * size) });
      emit('videoEnd', { mime: type, chunks: n }); // 'type' pisaría el nombre del evento
    };
    reader.readAsDataURL(blob);
  }
  const VIDEO = { w: 720, h: 1280, fps: 30 };

  // Imagen del recorrido con el mapa de fondo: el lienzo del mapa a [width] píxeles de ancho
  // (sube la resolución solo para la captura), en PNG, por pedazos como el video
  const CLEAN_HIDE = ['poi-icons', 'places-minor', 'regions-line', 'photos', 'track-hidden', 'found-ring', 'found-dot', 'found-label'];
  let cleanWas = null;
  function setClean(on) {
    whenReady(() => {
      if (on && !cleanWas) {
        cleanWas = CLEAN_HIDE.map((id) => [id, map.getLayer(id) && map.getLayoutProperty(id, 'visibility')]);
        CLEAN_HIDE.forEach((id) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', 'none'));
      } else if (!on && cleanWas) {
        cleanWas.forEach(([id, v]) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', v || 'visible'));
        cleanWas = null;
      }
    });
  }
  // Nombre de referencia junto a cada punto [lng, lat] (imagen del recorrido: "desde dónde hasta
  // dónde"), con lo que ya cargó el mapa: una cumbre o un lugar con nombre muy cerca; si no, la
  // calle; si no, el barrio o pueblo. null si no hay nada cerca
  const REF_POI = ['park', 'garden', 'attraction', 'museum', 'monument', 'castle', 'stadium', 'campsite', 'camp_site', 'shelter',
    'alpine_hut', 'wilderness_hut', 'viewpoint', 'spring', 'place_of_worship', 'university', 'college', 'zoo', 'golf', 'theatre'];
  function nearestNames(points) {
    const feats = (layer) => { try { return map.querySourceFeatures('topo', { sourceLayer: layer }); } catch (_) { return []; } };
    const groups = [
      [feats('mountain_peak'), 300],
      // Lugares que sirven de referencia (no comercios: "Repuestos Renault" no dice nada)
      [[...feats('poi').filter((f) => f.properties && (REF_POI.includes(f.properties.class) || REF_POI.includes(f.properties.subclass))), ...feats('water_name'), ...feats('park')], 150],
      [feats('transportation_name'), 60],
      // Parques y lagos grandes: su nombre está en un solo punto, a veces lejos del borde
      [[...feats('water_name'), ...feats('poi').filter((f) => f.properties && ['park', 'garden', 'nature_reserve'].includes(f.properties.class))], 900],
      [feats('place').filter((f) => f.properties && f.properties.class !== 'country' && f.properties.class !== 'state'), 2500],
    ];
    const meters = (a, b) => {
      const k = Math.cos(a[1] * Math.PI / 180);
      return Math.hypot((a[0] - b[0]) * k, a[1] - b[1]) * 111320;
    };
    // Dentro de un polígono (un parque grande): distancia 0
    const inRing = (pt, ring) => {
      let inside = false;
      for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        const [xi, yi] = ring[i], [xj, yj] = ring[j];
        if ((yi > pt[1]) !== (yj > pt[1]) && pt[0] < (xj - xi) * (pt[1] - yi) / (yj - yi) + xi) inside = !inside;
      }
      return inside;
    };
    const polys = (g) => (g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : []);
    // Distancia del punto a la figura (a sus vértices; las calles cortas de los mosaicos bastan)
    const dist = (pt, g) => {
      if (polys(g).some((rings) => inRing(pt, rings[0]))) return 0;
      const c = g.type === 'Point' ? [g.coordinates] : g.type === 'LineString' || g.type === 'MultiPoint' ? g.coordinates
        : g.type === 'MultiLineString' || g.type === 'Polygon' ? g.coordinates.flat() : g.type === 'MultiPolygon' ? g.coordinates.flat(2) : [];
      let best = Infinity;
      for (const q of c) best = Math.min(best, meters(pt, q));
      return best;
    };
    return points.map((pt) => {
      for (const [list, max] of groups) {
        let best = null, bestD = max;
        for (const f of list) {
          const p = f.properties || {};
          const name = p['name:es'] || p.name;
          if (!name) continue;
          const dd = dist(pt, f.geometry);
          if (dd < bestD) { bestD = dd; best = name; }
        }
        if (best) return best;
      }
      return null;
    });
  }
  // Lo mismo, acercándose a cada punto (a lo lejos los mosaicos no traen parques, lagos ni
  // calles chicas) y volviendo después; responde con el evento 'names'
  async function findNames(points) {
    const cam = { center: map.getCenter(), zoom: map.getZoom(), bearing: map.getBearing(), pitch: map.getPitch() };
    const names = [];
    try {
      for (const pt of points) {
        map.jumpTo({ center: pt, zoom: 15 });
        for (let t0 = performance.now(); performance.now() - t0 < 4000;) {
          await nextRender();
          if (map.areTilesLoaded()) break;
          await sleep(60);
        }
        names.push(nearestNames([pt])[0]);
      }
    } finally {
      map.jumpTo(cam);
      emit('names', { names });
    }
  }
  async function snapshot(width) {
    const c = map.getCanvas();
    const r0 = map.getPixelRatio();
    try {
      map.setPixelRatio(Math.max(r0, width / c.clientWidth));
      for (let t0 = performance.now(); performance.now() - t0 < 6000;) {
        await nextRender();
        if (map.areTilesLoaded()) break;
        await sleep(60);
      }
      // Se copia al terminar de dibujar (sin preserveDrawingBuffer, después ya está borrado)
      const url = await new Promise((r) => { map.once('render', () => r(c.toDataURL('image/png'))); map.triggerRepaint(); });
      const b64 = url.split(',')[1] || '';
      const size = 256 * 1024, n = Math.ceil(b64.length / size);
      for (let i = 0; i < n; i++) emit('snapChunk', { i, n, data: b64.slice(i * size, (i + 1) * size) });
      emit('snapEnd', { chunks: n, w: c.width, h: c.height });
    } catch (e) {
      emit('snapError', { message: String(e && e.message ? e.message : e) });
    } finally {
      map.setPixelRatio(r0);
    }
  }
  // Capas que en el video solo estorban: cambian de lugar al girar la cámara y parpadean
  // Las fotos también: una tomada en casa mostraría el inicio que el usuario recortó
  const VIDEO_HIDE = ['poi-icons', 'road-names', 'places-minor', 'regions-line', 'track', 'track-casing', 'track-ends', 'track-ends-label', 'track-hidden', 'photos', 'found-ring', 'found-dot', 'found-label'];
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const nextRender = () => new Promise((r) => { map.once('render', r); map.triggerRepaint(); });
  const smooth = (x) => x * x * (3 - 2 * x);
  async function videoCodec() {
    if (!window.VideoEncoder || !window.Mp4Muxer) return null;
    for (const codec of ['avc1.640028', 'avc1.4d0028', 'avc1.42002a', 'avc1.42001f']) {
      const cfg = { codec, width: VIDEO.w, height: VIDEO.h, bitrate: 4e6, framerate: VIDEO.fps };
      try { if ((await VideoEncoder.isConfigSupported(cfg)).supported) return cfg; } catch (_) { /* siguiente */ }
    }
    return null;
  }
  // Un cartel redondeado ("INICIO", "FIN") con una punta hacia el punto
  function pill(g, x, y, text, color, maxY = VIDEO.h - 200) {
    // Fuera del cuadro o sobre la franja del título, no se dibuja
    if (x < -60 || x > VIDEO.w + 60 || y < 60 || y > maxY) return;
    g.font = 'bold 30px sans-serif';
    const w = g.measureText(text).width + 36, h = 50, top = y - h - 26;
    g.fillStyle = 'rgba(0,0,0,0.25)'; g.beginPath(); g.roundRect(x - w / 2 + 2, top + 3, w, h, 25); g.fill();
    g.fillStyle = color; g.beginPath(); g.roundRect(x - w / 2, top, w, h, 25); g.fill();
    g.beginPath(); g.moveTo(x - 11, top + h - 1); g.lineTo(x + 11, top + h - 1); g.lineTo(x, top + h + 14); g.closePath(); g.fill();
    g.fillStyle = '#ffffff'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(text, x, top + h / 2 + 1);
    g.beginPath(); g.arc(x, y, 11, 0, Math.PI * 2); g.fillStyle = color; g.fill();
    g.lineWidth = 4; g.strokeStyle = '#ffffff'; g.stroke();
  }
  // opts (todas opcionales): base ('topo', 'sat', 'relief', 'night'), streets (nombres de las calles
  // a ~200 m del recorrido), trails, contours, buildings (edificios 3D), caption (título y cifras),
  // fast (más rápido), insetTop/insetBottom (espacio que tapa Flutter sobre la vista previa)
  async function flyTrack(segments, record, caption, opts = {}) {
    stopFly();
    const coords = segments.flat();
    if (coords.length < 2) return;
    const cfg = await videoCodec();
    if (!cfg) { emit('videoError', { message: 'Este teléfono no puede generar video del mapa.' }); return; }
    const job = (videoJob = { cancelled: false });
    // Distancias a lo largo del recorrido
    const d = [0];
    for (let i = 1; i < coords.length; i++) {
      const [a, b] = [coords[i - 1], coords[i]];
      const k = Math.cos(b[1] * Math.PI / 180);
      d.push(d[i - 1] + Math.hypot((b[0] - a[0]) * k, b[1] - a[1]) * 111320);
    }
    const total = d[d.length - 1];
    const at = (m) => {
      let i = 1;
      while (i < d.length - 1 && d[i] < m) i++;
      const t = (m - d[i - 1]) / Math.max(1e-6, d[i] - d[i - 1]);
      return [coords[i - 1][0] + (coords[i][0] - coords[i - 1][0]) * t, coords[i - 1][1] + (coords[i][1] - coords[i - 1][1]) * t];
    };
    const zoom = total < 2000 ? 15.6 : total < 8000 ? 14.6 : 13.6;
    const pitch = 60;
    const withCaption = opts.caption !== false; // título, cifras y barra de avance
    // Partes: 1 s quieto en el inicio, el vuelo (~3.5 s por km, 8–25 s; rápido: la mitad, 5–12 s) y
    // 4 s alejándose para ver todo (el 13 nov era ~6 s por km y se sentía lento)
    const fps = VIDEO.fps;
    const fast = !!opts.fast;
    const flySecs = fast ? Math.max(5, Math.min(12, total / 1000 * 1.75)) : Math.max(8, Math.min(25, total / 1000 * 3.5));
    const nIntro = Math.round((fast ? 0.6 : 1) * fps), nFly = Math.round(flySecs * fps);
    const nOutro = Math.round((fast ? 1.8 : 2.5) * fps), nHold = Math.round((fast ? 1 : 1.5) * fps);
    const N = nIntro + nFly + nOutro + nHold;

    // Estado del mapa durante el video (se restaura al final)
    const hide = [...VIDEO_HIDE];
    if (!opts.trails) hide.push('trails', 'tracks');
    if (!opts.contours) hide.push('contours', 'contour-labels');
    if (!opts.buildings) hide.push('buildings-3d');
    const showIds = [...(opts.streets ? ['video-streets'] : []), ...(opts.buildings ? ['buildings-3d'] : [])];
    const was = [...hide, ...showIds].map((id) => [id, map.getLayer(id) && map.getLayoutProperty(id, 'visibility')]);
    hide.forEach((id) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', 'none'));
    showIds.forEach((id) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', 'visible'));
    const prevBase = base;
    if (opts.base && opts.base !== base && BASE_LAYERS[opts.base]) setBase(opts.base);
    // Nombres de calles: solo el pedazo de cada calle que pasa a ~200 m (dos cuadras) del recorrido;
    // con el nombre de toda la calle, en una ciudad cuadriculada salían todas y en cualquier parte.
    // Se buscan en los mosaicos ya cargados; conforme avanza la cámara se cargan más y se suman
    let collectNames = () => {};
    const streets = [];
    if (opts.streets) {
      const cell = 90; // m; la celda del recorrido y dos alrededor ≈ 200 m
      const ky = 111320 / cell, kx = ky * Math.cos(coords[0][1] * Math.PI / 180);
      const isNear = (p) => near.has(`${Math.floor(p[0] * kx)},${Math.floor(p[1] * ky)}`);
      const near = new Set();
      for (let i = 0; i < coords.length; i++) {
        const a = coords[Math.max(0, i - 1)], b = coords[i];
        const steps = Math.max(1, Math.ceil((d[i] - d[Math.max(0, i - 1)]) / (cell / 2)));
        for (let s = 1; s <= steps; s++) {
          const x = Math.floor((a[0] + (b[0] - a[0]) * s / steps) * kx), y = Math.floor((a[1] + (b[1] - a[1]) * s / steps) * ky);
          for (let dx = -2; dx <= 2; dx++) for (let dy = -2; dy <= 2; dy++) near.add(`${x + dx},${y + dy}`);
        }
      }
      const seen = new Set();
      // Parte la calle (cada ~20 m) en pedazos seguidos que quedan cerca del recorrido
      const nearRuns = (line) => {
        const runs = [];
        let run = null;
        for (let i = 0; i < line.length; i++) {
          const pts = [line[i]];
          if (i > 0) {
            const [a, b] = [line[i - 1], line[i]];
            const m = Math.hypot((b[0] - a[0]) * kx, (b[1] - a[1]) * ky) * cell;
            const n = Math.min(200, Math.ceil(m / 20));
            pts.length = 0;
            for (let s = 1; s <= n; s++) pts.push([a[0] + (b[0] - a[0]) * s / n, a[1] + (b[1] - a[1]) * s / n]);
          }
          for (const p of pts) {
            if (isNear(p)) { if (!run) runs.push((run = [])); run.push(p); } else run = null;
          }
        }
        return runs.filter((r) => r.length >= 4); // menos de ~60 m no le cabe el nombre
      };
      collectNames = () => {
        let added = false;
        for (const f of map.querySourceFeatures('topo', { sourceLayer: 'transportation_name' })) {
          const name = f.properties && f.properties.name;
          if (!name) continue;
          const g = f.geometry;
          const lines = g.type === 'LineString' ? [g.coordinates] : g.type === 'MultiLineString' ? g.coordinates : [];
          for (const r of lines.flatMap(nearRuns)) {
            // El mismo pedazo llega de varios mosaicos y en cada consulta: se guarda una vez
            const k = `${name}|${r[0][0].toFixed(4)},${r[0][1].toFixed(4)}`;
            if (seen.has(k)) continue;
            seen.add(k);
            streets.push({ type: 'Feature', properties: { name }, geometry: { type: 'LineString', coordinates: r } });
            added = true;
          }
        }
        if (added) map.getSource('video-streets').setData({ type: 'FeatureCollection', features: streets });
      };
      // Mismos colores que los demás nombres (claros sobre satélite y noche)
      ['text-color', 'text-halo-color', 'text-halo-width'].forEach((p) => map.setPaintProperty('video-streets', p, map.getPaintProperty('road-names', p)));
    }
    const fade = map._fadeDuration;
    map._fadeDuration = 0; // sin fundido de etiquetas: se veía como parpadeo
    map.getSource('video-track').setData({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: coords } });
    const progress = (p) => {
      const q = Math.max(1e-6, Math.min(1, p));
      map.setPaintProperty('video-line', 'line-gradient', ['step', ['line-progress'], '#46eae5', q, 'rgba(70,234,229,0)']);
      map.setPaintProperty('video-casing', 'line-gradient', ['step', ['line-progress'], 'rgba(14,20,22,0.85)', q, 'rgba(14,20,22,0)']);
    };
    ['video-line', 'video-casing'].forEach((id) => map.setLayoutProperty(id, 'visibility', 'visible'));
    progress(0);
    if (!is3d) api.set3d(true);

    // Altura de la cámara: la del terreno, nunca 0 (0 = el relieve aún no cargó; la cámara quedaba
    // bajo el terreno y el video salía en blanco)
    let ground = 0;
    const setGround = (pt) => {
      if (!map.terrain) return;
      const el = map.terrain.getElevationForLngLatZoom(maplibregl.LngLat.convert(pt), map.transform.tileZoom);
      if (Number.isFinite(el) && el > 0) ground = el;
      if (ground > 0) map.transform.elevation = ground;
    };
    const noPad = { top: 0, bottom: 0, left: 0, right: 0 };
    let brg = bearing(coords[0], at(Math.min(total, 300)));
    const pose = (center, z, p, b) => { setGround(center); map.jumpTo({ center, zoom: z, pitch: p, bearing: b, padding: noPad }); };
    pose(coords[0], zoom, pitch, brg);
    // Espera a que cargue el inicio (relieve y mapa), máx 8 s
    for (let t0 = performance.now(); performance.now() - t0 < 8000;) {
      await nextRender();
      setGround(coords[0]);
      if (ground > 0 && map.areTilesLoaded()) break;
      await sleep(60);
    }
    pose(coords[0], zoom, pitch, brg);
    collectNames();

    // Vista final: todo el recorrido
    const bounds = coords.reduce((b, c) => b.extend(c), new maplibregl.LngLatBounds(coords[0], coords[0]));
    const src = map.getCanvas();
    const c = document.createElement('canvas');
    c.width = VIDEO.w; c.height = VIDEO.h;
    const g = c.getContext('2d');
    const dpr = src.width / src.clientWidth;
    // Recorte 9:16 al centro del mapa (sin padding, el centro de la cámara es el centro del lienzo)
    const cropW = Math.min(src.width, src.height * 9 / 16), cropH = cropW * 16 / 9;
    const sx = (src.width - cropW) / 2, sy = (src.height - cropH) / 2, scale = VIDEO.w / cropW;
    const toVideo = (pt) => { const q = map.project(pt); return [(q.x * dpr - sx) * scale, (q.y * dpr - sy) * scale]; };
    // Vista previa: el mismo cuadro que va al video (con el punto que avanza y los carteles), sobre
    // el mapa y entre lo que tapa Flutter arriba y abajo
    Object.assign(c.style, {
      position: 'fixed', left: '0', right: '0', top: `${opts.insetTop || 0}px`, bottom: `${opts.insetBottom || 0}px`,
      width: '100%', height: `calc(100% - ${(opts.insetTop || 0) + (opts.insetBottom || 0)}px)`,
      objectFit: 'contain', background: '#0e1416', zIndex: '5', pointerEvents: 'none',
    });
    const page = document.createElement('div');
    Object.assign(page.style, { position: 'fixed', inset: '0', background: '#0e1416', zIndex: '4', pointerEvents: 'none' });
    const maxY = withCaption ? VIDEO.h - 200 : VIDEO.h - 40;
    const draw = (state) => {
      g.drawImage(src, sx, sy, cropW, cropH, 0, 0, VIDEO.w, VIDEO.h);
      const [x0, y0] = toVideo(coords[0]);
      if (state.end) { const [x1, y1] = toVideo(coords[coords.length - 1]); pill(g, x1, y1, '🏁 FIN', '#d64545', maxY); }
      pill(g, x0, y0, 'INICIO', '#2f9e5f', maxY);
      if (!state.end) {
        const [hx, hy] = toVideo(state.head);
        g.beginPath(); g.arc(hx, hy, 22, 0, Math.PI * 2); g.fillStyle = 'rgba(70,234,229,0.35)'; g.fill();
        g.beginPath(); g.arc(hx, hy, 12, 0, Math.PI * 2); g.fillStyle = '#46eae5'; g.fill();
        g.lineWidth = 4; g.strokeStyle = '#ffffff'; g.stroke();
      }
      // Título, cifras y avance
      if (!withCaption) return;
      const band = g.createLinearGradient(0, VIDEO.h - 190, 0, VIDEO.h);
      band.addColorStop(0, 'rgba(14,20,22,0)'); band.addColorStop(1, 'rgba(14,20,22,0.88)');
      g.fillStyle = band; g.fillRect(0, VIDEO.h - 190, VIDEO.w, 190);
      g.textBaseline = 'alphabetic'; g.textAlign = 'left';
      if (caption) {
        g.fillStyle = '#ffffff'; g.font = 'bold 32px sans-serif'; g.fillText(caption.title, 32, VIDEO.h - 82);
        g.fillStyle = '#46eae5'; g.font = 'bold 24px sans-serif'; g.fillText(caption.detail, 32, VIDEO.h - 46);
      }
      g.textAlign = 'right'; g.fillStyle = 'rgba(255,255,255,0.75)'; g.font = 'bold 22px sans-serif';
      g.fillText(`${(state.m / 1000).toFixed(2)} km`, VIDEO.w - 32, VIDEO.h - 82);
      g.fillText('CRESTA', VIDEO.w - 32, VIDEO.h - 46);
      g.fillStyle = 'rgba(255,255,255,0.18)'; g.fillRect(0, VIDEO.h - 8, VIDEO.w, 8);
      g.fillStyle = '#46eae5'; g.fillRect(0, VIDEO.h - 8, VIDEO.w * state.m / total, 8);
    };

    const muxer = new Mp4Muxer.Muxer({ target: new Mp4Muxer.ArrayBufferTarget(), video: { codec: 'avc', width: VIDEO.w, height: VIDEO.h, frameRate: fps }, fastStart: 'in-memory' });
    let failed = null;
    const encoder = new VideoEncoder({ output: (chunk, meta) => muxer.addVideoChunk(chunk, meta), error: (e) => { failed = e; } });
    encoder.configure(cfg);
    let flyEnd = null; // última pose del vuelo, de donde parte el alejamiento
    let overview = null;
    try {
      for (let k = 0; k < N && !job.cancelled && !failed; k++) {
        let state;
        if (k < nIntro + nFly) {
          const f = k < nIntro ? 0 : smooth((k - nIntro) / (nFly - 1));
          const m = f * total;
          const head = at(m);
          const target = bearing(head, at(Math.min(total, m + 250)));
          brg += (((target - brg + 540) % 360) - 180) * 0.05;
          pose(head, zoom, pitch, brg);
          progress(m / total);
          state = { head, m, end: false };
          flyEnd = { center: head, zoom, pitch, bearing: brg };
        } else {
          if (!overview) {
            // Márgenes dentro del recorte 9:16 (lo de fuera del recorte no sale en el video): espacio para
            // los carteles arriba y la franja del título abajo. Antes eran fijos y sobraba mucho
            const mx = (src.width - cropW) / 2 / dpr, my = (src.height - cropH) / 2 / dpr;
            const cam = map.cameraForBounds(bounds, { padding: { top: my + 70, bottom: my + (withCaption ? 120 : 40), left: mx + 30, right: mx + 30 }, bearing: brg, pitch: 45 });
            // (MapLibre 4 no cuenta la inclinación al calcularlo: un poco más lejos para que quepa)
            overview = { center: cam.center.toArray(), zoom: Math.min(cam.zoom - 0.15, zoom), pitch: 45, bearing: brg };
          }
          const f = smooth(Math.min(1, (k - nIntro - nFly) / nOutro));
          const lerp = (a, b) => a + (b - a) * f;
          pose([lerp(flyEnd.center[0], overview.center[0]), lerp(flyEnd.center[1], overview.center[1])],
            lerp(flyEnd.zoom, overview.zoom), lerp(flyEnd.pitch, overview.pitch), flyEnd.bearing);
          progress(1);
          state = { head: coords[coords.length - 1], m: total, end: true };
        }
        // Espera a que cargue lo visible (máx 2.5 s por cuadro) y copia el cuadro al terminar de dibujarlo
        for (let t0 = performance.now(); !map.areTilesLoaded() && performance.now() - t0 < 2500;) { await nextRender(); await sleep(30); }
        await new Promise((r) => { map.once('render', () => { draw(state); r(); }); map.triggerRepaint(); });
        if (k === 0) document.body.append(page, c);
        const frame = new VideoFrame(c, { timestamp: Math.round(k * 1e6 / fps), duration: Math.round(1e6 / fps) });
        encoder.encode(frame, { keyFrame: k % (fps * 2) === 0 });
        frame.close();
        while (encoder.encodeQueueSize > 4) await sleep(5);
        if (k % 10 === 0) emit('videoProgress', { p: +(k / N).toFixed(3) });
        if (k % 15 === 0) collectNames();
      }
      await encoder.flush();
      if (failed) throw failed;
      if (job.cancelled) return;
      muxer.finalize();
      emit('videoProgress', { p: 1 });
      sendVideo(new Blob([muxer.target.buffer], { type: 'video/mp4' }), 'video/mp4');
    } catch (e) {
      emit('videoError', { message: `No se pudo generar el video: ${e && e.message ? e.message : e}` });
    } finally {
      try { encoder.close(); } catch (_) { /* ya cerrado */ }
      page.remove(); c.remove();
      if (opts.streets) map.getSource('video-streets').setData(empty);
      if (base !== prevBase) setBase(prevBase);
      ['video-line', 'video-casing'].forEach((id) => map.setLayoutProperty(id, 'visibility', 'none'));
      was.forEach(([id, v]) => map.getLayer(id) && map.setLayoutProperty(id, 'visibility', v || 'visible'));
      map._fadeDuration = fade;
      if (videoJob === job) videoJob = null;
      api.setTrack(segments, true);
      fitBounds(bounds.getWest(), bounds.getSouth(), bounds.getEast(), bounds.getNorth());
    }
  }
  function cancelVideo() { if (videoJob) videoJob.cancelled = true; }

  // Brújula: avisa a Flutter el giro del mapa (a lo sumo cada 120 ms y si cambió más de 1°)
  let lastBearing = 0, bearingTimer = null;
  map.on('move', () => {
    if (bearingTimer) return;
    bearingTimer = setTimeout(() => {
      bearingTimer = null;
      const b = map.getBearing();
      if (Math.abs(b - lastBearing) > 1 || (b === 0 && lastBearing !== 0)) {
        lastBearing = b;
        emit('bearing', { deg: Math.round(b) });
      }
    }, 120);
  });

  // Seguir la posición mientras se graba; si el usuario mueve el mapa, se deja de seguir
  let following = false;
  map.on('dragstart', () => {
    stopFly();
    if (following) { following = false; emit('followOff'); }
  });
  map.on('moveend', () => {
    const b = map.getBounds();
    emit('moveEnd', { zoom: map.getZoom(), bounds: [b.getWest(), b.getSouth(), b.getEast(), b.getNorth()] });
  });

  const cursorEl = document.createElement('div');
  cursorEl.className = 'cursor-mk';
  const cursor = new maplibregl.Marker({ element: cursorEl });
  const showCursorAt = (pt) => cursor.setLngLat(pt).addTo(map);

  let me = null;
  const memberMarkers = new Map();

  // --- Planificador: ajuste a senderos con lo que hay en el mapa visible. Funciona sin conexión:
  // usa los mosaicos vectoriales ya cargados, que salen de las zonas descargadas.
  const SNAP_CLASSES = ['path', 'track', 'service', 'minor', 'tertiary', 'secondary', 'primary', 'trunk'];
  const metersBetween = (a, b) => {
    const x = toRad(b[0] - a[0]) * Math.cos(toRad((a[1] + b[1]) / 2));
    const y = toRad(b[1] - a[1]);
    return Math.hypot(x, y) * 6371000;
  };
  /// Camino más corto por senderos entre a y b, o null si no hay o están a más de 250 m de uno.
  function snapLeg(a, b) {
    if (map.getZoom() < 12.5) return null; // con poco zoom los mosaicos no traen los senderos
    const feats = map.querySourceFeatures('topo', { sourceLayer: 'transportation', filter: ['match', ['get', 'class'], SNAP_CLASSES, true, false] });
    // Los mosaicos cortan las líneas en sus bordes: redondear a ~1 m une los extremos que coinciden
    const key = (c) => `${Math.round(c[0] * 1e5)},${Math.round(c[1] * 1e5)}`;
    const nodes = new Map();
    const node = (c) => {
      const k = key(c);
      let n = nodes.get(k);
      if (!n) { n = { c, edges: [] }; nodes.set(k, n); }
      return n;
    };
    const ends = [];
    for (const f of feats) {
      const g = f.geometry;
      const lines = g.type === 'LineString' ? [g.coordinates] : g.type === 'MultiLineString' ? g.coordinates : [];
      for (const line of lines) {
        for (let i = 1; i < line.length; i++) {
          const p = node(line[i - 1]), q = node(line[i]);
          if (p === q) continue;
          const w = metersBetween(p.c, q.c);
          p.edges.push([q, w]); q.edges.push([p, w]);
        }
        if (line.length > 1) ends.push(node(line[0]), node(line[line.length - 1]));
      }
    }
    // Los mosaicos simplifican las líneas y a veces un sendero "llega" a otro sin compartir
    // vértice: se une cada extremo suelto con el vértice más cercano a menos de 20 m.
    const cell = (c) => `${Math.floor(c[0] * 2000)},${Math.floor(c[1] * 2000)}`; // ~50 m
    const grid = new Map();
    for (const n of nodes.values()) {
      const k = cell(n.c);
      if (!grid.has(k)) grid.set(k, []);
      grid.get(k).push(n);
    }
    for (const e of ends) {
      if (e.edges.length > 1) continue; // ya es un cruce
      const [cx, cy] = cell(e.c).split(',').map(Number);
      let best = null, bd = 20;
      for (let dx = -1; dx <= 1; dx++) for (let dy = -1; dy <= 1; dy++) {
        for (const n of grid.get(`${cx + dx},${cy + dy}`) || []) {
          if (n === e || e.edges.some(([m]) => m === n)) continue;
          const d = metersBetween(e.c, n.c);
          if (d < bd) { bd = d; best = n; }
        }
      }
      if (best) { e.edges.push([best, bd]); best.edges.push([e, bd]); }
    }
    const nearest = (pt) => {
      let best = null, bd = 250;
      for (const n of nodes.values()) {
        const d = metersBetween(pt, n.c);
        if (d < bd) { bd = d; best = n; }
      }
      return best;
    };
    const from = nearest(a), to = nearest(b);
    if (!from || !to) return null;
    // Dijkstra con un montículo binario sencillo
    const dist = new Map([[from, 0]]), prev = new Map(), heap = [[0, from]];
    const push = (item) => {
      heap.push(item);
      for (let i = heap.length - 1; i > 0;) {
        const p = (i - 1) >> 1;
        if (heap[p][0] <= heap[i][0]) break;
        [heap[p], heap[i]] = [heap[i], heap[p]]; i = p;
      }
    };
    const pop = () => {
      const top = heap[0], last = heap.pop();
      if (heap.length) {
        heap[0] = last;
        for (let i = 0; ;) {
          const l = 2 * i + 1, r = l + 1;
          let m = i;
          if (l < heap.length && heap[l][0] < heap[m][0]) m = l;
          if (r < heap.length && heap[r][0] < heap[m][0]) m = r;
          if (m === i) break;
          [heap[m], heap[i]] = [heap[i], heap[m]]; i = m;
        }
      }
      return top;
    };
    while (heap.length) {
      const [d, n] = pop();
      if (n === to) break;
      if (d > (dist.get(n) ?? Infinity)) continue;
      for (const [m, w] of n.edges) {
        const nd = d + w;
        if (nd < (dist.get(m) ?? Infinity)) { dist.set(m, nd); prev.set(m, n); push([nd, m]); }
      }
    }
    if (from !== to && !prev.has(to)) return null;
    const path = [];
    for (let n = to; n; n = prev.get(n)) path.push(n.c);
    path.reverse();
    return [a, ...path, b];
  }

  let planMode = false;
  map.on('click', (e) => { if (planMode) emit('mapTap', { lng: e.lngLat.lng, lat: e.lngLat.lat }); });
  map.on('click', 'photos', (e) => { if (!planMode && e.features.length) emit('photoTap', { id: e.features[0].properties.id }); });
  const pointFeature = (c, props) => ({ type: 'Feature', properties: props, geometry: { type: 'Point', coordinates: c } });

  // --- API pública para Flutter
  const api = {
    setPadding(p) { padding = p; },
    setLayer,
    setLayers(states) { Object.entries(states).forEach(([id, on]) => setLayer(id, on)); },
    setBase,
    set3d(on) {
      is3d = on;
      whenReady(() => map.setTerrain(on ? { source: 'dem', exaggeration } : null));
      map.easeTo({ pitch: on ? 60 : 0, bearing: on ? map.getBearing() : 0, duration: ms(900) });
    },
    setExaggeration(x) {
      exaggeration = x;
      if (is3d) whenReady(() => map.setTerrain({ source: 'dem', exaggeration }));
    },
    /// Modo para elegir una zona: vista cenital, sin rotar, para que el recuadro sea un rectángulo real.
    setPickerMode(on) {
      if (on) { api.set3d(false); map.dragRotate.disable(); map.touchZoomRotate.disableRotation(); }
      else { map.dragRotate.enable(); map.touchZoomRotate.enableRotation(); }
    },
    /// Coordenadas [oeste, sur, este, norte] de un rectángulo de la pantalla (en píxeles CSS).
    boundsOfRect(left, top, right, bottom) {
      const a = map.unproject([left, top]);
      const b = map.unproject([right, bottom]);
      return [Math.min(a.lng, b.lng), Math.min(a.lat, b.lat), Math.max(a.lng, b.lng), Math.max(a.lat, b.lat)];
    },
    getView() {
      const c = map.getCenter();
      return { lng: c.lng, lat: c.lat, zoom: map.getZoom() };
    },
    fitBounds,
    setRoute(data) {
      route = data;
      // Con tramos (ruta guardada) cada uno lleva si sigue sendero; sin ellos (ruta de ejemplo) es uno solo
      const legs = data && data.legs && data.legs.length ? data.legs : data ? [{ coordinates: data.coordinates, snapped: true }] : [];
      whenReady(() => map.getSource('route').setData(data
        ? { type: 'FeatureCollection', features: legs.map((l) => ({ type: 'Feature', properties: { snapped: l.snapped }, geometry: { type: 'LineString', coordinates: l.coordinates } })) }
        : empty));
    },
    /// Rutas comparadas: lista de { coordinates: [[lng, lat], ...], color }; encuadra todas.
    setCompare(list) {
      whenReady(() => {
        map.getSource('compare').setData({
          type: 'FeatureCollection',
          features: list.map((r) => ({ type: 'Feature', properties: { color: r.color }, geometry: { type: 'LineString', coordinates: r.coordinates } })),
        });
        if (!list.length) return;
        const b = new maplibregl.LngLatBounds(list[0].coordinates[0], list[0].coordinates[0]);
        list.forEach((r) => r.coordinates.forEach((pt) => b.extend(pt)));
        map.fitBounds(b, { padding, pitch: 0, bearing: 0, duration: ms(1200) });
      });
    },
    /// Tramos del recorrido: lista de listas de [lng, lat] (una por cada tramo entre pausas).
    // Partes del recorrido que se ocultan al compartir (cada una, lista de [lng, lat])
    setHidden(lines) {
      whenReady(() => map.getSource('track-hidden').setData({
        type: 'FeatureCollection',
        features: lines.filter((l) => l.length > 1).map((coordinates) => ({ type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates } })),
      }));
    },
    setTrack(segments, showEnd = false) {
      const all = segments.flat();
      whenReady(() => {
        map.getSource('track').setData({ type: 'Feature', properties: {}, geometry: { type: 'MultiLineString', coordinates: segments } });
        // Recorrido y ruta son teal: con recorrido, la ruta queda tenue debajo
        ['route', 'route-straight'].forEach((id) => map.getLayer(id) && map.setPaintProperty(id, 'line-opacity', all.length > 1 ? 0.45 : 1));
        const ends = all.length ? [pointFeature(all[0], { role: 'start' })] : [];
        if (showEnd && all.length > 1) ends.push(pointFeature(all[all.length - 1], { role: 'end' }));
        map.getSource('track-ends').setData({ type: 'FeatureCollection', features: ends });
      });
    },
    setRegions(list) {
      whenReady(() => map.getSource('regions').setData({
        type: 'FeatureCollection',
        features: list.map((r) => ({ type: 'Feature', properties: { name: r.name, complete: r.complete }, geometry: { type: 'Polygon', coordinates: bboxPolygon(r.bbox) } })),
      }));
    },
    setCivil(civil) {
      const c = civil.volcano.center;
      const rings = [...civil.zones].sort((a, b) => a.radiusKm - b.radiusKm);
      const p = civil.ashPlume;
      whenReady(() => {
        map.getSource('zones').setData({ type: 'FeatureCollection', features: rings.map((z, i) => ({
          type: 'Feature', properties: { level: z.level, color: z.color },
          geometry: { type: 'Polygon', coordinates: i === 0 ? [circle(c, z.radiusKm)] : [circle(c, z.radiusKm), circle(c, rings[i - 1].radiusKm).reverse()] },
        })) });
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
      ['shelters', 'reports'].forEach((id) => setLayer(id, !!visible[id]));
    },
    /// En modo planificar cada toque en el mapa se envía a Flutter como 'mapTap'.
    setPlanMode(on) {
      planMode = on;
      map.getCanvas().style.cursor = on ? 'crosshair' : '';
      if (on) map.doubleClickZoom.disable(); else map.doubleClickZoom.enable();
    },
    snapLeg(a, b) { return snapLeg(a, b); },
    /// Lo que se está planeando: { legs: [[[lng, lat]…]…], snapped: [bool…], waypoints: [[lng, lat]…] }
    setPlan(plan) {
      whenReady(() => {
        map.getSource('plan').setData(!plan ? empty : {
          type: 'FeatureCollection',
          features: plan.legs.map((leg, i) => ({ type: 'Feature', properties: { snapped: !!plan.snapped[i] }, geometry: { type: 'LineString', coordinates: leg } })),
        });
        const w = plan ? plan.waypoints : [];
        map.getSource('plan-pts').setData({
          type: 'FeatureCollection',
          features: w.map((c, i) => pointFeature(c, { role: i === 0 ? 'start' : i === w.length - 1 ? 'end' : 'via' })),
        });
      });
    },
    /// Puntos de interés: [{ kind, name, at: [lng, lat] }]
    setPois(list) {
      whenReady(() => map.getSource('pois').setData({
        type: 'FeatureCollection',
        features: (list || []).map((p) => pointFeature(p.at, { kind: p.kind, name: p.name })),
      }));
    },
    /// Fotos del recorrido: [{ id, at: [lng, lat] }]
    setPhotos(list) {
      whenReady(() => map.getSource('photos').setData({
        type: 'FeatureCollection',
        features: (list || []).map((p) => pointFeature(p.at, { id: p.id })),
      }));
    },
    /// Lugar encontrado: { name, at: [lng, lat] } o null para quitarlo.
    setFound(p) {
      whenReady(() => map.getSource('found').setData(p ? { type: 'FeatureCollection', features: [pointFeature(p.at, { name: p.name })] } : empty));
    },
    resetNorth() { map.easeTo({ essential: true, bearing: 0, padding, duration: ms(500) }); },
    fitRoute,
    flyRoute,
    flyTrack,
    snapshot,
    setClean,
    nearestNames,
    findNames,
    cancelVideo,
    stopFly,
    flyTo(lng, lat, zoom = 13.5, pitch = 55, bearingDeg) {
      stopFly();
      // Con padding el punto queda al centro de la parte visible (no tapada por paneles).
      // essential: con animaciones reducidas, MapLibre cambia flyTo por un salto que descarta el padding
      map.flyTo({ essential: true, center: [lng, lat], zoom, padding, pitch: is3d ? (pitch ?? map.getPitch()) : 0, ...(bearingDeg == null ? {} : { bearing: bearingDeg }), duration: ms(1600) });
    },
    // Sin animación (p. ej. al abrir el mapa ya en tu posición); con pitch, también la inclinación
    jumpTo(lng, lat, zoom, pitch) { map.jumpTo({ center: [lng, lat], zoom, padding, ...(pitch == null ? {} : { pitch: is3d ? pitch : 0 }) }); },
    // Para pruebas: grados de pendiente del relieve en un punto (null si no hay relieve)
    async slopeAt(lng, lat, z = 12) {
      const n = 2 ** z, xf = (lng + 180) / 360 * n;
      const yf = (1 - Math.log(Math.tan(lat * Math.PI / 180) + 1 / Math.cos(lat * Math.PI / 180)) / Math.PI) / 2 * n;
      const g = await slopeGrid(z, Math.floor(xf), Math.floor(yf));
      return g && Math.round(g.deg[Math.floor((yf % 1) * g.n) * g.n + Math.floor((xf % 1) * g.n)] * 10) / 10;
    },
    // Para pruebas (tool/dev/cdp.py): estado de carga del mapa y del relieve
    debugState() {
      const t = map.transform;
      return { flying: !!flying, recording: !!videoJob, terrain: !!map.terrain, tilesLoaded: map.areTilesLoaded(),
        dem: map.isSourceLoaded('dem'), topo: map.isSourceLoaded('topo'), elevation: Math.round(t.elevation),
        zoom: +map.getZoom().toFixed(2), center: map.getCenter().toArray().map((x) => +x.toFixed(4)),
        cameraAlt: Math.round(map.transform.getCameraAltitude ? map.transform.getCameraAltitude() : -1),
        tileZoom: t.tileZoom,
        eTile: map.terrain && Math.round(map.terrain.getElevationForLngLatZoom(map.getCenter(), t.tileZoom)),
        e12: map.terrain && Math.round(map.terrain.getElevationForLngLatZoom(map.getCenter(), 12)),
        e10: map.terrain && Math.round(map.terrain.getElevationForLngLatZoom(map.getCenter(), 10)),
        demTiles: map.terrain ? Object.keys(map.terrain.sourceCache.sourceCache._tiles || {}).length : -1 };
    },
    // Para pruebas (tool/dev/cdp.py): dónde está la cámara y dónde se dibuja tu posición
    cameraInfo() {
      const c = map.getCenter(), m = me && map.project(me.getLngLat());
      return { center: [c.lng, c.lat], zoom: map.getZoom(), pitch: map.getPitch(), padding: map.getPadding(), padVar: padding,
        me: m && [Math.round(m.x), Math.round(m.y)], meLngLat: me && me.getLngLat().toArray(), size: [innerWidth, innerHeight], terrain: !!map.getTerrain() };
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
      if (following && !flying) map.easeTo({ essential: true, center: [lng, lat], padding, duration: ms(600) });
    },
    setFollow(on, zoom) {
      following = on;
      if (on && me) map.easeTo({ essential: true, center: me.getLngLat(), padding, ...(zoom ? { zoom } : {}), duration: ms(800) });
    },
    pulseReport(id) {
      const el = document.querySelector(`.report[data-id="${id}"]`);
      if (!el) return;
      el.classList.remove('pulse'); void el.offsetWidth; el.classList.add('pulse');
    },
  };
  window.cresta = api;

  // Los íconos de lugares se dibujan la primera vez que el mapa los pide
  map.on('styleimagemissing', (e) => {
    const def = POI_ICONS[e.id.replace(/^poi-/, '')];
    if (!def || map.hasImage(e.id)) return;
    const { image, pixelRatio } = poiImage(def[0], def[1]);
    map.addImage(e.id, image, { pixelRatio });
  });

  map.on('load', () => {
    // Créditos plegados al inicio (botón ⓘ) para no tapar los controles
    document.querySelector('.maplibregl-ctrl-attrib')?.classList.remove('maplibregl-compact-show');
    emit('ready');
  });
  // Con relieve, MapLibre toma la altura del destino al empezar un vuelo. Si su relieve aún no había
  // cargado (otro lugar, o recién encendido el 3D), la cámara queda a la altura del sitio anterior y
  // lo que está "al centro" se dibuja fuera de la pantalla. Al terminar de cargar, se corrige la
  // altura sin mover el centro.
  map.on('moveend', () => {
    if (!map.terrain) return;
    map.once('idle', () => {
      if (!map.terrain || map.isMoving()) return;
      const c = map.getCenter();
      const elevation = map.terrain.getElevationForLngLatZoom(c, map.transform.tileZoom);
      if (Math.abs(elevation - map.transform.elevation) < 5) return;
      map.transform.elevation = elevation;
      map.jumpTo({ center: c }); // redibuja y vuelve a colocar los marcadores
    });
  });
  map.on('error', (e) => {
    const message = String(e.error && e.error.message);
    // Los mosaicos que faltan sin conexión son normales; solo se reportan los demás errores
    if (!/tiles\/|204|Failed to fetch|AJAXError|sin relieve/.test(message)) emit('error', { message });
  });
})();
