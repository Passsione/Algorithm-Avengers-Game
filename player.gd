extends CharacterBody2D


@export var speed = 200
var _is_moving_this_frame: bool = false
const MOVEMENT_THRESHOLD = 10.0 # Adjust as needed

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
		
	velocity.y = direction.y * speed
	velocity.x = direction.x * speed
	move_and_slide()
	
	if velocity.length_squared() > MOVEMENT_THRESHOLD * MOVEMENT_THRESHOLD:
		_is_moving_this_frame = true
	else:
		_is_moving_this_frame = false

func is_player_moving() -> bool:
		return _is_moving_this_frame
