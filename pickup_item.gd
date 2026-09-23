extends Area2D
class_name PickupItem

@export var item_data: ItemData
@export var amount: int = 1
@export var manual_gather_time: float = 1.0 # The time it takes to pick up "MANUAL" items

# --- Hover Animation Settings ---
@export var hover_amplitude: float = 3.0 
@export var hover_speed: float = 4.0     

var target: Node2D = null
var base_magnet_speed: float = 150.0
var magnet_speed: float = 150.0
var spawner_id: String = "" 

@onready var sprite = $Sprite2D

var current_speed = 0.0
var movement_direction = Vector2.ZERO

var time_passed: float = 0.0
var hover_offset: float = 0.0
var base_sprite_y: float = 0.0

var gather_timer: float = 0.0 # Tracks the F key holding

func _ready():
	add_to_group("persist")
	add_to_group("interactable")
	
	hover_offset = randf() * PI * 2.0
	if sprite:
		base_sprite_y = sprite.position.y
		
	apply_texture_and_scale()

func apply_texture_and_scale():
	if item_data and item_data.icon and sprite:
		sprite.texture = item_data.icon
		sprite.scale = Vector2(1.0, 1.0)
		scale = Vector2(1.0, 1.0)

func _process(delta):
	if not item_data: return
	var mode = item_data.pickup_mode 
	
	if mode == ItemData.PickupMode.AUTO:
		time_passed += delta
		if sprite:
			sprite.position.y = base_sprite_y + sin(time_passed * hover_speed + hover_offset) * hover_amplitude
	
	if not InventoryManager.has_space_for(item_data):
		target = null
		magnet_speed = base_magnet_speed 
		current_speed = lerp(current_speed, 0.0, 5.0 * delta)
		global_position += movement_direction * current_speed * delta
		return
	
	if mode == ItemData.PickupMode.AUTO or mode == ItemData.PickupMode.BOTH:
		if target:
			movement_direction = global_position.direction_to(target.global_position)
			current_speed = magnet_speed
			global_position = global_position.move_toward(target.global_position, magnet_speed * delta)
			magnet_speed += 300 * delta 
			
			if global_position.distance_to(target.global_position) < 15.0:
				execute_pickup(target)
		else:
			var player = get_tree().get_first_node_in_group("player")
			if player and global_position.distance_to(player.global_position) < 150.0:
				if InventoryManager.has_space_for(item_data):
					target = player

# --- NEW: Continuous Gathering System ---
func process_gather(delta: float, actor: Node, tool = null) -> float:
	if not item_data: return 100.0
	if item_data.pickup_mode == ItemData.PickupMode.AUTO: 
		return 100.0 # Magnet items skip the loading bar entirely
		
	if not InventoryManager.has_space_for(item_data):
		gather_timer = 0.0
		return 0.0 # Cannot pick up, bar doesn't move
		
	gather_timer += delta
	var progress = (gather_timer / manual_gather_time) * 100.0
	
	if progress >= 100.0:
		execute_pickup(actor)
		
	return progress

func cancel_gather() -> void:
	gather_timer = 0.0

func execute_pickup(actor: Node) -> void:
	for i in range(amount): 
		if actor.has_method("collect_item"):
			actor.collect_item(item_data)
		else:
			InventoryManager.add_item(item_data)
	queue_free()

func get_custom_save_data() -> Dictionary:
	return {
		"item_path": item_data.resource_path if item_data else "",
		"amount": amount,
		"spawner_id": spawner_id
	}

func load_custom_save_data(data: Dictionary) -> void:
	amount = data.get("amount", 1)
	spawner_id = data.get("spawner_id", "") 
	var path = data.get("item_path", "")
	if path != "":
		item_data = load(path)
		apply_texture_and_scale()
