@tool
extends Node3D

@onready var grid_map : GridMap = $GridMap

@export var start : bool = false : set = set_start
func set_start(val:bool) -> void:
	generate()

@export var border_size : int = 20 : set = set_border_size
func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint(): 
		# Will only run if in game editor and not game itself
		visualize_border()

@export var min_room_size : int = 2
@export var max_room_size : int = 4
@export var room_amount : int = 4
@export var room_margin : int = 1
@export var room_recursion: int = 15

var room_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

func visualize_border():
	grid_map.clear()
	for i in range(-1, border_size + 1):
		grid_map.set_cell_item(Vector3i(i, 0, -1), 0) # top
		grid_map.set_cell_item(Vector3i(i, 0, border_size), 0, 10) # bottom
		grid_map.set_cell_item(Vector3i(border_size, 0, i), 0, 22) # right
		grid_map.set_cell_item(Vector3i(-1, 0, i), 0, 16) # left
	
	# clear corners
	grid_map.set_cell_item(Vector3i(-1, 0, -1), -1) 
	grid_map.set_cell_item(Vector3i(border_size, 0, -1), -1)
	
	grid_map.set_cell_item(Vector3i(-1, 0, border_size), 0, -1)
	
	grid_map.set_cell_item(Vector3i(border_size, 0, border_size), 0, -1)
	
	# replace corners
	grid_map.set_cell_item(Vector3i(-1, 0, -1), 1, 16) 
	grid_map.set_cell_item(Vector3i(border_size, 0, -1), 1, 0)
	
	grid_map.set_cell_item(Vector3i(-1, 0, border_size), 1, 10)
	
	grid_map.set_cell_item(Vector3i(border_size, 0, border_size), 1, 22)

func generate():
	room_tiles.clear()
	room_positions.clear()
	visualize_border()
	for i in room_amount:
		make_room(room_recursion)
	print(room_positions)

func make_room(rec:int):
	if !rec>0:
		return
	
	var width : int = (randi() % (max_room_size - min_room_size)) + min_room_size
	var height : int = (randi() % (max_room_size - min_room_size)) + min_room_size
	
	var start_pos : Vector3i
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - height + 1)
	
	for r in range(-room_margin, height + room_margin):
		for c in range(-room_margin, width + room_margin):
			var pos : Vector3i = start_pos + Vector3i(c, 0, r)
			if grid_map.get_cell_item(pos) == 2:
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var pos : Vector3i = start_pos + Vector3i(c, 0, r)
			grid_map.set_cell_item(pos, 2)
	
	room_tiles.append(room)
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x, 0, avg_z)
	room_positions.append(pos)
