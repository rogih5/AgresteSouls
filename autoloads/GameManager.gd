## Autoload singleton: estado global do jogo, mortes, respawn e Cruzeiros.
## Em multiplayer cada peer mantém o próprio estado (checkpoint, respawn).
extends Node

signal game_over
signal player_respawned(at_position: Vector3)
signal cruzeiro_activated(cruzeiro: Node)

var last_cruzeiro_position: Vector3 = Vector3.ZERO
var _respawning: bool = false

## Chamado pelo Cruzeiro ao ser ativado pelo jogador.
func register_cruzeiro_as_active(position: Vector3) -> void:
	last_cruzeiro_position = position
	cruzeiro_activated.emit(null)

## Chamado pelo Player ao morrer.
func handle_player_death() -> void:
	if _respawning:
		return
	_respawning = true
	AmagoManager.on_player_death()
	await get_tree().create_timer(2.0).timeout
	_do_respawn()

func _do_respawn() -> void:
	get_tree().call_group("enemy_spawner", "respawn_all")
	get_tree().call_group("cruzeiro", "on_respawn")
	player_respawned.emit(last_cruzeiro_position)
	_respawning = false
