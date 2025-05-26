# MazeGenerator.gd
extends Node2D

# Preload your scenes
@export var wall_scene: PackedScene
@export var floor_scene: PackedScene # Optional
@export var player_scene: PackedScene # For spawning the player
@export var enemy_scene: PackedScene # For spawning the enemy
@export var start_scene: PackedScene # For spawning the start
@export var end_scene: PackedScene # For spawning the end 
@export var warning_effect_scene: PackedScene # Optional: Scene for wall warning visual

# Define the size of each logical grid cell in pixels.
@export var cell_size: Vector2 = Vector2(40, 40)

# Maze dimensions
@export var maze_width: int = 21
@export var maze_height: int = 15

# Offset
@export var maze_offset: Vector2 = Vector2(20, 15)

# Dynamic Wall Settings
@export var wall_warning_duration: float = 2.0
@export var wall_modification_interval: float = 7.0

# Proximity Activation Settings
@export_category("Proximity Activation")
@export var proximity_activation_distance: float = 200.0 # Distance to enable/disable lights

@export_category("Enemy View Distance")
@export var proximity_enemy_1_distance: float = proximity_activation_distance - 50 # Distance to see enemy 

var maze_matrix: Array = []
var entrance_matrix_pos: Vector2i
var exit_matrix_pos: Vector2i
var player_node: Node2D = null
var start_node: Node2D = null
var end_node: Node2D = null


# Store data for proximity lights: [{light_node: Light2D, wall_node: Node2D}]
var proximity_lights_data: Array = []
# Store data for proximity enemies: [{enemy_node: Node2D}]
var proximity_enemies_data: Array = []


# --- Maze Generation (largely unchanged) ---
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
		var cx: int = current_cell.x; var cy: int = current_cell.y
		if cy - 2 >= 1 and maze_matrix[cy - 2][cx] == 1: neighbors.append(Vector2i(cx, cy - 2))
		if cy + 2 < maze_height - 1 and maze_matrix[cy + 2][cx] == 1: neighbors.append(Vector2i(cx, cy + 2))
		if cx - 2 >= 1 and maze_matrix[cy][cx - 2] == 1: neighbors.append(Vector2i(cx - 2, cy))
		if cx + 2 < maze_width - 1 and maze_matrix[cy][cx + 2] == 1: neighbors.append(Vector2i(cx + 2, cy))
		if not neighbors.is_empty():
			var next_cell: Vector2i = neighbors.pick_random()
			stack.push_back(current_cell)
			maze_matrix[next_cell.y][next_cell.x] = 0
			var wx = current_cell.x+(next_cell.x-current_cell.x)/2; var wy = current_cell.y+(next_cell.y-current_cell.y)/2
			maze_matrix[wy][wx] = 0
			current_cell = next_cell; visited_path_cells += 1
		elif not stack.is_empty(): current_cell = stack.pop_back()
		else: break
	_create_random_entrance_exit()

func _create_random_entrance_exit():
	var vy = []; for i in range(1,maze_height-1,2): vy.append(i)
	var vx = []; for i in range(1,maze_width-1,2): vx.append(i)
	if vy.is_empty() or vx.is_empty():
		push_error("Maze too small for random E/E."); entrance_matrix_pos=Vector2i(0,1); exit_matrix_pos=Vector2i(maze_width-1,maze_height-2)
		if maze_matrix.size()>1&&maze_matrix[0].size()>0:maze_matrix[1][0]=0
		if maze_height-2>=0&&maze_width-1>=0&&maze_matrix.size()>maze_height-2&&maze_matrix[0].size()>maze_width-1:maze_matrix[maze_height-2][maze_width-1]=0
		return
	var choice=randi()%2
	if choice==0: entrance_matrix_pos=Vector2i(0,vy.pick_random()); exit_matrix_pos=Vector2i(maze_width-1,vy.pick_random())
	else: entrance_matrix_pos=Vector2i(vx.pick_random(),0); exit_matrix_pos=Vector2i(vx.pick_random(),maze_height-1)
	maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x]=3; maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x]=2

