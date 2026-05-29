class_name HitboxComponent
extends Area2D

signal hit_landed(target: Node, damage: int)

@export var damage: int = 10
@export var knockback_force: float = 200.0

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		if hurtbox.owner == owner:
			return
		hurtbox.receive_hit(damage, global_position, knockback_force)
		hit_landed.emit(hurtbox.owner, damage)
