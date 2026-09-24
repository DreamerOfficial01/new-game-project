extends Area2D

@onready var progress_bar: ProgressBar = get_node_or_null("../InteractionProgress")
@onready var weapon_hitbox: Area2D = get_node_or_null("../WeaponHitbox")
@onready var weapon_shape: CollisionShape2D = get_node_or_null("../WeaponHitbox/CollisionShape2D")

var current_target: Node2D = null
var is_interacting: bool = false
var is_attacking: bool = false

func _ready() -> void:
	if progress_bar:
		progress_bar.hide()
		progress_bar.max_value = 100
		progress_bar.z_index = 100
		progress_bar.z_as_relative = false
	if weapon_shape:
		weapon_shape.disabled = true

func _process(delta: float) -> void:
	if current_target and not is_instance_valid(current_target):
		current_target = null
		is_interacting = false
		if progress_bar:
			progress_bar.hide()
			progress_bar.value = 0.0

	# --- FIXED: Combat Logic (Now works with ANY tool that has power) ---
	# --- FIXED ATTACK TRIGGER ---
	if Input.is_action_just_pressed("attack") and not is_interacting and not is_attacking:
		var active_item = get_active_item()
		if active_item:
			# 1. First, check if the item uses your custom 'attack_damage' stat from the Inspector
			if "attack_damage" in active_item and active_item.attack_damage > 0:
				perform_attack(active_item.attack_damage)
			# 2. Fallback: Check if it uses the old ToolData system (like for your axe)
			elif active_item.tool_data and active_item.tool_data.power > 0:
				perform_attack(active_item.tool_data.power)
			else:
				print("WARNING: This item has no ToolData or its Attack Damage is 0!")



	if not is_interacting:
		var overlapping: Array = [] 
		overlapping.append_array(get_overlapping_areas())
		overlapping.append_array(get_overlapping_bodies())
		
		var closest = null
		var min_dist = INF
		
		for node in overlapping:
			if node.is_in_group("interactable"):
				var dist = global_position.distance_to(node.global_position)
				if dist < min_dist:
					min_dist = dist
					closest = node
					
		current_target = closest

	if current_target and Input.is_action_pressed("gather"):
		if not is_interacting:
			is_interacting = true
			if progress_bar:
				progress_bar.show()
			
		var active_item = get_active_item()
		var tool_data = active_item.tool_data if active_item else null
		
		if current_target.has_method("process_gather"):
			var progress = current_target.process_gather(delta, owner, tool_data)
			
			if progress_bar:
				progress_bar.value = progress
				
			if progress >= 100.0:
				is_interacting = false
				if progress_bar:
					progress_bar.hide()
					progress_bar.value = 0.0
	else:
		if is_interacting:
			is_interacting = false
			if current_target and current_target.has_method("cancel_gather"):
				current_target.cancel_gather()
			if progress_bar:
				progress_bar.hide()
				progress_bar.value = 0.0

# --- FIXED: Attack Execution ---
# --- NEW: MATHEMATICAL ATTACK CONE ---
# --- PERMANENT RADAR CONE ATTACK ---
# --- FIXED: Pure Hitbox Attack (No Math Required) ---
# --- TRULY FIXED: Pure Hitbox Attack (Absolutely No Math) ---
# --- THE BULLETPROOF ATTACK (NO AREA2D NEEDED) ---
# --- THE GIANT SLAYER ATTACK ---
# --- THE TRUE GIANT SLAYER ATTACK ---
# --- THE SMART GIANT SLAYER ATTACK ---
func perform_attack(damage: int) -> void:
	is_attacking = true
	var hit_something = false
	
	var mouse_pos = get_global_mouse_position()
	# Direction the player is aiming
	var attack_dir = global_position.direction_to(mouse_pos)
	
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	
	for enemy in all_enemies:
		var dist = global_position.distance_to(enemy.global_position)
		var dir_to_enemy = global_position.direction_to(enemy.global_position)
		
		# 1. INCREASED RANGE: 250.0 easily reaches the tall Zombie's feet
		if dist <= 250.0:
			
			# 2. AIMING CHECK: Dot product > 0 means the enemy is in front of you!
			if attack_dir.dot(dir_to_enemy) > 0.0:
				
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, attack_dir)
					hit_something = true
				
	if hit_something:
		print("SMACK! Dealt ", damage, " damage!")
	else:
		print("Swung sword, but no enemies were in front of you.")
					
	await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func get_active_item() -> ItemData:
	if InventoryManager and InventoryManager.active_hotbar_slot < InventoryManager.hotbar_inventory.size():
		var slot_dict = InventoryManager.hotbar_inventory[InventoryManager.active_hotbar_slot]
		if slot_dict and slot_dict.has("item"):
			return slot_dict["item"]
	return null
