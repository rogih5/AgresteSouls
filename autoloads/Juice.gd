## Autoload singleton: "game juice" procedural (3D) — hitstop, screen shake,
## números de dano flutuantes e rajadas de partículas.
## Não tem class_name (acessado pelo nome registrado: Juice).
extends Node

## Cor do Âmago para partículas (dourado sépia).
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

# ─── Números de dano (Label3D no mundo) ──────────────────────────────────────
func spawn_damage_number(world_pos: Vector3, amount: int, is_crit: bool = false) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lbl := Label3D.new()
	lbl.text = str(amount)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.012 if is_crit else 0.008
	lbl.outline_size = 12
	lbl.modulate = Color(1.0, 0.85, 0.2) if is_crit else Color(1.0, 0.95, 0.85)
	lbl.outline_modulate = Color(0.05, 0.03, 0.02)
	lbl.position = world_pos + Vector3(randf_range(-0.3, 0.3), 1.4, randf_range(-0.3, 0.3))
	root.add_child(lbl)

	var rise := 1.2 if is_crit else 0.8
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + rise, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)

# ─── Rajada de partículas (CPUParticles3D) ───────────────────────────────────
func burst(world_pos: Vector3, color: Color, amount: int = 12, speed: float = 4.0, lifetime: float = 0.5) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles3D.new()
	p.position = world_pos + Vector3(0.0, 0.6, 0.0)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0           # emissão em todas as direções
	p.gravity = Vector3(0.0, -6.0, 0.0)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	p.color = color
	# Material emissivo simples para as partículas brilharem um pouco.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	p.material_override = mat
	p.mesh = QuadMesh.new()
	root.add_child(p)
	# Auto-remoção após terminar.
	var t := get_tree().create_timer(lifetime + 0.4)
	t.timeout.connect(p.queue_free)
