# event_manager.gd
class_name EventManager
extends Node

# Event storage
var active_events: Dictionary = {}
var scheduled_events: Array = []
var event_templates: Dictionary = {}
var event_effects: Dictionary = {}

# Event timing
var next_random_event_time: float = 0.0
var min_random_event_interval: float = 60.0  # At least 1 minute between random events
var max_random_event_interval: float = 300.0  # At most 5 minutes between random events
var event_check_interval: float = 5.0  # Check for events every 5 seconds
var event_check_timer: float = 0.0

# Event probabilities
var economic_event_weight: float = 0.3
var weather_event_weight: float = 0.25
var carrier_event_weight: float = 0.2
var regulatory_event_weight: float = 0.1
var customer_event_weight: float = 0.15
var criminal_event_weight: float = 0.1  # Less common
var event_weights_sum: float

# References to other systems
var economy_manager: EconomyEmulator
var map_manager: MapManager
var player_manager: PlayerManager
var carrier_manager: CarrierManager
var customer_manager: CustomerManager

# Signals
signal event_triggered(event_id, event_type, affected_ids)
signal event_resolved(event_id, outcome)
signal event_expired(event_id)

func _ready():
    # Get references to other managers
    economy_manager = get_node("/root/GameManager/EconomyEmulator")
    map_manager = get_node("/root/GameManager/MapManager")
    player_manager = get_node("/root/GameManager/PlayerManager")
    carrier_manager = get_node("/root/GameManager/CarrierManager")
    customer_manager = get_node("/root/GameManager/CustomerManager")
    
    # Calculate sum of weights for probability calculations
    event_weights_sum = economic_event_weight + weather_event_weight + carrier_event_weight + \
                      regulatory_event_weight + customer_event_weight + criminal_event_weight
    
    # Create initial event templates
    _create_event_templates()
    
    # Schedule first random event
    _schedule_next_random_event(0)

# Core event management
func create_event(event_type: String, event_name: String, duration: float, 
                 affected_ids: Array, severity: float, is_notification_only: bool = false):
    # Generate a unique event ID
    var event_id = "E" + str(Time.get_unix_time_from_system()).md5_text().substr(0, 8)
    
    var game_time = get_node("/root/GameManager").current_game_time
    
    var event = {
        "id": event_id,
        "type": event_type,
        "name": event_name,
        "start_time": game_time,
        "duration": duration,
        "end_time": game_time + duration,
        "affected_ids": affected_ids,
        "severity": severity,  # 0.0 to 1.0
        "is_active": true,
        "is_notification_only": is_notification_only,
        "player_response": "",
        "outcome": "",
        "effects": {}  # Will store specific effects like price modifiers, etc.
    }
    
    # Apply effects based on event type
    _apply_event_effects(event)
    
    # Store the event
    active_events[event_id] = event
    
    # Emit signal to notify other systems
    emit_signal("event_triggered", event_id, event_type, affected_ids)
    
    return event_id

func resolve_event(event_id: String, player_response: String = ""):
    if !active_events.has(event_id):
        return
    
    var event = active_events[event_id]
    
    # Mark player's response
    event.player_response = player_response
    
    # Calculate outcome based on event type and player response
    var outcome = _calculate_event_outcome(event, player_response)
    event.outcome = outcome
    
    # Apply outcome effects
    _apply_event_outcome(event, outcome)
    
    # For immediate resolution events, mark as inactive
    if outcome == "resolved" || outcome == "mitigated":
        event.is_active = false
    
    emit_signal("event_resolved", event_id, outcome)

func expire_event(event_id: String):
    if !active_events.has(event_id):
        return
    
    var event = active_events[event_id]
    
    # If event wasn't resolved by player, apply default outcome
    if event.outcome == "":
        var default_outcome = _calculate_default_outcome(event)
        event.

func expire_event(event_id: String):
    if !active_events.has(event_id):
        return
    
    var event = active_events[event_id]
    
    # If event wasn't resolved by player, apply default outcome
    if event.outcome == "":
        var default_outcome = _calculate_default_outcome(event)
        event.outcome = default_outcome
        _apply_event_outcome(event, default_outcome)
    
    # Mark as inactive
    event.is_active = false
    
    emit_signal("event_expired", event_id)

