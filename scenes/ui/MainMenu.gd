## Menu principal — jogar sozinho, hospedar co-op ou entrar numa partida.
extends Control

@onready var solo_button: Button = $CenterContainer/Menu/SoloButton
@onready var host_button: Button = $CenterContainer/Menu/HostButton
@onready var ip_input: LineEdit = $CenterContainer/Menu/JoinRow/IpInput
@onready var join_button: Button = $CenterContainer/Menu/JoinRow/JoinButton
@onready var status_label: Label = $CenterContainer/Menu/StatusLabel

func _ready() -> void:
	solo_button.pressed.connect(_on_solo_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.status_changed.connect(_on_status_changed)

func _on_solo_pressed() -> void:
	NetworkManager.start_solo()

func _on_host_pressed() -> void:
	_set_buttons_enabled(false)
	if NetworkManager.host_game() != OK:
		_set_buttons_enabled(true)

func _on_join_pressed() -> void:
	_set_buttons_enabled(false)
	if NetworkManager.join_game(ip_input.text) != OK:
		_set_buttons_enabled(true)

func _on_status_changed(message: String) -> void:
	status_label.text = message
	# Falhas devolvem o controle ao menu.
	if message.begins_with("Falha") or message.begins_with("Não foi") \
			or message.begins_with("Endereço") or message.begins_with("Digite"):
		_set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool) -> void:
	solo_button.disabled = not enabled
	host_button.disabled = not enabled
	join_button.disabled = not enabled
