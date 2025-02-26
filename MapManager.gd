extends AbstractManager
class_name MapManager
# second attempt at map manager
# Signals
signal lane_added(lane_id)
signal lane_removed(lane_id)
signal lane_status_changed(lane_id, status)
signal lane_congestion_changed(lane_id, congestion_level)
signal lane_risk_changed(lane_id, risk_level)
signal city_added(city_id)
signal city_removed(city_id)
signal lane_assigned(lane_id, carrier_id)
signal lane_unassigned(lane_id)

# Lane status enum
enum LaneStatus {
	AVAILABLE,  # Lane is available for purchase/use
	OWNED,      # Lane is owned by player
	BLOCKED,    # Lane is temporarily blocked (weather, disaster, etc.)
	CONGESTED,  # Lane is highly congested (slower travel)
	INACTIVE,   # Lane is inactive (no trade)
	ASSIGNED    # Lane is assigned to a carrier
}

# Lane risk level enum
enum RiskLevel {
	LOW,
	MEDIUM,
	HIGH,
	EXTREME
}

# Cities and locations
var cities: Dictionary = {}
var regions: Dictionary = {}

# Lanes and routes
var lanes: Dictionary = {}
var active_lanes: Dictionary = {}
var player_owned_lanes: Array = []
var lane_assignments: Dictionary = {}  # lane_id -> carrier_id

# Lane attributes
var lane_status: Dictionary = {}      # lane_id -> LaneStatus
var lane_congestion: Dictionary = {}  # lane_id -> float (0.0 to 1.0)
var lane_risk: Dictionary = {}        # lane_id -> RiskLevel
var lane_distance: Dictionary = {}    # lane_id -> float (in miles/km)
var lane_restrictions: Dictionary = {} # lane_id -> array of commodity restrictions

# Temporary effects
var blocked_lanes: Dictionary = {}    # lane_id -> remaining duration
var congestion_effects: Dictionary = {} # lane_id -> {effect, remaining_duration}
var risk_modifiers: Dictionary = {}   # lane_id -> {modifier, remaining_duration}

# Lane upgrade data
var lane_upgrades: Dictionary = {}    # lane_id -> Dictionary of upgrades

# Cache for pathfinding
var path_cache: Dictionary = {}

# Initialize the map
func _setup() -> void:
	debug_log("Setting up Map Manager")
	
	# In a real implementation, we would load map data from a resource
	# For now, we'll just set up a basic structure

# Initialize map for a new game
func initialize_map() -> void:
	debug_log("Initializing new map")
	
	# Clear existing data
	cities.clear()
	lanes.clear()
	active_lanes.clear()
	player_owned_lanes.clear()
	lane_assignments.clear()
	lane_status.clear()
	lane_congestion.clear()
	lane_risk.clear()
	lane_distance.clear()
	lane_restrictions.clear()
	blocked_lanes.clear()
	congestion_effects.clear()
	risk_modifiers.clear()
	lane_upgrades.clear()
	path_cache.clear()
	
	# Generate cities and regions
	_generate_cities_and_regions()
	
	# Generate initial lanes
	_generate_lanes()
	
	# Set initial lane attributes
	_initialize_lane_attributes()