# Event generation and scheduling
func _schedule_next_random_event(current_time: float):
    # Calculate when the next random event should happen
    var interval = randf_range(min_random_event_interval, max_random_event_interval)
    next_random_event_time = current_time + interval

func generate_random_event(game_time: float):
    # Select event type based on weighted probabilities
    var roll = randf() * event_weights_sum
    var event_type = ""
    
    if roll < economic_event_weight:
        event_type = "economic"
    elif roll < economic_event_weight + weather_event_weight:
        event_type = "weather"
    elif roll < economic_event_weight + weather_event_weight + carrier_event_weight:
        event_type = "carrier"
    elif roll < economic_event_weight + weather_event_weight + carrier_event_weight + regulatory_event_weight:
        event_type = "regulatory"
    elif roll < economic_event_weight + weather_event_weight + carrier_event_weight + regulatory_event_weight + customer_event_weight:
        event_type = "customer"
    else:
        event_type = "criminal"
    
    # Select a specific event template of this type
    var templates = _get_event_templates_by_type(event_type)
    if templates.size() == 0:
        return ""  # No templates available
    
    var template_index = randi() % templates.size()
    var template_id = templates[template_index]
    var template = event_templates[template_id]
    
    # Generate affected entities based on event type
    var affected_ids = _generate_affected_ids(event_type)
    
    # Generate appropriate duration for this event
    var duration = _generate_event_duration(template)
    
    # Generate severity (some events are more impactful)
    var severity = randf_range(0.2, 1.0)
    
    # Create the event
    return create_event(event_type, template.name, duration, affected_ids, severity, template.is_notification_only)

# Event effects application
func _apply_event_effects(event: Dictionary):
    var event_type = event.type
    var severity = event.severity
    
    # Apply different effects based on event type
    match event_type:
        "economic":
            _apply_economic_event_effects(event)
        "weather":
            _apply_weather_event_effects(event)
        "carrier":
            _apply_carrier_event_effects(event)
        "regulatory":
            _apply_regulatory_event_effects(event)
        "customer":
            _apply_customer_event_effects(event)
        "criminal":
            _apply_criminal_event_effects(event)

func _apply_economic_event_effects(event: Dictionary):
    # Examples: price changes, market shifts
    for affected_id in event.affected_ids:
        if affected_id.begins_with("item_"):
            # It's a commodity - apply price modifier
            var item_name = affected_id.substr(5)  # Remove "item_" prefix
            var modifier_name = "event_" + event.id + "_economic"
            var modifier_value = 1.0 + (event.severity * randf_range(-0.5, 0.5))  # -50% to +50%
            
            # Add price modifier to economy
            economy_manager.add_modifier(modifier_name, item_name, modifier_value)
            economy_manager.activate_modifier(modifier_name)
            
            # Store this so we can remove it when event ends
            event.effects[affected_id] = {
                "type": "price_modifier",
                "modifier_name": modifier_name
            }

func _apply_weather_event_effects(event: Dictionary):
    # Examples: lane disruptions, delivery delays
    for affected_id in event.affected_ids:
        if affected_id.begins_with("lane_"):
            # It's a lane - increase risk and travel time
            if map_manager.lanes.has(affected_id):
                var lane = map_manager.lanes[affected_id]
                
                # Increase traffic congestion due to weather
                lane.traffic_level = min(1.0, lane.traffic_level + event.severity * 0.5)
                
                # Add to affected events list
                if !lane.active_events.has(event.id):
                    lane.active_events.append(event.id)
                
                # Update lane status
                map_manager._update_lane_status(affected_id)
                
                # Store effects
                event.effects[affected_id] = {
                    "type": "lane_disruption",
                    "original_traffic": lane.traffic_level - (event.severity * 0.5)
                }

func _apply_carrier_event_effects(event: Dictionary):
    # Examples: carrier service disruptions, strikes
    for affected_id in event.affected_ids:
        if carrier_manager.carriers.has(affected_id):
            var carrier = carrier_manager.carriers[affected_id]
            
            # Make carrier temporarily unavailable or less reliable
            var original_reliability = carrier.reliability
            carrier.reliability = max(0.1, carrier.reliability - event.severity * 0.3)
            
            # Store effects
            event.effects[affected_id] = {
                "type": "carrier_disruption",
                "original_reliability": original_reliability
            }

