extends Node2D
@onready var tilemaplayer = $TileMap
@export var relicScene : PackedScene
# Constants
const ROWS = 25    
const COLS = 25
const WALL = Vector2i(8, 0)
const PATH = Vector2i(9, 0)
const EXIT = Vector2i(10, 0)
const WIN_TILE = Vector2i(11, 0)  # Special tile for win condition
const ENEMY_START_TILE = Vector2i(3,1) # Or choose another starting corner/logic

# Variables
var maze = []
var maze_change_timer = 0.0
var maze_change_interval = 3.0 # How often difficulty increases
var wall_shift_timer = 0.0
var wall_shift_interval = 8.0
var shifting_walls = []
var difficulty_level = 10# User set this, will now directly influence maze complexity
var exit_position: Vector2i
var player_reached_exit = false
var player : CharacterBody2D = null
var enemy_instance : CharacterBody2D = null
var camera : Camera2D = null

var pause : Button =  null
var quit : Button = null

var game_timer = 0.0
var time_limit = 30.0 # User set this
var player_dead = false

var timer_display_label: Label = null


var transition_screen: ColorRect = null
var win_tile_highlight: Sprite2D = null  # Sprite to highlight win tile
var win_tile_tween: Tween = null  # For animation

var relic : Node2D = null

# Core Functions
func _ready() -> void:
	randomize()

	initialize_maze() # Then initialize the maze and timer values
	pause = get_node_or_null("Player/Camera2D/Control/Pause")
	quit = get_node_or_null("Player/Camera2D/Control/Quit")

	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	quit.process_mode = Node.PROCESS_MODE_ALWAYS
	
	player = get_node_or_null("Player")
	camera = get_node_or_null("Player/Camera2D")
	
	setup_timer_display() # Call this first to ensure the label exists
	#add_child(heart_beat)
	
	
# --- Enemy Initialization (assuming enemy is pre-placed in the scene) ---
	enemy_instance = get_node_or_null("Enemy") # Get the enemy node if it exists in the scene

	if is_instance_valid(enemy_instance):
		var enemy_start_pos_tile = ENEMY_START_TILE
		if maze.size() > enemy_start_pos_tile.y and maze[enemy_start_pos_tile.y].size() > enemy_start_pos_tile.x:
			if maze[enemy_start_pos_tile.y][enemy_start_pos_tile.x] == 1: # If default is a wall
				var found_start = false
				for r in range(1, ROWS-1):
					for c in range(1, COLS-1):
						if maze[r][c] == 0: # Path
							enemy_start_pos_tile = Vector2i(c,r)
							found_start = true
							break
					if found_start: break
				if not found_start:
					printerr("Could not find a valid start tile for the enemy!")
					enemy_start_pos_tile = Vector2i(1,1) # Fallback
		else:
			printerr("Maze not initialized or too small for default enemy start tile.")
			enemy_start_pos_tile = Vector2i(1,1) # Fallback

		if enemy_instance.has_method("setup_ai"):
			# Crucially, tilemaplayer's scale and position are set by fit_maze_to_screen() in initialize_maze()
			# So, setup_ai must use these transformed coordinates.
			enemy_instance.setup_ai(maze, tilemaplayer, enemy_start_pos_tile, exit_position)
			if not enemy_instance.enemy_reached_exit.is_connected(_on_enemy_reached_exit):
				enemy_instance.enemy_reached_exit.connect(_on_enemy_reached_exit)
		else:
			printerr("Enemy instance found at 'Enemy' does not have 'setup_ai' method!")
	else:
		printerr("Enemy node not found at path 'Enemy'. Ensure it's in the scene and named correctly.")
	# --- End Enemy Initialization ---
	
		# --- Relic Initialization ---
	if relicScene: # Check if a scene was actually assigned in the editor
		relic = relicScene.instantiate()
		if relic:
			add_child(relic) # Crucial: Add the relic instance to the current scene tree
			
			# Position the relic correctly.
			# exit_position is in tilemap coordinates. We need to convert it to world space.
			# tilemaplayer.map_to_local() converts tile coords to position local to the tilemap.
			# We then add half a tile size to center it on the tile.
			# Finally, tilemaplayer.to_global() converts that tilemap-local position to world space.
			
			var relic_local_to_tilemap_pos = tilemaplayer.map_to_local(exit_position)
			var relic_world_pos = tilemaplayer.to_global(relic_local_to_tilemap_pos)
			
			relic.global_position = relic_world_pos # Set its global position
			
			print("Relic instantiated, added to scene, and positioned at: ", relic.global_position)
		else:
			printerr("Failed to instantiate relic scene!")
	else:
		printerr("RelicScene not assigned in the Inspector for this node!")
	# --- End Relic Initialization ---


