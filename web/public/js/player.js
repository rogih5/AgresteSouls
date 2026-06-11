// Jogador local: movimento 360° com aceleração/atrito, combo de 2 golpes,
// esquiva (rasteira) com iframes, stamina e câmera com follow suave.
import * as THREE from 'three';
import { makePlayerMesh, makeTextSprite, flashMesh, unflashMesh } from './entities.js';
import { resolveColliders } from './world.js';

const MOVE_SPEED = 6.0;
const ACCEL = 55.0;
const FRICTION = 48.0;
const TURN_SMOOTH = 14.0;

const DODGE_SPEED = 13.0;
const DODGE_DURATION = 0.44;
const IFRAME_START = 0.06;
const IFRAME_END = 0.36;

const ATTACK_1_DURATION = 0.34;
const ATTACK_2_DURATION = 0.4;
const COMBO_WINDOW = 0.65;
const ATTACK_LUNGE = 3.2;

const STAMINA_MAX = 220;
const STAMINA_REGEN = 30;
const STAMINA_DELAY = 1.5;
const COST_ATTACK = 15;
const COST_DODGE = 25;

const CAM_OFFSET = new THREE.Vector3(0, 15, 11);
const CAM_FOLLOW = 7.5;

export class LocalPlayer {
  constructor(scene, camera, fx, net, name) {
    this.scene = scene;
    this.camera = camera;
    this.fx = fx;
    this.net = net;

    this.mesh = makePlayerMesh(true);
    const label = makeTextSprite(name, { color: '#ffe9a8' });
    label.position.y = 2.15;
    this.mesh.add(label);
    scene.add(this.mesh);

    this.pos = new THREE.Vector3(10, 0, 22);
    this.vel = new THREE.Vector3();
    this.facing = new THREE.Vector3(0, 0, 1);
    this.ry = 0;

    this.state = 'idle';          // idle | move | attack | dodge | dead
    this.hp = 480; this.maxHp = 480;
    this.stamina = STAMINA_MAX;
    this._staminaBlock = 0;

    this._dodgeT = 0;
    this._dodgeDir = new THREE.Vector3();
    this.iframes = false;

    this._attackT = 0;
    this._comboWindow = 0;
    this._attackIndex = 0;        // 0 = nenhum, 1, 2
    this._queuedCombo = false;

    this.dead = false;

    this._camPos = this.pos.clone().add(CAM_OFFSET);

    // Arco visual do golpe.
    const arcGeo = new THREE.RingGeometry(0.6, 2.0, 18, 1, -Math.PI / 3, (Math.PI * 2) / 3);
    this.swingArc = new THREE.Mesh(arcGeo, new THREE.MeshBasicMaterial({
      color: 0xffe9a8, transparent: true, opacity: 0, side: THREE.DoubleSide, depthWrite: false,
    }));
    this.swingArc.rotation.x = -Math.PI / 2;
    this.swingArc.position.y = 0.25;
    scene.add(this.swingArc);

    // Input.
    this.keys = new Set();
    addEventListener('keydown', (e) => {
      if (e.repeat) return;
      this.keys.add(e.code);
      if (e.code === 'KeyJ') this.tryAttack();
      if (e.code === 'Space') { e.preventDefault(); this.tryDodge(); }
      if (e.code === 'KeyF') this.net.send({ t: 'rest' });
    });
    addEventListener('keyup', (e) => this.keys.delete(e.code));
    addEventListener('mousedown', (e) => { if (e.button === 0 && !e.target.closest('.overlay')) this.tryAttack(); });
  }

  spendStamina(cost) {
    if (this.stamina < cost) return false;
    this.stamina -= cost;
    this._staminaBlock = STAMINA_DELAY;
    return true;
  }

  tryAttack() {
    if (this.dead || this.state === 'dodge') return;
    if (this.state === 'attack') {
      if (this._comboWindow > 0 && this._attackIndex === 1) this._queuedCombo = true;
      return;
    }
    if (!this.spendStamina(COST_ATTACK)) return;
    this._startAttack(1);
  }

