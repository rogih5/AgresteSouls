class_name Cruzeiro
extends Area2D

## Checkpoint do jogo — ponto de retorno após morte, local de evolução e cura.
## Descansar no Cruzeiro avança a fase lunar e respawna TODOS os inimigos.

signal activated(cruzeiro: Cruzeiro)

@export var cruzeiro_id: String = "cruzeiro_01"
@export var is_cursed: bool = false

var is_discovered: bool = false
var _player_nearby: bool = false

func _ready() -> void:
	add_to_group("cruzeiro")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or is_cursed:
		return
	if event.is_action_pressed("interact") and is_discovered:
		_show_cruzeiro_menu()
	elif event.is_action_pressed("rest") and is_discovered:
		rest()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true
	if is_cursed:
		return
	if not is_discovered:
		_discover()
	GameManager.register_cruzeiro_as_active(global_position)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false

func _discover() -> void:
	is_discovered = true
	activated.emit(self)
	# Juice: brilho dourado ao descobrir o Cruzeiro.
	Juice.burst(global_position, Color(0.95, 0.85, 0.55), 16, 100.0, 0.9)
	_pulse()

## Pulso de escala/brilho do Cruzeiro (feedback de ativação/descanso).
func _pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)

## Descansa no Cruzeiro: cura, respawna inimigos, avança fase lunar.
## Tecla padrão: F (configurável no projeto)
func rest() -> void:
	if not is_discovered or is_cursed:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.health.heal(player.health.max_health)
		player.stamina_comp.set_max_stamina(player.stats.max_stamina)
		# Juice: jorro de cura no jogador e brilho no Cruzeiro.
		Juice.burst(player.global_position, Juice.HEAL_COLOR, 20, 110.0, 0.8)
	Juice.burst(global_position, Color(0.95, 0.88, 0.6), 24, 130.0, 1.0)
	_pulse()
	LunarClock.advance_one_phase()
	get_tree().call_group("enemy_spawner", "respawn_all")

## Chamado pelo GameManager ao respawnar o jogador.
func on_respawn() -> void:
	pass  # animação de brilho pode ser adicionada aqui

## Purifica o Cruzeiro maldito (requer milagre ou item específico).
func purify() -> void:
	if is_cursed:
		is_cursed = false
		_discover()

## Permite viagem rápida para este Cruzeiro.
func teleport_player_here(player: Player) -> void:
	if not is_discovered:
		return
	player.global_position = global_position

func _show_cruzeiro_menu() -> void:
	# Placeholder: abre UI de evolução de atributos
	pass
