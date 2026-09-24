extends Node2D
class_name EnemySpawner

@export_group("Spawner Settings")
@export var enemy_scene: PackedScene
@export var max_enemies: int = 3
@export var spawn_interval: float = 15.0
@export var spawn_radius: float = 100.0
@export var is_active: bool = true

var active_enemies: Array[Node] = []
var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if not is_active or not enemy_scene:
		return
		
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		attempt_spawn()

func attempt_spawn() -> void:
	# OPTIMIZATION: Clean the array of any dead enemies before counting
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.is_queued_for_deletion())
	
	# Stop spawning if we reached the camp limit
	if active_enemies.size() >= max_enemies:
		return
		
	var inst = enemy_scene.instantiate()
	
	# Pick a random spot around the spawner
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10.0, spawn_radius)
	inst.global_position = global_position + random_offset
	
	# Spawn it into the world
	var entities_layer = get_tree().current_scene.get_node_or_null("Entities")
	if entities_layer:
		entities_layer.add_child(inst)
	else:
		get_tree().current_scene.add_child(inst)
		
	# Track the enemy so we don't spawn infinite amounts
	active_enemies.append(inst)