  _startAttack(index) {
    this.state = 'attack';
    this._attackIndex = index;
    this._attackT = index === 1 ? ATTACK_1_DURATION : ATTACK_2_DURATION;
    this._comboWindow = 0;
    // Investida na direção olhada.
    this.vel.x = this.facing.x * ATTACK_LUNGE * (index === 2 ? 1.3 : 1);
    this.vel.z = this.facing.z * ATTACK_LUNGE * (index === 2 ? 1.3 : 1);
    // Informa o servidor (ele decide o dano nos inimigos).
    this.net.send({ t: 'attack', combo: index, dx: this.facing.x, dz: this.facing.z });
    // Arco visual.
    this.swingArc.material.opacity = 0.85;
    this.swingArc.material.color.setHex(index === 2 ? 0xffc46b : 0xffe9a8);
    this.fx.shake(0.12);
  }

  tryDodge() {
    if (this.dead || this.state === 'dodge' || this.state === 'attack') return;
    if (!this.spendStamina(COST_DODGE)) return;
    const input = this._inputDir();
    this._dodgeDir.copy(input.lengthSq() > 0 ? input : this.facing).normalize();
    this._dodgeT = 0;
    this.state = 'dodge';
    // Poeira do sertão.
    this.fx.burst(this.pos.clone().addScaledVector(this._dodgeDir, -0.3), 0x73593f, 10, 2.4, 0.45);
  }

  _inputDir() {
    const d = new THREE.Vector3();
    if (this.keys.has('KeyW') || this.keys.has('ArrowUp')) d.z -= 1;
    if (this.keys.has('KeyS') || this.keys.has('ArrowDown')) d.z += 1;
    if (this.keys.has('KeyA') || this.keys.has('ArrowLeft')) d.x -= 1;
    if (this.keys.has('KeyD') || this.keys.has('ArrowRight')) d.x += 1;
    if (d.lengthSq() > 1) d.normalize();
    return d;
  }

  onHurt(dmg, fromX, fromZ) {
    // Knockback para longe da origem.
    const kx = this.pos.x - fromX, kz = this.pos.z - fromZ;
    const kd = Math.hypot(kx, kz) || 1;
    this.vel.x = (kx / kd) * 5;
    this.vel.z = (kz / kd) * 5;
    flashMesh(this.mesh, 0xff3030, 1.2);
    setTimeout(() => unflashMesh(this.mesh), 140);
  }

  onDeath() {
    this.dead = true;
    this.state = 'dead';
    this.iframes = true;
    this.mesh.visible = false;
  }

  onRespawn(x, z, hp) {
    this.dead = false;
    this.state = 'idle';
    this.iframes = false;
    this.hp = hp;
    this.pos.set(x, 0, z);
    this.vel.set(0, 0, 0);
    this.stamina = STAMINA_MAX;
    this.mesh.visible = true;
    this._camPos.copy(this.pos).add(CAM_OFFSET);
  }

  update(dt) {
    if (this.dead) {
      this._updateCamera(dt);
      return;
    }

    // Stamina.
    if (this._staminaBlock > 0) this._staminaBlock -= dt;
    else this.stamina = Math.min(STAMINA_MAX, this.stamina + STAMINA_REGEN * dt);

    if (this._comboWindow > 0) this._comboWindow -= dt;

    switch (this.state) {
      case 'idle':
      case 'move': this._updateLocomotion(dt); break;
      case 'attack': this._updateAttack(dt); break;
      case 'dodge': this._updateDodge(dt); break;
    }

    // Integra e resolve colisões.
    this.pos.x += this.vel.x * dt;
    this.pos.z += this.vel.z * dt;
    const solved = resolveColliders(this.pos.x, this.pos.z, 0.42);
    this.pos.x = solved.x;
    this.pos.z = solved.z;

    // Aplica no mesh + rotação suave.
    this.mesh.position.set(this.pos.x, this.mesh.position.y, this.pos.z);
    const targetRy = Math.atan2(this.facing.x, this.facing.z);
    this.ry = lerpAngle(this.ry, targetRy, Math.min(1, dt * TURN_SMOOTH));
    this.mesh.rotation.y = this.ry;

    // Bob de caminhada.
    const speed = Math.hypot(this.vel.x, this.vel.z);
    this._walkT = (this._walkT || 0) + dt * (speed > 0.5 ? 9 : 0);
    this.mesh.position.y = Math.abs(Math.sin(this._walkT)) * (speed > 0.5 ? 0.07 : 0);

    // Arco do golpe segue o jogador e some.
    this.swingArc.position.x = this.pos.x;
    this.swingArc.position.z = this.pos.z;
    this.swingArc.rotation.z = -Math.atan2(this.facing.z, this.facing.x);
    if (this.swingArc.material.opacity > 0) {
      this.swingArc.material.opacity = Math.max(0, this.swingArc.material.opacity - dt * 6);
    }

    this._updateCamera(dt);
  }

