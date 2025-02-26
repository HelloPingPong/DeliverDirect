extends Node
class_name GameManager
# second major effort on game manager
# References to all major systems
var ui_manager: UIManager
var player_manager: PlayerManager
var economy_manager: EconomyManager
var carrier_manager: CarrierManager
var customer_manager: CustomerManager
var event_manager: EventManager
var map_manager: MapManager
var negotiation_manager: NegotiationManager
var audio_manager: AudioManager
var save_manager: SaveManager

# Game state variables
var game_paused: bool = false
var current_game_time: float = 0.0  # Time in seconds
var current_game_day: int = 0
var time_scale: float = 1.0  # For speed adjustments
var debug_mode: bool = false

# Constants
const SECONDS_PER_DAY: float = 600.0  # 10 minutes = 1 game day

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	randomize()  # Initialize random number generator
	initialize_managers()
	connect_signals()
	
	# Development mode - auto start a new game
	if OS.has_feature("editor"):
		new_game()

# Initialize all manager systems
func initialize_managers() -> void:
	# Create all manager instances
	ui_manager = $UIManager as UIManager
	player_manager = $PlayerManager as PlayerManager
	economy_manager = $EconomyManager as EconomyManager
	carrier_manager = $CarrierManager as CarrierManager
	customer_manager = $CustomerManager as CustomerManager
	event_manager = $EventManager as EventManager
	map_manager = $MapManager as MapManager
	negotiation_manager = $NegotiationManager as NegotiationManager
	audio_manager = $AudioManager as AudioManager
	save_manager = $SaveManager as SaveManager
	
	# Ensure all managers exist
	assert(ui_manager != null, "UIManager not found")
	assert(player_manager != null, "PlayerManager not found")
	assert(economy_manager != null, "EconomyManager not found")
	assert(carrier_manager != null, "CarrierManager not found")
	assert(customer_manager != null, "CustomerManager not found")
	assert(event_manager != null, "EventManager not found")
	assert(map_manager != null, "MapManager not found")
	assert(negotiation_manager != null, "NegotiationManager not found")
	assert(audio_manager != null, "AudioManager not found")
	assert(save_manager != null, "SaveManager not found")

# Connect signals between systems for communication
func connect_signals() -> void:
	# Connect UI signals
	ui_manager.connect("ui_game_paused", Callable(self, "_on_game_paused"))
	ui_manager.connect("ui_game_resumed", Callable(self, "_on_game_resumed"))
	ui_manager.connect("ui_new_game_requested", Callable(self, "new_game"))
	ui_manager.connect("ui_load_game_requested", Callable(self, "load_game"))
	ui_manager.connect("ui_save_game_requested", Callable(self, "save_game"))
	
	# Connect economy signals
	economy_manager.connect("market_updated", Callable(ui_manager, "update_market_display"))
	economy_manager.connect("price_surge", Callable(event_manager, "trigger_economic_event"))
	
	# Connect event signals
	event_manager.connect("event_triggered", Callable(self, "_on_event_triggered"))
	
	# Connect player signals
	player_manager.connect("player_bankrupt", Callable(self, "_on_player_bankrupt"))
	player_manager.connect("reputation_changed", Callable(ui_manager, "update_reputation_display"))
	
	# Connect any other necessary signals
	# ...

# Process game time
func _process(delta: float) -> void:
	if game_paused:
		return
		
	# Update game time
	current_game_time += delta * time_scale
	
	# Check for day change
	var new_day = int(current_game_time / SECONDS_PER_DAY)
	if new_day > current_game_day:
		current_game_day = new_day
		_on_day_changed()
	
	# Update economy time
	economy_manager.update_global_time(current_game_time)

# Start a new game
func new_game() -> void:
	# Reset game state
	current_game_time = 0.0
	current_game_day = 0
	game_paused = false
	
	# Initialize systems for a new game
	player_manager.initialize_new_player()
	economy_manager.initialize_economy()
	carrier_manager.initialize_carriers()
	customer_manager.initialize_customers()
	map_manager.initialize_map()
	
	# Set up initial game state
	event_manager.schedule_initial_events()
	ui_manager.switch_to_gameplay_screen()
	
	print("New game started")

