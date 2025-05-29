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
@export var maze_width: int = 7
@export var maze_height: int = 7

# Offset
@export var maze_offset: Vector2 = Vector2(20, 15)

# Dynamic Wall Settings
@export var wall_warning_duration: float = 2.0
@export var wall_modification_interval: float = 10.0


# Proximity Activation Settings
@export_category("Proximity Activation")
@export var proximity_activation_distance: float = 200.0 # For lights
@export var proximity_enemy_activation_distance: float = 150.0 # For enemies
@export_flags_2d_physics var wall_occlusion_layer: int = 1 # Physics layer for walls that block "hearing"


var maze_matrix: Array = []
var entrance_matrix_pos: Vector2i # Will be cell type 3 (start)
var exit_matrix_pos: Vector2i   # Will be cell type 2 (end)
var player_node: Node2D = null 

var nav_region: NavigationRegion2D = null # For navigation mesh

# Store data for proximity lights: [{light_node: Light2D, wall_node: Node2D}]
var proximity_lights_data: Array = []
# Store data for proximity enemies: [{enemy_node: Node2D}]
var proximity_enemies_data: Array = []


# --- Maze Generation ---
func _generate_maze_matrix():
	maze_matrix.clear()
	if maze_width < 5: maze_width = 5
	if maze_height < 5: maze_height = 5
	if maze_width % 2 == 0: maze_width += 1
	if maze_height % 2 == 0: maze_height += 1
	for y in range(maze_height):
		var row: Array = []
		for x in range(maze_width): row.append(1) # 1 = wall
		maze_matrix.append(row)
	var stack: Array = []
	var current_cell: Vector2i = Vector2i(1, 1) # Start carving from an internal path cell
	maze_matrix[current_cell.y][current_cell.x] = 0 # 0 = path
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
			maze_matrix[wy][wx] = 0 # Carve wall between
			current_cell = next_cell; visited_path_cells += 1
		elif not stack.is_empty(): current_cell = stack.pop_back()
		else: break
	_create_random_entrance_exit_points() 

func _create_random_entrance_exit_points():
	var vy = []; for i in range(1,maze_height-1,2): vy.append(i) 
	var vx = []; for i in range(1,maze_width-1,2): vx.append(i)
	if vy.is_empty() or vx.is_empty():
		push_error("Maze too small for random Start/End points.")
		entrance_matrix_pos = Vector2i(0, 1) 
		exit_matrix_pos = Vector2i(maze_width - 1, maze_height - 2)
		if entrance_matrix_pos.y < maze_matrix.size() and entrance_matrix_pos.x < maze_matrix[0].size():
			maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x] = 3 
		if exit_matrix_pos.y < maze_matrix.size() and exit_matrix_pos.x < maze_matrix[0].size():
			maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x] = 2
		if maze_matrix.size() > 1 and maze_matrix[0].size() > 1: 
			if entrance_matrix_pos.x == 0 and entrance_matrix_pos.x + 1 < maze_matrix[0].size() and maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x + 1] == 1: 
				maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x + 1] = 0
			elif entrance_matrix_pos.y == 0 and entrance_matrix_pos.y + 1 < maze_matrix.size() and maze_matrix[entrance_matrix_pos.y + 1][entrance_matrix_pos.x] == 1: 
				maze_matrix[entrance_matrix_pos.y + 1][entrance_matrix_pos.x] = 0
		return

	var choice=randi()%2
	if choice==0: 
		entrance_matrix_pos=Vector2i(0,vy.pick_random()) 
		exit_matrix_pos=Vector2i(maze_width-1,vy.pick_random()) 
		if entrance_matrix_pos.x + 1 < maze_width: maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x + 1] = 0
		if exit_matrix_pos.x - 1 >= 0: maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x - 1] = 0
	else: 
		entrance_matrix_pos=Vector2i(vx.pick_random(),0) 
		exit_matrix_pos=Vector2i(vx.pick_random(),maze_height-1) 
		if entrance_matrix_pos.y + 1 < maze_height: maze_matrix[entrance_matrix_pos.y + 1][entrance_matrix_pos.x] = 0
		if exit_matrix_pos.y - 1 >= 0: maze_matrix[exit_matrix_pos.y - 1][exit_matrix_pos.x] = 0
	maze_matrix[entrance_matrix_pos.y][entrance_matrix_pos.x]=3 
	maze_matrix[exit_matrix_pos.y][exit_matrix_pos.x]=2   

