# customer_manager.gd
class_name CustomerManager
extends Node

# Customer data
var customers: Dictionary = {}
var customer_needs: Dictionary = {}
var customer_contracts: Dictionary = {}
var pending_contracts: Dictionary = {}
var contract_history: Dictionary = {}

# Contract generation
var min_contract_interval: float = 30.0  # At least 30 seconds between contracts
var max_contract_interval: float = 120.0  # At most 2 minutes between contracts
var next_contract_time: float = 0.0
var contract_check_interval: float = 5.0
var contract_check_timer: float = 0.0

# References to other systems
var economy_manager: EconomyEmulator
var player_manager: PlayerManager

# Signals
signal customer_added(customer_id, customer_name)
signal customer_contract_offered(contract_id, customer_id, cargo_type, value)
signal customer_contract_accepted(contract_id)
signal customer_contract_completed(contract_id, success, profit)
signal customer_contract_failed(contract_id, reason)
signal customer_reputation_changed(customer_id, new_reputation)

func _ready():
    # Get references to other managers
    economy_manager = get_node("/root/GameManager/EconomyEmulator")
    player_manager = get_node("/root/GameManager/PlayerManager")
    
    # Schedule first contract offer
    _schedule_next_contract(0)

# Customer management
func add_customer(customer_id: String, customer_name: String, initial_trust: float = 50.0):
    if customers.has(customer_id):
        print_debug("Warning: Customer ID already exists: ", customer_id)
        return
    
    var customer = {
        "id": customer_id,
        "name": customer_name,
        "trust": initial_trust,  # 0-100 scale
        "contract_value_multiplier": 1.0,  # Base contract value
        "preferred_cargo_types": [],  # Types of cargo this customer needs
        "tier": _calculate_customer_tier(initial_trust),  # Premium, standard, etc.
        "active_contracts": [],  # Currently active contracts
        "contract_count": 0,  # Total contracts offered
        "successful_contracts": 0,  # Successfully completed contracts
        "failed_contracts": 0,  # Failed contracts
        "blacklisted": false,  # Whether customer refuses to work with player
        "next_contract_time": 0.0,  # When customer will offer next contract
    }
    
    customers[customer_id] = customer
    customer_needs[customer_id] = {}
    
    emit_signal("customer_added", customer_id, customer_name)

func remove_customer(customer_id: String):
    if customers.has(customer_id):
        customers.erase(customer_id)
        customer_needs.erase(customer_id)

# Customer needs and preferences
func set_customer_need(customer_id: String, cargo_type: String, need_level: float):
    if !customers.has(customer_id):
        print_debug("Warning: Unknown customer ID: ", customer_id)
        return
    
    if !customer_needs.has(customer_id):
        customer_needs[customer_id] = {}
    
    customer_needs[customer_id][cargo_type] = need_level
    
    # Add to preferred cargo types for quick reference
    if need_level > 0.0 && !customers[customer_id].preferred_cargo_types.has(cargo_type):
        customers[customer_id].preferred_cargo_types.append(cargo_type)

# Contract management
func generate_customer_contract(customer_id: String, game_time: float) -> Dictionary:
    if !customers.has(customer_id):
        return {}
    
    var customer = customers[customer_id]
    
    # Check if customer is blacklisted
    if customer.blacklisted:
        return {}
    
    # Select a cargo type based on customer needs
    var cargo_type = _select_customer_cargo_type(customer_id)
    if cargo_type == "":
        return {}  # No suitable cargo type found
    
    # Generate contract details
    var contract_id = "CC" + str(game_time).md5_text().substr(0, 8)
    var cargo_amount = randf_range(1.0, 10.0) * 10.0  # 10-100 units
    var base_value = _calculate_contract_value(cargo_type, cargo_amount)
    var contract_value = base_value * customer.contract_value_multiplier
    
    # Generate timeframes
    var deadline_buffer = 60.0 * (4 - _get_customer_tier_level(customer.tier))  # Premium customers have tighter deadlines
    var start_time = game_time
    var deadline = start_time + 300.0 + deadline_buffer  # Base 5 minutes + buffer
    var expiration_time = start_time + 60.0  # 1 minute to accept
    
    var contract = {
        "id": contract_id,
        "customer_id": customer_id,
        "cargo_type": cargo_type,
        "cargo_amount": cargo_amount,
        "value": contract_value,
        "upfront_cost": contract_value * 0.1,  # 10% upfront cost
        "penalty": contract_value * 0.2,  # 20% penalty for failure
        "start_time": start_time,
        "deadline": deadline,
        "expiration_time": expiration_time,
        "status": "pending",
        "carrier_assigned": false,
        "carrier_id": "",
        "lane_id": "",
        "difficulty": _get_customer_tier_level(customer.tier) / 3.0,  # 0.33-1.0 based on tier
    }
    
    # Store contract
    pending_contracts[contract_id] = contract
    customer.contract_count += 1
    
    emit_signal("customer_contract_offered", contract_id, customer_id, cargo_type, contract_value)
    return contract

