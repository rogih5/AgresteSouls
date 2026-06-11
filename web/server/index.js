// Agreste Souls — servidor co-op.
// Autoritativo para inimigos, dano, Âmago, Rastro, relógio lunar e descanso
// no Cruzeiro. Jogadores enviam o próprio estado (movimento client-authority,
// igual à arquitetura da versão Godot).
import express from 'express';
import http from 'http';
import path from 'path';
import { fileURLToPath } from 'url';
import { WebSocketServer } from 'ws';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT || 8087;

const app = express();
app.use(express.static(path.join(__dirname, '..', 'public')));
app.use('/vendor/three', express.static(path.join(__dirname, '..', 'node_modules', 'three')));

const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// ─── Constantes de jogo (espelham o projeto Godot) ──────────────────────────
const TICK_MS = 50;                 // 20 Hz
const PLAYER_MAX_HP = 480;
const ATTACK_RANGE = 2.2;           // alcance do golpe do jogador (m)
const ATTACK_ARC_COS = Math.cos(Math.PI / 3); // cone de 120°
const PLAYER_DMG = [25, 32];        // golpe 1, golpe 2 do combo
const RESPAWN_SECS = 2.5;
const GHOST_LIFETIME_SECS = 1200;
const PHASE_SECS = 300;             // fase lunar: 5 min (8 fases por ciclo)

const SAFE_X = 22;                  // a oeste disso é zona segura (hub)

const ENEMY_TYPES = {
  calango: {
    maxHp: 80, dmg: 15, reward: 50,
    patrolSpeed: 2.2, chaseSpeed: 4.5, fleeSpeed: 5.0,
    detection: 12, attackRange: 1.9, cooldown: 1.6, windup: 0.34,
  },
  cangaceiro: {
    maxHp: 160, dmg: 28, reward: 120,
    patrolSpeed: 2.6, chaseSpeed: 5.5, fleeSpeed: 4.0,
    detection: 16, attackRange: 2.0, cooldown: 1.3, windup: 0.30,
  },
};

const ENEMY_SPAWNS = [
  { type: 'calango', x: 30, z: 22 },
  { type: 'calango', x: 36, z: 14 },
  { type: 'calango', x: 36, z: 30 },
  { type: 'calango', x: 44, z: 10 },
  { type: 'calango', x: 44, z: 34 },
  { type: 'cangaceiro', x: 58, z: 14 },
  { type: 'cangaceiro', x: 58, z: 30 },
  { type: 'cangaceiro', x: 68, z: 22 },
];

const SPAWN_POINT = { x: 10, z: 22 };
const CRUZEIROS = [{ x: 14, z: 22 }, { x: 30, z: 38 }];

const PHASE_NAMES = [
  'Lua Nova', 'Quarto Crescente', 'Meia Lua Crescente', 'Gibosa Crescente',
  'Lua Cheia', 'Gibosa Minguante', 'Meia Lua Minguante', 'Quarto Minguante',
];
const PHASE_ICONS = ['🌑', '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘'];

// ─── Estado do mundo ─────────────────────────────────────────────────────────
const players = new Map();   // id -> player
const enemies = new Map();   // id -> enemy
let nextPlayerId = 1;
let nextEnemyId = 1;
let lunarPhase = 2;          // começa na Meia Lua Crescente (neutra)
let lunarTimer = 0;

function spawnEnemy(spawn) {
  const cfg = ENEMY_TYPES[spawn.type];
  const id = `e${nextEnemyId++}`;
  enemies.set(id, {
    id, type: spawn.type, cfg,
    x: spawn.x, z: spawn.z, ry: 0,
    spawnX: spawn.x, spawnZ: spawn.z,
    hp: cfg.maxHp,
    state: 'patrol',         // patrol | chase | windup | flee | dead
    targetId: null,
    patrolAngle: Math.random() * Math.PI * 2,
    waitTimer: Math.random() * 2,
    cooldownTimer: 0,
    windupTimer: 0,
    deadTimer: 0,
    kx: 0, kz: 0,            // knockback residual
  });
}
ENEMY_SPAWNS.forEach(spawnEnemy);