func _draw_maze():
	for c in get_children():
		if not c.is_in_group("player") and \
		   not c.is_in_group("enemy") and \
		   not c.is_in_group("persistent_effect") and \
		   not c is Timer and \
		   not c is NavigationRegion2D: 
			c.queue_free()
	proximity_lights_data.clear()

	if maze_matrix.is_empty(): printerr("Maze matrix empty."); return
	for y in range(maze_matrix.size()):
		for x in range(maze_matrix[y].size()):
			var cell_type=maze_matrix[y][x]
			var pos=Vector2(x*cell_size.x,y*cell_size.y)+maze_offset
			var gp=Vector2i(x,y)
			
			if cell_type==1 and wall_scene: 
				var wi=wall_scene.instantiate();wi.position=pos;wi.set_meta("grid_pos",gp);wi.add_to_group("wall_tile");add_child(wi)
			elif cell_type==0 and floor_scene: 
				var fi=floor_scene.instantiate();fi.position=pos;fi.set_meta("grid_pos",gp);fi.add_to_group("floor_tile");add_child(fi)
			elif cell_type==2 and end_scene: 
				var ei=end_scene.instantiate();ei.position=pos;ei.set_meta("grid_pos",gp);ei.add_to_group("end_tile");add_child(ei)
			elif cell_type==3 and start_scene: 
				var si=start_scene.instantiate();si.position=pos;si.set_meta("grid_pos",gp);si.add_to_group("start_tile");add_child(si)
			elif cell_type != 0 and cell_type != 1 and floor_scene : 
				var fi_fallback=floor_scene.instantiate();fi_fallback.position=pos;fi_fallback.set_meta("grid_pos",gp);fi_fallback.add_to_group("floor_tile");add_child(fi_fallback)

func _setup_navigation_region():
	# Attempt to find existing NavRegion, assuming it might be a direct child or child of parent
	var existing_nav_region = get_node_or_null("NavRegion")
	if not is_instance_valid(existing_nav_region) and get_parent() and get_parent().has_node("NavRegion"):
		existing_nav_region = get_parent().get_node("NavRegion")

	if is_instance_valid(existing_nav_region) and existing_nav_region is NavigationRegion2D:
		nav_region = existing_nav_region
		print_debug("Using existing NavigationRegion2D: %s" % nav_region.name)
	else:
		print_debug("NavigationRegion2D not found, creating a new one.")
		nav_region = NavigationRegion2D.new()
		nav_region.name = "NavRegion"
		# Add it as a child of this node's parent, or self if no parent (e.g. root)
		var nav_parent = get_parent() if get_parent() else self
		nav_parent.call_deferred("add_child", nav_region)
		# Connect to tree_entered to configure it once it's in the tree
		if not nav_region.is_connected("tree_entered", Callable(self, "_on_nav_region_tree_entered")):
			nav_region.tree_entered.connect(Callable(self, "_on_nav_region_tree_entered").bind(true)) # Bind true for initial bake
		print_debug("Scheduled NavigationRegion2D to be added.")
	
	if is_instance_valid(nav_region) and nav_region.is_inside_tree():
		# If already in tree (e.g. it existed), configure and bake immediately.
		_on_nav_region_tree_entered(true)


func _on_nav_region_tree_entered(is_initial_setup: bool = false):
	if not is_instance_valid(nav_region):
		printerr("_on_nav_region_tree_entered: nav_region is not valid!")
		return
	
	print_debug("NavRegion '%s' entered tree. Setting global position and navigation_layers." % nav_region.name)
	nav_region.global_position = Vector2.ZERO # Ensure it's at origin for global coord outlines
	nav_region.navigation_layers = 1
	
	# Perform initial bake if this flag is set (usually from _ready path)
	if is_initial_setup:
		print_debug("Performing initial bake for NavRegion from tree_entered.")
		_generate_and_bake_navigation_polygon_impl()

