# Edit File: res://scripts/BuildingSystem.gd
extends Node3D

@export var grid_map : GridMap
@export var camera : Camera3D
@export var build_material : StandardMaterial3D
@export var grid_line_material : StandardMaterial3D
@export var cursor_material : StandardMaterial3D
@export var cursor_offset := Vector3(0.5, 0.5, 0.5) # Centered offset for cursor
@export var grid_size := Vector2i(10, 10)

var current_cell := Vector3i.ZERO
var current_rotation := 0
var building_mode := false
var grid_lines := []
var cursor : MeshInstance3D
var cube_size := Vector3(2, 2, 2) # Match to actual cube size

func _ready():
	# Set GridMap cell size
	grid_map.cell_size = cube_size
	
	# Set up MeshLibrary
	var mesh_library = MeshLibrary.new()
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = cube_size
	mesh_library.create_item(0)
	mesh_library.set_item_mesh(0, cube_mesh)
	mesh_library.set_item_name(0, "Cube")
	grid_map.mesh_library = mesh_library
	
	# Create visuals
	create_grid_visualization()
	create_cursor()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func create_cursor():
	cursor = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = cube_size * 0.95 # Slightly smaller for visibility
	cube.material = cursor_material
	cursor.mesh = cube
	add_child(cursor)
	cursor.visible = false

func create_grid_visualization():
	# Remove old lines
	for line in grid_lines:
		line.queue_free()
	grid_lines.clear()
	
	var total_width = grid_size.x * cube_size.x
	var total_depth = grid_size.y * cube_size.z
	
	# X axis lines
	for x in range(-grid_size.x, grid_size.x + 1):
		var line = MeshInstance3D.new()
		line.mesh = ImmediateMesh.new()
		line.mesh.surface_begin(Mesh.PRIMITIVE_LINES, grid_line_material)
		line.mesh.surface_add_vertex(Vector3(x * cube_size.x, 0, -total_depth/2))
		line.mesh.surface_add_vertex(Vector3(x * cube_size.x, 0, total_depth/2))
		line.mesh.surface_end()
		add_child(line)
		grid_lines.append(line)
		line.visible = building_mode
	
	# Z axis lines
	for z in range(-grid_size.y, grid_size.y + 1):
		var line = MeshInstance3D.new()
		line.mesh = ImmediateMesh.new()
		line.mesh.surface_begin(Mesh.PRIMITIVE_LINES, grid_line_material)
		line.mesh.surface_add_vertex(Vector3(-total_width/2, 0, z * cube_size.z))
		line.mesh.surface_add_vertex(Vector3(total_width/2, 0, z * cube_size.z))
		line.mesh.surface_end()
		add_child(line)
		grid_lines.append(line)
		line.visible = building_mode

func _input(event):
	if event.is_action_pressed("toggle_build_mode"):
		building_mode = !building_mode
		for line in grid_lines:
			line.visible = building_mode
		cursor.visible = building_mode
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if building_mode else Input.MOUSE_MODE_VISIBLE)
	
	if event.is_action_pressed("rotate_building"):
		current_rotation = (current_rotation + 1) % 24
	
	if building_mode and event.is_action_pressed("place_building"):
		place_block()
	
	if building_mode and event is InputEventMouseMotion:
		update_cursor_position(event.position)

func place_block():
	grid_map.set_cell_item(current_cell, 0, current_rotation)

func update_cursor_position(mouse_position):
	var ray_length = 1000
	var from = camera.project_ray_origin(mouse_position)
	var to = from + camera.project_ray_normal(mouse_position) * ray_length
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		current_cell = grid_map.local_to_map(result.position)

		# If we're under the map, move the cursor up
		if current_cell.y < 0:
			current_cell.y = 0

		cursor.global_transform.origin = grid_map.map_to_local(current_cell)


func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
