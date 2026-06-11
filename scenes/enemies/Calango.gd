class_name Calango
extends CharacterBody3D

## Calango — inimigo básico do Sertão.
## Máquina de estados: PATROL → CHASE → ATTACK → FLEE (HP < 20%)
## Em co-op a IA roda só no servidor; clientes recebem posição/rotação pelo
## MultiplayerSynchronizer e os efeitos visuais por RPC.

# ─── Tunáveis por instância (permitem variantes: Cangaceiro, etc.) ───────────
@export var max_hp: int = 80
@export var amago_reward: int = 50
@export var attack_damage: int = 15
@export var patrol_speed: float = 2.2
@export var chase_speed: float = 4.5
@export var flee_speed: float = 5.0
@export var detection_range: float = 12.0
@export var attack_cooldown: float = 1.6

# ─── Parâmetros de IA fixos (metros) ──────────────────────────────────────────
const ATTACK_RANGE: float = 1.8
const FLEE_HP_RATIO: float = 0.2
const PATROL_WAIT: float = 2.0
const PATROL_RADIUS: float = 4.0
const KNOCKBACK_FORCE: float = 6.0
const GRAVITY: float = 20.0
const HITBOX_REACH: float = 1.0

enum State { PATROL, CHASE, ATTACK, HURT, FLEE, DEAD }

@onready var health: HealthComponent = $HealthComponent
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var detection_area: Area3D = $DetectionArea

var current_state: State = State.PATROL
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _patrol_wait_timer: float = 0.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _target: Node3D = null
var _spawn_position: Vector3
var _base_albedo: Color = Color(0.85, 0.2, 0.15)

func _ready() -> void:
	add_to_group("enemy")
	_spawn_position = global_position
	health.max_health = max_hp
	health.current_health = max_hp
	attack_hitbox.damage = attack_damage
	attack_hitbox.knockback_force = KNOCKBACK_FORCE
	attack_hitbox.position = Vector3(0.0, 0.6, HITBOX_REACH)
	health.died.connect(_on_died)
	health.health_changed.connect(_check_flee)
	hurtbox.hurt.connect(_on_hurt)
	detection_area.body_entered.connect(_on_body_detected)
	detection_area.body_exited.connect(_on_body_lost)
	if body_mesh.material_override:
		body_mesh.material_override = body_mesh.material_override.duplicate()
		_base_albedo = (body_mesh.material_override as StandardMaterial3D).albedo_color
	_generate_patrol_points()

func _generate_patrol_points() -> void:
	_patrol_points.clear()
	for i in range(4):
		var angle := float(i) * TAU / 4.0 + randf() * 0.5
		_patrol_points.append(_spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * PATROL_RADIUS)

func _physics_process(delta: float) -> void:
	# Clientes não simulam IA: o synchronizer move as réplicas.
	if not multiplayer.is_server():
		return
	match current_state:
		State.PATROL:  _process_patrol(delta)
		State.CHASE:   _process_chase(delta)
		State.ATTACK:  _process_attack(delta)
		State.HURT:    _process_hurt(delta)
		State.FLEE:    _process_flee(delta)
		State.DEAD:    pass

# ─── Patrulha ────────────────────────────────────────────────────────────────

func _process_patrol(delta: float) -> void:
	if _patrol_wait_timer > 0.0:
		_patrol_wait_timer -= delta
		_halt(delta)
		_play_anim("idle")
		return

	var target_pt := _patrol_points[_patrol_index]
	var to_pt := target_pt - global_position
	to_pt.y = 0.0
	if to_pt.length() < 0.4:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_wait_timer = PATROL_WAIT
		return

	var dir := to_pt.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	_face_direction(dir)
	_play_anim("walk")
	_apply_gravity(delta)
	move_and_slide()

# ─── Perseguição ──────────────────────────────────────────────────────────────