func _generate_and_bake_navigation_polygon_impl(): 
	if not is_instance_valid(nav_region) or not nav_region.is_inside_tree():
		printerr("Cannot generate navigation polygon: NavigationRegion2D is not valid or not in tree.")
		if not get_tree().has_meta("__nav_bake_deferred_retry"): 
			get_tree().set_meta("__nav_bake_deferred_retry", true)
			call_deferred("_generate_and_bake_navigation_polygon_impl")
			print_debug("Deferred nav bake due to nav_region not ready.")
		else:
			get_tree().remove_meta("__nav_bake_deferred_retry") 
		return
	
	if get_tree().has_meta("__nav_bake_deferred_retry"): 
		get_tree().remove_meta("__nav_bake_deferred_retry")

	var new_nav_poly_resource = NavigationPolygon.new() 
	var source_geometry_data = NavigationMeshSourceGeometryData2D.new()
	
	var walkable_outlines_collection = [] 

	for y_idx in range(maze_matrix.size()):
		for x_idx in range(maze_matrix[y_idx].size()):
			var cell_val = maze_matrix[y_idx][x_idx]
			if cell_val == 0 or cell_val == 2 or cell_val == 3: 
				var cell_rect_vertices = PackedVector2Array()
				var r_pos_x = x_idx * cell_size.x + maze_offset.x
				var r_pos_y = y_idx * cell_size.y + maze_offset.y
				
				cell_rect_vertices.append(Vector2(r_pos_x, r_pos_y))
				cell_rect_vertices.append(Vector2(r_pos_x + cell_size.x, r_pos_y))
				cell_rect_vertices.append(Vector2(r_pos_x + cell_size.x, r_pos_y + cell_size.y))
				cell_rect_vertices.append(Vector2(r_pos_x, r_pos_y + cell_size.y))
				walkable_outlines_collection.append(cell_rect_vertices)
	
	if not walkable_outlines_collection.is_empty():
		for outline in walkable_outlines_collection:
			source_geometry_data.add_traversable_outline(outline)
		
		var nav_poly_rid = new_nav_poly_resource.get_rid() 

		NavigationServer2D.parse_source_geometry_data(nav_poly_rid, source_geometry_data, nav_region)
		# MODIFIED: Added callback for bake_from_source_geometry_data
		NavigationServer2D.bake_from_source_geometry_data(nav_poly_rid, Callable(self, "_on_navigation_bake_finished")) 

		# The result of baking is asynchronous, so we check in the callback.
		# We assign the polygon resource to the region here, and the server updates it.
		nav_region.navigation_polygon = new_nav_poly_resource 
		print_debug("Navigation polygon baking initiated with %d outlines." % walkable_outlines_collection.size())
	else:
		printerr("No walkable cells found to generate navigation polygon outlines.")
		nav_region.navigation_polygon = null

func _on_navigation_bake_finished():
	print_debug("NavigationServer2D: Bake finished.")
	if is_instance_valid(nav_region) and is_instance_valid(nav_region.navigation_polygon):
		if nav_region.navigation_polygon.get_vertex_count() > 0:
			print_debug("Baked polygon has %d vertices." % nav_region.navigation_polygon.get_vertex_count())
		else:
			printerr("Navigation baking resulted in 0 vertices after callback. Check outlines and geometry data.")
	else:
		printerr("Navigation bake finished, but nav_region or its polygon is not valid.")


func _spawn_player_at_entrance():
	if not player_scene: print("Player scene not set."); return
	var pi=player_scene.instantiate()
	var wx=entrance_matrix_pos.x*cell_size.x+maze_offset.x+cell_size.x/2.0
	var wy=entrance_matrix_pos.y*cell_size.y+maze_offset.y+cell_size.y/2.0
	pi.global_position=Vector2(wx,wy); pi.add_to_group("player"); self.player_node=pi
	if get_parent(): get_parent().call_deferred("add_child",pi) 
	else: call_deferred("add_child",pi)
	
func _spawn_enemy():
	if not enemy_scene: 
		print("Enemy scene not set.")
		return
	
	var ei=enemy_scene.instantiate()

	if not is_instance_valid(player_node):
		printerr("Cannot spawn enemy: Player node is not valid (was it spawned and added to tree via call_deferred?).")
		if is_instance_valid(ei): ei.queue_free() 
		return

	if "player_target_node" in ei:
		ei.player_target_node = player_node 
	else:
		printerr("Enemy instance does not have 'player_target_node' property. Navigation might not work.")

	var spawn_attempts = 0; var spawned = false
	while spawn_attempts < 100 and not spawned:
		var ex_grid = randi() % maze_width; var ey_grid = randi() % maze_height
		if ey_grid < maze_matrix.size() and ex_grid < maze_matrix[ey_grid].size() and \
		   maze_matrix[ey_grid][ex_grid] == 0 and \
		   Vector2i(ex_grid, ey_grid) != entrance_matrix_pos and \
		   Vector2i(ex_grid, ey_grid) != exit_matrix_pos:
			var ex_world = ex_grid*cell_size.x+maze_offset.x+cell_size.x/2.0
			var ey_world = ey_grid*cell_size.y+maze_offset.y+cell_size.y/2.0
			ei.global_position = Vector2(ex_world, ey_world); spawned = true
		spawn_attempts += 1
	if not spawned: 
		print("Could not find valid spawn for enemy after 100 attempts.")
		if is_instance_valid(ei): ei.queue_free() 
		return

	ei.add_to_group("enemy"); ei.visible = false; ei.set_process(true) 
	proximity_enemies_data.append({"enemy_node": ei})
	if get_parent():get_parent().call_deferred("add_child",ei)
	else:call_deferred("add_child",ei)