func _apply_regulatory_event_effects(event: Dictionary):
    # Examples: new taxes, lane restrictions
    for affected_id in event.affected_ids:
        if affected_id.begins_with("lane_"):
            # It's a lane - add restrictions
            if map_manager.lanes.has(affected_id):
                var lane = map_manager.lanes[affected_id]
                
                # Add cargo restrictions
                var restricted_cargo = "HAZM"  # Example: Restrict hazardous materials
                if !lane.allowed_cargo_types.has(restricted_cargo):
                    lane.allowed_cargo_types.append(restricted_cargo)
                
                # Store effects
                event.effects[affected_id] = {
                    "type": "lane_restriction",
                    "restricted_cargo": restricted_cargo
                }
        elif affected_id.begins_with("item_"):
            # It's a commodity - add tax/tariff
            var item_name = affected_id.substr(5)
            var modifier_name = "event_" + event.id + "_regulatory"
            var modifier_value = 1.0 + (event.severity * 0.2)  # Up to 20% tax/tariff
            
            # Add price modifier to economy
            economy_manager.add_modifier(modifier_name, item_name, modifier_value)
            economy_manager.activate_modifier(modifier_name)
            
            # Store effects
            event.effects[affected_id] = {
                "type": "price_modifier",
                "modifier_name": modifier_name
            }

func _apply_customer_event_effects(event: Dictionary):
    # Examples: demand shifts, contract changes
    for affected_id in event.affected_ids:
        if customer_manager.customers.has(affected_id):
            # Adjust customer demands or expectations
            # Implementation depends on customer manager details
            pass

func _apply_criminal_event_effects(event: Dictionary):
    # Examples: cargo theft, fraud
    for affected_id in event.affected_ids:
        if affected_id.begins_with("shipment_"):
            # It's an active shipment - risk of theft
            if map_manager.active_shipments.has(affected_id):
                var shipment = map_manager.active_shipments[affected_id]
                
                # Increase chance of shipment failure
                # This would typically be applied during shipment update logic
                event.effects[affected_id] = {
                    "type": "shipment_risk",
                    "failure_chance_increase": event.severity * 0.5
                }

# Event outcome calculation
func _calculate_event_outcome(event: Dictionary, player_response: String) -> String:
    var outcome = "ongoing"  # Default - event continues
    
    # Different outcomes based on event type and player response
    match event.type:
        "economic":
            if player_response == "adjust_pricing":
                outcome = "mitigated"
            elif player_response == "invest":
                outcome = "resolved"
        "weather":
            if player_response == "reroute":
                outcome = "mitigated"
            elif player_response == "delay_shipments":
                outcome = "delayed"
        "carrier":
            if player_response == "find_alternative":
                outcome = "resolved"
            elif player_response == "negotiate":
                outcome = "mitigated"
        "regulatory":
            if player_response == "comply":
                outcome = "complied"
            elif player_response == "appeal":
                outcome = "pending_appeal"
        "customer":
            if player_response == "satisfy_demands":
                outcome = "resolved"
            elif player_response == "negotiate":
                outcome = "mitigated"
        "criminal":
            if player_response == "security_measures":
                outcome = "resolved"
            elif player_response == "report_authorities":
                outcome = "under_investigation"
    
    return outcome

func _calculate_default_outcome(event: Dictionary) -> String:
    # If player doesn't respond, calculate default outcome
    var outcome = "expired"
    
    # Different default outcomes based on event type
    match event.type:
        "economic":
            outcome = "market_adjusted"  # Economy eventually stabilized
        "weather":
            outcome = "cleared"  # Weather event eventually passed
        "carrier":
            outcome = "resolved_negatively"  # Carrier issues caused problems
        "regulatory":
            outcome = "enforced"  # Regulations were enforced
        "customer":
            outcome = "customer_dissatisfied"  # Customer unhappy with no response
        "criminal":
            outcome = "successful_crime"  # Crime succeeded without intervention
    
    return outcome

func _apply_event_outcome(event: Dictionary, outcome: String):
    # Apply effects based on the outcome
    match outcome:
        "resolved", "mitigated":
            # Remove negative effects, possibly add positive ones
            _cleanup_event_effects(event)
        "expired", "market_adjusted", "cleared":
            # Normal cleanup of effects
            _cleanup_event_effects(event)
        "resolved_negatively", "enforced", "customer_dissatisfied", "successful_crime":
            # Leave negative effects, possibly intensify them
            # This depends on the specific event
            pass

