class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)
signal stamina_depleted

@export var max_stamina: float = 100.0
@export var regen_rate: float = 30.0
## Delay em segundos antes de começar a regenerar após uso
@export var regen_delay: float = 1.5

var current_stamina: float
var _regen_timer: float = 0.0
var _blocked: bool = false

func _ready() -> void:
	current_stamina = max_stamina

func _process(delta: float) -> void:
	if _blocked:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			_blocked = false

	if not _blocked and current_stamina < max_stamina:
		current_stamina = minf(max_stamina, current_stamina + regen_rate * delta)
		stamina_changed.emit(current_stamina, max_stamina)

## Tenta gastar stamina. Retorna false se insuficiente.
func spend(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina -= amount
	_blocked = true
	_regen_timer = regen_delay
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		stamina_depleted.emit()
	return true

func has_enough(amount: float) -> bool:
	return current_stamina >= amount

func set_max_stamina(value: float) -> void:
	max_stamina = value
	current_stamina = minf(current_stamina, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)

func get_stamina_ratio() -> float:
	return current_stamina / max_stamina
