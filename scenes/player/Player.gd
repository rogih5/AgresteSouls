class_name Player
extends CharacterBody3D

# ─── Constantes de movimento (metros) ───────────────────────────────────────
const MOVE_SPEED: float = 6.0
const ATTACK_LUNGE: float = 3.0
const GRAVITY: float = 20.0
## Aceleração/atrito — dão peso e fluidez ao arranque e à parada (estilo ação 360°).
const ACCEL: float = 55.0
const FRICTION: float = 48.0
## Suavização da rotação do corpo ao virar (quanto menor, mais "molenga").
const TURN_SMOOTH: float = 0.35

# ─── Câmera ──────────────────────────────────────────────────────────────────
## Velocidade do follow suave da câmera. Maior = mais "grudada"; menor = mais cinematográfica.
const CAM_FOLLOW_SPEED: float = 7.5

# ─── Constantes de esquiva (rasteira de capoeira) ───────────────────────────
const DODGE_SPEED: float = 13.0
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
const HITBOX_REACH: float = 0.9

# ─── Screen shake ──────────────────────────────────────────────────────────
const MAX_SHAKE_OFFSET: float = 0.28
const SHAKE_DECAY: float = 2.2

# ─── Sinais ──────────────────────────────────────────────────────────────────
signal died

enum State { IDLE, MOVING, ATTACK_1, ATTACK_2, DODGING, HURT, DEAD }

# ─── Referências de nós ──────────────────────────────────────────────────────
@onready var health: HealthComponent = $HealthComponent
@onready var stamina_comp: StaminaComponent = $StaminaComponent
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D

# ─── Estado do jogador ───────────────────────────────────────────────────────
var stats: PlayerStats = PlayerStats.new()
var current_state: State = State.IDLE
var facing_direction: Vector3 = Vector3.FORWARD

# Ataque
var _attack_timer: float = 0.0
var _combo_decay: float = 0.0
var _can_combo: bool = false
var _attack_queued: bool = false

# Esquiva
var _dodge_direction: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0

# Dano
var _hurt_timer: float = 0.0

# Juice
var _shake_trauma: float = 0.0
var _camera_base_pos: Vector3
var _camera_initialized: bool = false
var _base_albedo: Color = Color(0.9, 0.75, 0.35)

## Em co-op o nome do nó é o id do peer dono. A autoridade se propaga aos
## filhos (hurtbox, synchronizer), então cada cliente controla só o seu corpo.
func _enter_tree() -> void:
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:
	add_to_group("player")
	health.set_max_health(stats.max_hp, true)
	stamina_comp.set_max_stamina(stats.max_stamina)
	health.died.connect(_on_health_zero)
	hurtbox.hurt.connect(_on_hurt)
	attack_hitbox.damage = stats.get_attack_damage()
	_camera_base_pos = camera.position
	# Rig em espaço global: a câmera segue o jogador com suavização (não rígida).
	camera_rig.top_level = true
	# Material único por instância para flash/iframe não afetarem outras cópias.
	if body_mesh.material_override:
		body_mesh.material_override = body_mesh.material_override.duplicate()
		_base_albedo = (body_mesh.material_override as StandardMaterial3D).albedo_color
	# Câmera e HUD pertencem só ao jogador local; réplicas remotas ficam mudas.
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	if is_local:
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		if hud:
			hud.connect_player(self)

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_handle_input_buffering()
	_decay_combo(delta)
	_update_camera(delta)
	_update_shake(delta)

func _physics_process(delta: float) -> void:
	# Réplicas remotas são movidas pelo MultiplayerSynchronizer.
	if not is_multiplayer_authority():
		return
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
			velocity.x = 0.0
			velocity.z = 0.0
			_apply_gravity(delta)
			move_and_slide()

# ─── Locomoção ───────────────────────────────────────────────────────────────

