# map_manager.gd
class_name MapManager
extends Node2D

# Map data
var cities: Dictionary = {}
var lanes: Dictionary = {}
var active_shipments: Dictionary = {}

# Map visualization settings
var lane_width: float = 5.0
var city_radius: float = 15.0
var mini_map_scale: float = 0.25

# Selection and interaction
var selected_city_id: String = ""
var selected_lane_id: String = ""
var hovering_city_id: String = ""
var hovering_lane_id: String = ""

# Lane status colors
var lane_colors = {
    "default": Color(0.7, 0.7, 0.7),  # Gray for inactive lanes
    "active": Color(0.2, 0.8, 0.2),   # Green for active, normal lanes
    "congested": Color(0.8, 0.8, 0.2), # Yellow for congested lanes
    "high_risk": Color(0.8, 0.4, 0.2), # Orange for high-risk lanes
    "blocked": Color(0.8, 0.2, 0.2),   # Red for blocked lanes
    "selected": Color(0.2, 0.6, 0.9),  # Blue for selected lanes
    "hovering": Color(0.4, 0.8, 1.0)   # Light blue for hovering lanes
}

# References to other systems
var economy_manager: EconomyEmulator
var carrier_manager: CarrierManager
var event_manager: EventManager

# Signals
signal city_selected(city_id)
signal lane_selected(lane_id)
signal lane_status_changed(lane_id, new_status)
signal carrier_assigned(lane_id, carrier_id)
signal shipment_started(shipment_id, lane_id, carrier_id)
signal shipment_completed(shipment_id, on_time)
signal shipment_failed(shipment_id, reason)

func _ready():
    # Get references to other managers
    economy_manager = get_node("/root/GameManager/EconomyEmulator")
    carrier_manager = get_node("/root/GameManager/CarrierManager")
    event_manager = get_node("/root/GameManager/EventManager")
    
    # Connect signals
    event_manager.connect("event_triggered", _on_event_triggered)

# City management
func add_city(city_id: String, position: Vector2, city_name: String):
    if cities.has(city_id):
        print_debug("Warning: City ID already exists: ", city_id)
        return
    
    var city = {
        "id": city_id,
        "name": city_name,
        "position": position,
        "size": 1.0,  # City size/importance factor
        "infrastructure": 1.0,  # Infrastructure quality (0-2)
        "traffic_congestion": 0.0,  # Current congestion level (0-1)
        "connected_lanes": [],  # Lane IDs connected to this city
        "risk_level": 0.0,  # Risk of problems in this city (0-1)
        "industry_focus": "",  # Main industry in this city
        "active_events": []  # Current events affecting the city
    }
    
    cities[city_id] = city
    update()

func remove_city(city_id: String):
    if !cities.has(city_id):
        return
    
    # Remove all lanes connected to this city
    var lanes_to_remove = []
    for lane_id in lanes.keys():
        var lane = lanes[lane_id]
        if lane.start_city == city_id || lane.end_city == city_id:
            lanes_to_remove.append(lane_id)
    
    for lane_id in lanes_to_remove:
        remove_lane(lane_id)
    
    cities.erase(city_id)
    update()

# Lane management
func add_lane(lane_id: String, start_city: String, end_city: String, distance: float):
    if lanes.has(lane_id):
        print_debug("Warning: Lane ID already exists: ", lane_id)
        return
    
    if !cities.has(start_city) || !cities.has(end_city):
        print_debug("Warning: Start or end city does not exist")
        return
    
    var lane = {
        "id": lane_id,
        "name": start_city + " to " + end_city,
        "start_city": start_city,
        "end_city": end_city,
        "distance": distance,
        "travel_time": distance / 100.0,  # Base travel time
        "traffic_level": 0.0,  # Current traffic congestion (0-1)
        "risk_factor": 0.0,  # Risk of problems on this lane (0-1)
        "status": "default",  # Current lane status
        "allowed_cargo_types": [],  # Restricted cargo types, empty means all allowed
        "active_shipments": [],  # Shipments currently on this lane
        "active_carriers": [],  # Carriers currently using this lane
        "active_events": [],  # Events currently affecting this lane
        "owner": "",  # Player or competitor who owns this lane
        "maintenance_cost": distance * 0.1,  # Regular upkeep cost
        "upgrade_level": 0  # Lane improvement level
    }
    
    lanes[lane_id] = lane
    
    # Add lane to connected cities
    cities[start_city].connected_lanes.append(lane_id)
    cities[end_city].connected_lanes.append(lane_id)
    
    update()

