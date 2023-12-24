@tool
extends Node3D

@onready var grid_map : GridMap = $GridMap

@export var start : bool = false : set = set_start
func set_start(val:bool) -> void:
	if Engine.is_editor_hint():
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

@export_multiline var custom_seed : String = " " : set = set_seed
func set_seed(val:String) -> void:
	custom_seed = val
	seed(val.hash())

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
	if custom_seed : set_seed(custom_seed)
	visualize_border()
	for i in room_amount:
		make_room(room_recursion)
	
	# Create Delaunay and Minimal Spanning Tree Graph
	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	
	for p in room_positions:
		# Grab room positions and turn them into Vector2s
		rpv2.append(Vector2(p.x, p.z))
		# Populate the Delaunay and Minimal Spanning Tree Graphs with the room positions/points
		del_graph.add_point(del_graph.get_available_point_id(), Vector2(p.x, p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(), Vector2(p.x, p.z))
	
	# Triangulates the area specified by the discrete set of points such that no point 
	# is inside the circumcircle of any resulting triangle in rpv2. Returns a PackedInt32Array 
	# where each triangle consists of three consecutive point indices into points 
	# (i.e. the returned array will have n * 3 elements, with n being the number of found triangles). 
	# This is not random. The triangles are arranged in order so that each 3 indexes of a triangle are
	# adjacent within the array.
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	# Connect the vertices wihtin the Delaunay graph
	for i in delaunay.size()/3:
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1, p2)
		del_graph.connect_points(p2, p3)
		del_graph.connect_points(p1, p3)
	
	# At this point, the Delaunay graph is finished - Moving on to the Minimal Spanning Tree
	
	# Keep track of visited points
	var visited_points : PackedInt32Array = []
	# Selects a random point from the pre-existing points to start from
	visited_points.append(randi() % room_positions.size())
	
	
	while visited_points.size() != mst_graph.get_point_count(): # Runs until all points have been visited
		
		var possible_connections: Array[PackedInt32Array] = [] # Store connections/edges as an ordered pair
		# For every visited point, check its connections in the Delaunay Graph
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c): # If the connected end is not already in visited points, add the connection
					var con : PackedInt32Array = [vp, c]
					possible_connections.append(con)
		
		# This connection will eventually end up as the connection we designate at the end of the
		# while loop (each time it runs, we are trying to find the shortest, new connection to an 
		# unvisited point from all f the current visited points (random placeholder connection assigned)
		var connection : PackedInt32Array = possible_connections.pick_random()
		
		# This loop compares the connection length of the current pc (possible connection)
		# to the stored connection. If the length is shorter, the possible connection becomes
		# the new connection. We iterate until we have exhausted all posibilities, thus giving us
		# the shortest connection
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
		
		# The end point of the new connection is now "visited" so append it to visited points
		visited_points.append(connection[1])
		# Create the new connection in the Minimal Spanning Tree Graph
		mst_graph.connect_points(connection[0], connection[1])
		del_graph.disconnect_points(connection[0], connection[1])
		
		var hallway_graph : AStar2D = mst_graph
		# Add additional hallways outside of the Minimal Spanning Tree
		for p in del_graph.get_point_ids():
			for c in del_graph.get_point_connections(p):
				if c>p:
					var kill : float = randf()
					if survival_chance > kill : 
						hallway_graph.connect_points(p, c)
		create_hallways(hallway_graph)

func create_hallways(hallway_graph:AStar2D):
	var hallways : Array[PackedVector3Array] = []
	for p in hallway_graph.get_point_ids():
		for c in hallway_graph.get_point_connections(p):
			if c>p: # Avoids redundant processing of connections and 
					# ensures that each connection is considered only once
				var room_from : PackedVector3Array = room_tiles[p]
				var room_to : PackedVector3Array = room_tiles[c]
				var tile_from : Vector3 = room_from[0]
				var tile_to : Vector3 = room_to[0]
				# Finds the tile in the former room that is closest to the next room
				for t in room_from:
					if t.distance_squared_to(room_positions[c]) <\
					tile_from.distance_squared_to(room_positions[c]):
						tile_from = t
				# Finds the tile in next room that is closest to the former room
				for t in room_to:
					if t.distance_squared_to(room_positions[p]) <\
					tile_to.distance_squared_to(room_positions[p]):
						tile_to = t
				# Create an ordered pair of the two door connections - hallway
				var hallway : PackedVector3Array = [tile_from, tile_to]
				hallways.append(hallway)
				grid_map.set_cell_item(tile_from, 3)
				grid_map.set_cell_item(tile_to, 3)
	
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.update()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	# Define Obstacle Tiles
	for t in grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x, t.z))
	
	for h in hallways: 
		var pos_from : Vector2i = Vector2i(h[0].x, h[0].z)
		var pos_to : Vector2i = Vector2i(h[1].x, h[1].z)
		var hall : PackedVector2Array = astar.get_point_path(pos_from, pos_to) # Array of points
		# of the path from pos_from to pos_to
		
		# Convert the Vector2s into Vector3s
		for t in hall:
			var pos : Vector3i = Vector3i(t.x, 0, t.y)
			if grid_map.get_cell_item(pos) < 0:
				# Place the hallway tiles down
				grid_map.set_cell_item(pos, 1)

func make_room(rec:int):
	if !rec>0:
		return
	
	var width : int = (randi() % (max_room_size - min_room_size)) + min_room_size
	var height : int = (randi() % (max_room_size - min_room_size)) + min_room_size
	
	var start_pos : Vector3i
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - height + 1)
	
	# 
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
			room.append(pos)
	
	room_tiles.append(room)
	# Calculate the center of the room and append it to the room_positions array
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x, 0, avg_z)
	room_positions.append(pos)
