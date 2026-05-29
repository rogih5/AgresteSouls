class_name HurtboxComponent
extends Area2D

signal hurt(damage: int, source_position: Vector2)

var is_invincible: bool = false

func receive_hit(damage: int, source_position: Vector2, _knockback_force: float) -> void:
	if is_invincible:
		return
	hurt.emit(damage, source_position)