func _process(delta: float) -> void:
	# If the player is dead, simply stop processing game logic for this frame.
	# The game over label and exit timer are handled in player_dies().
	if player_dead:
		return

	# Handle progressive difficulty changes within the current maze
	handle_difficulty_ramp(delta)
	handle_wall_shifts(delta)
	game_timer += delta
	update_timer_display() # This updates the label with "Time: 00:00"
	
	
	 
	# Robust check for time running out
	# Use floor() to handle slight floating point inaccuracies and ensure it triggers at 0 seconds
	if floor(time_limit - game_timer) <= 0:
		player_dies()
		return # Essential: stop further processing once player_dies() is called

# Update your initialize_maze function to call initialize_enemy properly
func initialize_maze():
	reset_maze()
	generate_maze()
	game_timer = 0.0 
	time_limit = max(1.0, 60)
	player_dead = false 
	player_reached_exit = false 
	if timer_display_label:
		timer_display_label.show() 
		update_timer_display() 
	maze_change_timer = 0.0
	
	# Draw maze and set exit first
	draw_maze()
	set_exit_position()
	
	# Then initialize enemy with the complete maze
	initialize_enemy()
	
	# Finally fit to screen
	fit_maze_to_screen()


func reset_maze():
	maze = []
	for r in range(ROWS):
		var row = []
		for c in range(COLS):
			row.append(1)  # 1 = wall, 0 = path
		maze.append(row)

func generate_maze():
	var complexity = min(difficulty_level, 5)

	# Set starting points for maze generation
	var start_points = get_start_points(complexity)

	# Generate paths using recursive backtracking
	for start in start_points:
		maze[start.x][start.y] = 0
		carve_passage(start.x, start.y)

	# Add complexity features based on difficulty
	if complexity >= 2: create_maze_rooms()
	if complexity >= 4: add_challenging_loops()
	add_random_paths(complexity)

	# Finalize maze setup
	mark_shifting_walls()
	draw_maze()
	set_exit_position()

func carve_passage(row, col):
	var directions = [[-2, 0], [0, 2], [2, 0], [0, -2]]  # Up, Right, Down, Left (2 steps to ensure walls between paths)
	directions.shuffle() # Randomize carving direction

	for dir in directions:
		var new_row = row + dir[0]
		var new_col = col + dir[1]

		# Check if the new cell is valid and unvisited (a wall)
		if is_valid_cell(new_row, new_col) and maze[new_row][new_col] == 1:
			maze[new_row][new_col] = 0 # Mark the new cell as a path
			maze[row + dir[0]/2][col + dir[1]/2] = 0 # Mark the cell between as a path
			carve_passage(new_row, new_col) # Recursively carve from the new cell

# Maze Features
func create_maze_rooms():
	var room_count = randi_range(2, 4)
	for _i in range(room_count):
		var room_size = randi_range(3, 5) # Rooms can be 3x3 to 5x5
		# Ensure room is within maze bounds
		var room_r = randi_range(2, ROWS - room_size - 2)
		var room_c = randi_range(2, COLS - room_size - 2)

		for r in range(room_r, room_r + room_size):
			for c in range(room_c, room_c + room_size):
				if is_valid_cell(r, c):
					maze[r][c] = 0 # Carve out the room

func add_challenging_loops():
	var loop_count = randi_range(3, 6)
	for _i in range(loop_count):
		var r = randi_range(2, ROWS - 3)
		var c = randi_range(2, COLS - 3)

		# Attempt to create a loop by breaking a wall if adjacent paths exist
		if maze[r][c] == 1 and maze[r+2][c] == 0 and maze[r][c+2] == 0:
			maze[r+1][c] = 0
			maze[r][c+1] = 0

func add_random_paths(complexity):
	var extra_paths = randi_range(2 + complexity, 8 + complexity * 2)
	for _i in range(extra_paths):
		var r = randi_range(1, ROWS - 2)
		var c = randi_range(1, COLS - 2)

		# Only convert a wall to a path if it has enough adjacent paths to connect to
		if maze[r][c] == 1 and count_adjacent_paths(r, c) >= max(1, 3 - complexity):
			maze[r][c] = 0

