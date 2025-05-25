#
## MazeGenerator.gd
#extends Node2D
#
## Preload your scenes for walls and floors
#@export var wall_scene: PackedScene
#@export var floor_scene: PackedScene # Optional
#@export var player_scene: PackedScene # For spawning the player
#@export var warning_effect_scene: PackedScene # Optional: Scene for wall warning visual
#
## Define the size of each logical grid cell in pixels.
#@export var cell_size: Vector2 = Vector2(40, 40)
#
## Maze dimensions (number of cells) - should be odd and ideally >= 5 for interesting modifications
#@export var maze_width: int = 21
#@export var maze_height: int = 15
#
## Offset for the entire maze's top-left corner from this Node2D's origin
#@export var maze_offset: Vector2 = Vector2(20, 15)
#
## Duration for the warning before a wall appears
#@export var wall_warning_duration: float = 2.0 # seconds
#
#var maze_matrix: Array = []
#var entrance_matrix_pos: Vector2i
#var exit_matrix_pos: Vector2i
#var player_node: Node2D = null # Reference to the player instance
#
## --- Maze Generation Algorithm (Recursive Backtracker) ---
#func _generate_maze_matrix():
	#maze_matrix.clear()
#
	## Ensure odd dimensions and minimum size for Recursive Backtracker & modifications
	#if maze_width < 5: maze_width = 5 # Need some internal space for modifications
	#if maze_height < 5: maze_height = 5
	#if maze_width % 2 == 0: maze_width += 1
	#if maze_height % 2 == 0: maze_height += 1
#
	## 1. Initialize with all walls (1s)
	#for y in range(maze_height):
		#var row: Array = []
		#for x in range(maze_width):
			#row.append(1) # 1 = wall
		#maze_matrix.append(row)
#
	## --- Recursive Backtracker Implementation ---
	#var stack: Array = []
	#var current_cell: Vector2i = Vector2i(1, 1)
	#maze_matrix[current_cell.y][current_cell.x] = 0
	#
	#var path_cells_x = (maze_width - 1) / 2
	#var path_cells_y = (maze_height - 1) / 2
	#var total_potential_path_cells: int = path_cells_x * path_cells_y
	#var visited_path_cells: int = 1
	#stack.push_back(current_cell)
#
	#while visited_path_cells < total_potential_path_cells and not stack.is_empty():
		#var neighbors: Array = []
		#var cx: int = current_cell.x
		#var cy: int = current_cell.y
#
		#if cy - 2 >= 1 and maze_matrix[cy - 2][cx] == 1: neighbors.append(Vector2i(cx, cy - 2))
		#if cy + 2 < maze_height - 1 and maze_matrix[cy + 2][cx] == 1: neighbors.append(Vector2i(cx, cy + 2))
		#if cx - 2 >= 1 and maze_matrix[cy][cx - 2] == 1: neighbors.append(Vector2i(cx - 2, cy))
		#if cx + 2 < maze_width - 1 and maze_matrix[cy][cx + 2] == 1: neighbors.append(Vector2i(cx + 2, cy))
#
		#if not neighbors.is_empty():
			#var next_cell: Vector2i = neighbors.pick_random()
			#stack.push_back(current_cell)
			#maze_matrix[next_cell.y][next_cell.x] = 0
			#var wall_to_remove_x = current_cell.x + (next_cell.x - current_cell.x) / 2
			#var wall_to_remove_y = current_cell.y + (next_cell.y - current_cell.y) / 2
			#maze_matrix[wall_to_remove_y][wall_to_remove_x] = 0
			#current_cell = next_cell
			#visited_path_cells += 1
		#elif not stack.is_empty():
			#current_cell = stack.pop_back()
		#else: break
	## --- End of Recursive Backtracker ---
	#_create_random_entrance_exit()
#
#func _create_random_entrance_exit():
	#var valid_y_indices_for_edges = []
	#for i in range(1, maze_height - 1, 2): valid_y_indices_for_edges.append(i)
	#var valid_x_indices_for_edges = []
	#for i in range(1, maze_width - 1, 2): valid_x_indices_for_edges.append(i)
