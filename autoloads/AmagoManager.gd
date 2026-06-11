## Autoload singleton: Âmago — moeda, XP e mecânica de perda/recuperação.
## O Âmago é perdido ao morrer e deixa um "Rastro" no local da morte.
## Morrer antes de recuperar o Rastro o destrói permanentemente.
extends Node

signal amago_changed(new_amount: int)
signal ghost_spawned(at_position: Vector3, amount: int)
signal ghost_collected(amount: int)
signal ghost_lost

## Quantos minutos o Rastro persiste (20 minutos reais de jogo)
const GHOST_LIFETIME_SECS: float = 1200.0
## Raio de atração automática em metros
const AUTO_ATTRACT_RADIUS: float = 3.0

var current_amago: int = 0

var _ghost_active: bool = false
var _ghost_position: Vector3 = Vector3.ZERO
var _ghost_level: String = ""
var _ghost_amount: int = 0
var _ghost_timer: float = 0.0

func _process(delta: float) -> void:
	if _ghost_active:
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_destroy_ghost()

## Adiciona Âmago, aplicando multiplicador lunar.
func add(amount: int) -> void:
	var mult := _get_lunar_mult()
	current_amago += int(float(amount) * mult)
	amago_changed.emit(current_amago)

## Tenta gastar Âmago. Retorna false se insuficiente.
func spend(amount: int) -> bool:
	if current_amago < amount:
		return false
	current_amago -= amount
	amago_changed.emit(current_amago)
	return true

func has_enough(amount: int) -> bool:
	return current_amago >= amount

## Chamado pelo GameManager quando o jogador morre.
func on_player_death() -> void:
	if current_amago == 0:
		return
	if _ghost_active:
		_destroy_ghost()
	_ghost_amount = current_amago
	_ghost_position = Vector3.ZERO  # sobrescrito pelo chamador via spawn_ghost_at
	current_amago = 0
	amago_changed.emit(current_amago)

## Instancia o Rastro no mundo. Chamado pelo Player ao morrer.
func spawn_ghost_at(world_position: Vector3) -> void:
	if _ghost_amount <= 0:
		return
	_ghost_position = world_position
	# Guarda em qual fase o Rastro ficou, para reaparecer ao revisitar.
	var scene := get_tree().current_scene
	_ghost_level = scene.scene_file_path if scene else ""
	_ghost_active = true
	_ghost_timer = GHOST_LIFETIME_SECS
	ghost_spawned.emit(_ghost_position, _ghost_amount)

## Tenta coletar o Rastro de uma posição. Retorna o valor recuperado (0 se falhou).
func try_collect_ghost(collector_position: Vector3) -> int:
	if not _ghost_active:
		return 0
	if collector_position.distance_to(_ghost_position) > AUTO_ATTRACT_RADIUS * 2.0:
		return 0
	var recovered := _ghost_amount
	_ghost_active = false
	_ghost_amount = 0
	_ghost_timer = 0.0
	current_amago += recovered
	amago_changed.emit(current_amago)
	ghost_collected.emit(recovered)
	return recovered

func get_ghost_position() -> Vector3:
	return _ghost_position

## Caminho da cena onde o Rastro foi deixado.
func get_ghost_level() -> String:
	return _ghost_level

func get_ghost_amount() -> int:
	return _ghost_amount

func has_ghost() -> bool:
	return _ghost_active

func _destroy_ghost() -> void:
	_ghost_active = false
	_ghost_amount = 0
	_ghost_timer = 0.0
	ghost_lost.emit()

func _get_lunar_mult() -> float:
	if LunarClock.current_phase == LunarClock.Phase.MEIA_LUA_MINGUANTE:
		return 1.2
	return 1.0
