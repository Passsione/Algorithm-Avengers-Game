extends CharacterBody2D


@export var speed = 200

# --- Called when the node enters the scene tree ---
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