#
	#if valid_y_indices_for_edges.is_empty() or valid_x_indices_for_edges.is_empty():
		#push_error("Maze dimensions too small for random entrance/exit.")
		#entrance_matrix_pos = Vector2i(0, 1)
		#exit_matrix_pos = Vector2i(maze_width - 1, maze_height - 2)
		#if maze_matrix.size() > 1: maze_matrix[1][0] = 0
		#if maze_matrix.size() > maze_height - 2 && maze_matrix[0].size() > maze_width -1:
			#maze_matrix[maze_height - 2][maze_width - 1] = 0
		#return
#
	#var edge_choice = randi() % 2
	#if edge_choice == 0: # Left/Right
		#entrance_matrix_pos.y = valid_y_indices_for_edges.pick_random()
		#entrance_matrix_pos.x = 0
		#exit_matrix_pos.y = valid_y_indices_for_edges.pick_random()
		#exit_matrix_pos.x = maze_width - 1
	#else: # Top/Bottom
		#entrance_matrix_pos.x = valid_x_indices_for_edges.pick_random()
		#entrance_matrix_pos.y = 0
		#exit_matrix_pos.x = valid_x_indices_for_edges.pick_random()
		#exit_matrix_pos.y = maze_height - 1
#
	#maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x] = 0
	#maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x] = 0
#
## --- Instantiation Logic ---
#func _draw_maze():
	#for child in get_children():
		#if not child.is_in_group("player") and not child.is_in_group("persistent_effect"): # Avoid deleting player or effects
			#child.queue_free()
#
	#if maze_matrix.is_empty():
		#printerr("Maze matrix is empty.")
		#return
#
	#for y in range(maze_matrix.size()):
		#for x in range(maze_matrix[y].size()):
			#var cell_type = maze_matrix[y][x]
			#var instance_position = Vector2(x * cell_size.x, y * cell_size.y) + maze_offset
			#var grid_pos = Vector2i(x,y)
#
			#if cell_type == 1: # Wall
				#if wall_scene:
					#var wall_instance = wall_scene.instantiate()
					#wall_instance.position = instance_position
					#wall_instance.set_meta("grid_pos", grid_pos)
					#wall_instance.add_to_group("wall_tile")
					#add_child(wall_instance)
			#elif cell_type == 0: # Path
				#if floor_scene:
					#var floor_instance = floor_scene.instantiate()
					#floor_instance.position = instance_position
					#floor_instance.set_meta("grid_pos", grid_pos)
					#floor_instance.add_to_group("floor_tile")
					#add_child(floor_instance)
#
#func _spawn_player_at_entrance():
	#if not player_scene:
		#print("Player scene not set. Player will not be spawned.")
		#return
	#if entrance_matrix_pos == null:
		#printerr("Entrance position not determined. Cannot spawn player.")
		#return
#
	#var player_instance = player_scene.instantiate()
	#var world_x = entrance_matrix_pos.x * cell_size.x + maze_offset.x + cell_size.x / 2.0
	#var world_y = entrance_matrix_pos.y * cell_size.y + maze_offset.y + cell_size.y / 2.0
	#player_instance.global_position = Vector2(world_x, world_y)
	#player_instance.add_to_group("player")
	#self.player_node = player_instance # Store reference
#
	#if get_parent(): get_parent().add_child(player_instance)
	#else: add_child(player_instance)
#
## --- Dynamic Wall Modification ---
#func modify_random_walls():
	#if player_node == null or not is_instance_valid(player_node): # Check if player exists
		#var players = get_tree().get_nodes_in_group("player")
		#if not players.is_empty(): self.player_node = players[0]
		## else: print("Player not found for wall modification check.") # Can proceed without player check
#
	#var modifiable_paths = []
	#var modifiable_walls = []
	#for y in range(1, maze_height - 1): # Iterate internal cells, excluding border
		#for x in range(1, maze_width - 1):
			#var current_grid_pos = Vector2i(x,y)
			## Ensure not to modify entrance or exit cells
			#if current_grid_pos == entrance_matrix_pos or current_grid_pos == exit_matrix_pos:
				#continue
			#if maze_matrix[y][x] == 0: modifiable_paths.append(current_grid_pos)
			#else: modifiable_walls.append(current_grid_pos)
