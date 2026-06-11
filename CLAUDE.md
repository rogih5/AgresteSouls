# Agreste Souls — CLAUDE.md
## Convenções e Arquitetura do Projeto

---

## Visão Geral

**Gênero:** Action RPG Soulslike com estética de xilogravura nordestina  
**Engine:** Godot 4.7 (renderer Forward+, projeto 3D)  
**Perspectiva:** 3D com câmera top-down angulada (follow suave; movimento no plano XZ)  
**Unidades:** metros (1 unidade = 1 m). Chão em Y=0, "para cima" = +Y.  
**Multiplayer:** co-op até 4 jogadores (ENet, host = servidor). Solo = modo offline.  
**Referência:** Dark Souls 1 (mundo interconectado, punição por morte, checkpoints)

---

## Estrutura de Pastas

```
AgresteSouls/
├── autoloads/          — Singletons acessíveis globalmente (sem class_name para evitar conflito)
├── scenes/
│   ├── player/         — Player.gd + Player.tscn
│   ├── enemies/        — Um subdiretório por tipo (Calango/, Cangaceiro/, etc.)
│   ├── world/          — Cruzeiro, AmagoGhost, EnemySpawner
│   │   ├── hub/        — Arraial da Pedra Furada
│   │   └── sertao/     — Biomas do Sertão
│   └── ui/             — HUD.gd + HUD.tscn (e futuros menus)
├── scripts/
│   ├── resources/      — Recursos (PlayerStats, ItemData, WeaponData)
│   └── components/     — Nós reutilizáveis (Health, Stamina, Hitbox, Hurtbox)
└── assets/
    ├── sprites/        — Separados por entidade (player/, enemies/, world/, ui/)
    ├── audio/          — sfx/ e music/
    └── fonts/          — Tipografia de xilogravura
```

---

## Singletons (Autoloads)

| Nome             | Arquivo                          | Responsabilidade                              |
|------------------|----------------------------------|-----------------------------------------------|
| `LunarClock`     | `autoloads/LunarClock.gd`        | Ciclo lunar: 8 fases × 10 min = 80 min/ciclo  |
| `AmagoManager`   | `autoloads/AmagoManager.gd`      | Âmago (moeda/XP), Rastro pós-morte            |
| `GameManager`    | `autoloads/GameManager.gd`       | Estado global, morte, respawn, Cruzeiros      |
| `Juice`          | `autoloads/Juice.gd`             | Hitstop, shake, números de dano, partículas   |
| `NetworkManager` | `autoloads/NetworkManager.gd`    | Co-op: hospedar/entrar, troca de fase, sync   |

**Regra:** Autoloads NÃO têm `class_name`. São acessados pelo nome registrado (ex.: `LunarClock.current_phase`).  
**Ordem de carregamento:** LunarClock → AmagoManager → GameManager → Juice → NetworkManager.

---

## Arquitetura Multiplayer (co-op)

- **Host = servidor.** Menu principal oferece Solo (offline), Hospedar e Entrar (IP).
- **Jogadores:** autoridade do próprio peer (nome do nó = id do peer; `_enter_tree` chama
  `set_multiplayer_authority`). Movimento local responsivo; posição/rotação replicadas
  por `MultiplayerSynchronizer`.
- **Inimigos:** IA roda SÓ no servidor (`if not multiplayer.is_server(): return`).
  Réplicas recebem posição via synchronizer; efeitos visuais (telegraph, flash, morte)
  via RPCs `@rpc("authority", "call_local", "reliable")`.
- **Dano:** `HurtboxComponent.receive_hit` roteia por RPC até o peer dono
  (`_net_hurt.rpc_id(get_multiplayer_authority(), ...)`); invencibilidade é checada no dono.
- **Fases:** estendem `LevelBase` (scripts/world/LevelBase.gd) — spawn de jogadores via
  `MultiplayerSpawner` (nó `Players`), portais decididos pelo servidor
  (`NetworkManager.change_level`), Rastro de Âmago local por peer.
- **Cenas de fase precisam de:** `PlayerSpawn` (Marker3D), `Players` (Node3D),
  `PlayerSpawner` (MultiplayerSpawner → ../Players) e, se houver inimigos, um
  `MultiplayerSpawner` com as cenas dos inimigos apontando para a raiz.
- **Modo solo funciona offline:** o `MultiplayerAPI` padrão (OfflineMultiplayerPeer) faz
  `is_server()` retornar `true` e RPCs `call_local` rodarem localmente.

---

## Componentes Reutilizáveis

