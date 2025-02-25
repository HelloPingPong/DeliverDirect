# carrier_manager.gd
class_name CarrierManager
extends Node

# Carrier data structure
var carriers: Dictionary = {}
var carrier_history: Dictionary = {}
var active_contracts: Dictionary = {}
var carrier_preferences: Dictionary = {}

# Configuration
var carrier_update_interval: float = 5.0  # Seconds between carrier AI updates
var carrier_offer_probability: float = 0.3  # Base chance of a carrier making an offer
var timer_since_last_update: float = 0.0

# Reference to other systems
var economy_manager: EconomyEmulator
var player_manager: PlayerManager

# Signals
signal carrier_added(carrier_id, carrier_name)
signal carrier_removed(carrier_id)
signal carrier_offer_made(carrier_id, lane_id, price, estimated_time)
signal carrier_contract_accepted(contract_id, carrier_id, lane_id)
signal carrier_contract_completed(contract_id, on_time, quality)
signal carrier_contract_failed(contract_id, reason)
signal carrier_reputation_changed(carrier_id, new_reputation)

func _ready():
    # Get references to other systems
    economy_manager = get_node("/root/GameManager/EconomyEmulator")
    player_manager = get_node("/root/GameManager/PlayerManager")

# Core carrier management functions
func add_carrier(carrier_id: String, carrier_name: String, 
                initial_reputation: float, fleet_size: int):
    if carriers.has(carrier_id):
        print_debug("Warning: Carrier ID already exists: ", carrier_id)
        return
        
    var carrier = {
        "id": carrier_id,
        "name": carrier_name,
        "reputation": initial_reputation,
        "fleet_size": fleet_size,
        "reliability": initial_reputation / 100.0,  # 0.0 to 1.0 based on reputation
        "speed_factor": 1.0,  # Multiplier for delivery time
        "busy_until": 0.0,  # Game time when carrier becomes available again
        "is_blacklisted": false,
        "is_trusted": initial_reputation >= 80.0,
        "preferred_cargo": [],  # Types of cargo this carrier prefers
        "active_contracts": [],  # Currently assigned contracts
        "risk_tolerance": randf_range(0.2, 0.8),  # Willingness to take risky contracts
        "pricing_factor": randf_range(0.8, 1.2),  # Tendency to charge more/less
        "negotiation_style": _generate_negotiation_style(),
        "failure_chance": max(0.01, 0.3 - (initial_reputation / 100.0) * 0.25),  # Chance of late/failed delivery
    }
    
    # Initialize carrier history
    carrier_history[carrier_id] = {
        "completed_contracts": 0,
        "failed_contracts": 0,
        "on_time_deliveries": 0,
        "late_deliveries": 0,
        "average_quality": 0.0,
        "last_contracts": [],  # Recent contracts for reference
    }
    
    # Initialize carrier preferences to default values
    carrier_preferences[carrier_id] = {
        "lane_preferences": {},
        "cargo_preferences": {},
    }
    
    carriers[carrier_id] = carrier
    emit_signal("carrier_added", carrier_id, carrier_name)

func remove_carrier(carrier_id: String):
    if carriers.has(carrier_id):
        carriers.erase(carrier_id)
        emit_signal("carrier_removed", carrier_id)

# Carrier preference settings
func set_carrier_preference(carrier_id: String, cargo_type: String, preference_value: float):
    if not carriers.has(carrier_id):
        print_debug("Warning: Unknown carrier ID: ", carrier_id)
        return
        
    if not carrier_preferences.has(carrier_id):
        carrier_preferences[carrier_id] = {
            "lane_preferences": {},
            "cargo_preferences": {},
        }
        
    carrier_preferences[carrier_id]["cargo_preferences"][cargo_type] = preference_value
    # Add to preferred cargo list for quick reference
    if preference_value > 1.0 and not carriers[carrier_id]["preferred_cargo"].has(cargo_type):
        carriers[carrier_id]["preferred_cargo"].append(cargo_type)

