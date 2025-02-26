# ui_manager.gd
class_name UIManager
extends Control

# UI Components - Main panels
var hud: Panel
var lane_management_panel: Panel
var carrier_offers_panel: Panel
var customer_contracts_panel: Panel
var dialogue_panel: Panel
var event_notification_area: Panel
var market_dashboard: Panel
var negotiation_window: Panel
var settings_menu: Panel

# References to other systems
var game_manager: GameManager
var player_manager: PlayerManager
var carrier_manager: CarrierManager
var customer_manager: CustomerManager
var map_manager: MapManager
var event_manager: EventManager
var economy_manager: EconomyEmulator

# UI State
var current_active_panel: String = ""
var notification_queue: Array = []
var selected_lane_id: String = ""
var selected_carrier_id: String = ""
var selected_contract_id: String = ""
var selected_customer_id: String = ""
var is_negotiating: bool = false
var menu_visible: bool = false

# UI Animation
var notification_anim_player: AnimationPlayer
var panel_anim_player: AnimationPlayer

# Signals
signal panel_opened(panel_name)
signal panel_closed(panel_name)
signal notification_shown(notification_id, notification_type)
signal notification_cleared(notification_id)
signal ui_action_performed(action_type, action_data)

func _ready():
    # Get references to other systems
    game_manager = get_node("/root/GameManager")
    player_manager = get_node("/root/GameManager/PlayerManager")
    carrier_manager = get_node("/root/GameManager/CarrierManager")
    customer_manager = get_node("/root/GameManager/CustomerManager")
    map_manager = get_node("/root/GameManager/MapManager")
    event_manager = get_node("/root/GameManager/EventManager")
    economy_manager = get_node("/root/GameManager/EconomyEmulator")
    
    # Setup UI components
    _setup_ui_components()
    
    # Connect signals from other systems
    _connect_signals()

# UI Component Setup
func _setup_ui_components():
    # Create main UI panels
    _setup_hud()
    _setup_lane_management_panel()
    _setup_carrier_offers_panel()
    _setup_customer_contracts_panel()
    _setup_dialogue_panel()
    _setup_event_notification_area()
    _setup_market_dashboard()
    _setup_negotiation_window()
    _setup_settings_menu()
    
    # Create animation players
    notification_anim_player = AnimationPlayer.new()
    add_child(notification_anim_player)
    _setup_notification_animations()
    
    panel_anim_player = AnimationPlayer.new()
    add_child(panel_anim_player)
    _setup_panel_animations()

func _setup_hud():
    hud = Panel.new()
    hud.name = "HUD"
    hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
    hud.custom_minimum_size = Vector2(0, 60)
    add_child(hud)
    
    # Add HUD elements like balance, reputation, date/time, etc.
    var balance_label = Label.new()
    balance_label.name = "BalanceLabel"
    balance_label.text = "Balance: $10,000"
    balance_label.position = Vector2(20, 20)
    hud.add_child(balance_label)
    
    var reputation_label = Label.new()
    reputation_label.name = "ReputationLabel"
    reputation_label.text = "Reputation: 50/100"
    reputation_label.position = Vector2(200, 20)
    hud.add_child(reputation_label)
    
    var time_label = Label.new()
    time_label.name = "TimeLabel"
    time_label.text = "Day 1 - 08:00"
    time_label.position = Vector2(400, 20)
    hud.add_child(time_label)
    
    # Add buttons for opening main panels
    var lane_button = Button.new()
    lane_button.name = "LaneButton"
    lane_button.text = "Lanes"
    lane_button.position = Vector2(600, 15)
    lane_button.connect("pressed", self, "_on_lane_button_pressed")
    hud.add_child(lane_button)
    
    var carrier_button = Button.new()
    carrier_button.name = "CarrierButton"
    carrier_button.text = "Carriers"
    carrier_button.position = Vector2(680, 15)
    carrier_button.connect("pressed", self, "_on_carrier_button_pressed")
    hud.add_child(carrier_button)
    
    var customer_button = Button.new()
    customer_button.name = "CustomerButton"
    customer_button.text = "Customers"
    customer_button.position = Vector2(760, 15)
    customer_button.connect("pressed", self, "_on_customer_button_pressed")
    hud.add_child(customer_button)
    
    var market_button = Button.new()
    market_button.name = "MarketButton"
    market_button.text = "Market"
    market_button.position = Vector2(840, 15)
    market_button.connect("pressed", self, "_on_market_button_pressed")
    hud.add_child(market_button)
    
    var settings_button = Button.new()
    settings_button.name = "SettingsButton"
    settings_button.text = "Settings"
    settings_button.position = Vector2(920, 15)
    settings_button.connect("pressed", self, "_on_settings_button_pressed")
    hud.add_child(settings_button)

