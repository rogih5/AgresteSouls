// Agreste Souls — ponto de entrada do cliente.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

import { Net } from './net.js';
import { buildWorld, CRUZEIROS } from './world.js';
import { EntityRegistry, flashMesh, unflashMesh } from './entities.js';
import { FX } from './fx.js';
import { HUD } from './hud.js';
import { LocalPlayer } from './player.js';

// ─── Renderer / cena ─────────────────────────────────────────────────────────
const canvas = document.getElementById('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setSize(innerWidth, innerHeight);
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(50, innerWidth / innerHeight, 0.1, 500);
camera.position.set(10, 15, 33);

const worldRefs = buildWorld(scene);

// Pós-processamento: bloom dá o brilho de Âmago/Cruzeiro/lua.
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.45, 0.55, 0.82);
composer.addPass(bloom);
composer.addPass(new OutputPass());

addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  composer.setSize(innerWidth, innerHeight);
});

// ─── Sistemas ────────────────────────────────────────────────────────────────
const fx = new FX(scene);
const hud = new HUD();
const registry = new EntityRegistry(scene);
const net = new Net();

let player = null;
let myId = null;
let ghostMesh = null;

// ─── Menu ────────────────────────────────────────────────────────────────────
const menu = document.getElementById('menu');
const nameInput = document.getElementById('name-input');
const playButton = document.getElementById('play-button');
const menuStatus = document.getElementById('menu-status');
nameInput.value = localStorage.getItem('agreste_name') || '';

playButton.addEventListener('click', startGame);
nameInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') startGame(); });

async function startGame() {
  const name = nameInput.value.trim() || 'Retirante';
  localStorage.setItem('agreste_name', name);
  playButton.disabled = true;
  menuStatus.textContent = 'Conectando ao sertão…';
  try {
    await net.connect();
  } catch {
    menuStatus.textContent = 'Não foi possível conectar. O servidor está rodando?';
    playButton.disabled = false;
    return;
  }
  net.send({ t: 'join', name });
}

// ─── Mensagens do servidor ───────────────────────────────────────────────────
net.on('welcome', (msg) => {
  myId = msg.id;
  player = new LocalPlayer(scene, camera, fx, net, nameInput.value.trim() || 'Retirante');
  player.pos.set(msg.spawn.x, 0, msg.spawn.z);
  worldRefs.applyLunar(msg.lunar.phase);
  hud.setLunar(msg.lunar.icon, msg.lunar.name);
  hud.setAmago(msg.amago);
  hud.setHp(480, 480);
  for (const p of msg.players) if (p.id !== myId) registry.addRemotePlayer(p);
  for (const e of msg.enemies) registry.addEnemy(e);
  menu.classList.add('hidden');
  hud.show();
});

net.on('snap', (msg) => {
  if (!player) return;
  registry.applySnapshot(msg, myId);
  hud.setPlayers(msg.players.map(p => p.id === myId ? `${p.name} (você)` : p.name));
});

net.on('player_joined', (msg) => registry.addRemotePlayer(msg.p));
net.on('player_left', (msg) => registry.removeRemotePlayer(msg.id));

net.on('lunar', (msg) => {
  worldRefs.applyLunar(msg.phase);
  hud.setLunar(msg.icon, msg.name);
});

net.on('amago', (msg) => {
  hud.setAmago(msg.amago);
  if (msg.gained > 0 && player) {
    fx.burst(player.pos, 0xf2c75a, 10, 3.5, 0.6);
  }
});

net.on('enemy_hurt', (msg) => {
  fx.damageNumber({ x: msg.x, z: msg.z }, msg.dmg);
  fx.burst({ x: msg.x, z: msg.z }, 0xb33326, 6, 3, 0.35);
  fx.hitstop(0.055, 0.08);
  fx.shake(0.25);
  const en = registry.enemies.get(msg.id);
  if (en) {
    flashMesh(en.group, 0xffffff, 1.4);
    setTimeout(() => { if (en.state !== 'windup') unflashMesh(en.group); }, 110);
  }
});

net.on('enemy_died', (msg) => {
  fx.burst({ x: msg.x, z: msg.z }, 0xf2c75a, 20, 5, 0.7);
  fx.damageNumber({ x: msg.x, z: msg.z }, `+${msg.reward}`, '#ffd76b');
  fx.hitstop(0.08, 0.06);
  fx.shake(0.45);
});

