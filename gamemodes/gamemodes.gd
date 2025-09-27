extends Node

var gamemode = 1

func _select_gamemode(selection: int):
	match selection:
		1:
			gamemode = 1
			print("gamemode 1")
		2:
			gamemode = 2
			print("gamemode 2")