# Generate cities and regions for the map
func _generate_cities_and_regions() -> void:
	debug_log("Generating cities and regions")
	
	# Define regions
	regions = {
		"northeast": {
			"name": "Northeast",
			"risk_factor": 0.2,
			"economy_strength": 0.8,
			"weather_susceptibility": 0.7,
			"cities": []
		},
		"midwest": {
			"name": "Midwest",
			"risk_factor": 0.3,
			"economy_strength": 0.6,
			"weather_susceptibility": 0.8,
			"cities": []
		},
		"south": {
			"name": "South",
			"risk_factor": 0.4,
			"economy_strength": 0.7,
			"weather_susceptibility": 0.6,
			"cities": []
		},
		"west": {
			"name": "West",
			"risk_factor": 0.5,
			"economy_strength": 0.9,
			"weather_susceptibility": 0.5,
			"cities": []
		},
		"northwest": {
			"name": "Northwest",
			"risk_factor": 0.3,
			"economy_strength": 0.7,
			"weather_susceptibility": 0.9,
			"cities": []
		}
	}
	
	# Create cities
	_create_city("NYC", "New York City", "northeast", Vector2(800, 200), 8.4, 0.9, ["RTLMD", "ELTEC", "FAGRP"])
	_create_city("CHI", "Chicago", "midwest", Vector2(600, 250), 2.7, 0.8, ["AUMAC", "ICMAT", "FAGRP"])
	_create_city("HOU", "Houston", "south", Vector2(550, 450), 2.3, 0.7, ["RAWMA", "AUMAC", "ELTEC"])
	_create_city("LA", "Los Angeles", "west", Vector2(150, 350), 4.0, 0.9, ["ELTEC", "TEXAP", "RTLMD"])
	_create_city("SEA", "Seattle", "northwest", Vector2(150, 150), 0.7, 0.8, ["TEXAP", "ELTEC", "FAGRP"])
	_create_city("MIA", "Miami", "south", Vector2(750, 550), 0.5, 0.6, ["FAGRP", "TEXAP", "RTLMD"])
	_create_city("DAL", "Dallas", "south", Vector2(500, 400), 1.3, 0.7, ["RAWMA", "AUMAC", "ICMAT"])
	_create_city("PHI", "Philadelphia", "northeast", Vector2(750, 230), 1.6, 0.8, ["ICMAT", "MEDPH", "RTLMD"])
	_create_city("PHX", "Phoenix", "west", Vector2(250, 400), 1.6, 0.6, ["RAWMA", "ELTEC", "SPCEX"])
	_create_city("DEN", "Denver", "midwest", Vector2(400, 300), 0.7, 0.7, ["AUMAC", "RAWMA", "MEDPH"])

# Create a city with given parameters
func _create_city(city_id: String, name: String, region_id: String, position: Vector2, population: float, infrastructure: float, industries: Array) -> void:
	# Create city data
	cities[city_id] = {
		"id": city_id,
		"name": name,
		"region": region_id,
		"position": position,
		"population": population,  # In millions
		"infrastructure": infrastructure,  # 0.0 to 1.0, higher is better
		"industries": industries,
		"risk_level": 0.0,
		"congestion": 0.0
	}
	
	# Add to region
	if regions.has(region_id):
		regions[region_id]["cities"].append(city_id)
	
	# Signal that city was added
	emit_signal("city_added", city_id)

# Generate lanes between cities
func _generate_lanes() -> void:
	debug_log("Generating lanes")
	
	# Create lanes between cities - not all cities need direct connections
	# For a real game, this would be more strategic, but this is a simple example
	
	# Connecting major cities first
	_create_lane("NYC-CHI", "NYC", "CHI", 800.0)
	_create_lane("CHI-LA", "CHI", "LA", 2000.0)
	_create_lane("NYC-MIA", "NYC", "MIA", 1200.0)
	_create_lane("LA-SEA", "LA", "SEA", 1100.0)
	_create_lane("CHI-HOU", "CHI", "HOU", 1000.0)
	_create_lane("HOU-MIA", "HOU", "MIA", 950.0)
	_create_lane("LA-PHX", "LA", "PHX", 400.0)
	_create_lane("CHI-DEN", "CHI", "DEN", 1000.0)
	_create_lane("DEN-LA", "DEN", "LA", 1020.0)
	_create_lane("NYC-PHI", "NYC", "PHI", 100.0)
	_create_lane("DAL-HOU", "DAL", "HOU", 250.0)
	_create_lane("DAL-PHX", "DAL", "PHX", 900.0)
	_create_lane("DEN-SEA", "DEN", "SEA", 1300.0)
	_create_lane("MIA-PHI", "MIA", "PHI", 1100.0)
	_create_lane("CHI-PHI", "CHI", "PHI", 750.0)

