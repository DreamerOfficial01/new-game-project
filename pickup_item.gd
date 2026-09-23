extends Area2D
class_name PickupItem # Added class_name for easy reference

enum PickupMode { MANUAL, AUTO, BOTH }

@export var item_data: ItemData
@export var amount: int = 1
@export var pickup_mode: PickupMode = PickupMode.BOTH

var target: Node2D = null
var base_magnet_speed: float = 150.0 # Saved so we can reset acceleration if dropped
var magnet_speed: float = 150.0

@onready var sprite = $Sprite2D

var current_speed = 0.0
var movement_direction = Vector2.ZERO

func _ready():
	# --- NEW: Add to required groups for Phase 3 ---
	add_to_group("persist")
	add_to_group("interactable")
	
	# --- EXISTING: Your scaling logic ---
	if item_data and item_data.icon:
		sprite.texture = item_data.icon
		
		var image_size = sprite.texture.get_size()
		var scale_x = 16.0 / image_size.x
		var scale_y = 16.0 / image_size.y
		
		sprite.scale = Vector2(scale_x, scale_y)


func _process(delta):
	# 1. If inventory is full, drop the target and coast to a stop
	if not InventoryManager.has_space_for(item_data):
		target = null
		magnet_speed = base_magnet_speed # Reset acceleration so it doesn't instantly snap later
		
		# Smoothly slow down (increased from 1.0 to 5.0 for better friction!)
		current_speed = lerp(current_speed, 0.0, 5.0 * delta)
		global_position += movement_direction * current_speed * delta
		return
	
	# --- NEW: Only run magnet logic if the mode allows it ---
	if pickup_mode == PickupMode.AUTO or pickup_mode == PickupMode.BOTH:
		if target:
			# 2. RECORD our momentum while flying so we have it if the inventory fills up!
			movement_direction = global_position.direction_to(target.global_position)
			current_speed = magnet_speed
			
			# Fly towards the player
			global_position = global_position.move_toward(target.global_position, magnet_speed * delta)
			magnet_speed += 300 * delta 
			
			# Pick it up when it touches
			if global_position.distance_to(target.global_position) < 15.0:
				execute_pickup(target)
		else:
			# Mathematically check for the player nearby (replaces the giant collision radar!)
			var player = get_tree().get_first_node_in_group("player")
			if player and global_position.distance_to(player.global_position) < 150.0: # 150 is the magnet range
				# ONLY lock on if the inventory has space!
				if InventoryManager.has_space_for(item_data):
					target = player


# --- NEW: Manual "Hold E" Interaction Hooks ---

# Called by PlayerInteraction to show the UI prompt
func get_interaction_prompt() -> String:
	if pickup_mode == PickupMode.AUTO: 
		return "" # Hide prompt if it's strictly a magnet item
	return "Pick up " + item_data.name

# Tells PlayerInteraction how long to hold E (0.2 seconds for quick pickup)
func get_hold_duration(tool = null) -> float:
	return 0.2

# Triggered when the UI circle finishes filling
func interact(actor: Node, tool = null) -> void:
	if pickup_mode != PickupMode.AUTO and InventoryManager.has_space_for(item_data):
		execute_pickup(actor)


# --- NEW: Consolidated Pickup & Save/Load Hooks ---

func execute_pickup(actor: Node) -> void:
	for i in range(amount): # Support dropping stacks of items at once
		if actor.has_method("collect_item"):
			actor.collect_item(item_data)
		else:
			InventoryManager.add_item(item_data)
	queue_free()

func get_custom_save_data() -> Dictionary:
	return {
		"item_path": item_data.resource_path if item_data else "",
		"amount": amount
	}

func load_custom_save_data(data: Dictionary) -> void:
	amount = data.get("amount", 1)
	var path = data.get("item_path", "")
	if path != "":
		item_data = load(path)
		# Trigger your scaling logic again so it looks correct after loading!
		if item_data and item_data.icon and sprite:
			sprite.texture = item_data.icon
			var image_size = sprite.texture.get_size()
			sprite.scale = Vector2(16.0 / image_size.x, 16.0 / image_size.y)