func set_lane_preference(carrier_id: String, lane_id: String, preference_value: float):
    if not carriers.has(carrier_id):
        print_debug("Warning: Unknown carrier ID: ", carrier_id)
        return
        
    if not carrier_preferences.has(carrier_id):
        carrier_preferences[carrier_id] = {
            "lane_preferences": {},
            "cargo_preferences": {},
        }
        
    carrier_preferences[carrier_id]["lane_preferences"][lane_id] = preference_value

# Carrier vetting and background checks
func get_carrier_profile(carrier_id: String) -> Dictionary:
    if not carriers.has(carrier_id):
        return {}
        
    var carrier = carriers[carrier_id]
    
    # Return public information about the carrier
    return {
        "id": carrier.id,
        "name": carrier.name,
        "reputation": carrier.reputation,
        "fleet_size": carrier.fleet_size,
        "preferred_cargo": carrier.preferred_cargo,
        "is_blacklisted": carrier.is_blacklisted,
        "is_trusted": carrier.is_trusted,
    }

func perform_background_check(carrier_id: String, check_depth: int = 1) -> Dictionary:
    # Different check depths reveal different levels of information
    # 1 = basic, 2 = standard, 3 = thorough
    
    if not carriers.has(carrier_id) or not carrier_history.has(carrier_id):
        return {}
    
    var carrier = carriers[carrier_id]
    var history = carrier_history[carrier_id]
    var result = get_carrier_profile(carrier_id)  # Start with public info
    
    # Add progressively more detailed information based on check depth
    if check_depth >= 1:
        result["completed_contracts"] = history.completed_contracts
        result["failed_contracts"] = history.failed_contracts
    
    if check_depth >= 2:
        result["on_time_rate"] = history.on_time_deliveries / max(1, history.completed_contracts)
        result["failure_rate"] = history.failed_contracts / max(1, history.completed_contracts + history.failed_contracts)
        result["average_quality"] = history.average_quality
    
    if check_depth >= 3:
        # Thorough check reveals hidden risk factors and past performance details
        result["reliability"] = carrier.reliability
        result["risk_tolerance"] = carrier.risk_tolerance
        result["failure_chance"] = carrier.failure_chance
        result["last_contracts"] = history.last_contracts
        
        # Thorough check might reveal fake credentials
        result["has_fake_credentials"] = _has_fake_credentials(carrier_id)
    
    return result

func _has_fake_credentials(carrier_id: String) -> bool:
    # Determine if a carrier has fake credentials
    # This would typically be hidden from the player unless they do a thorough check
    var carrier = carriers[carrier_id]
    
    # Shady carriers (lower reputation) are more likely to have fake credentials
    var fake_chance = max(0.0, 0.5 - (carrier.reputation / 100.0) * 0.5)
    
    # For deterministic behavior, we can seed the random check with the carrier ID
    var fake_seed = carrier_id.hash()
    seed(fake_seed)
    var has_fake = randf() < fake_chance
    seed(Time.get_ticks_msec())  # Reset seed
    
    return has_fake

# Contract and offer management
func generate_carrier_offer(lane_id: String, cargo_type: String, cargo_amount: float, 
                          deadline: float, game_time: float) -> Dictionary:
    # Pick an appropriate carrier for this job
    var potential_carriers = _find_suitable_carriers(lane_id, cargo_type, cargo_amount, game_time)
    
    if potential_carriers.size() == 0:
        return {}  # No suitable carriers
        
    # Choose a carrier (we could select multiple for competing offers)
    var selected_carrier_id = potential_carriers[randi() % potential_carriers.size()]
    var carrier = carriers[selected_carrier_id]
    
    # Calculate the carrier's price for this job
    var base_price = _calculate_base_price(lane_id, cargo_type, cargo_amount)
    var offered_price = _adjust_price_for_carrier(base_price, selected_carrier_id, lane_id, cargo_type)
    
    # Calculate estimated delivery time
    var base_time = _get_lane_travel_time(lane_id)
    var estimated_time = base_time * carrier.speed_factor
    
    # Create the offer
    var offer = {
        "carrier_id": selected_carrier_id,
        "lane_id": lane_id,
        "cargo_type": cargo_type,
        "cargo_amount": cargo_amount,
        "price": offered_price,
        "estimated_time": estimated_time,
        "deadline": deadline,
        "offer_expiration": game_time + 60.0,  # Offer expires in 1 minute of game time
    }
    
    emit_signal("carrier_offer_made", selected_carrier_id, lane_id, offered_price, estimated_time)
    return offer