# Create a lane between two cities
func _create_lane(lane_id: String, city1_id: String, city2_id: String, distance: float) -> void:
	# Create lane data
	lanes[lane_id] = {
		"id": lane_id,
		"start_city": city1_id,
		"end_city": city2_id,
		"distance": distance,
		"base_cost": _calculate_lane_base_cost(distance),
		"maintenance_cost": _calculate_lane_maintenance_cost(distance)
	}
	
	# Set initial lane status to AVAILABLE
	lane_status[lane_id] = LaneStatus.AVAILABLE
	
	# Calculate and set initial attributes
	lane_congestion[lane_id] = _calculate_initial_congestion(city1_id, city2_id)
	lane_risk[lane_id] = _calculate_initial_risk(city1_id, city2_id)
	lane_distance[lane_id] = distance
	
	# Set initial restrictions (if any)
	lane_restrictions[lane_id] = _calculate_lane_restrictions(city1_id, city2_id)
	
	# Signal that lane was added
	emit_signal("lane_added", lane_id)

# Initialize lane attributes based on cities and regions
func _initialize_lane_attributes() -> void:
	for lane_id in lanes.keys():
		var lane = lanes[lane_id]
		
		# Set initial status
		lane_status[lane_id] = LaneStatus.AVAILABLE
		
		# Initialize other attributes if not already set
		if not lane_congestion.has(lane_id):
			lane_congestion[lane_id] = _calculate_initial_congestion(lane["start_city"], lane["end_city"])
		
		if not lane_risk.has(lane_id):
			lane_risk[lane_id] = _calculate_initial_risk(lane["start_city"], lane["end_city"])
		
		if not lane_restrictions.has(lane_id):
			lane_restrictions[lane_id] = _calculate_lane_restrictions(lane["start_city"], lane["end_city"])

# Calculate initial congestion based on city infrastructure and population
func _calculate_initial_congestion(city1_id: String, city2_id: String) -> float:
	var city1 = cities[city1_id]
	var city2 = cities[city2_id]
	
	# Higher population and lower infrastructure increase congestion
	var population_factor = (city1["population"] + city2["population"]) / 10.0  # Normalize
	var infrastructure_factor = 2.0 - (city1["infrastructure"] + city2["infrastructure"])
	
	# Calculate congestion (0.0 to 1.0, higher means more congested)
	var congestion = clamp(population_factor * infrastructure_factor * 0.25, 0.1, 0.9)
	
	return congestion

# Calculate initial risk based on region risk factors
func _calculate_initial_risk(city1_id: String, city2_id: String) -> int:
	var city1 = cities[city1_id]
	var city2 = cities[city2_id]
	
	var region1 = regions[city1["region"]]
	var region2 = regions[city2["region"]]
	
	# Average risk factors of both regions
	var risk_factor = (region1["risk_factor"] + region2["risk_factor"]) / 2.0
	
	# Determine risk level based on factor
	if risk_factor < 0.2:
		return RiskLevel.LOW
	elif risk_factor < 0.4:
		return RiskLevel.MEDIUM
	elif risk_factor < 0.7:
		return RiskLevel.HIGH
	else:
		return RiskLevel.EXTREME

# Calculate lane restrictions based on cities and their industries
func _calculate_lane_restrictions(city1_id: String, city2_id: String) -> Array:
	# For now, just return an empty array (no restrictions)
	# In a full implementation, this would consider infrastructure, regulations, etc.
	return []

# Calculate lane base cost based on distance
func _calculate_lane_base_cost(distance: float) -> float:
	# Base formula: $10,000 per 100 distance units
	return (distance / 100.0) * 10000.0

# Calculate lane maintenance cost based on distance
func _calculate_lane_maintenance_cost(distance: float) -> float:
	# Base formula: $500 per 100 distance units per day
	return (distance / 100.0) * 500.0

