# player_manager.gd
class_name PlayerManager
extends Node

# Player data
var player_name: String = "Player Company"
var balance: float = 10000.0
var reputation: float = 50.0  # 0-100 scale

# Player progression and stats
var experience: float = 0.0
var level: int = 1
var company_value: float = 0.0
var contracts_completed: int = 0
var contracts_failed: int = 0
var total_revenue: float = 0.0
var total_expenses: float = 0.0
var carrier_relationships: Dictionary = {}
var customer_relationships: Dictionary = {}

# Business assets and inventory
var owned_lanes: Array = []
var special_permits: Dictionary = {}
var investments: Dictionary = {}

# Gameplay state
var active_contracts: Dictionary = {}
var pending_contracts: Dictionary = {}
var blacklisted_carriers: Array = []
var trusted_carriers: Array = []

# Reputation thresholds
const REPUTATION_ELITE = 90.0
const REPUTATION_RESPECTED = 70.0
const REPUTATION_NEUTRAL = 50.0
const REPUTATION_UNRELIABLE = 30.0
const REPUTATION_BLACKLISTED = 0.0

# Progression thresholds
const XP_PER_LEVEL = 1000.0

# Signals
signal balance_changed(new_balance)
signal reputation_changed(new_reputation)
signal contract_accepted(contract_id)
signal contract_completed(contract_id, profit)
signal contract_failed(contract_id, reason)
signal level_up(new_level)
signal lane_purchased(lane_id, cost)
signal investment_made(investment_id, amount)

func _ready():
    pass

# Basic getters and setters
func get_balance() -> float:
    return balance
    
func get_reputation() -> float:
    return reputation
    
func get_level() -> int:
    return level
    
func get_company_value() -> float:
    # Calculate company value based on assets and cash
    return balance + _calculate_asset_value()

# Initialization function
func initialize_player(company_name: String, starting_balance: float, 
                      starting_reputation: float):
    player_name = company_name
    balance = starting_balance
    reputation = starting_reputation
    emit_signal("balance_changed", balance)
    emit_signal("reputation_changed", reputation)

# Financial functions
func modify_balance(amount: float, reason: String = ""):
    balance += amount
    emit_signal("balance_changed", balance)
    
    if amount > 0:
        total_revenue += amount
    else:
        total_expenses += abs(amount)
    
    # Check for bankruptcy
    if balance < 0:
        # Future: trigger bankruptcy event
        pass

func can_afford(amount: float) -> bool:
    return balance >= amount

# Contract management
func accept_contract(contract: Dictionary) -> bool:
    # Check if player can take on this contract (has capital, not blacklisted, etc.)
    if !can_afford(contract.upfront_cost):
        return false
    
    # Store the contract
    active_contracts[contract.id] = contract
    
    # Apply financial effects
    modify_balance(-contract.upfront_cost, "Contract upfront cost")
    
    emit_signal("contract_accepted", contract.id)
    return true

func complete_contract(contract_id: String, success: bool, quality: float):
    if !active_contracts.has(contract_id):
        return
    
    var contract = active_contracts[contract_id]
    
    if success:
        # Calculate profit
        var revenue = contract.value
        var expenses = contract.carrier_cost
        var profit = revenue - expenses
        
        # Apply financial effects
        modify_balance(profit, "Contract completion")
        
        # Apply reputation effects based on quality
        var rep_change = _calculate_reputation_impact(quality, contract.difficulty)
        modify_reputation(rep_change)
        
        # Track contract completion for stats
        contracts_completed += 1
        
        # Add experience
        add_experience(contract.value * 0.1)
        
        # Update customer relationship
        if contract.has("customer_id"):
            improve_customer_relationship(contract.customer_id, quality)
        
        emit_signal("contract_completed", contract_id, profit)
    else:
        # Failed contract
        var penalty = contract.penalty if contract.has("penalty") else 0.0
        
        # Apply financial effects
        modify_balance(-penalty, "Contract failure penalty")
        
        # Apply negative reputation effect
        modify_reputation(-10.0)
        
        # Track contract failure for stats
        contracts_failed += 1
        
        # Update customer relationship negatively
        if contract.has("customer_id"):
            damage_customer_relationship(contract.customer_id, 0.5)
        
        emit_signal("contract_failed", contract_id, "player_failure")
    
    # Remove the contract
    active_contracts.erase(contract_id)

# Reputation management
func modify_reputation(amount: float):
    var old_reputation = reputation
    reputation = clamp(reputation + amount, 0.0, 100.0)
    
    # Check for threshold crossings (for gameplay events)
    if old_reputation < REPUTATION_RESPECTED && reputation >= REPUTATION_RESPECTED:
        # Player has become respected - trigger event
        pass
    elif old_reputation >= REPUTATION_RESPECTED && reputation < REPUTATION_RESPECTED:
        # Player has lost respected status - trigger event
        pass
    
    emit_signal("reputation_changed", reputation)

