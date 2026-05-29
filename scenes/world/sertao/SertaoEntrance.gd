## Entrada do Sertão — primeira área de combate após o Hub.
## Contém spawners de Calango e um Cruzeiro.
extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@onready var enemy_spawner: Node2D = $EnemySpawner

var _player: Player

func _ready() -> void:
	GameManager.player_respawned.connect(_on_respawn)
	_spawn_player()

func _spawn_player() -> void:
	_player = player_scene.instantiate() as Player
	add_child(_player)
	_player.global_position = player_spawn.global_position
	var hud := get_node_or_null("HUD")
	if hud:
		(hud as HUD).connect_player(_player)

func _on_respawn(at_position: Vector2) -> void:
	if is_instance_valid(_player):
		_player.respawn(at_position)
	else:
		_spawn_player()
		_player.global_position = at_position