# Get available lanes for purchase/use
func get_available_lanes() -> Array:
	var available = []
	
	for lane_id in lanes.keys():
		if lane_status[lane_id] == LaneStatus.AVAILABLE:
			# Create a copy of lane data with current status information
			var lane_data = lanes[lane_id].duplicate()
			lane_data["status"] = lane_status[lane_id]
			lane_data["congestion"] = lane_congestion[lane_id]
			lane_data["risk"] = lane_risk[lane_id]
			lane_data["restrictions"] = lane_restrictions[lane_id]
			
			available.append(lane_data)
	
	return available

# Get player owned lanes
func get_player_owned_lanes() -> Array:
	var owned = []
	
	for lane_id in player_owned_lanes:
		var lane_data = lanes[lane_id].duplicate()
		lane_data["status"] = lane_status[lane_id]
		lane_data["congestion"] = lane_congestion[lane_id]
		lane_data["risk"] = lane_risk[lane_id]
		lane_data["restrictions"] = lane_restrictions[lane_id]
		lane_data["assigned_to"] = lane_assignments.get(lane_id, "")
		
		owned.append(lane_data)
	
	return owned

# Get active lanes (those assigned to carriers)
func get_active_lanes() -> Array:
	var active = []
	
	for lane_id in lane_assignments.keys():
		var lane_data = lanes[lane_id].duplicate()
		lane_data["status"] = lane_status[lane_id]
		lane_data["congestion"] = lane_congestion[lane_id]
		lane_data["risk"] = lane_risk[lane_id]
		lane_data["assigned_to"] = lane_assignments[lane_id]
		
		active.append(lane_data)
	
	return active

# Purchase a lane for the player
func purchase_lane(lane_id: String) -> bool:
	if not lanes.has(lane_id):
		debug_log("Attempted to purchase non-existent lane: " + lane_id)
		return false
	
	if lane_status[lane_id] != LaneStatus.AVAILABLE:
		debug_log("Attempted to purchase unavailable lane: " + lane_id)
		return false
	
	# Get the base cost
	var cost = lanes[lane_id]["base_cost"]
	
	# Check if player can afford it
	if game_manager.player_manager.get_balance() < cost:
		debug_log("Player cannot afford lane: " + lane_id)
		return false
	
	# Deduct cost from player
	game_manager.player_manager.adjust_balance(-cost, "Lane Purchase: " + lane_id)
	
	# Update lane status
	lane_status[lane_id] = LaneStatus.OWNED
	player_owned_lanes.append(lane_id)
	
	# Signal lane status change
	emit_signal("lane_status_changed", lane_id, LaneStatus.OWNED)
	
	debug_log("Lane purchased: " + lane_id)
	return true

# Sell a lane (return to available state)
func sell_lane(lane_id: String) -> bool:
	if not lanes.has(lane_id):
		debug_log("Attempted to sell non-existent lane: " + lane_id)
		return false
	
	if not lane_id in player_owned_lanes:
		debug_log("Attempted to sell lane player doesn't own: " + lane_id)
		return false
	
	if lane_id in lane_assignments:
		debug_log("Cannot sell lane that has an active carrier: " + lane_id)
		return false
	
	# Calculate sell value (50% of purchase price)
	var sell_value = lanes[lane_id]["base_cost"] * 0.5
	
	# Add value to player's balance
	game_manager.player_manager.adjust_balance(sell_value, "Lane Sale: " + lane_id)
	
	# Update lane status
	lane_status[lane_id] = LaneStatus.AVAILABLE
	player_owned_lanes.erase(lane_id)
	
	# Signal lane status change
	emit_signal("lane_status_changed", lane_id, LaneStatus.AVAILABLE)
	
	debug_log("Lane sold: " + lane_id)
	return true

# Assign a carrier to a lane
func assign_carrier_to_lane(lane_id: String, carrier_id: String) -> bool:
	if not lanes.has(lane_id):
		debug_log("Attempted to assign carrier to non-existent lane: " + lane_id)
		return false
	
	if not lane_id in player_owned_lanes:
		debug_log("Attempted to assign carrier to lane player doesn't own: " + lane_id)
		return false
	
	if lane_status[lane_id] == LaneStatus.BLOCKED:
		debug_log("Cannot assign carrier to blocked lane: " + lane_id)
		return false
	
	if lane_id in lane_assignments:
		debug_log("Lane already has carrier assigned: " + lane_id)
		return false
	
	# Update lane assignment
	lane_assignments[lane_id] = carrier_id
	lane_status[lane_id] = LaneStatus.ASSIGNED
	
	# Signal the assignment
	emit_signal("lane_assigned", lane_id, carrier_id)
	emit_signal("lane_status_changed", lane_id, LaneStatus.ASSIGNED)
	
	debug_log("Carrier " + carrier_id + " assigned to lane " + lane_id)
	return true

