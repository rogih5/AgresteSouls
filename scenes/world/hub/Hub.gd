## Hub principal — Arraial da Pedra Furada.
## Ponto de retorno central, NPCs e acesso ao Sertão.
extends Node2D

@onready var hud: HUD = $HUD
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")

var _player: Player

func _ready() -> void:
	GameManager.player_respawned.connect(_on_respawn)
	# Define o spawn do hub como ponto de retorno padrão antes de qualquer Cruzeiro ser tocado
	GameManager.last_cruzeiro_position = player_spawn.global_position
	_spawn_player()

func _spawn_player() -> void:
	_player = player_scene.instantiate() as Player
	add_child(_player)
	_player.global_position = player_spawn.global_position
	hud.connect_player(_player)

func _on_respawn(at_position: Vector2) -> void:
	if is_instance_valid(_player):
		_player.respawn(at_position)
	else:
		_spawn_player()
		_player.global_position = at_position
