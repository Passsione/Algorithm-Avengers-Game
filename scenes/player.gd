extends CharacterBody2D

const SPEED = 150
var footsteps : AudioStreamPlayer2D = null
var playing = false
func _ready() -> void:
	# Position the player at the start of the maze (adjust coordinates as needed)
	position = Vector2(32, 32) # You may need to adjust this based on your maze
	footsteps = get_node("AudioStreamPlayer2D")
	footsteps.stream =  load("res://running-on-the-road-6220.mp3")
	

func _physics_process(delta: float) -> void:
	player_movement(delta)
	if (velocity.x != 0 || velocity.y != 0)  and not playing:
		footsteps.playing = true
		playing = true
	elif velocity == Vector2.ZERO:
		footsteps.playing = false
		playing = false
	
	move_and_slide()

func player_movement(delta):
	# Reset velocity
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right"):
		
		$Sprite2D.flip_h = false
		$Sprite2D.play("right")
		velocity.x = SPEED
		
	elif Input.is_action_pressed("ui_left"):
		
		$Sprite2D.flip_h = true
		$Sprite2D.play("right")  # or create a "left" animation
		velocity.x = -SPEED  # Fixed: was positive, should be negative
		
	elif Input.is_action_pressed("ui_down"):
		
		$Sprite2D.flip_h = false
		$Sprite2D.play("default")
		velocity.y = SPEED
		
	elif Input.is_action_pressed("ui_up"):  # Added missing up movement
		$Sprite2D.flip_h = false
		$Sprite2D.play("up")
		velocity.y = -SPEED
		
	else:
		# Stop animation when not moving
		$Sprite2D.stop()