# Similar setup functions for other UI panels follow...
# Each would create appropriate controls for that panel's functionality

# Panel visibility management
func show_panel(panel_name: String):
    # Hide current panel if any
    if current_active_panel != "":
        hide_panel(current_active_panel)
    
    # Show requested panel
    var panel = _get_panel_by_name(panel_name)
    if panel != null:
        panel.visible = true
        current_active_panel = panel_name
        panel_anim_player.play("show_" + panel_name)
        emit_signal("panel_opened", panel_name)

func hide_panel(panel_name: String):
    var panel = _get_panel_by_name(panel_name)
    if panel != null:
        panel.visible = false
        if current_active_panel == panel_name:
            current_active_panel = ""
        emit_signal("panel_closed", panel_name)

func _get_panel_by_name(panel_name: String) -> Control:
    match panel_name:
        "lane_management":
            return lane_management_panel
        "carrier_offers":
            return carrier_offers_panel
        "customer_contracts":
            return customer_contracts_panel
        "dialogue":
            return dialogue_panel
        "market_dashboard":
            return market_dashboard
        "negotiation":
            return negotiation_window
        "settings":
            return settings_menu
        _:
            return null

# Notification system
func show_notification(title: String, message: String, notification_type: String = "info", duration: float = 5.0):
    var notification_id = "N" + str(Time.get_unix_time_from_system()).md5_text().substr(0, 8)
    
    # Add to queue
    notification_queue.append({
        "id": notification_id,
        "title": title,
        "message": message,
        "type": notification_type,
        "duration": duration
    })
    
    # Process queue
    _process_notification_queue()
    
    return notification_id

func _process_notification_queue():
    # Check if we can show a notification
    if notification_queue.size() > 0 && !notification_anim_player.is_playing():
        var notification = notification_queue.pop_front()
        _display_notification(notification)

func _display_notification(notification: Dictionary):
    # Create notification UI
    var notification_panel = PanelContainer.new()
    notification_panel.name = "Notification_" + notification.id
    notification_panel.size = Vector2(300, 100)
    notification_panel.position = Vector2(get_viewport_rect().size.x - 320, 70)
    
    var vbox = VBoxContainer.new()
    notification_panel.add_child(vbox)
    
    var title_label = Label.new()
    title_label.text = notification.title
    title_label.add_theme_font_size_override("font_size", 16)
    vbox.add_child(title_label)
    
    var message_label = Label.new()
    message_label.text = notification.message
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(message_label)
    
    # Add color based on type
    var style_box = notification_panel.get_theme_stylebox("panel")
    match notification.type:
        "info":
            style_box.bg_color = Color(0.2, 0.6, 0.9, 0.9)  # Blue
        "warning":
            style_box.bg_color = Color(0.9, 0.6, 0.2, 0.9)  # Orange
        "error":
            style_box.bg_color = Color(0.9, 0.2, 0.2, 0.9)  # Red
        "success":
            style_box.bg_color = Color(0.2, 0.8, 0.2, 0.9)  # Green
    
    add_child(notification_panel)
    
    # Play show animation
    notification_anim_player.get_animation("show_notification").track_set_path(0, notification_panel.get_path() + ":position")
    notification_anim_player.play("show_notification")
    
    # Schedule hide after duration
    await get_tree().create_timer(notification.duration).timeout
    
    # Play hide animation
    notification_anim_player.get_animation("hide_notification").track_set_path(0, notification_panel.get_path() + ":position")
    notification_anim_player.play("hide_notification")
    
    # Remove notification after animation
    await notification_anim_player.animation_finished
    notification_panel.queue_free()
    
    # Process next notification if any
    _process_notification_queue()
    
    emit_signal("notification_cleared", notification.id)

