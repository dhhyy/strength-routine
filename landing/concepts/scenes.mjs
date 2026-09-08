import * as THREE from './vendor/three.module.min.js';

// Illustrative geometry only. DOM labels, keyboard controls and fallback belong to the host.
export async function createScene(host, { mode = 'load', onSelect = () => {}, reducedMotion = false } = {}) {
  const initial = { load: { weight: 60 }, atlas: { selected: 0 }, schedule: { days: [0, 2, 4] }, session: { completed: 0, completedSets: [false, false] }, insights: { applied: false } };
  if (!host || !initial[mode]) throw new TypeError('A scene host and a supported mode are required.');
  let state = structuredClone(initial[mode]), renderer, disposed = false, lost = false, visible = true, rendered = false;
  let frame = 0, width = 0, height = 0, pixelRatio = 1, pointer = null, lastTime = 0;
  const geometries = new Set(), materials = new Set(), tweens = [], targets = [];
  const scene = new THREE.Scene(), model = new THREE.Group();
  const camera = new THREE.OrthographicCamera(-5, 5, 5, -5, .1, 70);
  const raycaster = new THREE.Raycaster(), mouse = new THREE.Vector2();
  const css = getComputedStyle(host), palette = {};
  const report = error => {
    host.dataset.sceneReady = 'false';
    host.dispatchEvent(new CustomEvent('scene-error', { bubbles: true, detail: { mode, message: error.message || String(error) } }));
  };
  for (const name of ['bg', 'bg-lift', 'ink', 'muted', 'accent', 'good', 'hair-strong', 'cta-ink']) {
    let value = css.getPropertyValue(`--${name}`).trim(), alpha = 1;
    if (!value) { const error = new Error(`Missing scene color token --${name}`); report(error); throw error; }
    // THREE.Color ignores CSS alpha; retain the authored alpha separately.
    if (/^#[\da-f]{8}$/i.test(value)) { alpha = parseInt(value.slice(7), 16) / 255; value = value.slice(0, 7); }
    if (/^#[\da-f]{4}$/i.test(value)) { alpha = parseInt(value[4] + value[4], 16) / 255; value = value.slice(0, 4); }
    palette[name] = { color: new THREE.Color(value), alpha };
  }
  const geometry = value => { geometries.add(value); return value; };
  const material = (token, props = {}) => {
    const value = new THREE.MeshStandardMaterial({ color: palette[token].color, opacity: palette[token].alpha,
      transparent: palette[token].alpha < 1, roughness: .38, metalness: .3, ...props });
    materials.add(value); return value;
  };
  const mesh = (geo, mat, parent = model, x = 0, y = 0, z = 0) => {
    const value = new THREE.Mesh(geometry(geo), mat); value.position.set(x, y, z);
    value.castShadow = value.receiveShadow = true; parent.add(value); return value;
  };
  const box = (w, h, d, mat, parent, x, y, z) => mesh(new THREE.BoxGeometry(w, h, d), mat, parent, x, y, z);
  const steel = material('ink', { metalness: .72, roughness: .22 });
  const dark = material('bg-lift', { metalness: .48 });
  const muted = material('muted'), ink = material('ink');
  const accent = material('accent', { emissive: palette.accent.color, emissiveIntensity: .15 });
  const good = material('good', { emissive: palette.good.color, emissiveIntensity: .12 });
  const inset = material('cta-ink');
  const edgeMaterial = new THREE.LineBasicMaterial({ color: palette['hair-strong'].color,
    opacity: palette['hair-strong'].alpha, transparent: true }); materials.add(edgeMaterial);
  const outline = object => {
    const edges = new THREE.LineSegments(geometry(new THREE.EdgesGeometry(object.geometry)), edgeMaterial);
    object.add(edges); return object;
  };
  const tween = (object, key, value) => {
    const old = tweens.findIndex(t => t.object === object && t.key === key);
    if (old >= 0) tweens.splice(old, 1);
    if (reducedMotion) object[key] = value; else tweens.push({ object, key, value });
  };
  const cylinder = (r, length, mat, parent, x, y, z) => mesh(new THREE.CylinderGeometry(r, r, length, 48), mat, parent, x, y, z);
  const clearGeometry = group => {
    group.traverse(child => { if (child.geometry) { child.geometry.dispose(); geometries.delete(child.geometry); } });
    group.clear();
  };
  let apply;
  try {
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'low-power' });
    renderer.setClearColor(palette.bg.color); renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.2;
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    scene.add(model, new THREE.HemisphereLight(palette.ink.color, palette['bg-lift'].color, 2.1));
    const key = new THREE.DirectionalLight(palette.ink.color, 4); key.position.set(-3, 7, 6); key.castShadow = true;
    key.shadow.mapSize.set(1024, 1024); Object.assign(key.shadow.camera, { left: -7, right: 7, top: 7, bottom: -7, near: .1, far: 25 });
    key.shadow.normalBias = .035; scene.add(key);
    const rim = new THREE.DirectionalLight(palette.accent.color, 2.2); rim.position.set(4, 4, -5); scene.add(rim);
    const fill = new THREE.DirectionalLight(palette.ink.color, 1.5); fill.position.set(5, 3, 4); scene.add(fill);
    const cameraPositions = { load: [3, 6, 11], atlas: [3, 5, 12], schedule: [5, 9, 11], session: [3, 4.8, 12], insights: [0, 3.8, 12] };
    camera.position.set(...cameraPositions[mode]); camera.lookAt(0, mode === 'insights' ? 1.5 : 1.1, 0);
    const line = (from, to) => {
      const value = new THREE.Line(geometry(new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(...from), new THREE.Vector3(...to)])), edgeMaterial); model.add(value);
    };
    if (mode === 'load') {
      // The metal turntable belongs only to the barbell scene.
      cylinder(5, .16, dark, model, 0, -.14, 0);
      const ring = mesh(new THREE.TorusGeometry(4.88, .016, 8, 96), accent, model, 0, -.045, 0); ring.rotation.x = Math.PI / 2;
      for (let n = -4; n <= 4; n++) {
        const extent = Math.sqrt(25 - n * n); line([-extent, -.05, n], [extent, -.05, n]);
      }
    } else if (mode === 'atlas') {
      // A low exhibition shelf, with enough depth for the selected panel to advance.
      outline(box(9.25, .22, 3.9, dark, model, 0, -.16, -.35));
      box(9, .025, .035, accent, model, 0, -.035, 1.56);
    } else if (mode === 'schedule') {
      // The grid follows exactly seven weekday columns and four week rows.
      outline(box(8.05, .08, 5.12, inset, model, 0, -.11, 0));
      for (let day = 0; day <= 7; day++) {
        const x = (day - 3.5) * 1.05; line([x, -.055, -2.32], [x, -.055, 2.32]);
      }
      for (let week = 0; week <= 4; week++) {
        const z = (week - 2) * 1.16; line([-3.675, -.055, z], [3.675, -.055, z]);
      }
    } else if (mode === 'session') {
      // Only contact shadows ground the independent floating record panels.
      const shadow = new THREE.ShadowMaterial({ color: palette.bg.color, opacity: .55 }); materials.add(shadow);
      const floor = mesh(new THREE.PlaneGeometry(8.4, 5.4), shadow, model, 0, -.2, 0);
      floor.rotation.x = -Math.PI / 2; floor.castShadow = false;
    } else {
      // Rectangular chart paper, with a common height reference behind all six bars.
      outline(box(8.8, .08, 3.2, inset, model, 0, -.1, .25));
      for (let column = 0; column <= 6; column++) {
        const x = (column - 3) * 1.3; line([x, -.055, -1.15], [x, -.055, 1.65]);
      }
      for (let row = 0; row <= 4; row++) {
        const z = -1.15 + row * .7; line([-4.15, -.055, z], [4.15, -.055, z]);
      }
      for (const y of [0, 1, 2, 3]) line([-4.15, y, -.6], [4.15, y, -.6]);
    }
    if (mode === 'load') {
      const bar = new THREE.Group(), plates = new THREE.Group(); model.add(bar); bar.add(plates); bar.position.y = 1.25;
      const shaft = cylinder(.075, 8.7, steel, bar, 0, 0, 0); shaft.rotation.z = Math.PI / 2;
      for (const sign of [-1, 1]) {
        const sleeve = cylinder(.13, 1.45, steel, bar, sign * 3.48, 0, 0); sleeve.rotation.z = Math.PI / 2;
        const collar = cylinder(.22, .12, accent, bar, sign * 2.72, 0, 0); collar.rotation.z = Math.PI / 2;
        for (let i = 0; i < 22; i++) {
          const grip = mesh(new THREE.TorusGeometry(.078, .005, 5, 16), muted, bar, sign * (1.2 + i * .045), 0, 0); grip.rotation.y = Math.PI / 2;
        }
      }
      apply = () => {
        clearGeometry(plates); let remainder = (state.weight - 20) / 2; const values = [];
        for (const size of [20, 10, 5, 2.5, 1.25]) while (remainder >= size - .00001) { values.push(size); remainder -= size; }
        if (remainder > .00001) values.push(remainder);
        for (const sign of [-1, 1]) {
          let offset = 2.84;
          values.forEach((value, i) => {
            const r = .35 + Math.sqrt(value / 20) * .7, thickness = .12 + value * .005;
            const shape = new THREE.Shape(); shape.absarc(0, 0, r, 0, Math.PI * 2, false);
            const hole = new THREE.Path(); hole.absarc(0, 0, .14, 0, Math.PI * 2, true); shape.holes.push(hole);
            const plate = mesh(new THREE.ExtrudeGeometry(shape, { depth: thickness, bevelEnabled: true, bevelSize: .025,
              bevelThickness: .025, bevelSegments: 2, steps: 1, curveSegments: 48 }), i % 2 ? muted : dark, plates, sign * offset, 0, 0);
            plate.rotation.y = sign * Math.PI / 2;
            const lip = mesh(new THREE.TorusGeometry(r - .06, .023, 8, 64), i === 0 ? accent : steel, plates,
              sign * (offset + thickness + .025), 0, 0); lip.rotation.y = Math.PI / 2;
            offset += thickness + .05;
          });
        }
      };
    } else if (mode === 'atlas') {
      const panels = [];
      for (let i = 0; i < 5; i++) {
        const a = (i - 2) * Math.PI / 6, panel = new THREE.Group(); panel.position.set(Math.sin(a) * 4.1, 0, -Math.cos(a) * 1.7);
        panel.rotation.y = -a * .35; model.add(panel); panel.userData.baseZ = panel.position.z;
        const faceMat = material('bg-lift', { metalness: .45 });
        const face = outline(box(1.6, 2.65, .28, faceMat, panel, 0, 1.55, 0)); face.userData.index = i; targets.push(face);
        box(1.75, .23, .75, dark, panel, 0, .15, 0);
        box(1.15, .1, .045, accent, panel, 0, 2.48, .17);
        for (let row = 0; row < 3; row++) box(1.05 - row * .17, .07, .045, muted, panel, -.06, 1.14 - row * .27, .17);
        const axis = cylinder(.045, .92, steel, panel, 0, 1.86, .24); axis.rotation.z = Math.PI / 2;
        for (const sign of [-1, 1]) { const disc = cylinder(.17, .11, accent, panel, sign * .33, 1.86, .24); disc.rotation.z = Math.PI / 2; }
        panels.push({ panel, faceMat });
      }
      apply = () => panels.forEach(({ panel, faceMat }, i) => {
        const active = i === state.selected; tween(panel.position, 'z', panel.userData.baseZ + (active ? 1.2 : 0));
        tween(panel.position, 'y', active ? .3 : 0); faceMat.color.copy(palette[active ? 'accent' : 'bg-lift'].color);
        faceMat.emissive.copy(palette.accent.color); faceMat.emissiveIntensity = active ? .12 : 0;
      });
    } else if (mode === 'schedule') {
      const blocks = [];
      for (let row = 0; row < 4; row++) for (let day = 0; day < 7; day++) {
        const mat = material('bg-lift'), block = outline(box(.83, 1, .86, mat, model, (day - 3) * 1.05, .07, (row - 1.5) * 1.16));
        block.userData.index = day; block.scale.y = .14; targets.push(block); blocks.push({ block, mat, day, row });
      }
      apply = () => blocks.forEach(({ block, mat, day, row }) => {
        const selected = state.days.includes(day), h = selected ? .66 + row * .1 : .14;
        tween(block.scale, 'y', h); tween(block.position, 'y', h / 2);
        mat.color.copy(palette[selected ? 'accent' : 'bg-lift'].color);
      });
    } else if (mode === 'session') {
      const records = [];
      for (let i = 0; i < 2; i++) {
        const group = new THREE.Group(); group.position.set((i - .5) * 3.1, .28, 0); model.add(group);
        for (let layer = 0; layer < 4; layer++) outline(box(2.5, .12, 1.8, dark, group, 0, .08 + layer * .15, -.1));
        const fill = box(2.15, 1, 1.48, accent, group, 0, .65, -.1); fill.scale.y = .1;
        outline(box(2.5, 2.9, .2, dark, group, 0, 2.07, -.85));
        box(1.72, .09, .04, muted, group, 0, 3.15, -.72);
        for (let row = 0; row < 2; row++) box(1.3 - row * .3, .09, .04, ink, group, -.2, 2.7 - row * .3, -.72);
        const check = new THREE.Group(); group.add(check); check.position.set(.5, 1.7, -.66);
        const short = box(.13, .4, .07, good, check, -.15, -.04, 0); short.rotation.z = .8;
        const long = box(.13, .75, .07, good, check, .12, .09, 0); long.rotation.z = -.7;
        records.push({ fill, check });
      }
      apply = () => records.forEach(({ fill, check }, i) => {
        const done = state.completedSets[i], h = done ? 1.14 : .1;
        tween(fill.scale, 'y', h); tween(fill.position, 'y', .6 + h / 2); fill.material = done ? good : accent; check.visible = done;
      });
    } else {
      const bars = [], values = [60, 60, 60, 60, 60, 60];
      values.forEach((value, i) => {
        const h = value / 20, bar = outline(box(.79, 1, .86, i < 3 ? muted : i === 3 ? ink : accent, model, (i - 2.5) * 1.3, h / 2, 0));
        bar.scale.y = h; bars.push(bar);
        box(.94, .08, 1.1, inset, model, (i - 2.5) * 1.3, .01, 0);
        if (i >= 4) {
          const reference = geometry(new THREE.BoxGeometry(.86, 3, .94));
          const ghost = new THREE.LineSegments(geometry(new THREE.EdgesGeometry(reference)), edgeMaterial);
          ghost.position.set((i - 2.5) * 1.3, 1.5, 0); model.add(ghost);
        }
      });
      apply = () => bars.forEach((bar, i) => {
        if (i < 4) return; const h = (state.applied ? 57.5 : 60) / 20;
        tween(bar.scale, 'y', h); tween(bar.position, 'y', h / 2); bar.material = state.applied ? good : accent;
      });
    }
  } catch (error) { geometries.forEach(g => g.dispose()); materials.forEach(m => m.dispose()); renderer?.dispose(); report(error); throw error; }
  const canvas = renderer.domElement; canvas.setAttribute('aria-hidden', 'true'); canvas.style.cssText = 'display:block;width:100%;height:100%;touch-action:pan-y'; host.append(canvas);
  const paused = () => disposed || document.hidden || host.hidden || !visible || !width || !height || lost || getComputedStyle(host).visibility === 'hidden';
  const getState = () => ({ mode, ...structuredClone(state), rotation: model.rotation.y, ready: rendered && !disposed && !lost && !!width && !!height, paused: paused(), calls: renderer.info.render.calls, geometries: renderer.info.memory.geometries, textures: renderer.info.memory.textures });
  const publish = () => { host.dataset.sceneMode = mode; host.dataset.sceneReady = String(getState().ready); host.dataset.sceneState = JSON.stringify(getState()); };
  // Fit the projected stage, not an origin-centred rectangle: the old framing cut
  // the front of the turntable and the right side of the schedule on short stages.
  // Fixed pose envelopes include all selected/completed states, avoiding zoom on updates.
  const fitPoints = [];
  const envelope = mode === 'load' ? [[-4.5, .1, -1.1], [4.5, 2.45, 1.1]] : {
    atlas: [[-4.7, -.28, -2.35], [4.7, 3.3, 1.65]],
    schedule: [[-4.03, -.16, -2.57], [4.03, 1.05, 2.57]],
    session: [[-2.9, -.2, -1], [2.9, 3.85, .95]],
    insights: [[-4.42, -.16, -1.37], [4.42, 3.1, 1.87]]
  }[mode];
  for (const x of [envelope[0][0], envelope[1][0]]) for (const y of [envelope[0][1], envelope[1][1]]) for (const z of [envelope[0][2], envelope[1][2]]) fitPoints.push(new THREE.Vector3(x, y, z));
  if (mode === 'load') for (let i = 0; i < 48; i++) {
    const a = i * Math.PI / 24; fitPoints.push(new THREE.Vector3(Math.cos(a) * 5, -.23, Math.sin(a) * 5));
  }
  const fitCamera = () => {
    if (!width || !height) return; model.updateMatrixWorld(true); camera.updateMatrixWorld(true);
    const points = fitPoints.map(point => point.clone().applyMatrix4(model.matrixWorld).applyMatrix4(camera.matrixWorldInverse));
    const minX = Math.min(...points.map(p => p.x)), maxX = Math.max(...points.map(p => p.x));
    const minY = Math.min(...points.map(p => p.y)), maxY = Math.max(...points.map(p => p.y));
    const aspect = width / height, half = Math.max(maxY - minY, (maxX - minX) / aspect) * .57;
    const x = (minX + maxX) / 2, y = (minY + maxY) / 2;
    Object.assign(camera, { left: x - half * aspect, right: x + half * aspect, top: y + half, bottom: y - half }); camera.updateProjectionMatrix();
  };
  const invalidate = () => { if (!disposed && !paused() && !frame) frame = requestAnimationFrame(render); };
  function render(time) {
    frame = 0; if (disposed || paused()) { lastTime = 0; return; }
    const factor = Math.min(1, (time - (lastTime || time - 16)) / 80); lastTime = time;
    for (let i = tweens.length - 1; i >= 0; i--) {
      const t = tweens[i]; t.object[t.key] += (t.value - t.object[t.key]) * factor;
      if (Math.abs(t.value - t.object[t.key]) < .001) { t.object[t.key] = t.value; tweens.splice(i, 1); }
    }
    try { const first = !rendered; renderer.render(scene, camera); rendered = true; if (first) host.dispatchEvent(new CustomEvent('scene-ready', { bubbles: true })); }
    catch (error) { lost = true; report(error); }
    publish(); if (tweens.length) invalidate(); else lastTime = 0;
  }
  const resize = () => {
    if (disposed) return;
    const rect = host.getBoundingClientRect(), nextRatio = Math.min(window.devicePixelRatio || 1, 1.5);
    // ResizeObserver also reports the initial, already-sized host. Reassigning
    // canvas dimensions clears a valid static frame even when the size is equal.
    if (width === rect.width && height === rect.height && pixelRatio === nextRatio) { invalidate(); return; }
    width = rect.width; height = rect.height; rendered = false;
    if (width && height) {
      fitCamera();
      if (pixelRatio !== nextRatio) { renderer.setPixelRatio(nextRatio); pixelRatio = nextRatio; }
      renderer.setSize(width, height, false); invalidate();
    }
    publish();
  };
  const rotate = delta => { if (disposed || !Number.isFinite(delta)) return; model.rotation.y += delta; fitCamera(); publish(); invalidate(); };
  const resetView = () => { if (disposed) return; model.rotation.set(0, 0, 0); fitCamera(); publish(); invalidate(); };
  const down = event => {
    if (disposed || pointer || (event.pointerType === 'mouse' && event.button !== 0)) return;
    pointer = { id: event.pointerId, startX: event.clientX, startY: event.clientY, x: event.clientX, dragged: false }; canvas.setPointerCapture(event.pointerId);
  };
  const move = event => {
    if (!pointer || event.pointerId !== pointer.id) return;
    if (Math.hypot(event.clientX - pointer.startX, event.clientY - pointer.startY) > 6) pointer.dragged = true;
    if (pointer.dragged) rotate((event.clientX - pointer.x) * .009); pointer.x = event.clientX;
  };
  const up = event => {
    if (!pointer || event.pointerId !== pointer.id) return;
    const tap = !pointer.dragged && event.type === 'pointerup' && Math.hypot(event.clientX - pointer.startX, event.clientY - pointer.startY) <= 6; pointer = null;
    if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
    if (!tap || !targets.length || lost) return;
    const rect = canvas.getBoundingClientRect(); mouse.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
    scene.updateMatrixWorld(true); camera.updateMatrixWorld(true); raycaster.setFromCamera(mouse, camera);
    const hit = raycaster.intersectObjects(targets, false)[0]; if (hit) onSelect(hit.object.userData.index);
  };
  const visibility = () => { if (paused()) { cancelAnimationFrame(frame); frame = 0; lastTime = 0; } else invalidate(); publish(); };
  const contextLost = event => { event.preventDefault(); lost = true; rendered = false; visibility(); report(new Error('WebGL context lost')); };
  const contextRestored = () => { lost = false; rendered = false; resize(); };
  for (const [type, listener] of [['pointerdown', down], ['pointermove', move], ['pointerup', up], ['pointercancel', up], ['lostpointercapture', up], ['webglcontextlost', contextLost], ['webglcontextrestored', contextRestored]]) canvas.addEventListener(type, listener);
  document.addEventListener('visibilitychange', visibility);
  const observer = new ResizeObserver(resize); observer.observe(host);
  const intersection = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; visibility(); }); intersection.observe(host);
  const attributes = new MutationObserver(visibility); attributes.observe(host, { attributes: true, attributeFilter: ['hidden', 'class', 'style'] });
  const update = patch => {
    if (disposed) return; if (!patch || typeof patch !== 'object') throw new TypeError('A scene state object is required.');
    if (mode === 'load' && 'weight' in patch) {
      if (!Number.isFinite(patch.weight) || patch.weight < 20 || patch.weight > 120) throw new RangeError('weight must be 20–120.'); state.weight = patch.weight;
    } else if (mode === 'atlas' && 'selected' in patch) {
      if (!Number.isInteger(patch.selected) || patch.selected < 0 || patch.selected > 4) throw new RangeError('selected must be 0–4.'); state.selected = patch.selected;
    } else if (mode === 'schedule' && 'days' in patch) {
      if (!Array.isArray(patch.days) || patch.days.some(d => !Number.isInteger(d) || d < 0 || d > 6) || new Set(patch.days).size !== patch.days.length) throw new RangeError('days must contain unique indices 0–6.'); state.days = [...patch.days];
    } else if (mode === 'session' && 'completed' in patch) {
      if (!Number.isInteger(patch.completed) || patch.completed < 0 || patch.completed > 2) throw new RangeError('completed must be 0–2.'); state.completed = patch.completed;
      if ('completedSets' in patch) {
        if (!Array.isArray(patch.completedSets) || patch.completedSets.length !== 2 || patch.completedSets.some(v => typeof v !== 'boolean') || patch.completedSets.filter(Boolean).length !== patch.completed) throw new TypeError('completedSets must match the completed count.');
        state.completedSets = [...patch.completedSets];
      } else state.completedSets = [state.completed > 0, state.completed > 1];
    } else if (mode === 'insights' && 'applied' in patch) {
      if (typeof patch.applied !== 'boolean') throw new TypeError('applied must be a boolean.'); state.applied = patch.applied;
    }
    apply(); publish(); invalidate();
  };
  const dispose = () => {
    if (disposed) return; disposed = true; cancelAnimationFrame(frame); observer.disconnect(); intersection.disconnect(); attributes.disconnect(); document.removeEventListener('visibilitychange', visibility);
    for (const [type, listener] of [['pointerdown', down], ['pointermove', move], ['pointerup', up], ['pointercancel', up], ['lostpointercapture', up], ['webglcontextlost', contextLost], ['webglcontextrestored', contextRestored]]) canvas.removeEventListener(type, listener);
    pointer = null; tweens.length = 0; geometries.forEach(g => g.dispose()); materials.forEach(m => m.dispose());
    scene.traverse(object => object.shadow?.dispose()); renderer.dispose(); canvas.remove(); publish();
  };
  apply(); resize(); return { update, rotate, resetView, dispose, getState };
}