func accept_customer_contract(contract_id: String) -> bool:
    if !pending_contracts.has(contract_id):
        return false
    
    var contract = pending_contracts[contract_id]
    var customer_id = contract.customer_id
    
    if !customers.has(customer_id):
        return false
    
    var customer = customers[customer_id]
    
    # Move contract from pending to active
    customer_contracts[contract_id] = contract
    pending_contracts.erase(contract_id)
    
    # Update contract status
    contract.status = "active"
    
    # Add to customer's active contracts
    if !customer.active_contracts.has(contract_id):
        customer.active_contracts.append(contract_id)
    
    emit_signal("customer_contract_accepted", contract_id)
    return true

func complete_customer_contract(contract_id: String, success: bool, profit: float = 0.0):
    if !customer_contracts.has(contract_id):
        return
    
    var contract = customer_contracts[contract_id]
    var customer_id = contract.customer_id
    
    if !customers.has(customer_id):
        return
    
    var customer = customers[customer_id]
    
    # Update contract status
    contract.status = success ? "completed" : "failed"
    
    # Remove from active contracts
    customer.active_contracts.erase(contract_id)
    
    # Update customer stats
    if success:
        customer.successful_contracts += 1
        modify_customer_trust(customer_id, 5.0 * contract.difficulty)  # Trust increase based on difficulty
    else:
        customer.failed_contracts += 1
        modify_customer_trust(customer_id, -10.0 * contract.difficulty)  # Trust decrease based on difficulty
    
    # Add to contract history
    if !contract_history.has(customer_id):
        contract_history[customer_id] = []
    
    contract_history[customer_id].append({
        "id": contract_id,
        "cargo_type": contract.cargo_type,
        "value": contract.value,
        "success": success,
        "completion_time": get_node("/root/GameManager").current_game_time
    })
    
    # Signal contract completion
    emit_signal("customer_contract_completed", contract_id, success, profit)

# Customer trust and relationship
func modify_customer_trust(customer_id: String, amount: float):
    if !customers.has(customer_id):
        return
    
    var customer = customers[customer_id]
    var old_trust = customer.trust
    var old_tier = customer.tier
    
    # Apply change, clamping to valid range
    customer.trust = clamp(customer.trust + amount, 0.0, 100.0)
    
    # Update customer tier if needed
    var new_tier = _calculate_customer_tier(customer.trust)
    if new_tier != old_tier:
        customer.tier = new_tier
        customer.contract_value_multiplier = _get_tier_value_multiplier(new_tier)
    
    # Check for blacklisting
    if customer.trust <= 10.0 && !customer.blacklisted:
        customer.blacklisted = true
    elif customer.trust > 10.0 && customer.blacklisted:
        customer.blacklisted = false
    
    emit_signal("customer_reputation_changed", customer_id, customer.trust)

# Utility functions
func _calculate_customer_tier(trust: float) -> String:
    if trust >= 90.0:
        return "premium"
    elif trust >= 70.0:
        return "preferred"
    elif trust >= 40.0:
        return "standard"
    else:
        return "basic"

func _get_customer_tier_level(tier: String) -> int:
    match tier:
        "premium":
            return 3
        "preferred":
            return 2
        "standard":
            return 1
        "basic":
            return 0
        _:
            return 0

func _get_tier_value_multiplier(tier: String) -> float:
    match tier:
        "premium":
            return 1.5  # 50% premium
        "preferred":
            return 1.2  # 20% premium
        "standard":
            return 1.0  # Standard rate
        "basic":
            return 0.8  # 20% discount
        _:
            return 1.0

