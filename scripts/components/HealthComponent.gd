class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func set_max_health(value: int, also_heal: bool = false) -> void:
	max_health = value
	if also_heal:
		current_health = max_health
	else:
		current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0

func get_hp_ratio() -> float:
	return float(current_health) / float(max_health)