# Dialogue system
func show_dialogue(speaker_name: String, dialogue_text: String, options: Array = []):
    # Show dialogue panel with text and response options
    show_panel("dialogue")
    
    # Set dialogue content
    var speaker_label = dialogue_panel.get_node("SpeakerLabel")
    speaker_label.text = speaker_name
    
    var text_label = dialogue_panel.get_node("DialogueText")
    text_label.text = dialogue_text
    
    var options_container = dialogue_panel.get_node("OptionsContainer")
    
    # Clear existing options
    for child in options_container.get_children():
        child.queue_free()
    
    # Add new options
    for option in options:
        var option_button = Button.new()
        option_button.text = option.text
        option_button.connect("pressed", self, "_on_dialogue_option_selected", [option.id])
        options_container.add_child(option_button)

# Contract display
func show_contract_details(contract_id: String):
    if customer_manager.pending_contracts.has(contract_id):
        var contract = customer_manager.pending_contracts[contract_id]
        _display_contract(contract)
    elif customer_manager.customer_contracts.has(contract_id):
        var contract = customer_manager.customer_contracts[contract_id]
        _display_contract(contract)

func _display_contract(contract: Dictionary):
    show_panel("customer_contracts")
    
    # Populate contract details UI
    var contract_title = customer_contracts_panel.get_node("ContractTitle")
    contract_title.text = "Contract #" + contract.id
    
    var customer_name = ""
    if customer_manager.customers.has(contract.customer_id):
        customer_name = customer_manager.customers[contract.customer_id].name
    
    var details_label = customer_contracts_panel.get_node("DetailsLabel")
    details_label.text = "Customer: " + customer_name + "\n" + \
                      "Cargo: " + contract.cargo_type + "\n" + \
                      "Amount: " + str(contract.cargo_amount) + "\n" + \
                      "Value: $" + str(contract.value) + "\n" + \
                      "Deadline: " + _format_time(contract.deadline)
    
    var status_label = customer_contracts_panel.get_node("StatusLabel")
    status_label.text = "Status: " + contract.status.capitalize()
    
    var action_button = customer_contracts_panel.get_node("ActionButton")
    
    if contract.status == "pending":
        action_button.text = "Accept Contract"
        action_button.connect("pressed", self, "_on_accept_contract_pressed", [contract.id])
        action_button.visible = true
    elif contract.status == "active" && !contract.carrier_assigned:
        action_button.text = "Assign Carrier"
        action_button.connect("pressed", self, "_on_assign_carrier_pressed", [contract.id])
        action_button.visible = true
    else:
        action_button.visible = false

# Carrier offer display
func show_carrier_offer(carrier_id: String, lane_id: String, price: float, estimated_time: float):
    show_panel("carrier_offers")
    
    # Populate carrier offer UI
    var carrier_name = carrier_manager.get_carrier_name(carrier_id)
    
    var offer_title = carrier_offers_panel.get_node("OfferTitle")
    offer_title.text = "Offer from " + carrier_name
    
    var details_label = carrier_offers_panel.get_node("DetailsLabel")
    details_label.text = "Lane: " + lane_id + "\n" + \
                      "Price: $" + str(price) + "\n" + \
                      "Estimated Delivery Time: " + _format_time_duration(estimated_time)
    
    var accept_button = carrier_offers_panel.get_node("AcceptButton")
    accept_button.connect("pressed", self, "_on_accept_carrier_offer_pressed", [carrier_id, lane_id, price])
    
    var negotiate_button = carrier_offers_panel.get_node("NegotiateButton")
    negotiate_button.connect("pressed", self, "_on_negotiate_carrier_offer_pressed", [carrier_id, lane_id, price])
    
    var reject_button = carrier_offers_panel.get_node("RejectButton")
    reject_button.connect("pressed", self, "_on_reject_carrier_offer_pressed", [carrier_id, lane_id])

