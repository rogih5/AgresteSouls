## Entrada do Sertão — primeira área de combate após o Hub.
## Contém spawners de Calango e Cangaceiro e um Cruzeiro.
extends LevelBase

func _level_setup() -> void:
	$BackToHub.body_entered.connect(
		func(body: Node3D) -> void:
			_use_portal(body, "res://scenes/world/hub/Hub.tscn")
	)