func accept_carrier_offer(offer: Dictionary, game_time: float) -> String:
    # Player accepts a carrier's offer, creating a contract
    if not carriers.has(offer.carrier_id):
        return ""
        
    var carrier = carriers[offer.carrier_id]
    
    # Generate a unique contract ID
    var contract_id = "C" + str(game_time).md5_text().substr(0, 8)
    
    # Create the contract
    var contract = {
        "id": contract_id,
        "carrier_id": offer.carrier_id,
        "lane_id": offer.lane_id,
        "cargo_type": offer.cargo_type,
        "cargo_amount": offer.cargo_amount,
        "price": offer.price,
        "estimated_time": offer.estimated_time,
        "deadline": offer.deadline,
        "start_time": game_time,
        "expected_completion": game_time + offer.estimated_time,
        "status": "active",
        "actual_completion_time": 0.0,
        "quality": 0.0,
    }
    
    # Add to active contracts
    active_contracts[contract_id] = contract
    
    # Update carrier availability
    carrier.active_contracts.append(contract_id)
    carrier.busy_until = max(carrier.busy_until, game_time + offer.estimated_time)
    
    emit_signal("carrier_contract_accepted", contract_id, offer.carrier_id, offer.lane_id)
    return contract_id

func reject_carrier_offer(offer: Dictionary):
    # Player rejects a carrier's offer
    if not carriers.has(offer.carrier_id):
        return
    
    # Potential reputation effect with the carrier
    # More frequent rejections might make carrier less eager to work with player
    pass

func negotiate_carrier_offer(offer: Dictionary, counter_price: float) -> Dictionary:
    # Player attempts to negotiate the offer price
    if not carriers.has(offer.carrier_id):
        return {}
        
    var carrier = carriers[offer.carrier_id]
    var original_price = offer.price
    
    # Calculate carrier's willingness to negotiate
    var negotiation_threshold = _calculate_negotiation_threshold(carrier, offer)
    
    # Check if counteroffer is acceptable
    if counter_price >= original_price * negotiation_threshold:
        # Carrier accepts the counteroffer
        var new_offer = offer.duplicate()
        new_offer.price = counter_price
        return new_offer
    else:
        # Carrier rejects or makes a counter-counteroffer
        var counter_style = carrier.negotiation_style
        
        if counter_style == "firm":
            # Carrier stands firm on original price
            return {}  # Rejection
        elif counter_style == "flexible":
            # Carrier meets halfway
            var middle_ground = (original_price + counter_price) / 2
            var new_offer = offer.duplicate()
            new_offer.price = middle_ground
            return new_offer
        elif counter_style == "aggressive":
            # Carrier feels insulted and increases price slightly
            var new_offer = offer.duplicate()
            new_offer.price = original_price * 1.05  # 5% increase
            return new_offer
        else:  # "fair"
            # Carrier proposes a reasonable compromise
            var compromise = original_price * 0.95  # 5% discount
            var new_offer = offer.duplicate()
            new_offer.price = max(compromise, counter_price * 1.1)  # At least 10% more than counter
            return new_offer
    
    return {}  # Default rejection

# Utility functions
func _find_suitable_carriers(lane_id: String, cargo_type: String, cargo_amount: float, 
                           game_time: float) -> Array:
    var suitable_carriers = []
    
    for carrier_id in carriers.keys():
        var carrier = carriers[carrier_id]
        
        # Skip blacklisted, fully booked, or otherwise unsuitable carriers
        if carrier.is_blacklisted:
            continue
            
        if carrier.busy_until > game_time:
            continue
            
        if carrier.active_contracts.size() >= carrier.fleet_size:
            continue
            
        # Check if carrier specializes in this type of cargo or lane
        var specializes = false
        
        if carrier.preferred_cargo.has(cargo_type):
            specializes = true
            
        if carrier_preferences.has(carrier_id) and carrier_preferences[carrier_id]["lane_preferences"].has(lane_id):
            specializes = true
            
        # Add carrier to suitable list, with higher chance if they specialize
        if specializes or randf() < carrier_offer_probability:
            suitable_carriers.append(carrier_id)
    }
    
    return suitable_carriers

