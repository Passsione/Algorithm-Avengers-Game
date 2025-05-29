extends CharacterBody2D


@export var speed = 200
var _is_moving_this_frame: bool = false
const MOVEMENT_THRESHOLD = 10.0 # Adjust as needed

@onready var sprite_2d: Sprite2D = $Sprite2D # Assuming your Sprite2D is named "Sprite2D"
@onready var animation_player: AnimationPlayer = $AnimationPlayer # Assuming it's named "AnimationPlayer"

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
	update_animation()
	
	if velocity.length_squared() > MOVEMENT_THRESHOLD * MOVEMENT_THRESHOLD:
		_is_moving_this_frame = true
	else:
		_is_moving_this_frame = false

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
func is_player_moving() -> bool:
		return _is_moving_this_frame
