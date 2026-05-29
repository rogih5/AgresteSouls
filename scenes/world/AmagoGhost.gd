class_name AmagoGhost
extends Area2D

## Rastro de Âmago — orbe deixado no local da morte do jogador.
## O jogador deve retornar ao local para recuperar o Âmago perdido.
## Desaparece após GHOST_LIFETIME_SECS segundos ou se o jogador morrer novamente.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $AmountLabel
@onready var orb: Polygon2D = $Orb
@onready var orb_glow: Polygon2D = $OrbGlow

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Sincroniza posição com AmagoManager
	global_position = AmagoManager.get_ghost_position()
	_update_label()
	_start_pulse()
	AmagoManager.ghost_lost.connect(_on_ghost_expired)

## Pulsação contínua do orbe (respiração de brilho + giro do halo).
func _start_pulse() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(orb, "scale", Vector2(1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(orb, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	var halo := create_tween().set_loops()
	halo.tween_property(orb_glow, "scale", Vector2(1.4, 1.4), 1.0).set_trans(Tween.TRANS_SINE)
	halo.parallel().tween_property(orb_glow, "modulate:a", 0.4, 1.0)
	halo.tween_property(orb_glow, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE)
	halo.parallel().tween_property(orb_glow, "modulate:a", 1.0, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var recovered := AmagoManager.try_collect_ghost(global_position)
	if recovered > 0:
		queue_free()

func _on_ghost_expired() -> void:
	queue_free()

func _update_label() -> void:
	# Exibe o valor do Âmago perdido acima do orbe.
	var amount := AmagoManager.get_ghost_amount()
	label.text = "%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	label.add_theme_constant_override("outline_size", 4)