#
	#if modifiable_paths.is_empty() and modifiable_walls.is_empty():
		#print("No internal cells available for modification.")
		#return
#
	#var num_changes = randi_range(1, 3)
	#print("Attempting to make %d wall modifications." % num_changes)
#
	#for i in range(num_changes):
		#var action_type = randi() % 2 # 0 to remove, 1 to add
#
		#if action_type == 0 and not modifiable_walls.is_empty(): # Try remove wall
			#var cell_to_modify_idx = randi() % modifiable_walls.size()
			#var cell_pos: Vector2i = modifiable_walls.pop_at(cell_to_modify_idx)
			#_remove_wall_at(cell_pos)
			#modifiable_paths.append(cell_pos) # Now it's a path
		#elif action_type == 1 and not modifiable_paths.is_empty(): # Try add wall
			#var cell_to_modify_idx = randi() % modifiable_paths.size()
			#var cell_pos: Vector2i = modifiable_paths.pop_at(cell_to_modify_idx)
			#await _warn_and_add_wall_at(cell_pos) # Asynchronous
			#modifiable_walls.append(cell_pos) # Now it's a wall
		#elif not modifiable_walls.is_empty(): # Fallback to remove if add failed (no paths)
			#var cell_to_modify_idx = randi() % modifiable_walls.size()
			#var cell_pos: Vector2i = modifiable_walls.pop_at(cell_to_modify_idx)
			#_remove_wall_at(cell_pos)
			#modifiable_paths.append(cell_pos)
		#elif not modifiable_paths.is_empty(): # Fallback to add if remove failed (no walls)
			#var cell_to_modify_idx = randi() % modifiable_paths.size()
			#var cell_pos: Vector2i = modifiable_paths.pop_at(cell_to_modify_idx)
			#await _warn_and_add_wall_at(cell_pos)
			#modifiable_walls.append(cell_pos)
		#else:
			## print("No more modifiable cells of either type.")
			#break # No more cells to modify
#
#func _remove_wall_at(matrix_pos: Vector2i):
	#if maze_matrix[matrix_pos.y][matrix_pos.x] == 1:
		#maze_matrix[matrix_pos.y][matrix_pos.x] = 0
		#var wall_removed = false
		#for child in get_children():
			#if child.is_in_group("wall_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos") == matrix_pos:
				#child.queue_free()
				#wall_removed = true
				#break
		#if wall_removed: print("Wall removed at matrix: ", matrix_pos)
		#
		#if floor_scene: # Add a floor tile where the wall was
			#var floor_instance = floor_scene.instantiate()
			#var instance_position = Vector2(matrix_pos.x * cell_size.x, matrix_pos.y * cell_size.y) + maze_offset
			#floor_instance.position = instance_position
			#floor_instance.set_meta("grid_pos", matrix_pos)
			#floor_instance.add_to_group("floor_tile")
			#add_child(floor_instance)
#
#func _warn_and_add_wall_at(matrix_pos: Vector2i) -> void:
	#var world_pos_top_left = Vector2(matrix_pos.x * cell_size.x, matrix_pos.y * cell_size.y) + maze_offset
	#var warning_instance = null
#
	#if warning_effect_scene:
		#warning_instance = warning_effect_scene.instantiate()
		#warning_instance.position = world_pos_top_left + cell_size / 2.0 # Center it
		#warning_instance.add_to_group("persistent_effect") # So it's not cleared by _draw_maze
		#add_child(warning_instance)
	#else: # Fallback simple visual
		#var color_rect = ColorRect.new()
		#color_rect.color = Color(1, 0.8, 0, 0.4) # Orangey warning
		#color_rect.size = cell_size
		#color_rect.position = world_pos_top_left
		#color_rect.add_to_group("persistent_effect")
		#add_child(color_rect)
		#warning_instance = color_rect
	#print("WARNING: Wall appearing at matrix: ", matrix_pos)
#
	#var timer = get_tree().create_timer(wall_warning_duration)
	#await timer.timeout
