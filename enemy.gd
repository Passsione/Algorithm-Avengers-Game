# enemy.gd
extends CharacterBody2D

@export var move_speed: float = 80.0 # Increased speed for faster movement
@export var pathfinding_update_interval: float = 0.1 # Update path more frequently
@export var path_lookahead_steps: int = 3 # NEW: How many steps ahead to plan. Set to 0 or negative to disable.

# Animation names for different directions
const ANIM_DOWN = "walk_down"
const ANIM_UP = "walk_up"
const ANIM_LEFT = "walk_left"
const ANIM_RIGHT = "walk_right"
const ANIM_IDLE = "idle" # Optional idle animation


@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _tilemap_node: TileMap = null
var _maze_data: Array = []
var _exit_pos_tile: Vector2i = Vector2i.ZERO
var _current_path_world: Array[Vector2] = []
var _current_path_index: int = 0

var _a_star: AStar2D = AStar2D.new()
var _tile_size: Vector2 = Vector2.ONE * 16

# Pathfinding optimization
var _pathfinding_timer: float = 0.0
var _last_tile_pos: Vector2i = Vector2i(-999, -999) # Track position changes

const COLS_FOR_ID = 100
const WAYPOINT_TOLERANCE = 8.0 # Reduced tolerance for more precise movement
const EXIT_TOLERANCE_FACTOR = 0.2 # Tighter exit detection

signal enemy_reached_exit

func _ready() -> void:
	set_physics_process(false)
	if not is_instance_valid(sprite):
		printerr("Enemy: Sprite2D node not found or not assigned. Visuals will not work.")
	
	if not is_instance_valid(animation_player):
		printerr("Enemy: AnimationPlayer node not found. Animations will not work.")
	else:
		# Verify required animations exist
		var required_anims = [ANIM_DOWN, ANIM_UP, ANIM_LEFT, ANIM_RIGHT]
		for anim_name in required_anims:
			if not animation_player.has_animation(anim_name):
				printerr("Enemy: Missing animation '", anim_name, "' in AnimationPlayer.")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_tilemap_node):
		set_physics_process(false)
		printerr("Enemy: Tilemap node is not valid in _physics_process.")
		return

	# Update pathfinding periodically for better responsiveness
	_pathfinding_timer += delta
	if _pathfinding_timer >= pathfinding_update_interval:
		_pathfinding_timer = 0.0
		_check_and_update_path()

	# Check if path is completed or empty
	if _current_path_world.is_empty() or _current_path_index >= _current_path_world.size():
		_handle_path_completion()
		return

	var target_point: Vector2 = _current_path_world[_current_path_index]
	var direction_to_target: Vector2 = global_position.direction_to(target_point)
	
	if direction_to_target.length_squared() > 0:
		velocity = direction_to_target.normalized() * move_speed
		update_sprite_animation(velocity)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()

	# Check if current waypoint is reached
	if global_position.distance_to(target_point) < WAYPOINT_TOLERANCE:
		_current_path_index += 1

func _check_and_update_path() -> void:
	if not is_instance_valid(_tilemap_node):
		return
	
	var current_tile_pos = _tilemap_node.local_to_map(_tilemap_node.to_local(global_position))
	
	# Only recalculate if we've moved to a different tile
	if current_tile_pos != _last_tile_pos:
		_last_tile_pos = current_tile_pos
		
		# Validate current position is walkable
		if _is_tile_walkable(current_tile_pos):
			calculate_new_path(current_tile_pos)
		else:
			# If current position is not walkable, find nearest walkable tile
			var nearest_walkable = _find_nearest_walkable_tile(current_tile_pos)
			if nearest_walkable != Vector2i(-1, -1):
				calculate_new_path(nearest_walkable)

func _handle_path_completion() -> void:
	var global_exit_center = _tilemap_node.to_global(_tilemap_node.map_to_local(_exit_pos_tile) + _tile_size / 2.0)
	
	if global_position.distance_to(global_exit_center) < _tile_size.x * EXIT_TOLERANCE_FACTOR:
		if is_physics_processing():
			print("Enemy: Reached exit. Emitting signal.")
			emit_signal("enemy_reached_exit")
			set_physics_process(false)
			#get_tree().get_first_node_in_group("Player").set_physics_process(false)

