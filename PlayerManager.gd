extends AbstractManager
class_name PlayerManager
# this is the second version of the player manager.
# Signals
signal balance_changed(new_balance, change_amount, reason)
signal reputation_changed(new_reputation, change_amount)
signal player_bankrupt
signal contract_added(contract_id)
signal contract_completed(contract_id, success)
signal contract_failed(contract_id, reason)
signal player_level_changed(new_level)

# Player identity
var player_name: String = "Player"
var company_name: String = "DeliverDirect Inc."

# Financial data
var balance: float = 0.0
var net_worth: float = 0.0
var revenue_history: Array = []
var expense_history: Array = []
var transaction_history: Array = []

# Reputation data
var global_reputation: float = 50.0  # 0-100 scale
var customer_trust: Dictionary = {}  # customer_id -> trust_level (0-100)
var carrier_trust: Dictionary = {}   # carrier_id -> trust_level (0-100)
var legal_standing: float = 100.0    # 0-100 scale, 100 is perfect

# Contract data
var active_contracts: Dictionary = {}  # contract_id -> contract_data
var completed_contracts: Array = []    # Historical record of completed contracts
var failed_contracts: Array = []       # Historical record of failed contracts

# Progression data
var experience_level: int = 1
var experience_points: int = 0
var experience_needed_for_next_level: int = 1000
var unlocked_features: Dictionary = {}
var special_permits: Array = []

# Debt and loan data
var loans: Array = []
var total_debt: float = 0.0

# Inventory and assets
var owned_assets: Dictionary = {}

# Constants
const STARTING_BALANCE: float = 100000.0  # $100,000
const BANKRUPTCY_THRESHOLD: float = -50000.0  # -$50,000
const MAX_REPUTATION: float = 100.0
const MIN_REPUTATION: float = 0.0

# Initialize player for a new game
func initialize_new_player() -> void:
	debug_log("Initializing new player")
	
	# Reset all player data
	player_name = "Player"
	company_name = "DeliverDirect Inc."
	
	# Set starting financial state
	balance = STARTING_BALANCE
	net_worth = STARTING_BALANCE
	revenue_history = []
	expense_history = []
	transaction_history = []
	
	# Set starting reputation
	global_reputation = 50.0
	customer_trust = {}
	carrier_trust = {}
	legal_standing = 100.0
	
	# Reset contracts
	active_contracts = {}
	completed_contracts = []
	failed_contracts = []
	
	# Reset progression
	experience_level = 1
	experience_points = 0
	experience_needed_for_next_level = 1000
	unlocked_features = {}
	special_permits = []
	
	# Reset debt
	loans = []
	total_debt = 0.0
	
	# Reset assets
	owned_assets = {}
	
	# Initialize default unlocked features
	unlocked_features = {
		"max_active_contracts": 3,
		"carrier_vetting": true,
		"basic_lanes": true,
		"basic_commodities": true
	}
	
	# Send initial signals
	emit_signal("balance_changed", balance, balance, "Initial funds")
	emit_signal("reputation_changed", global_reputation, 0.0)
	
	debug_log("Player initialized with $" + str(balance) + " and reputation " + str(global_reputation))

# Adjust player balance
func adjust_balance(amount: float, reason: String = "") -> void:
	var old_balance = balance
	balance += amount
	
	# Record transaction
	var transaction = {
		"amount": amount,
		"balance_after": balance,
		"reason": reason,
		"day": game_manager.current_game_day,
		"time": game_manager.current_game_time
	}
	
	transaction_history.append(transaction)
	
	# Update revenue/expense history
	if amount > 0:
		_record_revenue(amount, reason)
	else:
		_record_expense(abs(amount), reason)
	
	# Update net worth
	_update_net_worth()
	
	# Check for bankruptcy
	if balance < BANKRUPTCY_THRESHOLD:
		emit_signal("player_bankrupt")
	
	# Emit signal about balance change
	emit_signal("balance_changed", balance, amount, reason)
	
	debug_log("Balance adjusted: " + str(amount) + " (" + reason + "). New balance: " + str(balance))