func _draw_maze():
	# Clear existing maze elements, but not player, effects, or timers
	for c in get_children():
		if not c.is_in_group("player") and \
		   not c.is_in_group("enemy") and \
		   not c.is_in_group("persistent_effect") and \
		   not c is Timer: 
			c.queue_free()
	# Also clear proximity data as the visual elements are being redrawn
	proximity_lights_data.clear()
	# proximity_enemies_data is cleared when enemies are re-spawned or if _draw_maze implies full reset

	if maze_matrix.is_empty(): printerr("Maze matrix empty."); return
	for y in range(maze_matrix.size()):
		for x in range(maze_matrix[y].size()):
			var cell=maze_matrix[y][x]; var pos=Vector2(x*cell_size.x,y*cell_size.y)+maze_offset; var gp=Vector2i(x,y)
			if cell==1 and wall_scene: var wi=wall_scene.instantiate();wi.position=pos;wi.set_meta("grid_pos",gp);wi.add_to_group("wall_tile");add_child(wi)
			elif cell==0 and floor_scene: var fi=floor_scene.instantiate();fi.position=pos;fi.set_meta("grid_pos",gp);fi.add_to_group("floor_tile");add_child(fi)
			elif cell==2 and end_scene: var ei=end_scene.instantiate();ei.position=pos;ei.set_meta("grid_pos",gp);ei.add_to_group("end_tile");add_child(ei)
			elif cell==3 and start_scene: var si=start_scene.instantiate();si.position=pos;si.set_meta("grid_pos",gp);si.add_to_group("start_tile");add_child(si)

func _spawn_player_at_entrance():
	if not player_scene: print("Player scene not set."); return
	var pi=player_scene.instantiate(); var wx=entrance_matrix_pos.x*cell_size.x+maze_offset.x+cell_size.x/2.0
	var wy=entrance_matrix_pos.y*cell_size.y+maze_offset.y+cell_size.y/2.0
	pi.global_position=Vector2(wx,wy); pi.add_to_group("player"); self.player_node=pi
	if get_parent(): get_parent().call_deferred("add_child",pi)
	else: call_deferred("add_child",pi)

func _spawn_exit():
	if not end_scene: print("End scene not set."); return
	var ei=end_scene.instantiate()
	var wx=exit_matrix_pos.x*cell_size.x+cell_size.x/2.0
	var wy=exit_matrix_pos.y*cell_size.y+cell_size.y/2.0
	ei.global_position=Vector2(wx,wy); ei.add_to_group("end"); self.end_node=ei
	if get_parent(): get_parent().call_deferred("add_child",ei)
	else: call_deferred("add_child",ei)
	
func _spawn_start():
	if not start_scene: print("Start scene not set."); return
	var ei=start_scene.instantiate()
	var wx=entrance_matrix_pos.x*cell_size.x+cell_size.x/2.0
	var wy=entrance_matrix_pos.y*cell_size.y+cell_size.y/2.0
	ei.global_position=Vector2(wx,wy); ei.add_to_group("start"); self.start_node=ei
	if get_parent(): get_parent().call_deferred("add_child",ei)
	else: call_deferred("add_child",ei)


func _spawn_enemy():
	if not enemy_scene: print("Enemy scene not set."); return
	var ei=enemy_scene.instantiate()
	# Find a valid path cell to spawn the enemy, not on player's start or exit
	var spawn_attempts = 0
	var spawned = false
	while spawn_attempts < 100 and not spawned: # Try a few times to find a spot
		var ex_grid = randi() % maze_width
		var ey_grid = randi() % maze_height
		if maze_matrix.size() > ey_grid and maze_matrix[ey_grid].size() > ex_grid and \
		   maze_matrix[ey_grid][ex_grid] == 0 and \
		   Vector2i(ex_grid, ey_grid) != entrance_matrix_pos and \
		   Vector2i(ex_grid, ey_grid) != exit_matrix_pos:
			
			var ex_world = ex_grid * cell_size.x + maze_offset.x + cell_size.x / 2.0
			var ey_world = ey_grid * cell_size.y + maze_offset.y + cell_size.y / 2.0
			ei.global_position = Vector2(ex_world, ey_world)
			spawned = true
		spawn_attempts += 1
	
	if not spawned:
		print("Could not find a valid spawn location for enemy after 100 attempts.")
		ei.queue_free() # Clean up unspawned enemy
		return

	ei.add_to_group("enemy")
	#ei.visible = false # Start invisible
	ei.set_process(false) # Start with processing off
	proximity_enemies_data.append({"enemy_node": ei})
	
	if get_parent():get_parent().call_deferred("add_child",ei)
	else:call_deferred("add_child",ei)

func _initialize_proximity_lights():
	proximity_lights_data.clear() # Clear before re-initializing
	var light_wall_nodes = get_tree().get_nodes_in_group("proximity_light_wall")
	for wall_node in light_wall_nodes:
		var light_2d_node = wall_node.get_node_or_null("ProximityPointLight") 

		if light_2d_node is Light2D:
			light_2d_node.enabled = false # Ensure light starts disabled
			proximity_lights_data.append({
				"light_node": light_2d_node, 
				"wall_node": wall_node 
			})
		else:
			print("Warning: Node '%s' in 'proximity_light_wall' group is missing child 'ProximityPointLight' (Light2D)." % wall_node.name)