func remove_lane(lane_id: String):
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    
    # Remove lane from connected cities
    if cities.has(lane.start_city):
        cities[lane.start_city].connected_lanes.erase(lane_id)
    
    if cities.has(lane.end_city):
        cities[lane.end_city].connected_lanes.erase(lane_id)
    
    lanes.erase(lane_id)
    update()

# Lane status management
func set_lane_status(lane_id: String, status: String):
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    var old_status = lane.status
    lane.status = status
    
    emit_signal("lane_status_changed", lane_id, status)
    update()

# Shipment and carrier management
func start_shipment(shipment_id: String, lane_id: String, carrier_id: String, cargo_type: String, 
                  cargo_amount: float, start_time: float, estimated_arrival: float):
    if !lanes.has(lane_id):
        print_debug("Warning: Lane does not exist: ", lane_id)
        return
    
    var lane = lanes[lane_id]
    
    var shipment = {
        "id": shipment_id,
        "lane_id": lane_id,
        "carrier_id": carrier_id,
        "cargo_type": cargo_type,
        "cargo_amount": cargo_amount,
        "start_time": start_time,
        "estimated_arrival": estimated_arrival,
        "actual_arrival": 0.0,
        "status": "in_transit",
        "position": 0.0,  # 0.0 to 1.0 along the lane
        "delay_factor": 0.0  # Additional delay due to events
    }
    
    active_shipments[shipment_id] = shipment
    lane.active_shipments.append(shipment_id)
    
    if !lane.active_carriers.has(carrier_id):
        lane.active_carriers.append(carrier_id)
    
    # Increase lane traffic based on cargo amount
    lane.traffic_level = min(1.0, lane.traffic_level + (cargo_amount / 1000.0))
    
    # Update lane status based on traffic
    _update_lane_status(lane_id)
    
    emit_signal("shipment_started", shipment_id, lane_id, carrier_id)
    update()

func complete_shipment(shipment_id: String, arrival_time: float, success: bool):
    if !active_shipments.has(shipment_id):
        return
    
    var shipment = active_shipments[shipment_id]
    var lane_id = shipment.lane_id
    
    if !lanes.has(lane_id):
        active_shipments.erase(shipment_id)
        return
    
    var lane = lanes[lane_id]
    
    # Process shipment completion
    shipment.status = "completed" if success else "failed"
    shipment.actual_arrival = arrival_time
    
    # Remove shipment from active lists
    lane.active_shipments.erase(shipment_id)
    
    # Check if carrier has other active shipments on this lane
    var carrier_still_active = false
    for s_id in lane.active_shipments:
        var s = active_shipments[s_id]
        if s.carrier_id == shipment.carrier_id:
            carrier_still_active = true
            break
    
    if !carrier_still_active:
        lane.active_carriers.erase(shipment.carrier_id)
    
    # Reduce lane traffic
    lane.traffic_level = max(0.0, lane.traffic_level - (shipment.cargo_amount / 1000.0))
    
    # Update lane status based on traffic
    _update_lane_status(lane_id)
    
    # Emit appropriate signal
    if success:
        var on_time = arrival_time <= shipment.estimated_arrival
        emit_signal("shipment_completed", shipment_id, on_time)
    else:
        emit_signal("shipment_failed", shipment_id, "carrier_failure")
    
    active_shipments.erase(shipment_id)
    update()

# Lane upgrades and modifications
func upgrade_lane(lane_id: String, upgrade_level: int):
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    lane.upgrade_level = upgrade_level
    
    # Apply upgrade effects
    match upgrade_level:
        1:  # Basic upgrades
            lane.travel_time *= 0.9  # 10% faster travel
            lane.risk_factor *= 0.9  # 10% lower risk
        2:  # Advanced upgrades
            lane.travel_time *= 0.8  # 20% faster travel
            lane.risk_factor *= 0.8  # 20% lower risk
        3:  # Premium upgrades
            lane.travel_time *= 0.7  # 30% faster travel
            lane.risk_factor *= 0.7  # 30% lower risk
    
    update()

func set_lane_restriction(lane_id: String, cargo_type: String, is_restricted: bool):
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    
    if is_restricted:
        if !lane.allowed_cargo_types.has(cargo_type):
            lane.allowed_cargo_types.append(cargo_type)
    else:
        lane.allowed_cargo_types.erase(cargo_type)

# Lane metrics and information
func get_lane_travel_time(lane_id: String) -> float:
    if !lanes.has(lane_id):
        return 0.0
    
    var lane = lanes[lane_id]
    var base_time = lane.travel_time
    
    # Adjust for traffic congestion
    var congestion_factor = 1.0 + lane.traffic_level
    
    # Adjust for events and conditions
    var event_factor = 1.0
    for event_id in lane.active_events:
        # This would normally check event specifics
        event_factor *= 1.2  # Generic 20% slowdown per event
    
    return base_time * congestion_factor * event_factor