# Wall Shifting System
func mark_shifting_walls():
	shifting_walls.clear()
	for r in range(2, ROWS - 2):
		for c in range(2, COLS - 2):
			# A wall is considered 'shifting' if it has 2 or 3 adjacent paths,
			# making it a potential candidate for temporary opening.
			if maze[r][c] == 1 and count_adjacent_paths(r, c) in [2, 3]:
				shifting_walls.append(Vector2i(r, c))

func shift_random_walls():
	if shifting_walls.is_empty(): return

	# Determine how many walls to shift based on difficulty
	var walls_to_shift = min(1 + difficulty_level / 2, shifting_walls.size())
	var walls_shifted = []

	for _i in range(walls_to_shift):
		var wall_pos = shifting_walls.pick_random()
		maze[wall_pos.x][wall_pos.y] = 0 # Temporarily convert wall to path
		# Update TileMap visually
		tilemaplayer.set_cell(0, Vector2i(wall_pos.y, wall_pos.x), 1, PATH)
		walls_shifted.append(wall_pos)

	# Set a timer to restore the shifted walls after a short delay
	get_tree().create_timer(randf_range(3.0, 5.0)).timeout.connect(
		func(): _restore_shifted_walls(walls_shifted)
	)
	# Notify enemy about maze change
	if is_instance_valid(enemy_instance) and enemy_instance.has_method("maze_changed_replan"):
		enemy_instance.maze_changed_replan(maze) # Pass the updated maze data

	get_tree().create_timer(randf_range(3.0, 5.0)).timeout.connect(
		func(): _restore_shifted_walls(shifting_walls) # Pass the correct list
	)

func _restore_shifted_walls(walls: Array):
	for wall_pos in walls:
		maze[wall_pos.x][wall_pos.y] = 1 # Convert path back to wall
		# Update TileMap visually
		tilemaplayer.set_cell(0, Vector2i(wall_pos.y, wall_pos.x), 1, WALL)
		# Notify enemy about maze change again
	if is_instance_valid(enemy_instance) and enemy_instance.has_method("maze_changed_replan"):
		enemy_instance.maze_changed_replan(maze)

# Add this function to your main game script to find a better enemy spawn position
func find_valid_enemy_spawn() -> Vector2i:
	# Try to find a spawn position that's not too close to the player or exit
	var valid_spawns = []
	
	# Look for path tiles that are at least 3 tiles away from edges
	for r in range(3, ROWS - 3):
		for c in range(3, COLS - 3):
			if maze[r][c] == 0: # Path tile
				var spawn_pos = Vector2i(c, r)
				# Check if it's not too close to exit
				if spawn_pos.distance_to(exit_position) > 5:
					valid_spawns.append(spawn_pos)
	
	if valid_spawns.is_empty():
		# Fallback: any path tile will do
		for r in range(1, ROWS - 1):
			for c in range(1, COLS - 1):
				if maze[r][c] == 0:
					valid_spawns.append(Vector2i(c, r))
	
	if valid_spawns.is_empty():
		# Force create a spawn point
		var fallback_pos = Vector2i(1, 1)
		maze[fallback_pos.y][fallback_pos.x] = 0
		return fallback_pos
	
	return valid_spawns.pick_random()

# Replace the enemy initialization section in your _ready() function with this:
func initialize_enemy():
	enemy_instance = get_node_or_null("Enemy")
	
	if is_instance_valid(enemy_instance):
		# Find a valid spawn position
		var enemy_start_pos_tile = find_valid_enemy_spawn()
		
		print("Enemy spawn position: ", enemy_start_pos_tile)
		
		if enemy_instance.has_method("setup_ai"):
			enemy_instance.setup_ai(maze, tilemaplayer, enemy_start_pos_tile, exit_position)
			if not enemy_instance.enemy_reached_exit.is_connected(_on_enemy_reached_exit):
				enemy_instance.enemy_reached_exit.connect(_on_enemy_reached_exit)
		else:
			printerr("Enemy instance found but does not have 'setup_ai' method!")
	else:
		printerr("Enemy node not found. Ensure it's in the scene and named correctly.")


# Display Functions
func draw_maze():
	tilemaplayer.clear() # Clear existing tiles

	for r in range(ROWS):
		for c in range(COLS):
			var tile = WALL if maze[r][c] == 1 else PATH
			tilemaplayer.set_cell(0, Vector2i(c, r), 1, tile) # Set cell on TileMap

	# Redraw exit in case it was overwritten during drawing
	if exit_position:
		tilemaplayer.set_cell(0, exit_position, 1, EXIT)