# Event notification display
func show_event_notification(event_id: String, event_type: String, event_name: String, event_description: String, response_options: Array = []):
    # Show notification of the event
    var notification_type = "info"
    
    match event_type:
        "economic":
            notification_type = "info"
        "weather":
            notification_type = "warning"
        "carrier":
            notification_type = "warning"
        "regulatory":
            notification_type = "info"
        "customer":
            notification_type = "info"
        "criminal":
            notification_type = "error"
    
    show_notification(event_name, event_description, notification_type, 10.0)
    
    # If there are response options, open dialogue
    if response_options.size() > 0:
        var dialogue_options = []
        for option in response_options:
            dialogue_options.append({
                "id": option.id,
                "text": option.text
            })
        
        show_dialogue("Event: " + event_name, event_description, dialogue_options)

# Utility functions
func _format_time(game_time: float) -> String:
    # Convert game time to hours:minutes format
    var day = int(game_time / (24 * 60 * 60)) + 1
    var hours = int(fmod(game_time, 24 * 60 * 60) / (60 * 60))
    var minutes = int(fmod(game_time, 60 * 60) / 60)
    
    return "Day " + str(day) + " - " + str(hours).pad_zeros(2) + ":" + str(minutes).pad_zeros(2)

func _format_time_duration(duration: float) -> String:
    # Convert duration to hours:minutes format
    var hours = int(duration / (60 * 60))
    var minutes = int(fmod(duration, 60 * 60) / 60)
    
    if hours > 0:
        return str(hours) + "h " + str(minutes) + "m"
    else:
        return str(minutes) + "m"

# Signal handlers from other systems
func _on_player_balance_changed(new_balance):
    var balance_label = hud.get_node("BalanceLabel")
    balance_label.text = "Balance: $" + str(int(new_balance))

func _on_player_reputation_changed(new_reputation):
    var reputation_label = hud.get_node("ReputationLabel")
    reputation_label.text = "Reputation: " + str(int(new_reputation)) + "/100"

func _on_carrier_offer_made(carrier_id, lane_id, price, estimated_time):
    # Show notification of new carrier offer
    var carrier_name = carrier_manager.get_carrier_name(carrier_id)
    show_notification("New Carrier Offer", carrier_name + " has made an offer for lane " + lane_id, "info")
    
    # Optionally auto-show the offer details
    if current_active_panel == "":
        show_carrier_offer(carrier_id, lane_id, price, estimated_time)

func _on_customer_contract_offered(contract_id, customer_id, cargo_type, value):
    # Show notification of new customer contract
    var customer_name = ""
    if customer_manager.customers.has(customer_id):
        customer_name = customer_manager.customers[customer_id].name
    
    show_notification("New Contract Offer", customer_name + " has offered a contract for " + cargo_type, "info")
    
    # Optionally auto-show the contract details
    if current_active_panel == "":
        show_contract_details(contract_id)

func _on_event_triggered(event_id, event_type, affected_ids):
    # Get event details from event manager
    var event = event_manager.active_events[event_id]
    
    # Show notification
    show_event_notification(event_id, event_type, event.name, event.description, _get_event_response_options(event))

func _get_event_response_options(event: Dictionary) -> Array:
    var options = []
    
    if event.has("possible_responses") && event.has("response_descriptions"):
        for response in event.possible_responses:
            options.append({
                "id": response,
                "text": event.response_descriptions[response]
            })
    
    return options

func _on_lane_selected(lane_id):
    selected_lane_id = lane_id
    
    # Update lane management panel with selected lane details
    if current_active_panel == "lane_management":
        _update_lane_management_panel()

# Button event handlers
func _on_lane_button_pressed():
    show_panel("lane_management")

func _on_carrier_button_pressed():
    show_panel("carrier_offers")

func _on_customer_button_pressed():
    show_panel("customer_contracts")

func _on_market_button_pressed():
    show_panel("market_dashboard")

func _on_settings_button_pressed():
    show_panel("settings")

func _on_accept_contract_pressed(contract_id):
    if player_manager.accept_contract(customer_manager.pending_contracts[contract_id]):
        customer_manager.accept_customer_contract(contract_id)
        show_notification("Contract Accepted", "You have accepted the contract.", "success")
        hide_panel("customer_contracts")
    else:
        show_notification("Cannot Accept Contract", "Insufficient funds or other issues.", "error")

