# game_manager.gd
class_name GameManager
extends Node

# References to all system managers
var ui_manager: UIManager
var map_manager: MapManager
var player_manager: PlayerManager
var carrier_manager: CarrierManager
var customer_manager: CustomerManager
var event_manager: EventManager
var economy_manager: EconomyEmulator
var negotiation_manager: NegotiationManager
var audio_manager: AudioManager
var save_manager: SaveManager

# Game state
var game_paused: bool = false
var current_game_time: float = 0
var game_speed: float = 1.0  # Can be adjusted for time acceleration

# Game settings
var settings: Dictionary = {
    "master_volume": 1.0,
    "music_volume": 0.8,
    "sfx_volume": 1.0,
    "ui_scale": 1.0,
    "auto_save_interval": 600,  # In seconds (10 minutes)
    "language": "en",
}

# Signals
signal game_paused(is_paused)
signal game_time_updated(time)
signal game_speed_changed(speed)
signal game_initialized
signal game_saved(slot_name)
signal game_loaded(slot_name)

func _ready():
    initialize_game()

func initialize_game():
    # Create all manager instances
    economy_manager = EconomyEmulator.new()
    add_child(economy_manager)
    
    ui_manager = UIManager.new()
    add_child(ui_manager)
    
    map_manager = MapManager.new()
    add_child(map_manager)
    
    player_manager = PlayerManager.new()
    add_child(player_manager)
    
    carrier_manager = CarrierManager.new()
    add_child(carrier_manager)
    
    customer_manager = CustomerManager.new()
    add_child(customer_manager)
    
    event_manager = EventManager.new()
    add_child(event_manager)
    
    negotiation_manager = NegotiationManager.new()
    add_child(negotiation_manager)
    
    audio_manager = AudioManager.new()
    add_child(audio_manager)
    
    save_manager = SaveManager.new()
    add_child(save_manager)
    
    # Connect system signals
    _connect_system_signals()
    
    # Initialize game data
    _initialize_game_data()
    
    emit_signal("game_initialized")

func _connect_system_signals():
    # Connect signals between systems to enable communication
    # Economic system connections
    economy_manager.connect("price_changed", player_manager._on_price_changed)
    economy_manager.connect("price_changed", carrier_manager._on_price_changed)
    economy_manager.connect("price_changed", customer_manager._on_price_changed)
    
    # Player signal connections
    player_manager.connect("balance_changed", ui_manager._on_player_balance_changed)
    player_manager.connect("reputation_changed", ui_manager._on_player_reputation_changed)
    
    # Carrier signal connections
    carrier_manager.connect("carrier_offer_made", ui_manager._on_carrier_offer_made)
    carrier_manager.connect("carrier_contract_accepted", player_manager._on_carrier_contract_accepted)
    
    # Customer signal connections
    customer_manager.connect("customer_contract_offered", ui_manager._on_customer_contract_offered)
    customer_manager.connect("customer_contract_completed", player_manager._on_customer_contract_completed)
    
    # Event signal connections
    event_manager.connect("event_triggered", economy_manager._on_event_triggered)
    event_manager.connect("event_triggered", ui_manager._on_event_triggered)
    event_manager.connect("event_resolved", ui_manager._on_event_resolved)
    
    # Map signal connections
    map_manager.connect("lane_selected", ui_manager._on_lane_selected)
    map_manager.connect("carrier_assigned", carrier_manager._on_carrier_assigned)

func _initialize_game_data():
    # Initialize starting commodities
    _initialize_commodities()
    
    # Initialize cities and trade routes
    _initialize_cities_and_lanes()
    
    # Initialize starting carriers
    _initialize_carriers()
    
    # Initialize starting customers
    _initialize_customers()
    
    # Initialize player starting state
    _initialize_player()