net.on('enemy_windup', (msg) => {
  const en = registry.enemies.get(msg.id);
  if (en) flashMesh(en.group, 0xe6b830, 1.1);
});

net.on('enemy_struck', (msg) => {
  const en = registry.enemies.get(msg.id);
  if (en) unflashMesh(en.group);
});

net.on('player_hurt', (msg) => {
  if (msg.id === myId && player) {
    player.hp = msg.hp;
    hud.setHp(msg.hp, player.maxHp);
    hud.damageFlash();
    player.onHurt(msg.dmg, msg.fromX, msg.fromZ);
    fx.damageNumber(player.pos, msg.dmg, '#ff7a6b');
    fx.hitstop(0.08, 0.05);
    fx.shake(0.7);
  } else {
    const rp = registry.remotePlayers.get(msg.id);
    if (rp) {
      flashMesh(rp.group, 0xff3030, 1.0);
      setTimeout(() => unflashMesh(rp.group), 130);
    }
  }
});

net.on('player_died', (msg) => {
  if (msg.id === myId && player) {
    player.onDeath();
    hud.setHp(0, player.maxHp);
    hud.showDeath(true);
    fx.shake(1.0);
  }
  fx.burst({ x: msg.x, z: msg.z }, 0x6b1d20, 16, 4, 0.7);
});

net.on('respawn', (msg) => {
  if (!player) return;
  player.onRespawn(msg.x, msg.z, msg.hp);
  hud.setHp(msg.hp, player.maxHp);
  hud.showDeath(false);
});

net.on('hp', (msg) => {
  if (!player) return;
  player.hp = msg.hp;
  hud.setHp(msg.hp, msg.maxHp);
});

net.on('rested', (msg) => {
  fx.burst({ x: msg.x, z: msg.z }, 0xf2e3a0, 24, 5, 1.0);
  if (player) fx.burst(player.pos, 0x8ce08a, 14, 4, 0.7);
});

net.on('ghost_spawned', (msg) => {
  removeGhost();
  ghostMesh = makeGhost(msg.x, msg.z);
  scene.add(ghostMesh);
  hud.showGhostHint(true);
});

net.on('ghost_collected', (msg) => {
  if (player) fx.burst(player.pos, 0xf2c75a, 18, 4.5, 0.7);
  removeGhost();
  hud.showGhostHint(false);
});

net.on('ghost_lost', () => {
  removeGhost();
  hud.showGhostHint(false);
});

net.on('_closed', () => {
  menuStatus.textContent = 'Conexão perdida. Recarregue a página.';
  menu.classList.remove('hidden');
  playButton.disabled = false;
});

function makeGhost(x, z) {
  const g = new THREE.Group();
  const orb = new THREE.Mesh(
    new THREE.SphereGeometry(0.32, 16, 16),
    new THREE.MeshStandardMaterial({
      color: 0xffe9a8, emissive: 0xf2c75a, emissiveIntensity: 2.2, roughness: 0.4,
    })
  );
  orb.position.y = 1.0;
  const light = new THREE.PointLight(0xf2c75a, 4, 6, 1.6);
  light.position.y = 1.2;
  g.add(orb, light);
  g.position.set(x, 0, z);
  g.userData.orb = orb;
  return g;
}
function removeGhost() {
  if (ghostMesh) { scene.remove(ghostMesh); ghostMesh = null; }
}

// ─── Loop principal ──────────────────────────────────────────────────────────
const clock = new THREE.Clock();
let stateTimer = 0;
let ghostPulse = 0;

function loop() {
  requestAnimationFrame(loop);
  const realDt = Math.min(0.05, clock.getDelta());
  fx.update(realDt);
  const dt = realDt * fx.timeScale;

  if (player) {
    player.update(dt);
    registry.update(dt);
    hud.setStamina(player.stamina, 220);

    // Prompt do Cruzeiro.
    const nearCruzeiro = CRUZEIROS.some(c => Math.hypot(player.pos.x - c.x, player.pos.z - c.z) < 3);
    hud.showPrompt(nearCruzeiro && !player.dead);

    // Envia estado ~20 Hz.
    stateTimer += realDt;
    if (stateTimer >= 0.05) {
      stateTimer = 0;
      net.send(player.stateMsg());
    }
  }

  // Pulso do Rastro de Âmago.
  if (ghostMesh) {
    ghostPulse += realDt * 2.4;
    const s = 1 + Math.sin(ghostPulse) * 0.22;
    ghostMesh.userData.orb.scale.setScalar(s);
  }

  composer.render();
}
loop();
