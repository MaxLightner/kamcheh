import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.module.js';
import {
  calibrateOneMeter, floorDistanceMeters, measuredMeters,
  horizontalSurface, onSameFloor, formatDistanceCm
} from './measure-core.mjs';

const $ = id => document.getElementById(id);
const ui = {
  start: $('start-ar'), support: $('support'), landing: $('start-screen'),
  overlay: $('ar-overlay'), leave: $('leave-ar'), tracking: $('tracking'),
  reticle: $('reticle-2d'), phase: $('phase'), reading: $('reading'),
  capture: $('capture'), again: $('reset-measure'), reset: $('reset-reference')
};

let renderer = null;
let scene = null;
let camera = null;
let session = null;
let hitSource = null;
let cursor = null;
let step = 0; // 0 ref A, 1 ref B, 2 measure A, 3 measure B, 4 complete
let refA = null;
let refB = null;
let pointA = null;
let pointB = null;
let correction = null;
let floorY = null;
let reticleMesh = null;
let geometryGroup = null;

function stage() {
  const titles = [
    'مرجع ۱ متر — نقطه اول', 'مرجع ۱ متر — نقطه دوم',
    'اندازه‌گیری — نقطه اول', 'اندازه‌گیری — نقطه دوم',
    'اندازه‌گیری کامل'
  ];
  const actions = [
    'ثبت نقطه اول مرجع', 'ثبت نقطه دوم مرجع',
    'ثبت نقطه شروع', 'ثبت نقطه پایان', 'اندازه‌گیری جدید'
  ];
  ui.phase.textContent = titles[step];
  ui.capture.textContent = actions[step];
  ui.capture.disabled = !cursor;
  ui.again.disabled = correction === null;
  if (step < 2) {
    ui.reading.textContent = 'فاصله مرجع باید در واقعیت دقیقاً ۱ متر باشد';
  } else if (step < 4) {
    ui.reading.textContent = 'مرجع ثبت شد؛ دو نقطه را انتخاب کن';
  } else if (pointA && pointB) {
    ui.reading.textContent = formatDistanceCm(measuredMeters(pointA, pointB, correction));
  }
}

function clearGroup() {
  if (!geometryGroup) return;
  for (const child of [...geometryGroup.children]) {
    child.geometry?.dispose();
    child.material?.dispose();
    geometryGroup.remove(child);
  }
}

function marker(position, color) {
  const material = new THREE.MeshBasicMaterial({
    color, depthTest: false, depthWrite: false
  });
  const mesh = new THREE.Mesh(
    new THREE.SphereGeometry(0.023, 12, 8), material
  );
  mesh.position.copy(position);
  mesh.position.y += 0.018;
  mesh.renderOrder = 12;
  geometryGroup.add(mesh);
}

function drawSegment(start, end, color) {
  if (!start || !end) return;
  const a = start.clone();
  const b = end.clone();
  a.y += 0.024;
  b.y += 0.024;
  const delta = b.clone().sub(a);
  const length = delta.length();
  if (length <= 0.001) return;
  const line = new THREE.Mesh(
    new THREE.CylinderGeometry(0.007, 0.007, length, 8),
    new THREE.MeshBasicMaterial({color, depthTest: false, depthWrite: false})
  );
  line.position.copy(a).lerp(b, 0.5);
  line.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.normalize());
  line.renderOrder = 11;
  geometryGroup.add(line);
}

function drawMarks() {
  clearGroup();
  if (refA) marker(refA, 0x42db9a);
  if (refB) marker(refB, 0x42db9a);
  if (refA && refB) drawSegment(refA, refB, 0x42db9a);
  if (pointA) marker(pointA, 0xffb259);
  if (pointB) marker(pointB, 0xffb259);
  if (pointA && pointB) drawSegment(pointA, pointB, 0xffb259);
}

function resetMeasurement() {
  pointA = null;
  pointB = null;
  step = correction === null ? 0 : 2;
  drawMarks();
  stage();
}

function resetReference() {
  refA = null;
  refB = null;
  correction = null;
  floorY = null;
  pointA = null;
  pointB = null;
  step = 0;
  drawMarks();
  stage();
}

function capture() {
  if (!cursor || !session) return;
  const p = cursor.clone();
  if (step > 0 && floorY !== null &&
      !onSameFloor(p, {y: floorY})) {
    ui.tracking.textContent = 'نقطه روی همان کف انتخاب‌شده نیست. دوربین را پایین بگیر.';
    return;
  }

  if (step === 0) {
    refA = p;
    floorY = p.y;
    step = 1;
  } else if (step === 1) {
    try {
      const factor = calibrateOneMeter(refA, p);
      if (floorDistanceMeters(refA, p) < 0.25) return;
      refB = p;
      correction = factor;
      step = 2;
    } catch (_) {
      ui.tracking.textContent = 'دو سر مرجع ۱ متری باید جدا و روی یک کف باشند؛ دوباره نقطه دوم را بگیر.';
      return;
    }
  } else if (step === 2 || step === 4) {
    pointA = p;
    pointB = null;
    step = 3;
  } else if (step === 3) {
    pointB = p;
    step = 4;
  }
  drawMarks();
  stage();
}

