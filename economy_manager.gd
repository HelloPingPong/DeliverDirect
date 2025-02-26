extends AbstractManager
class_name EconomyManager

# Signals
signal market_updated(commodity_info)
signal price_surge(commodity_type, surge_factor)
signal price_drop(commodity_type, drop_factor)
signal market_crash(severity)
signal market_boom(intensity)
signal commodity_added(commodity_id)
signal commodity_group_added(group_id)

# Reference to economy emulator
var economy_emulator: EconomyEmulator

# Commodity categories and types (from data sheet)
var commodity_categories = {
	"FAGRP": "Food and Agricultural Products",
	"ICMAT": "Industrial and Construction Materials",
	"AUMAC": "Automotive and Machinery",
	"ELTEC": "Electronics and Technology",
	"MEDPH": "Medical and Pharmaceutical",
	"TEXAP": "Textiles and Apparel",
	"MISEX": "Miscellaneous and Exotic",
	"MILSP": "Military Supplies",
	"ILDOS": "Illegal or Dangerous Objects/Substances",
	"SPCEX": "Space Exploration and Astronomical",
	"MYFAN": "Mythical and Fantasy Items",
	"RTLMD": "Retail Merchandise",
	"RAWMA": "Raw Materials",
	"DRYFG": "Dry Freight",
	"BEVGS": "Beverages"
}

# Individual commodities
var commodities = {}

# Market trends for each commodity
var market_trends = {}
var demand_factors = {}
var supply_factors = {}

# Market price history
var price_history = {}

# Economic conditions per region
var regional_economies = {}

# Market events
var active_market_events = []

# Base price for fuel (important commodity)
var base_fuel_price: float = 3.5  # dollars per gallon

# Additional price modifiers
var global_inflation: float = 0.0
var seasonal_factors = {}

# Constants
const MAX_PRICE_HISTORY_DAYS: int = 30
const PRICE_CHANGE_LIMIT: float = 0.25  # Maximum 25% change per day
const BASE_DAILY_DRIFT: float = 0.05    # Maximum 5% daily random drift

# Initialize economy
func _setup() -> void:
	debug_log("Setting up Economy Manager")
	
	# Create economy emulator instance
	economy_emulator = EconomyEmulator.new()
	add_child(economy_emulator)
	
	# Load initial commodity data
	_load_commodity_data()

# Initialize economy for a new game
func initialize_economy() -> void:
	debug_log("Initializing economy")
	
	# Reset the emulator
	economy_emulator = EconomyEmulator.new()
	add_child(economy_emulator)
	
	# Setup base EconomyEmulator configuration
	economy_emulator.set_base_price_grow(0.001)  # 0.1% daily growth
	economy_emulator.set_money_precision(0.01)
	
	# Add price drifts for realistic volatility
	economy_emulator.add_base_price_drift(0.03, 14.0)  # 3% biweekly cycle
	economy_emulator.add_base_price_drift(0.05, 30.0)  # 5% monthly cycle
	
	# Configure global actor
	economy_emulator.add_actor("global_market")
	
	# Add regional actors
	_setup_regional_actors()
	
	# Load initial commodities
	_load_commodity_data()
	
	# Setup initial price modifiers
	_setup_initial_price_modifiers()
	
	# Initialize trends
	_initialize_market_trends()
	
	# Setup seasonal factors
	_setup_seasonal_factors()

# Setup regional economic actors
func _setup_regional_actors() -> void:
	var regions = game_manager.map_manager.regions
	
	for region_id in regions.keys():
		var region = regions[region_id]
		
		# Create an economy actor for this region
		economy_emulator.add_actor(region_id, "global_market", 0.9)
		
		# Store regional economic data
		regional_economies[region_id] = {
			"name": region["name"],
			"economy_strength": region.get("economy_strength", 0.7),
			"specialties": [],
			"price_modifiers": {}
		}
		
		# Add regional specialties based on industries
		for city_id in region["cities"]:
			var city = game_manager.map_manager.cities[city_id]
			for industry in city["industries"]:
				if not regional_economies[region_id]["specialties"].has(industry):
					regional_economies[region_id]["specialties"].append(industry)
					
					# Add price modifier for specialty (reduced prices for producing regions)
					# This makes it strategic to buy goods from producing regions
					economy_emulator.add_modifier(
						"specialty_" + region_id + "_" + industry, 
						industry, 
						0.85,  # 15% discount
						PriceModifier.Types.MULTIPLY, 
						PriceModifier.StackingTypes.BASE
					)
					economy_emulator.activate_modifier("specialty_" + region_id + "_" + industry, region_id)

