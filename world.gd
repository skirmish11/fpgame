extends Node3D

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AdressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar



const  Player = preload("res://player.tscn")
const  PORT = 9998
var enet_peer = ENetMultiplayerPeer.new()
var game_codes = {}  # Dictionary to store game codes and session info
var current_game_code = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	# Generate a unique game code
	current_game_code = generate_game_code()
	
	# Store the game session information
	game_codes[current_game_code] = {
		"ip": upnp_setup(),
		"port": PORT
}
	add_player(multiplayer.get_unique_id())
	
	upnp_setup()

 # Show the game code to the host
	print("Game code:", current_game_code)

func generate_game_code() -> String:
	return str(randi())  # Generate a random number as the game code

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	# Retrieve the game code from the user input
	var game_code = address_entry.text
	var session_info = game_codes.get(game_code, null)
	
	if session_info:
		# Connect to the game using the session info
		enet_peer.create_client(session_info["ip"], session_info["port"])
		multiplayer.multiplayer_peer = enet_peer
	else:
		print("Invalid game code")

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! ERROR %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
	"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % current_game_code)
