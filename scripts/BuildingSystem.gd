# Edit File: res://scripts/BuildingSystem.gd
extends Node3D

@export var grid_map : GridMap
@export var camera : Camera3D
@export var build_material : StandardMaterial3D
@export var grid_line_material : StandardMaterial3D
@export var cursor_material : StandardMaterial3D
@export var cursor_offset := Vector3(0.5, 0.5, 0.5) # Centered offset for cursor
@export var grid_size := Vector2i(10, 10)

@onready var asp : AudioStreamPlayer3D = $Audio/SoundEffects/ErrorSound

var current_cell := Vector3i.ZERO
var current_rotation := 0
var building_mode := false
var grid_lines := []
var cursor : MeshInstance3D
var cube_size := Vector3(2, 2, 2)

var y_rotations := [0, 6, 12, 18]
var rotation_index := 0

var selected_item := 0

func _ready():
	# Set GridMap cell size
	grid_map.cell_size = cube_size
	
	# Set up MeshLibrary
	var mesh_library = MeshLibrary.new()
	
	# Item 0: Cube
	var cube_mesh = BoxMesh.new()
	cube_mesh.size = cube_size
	mesh_library.create_item(0)
	mesh_library.set_item_mesh(0, cube_mesh)
	mesh_library.set_item_name(0, "Cube")
	
	# Item 1: Sphere
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = cube_size.x / 2.0
	mesh_library.create_item(1)
	mesh_library.set_item_mesh(1, sphere_mesh)
	mesh_library.set_item_name(1, "Sphere")
	
	# Mansion Mesh
	var mansion_mesh = preload("res://scenes/assets/mansion-1.tscn").instantiate()
	mesh_library.create_item(2)
	mesh_library.set_item_mesh(2, mansion_mesh)
	mesh_library.set_item_name(2, "Mansion-1")
	
	#grid_map.mesh_library = mesh_library
	
	# Create visuals
	create_grid_visualization()
	create_cursor()

func align_all_gridmap_models():
	var mesh_lib = grid_map.mesh_library
	if not mesh_lib:
		return

	for i in mesh_lib.get_item_list():
		var mesh = mesh_lib.get_item_mesh(i)
		if mesh:
			var aabb = mesh.get_aabb()
			transform.origin.y = -aabb.size.y / 2.0
			mesh_lib.set_item_mesh_transform(i, transform)

func create_cursor():
	cursor = MeshInstance3D.new()
	var cube = BoxMesh.new()
	cube.size = cube_size * 1 # Slightly smaller for visibility
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
	
	if event.is_action_pressed("rotate_building"):
		rotate_building()
	
	if building_mode and event.is_action_pressed("place_building"):
		place_block()
		align_all_gridmap_models()
	
	if building_mode and event is InputEventMouseMotion:
		update_cursor_position(event.position)
		
	if Input.is_action_just_pressed("push"):
		selected_item += 1

func rotate_building():
	match current_rotation:
		0:
			current_rotation = 16
		16:
			current_rotation = 10
		10:
			current_rotation = 22
		22:
			current_rotation = 0

func place_block():
	if grid_map.get_cell_item(current_cell) == -1:
		grid_map.set_cell_item(current_cell, selected_item, current_rotation)
		print(current_rotation)
	else:
		show_blocked_feedback()

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

func show_blocked_feedback():
	# Play An Error Sound
	asp.play()

	# Show floating text
	var label = Label3D.new()
	label.text = "You Cannot Build Here"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = grid_map.map_to_local(current_cell) + Vector3(0, cube_size.y, 0)
	add_child(label)

	# Animate floating up and fading
	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector3(0, 1, 0), 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.connect("finished", Callable(label, "queue_free"))