func _cleanup_event_effects(event: Dictionary):
    # Clean up any effects this event created
    for affected_id in event.effects.keys():
        var effect = event.effects[affected_id]
        
        match effect.type:
            "price_modifier":
                # Remove price modifier from economy
                economy_manager.deactivate_modifier(effect.modifier_name)
            "lane_disruption":
                # Restore lane traffic to original level
                if map_manager.lanes.has(affected_id):
                    var lane = map_manager.lanes[affected_id]
                    lane.traffic_level = effect.original_traffic
                    lane.active_events.erase(event.id)
                    map_manager._update_lane_status(affected_id)
            "carrier_disruption":
                # Restore carrier reliability
                if carrier_manager.carriers.has(affected_id):
                    var carrier = carrier_manager.carriers[affected_id]
                    carrier.reliability = effect.original_reliability
            "lane_restriction":
                # Remove cargo restrictions
                if map_manager.lanes.has(affected_id):
                    var lane = map_manager.lanes[affected_id]
                    lane.allowed_cargo_types.erase(effect.restricted_cargo)

# Helper functions
func _get_event_templates_by_type(event_type: String) -> Array:
    var templates = []
    
    for template_id in event_templates.keys():
        var template = event_templates[template_id]
        if template.type == event_type:
            templates.append(template_id)
    
    return templates

func _generate_affected_ids(event_type: String) -> Array:
    var affected_ids = []
    
    match event_type:
        "economic":
            # Select random commodities to affect
            var all_items = economy_manager.items.keys()
            var num_items = min(3, all_items.size())
            
            for i in range(num_items):
                var random_index = randi() % all_items.size()
                var item = all_items[random_index]
                affected_ids.append("item_" + item)
                all_items.remove(random_index)
        
        "weather":
            # Select random lanes to affect
            var all_lanes = map_manager.lanes.keys()
            var num_lanes = min(3, all_lanes.size())
            
            for i in range(num_lanes):
                if all_lanes.size() == 0:
                    break
                var random_index = randi() % all_lanes.size()
                affected_ids.append(all_lanes[random_index])
                all_lanes.remove(random_index)
        
        "carrier":
            # Select random carriers to affect
            var all_carriers = carrier_manager.carriers.keys()
            var num_carriers = min(2, all_carriers.size())
            
            for i in range(num_carriers):
                if all_carriers.size() == 0:
                    break
                var random_index = randi() % all_carriers.size()
                affected_ids.append(all_carriers[random_index])
                all_carriers.remove(random_index)
        
        "regulatory":
            # Select random lanes or commodities to affect
            if randf() < 0.5:
                # Affect lanes
                var all_lanes = map_manager.lanes.keys()
                var num_lanes = min(2, all_lanes.size())
                
                for i in range(num_lanes):
                    if all_lanes.size() == 0:
                        break
                    var random_index = randi() % all_lanes.size()
                    affected_ids.append(all_lanes[random_index])
                    all_lanes.remove(random_index)
            else:
                # Affect commodities
                var all_items = economy_manager.items.keys()
                var num_items = min(2, all_items.size())
                
                for i in range(num_items):
                    if all_items.size() == 0:
                        break
                    var random_index = randi() % all_items.size()
                    var item = all_items[random_index]
                    affected_ids.append("item_" + item)
                    all_items.remove(random_index)
        
        "customer":
            # Select random customers to affect
            var all_customers = customer_manager.customers.keys()
            var num_customers = min(1, all_customers.size())
            
            for i in range(num_customers):
                if all_customers.size() == 0:
                    break
                var random_index = randi() % all_customers.size()
                affected_ids.append(all_customers[random_index])
                all_customers.remove(random_index)
        
        "criminal":
            # Affect active shipments or lanes
            if map_manager.active_shipments.size() > 0:
                # Affect a random active shipment
                var all_shipments = map_manager.active_shipments.keys()
                var random_index = randi() % all_shipments.size()
                affected_ids.append(all_shipments[random_index])
            else:
                # Affect a random lane
                var all_lanes = map_manager.lanes.keys()
                if all_lanes.size() > 0:
                    var random_index = randi() % all_lanes.size()
                    affected_ids.append(all_lanes[random_index])
    
    return affected_ids

func _generate_event_duration(template: Dictionary) -> float:
    # Generate appropriate duration based on template
    var base_duration = template.base_duration
    var variation = base_duration * 0.3  # 30% variation
    
    return base_duration + randf_range(-variation, variation)