# Record revenue
func _record_revenue(amount: float, source: String) -> void:
	revenue_history.append({
		"amount": amount,
		"source": source,
		"day": game_manager.current_game_day
	})

# Record expense
func _record_expense(amount: float, category: String) -> void:
	expense_history.append({
		"amount": amount,
		"category": category,
		"day": game_manager.current_game_day
	})

# Update net worth calculation
func _update_net_worth() -> void:
	# Start with current balance
	var worth = balance
	
	# Add value of owned lanes
	for lane_id in game_manager.map_manager.player_owned_lanes:
		var lane = game_manager.map_manager.lanes[lane_id]
		worth += lane["base_cost"] * 0.7  # Depreciated value
	
	# Add value of active contracts
	for contract_id in active_contracts.keys():
		var contract = active_contracts[contract_id]
		worth += contract["expected_profit"]
	
	# Subtract outstanding debt
	worth -= total_debt
	
	# Update net worth
	net_worth = worth

# Adjust reputation with a specific entity
func adjust_reputation(amount: float, entity_id: String = "", entity_type: String = "global") -> void:
	match entity_type:
		"global":
			global_reputation = clamp(global_reputation + amount, MIN_REPUTATION, MAX_REPUTATION)
		"customer":
			if not customer_trust.has(entity_id):
				customer_trust[entity_id] = 50.0
			
			customer_trust[entity_id] = clamp(customer_trust[entity_id] + amount, MIN_REPUTATION, MAX_REPUTATION)
		"carrier":
			if not carrier_trust.has(entity_id):
				carrier_trust[entity_id] = 50.0
			
			carrier_trust[entity_id] = clamp(carrier_trust[entity_id] + amount, MIN_REPUTATION, MAX_REPUTATION)
		"legal":
			legal_standing = clamp(legal_standing + amount, MIN_REPUTATION, MAX_REPUTATION)
	
	# Global reputation is slightly affected by all changes
	if entity_type != "global":
		global_reputation = clamp(global_reputation + (amount * 0.2), MIN_REPUTATION, MAX_REPUTATION)
	
	# Emit signal
	emit_signal("reputation_changed", global_reputation, amount)
	
	debug_log("Reputation adjusted: " + str(amount) + " for " + entity_type + 
			  (entity_id.is_empty() ? "" : " (" + entity_id + ")"))

# Add a new active contract
func add_contract(contract_id: String, contract_data: Dictionary) -> bool:
	# Check if we're at max contracts
	var max_contracts = unlocked_features.get("max_active_contracts", 3)
	if active_contracts.size() >= max_contracts:
		debug_log("Cannot add contract, at max capacity")
		return false
	
	# Add the contract
	active_contracts[contract_id] = contract_data
	
	# Signal contract added
	emit_signal("contract_added", contract_id)
	
	debug_log("Contract added: " + contract_id)
	return true

# Complete a contract successfully
func complete_contract(contract_id: String) -> void:
	if not active_contracts.has(contract_id):
		debug_log("Tried to complete non-existent contract: " + contract_id)
		return
	
	var contract = active_contracts[contract_id]
	
	# Add payment to balance
	adjust_balance(contract["payment"], "Contract Completed: " + contract_id)
	
	# Add reputation gain
	adjust_reputation(5.0, contract["customer_id"], "customer")
	
	# Move contract to completed list
	contract["completion_day"] = game_manager.current_game_day
	contract["success"] = true
	completed_contracts.append(contract)
	
	# Remove from active contracts
	active_contracts.erase(contract_id)
	
	# Signal contract completion
	emit_signal("contract_completed", contract_id, true)
	
	# Award experience points
	add_experience(100.0 + (contract["payment"] * 0.01))
	
	debug_log("Contract completed successfully: " + contract_id)

