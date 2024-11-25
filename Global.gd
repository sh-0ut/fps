extends Node

var player = null
var level = null
var world = null
var gui  = null

func stop():
	get_tree().quit()

func add(o):
	get_tree().root.add_child(o)
	