func _create_event_templates():
    # Economic events
    event_templates["econ_boom"] = {
        "id": "econ_boom",
        "type": "economic",
        "name": "Economic Boom",
        "description": "A sudden surge in economic activity has increased demand for goods.",
        "base_duration": 600.0,  # 10 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["adjust_pricing", "invest"],
        "response_descriptions": {
            "adjust_pricing": "Adjust your pricing to capitalize on increased demand",
            "invest": "Invest in expanded capacity to meet growing demand"
        }
    }
    
    event_templates["econ_recession"] = {
        "id": "econ_recession",
        "type": "economic",
        "name": "Economic Recession",
        "description": "An economic downturn has reduced demand for non-essential goods.",
        "base_duration": 900.0,  # 15 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["reduce_costs", "diversify"],
        "response_descriptions": {
            "reduce_costs": "Cut operational costs to weather the recession",
            "diversify": "Diversify into countercyclical goods"
        }
    }
    
    # Weather events
    event_templates["weather_storm"] = {
        "id": "weather_storm",
        "type": "weather",
        "name": "Severe Storm",
        "description": "A severe storm is causing dangerous driving conditions on multiple routes.",
        "base_duration": 300.0,  # 5 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["reroute", "delay_shipments"],
        "response_descriptions": {
            "reroute": "Reroute shipments around the storm",
            "delay_shipments": "Delay shipments until the storm passes"
        }
    }
    
    # Carrier events
    event_templates["carrier_strike"] = {
        "id": "carrier_strike",
        "type": "carrier",
        "name": "Driver Strike",
        "description": "Drivers for certain carriers have gone on strike, disrupting deliveries.",
        "base_duration": 450.0,  # 7.5 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["find_alternative", "negotiate"],
        "response_descriptions": {
            "find_alternative": "Find alternative carriers",
            "negotiate": "Negotiate with striking drivers"
        }
    }
    
    # Regulatory events
    event_templates["reg_new_tax"] = {
        "id": "reg_new_tax",
        "type": "regulatory",
        "name": "New Transport Tax",
        "description": "Government has introduced a new tax on certain cargo types.",
        "base_duration": 1200.0,  # 20 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["comply", "appeal"],
        "response_descriptions": {
            "comply": "Comply with the new tax regulations",
            "appeal": "Appeal the tax through legal channels"
        }
    }
    
    # Customer events
    event_templates["cust_demand_spike"] = {
        "id": "cust_demand_spike",
        "type": "customer",
        "name": "Urgent Customer Demand",
        "description": "A customer has an urgent need for expedited delivery.",
        "base_duration": 180.0,  # 3 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["satisfy_demands", "negotiate"],
        "response_descriptions": {
            "satisfy_demands": "Meet the customer's demands at any cost",
            "negotiate": "Negotiate more reasonable terms"
        }
    }
    
    # Criminal events
    event_templates["crim_theft_risk"] = {
        "id": "crim_theft_risk",
        "type": "criminal",
        "name": "Cargo Theft Risk",
        "description": "Reports indicate increased risk of cargo theft in certain areas.",
        "base_duration": 360.0,  # 6 minutes of game time
        "is_notification_only": false,
        "possible_responses": ["security_measures", "report_authorities"],
        "response_descriptions": {
            "security_measures": "Invest in additional security measures",
            "report_authorities": "Report threats to authorities"
        }
    }

# Update function
func update(delta: float, game_time: float):
    # Update timers
    event_check_timer += delta
    
    # Check for event expiration
    var events_to_expire = []
    for event_id in active_events.keys():
        var event = active_events[event_id]
        
        if !event.is_active:
            continue
        
        if game_time >= event.end_time:
            events_to_expire.append(event_id)
    
    # Process expirations
    for event_id in events_to_expire:
        expire_event(event_id)
    
    # Check for random events
    if event_check_timer >= event_check_interval:
        event_check_timer = 0.0
        check_for_random_events(delta)

func check_for_random_events(delta: float):
    var game_time = get_node("/root/GameManager").current_game_time
    
    # Check if it's time for a random event
    if game_time >= next_random_event_time:
        # Generate a random event
        generate_random_event(game_time)
        
        # Schedule the next event
        _schedule_next_random_event(game_time)
