// Construção do mundo: chão do sertão, muros, pilares, mandacarus, Cruzeiros,
// céu noturno com lua e estrelas, iluminação lunar dinâmica.
import * as THREE from 'three';

export const WORLD = { w: 76, h: 44 };
export const SAFE_X = 22;
export const CRUZEIROS = [{ x: 14, z: 22 }, { x: 30, z: 38 }];

// Colisores AABB (muros, divisória do hub, pilares). Usados pelo jogador local.
export const COLLIDERS = [
  { minX: -2, maxX: 78, minZ: -2, maxZ: 1 },      // norte
  { minX: -2, maxX: 78, minZ: 43, maxZ: 46 },     // sul
  { minX: -2, maxX: 1, minZ: -2, maxZ: 46 },      // oeste
  { minX: 75, maxX: 78, minZ: -2, maxZ: 46 },     // leste
  { minX: 20, maxX: 21, minZ: -2, maxZ: 18 },     // divisória hub (norte do portão)
  { minX: 20, maxX: 21, minZ: 26, maxZ: 46 },     // divisória hub (sul do portão)
];

const PILLARS = [
  { x: 26, z: 13 }, { x: 26, z: 31 }, { x: 36, z: 22 },
  { x: 44, z: 12 }, { x: 44, z: 32 }, { x: 54, z: 16 }, { x: 54, z: 28 },
];
for (const p of PILLARS) {
  COLLIDERS.push({ minX: p.x - 1, maxX: p.x + 1, minZ: p.z - 1, maxZ: p.z + 1 });
}

// Iluminação por fase lunar (porta a tabela do LunarAmbiance do projeto Godot).
const PHASE_LIGHT = [
  { moon: 0x7280d9, energy: 0.45, hemi: 0.32, fog: 0x0c0e1a },  // Lua Nova
  { moon: 0x99a0d9, energy: 0.75, hemi: 0.46, fog: 0x12131f },  // Quarto Crescente
  { moon: 0xc7ccf2, energy: 1.10, hemi: 0.60, fog: 0x191b26 },  // Meia Lua Crescente
  { moon: 0xebe0cc, energy: 1.35, hemi: 0.68, fog: 0x1d1b22 },  // Gibosa Crescente
  { moon: 0xfff9e6, energy: 1.70, hemi: 0.80, fog: 0x232532 },  // Lua Cheia
  { moon: 0xccc7cc, energy: 1.20, hemi: 0.62, fog: 0x1b191f },  // Gibosa Minguante
  { moon: 0x998fad, energy: 0.85, hemi: 0.48, fog: 0x141220 },  // Meia Lua Minguante
  { moon: 0x736b94, energy: 0.55, hemi: 0.36, fog: 0x0e0c17 },  // Quarto Minguante
];