func get_lane_risk(lane_id: String) -> float:
    if !lanes.has(lane_id):
        return 0.0
    
    var lane = lanes[lane_id]
    var base_risk = lane.risk_factor
    
    # Calculate risk factors from cities
    var start_city_risk = cities[lane.start_city].risk_level
    var end_city_risk = cities[lane.end_city].risk_level
    var city_risk = (start_city_risk + end_city_risk) / 2.0
    
    # Factor in active events
    var event_risk = 0.0
    for event_id in lane.active_events:
        # This would normally check event specifics
        event_risk += 0.1  # Generic 10% risk increase per event
    
    return base_risk + city_risk + event_risk

func get_lane_cost_factor(lane_id: String) -> float:
    if !lanes.has(lane_id):
        return 1.0
    
    var lane = lanes[lane_id]
    var base_factor = lane.distance / 100.0
    
    # Adjust for traffic
    var traffic_factor = 1.0 + (lane.traffic_level * 0.5)  # Up to 50% increase
    
    # Adjust for risks
    var risk_factor = 1.0 + get_lane_risk(lane_id)
    
    return base_factor * traffic_factor * risk_factor

# Drawing and visualization
func _draw():
    # Draw all lanes
    for lane_id in lanes:
        _draw_lane(lane_id)
    
    # Draw all cities
    for city_id in cities:
        _draw_city(city_id)
    
    # Draw active shipments
    for shipment_id in active_shipments:
        _draw_shipment(shipment_id)