// ─── Utilidades ──────────────────────────────────────────────────────────────
function broadcast(msg, exceptId = null) {
  const data = JSON.stringify(msg);
  for (const p of players.values()) {
    if (p.id !== exceptId && p.ws.readyState === 1) p.ws.send(data);
  }
}
function send(p, msg) {
  if (p.ws.readyState === 1) p.ws.send(JSON.stringify(msg));
}
function dist(ax, az, bx, bz) {
  return Math.hypot(ax - bx, az - bz);
}
function amagoMult() {
  return lunarPhase === 6 ? 1.2 : 1.0; // Meia Lua Minguante: +20%
}
function aggroMult() {
  return lunarPhase === 4 ? 1.3 : 1.0; // Lua Cheia: inimigos mais rápidos
}

// ─── Conexões ────────────────────────────────────────────────────────────────
wss.on('connection', (ws) => {
  const id = `p${nextPlayerId++}`;
  const player = {
    id, ws,
    name: 'Retirante',
    x: SPAWN_POINT.x + (players.size * 1.4), z: SPAWN_POINT.z, ry: 0,
    anim: 'idle', iframes: false,
    hp: PLAYER_MAX_HP, maxHp: PLAYER_MAX_HP,
    dead: false, respawnTimer: 0,
    amago: 0,
    ghost: null,             // { x, z, amount, timer }
    checkpoint: { ...CRUZEIROS[0] },
    lastAttack: 0,
  };
  players.set(id, player);

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    handleMessage(player, msg);
  });

  ws.on('close', () => {
    players.delete(id);
    broadcast({ t: 'player_left', id });
  });
});

function handleMessage(p, msg) {
  switch (msg.t) {
    case 'join': {
      p.name = String(msg.name || 'Retirante').slice(0, 16);
      send(p, {
        t: 'welcome',
        id: p.id,
        lunar: { phase: lunarPhase, name: PHASE_NAMES[lunarPhase], icon: PHASE_ICONS[lunarPhase] },
        amago: p.amago,
        spawn: { x: p.x, z: p.z },
        players: [...players.values()].map(publicPlayer),
        enemies: [...enemies.values()].map(publicEnemy),
      });
      broadcast({ t: 'player_joined', p: publicPlayer(p) }, p.id);
      break;
    }
    case 'state': {
      if (p.dead) break;
      p.x = Number(msg.x) || 0;
      p.z = Number(msg.z) || 0;
      p.ry = Number(msg.ry) || 0;
      p.anim = String(msg.anim || 'idle');
      p.iframes = Boolean(msg.iframes);
      break;
    }
    case 'attack': {
      if (p.dead) break;
      const now = Date.now();
      if (now - p.lastAttack < 250) break;   // anti-spam
      p.lastAttack = now;
      const combo = msg.combo === 2 ? 2 : 1;
      const dmg = PLAYER_DMG[combo - 1];
      const dx = Number(msg.dx) || 0, dz = Number(msg.dz) || 1;
      for (const e of enemies.values()) {
        if (e.state === 'dead') continue;
        const ex = e.x - p.x, ez = e.z - p.z;
        const d = Math.hypot(ex, ez);
        if (d > ATTACK_RANGE) continue;
        const dot = d > 0.001 ? (ex * dx + ez * dz) / d : 1;
        if (dot < ATTACK_ARC_COS) continue;
        hurtEnemy(e, dmg, p);
      }
      break;
    }
    case 'rest': {
      // Precisa estar perto de um Cruzeiro.
      const near = CRUZEIROS.find(c => dist(p.x, p.z, c.x, c.z) < 3.0);
      if (!near || p.dead) break;
      p.hp = p.maxHp;
      p.checkpoint = { ...near };
      for (const e of enemies.values()) resetEnemy(e);
      lunarPhase = (lunarPhase + 1) % 8;
      lunarTimer = 0;
      broadcast({ t: 'rested', by: p.id, x: near.x, z: near.z });
      broadcast({
        t: 'lunar',
        phase: lunarPhase, name: PHASE_NAMES[lunarPhase], icon: PHASE_ICONS[lunarPhase],
      });
      send(p, { t: 'hp', hp: p.hp, maxHp: p.maxHp });
      break;
    }
  }
}

function publicPlayer(p) {
  return { id: p.id, name: p.name, x: p.x, z: p.z, ry: p.ry, anim: p.anim, hp: p.hp, maxHp: p.maxHp, dead: p.dead };
}
function publicEnemy(e) {
  return { id: e.id, type: e.type, x: e.x, z: e.z, ry: e.ry, hp: e.hp, maxHp: e.cfg.maxHp, state: e.state };
}