#
	#if is_instance_valid(warning_instance): # Check if it wasn't somehow removed
		#warning_instance.queue_free()
#
	#var player_crushed = false
	#if player_node != null and is_instance_valid(player_node):
		#var player_relative_pos = player_node.global_position - maze_offset
		#var player_grid_x = floor(player_relative_pos.x / cell_size.x)
		#var player_grid_y = floor(player_relative_pos.y / cell_size.y)
		#if Vector2i(player_grid_x, player_grid_y) == matrix_pos:
			#player_crushed = true
#
	#if player_crushed:
		#print("PLAYER CRUSHED at matrix: ", matrix_pos, " by new wall!")
		## Implement player crush effect (e.g., emit signal, call player method)
		## For now, simple reload:
		#get_tree().reload_current_scene() 
		#return # Stop further execution if player is crushed and scene reloads
#
	## Proceed to add the wall if player not crushed or if crush doesn't stop wall placement
	#if maze_matrix[matrix_pos.y][matrix_pos.x] == 0: # Check if it's still a path
		#maze_matrix[matrix_pos.y][matrix_pos.x] = 1
		#
		## Remove any floor tile at this position
		#for child in get_children():
			#if child.is_in_group("floor_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos") == matrix_pos:
				#child.queue_free()
				#break
		#
		#if wall_scene:
			#var wall_instance = wall_scene.instantiate()
			#wall_instance.position = world_pos_top_left
			#wall_instance.set_meta("grid_pos", matrix_pos)
			#wall_instance.add_to_group("wall_tile")
			#add_child(wall_instance)
			#print("Wall added at matrix: ", matrix_pos)
#
## --- Godot Lifecycle and Public Methods ---
#func _ready():
	#randomize()
	#generate_and_draw()
	#_spawn_player_at_entrance()
	#
	## Example: Trigger wall modification after a delay for testing
	#var test_timer = get_tree().create_timer(5.0) # Wait 5 seconds
	#await test_timer.timeout
	#modify_random_walls() # Call the new function
#
#func generate_and_draw():
	#_generate_maze_matrix()
	#_draw_maze()
#
#func get_maze_matrix() -> Array: return maze_matrix
#func get_cell_type(x: int, y: int) -> int:
	#if y >= 0 and y < maze_matrix.size() and x >= 0 and x < maze_matrix[y].size():
		#return maze_matrix[y][x]
	#return -1
#func get_player_start_world_position() -> Vector2:
	#if entrance_matrix_pos != null:
		#return Vector2(entrance_matrix_pos.x * cell_size.x + maze_offset.x + cell_size.x / 2.0, \
					   #entrance_matrix_pos.y * cell_size.y + maze_offset.y + cell_size.y / 2.0)
	#return Vector2.ZERO
#func get_entrance_matrix_position() -> Vector2i: return entrance_matrix_pos
#func get_exit_matrix_position() -> Vector2i: return exit_matrix_pos

# MazeGenerator.gd
extends Node2D

# Preload your scenes for walls and floors
@export var wall_scene: PackedScene
@export var floor_scene: PackedScene # Optional
@export var player_scene: PackedScene # For spawning the player
@export var warning_effect_scene: PackedScene # Optional: Scene for wall warning visual

# Define the size of each logical grid cell in pixels.
@export var cell_size: Vector2 = Vector2(40, 40)

# Maze dimensions (number of cells) - should be odd and ideally >= 5 for interesting modifications
@export var maze_width: int = 21
@export var maze_height: int = 15

# Offset for the entire maze's top-left corner from this Node2D's origin
@export var maze_offset: Vector2 = Vector2(20, 15)

# Duration for the warning before a wall appears
@export var wall_warning_duration: float = 2.0 # seconds
@export var wall_modification_interval: float = 3.0 # seconds between modifications

var maze_matrix: Array = []
var entrance_matrix_pos: Vector2i
var exit_matrix_pos: Vector2i
var player_node: Node2D = null # Reference to the player instance