# Unassign a carrier from a lane
func unassign_carrier_from_lane(lane_id: String) -> bool:
	if not lanes.has(lane_id):
		debug_log("Attempted to unassign from non-existent lane: " + lane_id)
		return false
	
	if not lane_id in player_owned_lanes:
		debug_log("Attempted to unassign from lane player doesn't own: " + lane_id)
		return false
	
	if not lane_id in lane_assignments:
		debug_log("No carrier assigned to lane: " + lane_id)
		return false
	
	# Get assigned carrier for notification
	var carrier_id = lane_assignments[lane_id]
	
	# Remove assignment
	lane_assignments.erase(lane_id)
	lane_status[lane_id] = LaneStatus.OWNED
	
	# Signal the unassignment
	emit_signal("lane_unassigned", lane_id)
	emit_signal("lane_status_changed", lane_id, LaneStatus.OWNED)
	
	debug_log("Carrier unassigned from lane " + lane_id)
	return true

# Block lanes due to events (e.g., weather, disasters)
func block_lanes(affected_regions: Array, duration: float) -> void:
	debug_log("Blocking lanes in regions: " + str(affected_regions) + " for " + str(duration) + " days")
	
	# Find lanes in affected regions
	for lane_id in lanes.keys():
		var lane = lanes[lane_id]
		var start_city = cities[lane["start_city"]]
		var end_city = cities[lane["end_city"]]
		
		# If either city is in an affected region, block the lane
		if affected_regions.has(start_city["region"]) or affected_regions.has(end_city["region"]):
			# If lane is active, need to handle it specially
			if lane_id in lane_assignments:
				var carrier_id = lane_assignments[lane_id]
				# Notify carrier manager of disruption
				game_manager.carrier_manager.handle_lane_disruption(lane_id, carrier_id, "blocked", duration)
				
				# Unassign the carrier
				lane_assignments.erase(lane_id)
			
			# Block the lane
			lane_status[lane_id] = LaneStatus.BLOCKED
			blocked_lanes[lane_id] = duration
			
			# Signal the status change
			emit_signal("lane_status_changed", lane_id, LaneStatus.BLOCKED)
			
			debug_log("Lane blocked due to regional event: " + lane_id)

# Update lane congestion level
func update_lane_congestion(lane_id: String, congestion_value: float) -> void:
	if not lanes.has(lane_id):
		return
	
	lane_congestion[lane_id] = clamp(congestion_value, 0.0, 1.0)
	emit_signal("lane_congestion_changed", lane_id, lane_congestion[lane_id])

# Update lane risk level
func update_lane_risk(lane_id: String, risk_level: int) -> void:
	if not lanes.has(lane_id):
		return
	
	lane_risk[lane_id] = risk_level
	emit_signal("lane_risk_changed", lane_id, lane_risk[lane_id])

# Process daily update
func process_daily_update() -> void:
	debug_log("Processing daily map update")
	
	# Process temporary effects
	_process_temporary_effects()
	
	# Update lane conditions
	_update_lane_conditions()
	
	# Update city conditions
	_update_city_conditions()