// ─── Combate ─────────────────────────────────────────────────────────────────
function hurtEnemy(e, dmg, attacker) {
  e.hp -= dmg;
  // Knockback para longe do atacante.
  const kx = e.x - attacker.x, kz = e.z - attacker.z;
  const kd = Math.hypot(kx, kz) || 1;
  e.kx = (kx / kd) * 4.0;
  e.kz = (kz / kd) * 4.0;
  if (e.hp <= 0) {
    e.hp = 0;
    e.state = 'dead';
    e.deadTimer = 0;
    const reward = Math.round(e.cfg.reward * amagoMult());
    // Recompensa compartilhada (co-op amigável).
    for (const p of players.values()) {
      p.amago += reward;
      send(p, { t: 'amago', amago: p.amago, gained: reward });
    }
    broadcast({ t: 'enemy_died', id: e.id, x: e.x, z: e.z, reward });
  } else {
    if (e.state === 'patrol') { e.state = 'chase'; e.targetId = attacker.id; }
    broadcast({ t: 'enemy_hurt', id: e.id, dmg, x: e.x, z: e.z, hp: e.hp });
  }
}

function hurtPlayer(p, dmg, fromX, fromZ) {
  if (p.dead || p.iframes) return;
  p.hp -= dmg;
  if (p.hp <= 0) {
    p.hp = 0;
    p.dead = true;
    p.respawnTimer = RESPAWN_SECS;
    // Rastro de Âmago no local da morte (perde o anterior, se houver).
    if (p.amago > 0) {
      p.ghost = { x: p.x, z: p.z, amount: p.amago, timer: GHOST_LIFETIME_SECS };
      send(p, { t: 'ghost_spawned', x: p.x, z: p.z, amount: p.amago });
      p.amago = 0;
      send(p, { t: 'amago', amago: 0, gained: 0 });
    }
    broadcast({ t: 'player_died', id: p.id, x: p.x, z: p.z });
  } else {
    broadcast({ t: 'player_hurt', id: p.id, dmg, hp: p.hp, fromX, fromZ });
  }
}

function resetEnemy(e) {
  e.x = e.spawnX; e.z = e.spawnZ;
  e.hp = e.cfg.maxHp;
  e.state = 'patrol';
  e.targetId = null;
  e.cooldownTimer = 0;
  e.windupTimer = 0;
  e.kx = 0; e.kz = 0;
}

// ─── Simulação dos inimigos ──────────────────────────────────────────────────
function nearestPlayer(e) {
  let best = null, bestD = Infinity;
  for (const p of players.values()) {
    if (p.dead) continue;
    if (p.x < SAFE_X) continue;          // zona segura do hub
    const d = dist(e.x, e.z, p.x, p.z);
    if (d < bestD) { bestD = d; best = p; }
  }
  return { player: best, d: bestD };
}

