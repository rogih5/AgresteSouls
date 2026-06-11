class_name Cruzeiro
extends Area3D

## Checkpoint do jogo — ponto de retorno após morte, local de evolução e cura.
## Descansar no Cruzeiro avança a fase lunar e respawna TODOS os inimigos.
## Em co-op: a cura é só de quem descansou; relógio lunar e respawn valem
## para todos (sincronizados por RPC).

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

func _on_body_entered(body: Node3D) -> void:
	# Só reage ao jogador LOCAL — réplicas de outros peers não ativam checkpoint aqui.
	if not body.is_in_group("player") or not body.is_multiplayer_authority():
		return
	_player_nearby = true
	if is_cursed:
		return
	if not is_discovered:
		_discover()
	GameManager.register_cruzeiro_as_active(global_position)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		_player_nearby = false

func _discover() -> void:
	is_discovered = true
	activated.emit(self)
	# Juice: brilho dourado ao descobrir o Cruzeiro.
	Juice.burst(global_position, Color(0.95, 0.85, 0.55), 16, 4.0, 0.9)
	_pulse()

## Pulso de escala do Cruzeiro (feedback de ativação/descanso).
func _pulse() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.25, 1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)

## Descansa no Cruzeiro: cura (local), respawna inimigos e avança a fase
## lunar (para todos). Tecla padrão: F.
func rest() -> void:
	if not is_discovered or is_cursed:
		return
	var player := _get_local_player()
	if player:
		player.health.heal(player.health.max_health)
		player.stamina_comp.set_max_stamina(player.stats.max_stamina)
		# Juice: jorro de cura no jogador.
		Juice.burst(player.global_position, Juice.HEAL_COLOR, 20, 4.5, 0.8)
	_net_rest.rpc()

## Parte compartilhada do descanso — roda em todos os peers.
@rpc("any_peer", "call_local", "reliable")
func _net_rest() -> void:
	Juice.burst(global_position, Color(0.95, 0.88, 0.6), 24, 5.0, 1.0)
	_pulse()
	LunarClock.advance_one_phase()
	# respawn_all só tem efeito no servidor (dono dos inimigos).
	get_tree().call_group("enemy_spawner", "respawn_all")

func _get_local_player() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_multiplayer_authority():
			return node
	return null

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
