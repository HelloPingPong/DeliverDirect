extends AbstractManager
class_name UIManager

# UI-related signals
signal ui_game_paused
signal ui_game_resumed
signal ui_new_game_requested
signal ui_load_game_requested(slot_name)
signal ui_save_game_requested(slot_name)
signal ui_carrier_selected(carrier_id)
signal ui_lane_selected(lane_id)
signal ui_customer_selected(customer_id)
signal ui_contract_accepted(contract_id)
signal ui_contract_rejected(contract_id)
signal ui_negotiation_started(contract_id)
signal ui_negotiation_counteroffer(contract_id, offer_amount)

# References to major UI components
var hud: Control
var lane_management_panel: Control
var carrier_offers_panel: Control
var customer_interaction_panel: Control
var dialogue_panel: Control
var event_notification_area: Control
var market_overview_panel: Control
var negotiation_window: Control
var settings_menu: Control
var main_menu: Control
var game_over_screen: Control

# Current active panels and states
var current_screen: String = "main_menu"
var active_panels: Array = []
var notification_queue: Array = []

# Configuration
var notification_display_time: float = 5.0
var max_active_notifications: int = 5
var ui_animation_speed: float = 0.3

# Override _setup from base class
func _setup() -> void:
	debug_log("Setting up UI Manager")
	_initialize_ui_components()
	_setup_ui_themes()
	_connect_ui_signals()

# Initialize UI components
func _initialize_ui_components() -> void:
	# In a real implementation, these would be instances of actual scenes
	# For now, we're just establishing the structure
	hud = $HUD
	lane_management_panel = $Panels/LaneManagementPanel
	carrier_offers_panel = $Panels/CarrierOffersPanel
	customer_interaction_panel = $Panels/CustomerInteractionPanel
	dialogue_panel = $Panels/DialoguePanel
	event_notification_area = $NotificationArea
	market_overview_panel = $Panels/MarketOverviewPanel
	negotiation_window = $Panels/NegotiationWindow
	settings_menu = $Menus/SettingsMenu
	main_menu = $Menus/MainMenu
	game_over_screen = $Menus/GameOverScreen
	
	# Initially hide gameplay panels
	_hide_all_gameplay_panels()
	
	# Show main menu at start
	main_menu.visible = true

# Setup UI themes and styling
func _setup_ui_themes() -> void:
	# Load theme resources, set up colors, fonts, etc.
	pass

# Connect UI signals
func _connect_ui_signals() -> void:
	# Connect UI element signals to local handler methods
	
	# Example connections (these would be actual Control nodes in implementation)
	# main_menu.connect("new_game_pressed", Callable(self, "_on_new_game_pressed"))
	# main_menu.connect("load_game_pressed", Callable(self, "_on_load_game_pressed"))
	# hud.connect("pause_pressed", Callable(self, "_on_pause_pressed"))
	pass

# Switch to the main gameplay screen
func switch_to_gameplay_screen() -> void:
	debug_log("Switching to gameplay screen")
	
	# Hide non-gameplay elements
	main_menu.visible = false
	settings_menu.visible = false
	game_over_screen.visible = false
	
	# Show gameplay elements
	hud.visible = true
	
	# Update the current screen tracker
	current_screen = "gameplay"
	
	# Initial panel setup
	_show_panel(lane_management_panel)
	_show_panel(market_overview_panel)
	
	# Update all displays with current data
	update_all_displays()

# Switch to main menu
func switch_to_main_menu() -> void:
	debug_log("Switching to main menu")
	
	# Hide gameplay elements
	_hide_all_gameplay_panels()
	hud.visible = false
	
	# Show main menu
	main_menu.visible = true
	
	# Update the current screen tracker
	current_screen = "main_menu"

# Show game over screen
func show_game_over_screen(reason: String) -> void:
	debug_log("Game over: " + reason)
	
	# Hide gameplay elements
	_hide_all_gameplay_panels()
	
	# Setup and show game over screen
	# game_over_screen.setup(reason)
	game_over_screen.visible = true
	
	# Update the current screen tracker
	current_screen = "game_over"