# --- Maze Generation Algorithm (Recursive Backtracker) ---
func _generate_maze_matrix():
	maze_matrix.clear()

	if maze_width < 5: maze_width = 5
	if maze_height < 5: maze_height = 5
	if maze_width % 2 == 0: maze_width += 1
	if maze_height % 2 == 0: maze_height += 1

	for y in range(maze_height):
		var row: Array = []
		for x in range(maze_width): row.append(1)
		maze_matrix.append(row)

	var stack: Array = []
	var current_cell: Vector2i = Vector2i(1, 1)
	maze_matrix[current_cell.y][current_cell.x] = 0
	
	var path_cells_x = (maze_width - 1) / 2
	var path_cells_y = (maze_height - 1) / 2
	var total_potential_path_cells: int = path_cells_x * path_cells_y
	var visited_path_cells: int = 1
	stack.push_back(current_cell)

	while visited_path_cells < total_potential_path_cells and not stack.is_empty():
		var neighbors: Array = []
		var cx: int = current_cell.x
		var cy: int = current_cell.y

		if cy - 2 >= 1 and maze_matrix[cy - 2][cx] == 1: neighbors.append(Vector2i(cx, cy - 2))
		if cy + 2 < maze_height - 1 and maze_matrix[cy + 2][cx] == 1: neighbors.append(Vector2i(cx, cy + 2))
		if cx - 2 >= 1 and maze_matrix[cy][cx - 2] == 1: neighbors.append(Vector2i(cx - 2, cy))
		if cx + 2 < maze_width - 1 and maze_matrix[cy][cx + 2] == 1: neighbors.append(Vector2i(cx + 2, cy))

		if not neighbors.is_empty():
			var next_cell: Vector2i = neighbors.pick_random()
			stack.push_back(current_cell)
			maze_matrix[next_cell.y][next_cell.x] = 0
			var wall_to_remove_x = current_cell.x + (next_cell.x - current_cell.x) / 2
			var wall_to_remove_y = current_cell.y + (next_cell.y - current_cell.y) / 2
			maze_matrix[wall_to_remove_y][wall_to_remove_x] = 0
			current_cell = next_cell
			visited_path_cells += 1
		elif not stack.is_empty():
			current_cell = stack.pop_back()
		else: break
	_create_random_entrance_exit()

func _create_random_entrance_exit():
	var valid_y_indices_for_edges = []
	for i in range(1, maze_height - 1, 2): valid_y_indices_for_edges.append(i)
	var valid_x_indices_for_edges = []
	for i in range(1, maze_width - 1, 2): valid_x_indices_for_edges.append(i)

	if valid_y_indices_for_edges.is_empty() or valid_x_indices_for_edges.is_empty():
		push_error("Maze dimensions too small for random entrance/exit.")
		entrance_matrix_pos = Vector2i(0, 1)
		exit_matrix_pos = Vector2i(maze_width - 1, maze_height - 2)
		if maze_matrix.size() > 1 and maze_matrix[0].size() > 0: maze_matrix[1][0] = 0 # Check bounds
		if maze_height - 2 >=0 and maze_width - 1 >=0 and \
		   maze_matrix.size() > maze_height - 2 and maze_matrix[0].size() > maze_width -1: # Check bounds
			maze_matrix[maze_height - 2][maze_width - 1] = 0
		return

	var edge_choice = randi() % 2
	if edge_choice == 0: # Left/Right
		entrance_matrix_pos.y = valid_y_indices_for_edges.pick_random()
		entrance_matrix_pos.x = 0
		exit_matrix_pos.y = valid_y_indices_for_edges.pick_random()
		exit_matrix_pos.x = maze_width - 1
	else: # Top/Bottom
		entrance_matrix_pos.x = valid_x_indices_for_edges.pick_random()
		entrance_matrix_pos.y = 0
		exit_matrix_pos.x = valid_x_indices_for_edges.pick_random()
		exit_matrix_pos.y = maze_height - 1

	maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x] = 0
	maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x] = 0