func _on_assign_carrier_pressed(contract_id):
    selected_contract_id = contract_id
    show_panel("carrier_offers")
    # This would then populate available carriers for this contract

func _on_accept_carrier_offer_pressed(carrier_id, lane_id, price):
    var contract_id = carrier_manager.accept_carrier_offer({
        "carrier_id": carrier_id,
        "lane_id": lane_id,
        "price": price
    }, game_manager.current_game_time)
    
    if contract_id != "":
        show_notification("Carrier Accepted", "The carrier has been assigned to the route.", "success")
        hide_panel("carrier_offers")
    else:
        show_notification("Cannot Assign Carrier", "There was an issue assigning this carrier.", "error")

func _on_negotiate_carrier_offer_pressed(carrier_id, lane_id, price):
    is_negotiating = true
    show_panel("negotiation")
    
    # Setup negotiation UI
    var carrier_name = carrier_manager.get_carrier_name(carrier_id)
    var negotiation_title = negotiation_window.get_node("NegotiationTitle")
    negotiation_title.text = "Negotiate with " + carrier_name
    
    var offer_label = negotiation_window.get_node("OriginalOfferLabel")
    offer_label.text = "Original Offer: $" + str(price)
    
    var slider = negotiation_window.get_node("CounterOfferSlider")
    slider.min_value = price * 0.6  # 40% discount
    slider.max_value = price * 1.1  // 10% markup
    slider.value = price * 0.9  // Start at 10% discount
    
    var counter_label = negotiation_window.get_node("CounterOfferLabel")
    counter_label.text = "Counter Offer: $" + str(slider.value)
    
    slider.connect("value_changed", self, "_on_counter_offer_slider_changed")
    
    var submit_button = negotiation_window.get_node("SubmitButton")
    submit_button.connect("pressed", self, "_on_submit_counter_offer_pressed", [carrier_id, lane_id, price])
    
    var cancel_button = negotiation_window.get_node("CancelButton")
    cancel_button.connect("pressed", self, "_on_cancel_negotiation_pressed")

func _on_counter_offer_slider_changed(value):
    var counter_label = negotiation_window.get_node("CounterOfferLabel")
    counter_label.text = "Counter Offer: $" + str(value)

func _on_submit_counter_offer_pressed(carrier_id, lane_id, original_price):
    var slider = negotiation_window.get_node("CounterOfferSlider")
    var counter_price = slider.value
    
    var counter_result = carrier_manager.negotiate_carrier_offer({
        "carrier_id": carrier_id,
        "lane_id": lane_id,
        "price": original_price
    }, counter_price)
    
    is_negotiating = false
    
    if counter_result.size() > 0:
        if counter_result.price == counter_price:
            show_notification("Negotiation Successful", "The carrier accepted your offer!", "success")
            
            // Auto-accept the new offer
            _on_accept_carrier_offer_pressed(carrier_id, lane_id, counter_price)
        else:
            show_notification("Counteroffer Received", "The carrier made a counteroffer of $" + str(counter_result.price), "info")
            
            // Show new offer details
            show_carrier_offer(carrier_id, lane_id, counter_result.price, counter_result.estimated_time)
    else:
        show_notification("Negotiation Failed", "The carrier rejected your offer.", "warning")
        hide_panel("negotiation")

func _on_cancel_negotiation_pressed():
    is_negotiating = false
    hide_panel("negotiation")

func _on_reject_carrier_offer_pressed(carrier_id, lane_id):
    carrier_manager.reject_carrier_offer({
        "carrier_id": carrier_id,
        "lane_id": lane_id
    })
    
    show_notification("Offer Rejected", "You have rejected the carrier's offer.", "info")
    hide_panel("carrier_offers")

func _on_dialogue_option_selected(option_id):
    if is_negotiating:
        // Handle negotiation dialogue options
        pass
    else:
        // Handle general dialogue options, like event responses
        var event_id = dialogue_panel.get_meta("event_id") if dialogue_panel.has_meta("event_id") else ""
        
        if event_id != "" && event_manager.active_events.has(event_id):
            event_manager.resolve_event(event_id, option_id)
            hide_panel("dialogue")
            
            show_notification("Response Submitted", "Your response to the event has been submitted.", "info")
