## Ilumina o mundo 3D conforme a fase lunar atual.
## Anexar a um DirectionalLight3D na raiz de cada cena de mundo,
## com um WorldEnvironment irmão (para a luz ambiente).
extends DirectionalLight3D

## Configuração de luz por fase: cor/energia da lua + luz ambiente.
const PHASE_LIGHT: Dictionary = {
	0: {"color": Color(0.45, 0.50, 0.85), "energy": 0.25, "ambient": Color(0.08, 0.09, 0.16)},  # Lua Nova
	1: {"color": Color(0.60, 0.62, 0.85), "energy": 0.50, "ambient": Color(0.12, 0.13, 0.20)},  # Quarto Crescente
	2: {"color": Color(0.78, 0.80, 0.95), "energy": 0.80, "ambient": Color(0.17, 0.18, 0.24)},  # Meia Lua Crescente
	3: {"color": Color(0.92, 0.88, 0.80), "energy": 1.00, "ambient": Color(0.20, 0.19, 0.22)},  # Gibosa Crescente
	4: {"color": Color(1.00, 0.98, 0.90), "energy": 1.30, "ambient": Color(0.24, 0.24, 0.30)},  # Lua Cheia
	5: {"color": Color(0.80, 0.78, 0.80), "energy": 0.90, "ambient": Color(0.18, 0.17, 0.20)},  # Gibosa Minguante
	6: {"color": Color(0.60, 0.56, 0.68), "energy": 0.60, "ambient": Color(0.13, 0.12, 0.18)},  # Meia Lua Minguante
	7: {"color": Color(0.45, 0.42, 0.58), "energy": 0.35, "ambient": Color(0.09, 0.08, 0.14)},  # Quarto Minguante
}

const TRANSITION_SECS: float = 2.5

@onready var _env: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")

func _ready() -> void:
	LunarClock.phase_changed.connect(_on_phase_changed)
	_apply(LunarClock.current_phase, true)

func _on_phase_changed(new_phase: int, _old_phase: int) -> void:
	_apply(new_phase, false)

func _apply(phase: int, instant: bool) -> void:
	var cfg: Dictionary = PHASE_LIGHT.get(int(phase), PHASE_LIGHT[2])
	if instant:
		light_color = cfg.color
		light_energy = cfg.energy
		if _env and _env.environment:
			_env.environment.ambient_light_color = cfg.ambient
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "light_color", cfg.color, TRANSITION_SECS)
	tween.tween_property(self, "light_energy", cfg.energy, TRANSITION_SECS)
	if _env and _env.environment:
		tween.tween_property(_env.environment, "ambient_light_color", cfg.ambient, TRANSITION_SECS)