export function buildWorld(scene) {
  const refs = {};

  // ─── Névoa e céu ───
  scene.fog = new THREE.FogExp2(0x191b26, 0.016);
  scene.background = new THREE.Color(0x07060c);

  // ─── Luzes ───
  const hemi = new THREE.HemisphereLight(0x8a93c4, 0x2a2018, 0.46);
  scene.add(hemi);
  refs.hemi = hemi;

  const moonLight = new THREE.DirectionalLight(0xc7ccf2, 0.85);
  moonLight.position.set(55, 42, -10);
  moonLight.target.position.set(WORLD.w / 2, 0, WORLD.h / 2);
  moonLight.castShadow = true;
  moonLight.shadow.mapSize.set(2048, 2048);
  moonLight.shadow.camera.left = -50;
  moonLight.shadow.camera.right = 50;
  moonLight.shadow.camera.top = 40;
  moonLight.shadow.camera.bottom = -40;
  moonLight.shadow.camera.far = 140;
  moonLight.shadow.bias = -0.0008;
  scene.add(moonLight, moonLight.target);
  refs.moonLight = moonLight;

  // ─── Lua e estrelas ───
  const moon = new THREE.Mesh(
    new THREE.SphereGeometry(7, 24, 24),
    new THREE.MeshBasicMaterial({ color: 0xd8dcf5, fog: false })
  );
  moon.position.set(150, 90, -120);
  scene.add(moon);
  refs.moon = moon;

  const starGeo = new THREE.BufferGeometry();
  const starPos = [];
  for (let i = 0; i < 700; i++) {
    const t = Math.random() * Math.PI * 2;
    const ph = Math.random() * Math.PI * 0.46;
    const r = 320;
    starPos.push(
      Math.cos(t) * Math.cos(ph) * r + WORLD.w / 2,
      Math.sin(ph) * r + 5,
      Math.sin(t) * Math.cos(ph) * r + WORLD.h / 2
    );
  }
  starGeo.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3));
  const stars = new THREE.Points(starGeo, new THREE.PointsMaterial({
    color: 0xbfc4e0, size: 1.4, sizeAttenuation: false, fog: false,
  }));
  scene.add(stars);

  // ─── Chão (terra do sertão com textura procedural) ───
  const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(WORLD.w, WORLD.h),
    new THREE.MeshStandardMaterial({ map: makeGroundTexture(), roughness: 1.0 })
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(WORLD.w / 2, 0, WORLD.h / 2);
  ground.receiveShadow = true;
  scene.add(ground);

  // ─── Muros de pedra ───
  const wallMat = new THREE.MeshStandardMaterial({ color: 0x2b2118, roughness: 1.0 });
  addWall(scene, wallMat, WORLD.w + 2, 0.5, WORLD.w / 2, 0.5);            // norte
  addWall(scene, wallMat, WORLD.w + 2, 0.5, WORLD.w / 2, WORLD.h - 0.5);  // sul
  addWallV(scene, wallMat, WORLD.h + 2, 0.5, 0.5, WORLD.h / 2);           // oeste
  addWallV(scene, wallMat, WORLD.h + 2, 0.5, WORLD.w - 0.5, WORLD.h / 2); // leste
  // Divisória do hub com portão (abertura em z 18–26).
  addWallV(scene, wallMat, 18, 1.0, 20.5, 9);
  addWallV(scene, wallMat, 18, 1.0, 20.5, 35);

  // ─── Pilares de pedra ───
  const pillarMat = new THREE.MeshStandardMaterial({ color: 0x3a2e20, roughness: 1.0 });
  for (const p of PILLARS) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(2, 3.2, 2), pillarMat);
    m.position.set(p.x, 1.6, p.z);
    m.castShadow = m.receiveShadow = true;
    scene.add(m);
  }

  // ─── Mandacarus e pedras ───
  scatterCacti(scene);
  scatterRocks(scene);

  // ─── Cruzeiros ───
  for (const c of CRUZEIROS) addCruzeiro(scene, c.x, c.z);

  // ─── Placa do portão ───
  refs.applyLunar = (phase) => {
    const cfg = PHASE_LIGHT[phase] || PHASE_LIGHT[2];
    moonLight.color.setHex(cfg.moon);
    moonLight.intensity = cfg.energy;
    hemi.intensity = cfg.hemi;
    scene.fog.color.setHex(cfg.fog);
    moon.material.color.setHex(cfg.moon).multiplyScalar(1.4);
  };

  return refs;
}

// Muro horizontal (corre no eixo X).
function addWall(scene, mat, len, _depth, cx, cz) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(len, 2.4, 1), mat);
  m.position.set(cx, 1.2, cz);
  m.castShadow = m.receiveShadow = true;
  scene.add(m);
}
// Muro vertical (corre no eixo Z).
function addWallV(scene, mat, len, _depth, cx, cz) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(1, 2.4, len), mat);
  m.position.set(cx, 1.2, cz);
  m.castShadow = m.receiveShadow = true;
  scene.add(m);
}

function addCruzeiro(scene, x, z) {
  const mat = new THREE.MeshStandardMaterial({
    color: 0xcbbf9a, roughness: 0.85,
    emissive: 0x9a7b3a, emissiveIntensity: 0.22,
  });
  const v = new THREE.Mesh(new THREE.BoxGeometry(0.34, 2.7, 0.34), mat);
  v.position.set(x, 1.35, z);
  const h = new THREE.Mesh(new THREE.BoxGeometry(1.5, 0.3, 0.3), mat);
  h.position.set(x, 1.95, z);
  v.castShadow = h.castShadow = true;
  scene.add(v, h);

  const light = new THREE.PointLight(0xffd98a, 6.0, 9, 1.8);
  light.position.set(x, 1.9, z);
  scene.add(light);

  // Pedrinhas na base.
  const baseMat = new THREE.MeshStandardMaterial({ color: 0x4a3c28, roughness: 1 });
  for (let i = 0; i < 5; i++) {
    const a = (i / 5) * Math.PI * 2;
    const r = new THREE.Mesh(new THREE.DodecahedronGeometry(0.22, 0), baseMat);
    r.position.set(x + Math.cos(a) * 0.7, 0.12, z + Math.sin(a) * 0.7);
    r.scale.y = 0.6;
    scene.add(r);
  }
}