func _initialize_commodities():
    # Add various commodities by category
    # Food and Agricultural Products
    economy_manager.add_item("FVEG", 20.0)  # Fresh Vegetables
    economy_manager.add_item("FMEA", 35.0)  # Frozen Meat
    economy_manager.add_item("OHNY", 15.0)  # Organic Honey
    
    # Industrial and Construction Materials
    economy_manager.add_item("STBM", 50.0)  # Steel Beams
    economy_manager.add_item("LUMB", 25.0)  # Lumber
    economy_manager.add_item("ISND", 10.0)  # Industrial Sand
    
    # Create commodity groups
    economy_manager.add_group("FAGRP")  # Food and Agricultural Products
    economy_manager.add_group("ICMAT")  # Industrial and Construction Materials
    
    # Assign items to groups
    economy_manager.add_item_to_group("FVEG", "FAGRP")
    economy_manager.add_item_to_group("FMEA", "FAGRP")
    economy_manager.add_item_to_group("OHNY", "FAGRP")
    
    economy_manager.add_item_to_group("STBM", "ICMAT")
    economy_manager.add_item_to_group("LUMB", "ICMAT")
    economy_manager.add_item_to_group("ISND", "ICMAT")

func _initialize_cities_and_lanes():
    # Create cities as economic actors
    economy_manager.add_actor("city_a")
    economy_manager.add_actor("city_b")
    economy_manager.add_actor("city_c")
    
    # Add the cities to the map
    map_manager.add_city("city_a", Vector2(200, 150), "Metropolis")
    map_manager.add_city("city_b", Vector2(450, 200), "Harbor City")
    map_manager.add_city("city_c", Vector2(300, 350), "Mountain Town")
    
    # Create lanes between cities
    map_manager.add_lane("lane_1", "city_a", "city_b", 250.0)
    map_manager.add_lane("lane_2", "city_b", "city_c", 200.0)
    map_manager.add_lane("lane_3", "city_c", "city_a", 300.0)

func _initialize_carriers():
    # Add initial carriers to the system
    carrier_manager.add_carrier("SWLGT", "Swift Wheels Logistics", 75, 10)
    carrier_manager.add_carrier("BBTRK", "Big Blue Trucking Co.", 80, 15)
    carrier_manager.add_carrier("THHLT", "ThunderHaul Transport", 65, 8)
    
    # Set carrier specializations and preferences
    carrier_manager.set_carrier_preference("SWLGT", "FAGRP", 1.2)  # Prefers food
    carrier_manager.set_carrier_preference("BBTRK", "ICMAT", 1.1)  # Prefers industrial

func _initialize_customers():
    # Add initial customers
    customer_manager.add_customer("customer_a", "FreshMart", 70)
    customer_manager.add_customer("customer_b", "BuildRight Construction", 65)
    customer_manager.add_customer("customer_c", "GreenGrocer Co-op", 75)
    
    # Set customer needs and preferences
    customer_manager.set_customer_need("customer_a", "FAGRP", 5.0)  # Regular food needs
    customer_manager.set_customer_need("customer_b", "ICMAT", 3.0)  # Regular construction material needs

func _initialize_player():
    # Set starting player state
    player_manager.initialize_player("Player Company", 10000.0, 50.0)  # $10,000 starting balance, neutral reputation

func _process(delta):
    if !game_paused:
        # Update game time
        current_game_time += delta * game_speed
        economy_manager.update_global_time(current_game_time)
        
        # Trigger time-based updates
        _update_systems(delta * game_speed)
        
        emit_signal("game_time_updated", current_game_time)

func _update_systems(delta):
    # Allow each system to perform time-based updates
    carrier_manager.update(delta, current_game_time)
    customer_manager.update(delta, current_game_time)
    event_manager.update(delta, current_game_time)
    
    # Check for random events based on time
    event_manager.check_for_random_events(delta)

func pause_game(pause = true):
    game_paused = pause
    emit_signal("game_paused", game_paused)
    
    if game_paused:
        # Handle pausing behavior
        pass
