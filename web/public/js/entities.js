// Personagens low-poly montados por peças (estilo xilogravura 3D) +
// interpolação de jogadores remotos e inimigos vindos dos snapshots.
import * as THREE from 'three';

// ─── Fábrica de texto flutuante (nomes) ──────────────────────────────────────
export function makeTextSprite(text, { size = 26, color = '#e8c97a' } = {}) {
  const c = document.createElement('canvas');
  c.width = 256; c.height = 64;
  const g = c.getContext('2d');
  g.font = `bold ${size}px Georgia, serif`;
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.lineWidth = 5;
  g.strokeStyle = 'rgba(8,5,3,0.9)';
  g.strokeText(text, 128, 32);
  g.fillStyle = color;
  g.fillText(text, 128, 32);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false }));
  sprite.scale.set(2.6, 0.65, 1);
  return sprite;
}

// ─── Bonecos ─────────────────────────────────────────────────────────────────
function mat(color, opts = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.9, ...opts });
}

export function makePlayerMesh(isLocal = false) {
  const g = new THREE.Group();
  const bodyColor = isLocal ? 0xc9a45a : 0xa68a52;

  const torso = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.65, 0.34), mat(bodyColor));
  torso.position.y = 0.85;
  const legL = new THREE.Mesh(new THREE.BoxGeometry(0.18, 0.5, 0.2), mat(0x4a3826));
  legL.position.set(-0.14, 0.27, 0);
  const legR = legL.clone();
  legR.position.x = 0.14;
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 0.28), mat(0x9c6e4a));
  head.position.y = 1.36;
  // Chapéu de couro nordestino (meia-lua de abas levantadas).
  const hatBase = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.34, 0.09, 8), mat(0x6e4f2a));
  hatBase.position.y = 1.55;
  const hatTop = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.16, 0.26), mat(0x6e4f2a));
  hatTop.position.y = 1.63;
  // Peixeira na mão direita.
  const blade = new THREE.Mesh(
    new THREE.BoxGeometry(0.06, 0.55, 0.12),
    mat(0xc9c9c9, { metalness: 0.6, roughness: 0.35 })
  );
  blade.position.set(0.36, 0.9, 0.18);
  blade.rotation.x = Math.PI / 5;

  for (const part of [torso, legL, legR, head, hatBase, hatTop, blade]) {
    part.castShadow = true;
    g.add(part);
  }
  g.userData.parts = { torso, head, blade, legL, legR };
  g.userData.baseMats = [];
  g.traverse(o => { if (o.isMesh) g.userData.baseMats.push([o.material, o.material.emissive.getHex()]); });
  return g;
}

export function makeEnemyMesh(type) {
  const g = new THREE.Group();
  if (type === 'cangaceiro') {
    const torso = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.78, 0.36), mat(0x5a3a22));
    torso.position.y = 0.95;
    const legL = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.55, 0.22), mat(0x32241a));
    legL.position.set(-0.15, 0.3, 0);
    const legR = legL.clone(); legR.position.x = 0.15;
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.3, 0.28), mat(0x8a5e3e));
    head.position.y = 1.5;
    // Chapéu de cangaceiro (meia-lua larga).
    const hat = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.52, 0.1, 8), mat(0x2e2014));
    hat.position.y = 1.7;
    const hatDome = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.18, 0.26), mat(0x2e2014));
    hatDome.position.y = 1.79;
    const machete = new THREE.Mesh(
      new THREE.BoxGeometry(0.07, 0.7, 0.14),
      mat(0xb0b0b0, { metalness: 0.55, roughness: 0.4 })
    );
    machete.position.set(0.42, 1.0, 0.16);
    machete.rotation.x = Math.PI / 6;
    for (const part of [torso, legL, legR, head, hat, hatDome, machete]) {
      part.castShadow = true;
      g.add(part);
    }
  } else {
    // Calango: lagarto rasteiro avermelhado.
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.34, 0.95), mat(0xa03524));
    body.position.y = 0.32;
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.26, 0.4), mat(0xb84a30));
    head.position.set(0, 0.36, 0.62);
    const tail = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.18, 0.7), mat(0x8a2c1e));
    tail.position.set(0, 0.26, -0.75);
    const crest = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.2, 0.5), mat(0xd96b35));
    crest.position.set(0, 0.55, 0.1);
    for (const part of [body, head, tail, crest]) {
      part.castShadow = true;
      g.add(part);
    }
  }
  g.userData.baseMats = [];
  g.traverse(o => { if (o.isMesh) g.userData.baseMats.push([o.material, o.material.emissive.getHex()]); });
  return g;
}

