## Autoload singleton: "game juice" procedural — hitstop, screen shake,
## números de dano flutuantes e rajadas de partículas.
## Não tem class_name (acessado pelo nome registrado: Juice).
extends Node

## Cor padrão do Âmago para partículas (dourado sépia).
const AMAGO_COLOR: Color = Color(0.95, 0.78, 0.35)
## Cor de cura no Cruzeiro (verde-claro).
const HEAL_COLOR: Color = Color(0.55, 0.95, 0.55)

var _hitstop_token: int = 0

# ─── Hitstop ───────────────────────────────────────────────────────────────
## Congela brevemente o tempo para dar peso ao impacto.
func hitstop(duration: float = 0.06, scale: float = 0.05) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = scale
	# Timer que IGNORA o time_scale, senão nunca dispararia durante o congelamento.
	var t := get_tree().create_timer(duration, true, false, true)
	await t.timeout
	# Só restaura se nenhum outro hitstop tomou o controle nesse meio tempo.
	if token == _hitstop_token:
		Engine.time_scale = 1.0

# ─── Screen shake ──────────────────────────────────────────────────────────
## Sacode a câmera do jogador. amount entre 0.0 e 1.0.
func shake(amount: float = 0.4) -> void:
	get_tree().call_group("player", "add_shake", amount)

# ─── Números de dano ────────────────────────────────────────────────────────
func spawn_damage_number(world_pos: Vector2, amount: int, is_crit: bool = false) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lbl := Label.new()
	lbl.text = str(amount)
	lbl.z_index = 100
	lbl.position = world_pos + Vector2(randf_range(-6.0, 6.0), -20.0)
	lbl.add_theme_font_size_override("font_size", 20 if is_crit else 14)
	var col := Color(1.0, 0.85, 0.2) if is_crit else Color(1.0, 0.95, 0.85)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	lbl.add_theme_constant_override("outline_size", 4)
	root.add_child(lbl)

	var rise := -28.0 if is_crit else -20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + rise, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)

# ─── Rajada de partículas ────────────────────────────────────────────────────
func burst(world_pos: Vector2, color: Color, amount: int = 12, speed: float = 130.0, lifetime: float = 0.5) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	p.position = world_pos
	p.z_index = 50
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0           # 180° de cada lado = círculo completo
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = color
	root.add_child(p)
	# Auto-remoção após terminar.
	var t := get_tree().create_timer(lifetime + 0.4)
	t.timeout.connect(p.queue_free)