func _initialize_proximity_lights():
	proximity_lights_data.clear()
	var light_wall_nodes = get_tree().get_nodes_in_group("proximity_light_wall")
	for wall_node in light_wall_nodes:
		var light_2d_node = wall_node.get_node_or_null("ProximityPointLight") 
		if light_2d_node is Light2D:
			light_2d_node.enabled = false
			proximity_lights_data.append({"light_node": light_2d_node, "wall_node": wall_node })
		else: print("Warning: Node '%s' in 'proximity_light_wall' group missing 'ProximityPointLight'." % wall_node.name)

func _is_occluded(from_pos: Vector2, to_pos: Vector2, exclude_array: Array = []) -> bool:
	if not is_inside_tree(): return true 
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos) 
	query.collision_mask = wall_occlusion_layer
	query.exclude = exclude_array
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _process(delta: float):
	if not is_instance_valid(player_node):
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty(): player_node = players[0]
		else: return

	var player_pos = player_node.global_position
	var player_is_moving = false
	if player_node.has_method("is_player_moving"):
		player_is_moving = player_node.is_player_moving()

	var i = proximity_lights_data.size() - 1
	while i >= 0:
		var data = proximity_lights_data[i]
		var light: Light2D = data.light_node
		var wall_node = data.wall_node
		if not is_instance_valid(light) or not is_instance_valid(wall_node) or not wall_node.is_inside_tree():
			proximity_lights_data.remove_at(i); i -= 1; continue
		var target_pos = light.global_position 
		var distance_to_target = player_pos.distance_to(target_pos)
		var is_in_range = (distance_to_target <= proximity_activation_distance)
		var light_should_be_enabled = false
		if is_in_range:
			if player_is_moving: light_should_be_enabled = true
			else: 
				var exclude_list = [player_node.get_rid() if player_node else null]
				var occluded = _is_occluded(player_pos, target_pos, exclude_list) 
				light_should_be_enabled = not occluded
		if light.enabled != light_should_be_enabled: light.enabled = light_should_be_enabled
		i -= 1

	var j = proximity_enemies_data.size() - 1
	while j >= 0:
		var enemy_data = proximity_enemies_data[j]
		var enemy: Node2D = enemy_data.enemy_node 
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			proximity_enemies_data.remove_at(j); j -= 1; continue
		
		var enemy_pos = enemy.global_position
		var distance_to_enemy = player_pos.distance_to(enemy_pos)
		var is_in_range = (distance_to_enemy <= proximity_enemy_activation_distance)
		var enemy_should_be_visible = false 
		
		var enemy_is_moving = false
		if enemy.has_method("is_enemy_moving"):
			enemy_is_moving = enemy.is_enemy_moving()

		if is_in_range:
			if player_is_moving or enemy_is_moving: 
				enemy_should_be_visible = true
			else: 
				var exclude_list = [player_node.get_rid() if player_node else null]
				if enemy is CollisionObject2D: exclude_list.append(enemy.get_rid())
				var occluded = _is_occluded(player_pos, enemy_pos, exclude_list)
				enemy_should_be_visible = not occluded
		
		if enemy.visible != enemy_should_be_visible:
			enemy.visible = enemy_should_be_visible
			var enemy_light = enemy.get_node_or_null("enemy_light") 
			if enemy_light is Light2D:
				enemy_light.enabled = enemy_should_be_visible
		j -= 1

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
			if not is_inside_tree():return;mod_walls.append(cp) 
		elif not mod_walls.is_empty():
			var cp=mod_walls.pop_at(randi()%mod_walls.size());_remove_wall_at(cp);mod_paths.append(cp)
		elif not mod_paths.is_empty():
			var cp=mod_paths.pop_at(randi()%mod_paths.size());await _warn_and_add_wall_at(cp)
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
				var k=proximity_lights_data.size()-1
				while k>=0:
					if proximity_lights_data[k].wall_node==child:proximity_lights_data.remove_at(k);break
					k-=1
				child.queue_free();break
		if floor_scene:
			var fi=floor_scene.instantiate();var ip=Vector2(matrix_pos.x*cell_size.x,matrix_pos.y*cell_size.y)+maze_offset
			fi.position=ip;fi.set_meta("grid_pos",matrix_pos);fi.add_to_group("floor_tile");add_child(fi)
		
		# After removing a wall, the navigation mesh needs to be rebaked
		if is_instance_valid(nav_region):
			call_deferred("_generate_and_bake_navigation_polygon_impl") # Defer baking