func _process_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		current_state = State.PATROL
		return

	var dist := global_position.distance_to(_target.global_position)

	if dist > detection_range * 1.6:
		current_state = State.PATROL
		_target = null
		return

	if dist <= ATTACK_RANGE:
		current_state = State.ATTACK
		return

	var dir := (_target.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_face_direction(dir)
	_play_anim("walk")
	_apply_gravity(delta)
	move_and_slide()

# ─── Ataque ──────────────────────────────────────────────────────────────────

func _process_attack(delta: float) -> void:
	_halt(delta)

	if _attack_timer > 0.0:
		_attack_timer -= delta
		return

	if _is_attacking:
		return

	if not is_instance_valid(_target):
		current_state = State.PATROL
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist > ATTACK_RANGE * 1.3:
		current_state = State.CHASE
		return

	_do_attack()

func _do_attack() -> void:
	_is_attacking = true
	_attack_timer = attack_cooldown
	_play_anim("attack")
	if is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		_face_direction(to_target.normalized())

	# Telegrafa para TODOS os jogadores (clientes precisam ver o aviso p/ esquivar).
	_attack_fx.rpc()

	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_callback(func() -> void:
		if current_state == State.ATTACK:
			attack_hitbox.monitoring = true
	)
	tween.tween_interval(0.14)
	tween.tween_callback(func() -> void:
		attack_hitbox.monitoring = false
		_is_attacking = false
	)

# ─── Fuga ────────────────────────────────────────────────────────────────────

func _process_flee(delta: float) -> void:
	if not is_instance_valid(_target):
		current_state = State.PATROL
		return

	var flee_dir := (global_position - _target.global_position)
	flee_dir.y = 0.0
	flee_dir = flee_dir.normalized()
	velocity.x = flee_dir.x * flee_speed
	velocity.z = flee_dir.z * flee_speed
	_face_direction(flee_dir)
	_play_anim("walk")
	_apply_gravity(delta)
	move_and_slide()

# ─── Dano ────────────────────────────────────────────────────────────────────

func _on_hurt(damage: int, source_position: Vector3) -> void:
	if current_state == State.DEAD:
		return
	health.take_damage(damage)
	var knockback := (global_position - source_position)
	knockback.y = 0.0
	knockback = knockback.normalized() * 4.0
	velocity.x = knockback.x
	velocity.z = knockback.z
	current_state = State.HURT
	_play_anim("hurt")
	# Feedback do golpe em todos os peers (flash, número de dano, partículas).
	_hurt_fx.rpc(damage)

func _process_hurt(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 0.22)
	velocity.z = lerpf(velocity.z, 0.0, 0.22)
	_apply_gravity(delta)
	move_and_slide()
	# Retorna ao combate logo após o tranco.
	if velocity.length() < 0.5 and is_instance_valid(_target):
		current_state = State.CHASE

func _check_flee(current_hp: int, max_hp_now: int) -> void:
	if float(current_hp) / float(max_hp_now) < FLEE_HP_RATIO:
		current_state = State.FLEE

func _on_died() -> void:
	current_state = State.DEAD
	attack_hitbox.monitoring = false
	hurtbox.is_invincible = true
	velocity = Vector3.ZERO
	_play_anim("death")
	_death_fx.rpc()
	# Dissolve o corpo (encolhe) enquanto some. Visual:scale é replicado.
	var fade := create_tween()
	fade.tween_interval(0.4)
	fade.tween_property(visual, "scale", Vector3.ZERO, 0.8)
	get_tree().create_timer(1.8).timeout.connect(queue_free)

# ─── Efeitos replicados (rodam em todos os peers) ────────────────────────────

@rpc("authority", "call_local", "reliable")
func _attack_fx() -> void:
	# Telegrafa o ataque: pulsa um aviso amarelo durante o windup.
	if body_mesh.material_override:
		var tele := create_tween()
		tele.tween_property(body_mesh.material_override, "albedo_color", Color(1.4, 1.1, 0.3), 0.16)
		tele.tween_property(body_mesh.material_override, "albedo_color", _base_albedo, 0.04)

@rpc("authority", "call_local", "reliable")
func _hurt_fx(damage: int) -> void:
	_flash(Color(2.5, 2.5, 2.5))
	Juice.spawn_damage_number(global_position, damage, false)
	Juice.hitstop(0.05, 0.06)
	Juice.shake(0.35)
	Juice.burst(global_position, Color(0.9, 0.25, 0.2), 6, 3.0, 0.35)

@rpc("authority", "call_local", "reliable")
func _death_fx() -> void:
	# Explosão de Âmago dourado e tremor ao matar. Recompensa compartilhada:
	# cada peer credita o próprio Âmago (loot co-op amigável).
	AmagoManager.add(amago_reward)
	Juice.burst(global_position, Juice.AMAGO_COLOR, 18, 5.0, 0.7)
	Juice.shake(0.5)
	Juice.hitstop(0.08, 0.05)

# ─── Detecção ────────────────────────────────────────────────────────────────

func _on_body_detected(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("player") and current_state == State.PATROL:
		_target = body
		current_state = State.CHASE

func _on_body_lost(_body: Node3D) -> void:
	pass

# ─── Spawn pelo EnemySpawner ─────────────────────────────────────────────────

func reset_to_spawn() -> void:
	global_position = _spawn_position
	current_state = State.PATROL
	_target = null
	health.set_max_health(max_hp, true)
	hurtbox.is_invincible = false
	_attack_timer = 0.0
	_is_attacking = false
	visual.scale = Vector3.ONE
	_set_albedo(_base_albedo)
	_generate_patrol_points()
	show()

# ─── Utilidades ──────────────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

func _halt(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()

func _face_direction(dir: Vector3) -> void:
	if dir.length() > 0.01:
		var target_y := atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_y, 0.4)

func _set_albedo(color: Color) -> void:
	if body_mesh.material_override:
		(body_mesh.material_override as StandardMaterial3D).albedo_color = color

func _flash(color: Color, duration: float = 0.12) -> void:
	if body_mesh.material_override == null:
		return
	_set_albedo(color)
	var tween := create_tween()
	tween.tween_property(body_mesh.material_override, "albedo_color", _base_albedo, duration)

func _play_anim(_anim_name: String) -> void:
	# Sem animações ainda (placeholders de malha). Stub para futura AnimationPlayer.
	pass
