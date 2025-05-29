# enemy_type_1.gd
extends CharacterBody2D

@export var speed: float = 150.0 
@export var damage: int = 10
var player_target_node: Node2D # This will be set by MazeGenerator

@export var _is_moving_this_frame: bool = false
const MOVEMENT_THRESHOLD_SQUARED = 5.0 # e.g., (2.23^2)

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var growl_timer: Timer = $GrowlTimer 

@onready var sprite_2d: Sprite2D = $Sprite2D # Assuming your Sprite2D is named "Sprite2D"
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Assuming it's named "AnimationPlayer"


func _ready():
	if is_instance_valid(growl_timer): 
		growl_timer.start(randf_range(3.0, 8.0))
	else:
		printerr("%s: GrowlTimer node not found." % name)
		
	nav_agent.target_desired_distance = 5.0 
	nav_agent.path_desired_distance = 2.0   
	nav_agent.path_max_distance = 2000.0 

	# Connect signals for debugging
	nav_agent.navigation_finished.connect(_on_navigation_finished)
	nav_agent.target_reached.connect(_on_target_reached)
	nav_agent.path_changed.connect(_on_path_changed)
	
	print_debug("%s _ready: Navigation map RID: %s" % [name, nav_agent.get_navigation_map()])


	if is_instance_valid(player_target_node):
		# It's better to set the target position once the navigation map is ready.
		# We can use call_deferred to ensure it happens after the current frame's processing.
		call_deferred("_set_initial_target_position")
	else:
		print_debug("%s in _ready: Player target node NOT YET VALID." % name)

func _set_initial_target_position():
	if is_instance_valid(player_target_node):
		nav_agent.target_position = player_target_node.global_position
		print_debug("%s _set_initial_target_position: Initial target set to %s. Is target reachable? %s" % [name, nav_agent.target_position, nav_agent.is_target_reachable()])
	else:
		print_debug("%s _set_initial_target_position: Player target node still not valid." % name)


func _physics_process(delta: float):
	_is_moving_this_frame = false 

	if not is_instance_valid(player_target_node):
		velocity = Vector2.ZERO
		move_and_slide() 
		return

	# Update target position if it has changed significantly
	if nav_agent.target_position.distance_squared_to(player_target_node.global_position) > 1.0: # Update if target moved more than 1 unit (squared)
		nav_agent.target_position = player_target_node.global_position
		# The 'path_changed' signal will fire if a new path is needed and found.
		# print_debug("%s: Updated nav_agent.target_position to %s" % [name, nav_agent.target_position])

	if nav_agent.is_navigation_finished() or nav_agent.is_target_reached():
		# print_debug("%s: Navigation finished or target reached. Velocity set to ZERO." % name)
		velocity = Vector2.ZERO
	else:
		var next_path_position: Vector2 = nav_agent.get_next_path_position()
		var current_position: Vector2 = global_position
		
		# print_debug("%s: Current Pos: %s, Next Path Pos: %s, Target Pos: %s, Is Nav Finished: %s, Is Target Reached: %s" % [name, current_position, next_path_position, nav_agent.target_position, nav_agent.is_navigation_finished(), nav_agent.is_target_reached()])

		# Check if next_path_position is substantially different from current position
		if current_position.distance_squared_to(next_path_position) > (nav_agent.path_desired_distance * 0.5) * (nav_agent.path_desired_distance * 0.5) : 
			var direction: Vector2 = current_position.direction_to(next_path_position)
			velocity = direction * speed
			# print_debug("%s: Moving towards %s with velocity %s" % [name, next_path_position, velocity])
		else:
			# This case means the agent is very close to the next_path_position,
			# or next_path_position is the agent's current position (e.g., empty path).
			# If the path is not empty and not finished, it should eventually get a new next_path_position.
			velocity = Vector2.ZERO 
			# print_debug("%s: Next path position is very close or same as current. Velocity set to ZERO." % name)
	
	move_and_slide()
	update_animation()
	if velocity.length_squared() > MOVEMENT_THRESHOLD_SQUARED:
		_is_moving_this_frame = true