func _process(delta: float):
	if not is_instance_valid(player_node):
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty(): player_node = players[0]
		else: return # No player, no proximity updates

	var player_pos = player_node.global_position
	
	# Process Proximity Lights
	var i = proximity_lights_data.size() - 1
	while i >= 0:
		var data = proximity_lights_data[i]
		var light: Light2D = data.light_node
		var wall_node = data.wall_node

		if not is_instance_valid(light) or not is_instance_valid(wall_node) or not wall_node.is_inside_tree():
			proximity_lights_data.remove_at(i)
			i -= 1; continue

		var light_interaction_pos = light.global_position 
		var wall_pos = wall_node.global_position
		var distance_to_light = player_pos.distance_to(light_interaction_pos)
		var light_should_be_enabled = (distance_to_light <= proximity_activation_distance) and distance_to_light <= cell_size.x

		if light.enabled != light_should_be_enabled:
			light.enabled = light_should_be_enabled
			if light.enabled:
				light.energy = distance_to_light / (2 * proximity_activation_distance * proximity_activation_distance)
			else:
				light.energy = 0
			light.set_process(light_should_be_enabled) 
			
		
		i -= 1

	# Process Proximity Enemies
	var j = proximity_enemies_data.size() - 1
	while j >= 0:
		var enemy_data = proximity_enemies_data[j]
		var enemy: Node2D = enemy_data.enemy_node

		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			proximity_enemies_data.remove_at(j)
			j -= 1; continue

		var distance_to_enemy = player_pos.distance_to(enemy.global_position)
		var enemy_should_be_active = (distance_to_enemy <= proximity_enemy_1_distance) and enemy.is_enemy_moving()
		
		if enemy_should_be_active: # Check against current visibility
			enemy.visible = true
			var enemy_light: Light2D = enemy.get_node_or_null("enemy_light")
			enemy_light.energy = distance_to_enemy / ( proximity_activation_distance *  proximity_activation_distance)
			enemy_light.color = Color(2.3, 91, 1, enemy_light.energy)
			enemy.set_process(enemy_should_be_active) 
			# If your enemy has specific activate/deactivate methods, call them here:
			# if enemy_should_be_active and enemy.has_method("activate"): enemy.activate()
			# if not enemy_should_be_active and enemy.has_method("deactivate"): enemy.deactivate()
			# print("Enemy %s toggled to active: %s" % [enemy.name, enemy_should_be_active])
		else:
			enemy.visible = false
			
		j -= 1

# --- Dynamic Wall Modification ---
func modify_random_walls():
	if not is_inside_tree(): return
	var main_mod_timer = get_node_or_null("WallModificationTimer")
	if is_instance_valid(main_mod_timer) and main_mod_timer is Timer: main_mod_timer.stop()
	if player_node == null or not is_instance_valid(player_node):
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty(): self.player_node = players[0]
	var mod_paths = []; var mod_walls = []
	for y in range(1,maze_height-1):
		for x in range(1,maze_width-1):
			var cgp=Vector2i(x,y);if cgp==entrance_matrix_pos or cgp==exit_matrix_pos:continue
			if maze_matrix[y][x]==0:mod_paths.append(cgp)
			else:mod_walls.append(cgp)
	if mod_paths.is_empty() and mod_walls.is_empty():
		if is_instance_valid(main_mod_timer) and main_mod_timer is Timer and is_inside_tree(): main_mod_timer.start()
		return
	var num_changes = randi_range(1,3)
	for i in range(num_changes):
		if not is_inside_tree(): return
		var act_type = randi()%2
		if act_type==0 and not mod_walls.is_empty():var cp=mod_walls.pop_at(randi()%mod_walls.size());_remove_wall_at(cp);mod_paths.append(cp)
		elif act_type==1 and not mod_paths.is_empty():
			var cp=mod_paths.pop_at(randi()%mod_paths.size());await _warn_and_add_wall_at(cp)
			if not is_inside_tree():mod_walls.append(cp)
		elif not mod_walls.is_empty():var cp=mod_walls.pop_at(randi()%mod_walls.size());_remove_wall_at(cp);mod_paths.append(cp)
		elif not mod_paths.is_empty():
			var cp=mod_paths.pop_at(randi()%mod_paths.size())
			await _warn_and_add_wall_at(cp)
			if not is_inside_tree():return;mod_walls.append(cp)
		else:break
	if is_inside_tree() and is_instance_valid(main_mod_timer) and main_mod_timer is Timer:main_mod_timer.start()

