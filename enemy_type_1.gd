# Enemy.gd (Attached to your CharacterBody2D enemy node)
extends CharacterBody2D

@export var move_speed: float = 80.0 # How fast the enemy moves
@export var path_recalc_interval: float = 0.5 # How often the enemy recalculates its path (lower = smarter but more CPU intensive)

var navigation_agent: NavigationAgent2D = null
var current_path: PackedVector2Array = []
var path_follow_index: int = 0
var recalc_timer: float = 0.0

func _ready() -> void:
	# Get the NavigationAgent2D node (you'll add this as a child in the editor)
	navigation_agent = $NavigationAgent2D
	if navigation_agent == null:
		print("ERROR: NavigationAgent2D not found as a child of Enemy.")
		return
	
	# Connect the path_changed signal (useful for debugging)
	navigation_agent.path_changed.connect(_on_navigation_path_changed)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)

	# Start pathfinding once the game is ready and the maze is initialized
	set_physics_process(false) # Disable physics process until target is set

func _physics_process(delta: float) -> void:
	recalc_timer += delta
	if recalc_timer >= path_recalc_interval:
		recalc_timer = 0.0
		# Request a new path if there's a target
		if navigation_agent.target_position != Vector2.ZERO: # Assuming Vector2.ZERO means no target
			navigation_agent.request_path_ready()

	# If a path exists, move along it
	if not navigation_agent.is_navigation_finished():
		var next_point = navigation_agent.get_next_path_position()
		var direction = (next_point - global_position).normalized()
		navigation_agent.set_velocity(direction * move_speed)
	else:
		navigation_agent.set_velocity(Vector2.ZERO) # Stop if path is finished

func _on_navigation_path_changed():
	# This signal is emitted when the path changes, can be used for debugging
	current_path = navigation_agent.get_current_navigation_path()
	path_follow_index = 0
	# print("Enemy path changed. New path length: ", current_path.size())

func _on_velocity_computed(safe_velocity: Vector2):
	# Apply the safe velocity to the CharacterBody2D
	velocity = safe_velocity
	move_and_slide()

# Call this function from your main MazeManager script to tell the enemy where to go
func set_target_position(target_pos: Vector2):
	if navigation_agent:
		navigation_agent.target_position = target_pos
		set_physics_process(true) # Enable physics processing when a target is set
		# Immediately request a path to the new target
		navigation_agent.request_path_ready()
	else:
		print("NavigationAgent2D not ready for target setting.")

# Call this from MazeManager when the player dies or game ends
func stop_movement():
	set_physics_process(false)
	velocity = Vector2.ZERO
	if navigation_agent:
		navigation_agent.set_velocity(Vector2.ZERO)
		navigation_agent.target_position = global_position # Set target to self to clear any active path

func _on_body_entered(body: Node2D):
	# Assuming your player has a "Player" group or is named "Player"
	if body.is_in_group("player") or body.name == "Player":
		print("Enemy collided with Player!")
		# Emit a signal to tell the MazeManager that the player was caught
		get_parent().player_caught()