func _calculate_base_price(lane_id: String, cargo_type: String, cargo_amount: float) -> float:
    # Get the base commodity price from the economy system
    var commodity_price = economy_manager.get_price(cargo_type)
    
    # Get the lane distance or cost factor
    var lane_factor = _get_lane_cost_factor(lane_id)
    
    # Calculate a basic price based on cargo value and distance
    var base_price = commodity_price * cargo_amount * lane_factor
    
    return base_price

func _adjust_price_for_carrier(base_price: float, carrier_id: String, 
                             lane_id: String, cargo_type: String) -> float:
    var carrier = carriers[carrier_id]
    var adjusted_price = base_price * carrier.pricing_factor
    
    # Check if carrier has preferences that affect pricing
    if carrier_preferences.has(carrier_id):
        var prefs = carrier_preferences[carrier_id]
        
        # Preferred cargo types get a discount
        if prefs["cargo_preferences"].has(cargo_type):
            adjusted_price *= prefs["cargo_preferences"][cargo_type]
            
        # Preferred lanes get a discount
        if prefs["lane_preferences"].has(lane_id):
            adjusted_price *= prefs["lane_preferences"][lane_id]
    }
    
    return adjusted_price

func _get_lane_travel_time(lane_id: String) -> float:
    # This would normally query the map system for lane distance and calculate travel time
    # For now, we'll return a placeholder value
    return 120.0  # 2 hours of game time

func _get_lane_cost_factor(lane_id: String) -> float:
    # This would normally query the map system for lane properties
    # For now, we'll return a placeholder value
    return 1.5

func _calculate_negotiation_threshold(carrier: Dictionary, offer: Dictionary) -> float:
    # Calculate the minimum price ratio a carrier will accept
    var threshold = 0.85  # Default: accept 85% of original price
    
    # Adjust based on carrier's negotiation style
    match carrier.negotiation_style:
        "firm":
            threshold = 0.95  # Only accept 5% discount
        "flexible":
            threshold = 0.80  # Accept up to 20% discount
        "aggressive":
            threshold = 0.98  # Very little room for negotiation
        "fair":
            threshold = 0.85  # Standard 15% discount possible
    
    # Adjust based on player reputation
    var player_reputation = player_manager.get_reputation()
    
    # High-reputation players can negotiate better deals
    threshold -= (player_reputation / 100.0) * 0.1  # Up to 10% better deals
    
    # Adjust based on carrier's relationship with player
    # Future enhancement: track individual relationships
    
    return threshold

func _generate_negotiation_style() -> String:
    # Generate a negotiation style for a carrier
    var styles = ["firm", "flexible", "aggressive", "fair"]
    var weights = [0.25, 0.25, 0.2, 0.3]  # Probability weights
    
    var total_weight = 0.0
    for w in weights:
        total_weight += w
        
    var roll = randf() * total_weight
    var current_weight = 0.0
    
    for i in range(styles.size()):
        current_weight += weights[i]
        if roll < current_weight:
            return styles[i]
            
    return "fair"  # Default

# Update loop for carrier AI behavior
func update(delta: float, game_time: float):
    timer_since_last_update += delta
    
    # Update carriers periodically rather than every frame
    if timer_since_last_update >= carrier_update_interval:
        timer_since_last_update = 0.0
        
        # Check for contract completions
        _check_contract_completions(game_time)
        
        # Update carrier statuses
        _update_carrier_statuses(game_time)
        
        # Generate spontaneous offers if appropriate
        _generate_spontaneous_offers(game_time)

func _check_contract_completions(game_time: float):
    var contracts_to_complete = []
    
    # Find contracts due for completion
    for contract_id in active_contracts.keys():
        var contract = active_contracts[contract_id]
        
        if contract.status != "active":
            continue
            
        if game_time >= contract.expected_completion:
            contracts_to_complete.append(contract_id)
    
    # Process completions
    for contract_id in contracts_to_complete:
        _complete_contract(contract_id, game_time)