# Load commodity data from predefined list
func _load_commodity_data() -> void:
	# This would typically load from a data file
	# For now, we'll hardcode some example commodities
	
	# FAGRP - Food and Agricultural Products
	_add_commodity("FVEG", "Fresh Vegetables", "FAGRP", 2000.0)
	_add_commodity("FMEA", "Frozen Meat", "FAGRP", 3500.0)
	_add_commodity("OHNY", "Organic Honey", "FAGRP", 4500.0)
	_add_commodity("EFRU", "Exotic Fruits", "FAGRP", 5000.0)
	
	# ICMAT - Industrial and Construction Materials
	_add_commodity("STBM", "Steel Beams", "ICMAT", 6000.0)
	_add_commodity("LUMB", "Lumber", "ICMAT", 3000.0)
	_add_commodity("ISND", "Industrial Sand", "ICMAT", 1500.0)
	_add_commodity("PMET", "Precious Metals", "ICMAT", 15000.0)
	
	# AUMAC - Automotive and Machinery
	_add_commodity("ECBT", "Electric Car Batteries", "AUMAC", 8000.0)
	_add_commodity("TRCT", "Tractors", "AUMAC", 25000.0)
	_add_commodity("JENG", "Jet Engines", "AUMAC", 35000.0)
	
	# ELTEC - Electronics and Technology
	_add_commodity("SMPH", "Smartphones", "ELTEC", 10000.0)
	_add_commodity("SLPL", "Solar Panels", "ELTEC", 12000.0)
	_add_commodity("FOCA", "Fiber Optic Cables", "ELTEC", 5000.0)
	
	# MEDPH - Medical and Pharmaceutical
	_add_commodity("VACC", "Vaccines", "MEDPH", 9000.0)
	_add_commodity("MEQP", "Medical Equipment", "MEDPH", 15000.0)
	_add_commodity("PLMB", "Prosthetic Limbs", "MEDPH", 18000.0)
	
	# TEXAP - Textiles and Apparel
	_add_commodity("DCLS", "Designer Clothes", "TEXAP", 7000.0)
	_add_commodity("SILK", "Silk Fabrics", "TEXAP", 8000.0)
	
	# Create commodity groups
	_create_commodity_group("perishable", ["FVEG", "FMEA", "EFRU"])
	_create_commodity_group("construction", ["STBM", "LUMB", "ISND"])
	_create_commodity_group("electronics", ["SMPH", "SLPL", "FOCA"])
	_create_commodity_group("medical", ["VACC", "MEQP", "PLMB"])
	_create_commodity_group("luxury", ["DCLS", "SILK", "PMET"])
	
	# Special case - fuel
	_add_commodity("FUEL", "Fuel", "RAWMA", base_fuel_price * 1000.0)  # Price per 1000 gallons

# Add a commodity to the economy
func _add_commodity(commodity_id: String, name: String, category: String, base_price: float) -> void:
	# Store commodity information
	commodities[commodity_id] = {
		"id": commodity_id,
		"name": name,
		"category": category,
		"base_price": base_price
	}
	
	# Add to economy emulator
	economy_emulator.add_item(commodity_id, base_price)
	
	# Initialize price history
	price_history[commodity_id] = []
	
	# Initialize market trends
	market_trends[commodity_id] = 0.0  # 0 = stable, positive = increasing, negative = decreasing
	demand_factors[commodity_id] = 1.0  # 1.0 = normal demand
	supply_factors[commodity_id] = 1.0  # 1.0 = normal supply
	
	emit_signal("commodity_added", commodity_id)
	debug_log("Added commodity: " + commodity_id + " (" + name + ") at $" + str(base_price))

