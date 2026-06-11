class_name LevelBase
extends Node3D

## Base das fases jogáveis. Cuida do que toda fase precisa em co-op:
## spawn de jogadores (local e remotos via MultiplayerSpawner), portais em
## rede, respawn no Cruzeiro e o Rastro de Âmago.
## Fases concretas implementam _level_setup().
##
## Estrutura mínima esperada na cena:
##   PlayerSpawn (Marker3D), Players (Node3D),
##   PlayerSpawner (MultiplayerSpawner com Player.tscn → ../Players)

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const AMAGO_GHOST_SCENE: PackedScene = preload("res://scenes/world/AmagoGhost.tscn")

@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var players_root: Node3D = $Players

func _ready() -> void:
	GameManager.player_respawned.connect(_on_respawn)
	AmagoManager.ghost_spawned.connect(_on_ghost_spawned)
	_level_setup()
	# O servidor (ou o modo solo) spawna o próprio corpo; clientes pedem o
	# deles ao servidor via NetworkManager.level_loaded().
	if multiplayer.is_server():
		spawn_player_for(multiplayer.get_unique_id())
	NetworkManager.level_loaded()
	# Rastro deixado nesta fase numa visita anterior ainda está de pé?
	if AmagoManager.has_ghost() and AmagoManager.get_ghost_level() == scene_file_path:
		_on_ghost_spawned(AmagoManager.get_ghost_position(), AmagoManager.get_ghost_amount())

## Hook das fases concretas (portais, checkpoint padrão, música...).
func _level_setup() -> void:
	pass

## Servidor: cria o corpo de um jogador. Replicado aos clientes pelo spawner.
func spawn_player_for(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var pname := str(peer_id)
	if players_root.has_node(pname):
		return
	var p := PLAYER_SCENE.instantiate()
	p.name = pname
	players_root.add_child(p, true)
	# Espalha os jogadores lado a lado no ponto de spawn.
	var idx := players_root.get_child_count() - 1
	p.global_position = player_spawn.global_position + Vector3(1.4 * idx, 0.0, 0.0)

func despawn_player_for(peer_id: int) -> void:
	var p := players_root.get_node_or_null(str(peer_id))
	if p:
		p.queue_free()

## O jogador controlado por ESTA máquina.
func get_local_player() -> Player:
	return players_root.get_node_or_null(str(multiplayer.get_unique_id())) as Player

## Portal entre fases: só o servidor decide a viagem (e leva todos juntos).
func _use_portal(body: Node3D, level_path: String) -> void:
	if not body.is_in_group("player"):
		return
	if not multiplayer.is_server():
		return
	NetworkManager.change_level(level_path)

func _on_respawn(at_position: Vector3) -> void:
	var p := get_local_player()
	if is_instance_valid(p):
		p.respawn(at_position)

func _on_ghost_spawned(at_position: Vector3, _amount: int) -> void:
	var g := AMAGO_GHOST_SCENE.instantiate()
	add_child(g)
	g.global_position = at_position
