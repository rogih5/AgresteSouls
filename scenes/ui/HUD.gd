class_name HUD
extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HpBar
@onready var stamina_bar: ProgressBar = $MarginContainer/VBoxContainer/StaminaBar
@onready var amago_label: Label = $AmagoContainer/AmagoLabel
@onready var lunar_icon: Label = $LunarContainer/LunarIcon
@onready var lunar_name: Label = $LunarContainer/LunarName
@onready var ghost_indicator: Control = $GhostIndicator
@onready var phase_transition_overlay: ColorRect = $PhaseTransitionOverlay

func _ready() -> void:
	# O jogador local se conecta ao HUD via este grupo ao spawnar.
	add_to_group("hud")
	AmagoManager.amago_changed.connect(_on_amago_changed)
	AmagoManager.ghost_spawned.connect(_on_ghost_spawned)
	AmagoManager.ghost_collected.connect(_on_ghost_collected)
	AmagoManager.ghost_lost.connect(_on_ghost_lost)
	LunarClock.phase_changed.connect(_on_phase_changed)

	ghost_indicator.visible = false
	_refresh_lunar_display()
	_on_amago_changed(AmagoManager.current_amago)

## Conecta o HUD a um Player recém-instanciado (só o local).
func connect_player(player: Player) -> void:
	player.health.health_changed.connect(_on_hp_changed)
	player.stamina_comp.stamina_changed.connect(_on_stamina_changed)
	hp_bar.max_value = player.health.max_health
	hp_bar.value = player.health.current_health
	stamina_bar.max_value = player.stamina_comp.max_stamina
	stamina_bar.value = player.stamina_comp.current_stamina

func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current

func _on_amago_changed(amount: int) -> void:
	amago_label.text = str(amount)

func _on_ghost_spawned(_pos: Vector3, _amount: int) -> void:
	ghost_indicator.visible = true

func _on_ghost_collected(_amount: int) -> void:
	ghost_indicator.visible = false

func _on_ghost_lost() -> void:
	ghost_indicator.visible = false

func _on_phase_changed(_new: int, _old: int) -> void:
	_refresh_lunar_display()
	_play_phase_transition()

func _refresh_lunar_display() -> void:
	lunar_icon.text = LunarClock.get_phase_icon()
	# Mostra apenas o nome curto (antes do " — ")
	var full_name := LunarClock.get_phase_name()
	var parts := full_name.split(" — ")
	lunar_name.text = parts[0] if parts.size() > 0 else full_name

func _play_phase_transition() -> void:
	# Fade rápido para indicar mudança de fase
	var tween := create_tween()
	phase_transition_overlay.modulate.a = 0.0
	phase_transition_overlay.visible = true
	tween.tween_property(phase_transition_overlay, "modulate:a", 0.35, 0.8)
	tween.tween_property(phase_transition_overlay, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func() -> void: phase_transition_overlay.visible = false)
