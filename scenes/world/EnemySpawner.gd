## Gerenciador de spawn de inimigos.
## Instancia inimigos nos Marker3D filhos e os respawna ao descansar no Cruzeiro.
## Em co-op, só o servidor spawna — o MultiplayerSpawner da cena replica
## os inimigos para os clientes.
extends Node3D

@export var enemy_scene: PackedScene

var _markers: Array[Marker3D] = []
var _enemies: Array = []
var _spawn_counter: int = 0

func _ready() -> void:
	add_to_group("enemy_spawner")
	for child in get_children():
		if child is Marker3D:
			_markers.append(child)
	_enemies.resize(_markers.size())
	if multiplayer.is_server() and enemy_scene:
		_spawn_missing()

func _spawn_missing() -> void:
	for i in _markers.size():
		if is_instance_valid(_enemies[i]):
			continue
		var enemy := enemy_scene.instantiate()
		# Nome único e legível: obrigatório para a replicação em rede.
		enemy.name = "%s_%d" % [name, _spawn_counter]
		_spawn_counter += 1
		get_parent().add_child(enemy, true)
		enemy.global_position = _markers[i].global_position
		_enemies[i] = enemy

## Chamado pelo GameManager e pelo Cruzeiro ao descansar.
## Reseta os vivos e re-instancia os mortos (comportamento souls).
func respawn_all() -> void:
	if not multiplayer.is_server():
		return
	for enemy in _enemies:
		if is_instance_valid(enemy) and enemy.has_method("reset_to_spawn"):
			enemy.reset_to_spawn()
	_spawn_missing()
