extends Control

func _on_level_1_pressed() -> void:
	var first_level_path = "res://maze_map.tscn"
	var error = get_tree().change_scene_to_file(first_level_path)

	if error != OK:
		print("Error changing scene: ", error) # Or use push_error()


func _on_level_2_pressed() -> void:
	pass
	#var first = get_tree().get_first_node_in_group("first_level")
	#if first == null or !first.player_reached_exit: return
#
	#var game_scene_path = "res://maze_map_level2.tscn"
	#var error = get_tree().change_scene_to_file(game_scene_path)
	#if error != OK:
		#print("Error changing scene: ", error) # Or use push_error()



func _on_leaderborad_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit() # This quits the game
