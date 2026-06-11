class_name HurtboxComponent
extends Area3D

signal hurt(damage: int, source_position: Vector3)

var is_invincible: bool = false

## Pode ser chamada em qualquer peer (quem detectou o golpe). O dano é
## roteado por RPC até o peer dono da entidade: servidor para inimigos,
## o próprio cliente para o seu jogador. Em solo, executa localmente.
func receive_hit(damage: int, source_position: Vector3, _knockback_force: float) -> void:
	_net_hurt.rpc_id(get_multiplayer_authority(), damage, source_position)

@rpc("any_peer", "call_local", "reliable")
func _net_hurt(damage: int, source_position: Vector3) -> void:
	# A invencibilidade é checada aqui, no dono, onde o estado é confiável
	# (ex.: iframes da esquiva só existem no peer que controla o jogador).
	if is_invincible:
		return
	hurt.emit(damage, source_position)
