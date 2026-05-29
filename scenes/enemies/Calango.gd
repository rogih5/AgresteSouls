class_name Calango
extends CharacterBody2D

## Calango — inimigo básico do Sertão.
## Máquina de estados: PATROL → CHASE → ATTACK → FLEE (HP < 20%)

# ─── Parâmetros de IA ────────────────────────────────────────────────────────
const PATROL_SPEED: float = 70.0
const CHASE_SPEED: float = 145.0
const FLEE_SPEED: float = 165.0
const DETECTION_RANGE: float = 200.0
const ATTACK_RANGE: float = 44.0
const FLEE_HP_RATIO: float = 0.2
const ATTACK_COOLDOWN: float = 1.6
const PATROL_WAIT: float = 2.0
const PATROL_RADIUS: float = 88.0
const AMAGO_REWARD: int = 50
const ATTACK_DAMAGE: int = 15
const KNOCKBACK_FORCE: float = 200.0

enum State { PATROL, CHASE, ATTACK, HURT, FLEE, DEAD }

@onready var health: HealthComponent = $HealthComponent
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var current_state: State = State.PATROL
var _patrol_points: Array[Vector2] = []
var _patrol_index: int = 0
var _patrol_wait_timer: float = 0.0
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _target: Node2D = null
var _spawn_position: Vector2

func _ready() -> void:
	add_to_group("enemy")
	_spawn_position = global_position
	health.max_health = 80
	health.current_health = 80
	attack_hitbox.damage = ATTACK_DAMAGE
	attack_hitbox.knockback_force = KNOCKBACK_FORCE
	health.died.connect(_on_died)
	health.health_changed.connect(_check_flee)
	hurtbox.hurt.connect(_on_hurt)
	detection_area.body_entered.connect(_on_body_detected)
	detection_area.body_exited.connect(_on_body_lost)
	_generate_patrol_points()

func _ready_patrol_points() -> void:
	_generate_patrol_points()

func _generate_patrol_points() -> void:
	_patrol_points.clear()
	for i in range(4):
		var angle := float(i) * TAU / 4.0 + randf() * 0.5
		_patrol_points.append(_spawn_position + Vector2(cos(angle), sin(angle)) * PATROL_RADIUS)

func _physics_process(delta: float) -> void:
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
		velocity = Vector2.ZERO
		move_and_slide()
		_play_anim("idle")
		return

	var target_pt := _patrol_points[_patrol_index]
	var dir := (target_pt - global_position)
	if dir.length() < 6.0:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_patrol_wait_timer = PATROL_WAIT
		return

	velocity = dir.normalized() * PATROL_SPEED
	_face_direction(velocity)
	_play_anim("walk")
	move_and_slide()

# ─── Perseguição ──────────────────────────────────────────────────────────────

func _process_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		current_state = State.PATROL
		return

	var dist := global_position.distance_to(_target.global_position)

	if dist > DETECTION_RANGE * 1.6:
		current_state = State.PATROL
		_target = null
		return

	if dist <= ATTACK_RANGE:
		current_state = State.ATTACK
		return

	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * CHASE_SPEED
	_face_direction(velocity)
	_play_anim("walk")
	move_and_slide()

# ─── Ataque ──────────────────────────────────────────────────────────────────

func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

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
	_attack_timer = ATTACK_COOLDOWN
	_play_anim("attack")
	_face_direction(_target.global_position - global_position if is_instance_valid(_target) else facing_direction())

	# Telegrafa o ataque: pulsa um aviso amarelo-avermelhado durante o windup.
	var tele := create_tween()
	tele.tween_property(self, "modulate", Color(1.8, 1.2, 0.4), 0.16)
	tele.tween_property(self, "modulate", Color.WHITE, 0.04)

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

	var flee_dir := (global_position - _target.global_position).normalized()
	velocity = flee_dir * FLEE_SPEED
	_face_direction(-flee_dir)
	_play_anim("walk")
	move_and_slide()

# ─── Dano ────────────────────────────────────────────────────────────────────

func _on_hurt(damage: int, source_position: Vector2) -> void:
	if current_state == State.DEAD:
		return
	health.take_damage(damage)
	velocity = (global_position - source_position).normalized() * 160.0
	current_state = State.HURT
	_play_anim("hurt")
	# Juice: feedback do golpe do jogador acertando o inimigo.
	_flash(Color(2.5, 2.5, 2.5))
	Juice.spawn_damage_number(global_position, damage, false)
	Juice.hitstop(0.05, 0.06)
	Juice.shake(0.35)
	Juice.burst(global_position, Color(0.9, 0.25, 0.2), 6, 90.0, 0.35)

func _process_hurt(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 0.22)
	move_and_slide()

func _check_flee(current_hp: int, max_hp: int) -> void:
	if float(current_hp) / float(max_hp) < FLEE_HP_RATIO:
		current_state = State.FLEE

func _on_died() -> void:
	current_state = State.DEAD
	attack_hitbox.monitoring = false
	hurtbox.is_invincible = true
	velocity = Vector2.ZERO
	_play_anim("death")
	AmagoManager.add(AMAGO_REWARD)
	# Juice: explosão de Âmago dourado e tremor ao matar.
	Juice.burst(global_position, Juice.AMAGO_COLOR, 18, 160.0, 0.7)
	Juice.shake(0.5)
	Juice.hitstop(0.08, 0.05)
	# Dissolve o corpo enquanto some.
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.2).set_delay(0.4)
	get_tree().create_timer(1.8).timeout.connect(queue_free)

# ─── Detecção ────────────────────────────────────────────────────────────────

func _on_body_detected(body: Node2D) -> void:
	if body.is_in_group("player") and current_state == State.PATROL:
		_target = body
		current_state = State.CHASE

func _on_body_lost(body: Node2D) -> void:
	if body == _target:
		# Mantém _target para continuar perseguindo até perder de vista no chase
		pass

# ─── Spawn pelo EnemySpawner ─────────────────────────────────────────────────

func reset_to_spawn() -> void:
	global_position = _spawn_position
	current_state = State.PATROL
	_target = null
	health.set_max_health(80, true)
	hurtbox.is_invincible = false
	_attack_timer = 0.0
	_is_attacking = false
	modulate = Color.WHITE
	_generate_patrol_points()
	show()

# ─── Utilidades ──────────────────────────────────────────────────────────────

func _face_direction(dir: Vector2) -> void:
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

func facing_direction() -> Vector2:
	return Vector2(-1 if sprite.flip_h else 1, 0)

func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

## Pisca o corpo numa cor por um instante (feedback de dano recebido).
func _flash(color: Color, duration: float = 0.12) -> void:
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, duration)
