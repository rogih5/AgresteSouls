## Autoload singleton: rede co-op (ENet, até 4 jogadores).
## Arquitetura: host é o servidor. Jogadores têm autoridade do próprio peer
## (movimento local responsivo); inimigos são simulados só no servidor e
## replicados via MultiplayerSynchronizer; dano viaja por RPC até o peer dono.
## Não tem class_name (acessado pelo nome registrado: NetworkManager).
extends Node

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const FIRST_LEVEL: String = "res://scenes/world/hub/Hub.tscn"
const MAIN_MENU: String = "res://scenes/ui/MainMenu.tscn"

signal status_changed(message: String)

var current_level_path: String = ""
var _changing_level: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Joga sozinho (sem rede — o MultiplayerAPI offline age como servidor local).
func start_solo() -> void:
	_do_change_level(FIRST_LEVEL)

## Hospeda uma partida co-op nesta máquina.
func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		status_changed.emit("Não foi possível hospedar (porta %d já em uso?)." % port)
		return err
	multiplayer.multiplayer_peer = peer
	_do_change_level(FIRST_LEVEL)
	return OK

## Entra na partida de um anfitrião pelo IP.
func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	var address := ip.strip_edges()
	if address.is_empty():
		status_changed.emit("Digite o IP do anfitrião.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		status_changed.emit("Endereço inválido.")
		return err
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Conectando a %s..." % address)
	return OK

## Servidor: leva TODOS os jogadores para outra fase (portais).
func change_level(path: String) -> void:
	if not multiplayer.is_server() or _changing_level:
		return
	_do_change_level.rpc(path)

@rpc("authority", "call_local", "reliable")
func _do_change_level(path: String) -> void:
	_changing_level = true
	current_level_path = path
	get_tree().call_deferred("change_scene_to_file", path)

## Chamado por LevelBase._ready() quando a fase termina de carregar.
## Clientes avisam o servidor para ganharem seu corpo na fase nova.
func level_loaded() -> void:
	_changing_level = false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_client_level_ready.rpc_id(1)

@rpc("any_peer", "reliable")
func _client_level_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var level := get_tree().current_scene
	if level is LevelBase:
		level.spawn_player_for(peer_id)

@rpc("authority", "reliable")
func _sync_lunar_clock(cycle_time: float) -> void:
	LunarClock.cycle_time = cycle_time

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	status_changed.emit("Jogador %d conectou." % id)
	# Sincroniza o relógio lunar e manda o recém-chegado para a fase atual.
	_sync_lunar_clock.rpc_id(id, LunarClock.cycle_time)
	if current_level_path != "":
		_do_change_level.rpc_id(id, current_level_path)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var level := get_tree().current_scene
	if level is LevelBase:
		level.despawn_player_for(id)

func _on_connected_to_server() -> void:
	status_changed.emit("Conectado! Aguardando o anfitrião...")

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	status_changed.emit("Falha na conexão. Confira o IP e tente de novo.")

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	status_changed.emit("O anfitrião encerrou a partida.")
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)
