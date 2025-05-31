extends Control


func _on_level_2_pressed() -> void:
	var game_scene_path = "res://maze_map_level2.tscn"
	var error = get_tree().change_scene_to_file(game_scene_path)
	if error != OK:
		print("Error changing scene: ", error) # Or use push_error()


func _on_quit_pressed() -> void:
	get_tree().quit()
