extends Area2D
var success : AudioStreamPlayer2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	var camera : Camera2D = get_tree().get_first_node_in_group("camera")
	var level1 = get_tree().get_first_node_in_group("Root") != null
	
	if body.name == "Player" and success == null:
		success  = AudioStreamPlayer2D.new()
		
		var win_label = Label.new()
		win_label.text = "LEVEL COMPLETE!" if level1 else "GAME COMPLETE!"
		win_label.z_index = 2
		# Center the label on the screen
		#win_label.position = get_viewport().get_visible_rect().size / 2 - win_label.size / 2
		win_label.add_theme_font_size_override("font_size", 14)
		camera.add_child(win_label)
	
		
		add_child(success)
		success.stream =  load("res://success-fanfare-trumpets-6185.mp3")
		success.playing = true
		
		get_tree().create_timer(2.0).timeout.connect(
			func():
				if is_instance_valid(win_label): # Safety check
					win_label.queue_free() # Remove the win message
				#difficulty_level += 1 # Increase difficulty
				
				var level_2_scene = "res://contiune.tscn" if level1 else "res://start_menu.tscn"
				var error = get_tree().change_scene_to_file(level_2_scene)
		)
	elif body.name == "Enemy" and success == null:
		success  = AudioStreamPlayer2D.new()
		add_child(success)
		success.stream =  load("res://scary-scream-3-81274.mp3")
		success.playing = true
		var game_over_label = Label.new()
		game_over_label.text = "FOOL,YOU WERE DEFEATED!"
		game_over_label.add_theme_font_size_override("font_size", 20)

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
			 #player_node.set_process(false) # Stop its _process updates
		set_physics_process(false) # Stop its _physics_process updates

		# Set a timer to wait for 3 seconds, then remove the label and quit the game
		get_tree().create_timer(3.0).timeout.connect(
			func():
				if is_instance_valid(game_over_label): # Check if it's still valid before queueing free
					game_over_label.queue_free() # Remove the "GAME OVER!" message
				var start_scene_path = "res://start_menu.tscn" if level1 else "res://maze_map_level2.tscn"
				get_tree().change_scene_to_file(start_scene_path)
				
		)
		#get_tree().change_scene_to_file("res://contiune.tscn")