# Hide all gameplay panels
func _hide_all_gameplay_panels() -> void:
	lane_management_panel.visible = false
	carrier_offers_panel.visible = false
	customer_interaction_panel.visible = false
	dialogue_panel.visible = false
	market_overview_panel.visible = false
	negotiation_window.visible = false
	
	active_panels.clear()

# Show a specific panel
func _show_panel(panel: Control) -> void:
	panel.visible = true
	
	if not active_panels.has(panel):
		active_panels.append(panel)
	
	# Arrange panels based on active configuration
	_arrange_active_panels()

# Hide a specific panel
func _hide_panel(panel: Control) -> void:
	panel.visible = false
	
	if active_panels.has(panel):
		active_panels.erase(panel)
	
	# Rearrange remaining panels
	_arrange_active_panels()

# Arrange active panels in the UI
func _arrange_active_panels() -> void:
	# Layout logic for positioning panels would go here
	# This would depend on the specific UI design
	pass

# Update all display elements with current data
func update_all_displays() -> void:
	update_hud_display()
	update_lane_display()
	update_carrier_display()
	update_customer_display()
	update_market_display()
	update_reputation_display()

# Update HUD elements
func update_hud_display() -> void:
	if hud == null or not hud.visible:
		return
	
	# Get data from appropriate managers
	var balance = game_manager.player_manager.get_balance()
	var reputation = game_manager.player_manager.get_reputation_score()
	var active_contracts = game_manager.player_manager.get_active_contracts_count()
	var current_day = game_manager.current_game_day
	
	# Update HUD elements
	# hud.update_balance(balance)
	# hud.update_reputation(reputation)
	# hud.update_active_contracts(active_contracts)
	# hud.update_day(current_day)
	
	debug_log("Updated HUD display")

# Update lane management display
func update_lane_display() -> void:
	if lane_management_panel == null or not lane_management_panel.visible:
		return
	
	# Get lane data from map manager
	var lanes = game_manager.map_manager.get_available_lanes()
	
	# Update lane management panel
	# lane_management_panel.update_lanes(lanes)
	
	debug_log("Updated lane display with " + str(lanes.size()) + " lanes")

# Update carrier display
func update_carrier_display() -> void:
	if carrier_offers_panel == null or not carrier_offers_panel.visible:
		return
	
	# Get carrier data
	var carriers = game_manager.carrier_manager.get_available_carriers()
	var carrier_offers = game_manager.carrier_manager.get_active_offers()
	
	# Update carrier panel
	# carrier_offers_panel.update_carriers(carriers)
	# carrier_offers_panel.update_offers(carrier_offers)
	
	debug_log("Updated carrier display")

# Update customer display
func update_customer_display() -> void:
	if customer_interaction_panel == null or not customer_interaction_panel.visible:
		return
	
	# Get customer data
	var customers = game_manager.customer_manager.get_active_customers()
	
	# Update customer panel
	# customer_interaction_panel.update_customers(customers)
	
	debug_log("Updated customer display")

# Update market display
func update_market_display() -> void:
	if market_overview_panel == null or not market_overview_panel.visible:
		return
	
	# Get market data
	var prices = game_manager.economy_manager.get_current_prices()
	var trends = game_manager.economy_manager.get_market_trends()
	
	# Update market panel
	# market_overview_panel.update_prices(prices)
	# market_overview_panel.update_trends(trends)
	
	debug_log("Updated market display")

# Update reputation display
func update_reputation_display() -> void:
	if hud == null or not hud.visible:
		return
	
	# Get reputation data
	var reputation = game_manager.player_manager.get_reputation_score()
	var rep_status = game_manager.negotiation_manager.get_reputation_status()
	
	# Update reputation on HUD
	# hud.update_reputation_details(reputation, rep_status)
	
	debug_log("Updated reputation display")