func _draw_lane(lane_id: String):
    var lane = lanes[lane_id]
    var start_pos = cities[lane.start_city].position
    var end_pos = cities[lane.end_city].position
    
    # Select color based on lane status
    var color = lane_colors["default"]
    if lane.status in lane_colors:
        color = lane_colors[lane.status]
    
    # Special coloring for selected or hovered lanes
    if lane_id == selected_lane_id:
        color = lane_colors["selected"]
    elif lane_id == hovering_lane_id:
        color = lane_colors["hovering"]
    
    # Draw the lane with appropriate width
    var width = lane_width
    if lane.upgrade_level > 0:
        width += lane.upgrade_level * 2  # Thicker lines for upgraded lanes
    
    draw_line(start_pos, end_pos, color, width)
    
    # Draw lane name at midpoint
    var mid_point = (start_pos + end_pos) / 2
    var font = ThemeDB.fallback_font
    var font_size = ThemeDB.fallback_font_size
    var text_pos = mid_point - Vector2(font.get_string_size(lane.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2, 0)
    draw_string(font, text_pos, lane.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_city(city_id: String):
    var city = cities[city_id]
    var pos = city.position
    var radius = city_radius * (1.0 + city.size * 0.5)  # Size affects radius
    
    # Choose color based on selection state
    var color = Color(0.2, 0.6, 0.2)  # Default green
    var border_color = Color(0.1, 0.3, 0.1)
    
    if city_id == selected_city_id:
        color = Color(0.2, 0.6, 0.9)  # Blue for selected
        border_color = Color(0.1, 0.3, 0.5)
    elif city_id == hovering_city_id:
        color = Color(0.4, 0.8, 1.0)  # Light blue for hovering
        border_color = Color(0.2, 0.4, 0.6)
    
    # Draw city circle
    draw_circle(pos, radius, color)
    draw_arc(pos, radius, 0, TAU, 32, border_color, 2.0)
    
    # Draw city name
    var font = ThemeDB.fallback_font
    var font_size = ThemeDB.fallback_font_size
    var text_pos = pos + Vector2(0, radius + 5)
    var text_size = font.get_string_size(city.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, text_pos - Vector2(text_size.x / 2, 0), city.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_shipment(shipment_id: String):
    var shipment = active_shipments[shipment_id]
    var lane_id = shipment.lane_id
    
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    var start_pos = cities[lane.start_city].position
    var end_pos = cities[lane.end_city].position
    
    # Calculate position along the lane (0-1)
    var position = shipment.position
    var shipment_pos = start_pos.lerp(end_pos, position)
    
    # Draw shipment icon (small rectangle)
    var rect_size = Vector2(10, 10)
    draw_rect(Rect2(shipment_pos - rect_size/2, rect_size), Color(0.9, 0.6, 0.2))

# Input handling
func _input(event):
    if event is InputEventMouseMotion:
        _handle_mouse_motion(event.position)
    elif event is InputEventMouseButton && event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
        _handle_mouse_click(event.position)

func _handle_mouse_motion(position: Vector2):
    # Check if hovering over a city
    hovering_city_id = ""
    for city_id in cities:
        var city = cities[city_id]
        var distance = position.distance_to(city.position)
        if distance <= city_radius * (1.0 + city.size * 0.5):
            hovering_city_id = city_id
            break
    
    # Check if hovering over a lane
    hovering_lane_id = ""
    for lane_id in lanes:
        var lane = lanes[lane_id]
        var start_pos = cities[lane.start_city].position
        var end_pos = cities[lane.end_city].position
        
        # Check if point is near the line
        var nearest = Geometry2D.get_closest_point_to_segment(position, start_pos, end_pos)
        var distance = position.distance_to(nearest)
        
        if distance <= lane_width + 5:  # 5 pixel buffer
            hovering_lane_id = lane_id
            break
    
    update()

func _handle_mouse_click(position: Vector2):
    # Check for city selection
    for city_id in cities:
        var city = cities[city_id]
        var distance = position.distance_to(city.position)
        if distance <= city_radius * (1.0 + city.size * 0.5):
            select_city(city_id)
            return
    
    # Check for lane selection
    for lane_id in lanes:
        var lane = lanes[lane_id]
        var start_pos = cities[lane.start_city].position
        var end_pos = cities[lane.end_city].position
        
        # Check if point is near the line
        var nearest = Geometry2D.get_closest_point_to_segment(position, start_pos, end_pos)
        var distance = position.distance_to(nearest)
        
        if distance <= lane_width + 5:  # 5 pixel buffer
            select_lane(lane_id)
            return
    
    # Click in empty space deselects everything
    selected_city_id = ""
    selected_lane_id = ""
    emit_signal("city_selected", "")
    emit_signal("lane_selected", "")
    update()

func select_city(city_id: String):
    selected_city_id = city_id
    selected_lane_id = ""  # Deselect any lane
    emit_signal("city_selected", city_id)
    update()

func select_lane(lane_id: String):
    selected_lane_id = lane_id
    selected_city_id = ""  # Deselect any city
    emit_signal("lane_selected", lane_id)
    update()

# Update functions
func update_shipment_positions(delta: float, game_time: float):
    # Update all active shipment positions
    for shipment_id in active_shipments.keys():
        var shipment = active_shipments[shipment_id]
        
        if shipment.status != "in_transit":
            continue
        
        var lane_id = shipment.lane_id
        if !lanes.has(lane_id):
            active_shipments.erase(shipment_id)
            continue
        
        var lane = lanes[lane_id]
        
        # Calculate travel progress
        var total_time = shipment.estimated_arrival - shipment.start_time
        var elapsed_time = game_time - shipment.start_time
        var progress = elapsed_time / total_time
        
        # Apply progress to position (0-1 along the lane)
        shipment.position = clamp(progress, 0.0, 1.0)
        
        # Check if shipment has arrived
        if progress >= 1.0:
            complete_shipment(shipment_id, game_time, true)
    
    update()

func _update_lane_status(lane_id: String):
    if !lanes.has(lane_id):
        return
    
    var lane = lanes[lane_id]
    var status = "default"
    
    # Determine status based on traffic, events, and risks
    if lane.active_shipments.size() > 0:
        status = "active"
    
    if lane.traffic_level > 0.5:
        status = "congested"
    
    var risk = get_lane_risk(lane_id)
    if risk > 0.7:
        status = "high_risk"
    
    # Check for blocking events
    for event_id in lane.active_events:
        # This would check event specifics for blocking status
        # For now, just assume events don't block lanes
        pass
    
    set_lane_status(lane_id, status)

# Signal handlers
func _on_event_triggered(event_id, event_type, affected_ids):
    # Handle events that affect the map
    if event_type == "weather" || event_type == "disaster" || event_type == "political":
        # These events might affect lanes
        for lane_id in affected_ids:
            if lanes.has(lane_id):
                var lane = lanes[lane_id]
                if !lane.active_events.has(event_id):
                    lane.active_events.append(event_id)
                _update_lane_status(lane_id)
    
    if event_type == "city_event":
        # These events affect cities
        for city_id in affected_ids:
            if cities.has(city_id):
                var city = cities[city_id]
                if !city.active_events.has(event_id):
                    city.active_events.append(event_id)
                
                # Update all connected lanes
                for lane_id in city.connected_lanes:
                    _update_lane_status(lane_id)
