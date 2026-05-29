class_name Player
extends CharacterBody2D

# ─── Constantes de movimento ────────────────────────────────────────────────
const MOVE_SPEED: float = 200.0
const ATTACK_LUNGE: float = 90.0

# ─── Constantes de esquiva (rasteira de capoeira) ───────────────────────────
const DODGE_SPEED: float = 460.0
const DODGE_DURATION: float = 0.44
## Frames de invencibilidade: iframes começam em 0.06s e terminam em 0.36s
const DODGE_IFRAME_START: float = 0.06
const DODGE_IFRAME_END: float = 0.36

# ─── Constantes de combate ───────────────────────────────────────────────────
const ATTACK_1_DURATION: float = 0.38
const ATTACK_2_DURATION: float = 0.44
const COMBO_WINDOW: float = 0.65
const STAMINA_DODGE_COST: float = 25.0
const STAMINA_ATTACK_COST: float = 15.0

# ─── Sinais ──────────────────────────────────────────────────────────────────
signal died

enum State { IDLE, MOVING, ATTACK_1, ATTACK_2, DODGING, HURT, DEAD }

# ─── Referências de nós ──────────────────────────────────────────────────────
@onready var health: HealthComponent = $HealthComponent
@onready var stamina_comp: StaminaComponent = $StaminaComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

# ─── Screen shake ──────────────────────────────────────────────────────────
const MAX_SHAKE_OFFSET: float = 7.0
const SHAKE_DECAY: float = 2.2
var _shake_trauma: float = 0.0

# ─── Estado do jogador ───────────────────────────────────────────────────────
var stats: PlayerStats = PlayerStats.new()
var current_state: State = State.IDLE
var facing_direction: Vector2 = Vector2.RIGHT

# Ataque
var _attack_timer: float = 0.0
var _combo_decay: float = 0.0
var _can_combo: bool = false
var _attack_queued: bool = false

# Esquiva
var _dodge_direction: Vector2 = Vector2.ZERO
var _dodge_timer: float = 0.0

# Dano
var _hurt_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	health.set_max_health(stats.max_hp, true)
	stamina_comp.set_max_stamina(stats.max_stamina)
	health.died.connect(_on_health_zero)
	hurtbox.hurt.connect(_on_hurt)
	attack_hitbox.damage = stats.get_attack_damage()

func _process(delta: float) -> void:
	_handle_input_buffering()
	_decay_combo(delta)
	_update_shake(delta)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE, State.MOVING:
			_process_locomotion(delta)
		State.ATTACK_1:
			_process_attack_1(delta)
		State.ATTACK_2:
			_process_attack_2(delta)
		State.DODGING:
			_process_dodge(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			velocity = Vector2.ZERO
			move_and_slide()

# ─── Locomoção ───────────────────────────────────────────────────────────────

func _process_locomotion(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		facing_direction = dir.normalized()
		velocity = dir * MOVE_SPEED
		current_state = State.MOVING
		_play_anim("walk")
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.25)
		if velocity.length() < 4.0:
			velocity = Vector2.ZERO
		current_state = State.IDLE
		_play_anim("idle")
	move_and_slide()
	_rotate_sprite_to_direction()

# ─── Combate ─────────────────────────────────────────────────────────────────

func _handle_input_buffering() -> void:
	match current_state:
		State.IDLE, State.MOVING:
			if Input.is_action_just_pressed("attack"):
				_start_attack_1()
			elif Input.is_action_just_pressed("dodge"):
				_start_dodge()
		State.ATTACK_1:
			if _can_combo and Input.is_action_just_pressed("attack"):
				_attack_queued = true

func _decay_combo(delta: float) -> void:
	if _combo_decay > 0.0:
		_combo_decay -= delta
		if _combo_decay <= 0.0:
			_can_combo = false
			_attack_queued = false

func _start_attack_1() -> void:
	if not stamina_comp.spend(STAMINA_ATTACK_COST):
		return
	current_state = State.ATTACK_1
	_attack_timer = ATTACK_1_DURATION
	_can_combo = false
	_attack_queued = false
	velocity = facing_direction * ATTACK_LUNGE
	attack_hitbox.damage = stats.get_attack_damage()
	attack_hitbox.position = facing_direction * 22.0
	_play_anim("attack_1")

	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void:
		if current_state == State.ATTACK_1:
			attack_hitbox.monitoring = true
	)
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void:
		attack_hitbox.monitoring = false
		_can_combo = true
		_combo_decay = COMBO_WINDOW
	)

func _process_attack_1(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 0.18)
	move_and_slide()
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	if _attack_queued and _can_combo:
		_attack_queued = false
		_can_combo = false
		_combo_decay = 0.0
		_start_attack_2()
	else:
		_can_combo = false
		current_state = State.IDLE