# Fail a contract
func fail_contract(contract_id: String, reason: String) -> void:
	if not active_contracts.has(contract_id):
		debug_log("Tried to fail non-existent contract: " + contract_id)
		return
	
	var contract = active_contracts[contract_id]
	
	# Apply financial penalty if specified
	if contract.has("penalty") and contract["penalty"] > 0:
		adjust_balance(-contract["penalty"], "Contract Penalty: " + contract_id)
	
	# Reputation loss
	adjust_reputation(-10.0, contract["customer_id"], "customer")
	
	# Move contract to failed list
	contract["failure_day"] = game_manager.current_game_day
	contract["failure_reason"] = reason
	contract["success"] = false
	failed_contracts.append(contract)
	
	# Remove from active contracts
	active_contracts.erase(contract_id)
	
	# Signal contract failure
	emit_signal("contract_failed", contract_id, reason)
	
	debug_log("Contract failed: " + contract_id + " (Reason: " + reason + ")")

# Add experience points to player
func add_experience(amount: float) -> void:
	experience_points += amount
	
	# Check for level up
	while experience_points >= experience_needed_for_next_level:
		experience_points -= experience_needed_for_next_level
		experience_level += 1
		experience_needed_for_next_level = _calculate_next_level_exp(experience_level)
		
		# Update unlocks based on new level
		_update_level_unlocks(experience_level)
		
		emit_signal("player_level_changed", experience_level)
		debug_log("Player leveled up to level " + str(experience_level))

# Calculate experience needed for next level
func _calculate_next_level_exp(level: int) -> int:
	# Simple exponential growth formula
	return 1000 * pow(1.5, level - 1)

# Update unlocks based on player level
func _update_level_unlocks(level: int) -> void:
	match level:
		2:
			unlocked_features["max_active_contracts"] = 5
			debug_log("Unlocked: Increased max contracts to 5")
		3:
			unlocked_features["advanced_vetting"] = true
			debug_log("Unlocked: Advanced carrier vetting")
		4:
			unlocked_features["max_active_contracts"] = 7
			debug_log("Unlocked: Increased max contracts to 7")
		5:
			unlocked_features["lane_upgrades"] = true
			debug_log("Unlocked: Lane upgrades")
		7:
			unlocked_features["max_active_contracts"] = 10
			debug_log("Unlocked: Increased max contracts to 10")
		10:
			unlocked_features["special_commodities"] = true
			debug_log("Unlocked: Special commodity types")
		_:
			pass

# Take out a loan
func take_loan(amount: float, interest_rate: float, term_days: int) -> bool:
	if amount <= 0 or interest_rate <= 0 or term_days <= 0:
		return false
	
	var loan = {
		"amount": amount,
		"interest_rate": interest_rate,
		"term_days": term_days,
		"remaining_days": term_days,
		"daily_payment": amount * (1 + interest_rate) / term_days,
		"total_remaining": amount * (1 + interest_rate),
		"start_day": game_manager.current_game_day
	}
	
	# Add loan to list
	loans.append(loan)
	
	# Update total debt
	total_debt += loan["total_remaining"]
	
	# Add to player balance
	adjust_balance(amount, "Loan")
	
	debug_log("Loan taken: $" + str(amount) + " at " + str(interest_rate * 100) + "% for " + str(term_days) + " days")
	return true

# Make loan payments
func process_loan_payments() -> void:
	var loans_to_remove = []
	
	for i in range(loans.size()):
		var loan = loans[i]
		
		# Deduct daily payment
		var payment = min(loan["daily_payment"], loan["total_remaining"])
		adjust_balance(-payment, "Loan Payment")
		
		# Update loan
		loan["total_remaining"] -= payment
		loan["remaining_days"] -= 1
		
		# Check if loan is paid off
		if loan["total_remaining"] <= 0 or loan["remaining_days"] <= 0:
			total_debt -= loan["total_remaining"]
			loans_to_remove.append(i)
			debug_log("Loan paid off: $" + str(loan["amount"]))
	
	# Remove paid off loans
	for i in range(loans_to_remove.size() - 1, -1, -1):
		loans.remove_at(loans_to_remove[i])