func _is_tile_walkable(tile_pos: Vector2i) -> bool:
	if _maze_data.is_empty():
		return false
	
	if tile_pos.y < 0 or tile_pos.y >= _maze_data.size():
		return false
	
	if tile_pos.x < 0 or tile_pos.x >= _maze_data[tile_pos.y].size():
		return false
	
	return _maze_data[tile_pos.y][tile_pos.x] == 0

func _find_nearest_walkable_tile(from_tile: Vector2i) -> Vector2i:
	var search_radius = 3
	
	for radius in range(1, search_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) == radius or abs(dy) == radius: # Only check perimeter
					var check_tile = from_tile + Vector2i(dx, dy)
					if _is_tile_walkable(check_tile):
						return check_tile
	
	return Vector2i(-1, -1) # No walkable tile found

func update_sprite_animation(current_velocity: Vector2) -> void:
	if not is_instance_valid(animation_player):
		return

	if current_velocity.length_squared() > 0.1:
		var target_animation: String = ""
		var should_flip: bool = false

		# Determine primary movement direction
		if abs(current_velocity.x) > abs(current_velocity.y):
			# Moving horizontally
			if current_velocity.x < 0:
				# Moving left
				target_animation = ANIM_RIGHT
				should_flip = true
			else:
				# Moving right - use left animation but flipped
				target_animation = ANIM_RIGHT
				should_flip = false
		else:
			# Moving vertically
			should_flip = false
			if current_velocity.y < 0:
				# Moving up
				target_animation = ANIM_UP
			else:
				# Moving down
				target_animation = ANIM_DOWN
		
		# Apply sprite flipping
		if is_instance_valid(sprite):
			sprite.flip_h = should_flip
		
		# Play the animation if it's different from current
		if animation_player.current_animation != target_animation:
			if animation_player.has_animation(target_animation):
				animation_player.play(target_animation)
			else:
				printerr("Enemy: Animation '", target_animation, "' not found!")

func play_idle_animation() -> void:
	if not is_instance_valid(animation_player):
		return
	
	# Play idle animation if it exists, otherwise stop current animation
	if animation_player.has_animation(ANIM_IDLE):
		if animation_player.current_animation != ANIM_IDLE:
			animation_player.play(ANIM_IDLE)
	else:
		# No idle animation, just stop the current one
		if animation_player.is_playing():
			animation_player.stop()

func setup_ai(maze_array: Array, tilemap: TileMap, start_pos_tile: Vector2i, target_pos_tile: Vector2i) -> void:
	_maze_data = maze_array
	_tilemap_node = tilemap
	_exit_pos_tile = target_pos_tile
	
	if is_instance_valid(_tilemap_node) and is_instance_valid(_tilemap_node.tile_set):
		_tile_size = _tilemap_node.tile_set.tile_size
	else:
		printerr("Enemy AI: Tilemap node or tile_set not valid during setup. Using default tile size.")
		_tile_size = Vector2.ONE * 16

	# Ensure start position is walkable
	var actual_start_pos = start_pos_tile
	if not _is_tile_walkable(start_pos_tile):
		print("Enemy: Start position is not walkable, finding alternative...")
		actual_start_pos = _find_nearest_walkable_tile(start_pos_tile)
		if actual_start_pos == Vector2i(-1, -1):
			printerr("Enemy: No walkable start position found!")
			return

	var local_start_pos_center = _tilemap_node.map_to_local(actual_start_pos) 
	global_position = _tilemap_node.to_global(local_start_pos_center)

	print("Enemy AI setup. Start Tile: ", actual_start_pos, " Target Tile: ", _exit_pos_tile)
	print("Enemy Global Position Set To: ", global_position)
	
	# Initialize sprite and animation
	if is_instance_valid(animation_player):
		if animation_player.has_animation(ANIM_DOWN):
			animation_player.play(ANIM_DOWN)
		sprite.flip_h = false
	elif is_instance_valid(sprite):
		sprite.flip_h = false

	# Build pathfinding graph and calculate initial path
	update_pathfinding_graph()
	calculate_new_path(actual_start_pos)

func _tile_to_id(tile_pos: Vector2i) -> int:
	return tile_pos.x + tile_pos.y * COLS_FOR_ID

func _id_to_tile(id: int) -> Vector2i:
	return Vector2i(id % COLS_FOR_ID, id / COLS_FOR_ID)