function frameLoop(_time, frame) {
  if (!frame || !session || !hitSource || !renderer) return;
  const reference = renderer.xr.getReferenceSpace();
  const hits = frame.getHitTestResults(hitSource);
  cursor = null;
  for (const hit of hits) {
    const pose = hit.getPose(reference);
    if (!pose) continue;
    const t = pose.transform;
    const q = new THREE.Quaternion(
      t.orientation.x, t.orientation.y, t.orientation.z, t.orientation.w
    );
    const normalY = new THREE.Vector3(0, 1, 0).applyQuaternion(q).y;
    if (!horizontalSurface(normalY)) continue;
    const candidate = new THREE.Vector3(
      t.position.x, t.position.y, t.position.z
    );
    if (floorY !== null && !onSameFloor(candidate, {y: floorY})) continue;
    cursor = candidate;
    break;
  }
  if (reticleMesh) {
    reticleMesh.visible = !!cursor;
    if (cursor) {
      reticleMesh.position.copy(cursor);
      reticleMesh.position.y += 0.007;
    }
  }
  ui.reticle.classList.toggle('ready', !!cursor);
  ui.capture.disabled = !cursor;
  ui.tracking.textContent = cursor
    ? 'کف شناسایی شد · نشانگر را روی نقطه مورد نظر بگیر'
    : 'در حال جست‌وجوی کف… گوشی را آهسته حرکت بده';
  renderer.render(scene, camera);
}

function cleanup() {
  hitSource?.cancel?.();
  hitSource = null;
  cursor = null;
  session = null;
  renderer?.setAnimationLoop(null);
  renderer?.dispose();
  renderer?.domElement?.remove();
  renderer = null;
  if (scene && geometryGroup) clearGroup();
  scene = null;
  geometryGroup = null;
  reticleMesh = null;
  camera = null;
  ui.overlay.hidden = true;
  ui.landing.hidden = false;
  ui.start.disabled = false;
  step = 0;
  refA = null; refB = null; pointA = null; pointB = null;
  correction = null; floorY = null;
}

async function startAR() {
  if (!navigator.xr || !await navigator.xr.isSessionSupported('immersive-ar')) {
    ui.support.textContent = 'این دستگاه یا مرورگر از AR پشتیبانی نمی‌کند. صفحه را در Chrome اندروید باز کن.';
    return;
  }
  ui.start.disabled = true;
  try {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera();
    geometryGroup = new THREE.Group();
    scene.add(geometryGroup);
    const ring = new THREE.RingGeometry(0.035, 0.054, 32);
    reticleMesh = new THREE.Mesh(ring,
      new THREE.MeshBasicMaterial({
        color: 0x42ffbf, side: THREE.DoubleSide,
        depthTest: false, depthWrite: false
      }));
    reticleMesh.rotation.x = -Math.PI / 2;
    reticleMesh.visible = false;
    reticleMesh.renderOrder = 15;
    scene.add(reticleMesh);
    renderer = new THREE.WebGLRenderer({alpha:true,antialias:true});
    renderer.domElement.className = 'kamcheh-ar-canvas';
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.xr.enabled = true;
    renderer.xr.setReferenceSpaceType('local');
    document.body.append(renderer.domElement);
    // DOM overlay is required so the same session can expose physical
    // capture/exit controls. We do not provide a fake camera fallback.
    ui.overlay.hidden = false;
    session = await navigator.xr.requestSession('immersive-ar', {
      requiredFeatures: ['hit-test', 'dom-overlay'],
      optionalFeatures: ['anchors', 'plane-detection'],
      domOverlay: {root: ui.overlay}
    });
    session.addEventListener('end', cleanup, {once:true});
    await renderer.xr.setSession(session);
    const viewerSpace = await session.requestReferenceSpace('viewer');
    hitSource = await session.requestHitTestSource({space: viewerSpace});
    ui.landing.hidden = true;
    resetReference();
    renderer.setAnimationLoop(frameLoop);
  } catch (error) {
    const name = error?.name || '';
    ui.support.textContent = name === 'NotAllowedError'
      ? 'برای شروع AR اجازه دوربین لازم است.'
      : 'شروع AR ممکن نشد. Chrome و Google Play Services for AR را بررسی کن. ' + (error?.message || '');
    if (session) {
      try {await session.end();} catch (_) {cleanup();}
    } else cleanup();
  }
}

async function checkSupport() {
  if (!window.isSecureContext || !navigator.xr) {
    ui.start.disabled = true;
    ui.support.textContent = 'برای AR، گوشی اندرویدی سازگار و Chrome با اتصال امن HTTPS لازم است.';
    return;
  }
  try {
    const supported = await navigator.xr.isSessionSupported('immersive-ar');
    ui.start.disabled = !supported;
    ui.support.textContent = supported
      ? 'دستگاه آماده است. برای شروع مجوز دوربین را تأیید کن.'
      : 'AR روی این دستگاه یا این مرورگر فعال نیست. با Chrome اندروید امتحان کن.';
  } catch (_) {
    ui.start.disabled = true;
    ui.support.textContent = 'امکان بررسی پشتیبانی AR وجود ندارد.';
  }
}

ui.start.addEventListener('click', startAR);
ui.leave.addEventListener('click', () => session?.end());
ui.capture.addEventListener('click', capture);
ui.again.addEventListener('click', resetMeasurement);
ui.reset.addEventListener('click', resetReference);
window.addEventListener('resize', () => {
  renderer?.setSize(window.innerWidth, window.innerHeight);
});
window.addEventListener('pagehide', () => { if (session) session.end(); });
checkSupport();