func _draw_maze():
	for child in get_children():
		if not child.is_in_group("player") and \
		   not child.is_in_group("persistent_effect") and \
		   not child is Timer: # Don't remove the WallModificationTimer
			child.queue_free()

	if maze_matrix.is_empty():
		printerr("Maze matrix is empty.")
		return

	for y in range(maze_matrix.size()):
		for x in range(maze_matrix[y].size()):
			var cell_type = maze_matrix[y][x]
			var instance_position = Vector2(x * cell_size.x, y * cell_size.y) + maze_offset
			var grid_pos = Vector2i(x,y)

			if cell_type == 1: # Wall
				if wall_scene:
					var wall_instance = wall_scene.instantiate()
					wall_instance.position = instance_position
					wall_instance.set_meta("grid_pos", grid_pos)
					wall_instance.add_to_group("wall_tile")
					add_child(wall_instance)
			elif cell_type == 0: # Path
				if floor_scene:
					var floor_instance = floor_scene.instantiate()
					floor_instance.position = instance_position
					floor_instance.set_meta("grid_pos", grid_pos)
					floor_instance.add_to_group("floor_tile")
					add_child(floor_instance)

func _spawn_player_at_entrance():
	if not player_scene:
		print("Player scene not set. Player will not be spawned.")
		return
	if entrance_matrix_pos == null: # Should ideally be initialized.
		printerr("Entrance position not determined. Cannot spawn player.")
		return

	var player_instance = player_scene.instantiate()
	var world_x = entrance_matrix_pos.x * cell_size.x + maze_offset.x + cell_size.x / 2.0
	var world_y = entrance_matrix_pos.y * cell_size.y + maze_offset.y + cell_size.y / 2.0
	player_instance.global_position = Vector2(world_x, world_y)
	player_instance.add_to_group("player")
	self.player_node = player_instance

	if get_parent():
		get_parent().call_deferred("add_child", player_instance)
	else:
		call_deferred("add_child", player_instance)

func modify_random_walls():
	if player_node == null or not is_instance_valid(player_node):
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty(): self.player_node = players[0]
	
	var modifiable_paths = []
	var modifiable_walls = []
	for y in range(1, maze_height - 1):
		for x in range(1, maze_width - 1):
			var current_grid_pos = Vector2i(x,y)
			if current_grid_pos == entrance_matrix_pos or current_grid_pos == exit_matrix_pos:
				continue
			if maze_matrix[y][x] == 0: modifiable_paths.append(current_grid_pos)
			else: modifiable_walls.append(current_grid_pos)

	if modifiable_paths.is_empty() and modifiable_walls.is_empty():
		# print("No internal cells available for modification this cycle.")
		return

	var num_changes = randi_range(1, 3)
	# print("Attempting to make %d wall modifications." % num_changes)

	for i in range(num_changes):
		var action_type = randi() % 2
		if action_type == 0 and not modifiable_walls.is_empty():
			var cell_pos: Vector2i = modifiable_walls.pop_at(randi() % modifiable_walls.size())
			_remove_wall_at(cell_pos)
			modifiable_paths.append(cell_pos)
		elif action_type == 1 and not modifiable_paths.is_empty():
			var cell_pos: Vector2i = modifiable_paths.pop_at(randi() % modifiable_paths.size())
			await _warn_and_add_wall_at(cell_pos)
			modifiable_walls.append(cell_pos)
		elif not modifiable_walls.is_empty():
			var cell_pos: Vector2i = modifiable_walls.pop_at(randi() % modifiable_walls.size())
			_remove_wall_at(cell_pos)
			modifiable_paths.append(cell_pos)
		elif not modifiable_paths.is_empty():
			var cell_pos: Vector2i = modifiable_paths.pop_at(randi() % modifiable_paths.size())
			await _warn_and_add_wall_at(cell_pos)
			modifiable_walls.append(cell_pos)
		else: break

func _remove_wall_at(matrix_pos: Vector2i):
	if maze_matrix[matrix_pos.y][matrix_pos.x] == 1:
		maze_matrix[matrix_pos.y][matrix_pos.x] = 0
		var wall_removed = false
		for child in get_children():
			if child.is_in_group("wall_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos") == matrix_pos:
				child.queue_free()
				wall_removed = true
				break
		# if wall_removed: print("Wall removed at matrix: ", matrix_pos)
		
		if floor_scene:
			var floor_instance = floor_scene.instantiate()
			var instance_position = Vector2(matrix_pos.x * cell_size.x, matrix_pos.y * cell_size.y) + maze_offset
			floor_instance.position = instance_position
			floor_instance.set_meta("grid_pos", matrix_pos)
			floor_instance.add_to_group("floor_tile")
			add_child(floor_instance)

