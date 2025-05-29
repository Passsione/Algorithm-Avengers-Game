extends Node2D

@export var enemy_scene: PackedScene
@export var max_enemies = 5
@export var spawn_radius = 300

func _ready():
	for i in max_enemies:
		spawn_enemy()

func spawn_enemy():
	var spawn_pos = Vector2(
		randf_range(-spawn_radius, spawn_radius),
		randf_range(-spawn_radius, spawn_radius)
	)
	
	var params = PhysicsPointQueryParameters2D.new()
	params.position = spawn_pos
	params.collision_mask = 1
	
	if get_world_2d().direct_space_state.get_rest_info(params).is_empty():
		var enemy = enemy_scene.instantiate()
		enemy.position = spawn_pos
		add_child(enemy)
