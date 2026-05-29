## Gerenciador de spawn de inimigos.
## Instancia inimigos nos Marker2D filhos e os respawna ao descansar no Cruzeiro.
extends Node2D

@export var enemy_scene: PackedScene

var _enemies: Array[Node] = []

func _ready() -> void:
	add_to_group("enemy_spawner")
	if enemy_scene:
		_spawn_all()

func _spawn_all() -> void:
	for child in get_children():
		if child is Marker2D:
			var enemy := enemy_scene.instantiate()
			get_parent().add_child(enemy)
			enemy.global_position = child.global_position
			_enemies.append(enemy)

## Chamado pelo GameManager e pelo Cruzeiro ao descansar.
func respawn_all() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("reset_to_spawn"):
				enemy.reset_to_spawn()
