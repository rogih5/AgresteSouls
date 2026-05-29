## Autoload singleton: relógio lunar com 8 fases de 10 minutos cada.
## Total do ciclo: ~80 minutos de tempo real de jogo.
extends Node

enum Phase {
	LUA_NOVA,           ## A Boca da Noite — escuridão total, inimigos triplicam
	QUARTO_CRESCENTE,   ## A Abertura — névoa baixa, magias de fogo mais baratas
	MEIA_LUA_CRESCENTE, ## O Meio Caminho — estado neutro, visibilidade boa
	GIBOSA_CRESCENTE,   ## A Promessa — curas mais baratas, +10% regen de stamina
	LUA_CHEIA,          ## O Olho do Céu — loot triplicado, inimigos +30% agressivos
	GIBOSA_MINGUANTE,   ## O Peso do Fim — magias de Crença mais baratas
	MEIA_LUA_MINGUANTE, ## A Rachadura — -10% HP máx, +20% Âmago ao matar
	QUARTO_MINGUANTE,   ## A Agonia — perde 1% HP/min fora de área segura
}

signal phase_changed(new_phase: Phase, old_phase: Phase)

const PHASE_DURATION_SECS: float = 600.0  # 10 minutos por fase
const TRANSITION_SECS: float = 120.0      # 2 minutos de fade entre fases
const TOTAL_CYCLE_SECS: float = PHASE_DURATION_SECS * 8.0

const PHASE_NAMES: Dictionary = {
	0: "Lua Nova — A Boca da Noite",
	1: "Quarto Crescente — A Abertura",
	2: "Meia Lua Crescente — O Meio Caminho",
	3: "Gibosa Crescente — A Promessa",
	4: "Lua Cheia — O Olho do Céu",
	5: "Gibosa Minguante — O Peso do Fim",
	6: "Meia Lua Minguante — A Rachadura",
	7: "Quarto Minguante — A Agonia",
}

const PHASE_ICONS: Array[String] = [
	"🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"
]

var current_phase: Phase = Phase.LUA_NOVA
var cycle_time: float = 0.0
var is_paused: bool = false

func _process(delta: float) -> void:
	if is_paused:
		return

	cycle_time += delta
	if cycle_time >= TOTAL_CYCLE_SECS:
		cycle_time -= TOTAL_CYCLE_SECS

	var new_phase: Phase = int(cycle_time / PHASE_DURATION_SECS)
	if new_phase != current_phase:
		var old := current_phase
		current_phase = new_phase
		phase_changed.emit(current_phase, old)

## Avança manualmente uma fase (usado no Cruzeiro ao descansar).
func advance_one_phase() -> void:
	var next_index: int = (int(current_phase) + 1) % 8
	cycle_time = float(next_index) * PHASE_DURATION_SECS
	var old := current_phase
	current_phase = next_index
	phase_changed.emit(current_phase, old)

## Retorna o progresso dentro da fase atual (0.0–1.0).
func get_phase_progress() -> float:
	return fmod(cycle_time, PHASE_DURATION_SECS) / PHASE_DURATION_SECS

## Retorna true se estiver nos 2 min de transição para a próxima fase.
func is_transitioning() -> bool:
	return fmod(cycle_time, PHASE_DURATION_SECS) > (PHASE_DURATION_SECS - TRANSITION_SECS)

func get_phase_name() -> String:
	return PHASE_NAMES.get(int(current_phase), "")

func get_phase_icon() -> String:
	return PHASE_ICONS[int(current_phase)]

## Retorna o dicionário de modificadores ativos da fase atual.
func get_current_modifiers() -> Dictionary:
	match current_phase:
		Phase.LUA_NOVA:
			return {"enemy_spawn_mult": 3.0, "loot_mult": 0.8, "vision_range_mult": 0.5}
		Phase.QUARTO_CRESCENTE:
			return {"fire_cost_mult": 0.9}
		Phase.MEIA_LUA_CRESCENTE:
			return {}
		Phase.GIBOSA_CRESCENTE:
			return {"stamina_regen_mult": 1.1, "cure_cost_mult": 0.9}
		Phase.LUA_CHEIA:
			return {"loot_mult": 3.0, "enemy_aggression_mult": 1.3, "spawn_mula": true}
		Phase.GIBOSA_MINGUANTE:
			return {"faith_cost_mult": 0.85}
		Phase.MEIA_LUA_MINGUANTE:
			return {"max_hp_mult": 0.9, "amago_kill_mult": 1.2, "portals_active": true}
		Phase.QUARTO_MINGUANTE:
			return {"passive_hp_drain_per_sec": 1.0 / 60.0, "corpo_seco_active": true}
		_:
			return {}