# Process temporary effects like blocks, congestion, etc.
func _process_temporary_effects() -> void:
	# Process blocked lanes
	var lanes_to_unblock = []
	
	for lane_id in blocked_lanes.keys():
		blocked_lanes[lane_id] -= 1.0
		
		# If duration expired, unblock
		if blocked_lanes[lane_id] <= 0:
			lanes_to_unblock.append(lane_id)
	
	# Unblock lanes with expired durations
	for lane_id in lanes_to_unblock:
		blocked_lanes.erase(lane_id)
		
		# If player owns this lane, set status back to OWNED
		if lane_id in player_owned_lanes:
			lane_status[lane_id] = LaneStatus.OWNED
		else:
			lane_status[lane_id] = LaneStatus.AVAILABLE
		
		emit_signal("lane_status_changed", lane_id, lane_status[lane_id])
		
		debug_log("Lane unblocked: " + lane_id)
	
	# Process congestion effects
	var congestion_to_remove = []
	
	for lane_id in congestion_effects.keys():
		congestion_effects[lane_id]["remaining_duration"] -= 1.0
		
		# If duration expired, remove effect
		if congestion_effects[lane_id]["remaining_duration"] <= 0:
			congestion_to_remove.append(lane_id)
	
	# Remove expired congestion effects
	for lane_id in congestion_to_remove:
		congestion_effects.erase(lane_id)
		
		# Reset congestion to base level
		update_lane_congestion(lane_id, _calculate_initial_congestion(
			lanes[lane_id]["start_city"], 
			lanes[lane_id]["end_city"]
		))
		
		debug_log("Congestion effect expired for lane: " + lane_id)
	
	# Process risk modifiers
	var risk_to_remove = []
	
	for lane_id in risk_modifiers.keys():
		risk_modifiers[lane_id]["remaining_duration"] -= 1.0
		
		# If duration expired, remove modifier
		if risk_modifiers[lane_id]["remaining_duration"] <= 0:
			risk_to_remove.append(lane_id)
	
	# Remove expired risk modifiers
	for lane_id in risk_to_remove:
		risk_modifiers.erase(lane_id)
		
		# Reset risk to base level
		update_lane_risk(lane_id, _calculate_initial_risk(
			lanes[lane_id]["start_city"], 
			lanes[lane_id]["end_city"]
		))
		
		debug_log("Risk modifier expired for lane: " + lane_id)

# Update lane conditions based on time, events, etc.
func _update_lane_conditions() -> void:
	# Random fluctuations in lane conditions for realism
	for lane_id in lanes.keys():
		# Skip blocked lanes
		if lane_status[lane_id] == LaneStatus.BLOCKED:
			continue
		
		# Add slight random variations to congestion
		if not lane_id in congestion_effects:
			var current_congestion = lane_congestion[lane_id]
			var variation = (randf() * 0.2) - 0.1  # -0.1 to +0.1 variation
			update_lane_congestion(lane_id, clamp(current_congestion + variation, 0.1, 0.9))
		
		# Occasionally change risk levels
		if not lane_id in risk_modifiers and randf() < 0.05:  # 5% chance per day
			var current_risk = lane_risk[lane_id]
			var risk_change = randi() % 3 - 1  # -1, 0, or +1
			var new_risk = clamp(current_risk + risk_change, RiskLevel.LOW, RiskLevel.EXTREME)
			
			if new_risk != current_risk:
				update_lane_risk(lane_id, new_risk)
				debug_log("Random risk change for lane " + lane_id + ": " + str(current_risk) + " -> " + str(new_risk))

# Update city conditions based on time, events, etc.
func _update_city_conditions() -> void:
	# Update city risk and congestion randomly for realism
	for city_id in cities.keys():
		var city = cities[city_id]
		
		# Random congestion changes
		city["congestion"] = clamp(city["congestion"] + (randf() * 0.2) - 0.1, 0.0, 1.0)
		
		# Random risk changes
		if randf() < 0.1:  # 10% chance per day
			city["risk_level"] = clamp(city["risk_level"] + (randf() * 0.3) - 0.15, 0.0, 1.0)
		
		# Update connected lanes if risk or congestion changed significantly
		# This would propagate changes to affected lanes

