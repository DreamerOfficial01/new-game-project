extends CharacterBody2D
class_name BaseEnemy

@export_category("Identity")
@export var enemy_name: String = "Monster"

@export_category("Combat Stats")
@export var max_health: int = 30
@export var move_speed: float = 65.0
@export var damage_to_player: int = 5
@export var attack_cooldown: float = 1.0

@export_category("AI & Vision")
@export var detection_radius: float = 200.0
@export var attack_range: float = 18.0

@export_category("Loot Drops")
@export var drops: Array[DropData] 
@export var spawn_radius: float = 24.0

var current_health: int
var player: Node2D = null
var can_attack: bool = true

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("enemy")
	add_to_group("persist")
	current_health = max_health

func _physics_process(_delta):
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return
		
	var dist = global_position.distance_to(player.global_position)
	
	# Chase Player
	if dist < detection_radius and dist > attack_range:
		velocity = global_position.direction_to(player.global_position) * move_speed
		move_and_slide()
		if sprite:
			sprite.flip_h = velocity.x < 0
			
	# Attack Player
	elif dist <= attack_range:
		velocity = Vector2.ZERO
		if can_attack:
			attack_player()

func attack_player() -> void:
	can_attack = false
	
	# Small lunge animation
	if sprite:
		var tween = create_tween()
		var original_pos = sprite.position
		var lunge_dir = global_position.direction_to(player.global_position) * 5.0
		tween.tween_property(sprite, "position", original_pos + lunge_dir, 0.1)
		tween.tween_property(sprite, "position", original_pos, 0.1)
	
	if player and player.has_method("take_damage"):
		player.take_damage(damage_to_player)
		
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int) -> void:
	current_health -= amount
	
	if sprite:
		var tween = create_tween()
		sprite.modulate = Color(3, 0, 0, 1) # Flash intense red
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)
	
	if current_health <= 0:
		die()

func die() -> void:
	for drop in drops:
		if randf() * 100.0 <= drop.drop_chance:
			var qty = randi_range(drop.min_quantity, drop.max_quantity)
			if qty > 0:
				attempt_spawn(drop.item, qty)
				
	var notifier = get_tree().get_first_node_in_group("loot_notifier")
	if notifier and notifier.has_method("notify_kill"):
		notifier.notify_kill(enemy_name)
		
	queue_free()

func attempt_spawn(item: ItemData, qty: int) -> void:
	var pickup_scene = load("res://PickupItem.tscn")
	if pickup_scene == null: return
	
	var inst = pickup_scene.instantiate()
	inst.item_data = item
	inst.amount = qty
	
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(5.0, spawn_radius)
	inst.global_position = global_position + random_offset
	
	var entities_layer = get_tree().current_scene.get_node_or_null("Entities")
	if entities_layer:
		entities_layer.add_child(inst)
	else:
		get_tree().current_scene.add_child(inst)

func get_custom_save_data() -> Dictionary:
	return { "health": current_health }

func load_custom_save_data(data: Dictionary) -> void:
	current_health = data.get("health", max_health)
	if current_health <= 0:
		queue_free()
