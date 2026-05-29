## Tinge todo o canvas 2D do mundo conforme a fase lunar atual.
## Anexar a um nó CanvasModulate na raiz de cada cena de mundo.
## NÃO afeta CanvasLayer (HUD), apenas o mundo — a UI continua legível.
extends CanvasModulate

## Cor de luz ambiente por fase (valores > 1.0 clareiam, < 1.0 escurecem).
const PHASE_COLORS: Dictionary = {
	0: Color(0.28, 0.30, 0.52),  # Lua Nova — escuridão azulada
	1: Color(0.52, 0.52, 0.66),  # Quarto Crescente — penumbra
	2: Color(0.82, 0.82, 0.88),  # Meia Lua Crescente — neutro
	3: Color(0.92, 0.90, 0.82),  # Gibosa Crescente — quente suave
	4: Color(1.12, 1.10, 0.98),  # Lua Cheia — claridade prateada
	5: Color(0.80, 0.76, 0.74),  # Gibosa Minguante — frio
	6: Color(0.58, 0.54, 0.60),  # Meia Lua Minguante — sombrio
	7: Color(0.38, 0.36, 0.46),  # Quarto Minguante — agonia
}

const TRANSITION_SECS: float = 2.5

func _ready() -> void:
	LunarClock.phase_changed.connect(_on_phase_changed)
	color = _color_for(LunarClock.current_phase)

func _on_phase_changed(new_phase: int, _old_phase: int) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "color", _color_for(new_phase), TRANSITION_SECS)

func _color_for(phase: int) -> Color:
	return PHASE_COLORS.get(int(phase), Color.WHITE)