func _select_customer_cargo_type(customer_id: String) -> String:
    if !customer_needs.has(customer_id) || customer_needs[customer_id].size() == 0:
        return ""  # No needs defined
    
    var needs = customer_needs[customer_id]
    var total_need = 0.0
    
    for cargo_type in needs:
        total_need += needs[cargo_type]
    
    if total_need <= 0.0:
        return ""  # No positive needs
    
    # Select based on weighted probability
    var roll = randf() * total_need
    var current_sum = 0.0
    
    for cargo_type in needs:
        current_sum += needs[cargo_type]
        if roll < current_sum:
            return cargo_type
    
    # Fallback to first cargo type (shouldn't happen normally)
    return needs.keys()[0]

func _calculate_contract_value(cargo_type: String, cargo_amount: float) -> float:
    # Base contract value depends on commodity price
    var commodity_price = economy_manager.get_price(cargo_type)
    if commodity_price == null:
        commodity_price = 20.0  # Default fallback price
    
    # Value is price * amount * markup
    return commodity_price * cargo_amount * 1.5  # 50% markup for logistics service

# Contract generation and scheduling
func _schedule_next_contract(current_time: float):
    # Calculate when the next contract should be offered
    var interval = randf_range(min_contract_interval, max_contract_interval)
    next_contract_time = current_time + interval

# Update loop
func update(delta: float, game_time: float):
    contract_check_timer += delta
    
    # Check for contract expirations
    _check_contract_expirations(game_time)
    
    // Check for new contracts periodically
    if contract_check_timer >= contract_check_interval:
        contract_check_timer = 0.0
        
        // Check if it's time for a new contract
        if game_time >= next_contract_time:
            // Select a customer to offer a contract
            var potential_customers = _get_potential_contract_customers(game_time)
            
            if potential_customers.size() > 0:
                var customer_index = randi() % potential_customers.size()
                var customer_id = potential_customers[customer_index]
                
                // Generate a contract from this customer
                generate_customer_contract(customer_id, game_time)
            
            // Schedule the next contract
            _schedule_next_contract(game_time)
    
    // Update individual customer timers and needs
    for customer_id in customers.keys():
        _update_customer_needs(customer_id, delta)

func _check_contract_expirations(game_time: float):
    var contracts_to_expire = []
    
    // Check pending contracts
    for contract_id in pending_contracts.keys():
        var contract = pending_contracts[contract_id]
        if game_time >= contract.expiration_time:
            contracts_to_expire.append(contract_id)
    
    // Process expirations
    for contract_id in contracts_to_expire:
        _expire_pending_contract(contract_id)

func _expire_pending_contract(contract_id: String):
    if !pending_contracts.has(contract_id):
        return
    
    var contract = pending_contracts[contract_id]
    var customer_id = contract.customer_id
    
    // Update customer relationship slightly negatively
    if customers.has(customer_id):
        modify_customer_trust(customer_id, -2.0)  // Small negative impact for ignoring contract
    
    // Remove the expired contract
    pending_contracts.erase(contract_id)

func _get_potential_contract_customers(game_time: float) -> Array:
    var potential_customers = []
    
    for customer_id in customers.keys():
        var customer = customers[customer_id]
        
        // Skip blacklisted customers
        if customer.blacklisted:
            continue
        
        // Skip customers who recently offered contracts
        if customer.next_contract_time > game_time:
            continue
        
        // Skip customers with too many active contracts
        if customer.active_contracts.size() >= 3:  // Max 3 active contracts per customer
            continue
        
        potential_customers.append(customer_id)
    }
    
    return potential_customers

func _update_customer_needs(customer_id: String, delta: float):
    if !customer_needs.has(customer_id):
        return
    
    // Gradually increase needs over time
    for cargo_type in customer_needs[customer_id].keys():
        var current_need = customer_needs[customer_id][cargo_type]
        
        // Increase need slightly
        var need_increase = delta * 0.01  // 1% increase per second
        customer_needs[customer_id][cargo_type] = current_need + need_increase

// Signal handlers
func _on_price_changed(item_name, new_price, actor_name):
    // Respond to economy price changes
    // This might affect contract values and customer needs
    pass
