## Hub principal — Arraial da Pedra Furada.
## Zona segura: ponto de retorno central, NPCs e acesso ao Sertão.
extends LevelBase

func _level_setup() -> void:
	$ExitToSertao.body_entered.connect(
		func(body: Node3D) -> void:
			_use_portal(body, "res://scenes/world/sertao/SertaoEntrance.tscn")
	)
	# Spawn do hub é o ponto de retorno padrão antes do primeiro Cruzeiro.
	GameManager.last_cruzeiro_position = player_spawn.global_position