// Flash de emissive (telegraph/dano) num boneco inteiro.
export function flashMesh(group, hexColor, intensity = 0.9) {
  group.traverse(o => {
    if (o.isMesh) {
      o.material.emissive.setHex(hexColor);
      o.material.emissiveIntensity = intensity;
    }
  });
}
export function unflashMesh(group) {
  for (const [m, base] of group.userData.baseMats || []) {
    m.emissive.setHex(base);
    m.emissiveIntensity = 1.0;
  }
}

// ─── Registro de entidades remotas (jogadores e inimigos) ────────────────────
export class EntityRegistry {
  constructor(scene) {
    this.scene = scene;
    this.remotePlayers = new Map();  // id -> { group, label, target, anim }
    this.enemies = new Map();        // id -> { group, target, type, state }
  }

  addRemotePlayer(p) {
    if (this.remotePlayers.has(p.id)) return;
    const group = makePlayerMesh(false);
    group.position.set(p.x, 0, p.z);
    const label = makeTextSprite(p.name);
    label.position.y = 2.15;
    group.add(label);
    this.scene.add(group);
    this.remotePlayers.set(p.id, {
      group, label,
      target: { x: p.x, z: p.z, ry: p.ry || 0 },
      anim: p.anim || 'idle', dead: p.dead, walkT: 0,
    });
  }

  removeRemotePlayer(id) {
    const rp = this.remotePlayers.get(id);
    if (rp) { this.scene.remove(rp.group); this.remotePlayers.delete(id); }
  }

  addEnemy(e) {
    if (this.enemies.has(e.id)) return;
    const group = makeEnemyMesh(e.type);
    group.position.set(e.x, 0, e.z);
    this.scene.add(group);
    this.enemies.set(e.id, {
      group, type: e.type, state: e.state,
      target: { x: e.x, z: e.z, ry: e.ry || 0 },
      walkT: 0, deadScale: 1,
    });
  }

  applySnapshot(snap, myId) {
    for (const p of snap.players) {
      if (p.id === myId) continue;
      if (!this.remotePlayers.has(p.id)) this.addRemotePlayer(p);
      const rp = this.remotePlayers.get(p.id);
      rp.target.x = p.x; rp.target.z = p.z; rp.target.ry = p.ry;
      rp.anim = p.anim;
      rp.dead = p.dead;
    }
    for (const e of snap.enemies) {
      if (!this.enemies.has(e.id)) this.addEnemy(e);
      const en = this.enemies.get(e.id);
      en.target.x = e.x; en.target.z = e.z; en.target.ry = e.ry;
      en.prevState = en.state;
      en.state = e.state;
    }
  }

  update(dt) {
    const k = Math.min(1, dt * 12);   // suavização da interpolação
    for (const rp of this.remotePlayers.values()) {
      const g = rp.group;
      const dx = rp.target.x - g.position.x, dz = rp.target.z - g.position.z;
      g.position.x += dx * k;
      g.position.z += dz * k;
      g.rotation.y = lerpAngle(g.rotation.y, rp.target.ry, k);
      // Bob de caminhada procedural.
      const speed = Math.hypot(dx, dz) / Math.max(dt, 0.001);
      rp.walkT += dt * (speed > 0.4 ? 9 : 0);
      g.position.y = Math.abs(Math.sin(rp.walkT)) * (speed > 0.4 ? 0.07 : 0);
      g.visible = !rp.dead;
    }
    for (const en of this.enemies.values()) {
      const g = en.group;
      if (en.state === 'dead') {
        en.deadScale = Math.max(0, en.deadScale - dt * 1.4);
        g.scale.setScalar(Math.max(0.001, en.deadScale));
        g.visible = en.deadScale > 0.01;
        continue;
      }
      if (en.deadScale < 1) {       // renasceu
        en.deadScale = 1;
        g.scale.setScalar(1);
        g.visible = true;
        unflashMesh(g);
      }
      const dx = en.target.x - g.position.x, dz = en.target.z - g.position.z;
      g.position.x += dx * k;
      g.position.z += dz * k;
      g.rotation.y = lerpAngle(g.rotation.y, en.target.ry, k);
      const speed = Math.hypot(dx, dz) / Math.max(dt, 0.001);
      en.walkT += dt * (speed > 0.4 ? 10 : 0);
      g.position.y = Math.abs(Math.sin(en.walkT)) * (speed > 0.4 ? 0.06 : 0);
    }
  }
}

function lerpAngle(a, b, t) {
  let d = (b - a) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}