# Save current game state
func save_game(slot_name: String = "quicksave") -> void:
	var save_data = {
		"game_time": current_game_time,
		"game_day": current_game_day,
		"player": player_manager.get_save_data(),
		"economy": economy_manager.get_save_data(),
		"carriers": carrier_manager.get_save_data(),
		"customers": customer_manager.get_save_data(),
		"map": map_manager.get_save_data(),
		"events": event_manager.get_save_data(),
		"reputation": negotiation_manager.get_save_data(),
		"meta": {
			"save_version": "1.0",
			"timestamp": Time.get_datetime_string_from_system(),
			"game_version": "0.1.0"  # Update with actual game version
		}
	}
	
	save_manager.save_game(slot_name, save_data)
	ui_manager.show_notification("Game saved to slot: " + slot_name)

# Load a saved game
func load_game(slot_name: String = "quicksave") -> void:
	var save_data = save_manager.load_game(slot_name)
	if save_data == null:
		ui_manager.show_notification("Failed to load game from slot: " + slot_name)
		return
	
	# Restore game state
	current_game_time = save_data["game_time"]
	current_game_day = save_data["game_day"]
	
	# Load data into each system
	player_manager.load_save_data(save_data["player"])
	economy_manager.load_save_data(save_data["economy"])
	carrier_manager.load_save_data(save_data["carriers"])
	customer_manager.load_save_data(save_data["customers"])
	map_manager.load_save_data(save_data["map"])
	event_manager.load_save_data(save_data["events"])
	negotiation_manager.load_save_data(save_data["reputation"])
	
	# Update UI to reflect loaded game state
	ui_manager.switch_to_gameplay_screen()
	ui_manager.update_all_displays()
	
	ui_manager.show_notification("Game loaded from slot: " + slot_name)

# Handle day change events
func _on_day_changed() -> void:
	print("Day changed to: ", current_game_day)
	
	# Trigger daily updates in various systems
	economy_manager.process_daily_update()
	carrier_manager.process_daily_update()
	customer_manager.process_daily_update()
	player_manager.process_daily_update()
	
	# Generate new customer requests
	customer_manager.generate_daily_requests()
	
	# Check for completion of deliveries
	carrier_manager.check_completed_deliveries()
	
	# Handle auto-save
	if current_game_day % 7 == 0:  # Auto-save weekly
		save_game("auto_" + str(current_game_day))

# Handle event triggering
func _on_event_triggered(event_name: String, event_data: Dictionary) -> void:
	print("Event triggered: ", event_name)
	
	# Process event effects on different systems
	match event_name:
		"fuel_price_surge":
			economy_manager.modify_item_price("fuel", event_data["multiplier"])
			carrier_manager.update_operating_costs()
		"market_crash":
			economy_manager.trigger_market_crash(event_data["severity"])
		"carrier_strike":
			carrier_manager.trigger_carrier_strike(event_data["carriers"], event_data["duration"])
		"weather_disaster":
			map_manager.block_lanes(event_data["affected_regions"], event_data["duration"])
		_:
			push_warning("Unknown event type: " + event_name)
	
	# Notify the player about the event
	ui_manager.show_event_notification(event_name, event_data)
	
	# Play appropriate sound effect
	audio_manager.play_event_sound(event_name)

# Handle game pause state
func _on_game_paused() -> void:
	game_paused = true
	
func _on_game_resumed() -> void:
	game_paused = false

# Handle player bankruptcy
func _on_player_bankrupt() -> void:
	game_paused = true
	ui_manager.show_game_over_screen("bankruptcy")

# Debug functions
func toggle_debug_mode() -> void:
	debug_mode = !debug_mode
	print("Debug mode: ", debug_mode)
	
	# Update all systems with debug mode
	ui_manager.set_debug_mode(debug_mode)
	economy_manager.set_debug_mode(debug_mode)
	carrier_manager.set_debug_mode(debug_mode)
	customer_manager.set_debug_mode(debug_mode)
	event_manager.set_debug_mode(debug_mode)
	map_manager.set_debug_mode(debug_mode)