func _complete_contract(contract_id: String, game_time: float):
    var contract = active_contracts[contract_id]
    var carrier_id = contract.carrier_id
    
    if not carriers.has(carrier_id):
        # Carrier no longer exists - handle this edge case
        contract.status = "failed"
        emit_signal("carrier_contract_failed", contract_id, "carrier_not_found")
        return
        
    var carrier = carriers[carrier_id]
    
    # Determine if delivery was successful
    var success = randf() > carrier.failure_chance
    
    if success:
        # Successful delivery
        var on_time = game_time <= contract.deadline
        var quality = randf_range(0.7, 1.0) * carrier.reliability
        
        # Update contract
        contract.status = "completed"
        contract.actual_completion_time = game_time
        contract.quality = quality
        
        # Update carrier history
        var history = carrier_history[carrier_id]
        history.completed_contracts += 1
        
        if on_time:
            history.on_time_deliveries += 1
        else:
            history.late_deliveries += 1
            
        history.average_quality = (history.average_quality * (history.completed_contracts - 1) + quality) / history.completed_contracts
        
        if history.last_contracts.size() >= 10:
            history.last_contracts.pop_front()
        history.last_contracts.append({
            "id": contract_id,
            "on_time": on_time,
            "quality": quality
        })
        
        # Update carrier status
        carrier.active_contracts.erase(contract_id)
        
        # Signal completion
        emit_signal("carrier_contract_completed", contract_id, on_time, quality)
    else:
        # Failed delivery
        contract.status = "failed"
        
        # Update carrier history
        var history = carrier_history[carrier_id]
        history.failed_contracts += 1
        
        if history.last_contracts.size() >= 10:
            history.last_contracts.pop_front()
        history.last_contracts.append({
            "id": contract_id,
            "failed": true
        })
        
        # Update carrier status
        carrier.active_contracts.erase(contract_id)
        
        # Signal failure
        emit_signal("carrier_contract_failed", contract_id, "carrier_failure")
        
        # Adjust carrier reputation downward
        _adjust_carrier_reputation(carrier_id, -5.0)

func _update_carrier_statuses(game_time: float):
    # Update each carrier's status based on their performance history
    for carrier_id in carriers.keys():
        var carrier = carriers[carrier_id]
        var history = carrier_history[carrier_id]
        
        # Skip carriers with no history
        if history.completed_contracts + history.failed_contracts == 0:
            continue
            
        # Calculate reliability based on history
        var success_rate = float(history.completed_contracts) / max(1, history.completed_contracts + history.failed_contracts)
        var on_time_rate = float(history.on_time_deliveries) / max(1, history.completed_contracts)
        
        # Update carrier reliability factors
        carrier.reliability = (success_rate * 0.6) + (on_time_rate * 0.4)
        carrier.failure_chance = max(0.01, 0.3 - carrier.reliability * 0.25)
        
        # Update trusted status
        carrier.is_trusted = carrier.reputation >= 80.0

func _adjust_carrier_reputation(carrier_id: String, amount: float):
    if not carriers.has(carrier_id):
        return
        
    var carrier = carriers[carrier_id]
    var old_reputation = carrier.reputation
    
    # Apply change, clamping to valid range
    carrier.reputation = clamp(carrier.reputation + amount, 0.0, 100.0)
    
    # Update dependent attributes
    _update_carrier_statuses(0)  # 0 is a placeholder for game_time
    
    emit_signal("carrier_reputation_changed", carrier_id, carrier.reputation)

func _generate_spontaneous_offers(game_time: float):
    # Occasionally, carriers might generate unsolicited offers
    # This would integrate with the customer system for available contracts
    pass

# Signal handlers
func _on_price_changed(item_name, new_price, actor_name):
    # Respond to economy price changes
    # This might affect carrier pricing and offers
    pass

func _on_carrier_assigned(lane_id, carrier_id):
    # Handle map UI interactions where player assigns carriers
    pass

# Carrier info and debugging
func get_all_carriers() -> Array:
    return carriers.keys()

func get_carrier_name(carrier_id: String) -> String:
    if carriers.has(carrier_id):
        return carriers[carrier_id].name
    return ""