# Get total daily expenses
func get_daily_expenses() -> float:
	var total = 0.0
	
	# Loan payments
	for loan in loans:
		total += loan["daily_payment"]
	
	# Lane maintenance
	for lane_id in game_manager.map_manager.player_owned_lanes:
		var lane = game_manager.map_manager.lanes[lane_id]
		total += lane["maintenance_cost"]
	
	return total

# Process daily update
func process_daily_update() -> void:
	debug_log("Processing player daily update")
	
	# Process loans
	process_loan_payments()
	
	# Pay lane maintenance costs
	for lane_id in game_manager.map_manager.player_owned_lanes:
		var lane = game_manager.map_manager.lanes[lane_id]
		adjust_balance(-lane["maintenance_cost"], "Lane Maintenance: " + lane_id)
	
	# Update net worth
	_update_net_worth()

# Get current balance
func get_balance() -> float:
	return balance

# Get reputation score
func get_reputation_score() -> float:
	return global_reputation

# Get reputation with specific entity
func get_entity_reputation(entity_id: String, entity_type: String) -> float:
	match entity_type:
		"customer":
			return customer_trust.get(entity_id, 50.0)
		"carrier":
			return carrier_trust.get(entity_id, 50.0)
		_:
			return global_reputation

# Get total number of active contracts
func get_active_contracts_count() -> int:
	return active_contracts.size()

# Unlock special permit
func unlock_special_permit(permit_type: String) -> bool:
	if special_permits.has(permit_type):
		return false
	
	special_permits.append(permit_type)
	debug_log("Special permit unlocked: " + permit_type)
	return true

# Check if player has a special permit
func has_special_permit(permit_type: String) -> bool:
	return special_permits.has(permit_type)

# Get success rate for contracts
func get_contract_success_rate() -> float:
	var total = completed_contracts.size() + failed_contracts.size()
	if total == 0:
		return 100.0  # No contracts yet
	
	var success_count = 0
	for contract in completed_contracts:
		if contract["success"]:
			success_count += 1
	
	return (float(success_count) / float(total)) * 100.0

# Get save data
func get_save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"company_name": company_name,
		"balance": balance,
		"global_reputation": global_reputation,
		"customer_trust": customer_trust.duplicate(),
		"carrier_trust": carrier_trust.duplicate(),
		"legal_standing": legal_standing,
		"active_contracts": active_contracts.duplicate(true),
		"completed_contracts": completed_contracts.duplicate(true),
		"failed_contracts": failed_contracts.duplicate(true),
		"experience_level": experience_level,
		"experience_points": experience_points,
		"experience_needed_for_next_level": experience_needed_for_next_level,
		"unlocked_features": unlocked_features.duplicate(),
		"special_permits": special_permits.duplicate(),
		"loans": loans.duplicate(true),
		"total_debt": total_debt,
		"revenue_history": revenue_history.duplicate(true),
		"expense_history": expense_history.duplicate(true),
		"transaction_history": transaction_history.duplicate(true)
	}

# Load save data
func load_save_data(data: Dictionary) -> void:
	player_name = data["player_name"]
	company_name = data["company_name"]
	balance = data["balance"]
	global_reputation = data["global_reputation"]
	customer_trust = data["customer_trust"].duplicate()
	carrier_trust = data["carrier_trust"].duplicate()
	legal_standing = data["legal_standing"]
	active_contracts = data["active_contracts"].duplicate(true)
	completed_contracts = data["completed_contracts"].duplicate(true)
	failed_contracts = data["failed_contracts"].duplicate(true)
	experience_level = data["experience_level"]
	experience_points = data["experience_points"]
	experience_needed_for_next_level = data["experience_needed_for_next_level"]
	unlocked_features = data["unlocked_features"].duplicate()
	special_permits = data["special_permits"].duplicate()
	loans = data["loans"].duplicate(true)
	total_debt = data["total_debt"]
	revenue_history = data["revenue_history"].duplicate(true)
	expense_history = data["expense_history"].duplicate(true)
	transaction_history = data["transaction_history"].duplicate(true)
	
	# Update net worth
	_update_net_worth()
	
	debug_log("Player data loaded")

# Override get_class from base
func get_class() -> String:
	return "PlayerManager"