  _updateLocomotion(dt) {
    const input = this._inputDir();
    if (input.lengthSq() > 0) {
      this.facing.copy(input).normalize();
      this.vel.x = moveToward(this.vel.x, input.x * MOVE_SPEED, ACCEL * dt);
      this.vel.z = moveToward(this.vel.z, input.z * MOVE_SPEED, ACCEL * dt);
      this.state = 'move';
    } else {
      this.vel.x = moveToward(this.vel.x, 0, FRICTION * dt);
      this.vel.z = moveToward(this.vel.z, 0, FRICTION * dt);
      this.state = 'idle';
    }
  }

  _updateAttack(dt) {
    this.vel.x *= 1 - Math.min(1, dt * 8);
    this.vel.z *= 1 - Math.min(1, dt * 8);
    this._attackT -= dt;
    if (this._attackT > 0) return;
    if (this._attackIndex === 1) {
      this._comboWindow = COMBO_WINDOW;
      if (this._queuedCombo && this.spendStamina(COST_ATTACK * 0.8)) {
        this._queuedCombo = false;
        this._startAttack(2);
        return;
      }
    }
    this._attackIndex = 0;
    this._queuedCombo = false;
    this.state = 'idle';
  }

  _updateDodge(dt) {
    this._dodgeT += dt;
    const t = this._dodgeT / DODGE_DURATION;
    this.iframes = this._dodgeT >= IFRAME_START && this._dodgeT <= IFRAME_END;
    // Corpo azulado durante os iframes.
    if (this.iframes) flashMesh(this.mesh, 0x3d6fd9, 0.5);
    else unflashMesh(this.mesh);

    const speedMult = 1 - easeIn(t, 2.2);
    this.vel.x = this._dodgeDir.x * DODGE_SPEED * speedMult;
    this.vel.z = this._dodgeDir.z * DODGE_SPEED * speedMult;

    if (this._dodgeT >= DODGE_DURATION) {
      this.iframes = false;
      unflashMesh(this.mesh);
      this.state = 'idle';
    }
  }

  _updateCamera(dt) {
    const target = this.pos.clone().add(CAM_OFFSET);
    const k = 1 - Math.exp(-CAM_FOLLOW * dt);
    this._camPos.lerp(target, k);
    const shakeOff = this.fx.cameraOffset();
    this.camera.position.set(
      this._camPos.x + shakeOff.x,
      this._camPos.y + shakeOff.y,
      this._camPos.z
    );
    this.camera.lookAt(this._camPos.x - CAM_OFFSET.x, 0.6, this._camPos.z - CAM_OFFSET.z);
  }

  stateMsg() {
    return {
      t: 'state',
      x: round2(this.pos.x), z: round2(this.pos.z), ry: round2(this.ry),
      anim: this.state, iframes: this.iframes,
    };
  }
}

function moveToward(v, target, delta) {
  if (Math.abs(target - v) <= delta) return target;
  return v + Math.sign(target - v) * delta;
}
function easeIn(t, p) { return Math.pow(Math.min(1, Math.max(0, t)), p); }
function lerpAngle(a, b, t) {
  let d = (b - a) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return a + d * t;
}
function round2(v) { return Math.round(v * 100) / 100; }