| Classe             | Tipo    | Uso                                                  |
|--------------------|---------|------------------------------------------------------|
| `HealthComponent`  | Node    | HP de qualquer entidade; emite `died` e `health_changed` |
| `StaminaComponent` | Node    | Stamina com regen automático; delay configurável     |
| `HitboxComponent`  | Area3D  | Detecta HurtboxComponent e entrega dano              |
| `HurtboxComponent` | Area3D  | Recebe dano via RPC no peer dono, respeita `is_invincible` |

---

## Camadas de Colisão

| Camada | Bit | Valor | Quem usa                            |
|--------|-----|-------|-------------------------------------|
| 1      | 0   | 1     | Geometria de mundo (StaticBody3D)   |
| 2      | 1   | 2     | Corpo do Player (CharacterBody3D)   |
| 3      | 2   | 4     | Corpo dos Inimigos (CharacterBody3D)|
| 4      | 3   | 8     | AttackHitbox do Player (Area3D)     |
| 5      | 4   | 16    | AttackHitbox dos Inimigos (Area3D)  |
| 6      | 5   | 32    | Hurtbox do Player (Area3D)          |
| 7      | 6   | 64    | Hurtbox dos Inimigos (Area3D)       |
| 8      | 7   | 128   | Coletáveis (AmagoGhost, itens)      |
| 9      | 8   | 256   | Áreas de interação (Cruzeiro, portas)|

**Regra de detecção para hitboxes:**
- Player HitboxComponent: `collision_mask = 64` (detecta hurtbox de inimigos)
- Enemy HitboxComponent: `collision_mask = 32` (detecta hurtbox do player)
- DetectionArea (Calango): `collision_mask = 2` (detecta corpo do player)

---

## Sistema de Atributos (PlayerStats)

| Atributo    | Nome BR   | Derivados                                     | Soft Cap |
|-------------|-----------|-----------------------------------------------|----------|
| `raiz`      | RAIZ      | HP (+18/pt até 20, +12 até 40, +8 acima)     | 40       |
| `folego`    | FÔLEGO    | Stamina (+12/pt até 20, +8 até 30, +4 acima) | 30       |
| `braco`     | BRAÇO     | Dano de ataque, Poise                         | —        |
| `ginga`     | GINGA     | Crítico (+0.5%/pt), velocidade ataque, iframes| 40/50    |
| `saberes`   | SABERES   | Magia elemental (fogo/natureza)               | 50       |
| `crenca`    | CRENÇA    | Milagres, defesa vs. maldição                 | 45       |
| `mandinga`  | MANDINGA  | Drop rate, loot lunar                         | 30       |

---

## Sistema Lunar (LunarClock)

Ciclo completo: **80 minutos** de tempo real de jogo (8 fases × 10 min).  
O jogador **não controla o tempo** — apenas se prepara.  
Descansar no Cruzeiro avança **1 fase** (mas respawna inimigos).

| Fase | Nome BR               | Modificador Principal                        |
|------|-----------------------|----------------------------------------------|
| 🌑 0 | Lua Nova              | Inimigos ×3, Loot ×0.8, Visão reduzida       |
| 🌒 1 | Quarto Crescente      | Magia de fogo -10% Âmago                     |
| 🌓 2 | Meia Lua Crescente    | Estado neutro                                |
| 🌔 3 | Gibosa Crescente      | Regen stamina +10%, curas -10% custo         |
| 🌕 4 | Lua Cheia             | Loot ×3, inimigos +30% agressivos, Mula Sem Cabeça |
| 🌖 5 | Gibosa Minguante      | Magia de Crença -15% Âmago                   |
| 🌗 6 | Meia Lua Minguante    | -10% HP máx, +20% Âmago ao matar             |
| 🌘 7 | Quarto Minguante      | -1% HP/min fora de área segura, Corpo-Seco   |

---

## Âmago (AmagoManager)

- Coletado automaticamente ao matar inimigos.
- Ao morrer: 100% depositado como **Rastro de Âmago** no local da morte.
- Rastro persiste **20 minutos** de jogo real.
- Morrer antes de recuperar o Rastro → **perdido permanentemente**.
- Multiplicador na Meia Lua Minguante: **×1.2**.

---

## Cruzeiro (Checkpoint)

- **E** (perto do Cruzeiro) → abre menu de evolução de atributos.
- **F** → descansa: cura total, avança 1 fase lunar, respawna inimigos.
- Teleporte para qualquer Cruzeiro já descoberto (futura UI).
- Tipos especiais: **Amaldiçoado** (precisa purificar), **Lunar** (aparece só numa fase).

