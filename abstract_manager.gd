extends Node
class_name AbstractManager

# Base class for all manager systems
# Provides common functionality and interface that all managers will implement

# Reference to game manager for cross-system communication
var game_manager: GameManager

# Debug mode flag
var debug_mode: bool = false

# Initialize manager with game manager reference
func initialize(game_mgr: GameManager) -> void:
	game_manager = game_mgr
	_setup()

# Setup method to be overridden by derived classes
func _setup() -> void:
	pass

# Process daily update (called once per game day)
func process_daily_update() -> void:
	pass

# Get save data as dictionary
func get_save_data() -> Dictionary:
	return {}

# Load save data from dictionary
func load_save_data(data: Dictionary) -> void:
	pass

# Set debug mode
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled
	_on_debug_mode_changed()

# Handle debug mode changes
func _on_debug_mode_changed() -> void:
	pass

# Log debug messages
func debug_log(message: String) -> void:
	if debug_mode:
		print("[" + get_class() + "] " + message)

# Get the class name as a string - useful for debugging
func get_class() -> String:
	return "AbstractManager"