func fit_maze_to_screen():
	var screen_size = get_viewport().get_visible_rect().size
	var tile_size = 16 # Assuming your tile size is 16x16 pixels
	var maze_size = Vector2(COLS, ROWS) * tile_size

	# Calculate scale to fit the maze within 90% of the screen
	var scale = min(
		(screen_size.x * 0.9) / maze_size.x,
		(screen_size.y * 0.9) / maze_size.y
	)

	tilemaplayer.scale = Vector2(scale, scale)
	# Center the scaled maze on the screen
	tilemaplayer.position = (screen_size - maze_size * scale) / 2

# Game Logic
func set_exit_position():
	# Define a region in the bottom-right corner for the exit
	var bottom_right_rows = range(ROWS - 5, ROWS - 2)
	var bottom_right_cols = range(COLS - 5, COLS - 2)

	bottom_right_rows.shuffle()
	bottom_right_cols.shuffle()

	# Find the first available path cell in the bottom-right region
	for r in bottom_right_rows:
		for c in bottom_right_cols:
			if maze[r][c] == 0:
				exit_position = Vector2i(c, r)
				tilemaplayer.set_cell(0, exit_position, 1, EXIT)
				return

	# Fallback: if no suitable spot found, force the bottom-right corner
	exit_position = Vector2i(COLS - 2, ROWS - 2)
	if maze[exit_position.y][exit_position.x] == 1:
		maze[exit_position.y][exit_position.x] = 0 # Ensure it's a path
	tilemaplayer.set_cell(0, exit_position, 1, EXIT)


func handle_win_condition():
	print("Level Complete! Difficulty: ", difficulty_level)
	if timer_display_label:
		timer_display_label.hide() # Hide the timer when the win message is displayed

	var win_label = Label.new()
	win_label.text = "LEVEL COMPLETE!"
	# Center the label on the screen
	#win_label.position = get_viewport().get_visible_rect().size / 2 - win_label.size / 2
	win_label.add_theme_font_size_override("font_size", 14)
	camera.add_child(win_label)

	get_tree().create_timer(2.0).timeout.connect(
		func():
			if is_instance_valid(win_label): # Safety check
				win_label.queue_free() # Remove the win message
			difficulty_level += 1 # Increase difficulty
			
			var level_2_scene = "res://contiune.tscn"
			var error = get_tree().change_scene_to_file(level_2_scene)
	)

func player_dies():
	player_dead = true # Set the player_dead flag
	print("GAME OVER! Time ran out. Exiting game.") # Confirm this prints in console output

	# Stop enemy if player dies
	if is_instance_valid(enemy_instance):
		enemy_instance.set_physics_process(false)
		
	if timer_display_label:
		timer_display_label.hide() # Hide the countdown timer label
	var success : AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		
	add_child(success)
	success.stream =  load("res://man-death-scream-186763.mp3")
	success.playing = true
	var game_over_label = Label.new()
	game_over_label.text = "GAME OVER!"
	game_over_label.add_theme_font_size_override("font_size", 34)

	# Ensure the label is clearly visible and perfectly centered
	game_over_label.set_modulate(Color("red")) # Make it red for high visibility
	game_over_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER) # Center it properly using anchors
	game_over_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER) # Ensure text is centered within the label's rect
	game_over_label.set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER) # Ensure text is centered vertically within the label's rect

	camera.add_child(game_over_label) # Add the game over label to the scene

	# You might want to stop the player's movement or hide them here as well
	# For example, if your player node is named "Player" and it's a child of this Node2D:
	# var player_node = get_node_or_null("Player")
	# if player_node:
	#     player_node.hide() # Hide the player character visually
	#     player_node.set_process(false) # Stop its _process updates
	player.set_physics_process(false) # Stop its _physics_process updates

	# Set a timer to wait for 3 seconds, then remove the label and quit the game
	get_tree().create_timer(3.0).timeout.connect(
		func():
			if is_instance_valid(game_over_label): # Check if it's still valid before queueing free
				game_over_label.queue_free() # Remove the "GAME OVER!" message
			var start_scene_path = "res://start_menu.tscn"
			get_tree().change_scene_to_file(start_scene_path)
			
	)