function scatterCacti(scene) {
  const green = new THREE.MeshStandardMaterial({ color: 0x3f5a35, roughness: 0.95 });
  const spots = [
    [6, 8], [8, 36], [17, 6], [16, 38],
    [25, 6], [24, 38], [33, 9], [33, 34], [40, 20],
    [48, 7], [48, 37], [58, 9], [60, 36], [68, 12], [70, 30], [64, 22],
  ];
  for (const [x, z] of spots) {
    const cactus = new THREE.Group();
    const hgt = 1.6 + Math.random() * 1.2;
    const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.22, hgt, 7), green);
    trunk.position.y = hgt / 2;
    trunk.castShadow = true;
    cactus.add(trunk);
    const arms = 1 + Math.floor(Math.random() * 3);
    for (let i = 0; i < arms; i++) {
      const armH = 0.5 + Math.random() * 0.6;
      const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.13, armH, 6), green);
      const side = Math.random() < 0.5 ? 1 : -1;
      arm.position.set(side * 0.28, hgt * (0.4 + Math.random() * 0.3), 0);
      arm.castShadow = true;
      cactus.add(arm);
      const tip = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.12, 0.5, 6), green);
      tip.position.set(side * 0.4, arm.position.y + armH / 2 + 0.18, 0);
      tip.castShadow = true;
      cactus.add(tip);
    }
    cactus.position.set(x + (Math.random() - 0.5), 0, z + (Math.random() - 0.5));
    cactus.rotation.y = Math.random() * Math.PI;
    scene.add(cactus);
  }
}

function scatterRocks(scene) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x494034, roughness: 1 });
  for (let i = 0; i < 22; i++) {
    const r = new THREE.Mesh(new THREE.DodecahedronGeometry(0.3 + Math.random() * 0.5, 0), mat);
    r.position.set(2 + Math.random() * (WORLD.w - 4), 0.15, 2 + Math.random() * (WORLD.h - 4));
    r.scale.y = 0.5 + Math.random() * 0.3;
    r.rotation.y = Math.random() * Math.PI;
    r.castShadow = r.receiveShadow = true;
    scene.add(r);
  }
}

// Textura procedural de terra rachada (canvas — sem assets externos).
function makeGroundTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 512;
  const g = c.getContext('2d');
  g.fillStyle = '#41311e';
  g.fillRect(0, 0, 512, 512);
  // Manchas de terra.
  for (let i = 0; i < 900; i++) {
    const a = 0.04 + Math.random() * 0.09;
    g.fillStyle = Math.random() < 0.5 ? `rgba(20,12,6,${a})` : `rgba(120,92,52,${a})`;
    const s = 4 + Math.random() * 26;
    g.beginPath();
    g.ellipse(Math.random() * 512, Math.random() * 512, s, s * (0.4 + Math.random() * 0.6), Math.random() * Math.PI, 0, Math.PI * 2);
    g.fill();
  }
  // Rachaduras (traço de xilogravura).
  g.strokeStyle = 'rgba(14,9,4,0.55)';
  g.lineWidth = 1.6;
  for (let i = 0; i < 70; i++) {
    let x = Math.random() * 512, y = Math.random() * 512;
    g.beginPath();
    g.moveTo(x, y);
    const segs = 3 + Math.floor(Math.random() * 4);
    for (let s = 0; s < segs; s++) {
      x += (Math.random() - 0.5) * 70;
      y += (Math.random() - 0.5) * 70;
      g.lineTo(x, y);
    }
    g.stroke();
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(7, 4);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

// Resolve colisão círculo (jogador) × AABBs. Retorna posição corrigida.
export function resolveColliders(x, z, radius) {
  for (const c of COLLIDERS) {
    const cx = Math.max(c.minX, Math.min(x, c.maxX));
    const cz = Math.max(c.minZ, Math.min(z, c.maxZ));
    const dx = x - cx, dz = z - cz;
    const d2 = dx * dx + dz * dz;
    if (d2 < radius * radius && d2 > 0.000001) {
      const d = Math.sqrt(d2);
      x = cx + (dx / d) * radius;
      z = cz + (dz / d) * radius;
    } else if (d2 <= 0.000001) {
      x += radius; // dentro do AABB: empurra pra fora do jeito simples
    }
  }
  return { x, z };
}