---

## Convenções de GDScript 4

```gdscript
# Nomes de variáveis: snake_case
var current_state: State = State.IDLE

# Constantes: SCREAMING_SNAKE_CASE
const MOVE_SPEED: float = 200.0

# Sinais: snake_case, sem prefixo "on_"
signal health_changed(current: int, maximum: int)

# Funções internas (não API pública): prefixo _
func _process_locomotion(delta: float) -> void: ...

# Enums: PascalCase no nome, SCREAMING_SNAKE em valores
enum State { IDLE, MOVING, ATTACK_1, DODGING, DEAD }

# Tipos sempre explícitos em funções públicas
func take_damage(amount: int) -> void: ...

# @onready antes de var, @export em recursos
@onready var health: HealthComponent = $HealthComponent
@export_range(1, 99) var raiz: int = 10

# Nunca usar await dentro de _physics_process — usar Tween ou timer var
var tween := create_tween()
tween.tween_interval(0.15)
tween.tween_callback(func() -> void: hitbox.monitoring = true)
```

---

## Grupos de Nodes

| Grupo           | Quem adiciona                | Usado por                            |
|-----------------|------------------------------|--------------------------------------|
| `"player"`      | Player._ready()              | Cruzeiro, detecção de inimigos       |
| `"enemy"`       | Calango._ready()             | AoE effects, contagem                |
| `"enemy_spawner"` | EnemySpawner._ready()      | GameManager, Cruzeiro (respawn)      |
| `"cruzeiro"`    | Cruzeiro._ready()            | GameManager (on_respawn)             |

---

## Pipeline de Assets

- **Modelos/Malhas:** placeholders com primitivas (`CapsuleMesh`, `BoxMesh`, `SphereMesh`) + `StandardMaterial3D`. Cor por instância via `material_override` (duplicado com `.duplicate()` no `_ready` para flash/iframe, pois Node3D não tem `modulate`).
- **Texturas (quando entrarem):** estilo xilogravura nordestina aplicado em albedo/emission; importar com filter `Nearest` para manter o look gravado.
- **Iluminação:** `DirectionalLight3D` (cor/energia por fase lunar via LunarAmbiance.gd) + `WorldEnvironment` (ambient, glow, fog, SSAO, tonemap ACES).
- **Texto flutuante:** `Label3D` com `billboard` (dano, quantidade de Âmago, placas).
- **Áudio:** OGG para música, WAV para SFX. Música: ambiência de zabumba, triângulo, sanfona.
- **Fontes:** Importar como `.ttf`, hinting `None` para manter look xilogravura.

---

## Controles Padrão

| Ação       | Teclado           | Mouse / Alt          |
|------------|-------------------|----------------------|
| Mover      | WASD / Setas      | —                    |
| Atacar     | J / Clique Esq.   | —                    |
| Esquivar   | Space             | —                    |
| Interagir  | E                 | —                    |
| Descansar  | F (perto Cruzeiro)| —                    |

---

## Adicionando um Novo Inimigo

**Variante simples (só números):** copie `Cangaceiro.tscn` — reusa `Calango.gd` e ajusta os
`@export` (`max_hp`, `attack_damage`, `chase_speed`, `amago_reward`, etc.) direto na cena.

**Inimigo com comportamento novo:**
1. Crie `scenes/enemies/NomeInimigo/NomeInimigo.gd` extendendo `CharacterBody3D`.
2. Copie a estrutura de `Calango.tscn` como base (inclui `MultiplayerSynchronizer`).
3. Ajuste os `@export` e a lógica da máquina de estados (IA só no servidor!).
4. Adicione ao grupo `"enemy"` no `_ready()`.
5. Configure o `EnemySpawner` na cena destino e registre a cena no `MultiplayerSpawner` de inimigos.

---

## Fases de Desenvolvimento

| Fase | Objetivo                                           | Status   |
|------|----------------------------------------------------|----------|
| 1    | Prototipagem: Player, Calango, Âmago, Lunar, Hub   | ✅ Base criada |
| 2    | Arte: sprites xilogravura, tileset, SFX/música     | —        |
| 3    | Conteúdo: 3 biomas, 8 inimigos, 3 bosses           | —        |
| 4    | Sistema de armas, encantamentos, Forja Benedito    | —        |
| 5    | Eventos lunares: Mula Sem Cabeça, Boitatá, Corpo-Seco | —    |
| 6    | Polimento, NG+, balanceamento final                | —        |