func update_animation():
	if velocity.length_squared() > 0: # Player is moving
		if velocity.x < 0:
			if animation_player.current_animation != "walk_left": # Or play "walk_right" and flip
				animation_player.play("walk_left") # Assuming you have a "walk_left" animation
			sprite_2d.flip_h = true # Flip sprite if using a right-facing animation for left
		elif velocity.x > 0:
			if animation_player.current_animation != "walk_right":
				animation_player.play("walk_right")
			sprite_2d.flip_h = false
		elif velocity.y < 0: # Moving up
			if animation_player.current_animation != "walk_up":
				animation_player.play("walk_up")
			# sprite_2d.flip_h = false # Usually no horizontal flip for up/down
		elif velocity.y > 0: # Moving down
			if animation_player.current_animation != "walk_down":
				animation_player.play("walk_down")
			# sprite_2d.flip_h = false
	else: # Player is idle
		if animation_player.current_animation != "idle_down": # Or your default idle animation
			animation_player.play("idle_down") # Assuming you have an "idle_down" animation

func is_enemy_moving() -> bool:
	return _is_moving_this_frame

func _on_hitbox_body_entered(body: Node):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		else:
			printerr("Player node does not have 'take_damage' method.")

func _on_growl_timer_timeout():
	if is_instance_valid(audio_player): 
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()
	if is_instance_valid(growl_timer): 
		growl_timer.start(randf_range(5.0, 10.0))

# --- NavigationAgent2D Signal Callbacks for Debugging ---
func _on_navigation_finished():
	print_debug("ENEMY (%s): Signal 'navigation_finished' received. Is target reachable? %s" % [name, nav_agent.is_target_reachable()])


func _on_target_reached():
	print_debug("ENEMY (%s): Signal 'target_reached' received. Target desired distance: %s. Current distance to player: %s. Is target reachable? %s" % [
		name, 
		nav_agent.target_desired_distance, 
		global_position.distance_to(player_target_node.global_position if is_instance_valid(player_target_node) else global_position),
		nav_agent.is_target_reachable()
	])


func _on_path_changed():
	print_debug("ENEMY (%s): Signal 'path_changed' received. New path is available." % name)
	var current_path = nav_agent.get_current_navigation_path()
	print_debug("ENEMY (%s): Current Path Points: %s (Size: %d)" % [name, current_path, current_path.size()])
	
	if current_path.is_empty():
		printerr("ENEMY (%s): Path is EMPTY. Is target reachable? %s. Agent Position: %s, Target Position: %s" % [
			name, 
			nav_agent.is_target_reachable(), 
			global_position, 
			nav_agent.target_position
		])
		var map_rid = nav_agent.get_navigation_map()
		if map_rid.is_valid():
			var closest_point_to_agent = NavigationServer2D.map_get_closest_point(map_rid, global_position)
			var closest_point_to_target = NavigationServer2D.map_get_closest_point(map_rid, nav_agent.target_position)
			print_debug("ENEMY (%s): Closest nav point to agent: %s (Distance: %s)" % [name, closest_point_to_agent, global_position.distance_to(closest_point_to_agent)])
			print_debug("ENEMY (%s): Closest nav point to target: %s (Distance: %s)" % [name, closest_point_to_target, nav_agent.target_position.distance_to(closest_point_to_target)])
		else:
			printerr("ENEMY (%s): No valid navigation map RID." % name)
			
	elif current_path.size() > 0:
		print_debug("ENEMY (%s): First point in new path: %s" % [name, current_path[0]])


func _on_velocity_computed(safe_velocity: Vector2):
	# print_debug("ENEMY (%s): Signal 'velocity_computed' received: %s" % [name, safe_velocity])
	pass 