func _process_locomotion(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Movimento livre 360° com aceleração/atrito (sem snap) — fluidez de ação.
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir != Vector3.ZERO:
		facing_direction = dir.normalized()
		var target := dir * MOVE_SPEED
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
		current_state = State.MOVING
		_play_anim("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		current_state = State.IDLE
		_play_anim("idle")
	_apply_gravity(delta)
	move_and_slide()
	_rotate_visual_to_direction()

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
	velocity.x = facing_direction.x * ATTACK_LUNGE
	velocity.z = facing_direction.z * ATTACK_LUNGE
	attack_hitbox.damage = stats.get_attack_damage()
	attack_hitbox.position = facing_direction * HITBOX_REACH + Vector3(0.0, 0.8, 0.0)
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
	velocity.x = lerpf(velocity.x, 0.0, 0.18)
	velocity.z = lerpf(velocity.z, 0.0, 0.18)
	_apply_gravity(delta)
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
	velocity.x = facing_direction.x * ATTACK_LUNGE * 1.3
	velocity.z = facing_direction.z * ATTACK_LUNGE * 1.3
	# Segundo golpe faz 130% do dano base.
	attack_hitbox.damage = int(float(stats.get_attack_damage()) * 1.3)
	attack_hitbox.position = facing_direction * HITBOX_REACH + Vector3(0.0, 0.8, 0.0)
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
	velocity.x = lerpf(velocity.x, 0.0, 0.14)
	velocity.z = lerpf(velocity.z, 0.0, 0.14)
	_apply_gravity(delta)
	move_and_slide()
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		current_state = State.IDLE

# ─── Esquiva (rasteira de capoeira) ──────────────────────────────────────────

func _start_dodge() -> void:
	if not stamina_comp.spend(STAMINA_DODGE_COST):
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	_dodge_direction = (dir if dir != Vector3.ZERO else facing_direction).normalized()
	_dodge_timer = DODGE_DURATION
	current_state = State.DODGING
	hurtbox.is_invincible = false
	_play_anim("dodge")
	# Poeira do sertão levantada pela rasteira.
	Juice.burst(global_position - _dodge_direction * 0.3, Color(0.45, 0.36, 0.26), 10, 2.4, 0.45)

func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	var elapsed := DODGE_DURATION - _dodge_timer
	hurtbox.is_invincible = elapsed >= DODGE_IFRAME_START and elapsed <= DODGE_IFRAME_END

	# Indicador visual de iframes: corpo fica azulado enquanto invencível.
	_set_albedo(Color(0.45, 0.7, 1.0) if hurtbox.is_invincible else _base_albedo)

	# Curva de velocidade: arranque rápido, desaceleração suave (rasteira)
	var t := elapsed / DODGE_DURATION
	var speed_mult := 1.0 - ease(t, 2.2)
	velocity.x = _dodge_direction.x * DODGE_SPEED * speed_mult
	velocity.z = _dodge_direction.z * DODGE_SPEED * speed_mult
	_apply_gravity(delta)
	move_and_slide()

	if _dodge_timer <= 0.0:
		hurtbox.is_invincible = false
		_set_albedo(_base_albedo)
		current_state = State.IDLE

# ─── Dano recebido ───────────────────────────────────────────────────────────

func _on_hurt(damage: int, source_position: Vector3) -> void:
	if current_state == State.DEAD:
		return
	health.take_damage(damage)
	var knockback := (global_position - source_position)
	knockback.y = 0.0
	knockback = knockback.normalized() * 5.0
	velocity.x = knockback.x
	velocity.z = knockback.z
	current_state = State.HURT
	_hurt_timer = 0.35
	_play_anim("hurt")
	# Juice: flash vermelho, tranco no tempo e tremor de câmera.
	_flash(Color(2.0, 0.4, 0.4))
	Juice.spawn_damage_number(global_position, damage, false)
	Juice.hitstop(0.08, 0.04)
	add_shake(0.7)

func _process_hurt(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 0.2)
	velocity.z = lerpf(velocity.z, 0.0, 0.2)
	_apply_gravity(delta)
	move_and_slide()
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		current_state = State.IDLE

func _on_health_zero() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	hurtbox.is_invincible = true
	velocity = Vector3.ZERO
	_play_anim("death")
	AmagoManager.spawn_ghost_at(global_position)
	GameManager.handle_player_death()
	died.emit()

# ─── Respawn ─────────────────────────────────────────────────────────────────

func respawn(at_position: Vector3) -> void:
	global_position = at_position
	_snap_camera()
	velocity = Vector3.ZERO
	current_state = State.IDLE
	hurtbox.is_invincible = false
	_set_albedo(_base_albedo)
	health.set_max_health(stats.max_hp, true)
	stamina_comp.set_max_stamina(stats.max_stamina)
	_play_anim("idle")

# ─── Física e utilidades ─────────────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta

func _rotate_visual_to_direction() -> void:
	if facing_direction != Vector3.ZERO:
		var target_y := atan2(facing_direction.x, facing_direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_y, TURN_SMOOTH)

func _set_albedo(color: Color) -> void:
	if body_mesh.material_override:
		(body_mesh.material_override as StandardMaterial3D).albedo_color = color

func _play_anim(_anim_name: String) -> void:
	# Sem animações ainda (placeholders de malha). Stub para futura AnimationPlayer.
	pass

# ─── Câmera com follow suave ──────────────────────────────────────────────────

func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera_rig):
		return
	# Na primeira passada, gruda no jogador (a posição só é definida após add_child).
	if not _camera_initialized:
		camera_rig.global_position = global_position
		_camera_initialized = true
		return
	# Suavização exponencial independente de framerate.
	var t := 1.0 - exp(-CAM_FOLLOW_SPEED * delta)
	camera_rig.global_position = camera_rig.global_position.lerp(global_position, t)

## Reposiciona a câmera instantaneamente (usado no respawn/teleporte).
func _snap_camera() -> void:
	if is_instance_valid(camera_rig):
		camera_rig.global_position = global_position
		_camera_initialized = true

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
		camera.position = _camera_base_pos + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * amt * MAX_SHAKE_OFFSET
	elif camera.position != _camera_base_pos:
		camera.position = camera.position.lerp(_camera_base_pos, 0.35)

## Pisca o corpo numa cor por um instante (não usar durante a esquiva).
func _flash(color: Color, duration: float = 0.14) -> void:
	if current_state == State.DODGING or body_mesh.material_override == null:
		return
	_set_albedo(color)
	var tween := create_tween()
	tween.tween_property(body_mesh.material_override, "albedo_color", _base_albedo, duration)
