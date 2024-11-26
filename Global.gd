extends Node

var player = null
var level = null
var world = null
var gui  = null
var hook : CharacterBody3D = null
var hook_current_point : Transform3D

signal hook_signal
signal hook_current_position

func stop():
	get_tree().quit()

func add(o):
	get_tree().root.add_child(o)
