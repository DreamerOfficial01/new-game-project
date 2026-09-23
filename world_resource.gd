extends StaticBody2D
class_name WorldResource

@export_group("Resource Identity")
@export var resource_name: String = "Tree"

@export_group("Harvesting")
@export var is_harvestable: bool = true
@export var max_health: int = 100
@export var resistance: int = 10
@export var accepted_methods: Array[String] = ["Chop"]
@export var accepted_tool_types: Array[String] = ["Axe"]
@export var base_harvest_duration: float = 1.0 # Time per HIT

@export_group("Drops")
@export var drops: Array[DropData]

@export_group("Auto Production")
@export var auto_produce_enabled: bool = false
@export var auto_produce_item: ItemData
@export var auto_produce_interval: Vector2 = Vector2(10.0, 20.0) 
@export var auto_produce_max: int = 5
@export var spawn_radius: float = 32.0

@export_group("Visual States")
@export var healthy_texture: Texture2D
@export var depleted_texture: Texture2D
@export var destroy_on_depleted: bool = false

var current_health: int = max_health
var is_depleted: bool = false
var auto_produce_timer: float = 0.0
var current_auto_interval: float = 0.0

@onready var sprite = $Sprite2D

var gather_timer: float = 0.0
var hit_timer: float = 0.0
var initial_total_time: float = 0.0

func _ready() -> void:
	add_to_group("persist")
	add_to_group("interactable")
	if healthy_texture:
		sprite.texture = healthy_texture
	reset_auto_timer()

func _process(delta: float) -> void:
	if auto_produce_enabled and not is_depleted:
		auto_produce_timer += delta
		if auto_produce_timer >= current_auto_interval:
			auto_produce_timer = 0.0
			reset_auto_timer()
			
			if get_spawned_count_for_this_bush() < auto_produce_max:
				attempt_spawn(auto_produce_item, 1)

func get_unique_spawner_id() -> String:
	return str(get_path())

func get_spawned_count_for_this_bush() -> int:
	var count = 0
	var entities = get_tree().current_scene.get_node_or_null("Entities")
	if not entities: return 0
	
	var my_id = get_unique_spawner_id()
	var target_path = auto_produce_item.resource_path if auto_produce_item else ""
	
	for child in entities.get_children():
		if child is PickupItem and child.item_data:
			if child.item_data.resource_path == target_path and child.spawner_id == my_id:
				count += child.amount
	return count

func reset_auto_timer() -> void:
	current_auto_interval = randf_range(auto_produce_interval.x, auto_produce_interval.y)

# --- NEW: Continuous Gathering Logic ---
func process_gather(delta: float, actor: Node, tool: ToolData = null) -> float:
	if not is_harvestable or is_depleted:
		return 100.0

	if accepted_tool_types.size() > 0:
		if tool == null or tool.tool_type not in accepted_tool_types:
			return 0.0 # Wrong tool, bar doesn't move
			
	var power = tool.power if tool else 10 
	var damage = maxi(1, power - resistance)
	if damage <= 0: return 0.0
	
	# Calculate the exact total time based on health when they started holding F
	if gather_timer == 0.0:
		var hits_needed = ceil(float(current_health) / float(damage))
		initial_total_time = hits_needed * base_harvest_duration
		
	var speed_multiplier = tool.speed if tool else 1.0
	gather_timer += (delta * speed_multiplier)
	hit_timer += (delta * speed_multiplier)
	
	# Trigger flashes/damage at each interval
	if hit_timer >= base_harvest_duration:
		hit_timer -= base_harvest_duration
		apply_hit(damage)
		
	if current_health <= 0:
		return 100.0
		
	return (gather_timer / initial_total_time) * 100.0

func apply_hit(dmg: int) -> void:
	current_health -= dmg
	if sprite:
		var tween = create_tween()
		sprite.modulate = Color(5, 5, 5, 1) 
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.15) 
		
	if current_health <= 0:
		deplete()

func cancel_gather() -> void:
	gather_timer = 0.0
	hit_timer = 0.0

func deplete() -> void:
	is_depleted = true
	remove_from_group("interactable")
	for drop in drops:
		if randf() * 100.0 <= drop.drop_chance:
			var qty = randi_range(drop.min_quantity, drop.max_quantity)
			if qty > 0:
				attempt_spawn(drop.item, qty)
	
	if destroy_on_depleted:
		queue_free()
	else:
		if depleted_texture:
			sprite.texture = depleted_texture

func attempt_spawn(item: ItemData, qty: int) -> void:
	var pickup_scene = load("res://PickupItem.tscn")
	if pickup_scene == null: return
	
	var inst = pickup_scene.instantiate()
	inst.item_data = item
	inst.amount = qty
	inst.spawner_id = get_unique_spawner_id()
	
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10.0, spawn_radius)
	inst.global_position = global_position + random_offset
	
	var entities_layer = get_tree().current_scene.get_node_or_null("Entities")
	if entities_layer:
		entities_layer.add_child(inst)
	else:
		get_tree().current_scene.add_child(inst)

func get_custom_save_data() -> Dictionary:
	return {
		"health": current_health,
		"is_depleted": is_depleted,
		"timer": auto_produce_timer
	}

func load_custom_save_data(data: Dictionary) -> void:
	current_health = data.get("health", max_health)
	is_depleted = data.get("is_depleted", false)
	auto_produce_timer = data.get("timer", 0.0)
	
	if is_depleted:
		remove_from_group("interactable") # FIX: Ensure loaded stumps stay un-interactable!
		if destroy_on_depleted:
			queue_free()
		elif depleted_texture:
			sprite.texture = depleted_texture