func _remove_wall_at(matrix_pos: Vector2i):
	if not is_inside_tree(): return
	if matrix_pos.y<0 or matrix_pos.y>=maze_matrix.size() or matrix_pos.x<0 or matrix_pos.x>=maze_matrix[matrix_pos.y].size(): return
	if maze_matrix[matrix_pos.y][matrix_pos.x]==1:
		maze_matrix[matrix_pos.y][matrix_pos.x]=0
		for child in get_children():
			if child.is_in_group("wall_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos")==matrix_pos:
				var k=proximity_lights_data.size()-1 # Check if it was a light wall
				while k>=0:
					if proximity_lights_data[k].wall_node==child:proximity_lights_data.remove_at(k);break
					k-=1
				child.queue_free();break
		if floor_scene:
			var fi=floor_scene.instantiate()
			var ip=Vector2(matrix_pos.x*cell_size.x,matrix_pos.y*cell_size.y)+maze_offset
			fi.position=ip;fi.set_meta("grid_pos",matrix_pos);fi.add_to_group("floor_tile");add_child(fi)

func _warn_and_add_wall_at(matrix_pos: Vector2i) -> void:
	if not is_inside_tree(): return
	var world_pos_tl = Vector2(matrix_pos.x*cell_size.x,matrix_pos.y*cell_size.y)+maze_offset; var wi_node=null # Renamed for clarity
	if warning_effect_scene:wi_node=warning_effect_scene.instantiate();wi_node.position=world_pos_tl+cell_size/2.0;wi_node.add_to_group("persistent_effect");add_child(wi_node)
	else:var cr=ColorRect.new();cr.color=Color(1,0.8,0,0.4);cr.size=cell_size;cr.position=world_pos_tl;cr.add_to_group("persistent_effect");add_child(cr);wi_node=cr
	if not is_inside_tree():
		if is_instance_valid(wi_node) and wi_node.is_inside_tree():wi_node.queue_free();return
	var lwt=get_tree().create_timer(wall_warning_duration);await lwt.timeout
	if not is_inside_tree():
		if is_instance_valid(wi_node) and wi_node.is_inside_tree():wi_node.queue_free();return
	if is_instance_valid(wi_node) and wi_node.is_inside_tree():wi_node.queue_free()
	var pc=false
	if player_node!=null and is_instance_valid(player_node):
		var prp=player_node.global_position-maze_offset
		if Vector2i(floor(prp.x/cell_size.x),floor(prp.y/cell_size.y))==matrix_pos:pc=true
	if pc:print("PLAYER CRUSHED at matrix: ",matrix_pos);if not is_inside_tree():return;get_tree().reload_current_scene();return
	if matrix_pos.y<0 or matrix_pos.y>=maze_matrix.size() or matrix_pos.x<0 or matrix_pos.x>=maze_matrix[matrix_pos.y].size():return
	if maze_matrix[matrix_pos.y][matrix_pos.x]==0:
		maze_matrix[matrix_pos.y][matrix_pos.x]=1
		for child in get_children():
			if child.is_in_group("floor_tile") and child.has_meta("grid_pos") and child.get_meta("grid_pos")==matrix_pos:child.queue_free();break
		if wall_scene:
			var wall_i=wall_scene.instantiate();wall_i.position=world_pos_tl;wall_i.set_meta("grid_pos",matrix_pos)
			wall_i.add_to_group("wall_tile");add_child(wall_i)
			# If the new wall happens to be a proximity light wall, re-initialize lights
			if wall_i.is_in_group("proximity_light_wall"):_initialize_proximity_lights()

func _ready():
	randomize();
	generate_and_draw();
	_initialize_proximity_lights();
	_spawn_player_at_entrance();
	_spawn_enemy();
	
	if wall_modification_interval>0:
		var wmt=Timer.new();wmt.name="WallModificationTimer";wmt.wait_time=wall_modification_interval
		wmt.connect("timeout",Callable(self,"modify_random_walls"));add_child(wmt);wmt.start()
	else:print("Wall modification interval <=0, dynamic walls disabled.")

func generate_and_draw():
	_generate_maze_matrix()
	_draw_maze()
	# Enemies and lights are initialized/spawned in _ready after draw,
	# or if a wall is added that is a light wall, _initialize_proximity_lights is called.
	# If you want enemies to respawn on every generate_and_draw, you'd need to manage that.
	# For now, proximity_enemies_data is not cleared here, assuming enemies persist unless _ready is called again.


func get_maze_matrix()->Array:return maze_matrix
func get_cell_type(x:int,y:int)->int:
	if y>=0 and y<maze_matrix.size() and x>=0 and x<maze_matrix[y].size():return maze_matrix[y][x]
	return -1
func get_player_start_world_position()->Vector2:
	var wx=entrance_matrix_pos.x*cell_size.x+maze_offset.x+cell_size.x/2.0
	var wy=entrance_matrix_pos.y*cell_size.y+maze_offset.y+cell_size.y/2.0;return Vector2(wx,wy)
func get_entrance_matrix_position()->Vector2i:return entrance_matrix_pos
func get_exit_matrix_position()->Vector2i:return exit_matrix_pos
