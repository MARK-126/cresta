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

  // --- Estilo. Capas base (cambian con el mapa base) y capas superpuestas (las enciende el usuario).
  const C = {
    land: '#f2efe6', wood: '#cfe1bd', grass: '#e3ebcb', rock: '#e2ddd5', ice: '#fbfdff', sand: '#efe5c6', wetland: '#d3e6df',
    residential: '#e9e2d8', water: '#a8cbe6', waterway: '#7eafd9', contour: '#a9825a', road: '#ffffff', roadCase: '#c9c1b6',
    major: '#f3c56d', track: '#8a6236', path: '#c4342c', label: '#2a2a28', halo: 'rgba(255,255,255,0.9)',
  };
  const empty = { type: 'FeatureCollection', features: [] };
  const font = (w) => [w === 'bold' ? 'Noto Sans Bold' : w === 'italic' ? 'Noto Sans Italic' : 'Noto Sans Regular'];
  const roadClass = (...c) => ['match', ['get', 'class'], c, true, false];

  const BASE_LAYERS = {
    topo: ['bg-topo', 'landcover', 'landuse', 'park', 'water', 'waterway', 'buildings'],
    sat: ['sat'],
    relief: ['bg-relief', 'water', 'waterway'],
  };

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
        route: { type: 'geojson', data: empty },
        track: { type: 'geojson', data: empty },
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
        { id: 'regions-line', type: 'line', source: 'regions', paint: { 'line-color': ['case', ['get', 'complete'], '#2e8b57', '#e07a10'], 'line-width': 2, 'line-dasharray': [4, 2] } },
        { id: 'route-casing', type: 'line', source: 'route', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#ffffff', 'line-width': 6.5, 'line-opacity': 0.85 } },
        { id: 'route', type: 'line', source: 'route', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#d0245a', 'line-width': 3.5 } },
        // Recorrido grabado (azul, encima de la ruta planeada)
        { id: 'track-casing', type: 'line', source: 'track', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#ffffff', 'line-width': 7, 'line-opacity': 0.9 } },
        { id: 'track', type: 'line', source: 'track', layout: { 'line-join': 'round', 'line-cap': 'round' }, paint: { 'line-color': '#1f6fd6', 'line-width': 4 } },
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
        { id: 'places', type: 'symbol', source: 'topo', 'source-layer': 'place', filter: roadClass('city', 'town', 'village', 'hamlet'), layout: {
          'text-field': ['get', 'name'], 'text-font': font('bold'),
          'text-size': ['match', ['get', 'class'], 'city', 15, 'town', 13, 'village', 12, 11] },
          paint: { 'text-color': C.label, 'text-halo-color': C.halo, 'text-halo-width': 1.6 } },
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
    route: { layers: ['route', 'route-casing'] },
    track: { layers: ['track', 'track-casing'] },
    trails: { layers: ['trails', 'tracks'] },
    contours: { layers: ['contours', 'contour-labels'] },
    labels: { layers: ['peaks', 'peaks-dot', 'places', 'water-names'] },
    hillshade: { layers: ['hillshade'] },
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

  function setBase(next) {
    base = next;
    whenReady(() => {
      const all = new Set(Object.values(BASE_LAYERS).flat());
      all.forEach((l) => show(l, BASE_LAYERS[base].includes(l)));
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
      whenReady(() => map.getSource('route').setData(data
        ? { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: data.coordinates } }
        : empty));
    },
    /// Tramos del recorrido: lista de listas de [lng, lat] (una por cada tramo entre pausas).
    setTrack(segments) {
      whenReady(() => map.getSource('track').setData({ type: 'Feature', properties: {}, geometry: { type: 'MultiLineString', coordinates: segments } }));
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
    fitRoute,
    flyRoute,
    stopFly,
    flyTo(lng, lat, zoom = 13.5, pitch = 55, bearingDeg) {
      stopFly();
      // Con padding el punto queda al centro de la parte visible (no tapada por paneles)
      map.flyTo({ center: [lng, lat], zoom, padding, pitch: is3d ? pitch : 0, ...(bearingDeg == null ? {} : { bearing: bearingDeg }), duration: ms(1600) });
    },
    jumpTo(lng, lat, zoom) { map.jumpTo({ center: [lng, lat], zoom }); },
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
      if (following && !flying) map.easeTo({ center: [lng, lat], padding, duration: ms(600) });
    },
    setFollow(on, zoom) {
      following = on;
      if (on && me) map.easeTo({ center: me.getLngLat(), padding, ...(zoom ? { zoom } : {}), duration: ms(800) });
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
  map.on('error', (e) => {
    const message = String(e.error && e.error.message);
    // Los mosaicos que faltan sin conexión son normales; solo se reportan los demás errores
    if (!/tiles\/|204|Failed to fetch|AJAXError/.test(message)) emit('error', { message });
  });
})();