# Helper Functions
# New function to handle when the enemy reaches the exit
func _on_enemy_reached_exit() -> void:
	if player_dead or player_reached_exit: # If player already lost or won, do nothing
		return

	print("Enemy reached the exit first! Player loses.")
	# You can customize the "enemy wins" message or screen
	# For now, let's just call player_dies with a specific message potentially later
	# or trigger a unique "enemy won" screen.
	
	# We'll use the player_dies function but you might want a different label
	player_dead = true # Mark player as effectively dead/lost
	if is_instance_valid(player):
		player.set_physics_process(false) # Stop player movement

	if timer_display_label:
		timer_display_label.hide()

	var enemy_won_label = Label.new()
	enemy_won_label.text = "DEFEAT! THE ENEMY WON!"
	enemy_won_label.add_theme_font_size_override("font_size", 28) # Slightly smaller than game over
	enemy_won_label.modulate = Color.ORANGE_RED
	
	if is_instance_valid(camera):
		enemy_won_label.global_position = camera.get_screen_center_position()
		enemy_won_label.pivot_offset = enemy_won_label.size / 2.0
		camera.add_child(enemy_won_label)
	else:
		enemy_won_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		add_child(enemy_won_label)

	get_tree().create_timer(3.0).timeout.connect(
		func():
			if is_instance_valid(enemy_won_label):
				enemy_won_label.queue_free()
			var start_scene_path = "res://start_menu.tscn"
			get_tree().change_scene_to_file(start_scene_path)
	)

func get_start_points(complexity) -> Array:
	if complexity >= 3:
		# Multiple start points for higher complexity
		return [Vector2i(1, 1), Vector2i(ROWS-2, 1), Vector2i(1, COLS-2)]
	else:
		# Single random start point for lower complexity
		return [Vector2i(
			randi_range(1, 3) * 2 - 1,
			randi_range(1, 3) * 2 - 1
		)]

func is_valid_cell(r, c) -> bool:
	return r > 0 and r < ROWS - 1 and c > 0 and c < COLS - 1

func count_adjacent_paths(r, c) -> int:
	# Count how many adjacent cells are paths (value 0)
	return int(maze[r-1][c] == 0) + int(maze[r+1][c] == 0) + \
		   int(maze[r][c-1] == 0) + int(maze[r][c+1] == 0)

# Renamed from handle_maze_changes to clarify its purpose
func handle_difficulty_ramp(delta: float):
	maze_change_timer += delta
	if maze_change_timer >= maze_change_interval:
		# Only increase difficulty and reset this specific timer
		# This makes the current maze harder, but doesn't restart the game
		difficulty_level += 1
		print("Difficulty increased! Current level: ", difficulty_level)
		maze_change_timer = 0.0
		# Adjust interval for next difficulty increase
		maze_change_interval = max(15.0, 25.0 - (difficulty_level * 1.5))

func handle_wall_shifts(delta: float):
	wall_shift_timer += delta
	if wall_shift_timer >= wall_shift_interval:
		shift_random_walls() # Trigger wall shifting
		wall_shift_timer = 0.0
		# Adjust interval for wall shifts, faster with higher difficulty
		wall_shift_interval = max(4.0, 8.0 - (difficulty_level * 0.5))
# Timer Display Functions
func setup_timer_display():
	if timer_display_label == null or not is_instance_valid(timer_display_label):
		timer_display_label = Label.new()
		if is_instance_valid(camera):
			camera.add_child(timer_display_label)
		else:
			add_child(timer_display_label)
	elif is_instance_valid(camera) and timer_display_label.get_parent() != camera:
		timer_display_label.reparent(camera)
	elif not is_instance_valid(camera) and timer_display_label.get_parent() != self:
		timer_display_label.reparent(self)

	if is_instance_valid(timer_display_label):
		timer_display_label.add_theme_font_size_override("font_size", 10)
		timer_display_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT) 
		timer_display_label.position = Vector2(30, -30)
		timer_display_label.set_modulate(Color("white"))
		
		timer_display_label.show()


func update_timer_display():
	if is_instance_valid(timer_display_label) and not player_dead:
		var time_left = max(0.0, time_limit - game_timer)
		var minutes = floor(time_left / 60)
		var seconds = int(fmod(time_left, 60))
		if seconds <= 11:
			timer_display_label.set_modulate(Color("red"))
			
		timer_display_label.text = "Time: %02d:%02d" % [minutes, seconds]

# Transition Screen Function
func setup_transition_screen():
	transition_screen = ColorRect.new()
	transition_screen.color = Color(0, 0, 0, 0)
	transition_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_screen.set_z_index(200)
	add_child(transition_screen)

func _on_pause_pressed() -> void:
		pause.text = "Resume" if not get_tree().paused else "Pause"
		quit.visible = not get_tree().paused 
		get_tree().paused = not get_tree().paused

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://start_menu.tscn")
