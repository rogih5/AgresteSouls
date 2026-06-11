// Juice: partículas em voxel, números de dano, hitstop e screen shake.
import * as THREE from 'three';

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.timeScale = 1.0;
    this._hitstopTimer = 0;
    this._trauma = 0;

    // Pool de partículas (cubinhos — combina com o traço de xilogravura).
    this.particles = [];
    const geo = new THREE.BoxGeometry(0.09, 0.09, 0.09);
    for (let i = 0; i < 220; i++) {
      const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xffffff }));
      m.visible = false;
      scene.add(m);
      this.particles.push({ mesh: m, vel: new THREE.Vector3(), life: 0, maxLife: 1 });
    }
    this._pIndex = 0;

    // Pool de números de dano.
    this.numbers = [];
    for (let i = 0; i < 24; i++) {
      const c = document.createElement('canvas');
      c.width = 128; c.height = 64;
      const tex = new THREE.CanvasTexture(c);
      tex.colorSpace = THREE.SRGBColorSpace;
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true }));
      sp.scale.set(1.5, 0.75, 1);
      sp.visible = false;
      scene.add(sp);
      this.numbers.push({ sprite: sp, canvas: c, tex, life: 0, vy: 0 });
    }
    this._nIndex = 0;
  }

  // ─── Partículas ───
  burst(pos, colorHex, count = 12, speed = 4, lifetime = 0.5) {
    for (let i = 0; i < count; i++) {
      const p = this.particles[this._pIndex];
      this._pIndex = (this._pIndex + 1) % this.particles.length;
      p.mesh.visible = true;
      p.mesh.material.color.setHex(colorHex);
      p.mesh.position.set(pos.x, (pos.y ?? 0) + 0.6, pos.z);
      const a = Math.random() * Math.PI * 2;
      const up = Math.random() * speed;
      const out = (0.35 + Math.random() * 0.65) * speed * 0.7;
      p.vel.set(Math.cos(a) * out, up, Math.sin(a) * out);
      p.life = p.maxLife = lifetime * (0.7 + Math.random() * 0.6);
      p.mesh.scale.setScalar(0.7 + Math.random() * 1.3);
    }
  }

  // ─── Números de dano ───
  damageNumber(pos, amount, color = '#ffe9d0') {
    const n = this.numbers[this._nIndex];
    this._nIndex = (this._nIndex + 1) % this.numbers.length;
    const g = n.canvas.getContext('2d');
    g.clearRect(0, 0, 128, 64);
    g.font = 'bold 38px Georgia, serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.lineWidth = 6;
    g.strokeStyle = 'rgba(10,5,3,0.95)';
    g.strokeText(String(amount), 64, 32);
    g.fillStyle = color;
    g.fillText(String(amount), 64, 32);
    n.tex.needsUpdate = true;
    n.sprite.position.set(pos.x + (Math.random() - 0.5) * 0.5, 1.7, pos.z + (Math.random() - 0.5) * 0.5);
    n.sprite.material.opacity = 1;
    n.sprite.visible = true;
    n.life = 0.7;
    n.vy = 1.6;
  }

  // ─── Hitstop (câmera lenta de impacto) ───
  hitstop(duration = 0.07, scale = 0.08) {
    this.timeScale = scale;
    this._hitstopTimer = duration;
  }

  // ─── Screen shake (modelo de trauma) ───
  shake(amount = 0.4) {
    this._trauma = Math.min(1, this._trauma + amount);
  }

  cameraOffset() {
    const amt = this._trauma * this._trauma;
    return {
      x: (Math.random() * 2 - 1) * amt * 0.35,
      y: (Math.random() * 2 - 1) * amt * 0.3,
    };
  }

  // dt REAL (sem timeScale) — hitstop precisa decair em tempo de relógio.
  update(realDt) {
    if (this._hitstopTimer > 0) {
      this._hitstopTimer -= realDt;
      if (this._hitstopTimer <= 0) this.timeScale = 1.0;
    }
    this._trauma = Math.max(0, this._trauma - realDt * 1.6);

    const dt = realDt * this.timeScale;
    for (const p of this.particles) {
      if (!p.mesh.visible) continue;
      p.life -= dt;
      if (p.life <= 0) { p.mesh.visible = false; continue; }
      p.vel.y -= 9 * dt;
      p.mesh.position.addScaledVector(p.vel, dt);
      if (p.mesh.position.y < 0.04) { p.mesh.position.y = 0.04; p.vel.y *= -0.3; p.vel.x *= 0.7; p.vel.z *= 0.7; }
      p.mesh.scale.setScalar(Math.max(0.05, p.mesh.scale.x * (1 - dt * 1.2)));
    }
    for (const n of this.numbers) {
      if (!n.sprite.visible) continue;
      n.life -= realDt;
      if (n.life <= 0) { n.sprite.visible = false; continue; }
      n.sprite.position.y += n.vy * realDt;
      n.vy *= 0.94;
      n.sprite.material.opacity = Math.min(1, n.life / 0.35);
    }
  }
}