func _warn_and_add_wall_at(matrix_pos: Vector2i) -> void:
	if not is_inside_tree(): return
	var world_pos_tl = Vector2(matrix_pos.x*cell_size.x,matrix_pos.y*cell_size.y)+maze_offset; var wi_node=null
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
			if wall_i.is_in_group("proximity_light_wall"):_initialize_proximity_lights()
		
		if is_instance_valid(nav_region):
			call_deferred("_generate_and_bake_navigation_polygon_impl") # Defer baking

func _ready():
	randomize()
	_setup_navigation_region() 
	
	generate_and_draw() # This now handles initial spawn and nav bake
	
	# Timer setup is now primarily managed within generate_and_draw to ensure
	# it's correctly setup/removed if that function is called multiple times.
	# However, ensure it's initially set up if wall_modification_interval > 0
	if wall_modification_interval > 0 and not has_node("WallModificationTimer"):
		var wmt = Timer.new()
		wmt.name = "WallModificationTimer"
		wmt.wait_time = wall_modification_interval
		wmt.connect("timeout", Callable(self, "modify_random_walls"))
		add_child(wmt)
		wmt.start()
	elif wall_modification_interval <= 0 and has_node("WallModificationTimer"):
		get_node("WallModificationTimer").queue_free()


func generate_and_draw():
	_generate_maze_matrix()
	_draw_maze() 
	
	# Bake navigation AFTER the maze visuals are set.
	# Use call_deferred to ensure nav_region is in tree if added deferred.
	if is_instance_valid(nav_region):
		call_deferred("_generate_and_bake_navigation_polygon_impl") 
	elif has_node("NavRegion"): # Attempt to get it if it was added by _setup_navigation_region
		nav_region = get_node("NavRegion")
		if is_instance_valid(nav_region):
			call_deferred("_generate_and_bake_navigation_polygon_impl")
	else: # Try getting from parent if it was added there
		var parent_nav_region = get_parent().get_node_or_null("NavRegion") if get_parent() else null
		if is_instance_valid(parent_nav_region):
			nav_region = parent_nav_region
			call_deferred("_generate_and_bake_navigation_polygon_impl")
		else:
			printerr("generate_and_draw: NavigationRegion2D not found for baking.")

	
	_initialize_proximity_lights() 
	_spawn_player_at_entrance() 
	_spawn_enemy() 

	# Ensure WallModificationTimer is correctly managed
	var wmt = get_node_or_null("WallModificationTimer")
	if wall_modification_interval > 0:
		if not is_instance_valid(wmt):
			wmt = Timer.new()
			wmt.name = "WallModificationTimer"
			add_child(wmt)
		wmt.wait_time = wall_modification_interval
		if not wmt.is_connected("timeout", Callable(self, "modify_random_walls")):
			wmt.connect("timeout", Callable(self, "modify_random_walls"))
		wmt.start()
	elif is_instance_valid(wmt):
		wmt.queue_free()


func get_maze_matrix()->Array:return maze_matrix
func get_cell_type(x:int,y:int)->int:
	if y>=0 and y<maze_matrix.size() and x>=0 and x<maze_matrix[y].size():
		return maze_matrix[y][x]
	return -1
func get_player_start_world_position()->Vector2:
	var wx=entrance_matrix_pos.x*cell_size.x+maze_offset.x+cell_size.x/2.0
	var wy=entrance_matrix_pos.y*cell_size.y+maze_offset.y+cell_size.y/2.0;return Vector2(wx,wy)
func get_entrance_matrix_position()->Vector2i:return entrance_matrix_pos
func get_exit_matrix_position()->Vector2i:return exit_matrix_pos
