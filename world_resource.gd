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
@export var base_harvest_duration: float = 1.0 # Time to hold E

@export_group("Drops")
@export var drops: Array[DropData]

@export_group("Auto Production")
@export var auto_produce_enabled: bool = false
@export var auto_produce_item: ItemData
@export var auto_produce_interval: Vector2 = Vector2(10.0, 20.0) # Min/Max seconds
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
			attempt_spawn(auto_produce_item, 1)

func reset_auto_timer() -> void:
	current_auto_interval = randf_range(auto_produce_interval.x, auto_produce_interval.y)

# Called by PlayerInteraction
func get_interaction_prompt() -> String:
	if is_depleted: return ""
	return "Harvest " + resource_name

func get_hold_duration(tool: ToolData = null) -> float:
	if tool:
		return base_harvest_duration / tool.speed
	return base_harvest_duration

func interact(actor: Node, tool: ToolData = null) -> void:
	if not is_harvestable or is_depleted:
		return

	# Validation: Does the tool match?
	if accepted_tool_types.size() > 0:
		if tool == null or tool.tool_type not in accepted_tool_types:
			# Needs a tool but player has none/wrong one
			return
			
	var power = tool.power if tool else 10 # Base power if no tool required
	var damage = maxi(1, power - resistance)
	
	current_health -= damage
	# Optional: Trigger particles/wobble animation here
	
	if current_health <= 0:
		deplete()

func deplete() -> void:
	is_depleted = true
	# Generate drops
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
	var pickup_scene = load("res://PickupItem.tscn") # Adjust path to your pickup item scene
	if pickup_scene == null: return
	
	var inst = pickup_scene.instantiate()
	inst.item_data = item
	inst.amount = qty
	
	# Generic spawn validation (within radius, simplified)
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10.0, spawn_radius)
	inst.global_position = global_position + random_offset
	
	# Add to world container
	var entities_layer = get_tree().current_scene.get_node_or_null("Entities")
	if entities_layer:
		entities_layer.add_child(inst)
	else:
		get_tree().current_scene.add_child(inst)

# --- PERSISTENCE ---
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
		if destroy_on_depleted:
			queue_free()
		elif depleted_texture:
			sprite.texture = depleted_texture
