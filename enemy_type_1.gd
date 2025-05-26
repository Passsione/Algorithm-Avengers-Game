extends CharacterBody2D

@export var enemy_speed = 100
@export var _is_moving_this_frame: bool = false
const MOVEMENT_THRESHOLD = 10.0 # Adjust as needed

func _physics_process(delta: float) -> void:
	var direction = Vector2.ZERO
	direction.x -= randi_range(-1, 1)
	direction.y -= randi_range(-1, 1)
	velocity.y = direction.y * enemy_speed
	velocity.x = direction.x * enemy_speed
	move_and_slide()

	if velocity.length_squared() > MOVEMENT_THRESHOLD * MOVEMENT_THRESHOLD:
		_is_moving_this_frame = true
	else:
		_is_moving_this_frame = false

func is_enemy_moving() -> bool:
		return _is_moving_this_frame