function tickEnemy(e, dt) {
  const cfg = e.cfg;
  // Knockback decai.
  if (Math.abs(e.kx) > 0.05 || Math.abs(e.kz) > 0.05) {
    e.x += e.kx * dt; e.z += e.kz * dt;
    e.kx *= 0.82; e.kz *= 0.82;
  }

  switch (e.state) {
    case 'dead': {
      e.deadTimer += dt;
      if (e.deadTimer > 25) resetEnemy(e);   // renasce sozinho após um tempo
      return;
    }
    case 'patrol': {
      const { player, d } = nearestPlayer(e);
      if (player && d < cfg.detection) {
        e.state = 'chase'; e.targetId = player.id;
        return;
      }
      if (e.waitTimer > 0) { e.waitTimer -= dt; return; }
      e.patrolAngle += dt * 0.6;
      const px = e.spawnX + Math.cos(e.patrolAngle) * 3.5;
      const pz = e.spawnZ + Math.sin(e.patrolAngle) * 3.5;
      moveToward(e, px, pz, cfg.patrolSpeed, dt);
      if (Math.random() < dt * 0.25) e.waitTimer = 1.5;
      return;
    }
    case 'chase': {
      const target = players.get(e.targetId);
      if (!target || target.dead || target.x < SAFE_X) {
        e.state = 'patrol'; e.targetId = null;
        return;
      }
      const d = dist(e.x, e.z, target.x, target.z);
      if (d > cfg.detection * 1.8) { e.state = 'patrol'; e.targetId = null; return; }
      if (e.hp < cfg.maxHp * 0.2) { e.state = 'flee'; return; }
      if (e.cooldownTimer > 0) e.cooldownTimer -= dt;
      if (d <= cfg.attackRange && e.cooldownTimer <= 0) {
        e.state = 'windup';
        e.windupTimer = cfg.windup;
        broadcast({ t: 'enemy_windup', id: e.id });
        return;
      }
      if (d > cfg.attackRange * 0.85) {
        moveToward(e, target.x, target.z, cfg.chaseSpeed * aggroMult(), dt);
      }
      return;
    }
    case 'windup': {
      e.windupTimer -= dt;
      const target = players.get(e.targetId);
      if (target && !target.dead) {
        e.ry = Math.atan2(target.x - e.x, target.z - e.z);
      }
      if (e.windupTimer <= 0) {
        e.state = 'chase';
        e.cooldownTimer = e.cfg.cooldown;
        if (target && !target.dead) {
          const d = dist(e.x, e.z, target.x, target.z);
          if (d <= e.cfg.attackRange * 1.25) {
            hurtPlayer(target, e.cfg.dmg, e.x, e.z);
          }
        }
        broadcast({ t: 'enemy_struck', id: e.id });
      }
      return;
    }
    case 'flee': {
      const target = players.get(e.targetId);
      if (!target || target.dead) { e.state = 'patrol'; e.targetId = null; return; }
      const away = Math.atan2(e.x - target.x, e.z - target.z);
      moveToward(e, e.x + Math.sin(away) * 3, e.z + Math.cos(away) * 3, e.cfg.fleeSpeed, dt);
      if (dist(e.x, e.z, target.x, target.z) > e.cfg.detection * 1.5) {
        e.state = 'patrol'; e.targetId = null;
      }
      return;
    }
  }
}

function moveToward(e, tx, tz, speed, dt) {
  const dx = tx - e.x, dz = tz - e.z;
  const d = Math.hypot(dx, dz);
  if (d < 0.05) return;
  e.x += (dx / d) * speed * dt;
  e.z += (dz / d) * speed * dt;
  e.ry = Math.atan2(dx, dz);
  // Mantém dentro da arena (limites do mundo: 1..75 x 1..43).
  e.x = Math.max(1.5, Math.min(74.5, e.x));
  e.z = Math.max(1.5, Math.min(42.5, e.z));
}

// ─── Loop principal ──────────────────────────────────────────────────────────
let lastTick = Date.now();
setInterval(() => {
  const now = Date.now();
  const dt = Math.min(0.25, (now - lastTick) / 1000);
  lastTick = now;

  // Relógio lunar.
  lunarTimer += dt;
  if (lunarTimer >= PHASE_SECS) {
    lunarTimer = 0;
    lunarPhase = (lunarPhase + 1) % 8;
    broadcast({ t: 'lunar', phase: lunarPhase, name: PHASE_NAMES[lunarPhase], icon: PHASE_ICONS[lunarPhase] });
  }

  // Inimigos.
  for (const e of enemies.values()) tickEnemy(e, dt);

  // Jogadores: respawn e Rastro.
  for (const p of players.values()) {
    if (p.dead) {
      p.respawnTimer -= dt;
      if (p.respawnTimer <= 0) {
        p.dead = false;
        p.hp = p.maxHp;
        p.x = p.checkpoint.x + 1.5;
        p.z = p.checkpoint.z;
        p.iframes = false;
        send(p, { t: 'respawn', x: p.x, z: p.z, hp: p.hp });
        broadcast({ t: 'player_respawned', id: p.id, x: p.x, z: p.z }, p.id);
      }
    }
    if (p.ghost) {
      p.ghost.timer -= dt;
      if (p.ghost.timer <= 0) {
        p.ghost = null;
        send(p, { t: 'ghost_lost' });
      } else if (!p.dead && dist(p.x, p.z, p.ghost.x, p.ghost.z) < 1.6) {
        p.amago += p.ghost.amount;
        send(p, { t: 'ghost_collected', amount: p.ghost.amount });
        send(p, { t: 'amago', amago: p.amago, gained: p.ghost.amount });
        p.ghost = null;
      }
    }
  }

  // Snapshot para todos.
  broadcast({
    t: 'snap',
    players: [...players.values()].map(publicPlayer),
    enemies: [...enemies.values()].map(publicEnemy),
  });
}, TICK_MS);

server.listen(PORT, () => {
  console.log(`Agreste Souls web — http://localhost:${PORT}`);
});