# Calculate delivery time for a lane
func calculate_delivery_time(lane_id: String, carrier_speed_factor: float = 1.0) -> float:
	if not lanes.has(lane_id):
		return -1.0
	
	var lane = lanes[lane_id]
	var distance = lane["distance"]
	var congestion = lane_congestion[lane_id]
	
	# Base time: distance ÷ speed (assume 60 distance units/hour)
	var base_time = distance / 60.0
	
	# Congestion increases time (up to double for maximum congestion)
	var congestion_multiplier = 1.0 + congestion
	
	# Calculate total time in hours
	var total_time = base_time * congestion_multiplier / carrier_speed_factor
	
	return total_time

# Get risk factor for a lane (0.0 to 1.0)
func get_lane_risk_factor(lane_id: String) -> float:
	if not lanes.has(lane_id):
		return 0.0
	
	var risk_level = lane_risk[lane_id]
	
	# Convert enum to factor
	match risk_level:
		RiskLevel.LOW:
			return 0.1
		RiskLevel.MEDIUM:
			return 0.3
		RiskLevel.HIGH:
			return 0.6
		RiskLevel.EXTREME:
			return 0.9
		_:
			return 0.0

# Get a path between two cities
func get_path_between_cities(start_city_id: String, end_city_id: String) -> Array:
	# Check if path is cached
	var cache_key = start_city_id + "_" + end_city_id
	if path_cache.has(cache_key):
		return path_cache[cache_key]
	
	# For now, just return direct path if it exists
	for lane_id in lanes.keys():
		var lane = lanes[lane_id]
		if (lane["start_city"] == start_city_id and lane["end_city"] == end_city_id) or \
		   (lane["start_city"] == end_city_id and lane["end_city"] == start_city_id):
			var path = [lane_id]
			path_cache[cache_key] = path
			return path
	
	# In a real implementation, this would use pathfinding algorithms
	# to find the shortest/fastest path between cities using available lanes
	debug_log("No direct path found between " + start_city_id + " and " + end_city_id)
	
	# For now, return empty array indicating no path
	path_cache[cache_key] = []
	return []

# Add a temporary congestion effect to a lane
func add_congestion_effect(lane_id: String, effect_value: float, duration: float) -> void:
	if not lanes.has(lane_id):
		return
	
	congestion_effects[lane_id] = {
		"effect": effect_value,
		"remaining_duration": duration
	}
	
	# Apply effect immediately
	var base_congestion = _calculate_initial_congestion(
		lanes[lane_id]["start_city"], 
		lanes[lane_id]["end_city"]
	)
	
	update_lane_congestion(lane_id, clamp(base_congestion + effect_value, 0.0, 1.0))
	
	debug_log("Added congestion effect to lane " + lane_id + ": +" + str(effect_value) + " for " + str(duration) + " days")

# Add a temporary risk modifier to a lane
func add_risk_modifier(lane_id: String, risk_change: int, duration: float) -> void:
	if not lanes.has(lane_id):
		return
	
	var current_risk = lane_risk[lane_id]
	var new_risk = clamp(current_risk + risk_change, RiskLevel.LOW, RiskLevel.EXTREME)
	
	risk_modifiers[lane_id] = {
		"modifier": risk_change,
		"remaining_duration": duration
	}
	
	# Apply effect immediately
	update_lane_risk(lane_id, new_risk)
	
	debug_log("Added risk modifier to lane " + lane_id + ": " + str(risk_change) + " for " + str(duration) + " days")