func _warn_and_add_wall_at(matrix_pos: Vector2i) -> void:
	var world_pos_top_left = Vector2(matrix_pos.x * cell_size.x, matrix_pos.y * cell_size.y) + maze_offset
	var warning_instance = null

	if warning_effect_scene:
		warning_instance = warning_effect_scene.instantiate()
		warning_instance.position = world_pos_top_left + cell_size / 2.0
		warning_instance.add_to_group("persistent_effect")
		add_child(warning_instance)
	else:
		var color_rect = ColorRect.new()
		color_rect.color = Color(1, 0.8, 0, 0.4)
		color_rect.size = cell_size
		color_rect.position = world_pos_top_left
		color_rect.add_to_group("persistent_effect")
		add_child(color_rect)
		warning_instance = color_rect
	# print("WARNING: Wall appearing at matrix: ", matrix_pos)

	var timer = get_tree().create_timer(wall_warning_duration)
	await timer.timeout

	if is_instance_valid(warning_instance):
		warning_instance.queue_free()

	var player_crushed = false
	if player_node != null and is_instance_valid(player_node):
		var player_relative_pos = player_node.global_position - maze_offset
		var player_grid_x = floor(player_relative_pos.x / cell_size.x)
		var player_grid_y = floor(player_relative_pos.y / cell_size.y)
		if Vector2i(player_grid_x, player_grid_y) == matrix_pos:
			player_crushed = true

	if player_crushed:
		print("PLAYER CRUSHED at matrix: ", matrix_pos, " by new wall!")
		get_tree().reload_current_scene() # Cleaned trailing space
		return

	if maze_matrix[matrix_pos.y][matrix_pos.x] == 0:
		maze_matrix[matrix_pos.y][matrix_pos.x] = 1
		for child in get_children():
			if child.is_in_group("floor_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos") == matrix_pos:
				child.queue_free()
				break
		
		if wall_scene:
			var wall_instance = wall_scene.instantiate()
			wall_instance.position = world_pos_top_left
			wall_instance.set_meta("grid_pos", matrix_pos)
			wall_instance.add_to_group("wall_tile")
			add_child(wall_instance)
			# print("Wall added at matrix: ", matrix_pos)

func _ready():
	randomize()
	generate_and_draw()
	_spawn_player_at_entrance()
	
	if wall_modification_interval > 0:
		var wall_mod_timer = Timer.new()
		wall_mod_timer.name = "WallModificationTimer"
		wall_mod_timer.wait_time = wall_modification_interval
		# Timer repeats by default (one_shot is false by default)
		wall_mod_timer.connect("timeout", Callable(self, "modify_random_walls"))
		add_child(wall_mod_timer) # Important: Add timer to scene tree so it processes
		wall_mod_timer.start()
	else:
		print("Wall modification interval is 0 or less, dynamic walls disabled.")

func generate_and_draw():
	_generate_maze_matrix()
	_draw_maze()

func get_maze_matrix() -> Array: return maze_matrix
func get_cell_type(x_coord: int, y_coord: int) -> int: # Renamed parameters for clarity
	if y_coord >= 0 and y_coord < maze_matrix.size() and \
	   x_coord >= 0 and x_coord < maze_matrix[y_coord].size():
		return maze_matrix[y_coord][x_coord]
	return -1

func get_player_start_world_position() -> Vector2:
	if entrance_matrix_pos != null: # Check if initialized
		var world_x = entrance_matrix_pos.x * cell_size.x + maze_offset.x + cell_size.x / 2.0
		var world_y = entrance_matrix_pos.y * cell_size.y + maze_offset.y + cell_size.y / 2.0
		return Vector2(world_x, world_y)
	return Vector2.ZERO

func get_entrance_matrix_position() -> Vector2i: return entrance_matrix_pos
func get_exit_matrix_position() -> Vector2i: return exit_matrix_pos