func _start_attack_2() -> void:
	if not stamina_comp.spend(STAMINA_ATTACK_COST * 0.8):
		current_state = State.IDLE
		return
	current_state = State.ATTACK_2
	_attack_timer = ATTACK_2_DURATION
	velocity = facing_direction * ATTACK_LUNGE * 1.3
	# Segundo golpe faz 130% do dano base, lunge mais longo
	attack_hitbox.damage = int(float(stats.get_attack_damage()) * 1.3)
	attack_hitbox.position = facing_direction * 22.0
	_play_anim("attack_2")

	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if current_state == State.ATTACK_2:
			attack_hitbox.monitoring = true
	)
	tween.tween_interval(0.18)
	tween.tween_callback(func() -> void:
		attack_hitbox.monitoring = false
	)

func _process_attack_2(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 0.14)
	move_and_slide()
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		current_state = State.IDLE

# ─── Esquiva (rasteira de capoeira) ──────────────────────────────────────────

func _start_dodge() -> void:
	if not stamina_comp.spend(STAMINA_DODGE_COST):
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dodge_direction = (dir if dir != Vector2.ZERO else facing_direction).normalized()
	_dodge_timer = DODGE_DURATION
	current_state = State.DODGING
	hurtbox.is_invincible = false
	_play_anim("dodge")

func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	var elapsed := DODGE_DURATION - _dodge_timer
	hurtbox.is_invincible = elapsed >= DODGE_IFRAME_START and elapsed <= DODGE_IFRAME_END

	# Indicador visual de iframes: fica azul-translúcido enquanto invencível.
	modulate = Color(0.55, 0.8, 1.0, 0.55) if hurtbox.is_invincible else Color.WHITE

	# Curva de velocidade: arranque rápido, desaceleração suave (rasteira)
	var t := elapsed / DODGE_DURATION
	var speed_mult := 1.0 - ease(t, 2.2)
	velocity = _dodge_direction * DODGE_SPEED * speed_mult
	move_and_slide()

	if _dodge_timer <= 0.0:
		hurtbox.is_invincible = false
		modulate = Color.WHITE
		current_state = State.IDLE

# ─── Dano recebido ───────────────────────────────────────────────────────────

func _on_hurt(damage: int, source_position: Vector2) -> void:
	if current_state == State.DEAD:
		return
	health.take_damage(damage)
	var knockback := (global_position - source_position).normalized() * 180.0
	velocity = knockback
	current_state = State.HURT
	_hurt_timer = 0.35
	_play_anim("hurt")
	# Juice: dano levar leva flash vermelho, tranco no tempo e tremor de câmera.
	_flash(Color(2.0, 0.5, 0.5))
	Juice.spawn_damage_number(global_position, damage, false)
	Juice.hitstop(0.08, 0.04)
	add_shake(0.7)

func _process_hurt(delta: float) -> void:
	velocity = velocity.lerp(Vector2.ZERO, 0.2)
	move_and_slide()
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		current_state = State.IDLE

func _on_health_zero() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	hurtbox.is_invincible = true
	velocity = Vector2.ZERO
	_play_anim("death")
	AmagoManager.spawn_ghost_at(global_position)
	GameManager.handle_player_death()
	died.emit()

# ─── Respawn ─────────────────────────────────────────────────────────────────

func respawn(at_position: Vector2) -> void:
	global_position = at_position
	current_state = State.IDLE
	hurtbox.is_invincible = false
	health.set_max_health(stats.max_hp, true)
	stamina_comp.set_max_stamina(stats.max_stamina)
	_play_anim("idle")

# ─── Utilidades ──────────────────────────────────────────────────────────────

func _rotate_sprite_to_direction() -> void:
	if facing_direction != Vector2.ZERO:
		sprite.flip_h = facing_direction.x < 0.0

func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

# ─── Juice: screen shake e flash ─────────────────────────────────────────────

## Adiciona trauma de tremor de câmera (chamado pelo autoload Juice).
func add_shake(amount: float) -> void:
	_shake_trauma = minf(_shake_trauma + amount, 1.0)

func _update_shake(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - SHAKE_DECAY * delta, 0.0)
		var amt := _shake_trauma * _shake_trauma
		camera.offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * amt * MAX_SHAKE_OFFSET
	elif camera.offset != Vector2.ZERO:
		camera.offset = camera.offset.lerp(Vector2.ZERO, 0.35)

## Pisca o corpo numa cor por um instante (não usar durante a esquiva).
func _flash(color: Color, duration: float = 0.14) -> void:
	if current_state == State.DODGING:
		return
	modulate = color
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, duration)