# Apply a lane upgrade
func apply_lane_upgrade(lane_id: String, upgrade_type: String) -> bool:
	if not lanes.has(lane_id) or not lane_id in player_owned_lanes:
		return false
	
	# Initialize upgrades for this lane if not already done
	if not lane_upgrades.has(lane_id):
		lane_upgrades[lane_id] = {}
	
	# Check if upgrade is already applied
	if lane_upgrades[lane_id].has(upgrade_type):
		debug_log("Lane already has this upgrade: " + upgrade_type)
		return false
	
	# Handle different upgrade types
	var upgrade_cost = 0.0
	var upgrade_effect = {}
	
	match upgrade_type:
		"faster_roads":
			upgrade_cost = lanes[lane_id]["base_cost"] * 0.3
			upgrade_effect = {"congestion_reduction": 0.2}
			
		"security_escort":
			upgrade_cost = lanes[lane_id]["base_cost"] * 0.4
			upgrade_effect = {"risk_reduction": 1}  # Reduce by one level
			
		"automated_checkpoints":
			upgrade_cost = lanes[lane_id]["base_cost"] * 0.25
			upgrade_effect = {"congestion_reduction": 0.15}
			
		"specialized_lane":
			upgrade_cost = lanes[lane_id]["base_cost"] * 0.5
			upgrade_effect = {"restrictions_removed": true}
			
		_:
			debug_log("Unknown upgrade type: " + upgrade_type)
			return false
	
	# Check if player can afford it
	if game_manager.player_manager.get_balance() < upgrade_cost:
		debug_log("Player cannot afford upgrade")
		return false
	
	# Deduct cost
	game_manager.player_manager.adjust_balance(-upgrade_cost, "Lane Upgrade: " + upgrade_type)
	
	# Apply upgrade
	lane_upgrades[lane_id][upgrade_type] = upgrade_effect
	
	# Apply immediate effects
	if upgrade_effect.has("congestion_reduction"):
		var new_congestion = lane_congestion[lane_id] - upgrade_effect["congestion_reduction"]
		update_lane_congestion(lane_id, clamp(new_congestion, 0.0, 1.0))
	
	if upgrade_effect.has("risk_reduction"):
		var new_risk = lane_risk[lane_id] - upgrade_effect["risk_reduction"]
		update_lane_risk(lane_id, clamp(new_risk, RiskLevel.LOW, RiskLevel.EXTREME))
	
	if upgrade_effect.has("restrictions_removed"):
		lane_restrictions[lane_id] = []
	
	debug_log("Applied upgrade " + upgrade_type + " to lane " + lane_id)
	return true

# Get save data for the map system
func get_save_data() -> Dictionary:
	return {
		"cities": cities.duplicate(true),
		"regions": regions.duplicate(true),
		"lanes": lanes.duplicate(true),
		"player_owned_lanes": player_owned_lanes.duplicate(),
		"lane_assignments": lane_assignments.duplicate(),
		"lane_status": lane_status.duplicate(),
		"lane_congestion": lane_congestion.duplicate(),
		"lane_risk": lane_risk.duplicate(),
		"lane_restrictions": lane_restrictions.duplicate(),
		"blocked_lanes": blocked_lanes.duplicate(),
		"congestion_effects": congestion_effects.duplicate(true),
		"risk_modifiers": risk_modifiers.duplicate(true),
		"lane_upgrades": lane_upgrades.duplicate(true)
	}

# Load save data for the map system
func load_save_data(data: Dictionary) -> void:
	# Clear existing data
	cities.clear()
	regions.clear()
	lanes.clear()
	player_owned_lanes.clear()
	lane_assignments.clear()
	lane_status.clear()
	lane_congestion.clear()
	lane_risk.clear()
	lane_restrictions.clear()
	blocked_lanes.clear()
	congestion_effects.clear()
	risk_modifiers.clear()
	lane_upgrades.clear()
	path_cache.clear()
	
	# Load data
	cities = data["cities"].duplicate(true)
	regions = data["regions"].duplicate(true)
	lanes = data["lanes"].duplicate(true)
	player_owned_lanes = data["player_owned_lanes"].duplicate()
	lane_assignments = data["lane_assignments"].duplicate()
	lane_status = data["lane_status"].duplicate()
	lane_congestion = data["lane_congestion"].duplicate()
	lane_risk = data["lane_risk"].duplicate()
	lane_restrictions = data["lane_restrictions"].duplicate()
	blocked_lanes = data["blocked_lanes"].duplicate()
	congestion_effects = data["congestion_effects"].duplicate(true)
	risk_modifiers = data["risk_modifiers"].duplicate(true)
	lane_upgrades = data["lane_upgrades"].duplicate(true)
	
	debug_log("Map data loaded")

# Override get_class from base
func get_class() -> String:
	return "MapManager"