func update_pathfinding_graph() -> void:
	if _maze_data.is_empty() or not is_instance_valid(_tilemap_node):
		printerr("Enemy AI: Maze data or tilemap not set for pathfinding graph.")
		return
	
	_a_star.clear()
	var rows = _maze_data.size()
	if rows == 0:
		return
	var cols = _maze_data[0].size()

	# Add all walkable tiles as points
	for r in range(rows):
		for c in range(cols):
			if _maze_data[r][c] == 0:
				var current_tile = Vector2i(c, r)
				_a_star.add_point(_tile_to_id(current_tile), current_tile, 1)

	# Connect adjacent walkable tiles
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	for r in range(rows):
		for c in range(cols):
			if _maze_data[r][c] == 0:
				var current_tile = Vector2i(c, r)
				var current_id = _tile_to_id(current_tile)
				
				for dir in directions:
					var neighbor_tile = current_tile + dir
					if _is_tile_walkable(neighbor_tile):
						var neighbor_id = _tile_to_id(neighbor_tile)
						if _a_star.has_point(neighbor_id):
							_a_star.connect_points(current_id, neighbor_id, false)

	print("Enemy A* graph populated with ", _a_star.get_point_count(), " points.")


func calculate_new_path(current_pos_tile: Vector2i) -> void:
	_current_path_world.clear()
	_current_path_index = 0

	if not is_instance_valid(_tilemap_node):
		printerr("Enemy: Tilemap node not valid in calculate_new_path.")
		set_physics_process(false)
		return

	# Validate start and end positions
	if not _a_star.has_point(_tile_to_id(current_pos_tile)):
		printerr("Enemy AI: Start position ", current_pos_tile, " is not walkable.")
		set_physics_process(false)
		return
		
	if not _a_star.has_point(_tile_to_id(_exit_pos_tile)):
		printerr("Enemy AI: Target position ", _exit_pos_tile, " is not walkable.")
		set_physics_process(false)
		return

	# Calculate path
	var path_ids: PackedInt64Array = _a_star.get_id_path(_tile_to_id(current_pos_tile), _tile_to_id(_exit_pos_tile))
	
	if path_ids.is_empty():
		if current_pos_tile == _exit_pos_tile:
			# Already at exit
			emit_signal("enemy_reached_exit")
		else:
			print("Enemy AI: No path found from ", current_pos_tile, " to ", _exit_pos_tile)
		set_physics_process(false)
		return

	# ---- MODIFICATION FOR SHORT-SIGHTED PATH ----
	var steps_to_process: int = path_ids.size()
	if path_lookahead_steps > 0 and path_ids.size() > path_lookahead_steps:
		steps_to_process = path_lookahead_steps
		print("Enemy AI: Path is long, taking only first ", steps_to_process, " steps (short-sighted).")
	# ---- END OF MODIFICATION ----

	# Convert path to world coordinates
	for i in range(steps_to_process): # Iterate only up to steps_to_process
		var id: int = path_ids[i] # Get id by index
		var tile_coord: Vector2i = _id_to_tile(id)
		var local_waypoint_center: Vector2 = _tilemap_node.map_to_local(tile_coord)
		var global_waypoint_center: Vector2 = _tilemap_node.to_global(local_waypoint_center)
		_current_path_world.append(global_waypoint_center)
	
	if not _current_path_world.is_empty():
		print("Enemy AI: Path calculated with ", _current_path_world.size(), " waypoints.")
		set_physics_process(true)
	else:
		# This case should ideally not be reached if path_ids was not empty,
		# unless steps_to_process became 0 for some unexpected reason.
		set_physics_process(false)
func maze_changed_replan(new_maze_data: Array) -> void:
	print("Enemy: Maze changed, replanning path.")
	_maze_data = new_maze_data
	update_pathfinding_graph()
	
	if not is_instance_valid(_tilemap_node):
		printerr("Enemy: Tilemap node not valid in maze_changed_replan.")
		return
		
	# Get current position and replan immediately
	var current_tile_pos = _tilemap_node.local_to_map(_tilemap_node.to_local(global_position))
	
	# Ensure current position is still walkable after maze change
	if not _is_tile_walkable(current_tile_pos):
		current_tile_pos = _find_nearest_walkable_tile(current_tile_pos)
		if current_tile_pos == Vector2i(-1, -1):
			printerr("Enemy: No walkable position found after maze change!")
			set_physics_process(false)
			return
	
	calculate_new_path(current_tile_pos)
