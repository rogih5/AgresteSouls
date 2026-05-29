# Agreste Souls — CLAUDE.md
## Convenções e Arquitetura do Projeto

---

## Visão Geral

**Gênero:** Action RPG Soulslike com estética de xilogravura nordestina  
**Engine:** Godot 4.3+  
**Perspectiva:** Top-down 2D  
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

| Nome           | Arquivo                          | Responsabilidade                              |
|----------------|----------------------------------|-----------------------------------------------|
| `LunarClock`   | `autoloads/LunarClock.gd`        | Ciclo lunar: 8 fases × 10 min = 80 min/ciclo  |
| `AmagoManager` | `autoloads/AmagoManager.gd`      | Âmago (moeda/XP), Rastro pós-morte            |
| `GameManager`  | `autoloads/GameManager.gd`       | Estado global, morte, respawn, Cruzeiros      |

**Regra:** Autoloads NÃO têm `class_name`. São acessados pelo nome registrado (ex.: `LunarClock.current_phase`).  
**Ordem de carregamento:** LunarClock → AmagoManager → GameManager (AmagoManager depende de LunarClock).

---

## Componentes Reutilizáveis

| Classe             | Tipo    | Uso                                                  |
|--------------------|---------|------------------------------------------------------|
| `HealthComponent`  | Node    | HP de qualquer entidade; emite `died` e `health_changed` |
| `StaminaComponent` | Node    | Stamina com regen automático; delay configurável     |
| `HitboxComponent`  | Area2D  | Detecta HurtboxComponent e entrega dano              |
| `HurtboxComponent` | Area2D  | Recebe dano, respeita `is_invincible`                |

---

## Camadas de Colisão

| Camada | Bit | Valor | Quem usa                            |
|--------|-----|-------|-------------------------------------|
| 1      | 0   | 1     | Geometria de mundo (StaticBody2D)   |
| 2      | 1   | 2     | Corpo do Player (CharacterBody2D)   |
| 3      | 2   | 4     | Corpo dos Inimigos (CharacterBody2D)|
| 4      | 3   | 8     | AttackHitbox do Player (Area2D)     |
| 5      | 4   | 16    | AttackHitbox dos Inimigos (Area2D)  |
| 6      | 5   | 32    | Hurtbox do Player (Area2D)          |
| 7      | 6   | 64    | Hurtbox dos Inimigos (Area2D)       |
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

- **Sprites:** PNG com fundo transparente. Resolução base: 16×16 ou 32×32 px (upscale via zoom da câmera 2×).
- **Estilo:** Xilogravura nordestina — preto/branco com detalhes em sépia. Importar como `Nearest` (pixel art).
- **Áudio:** OGG para música, WAV para SFX. Música: ambiência de zabumba, triângulo, sanfona.
- **Fontes:** Importar como `.ttf`, hinting `None` para manter look xilogravura.

**Configuração de importação para sprites (pixel art):**
```
filter = false
mipmaps = false
compress/mode = 0 (Lossless)
```

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

1. Crie `scenes/enemies/NomeInimigo/NomeInimigo.gd` extendendo `CharacterBody2D`.
2. Copie a estrutura de `Calango.tscn` como base.
3. Ajuste `AMAGO_REWARD`, `ATTACK_DAMAGE`, `DETECTION_RANGE` e a lógica da máquina de estados.
4. Adicione ao grupo `"enemy"` no `_ready()`.
5. Configure o `EnemySpawner` na cena destino para usar a nova `PackedScene`.

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
