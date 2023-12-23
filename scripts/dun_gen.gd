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
@export_range(0, 1) var survival_chance : float = 0.25

var room_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

func visualize_border():
	grid_map.clear()
	for i in range(-1, border_size + 1):
		grid_map.set_cell_item(Vector3i(i, 0, -1), 2) # top
		grid_map.set_cell_item(Vector3i(i, 0, border_size), 2, 10) # bottom
		grid_map.set_cell_item(Vector3i(border_size, 0, i), 2, 22) # right
		grid_map.set_cell_item(Vector3i(-1, 0, i), 2, 16) # left

func generate():
	room_tiles.clear()
	room_positions.clear()
	visualize_border()
	for i in room_amount:
		make_room(room_recursion)
	
	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	
	for p in room_positions:
		rpv2.append(Vector2(p.x, p.z))
		del_graph.add_point(del_graph.get_available_point_id(), Vector2(p.x, p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(), Vector2(p.x, p.z))
	
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	for i in delaunay.size()/3:
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1, p2)
		del_graph.connect_points(p2, p3)
		del_graph.connect_points(p1, p3)
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi() % room_positions.size())
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections: Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp, c]
					possible_connections.append(con)
		var connection : PackedInt32Array = possible_connections.pick_random()
		
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
				
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0], connection[1])
		del_graph.disconnect_points(connection[0], connection[1])
		
		var hallway_graph : AStar2D = mst_graph
		
		for p in del_graph.get_point_ids():
			for c in del_graph.get_point_connections(p):
				if c>p:
					var kill : float = randf()
					if survival_chance > kill : 
						hallway_graph.connect_points(p, c)
	# create_hallways(hallway_graph)

func create_hallways(hallway_graph:AStar2D):
	pass

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
			if grid_map.get_cell_item(pos) == 0:
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var pos : Vector3i = start_pos + Vector3i(c, 0, r)
			grid_map.set_cell_item(pos, 0)
	
	room_tiles.append(room)
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x, 0, avg_z)
	room_positions.append(pos)