# Show notification to player
func show_notification(message: String, type: String = "info") -> void:
	debug_log("Notification: " + message + " (Type: " + type + ")")
	
	# Add to notification queue
	notification_queue.append({
		"message": message,
		"type": type,
		"time": notification_display_time
	})
	
	# Process notification queue
	_process_notification_queue()

# Show event notification
func show_event_notification(event_name: String, event_data: Dictionary) -> void:
	# Format the event notification based on event type
	var message = "Event: " + event_name
	var type = "event"
	
	# Handle specific event types with custom messages
	match event_name:
		"fuel_price_surge":
			message = "Fuel prices surge by " + str(event_data["multiplier"]) + "x!"
			type = "warning"
		"market_crash":
			message = "Market crash! Economic instability ahead."
			type = "danger"
		"carrier_strike":
			message = "Carrier strike affecting " + str(event_data["carriers"].size()) + " carriers!"
			type = "warning"
		"weather_disaster":
			message = "Weather emergency in " + str(event_data["affected_regions"].size()) + " regions!"
			type = "danger"
	
	# Show the notification
	show_notification(message, type)
	
	# Create and show detailed event panel with actions if needed
	# _show_event_details_panel(event_name, event_data)

# Process notification queue
func _process_notification_queue() -> void:
	# Check if we can display more notifications
	if event_notification_area == null:
		return
	
	# Process up to max_active_notifications
	var displayed_count = event_notification_area.get_child_count()
	
	while notification_queue.size() > 0 and displayed_count < max_active_notifications:
		var notification = notification_queue.pop_front()
		
		# Create notification element
		# var notification_element = NotificationElement.instance()
		# notification_element.setup(notification.message, notification.type, notification.time)
		# event_notification_area.add_child(notification_element)
		
		displayed_count += 1

# Open dialogue panel with specific dialogue
func open_dialogue(dialogue_id: String, speaker: String) -> void:
	debug_log("Opening dialogue: " + dialogue_id + " with " + speaker)
	
	# Show dialogue panel
	_show_panel(dialogue_panel)
	
	# Setup dialogue
	# dialogue_panel.start_dialogue(dialogue_id, speaker)

# Close dialogue panel
func close_dialogue() -> void:
	_hide_panel(dialogue_panel)

# Open negotiation window
func open_negotiation(contract_id: String) -> void:
	debug_log("Opening negotiation for contract: " + contract_id)
	
	# Get contract details
	var contract = game_manager.negotiation_manager.get_contract_details(contract_id)
	
	# Show negotiation window
	_show_panel(negotiation_window)
	
	# Setup negotiation window
	# negotiation_window.setup_negotiation(contract)
	
	# Emit signal that negotiation started
	emit_signal("ui_negotiation_started", contract_id)

# Close negotiation window
func close_negotiation() -> void:
	_hide_panel(negotiation_window)

# Event handlers for UI actions
func _on_new_game_pressed() -> void:
	emit_signal("ui_new_game_requested")

func _on_load_game_pressed(slot_name: String) -> void:
	emit_signal("ui_load_game_requested", slot_name)

func _on_save_game_pressed(slot_name: String) -> void:
	emit_signal("ui_save_game_requested", slot_name)

func _on_pause_pressed() -> void:
	emit_signal("ui_game_paused")

func _on_resume_pressed() -> void:
	emit_signal("ui_game_resumed")

# Show specific panels
func show_lane_management() -> void:
	_show_panel(lane_management_panel)

func show_carrier_offers() -> void:
	_show_panel(carrier_offers_panel)

func show_customer_interaction() -> void:
	_show_panel(customer_interaction_panel)

func show_market_overview() -> void:
	_show_panel(market_overview_panel)

func show_settings() -> void:
	settings_menu.visible = true

# Override for debug mode changes
func _on_debug_mode_changed() -> void:
	# Add debug information to UI if enabled
	if debug_mode:
		# Show debug overlay
		pass
	else:
		# Hide debug overlay
		pass

# Override get_class from base
func get_class() -> String:
	return "UIManager"