func get_reputation_tier() -> String:
    if reputation >= REPUTATION_ELITE:
        return "Elite"
    elif reputation >= REPUTATION_RESPECTED:
        return "Respected"
    elif reputation >= REPUTATION_NEUTRAL:
        return "Neutral"
    elif reputation >= REPUTATION_UNRELIABLE:
        return "Unreliable"
    else:
        return "Blacklisted"

# Progression system
func add_experience(amount: float):
    experience += amount
    
    # Check for level up
    var new_level = int(experience / XP_PER_LEVEL) + 1
    if new_level > level:
        level_up(new_level)

func level_up(new_level: int):
    level = new_level
    # Apply level-up benefits like new lane access, discounts, etc.
    emit_signal("level_up", level)

# Relationship management
func improve_carrier_relationship(carrier_id: String, amount: float):
    if !carrier_relationships.has(carrier_id):
        carrier_relationships[carrier_id] = 50.0  # Neutral starting point
    
    carrier_relationships[carrier_id] = clamp(carrier_relationships[carrier_id] + amount, 0.0, 100.0)
    
    # Check if carrier should be added to trusted list
    if carrier_relationships[carrier_id] >= 80.0 && !trusted_carriers.has(carrier_id):
        trusted_carriers.append(carrier_id)

func damage_carrier_relationship(carrier_id: String, amount: float):
    if !carrier_relationships.has(carrier_id):
        carrier_relationships[carrier_id] = 50.0  # Neutral starting point
    
    carrier_relationships[carrier_id] = clamp(carrier_relationships[carrier_id] - amount, 0.0, 100.0)
    
    # Check if carrier should be blacklisted
    if carrier_relationships[carrier_id] <= 20.0 && !blacklisted_carriers.has(carrier_id):
        blacklisted_carriers.append(carrier_id)
    
    # Remove from trusted list if applicable
    if carrier_relationships[carrier_id] < 80.0 && trusted_carriers.has(carrier_id):
        trusted_carriers.erase(carrier_id)

func damage_customer_relationship(customer_id: String, amount: float):
    if !customer_relationships.has(customer_id):
        customer_relationships[customer_id] = 50.0  # Neutral starting point
    
    customer_relationships[customer_id] = clamp(customer_relationships[customer_id] - amount, 0.0, 100.0)

# Asset management
func purchase_lane(lane_id: String, cost: float) -> bool:
    if !can_afford(cost):
        return false
    
    modify_balance(-cost, "Lane purchase")
    owned_lanes.append(lane_id)
    
    emit_signal("lane_purchased", lane_id, cost)
    return true

func acquire_special_permit(permit_type: String, cost: float, duration: float) -> bool:
    if !can_afford(cost):
        return false
    
    modify_balance(-cost, "Special permit acquisition")
    
    # Store the permit with expiration time
    special_permits[permit_type] = {
        "acquired_at": Time.get_unix_time_from_system(),
        "duration": duration,
        "expires_at": Time.get_unix_time_from_system() + duration
    }
    
    return true

func make_investment(investment_id: String, amount: float) -> bool:
    if !can_afford(amount):
        return false
    
    modify_balance(-amount, "Investment")
    
    if investments.has(investment_id):
        investments[investment_id] += amount
    else:
        investments[investment_id] = amount
    
    emit_signal("investment_made", investment_id, amount)
    return true

# Utility functions
func _calculate_asset_value() -> float:
    var asset_value = 0.0
    
    # Value of owned lanes
    for lane_id in owned_lanes:
        # Calculate lane value based on traffic, condition, etc.
        # This would normally query the map system
        asset_value += 5000.0  # Placeholder value
    
    # Value of investments
    for investment_id in investments:
        asset_value += investments[investment_id]  # Base investment amount
        # Future: calculate ROI and appreciation
    
    return asset_value

func _calculate_reputation_impact(quality: float, difficulty: float) -> float:
    # Calculate reputation change based on contract quality and difficulty
    # Higher difficulty contracts have more impact on reputation
    return quality * difficulty * 5.0

# Signal handlers from other systems
func _on_carrier_contract_accepted(contract_id, carrier_id, lane_id):
    # Handle the financial and tracking aspects when a carrier accepts a contract
    if active_contracts.has(contract_id):
        var contract = active_contracts[contract_id]
        contract.carrier_id = carrier_id
        contract.carrier_assigned = true
    
func _on_customer_contract_completed(contract_id, success, profit):
    # Process contract completion from customer's perspective
    complete_contract(contract_id, success, 1.0)  # 1.0 is placeholder quality

func _on_price_changed(item_name, new_price, actor_name):
    # Respond to economy changes
    # This might affect the value of assets, contracts, etc.
    pass