# Create a commodity group
func _create_commodity_group(group_id: String, commodity_ids: Array) -> void:
	economy_emulator.add_group(group_id)
	
	for commodity_id in commodity_ids:
		if commodities.has(commodity_id):
			economy_emulator.add_item_to_group(commodity_id, group_id)
	
	emit_signal("commodity_group_added", group_id)
	debug_log("Created commodity group: " + group_id + " with " + str(commodity_ids.size()) + " items")

# Setup initial price modifiers
func _setup_initial_price_modifiers() -> void:
	# Add global price modifiers
	economy_emulator.add_modifier(
		"global_inflation", 
		"", # Empty means applies to all
		1.0 + global_inflation, 
		PriceModifier.Types.MULTIPLY, 
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier("global_inflation")
	
	# Add region-specific modifiers
	for region_id in regional_economies.keys():
		var region = regional_economies[region_id]
		
		# Economy strength affects prices
		var strength_modifier = 1.0 - ((region["economy_strength"] - 0.7) * 0.3)
		
		economy_emulator.add_modifier(
			"economy_strength_" + region_id,
			"",
			strength_modifier,
			PriceModifier.Types.MULTIPLY,
			PriceModifier.StackingTypes.BASE
		)
		economy_emulator.activate_modifier("economy_strength_" + region_id, region_id)
	
	# Add category-specific modifiers
	_setup_category_modifiers()

# Setup category-specific price modifiers
func _setup_category_modifiers() -> void:
	# Electronics are generally more expensive
	economy_emulator.add_modifier(
		"tech_premium",
		"ELTEC",
		1.1,
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier("tech_premium")
	
	# Medical supplies are also premium
	economy_emulator.add_modifier(
		"medical_premium",
		"MEDPH",
		1.15,
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier("medical_premium")
	
	# Luxury goods get a premium
	economy_emulator.add_modifier(
		"luxury_premium",
		"luxury",
		1.2,
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier("luxury_premium")

# Initialize market trends
func _initialize_market_trends() -> void:
	for commodity_id in commodities.keys():
		# Random initial trend
		market_trends[commodity_id] = (randf() * 0.2) - 0.1  # -0.1 to +0.1
		
		# Random initial supply/demand
		supply_factors[commodity_id] = 0.9 + (randf() * 0.2)  # 0.9 to 1.1
		demand_factors[commodity_id] = 0.9 + (randf() * 0.2)  # 0.9 to 1.1
	
	debug_log("Market trends initialized")

# Setup seasonal factors
func _setup_seasonal_factors() -> void:
	# This simulates seasonal effects on prices
	seasonal_factors = {
		"winter": {
			"FAGRP": 1.2,  # Food more expensive in winter
			"ICMAT": 0.9,  # Construction slows in winter
			"FUEL": 1.3    # Fuel more expensive in winter
		},
		"spring": {
			"FAGRP": 0.9,  # Food cheaper as growing season starts
			"TEXAP": 1.1   # Clothing demand up with season change
		},
		"summer": {
			"ELTEC": 1.1,  # Electronics demand up
			"FUEL": 1.1    # Fuel more expensive in summer
		},
		"fall": {
			"FAGRP": 0.8,  # Food cheaper after harvest
			"TEXAP": 1.1   # Clothing demand up with season change
		}
	}

# Apply seasonal modifiers based on current game day
func _apply_seasonal_modifiers() -> void:
	var day = game_manager.current_game_day
	var days_per_year = 360  # Game year length
	var days_per_season = days_per_year / 4
	
	var current_season = ""
	
	# Determine current season
	var day_of_year = day % days_per_year
	if day_of_year < days_per_season:
		current_season = "winter"
	elif day_of_year < days_per_season * 2:
		current_season = "spring"
	elif day_of_year < days_per_season * 3:
		current_season = "summer"
	else:
		current_season = "fall"
	
	# Apply seasonal modifiers
	if seasonal_factors.has(current_season):
		var season_modifiers = seasonal_factors[current_season]
		
		for category in season_modifiers.keys():
			var modifier_id = "seasonal_" + category
			var modifier_value = season_modifiers[category]
			
			# See if this modifier already exists
			if economy_emulator.modifiers.has(modifier_id):
				# Update existing modifier
				economy_emulator.remove_modifier(modifier_id)
			
			# Add new modifier
			economy_emulator.add_modifier(
				modifier_id,
				category,
				modifier_value,
				PriceModifier.Types.MULTIPLY,
				PriceModifier.StackingTypes.BASE
			)
			economy_emulator.activate_modifier(modifier_id)
			
			debug_log("Applied seasonal modifier " + modifier_id + ": " + str(modifier_value))

# Update global time for economy emulator
func update_global_time(time: float) -> void:
	economy_emulator.update_global_time(time)

# Process daily economy update
func process_daily_update() -> void:
	debug_log("Processing economy daily update")
	
	# Update market trends
	_update_market_trends()
	
	# Apply seasonal modifiers
	_apply_seasonal_modifiers()
	
	# Process active market events
	_process_market_events()
	
	# Update all prices
	economy_emulator.update_all_prices()
	
	# Record price history
	_record_price_history()
	
	# Notify market update
	emit_signal("market_updated", get_current_prices())

# Update market trends for all commodities
func _update_market_trends() -> void:
	for commodity_id in commodities.keys():
		# Gradually shift trends
		var current_trend = market_trends[commodity_id]
		var trend_shift = (randf() * 0.1) - 0.05  # -0.05 to +0.05
		var new_trend = clamp(current_trend + trend_shift, -0.2, 0.2)
		market_trends[commodity_id] = new_trend
		
		# Apply trend to demand factor
		var demand_shift = new_trend * 0.5  # Half of the trend affects demand
		demand_factors[commodity_id] = clamp(demand_factors[commodity_id] + demand_shift, 0.5, 1.5)
		
		# Apply demand to economy emulator via modifiers
		_update_demand_modifier(commodity_id, demand_factors[commodity_id])
		
		# Supply fluctuations (more random)
		var supply_shift = (randf() * 0.1) - 0.05  # -0.05 to +0.05
		supply_factors[commodity_id] = clamp(supply_factors[commodity_id] + supply_shift, 0.5, 1.5)
		
		# Apply supply to economy emulator via modifiers
		_update_supply_modifier(commodity_id, supply_factors[commodity_id])

# Update demand modifier for a commodity
func _update_demand_modifier(commodity_id: String, demand_factor: float) -> void:
	var modifier_id = "demand_" + commodity_id
	
	# Remove existing modifier
	if economy_emulator.modifiers.has(modifier_id):
		economy_emulator.remove_modifier(modifier_id)
	
	# Add new modifier - higher demand = higher prices
	economy_emulator.add_modifier(
		modifier_id,
		commodity_id,
		demand_factor,
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier(modifier_id)

# Update supply modifier for a commodity
func _update_supply_modifier(commodity_id: String, supply_factor: float) -> void:
	var modifier_id = "supply_" + commodity_id
	
	# Remove existing modifier
	if economy_emulator.modifiers.has(modifier_id):
		economy_emulator.remove_modifier(modifier_id)
	
	# Add new modifier - higher supply = lower prices
	economy_emulator.add_modifier(
		modifier_id,
		commodity_id,
		1.0 / supply_factor,  # Inverse relationship
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.BASE
	)
	economy_emulator.activate_modifier(modifier_id)

# Process active market events
func _process_market_events() -> void:
	var events_to_remove = []
	
	for i in range(active_market_events.size()):
		var event = active_market_events[i]
		
		# Update event duration
		event["remaining_duration"] -= 1
		
		# Check if event has ended
		if event["remaining_duration"] <= 0:
			events_to_remove.append(i)
			
			# Remove event effects
			if event.has("cleanup_function") and event["cleanup_function"] != "":
				call(event["cleanup_function"], event)
	
	# Remove expired events
	for i in range(events_to_remove.size() - 1, -1, -1):
		debug_log("Market event ended: " + active_market_events[events_to_remove[i]]["name"])
		active_market_events.remove_at(events_to_remove[i])

# Record current prices to history
func _record_price_history() -> void:
	for commodity_id in commodities.keys():
		var price = get_price(commodity_id)
		
		# Add to history
		price_history[commodity_id].append(price)
		
		# Trim history to keep only recent prices
		while price_history[commodity_id].size() > MAX_PRICE_HISTORY_DAYS:
			price_history[commodity_id].pop_front()

# Get current price for a commodity
func get_price(commodity_id: String, region_id: String = "global_market") -> float:
	if not commodities.has(commodity_id):
		return 0.0
	
	return economy_emulator.get_price(commodity_id, game_manager.current_game_time, region_id)

# Get all current prices
func get_current_prices() -> Dictionary:
	var prices = {}
	
	for commodity_id in commodities.keys():
		prices[commodity_id] = {
			"id": commodity_id,
			"name": commodities[commodity_id]["name"],
			"category": commodities[commodity_id]["category"],
			"price": get_price(commodity_id),
			"trend": market_trends[commodity_id],
			"demand": demand_factors[commodity_id],
			"supply": supply_factors[commodity_id]
		}
	
	return prices

# Get market trends
func get_market_trends() -> Dictionary:
	var trends = {}
	
	for commodity_id in commodities.keys():
		trends[commodity_id] = {
			"trend": market_trends[commodity_id],
			"demand": demand_factors[commodity_id],
			"supply": supply_factors[commodity_id],
			"history": price_history[commodity_id].duplicate()
		}
	
	return trends

# Modify price of a specific item directly
func modify_item_price(commodity_id: String, multiplier: float, duration: float = 0.0) -> void:
	if not commodities.has(commodity_id):
		debug_log("Cannot modify non-existent commodity: " + commodity_id)
		return
	
	var modifier_id = "price_mod_" + commodity_id + "_" + str(game_manager.current_game_day)
	
	economy_emulator.add_modifier(
		modifier_id,
		commodity_id,
		multiplier,
		PriceModifier.Types.MULTIPLY,
		PriceModifier.StackingTypes.TOTAL
	)
	economy_emulator.activate_modifier(modifier_id)
	
	# If duration specified, track it for removal later
	if duration > 0:
		var event = {
			"name": "Price Modifier: " + commodity_id,
			"type": "price_modifier",
			"commodity_id": commodity_id,
			"modifier_id": modifier_id,
			"multiplier": multiplier,
			"remaining_duration": duration,
			"cleanup_function": "_cleanup_price_modifier"
		}
		
		active_market_events.append(event)
	
	debug_log("Modified price of " + commodity_id + " by x" + str(multiplier) + 
			  (duration > 0 ? " for " + str(duration) + " days" : ""))
	
	# Emit appropriate signal
	if multiplier > 1.0:
		emit_signal("price_surge", commodity_id, multiplier)
	else:
		emit_signal("price_drop", commodity_id, multiplier)

# Cleanup function for price modifier events
func _cleanup_price_modifier(event: Dictionary) -> void:
	if economy_emulator.modifiers.has(event["modifier_id"]):
		economy_emulator.remove_modifier(event["modifier_id"])

# Trigger a market crash
func trigger_market_crash(severity: float) -> void:
	severity = clamp(severity, 0.0, 1.0)
	
	debug_log("Triggering market crash with severity " + str(severity))
	
	# Apply crash effects to all commodities
	for commodity_id in commodities.keys():
		var crash_multiplier = 1.0 - (severity * 0.5)  # Up to 50% price drop
		
		modify_item_price(commodity_id, crash_multiplier, 10.0 + (severity * 20.0))
	
	# Affect demand globally
	for commodity_id in commodities.keys():
		demand_factors[commodity_id] = max(demand_factors[commodity_id] - (severity * 0.4), 0.5)
	
	# Create a market crash event
	var event = {
		"name": "Market Crash",
		"type": "market_crash",
		"severity": severity,
		"remaining_duration": 15.0 + (severity * 15.0),
		"recovery_rate": 0.05,  # Recovery per day
		"cleanup_function": "_cleanup_market_crash"
	}
	
	active_market_events.append(event)
	
	# Emit signal
	emit_signal("market_crash", severity)

# Cleanup function for market crash event
func _cleanup_market_crash(event: Dictionary) -> void:
	debug_log("Market crash recovery complete")
	
	# No specific cleanup needed as price modifiers handle themselves
	# But we could add additional effects here

# Get local price for a commodity in a specific city
func get_local_price(commodity_id: String, city_id: String) -> float:
	if not commodities.has(commodity_id) or not game_manager.map_manager.cities.has(city_id):
		return 0.0
	
	var city = game_manager.map_manager.cities[city_id]
	var region_id = city["region"]
	
	return get_price(commodity_id, region_id)

# Get save data
func get_save_data() -> Dictionary:
	var data = {
		"commodities": commodities.duplicate(true),
		"market_trends": market_trends.duplicate(),
		"demand_factors": demand_factors.duplicate(),
		"supply_factors": supply_factors.duplicate(),
		"price_history": {},  # Convert arrays to serializable format
		"global_inflation": global_inflation,
		"active_market_events": active_market_events.duplicate(true),
		"base_fuel_price": base_fuel_price
	}
	
	# Convert price history arrays to serializable format
	for commodity_id in price_history.keys():
		data["price_history"][commodity_id] = price_history[commodity_id].duplicate()
	
	return data

# Load save data
func load_save_data(data: Dictionary) -> void:
	# Remove old economy emulator
	if economy_emulator != null:
		economy_emulator.queue_free()
	
	# Create new economy emulator
	economy_emulator = EconomyEmulator.new()
	add_child(economy_emulator)
	
	# Load data
	commodities = data["commodities"].duplicate(true)
	market_trends = data["market_trends"].duplicate()
	demand_factors = data["demand_factors"].duplicate()
	supply_factors = data["supply_factors"].duplicate()
	global_inflation = data["global_inflation"]
	active_market_events = data["active_market_events"].duplicate(true)
	base_fuel_price = data["base_fuel_price"]
	
	# Load price history
	price_history.clear()
	for commodity_id in data["price_history"].keys():
		price_history[commodity_id] = data["price_history"][commodity_id].duplicate()
	
	# Setup regional actors and re-add commodities
	_setup_regional_actors()
	
	# Re-add all commodities to economy emulator
	for commodity_id in commodities.keys():
		var commodity = commodities[commodity_id]
		economy_emulator.add_item(commodity_id, commodity["base_price"])
	
	# Recreate commodity groups
	_create_commodity_group("perishable", ["FVEG", "FMEA", "EFRU"])
	_create_commodity_group("construction", ["STBM", "LUMB", "ISND"])
	_create_commodity_group("electronics", ["SMPH", "SLPL", "FOCA"])
	_create_commodity_group("medical", ["VACC", "MEQP", "PLMB"])
	_create_commodity_group("luxury", ["DCLS", "SILK", "PMET"])
	
	# Setup modifiers
	_setup_initial_price_modifiers()
	
	# Setup seasonal factors
	_setup_seasonal_factors()
	
	# Apply current demand and supply factors
	for commodity_id in commodities.keys():
		_update_demand_modifier(commodity_id, demand_factors[commodity_id])
		_update_supply_modifier(commodity_id, supply_factors[commodity_id])
	
	debug_log("Economy data loaded")

# Override get_class from base
func get_class() -> String:
	return "EconomyManager"
