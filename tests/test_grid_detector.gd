extends Node

const GridDetectorScript = preload("res://scripts/grid_detector.gd")

func _ready() -> void:
	var image := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	image.fill(Color("536c45"))
	# Simulate a painted surface so detection cannot rely on a flat background.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var variation := sin(float(x) * 0.031) * 0.025 + cos(float(y) * 0.047) * 0.02
			image.set_pixel(x, y, Color(0.32 + variation, 0.42 + variation, 0.27 + variation, 1.0))
	var grid_color := Color(0.08, 0.09, 0.07, 0.72)
	for x in range(20, 621, 40):
		for y in range(image.get_height()):
			image.set_pixel(x, y, grid_color)
	for y in range(20, 461, 40):
		for x in range(image.get_width()):
			image.set_pixel(x, y, grid_color)
	var result: Dictionary = GridDetectorScript.detect(image)
	if not result.get("found", false):
		push_error("Synthetic square grid was not detected: %s" % result)
		get_tree().quit(1)
		return
	var cells: Vector2i = result["cells"]
	if abs(cells.x - 15) > 1 or abs(cells.y - 11) > 1:
		push_error("Unexpected detected grid size: %s" % cells)
		get_tree().quit(1)
		return
	# Grid lines one full cell from each image edge: the image borders are the
	# missing outer boundaries, so every outer field must remain placeable.
	var edge_grid := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	edge_grid.fill(Color("536c45"))
	for x in range(40, 601, 40):
		for y in range(edge_grid.get_height()):
			edge_grid.set_pixel(x, y, grid_color)
	for y in range(40, 441, 40):
		for x in range(edge_grid.get_width()):
			edge_grid.set_pixel(x, y, grid_color)
	var edge_result: Dictionary = GridDetectorScript.detect(edge_grid)
	if not edge_result.get("found", false):
		push_error("Edge-boundary grid was not detected: %s" % edge_result)
		get_tree().quit(1)
		return
	var edge_origin: Vector2 = edge_result["origin"]
	var edge_cells: Vector2i = edge_result["cells"]
	if edge_origin.x > 0.02 or edge_origin.y > 0.02 or edge_cells.x < 15 or edge_cells.y < 11:
		push_error("Outer grid fields were excluded: origin %s, cells %s" % [edge_origin, edge_cells])
		get_tree().quit(1)
		return
	var edge_end: Vector2 = edge_result["end"]
	var edge_spacing: Vector2 = edge_result["spacing"]
	var reconstructed_end := edge_origin + edge_spacing * Vector2(edge_cells)
	if reconstructed_end.distance_to(edge_end) > 0.001:
		push_error("Detected spacing accumulates drift: reconstructed %s, expected %s" % [reconstructed_end, edge_end])
		get_tree().quit(1)
		return
	# A sparse high-resolution grid must not fall back to a half-cell harmonic
	# merely because its real spacing is wider than 120 analysis pixels.
	var sparse_grid := Image.create(1536, 1536, false, Image.FORMAT_RGBA8)
	sparse_grid.fill(Color("397f70"))
	for x in range(68, 1509, 144):
		for y in range(sparse_grid.get_height()):
			sparse_grid.set_pixel(x, y, grid_color)
	for y in range(68, 1509, 144):
		for x in range(sparse_grid.get_width()):
			sparse_grid.set_pixel(x, y, grid_color)
	var sparse_result: Dictionary = GridDetectorScript.detect(sparse_grid)
	if not sparse_result.get("found", false) or sparse_result["cells"] != Vector2i(10, 10):
		push_error("Sparse wide grid was split into smaller cells: %s" % sparse_result)
		get_tree().quit(1)
		return
	# Every real line must win over the equally periodic every-second-line
	# harmonic, matching dense maps such as RIDDERMOUND-Tomb.
	var dense_grid := Image.create(1400, 1400, false, Image.FORMAT_RGBA8)
	dense_grid.fill(Color("07171b"))
	for x in range(0, dense_grid.get_width(), 70):
		for y in range(dense_grid.get_height()):
			dense_grid.set_pixel(x, y, grid_color)
	for y in range(0, dense_grid.get_height(), 70):
		for x in range(dense_grid.get_width()):
			dense_grid.set_pixel(x, y, grid_color)
	var dense_result: Dictionary = GridDetectorScript.detect(dense_grid)
	var dense_cells: Vector2i = dense_result.get("cells", Vector2i.ZERO)
	if not dense_result.get("found", false) or dense_cells.x < 18 or dense_cells.y < 18:
		push_error("Dense grid incorrectly selected every second line: %s" % dense_result)
		get_tree().quit(1)
		return
	var no_grid := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	for y in range(no_grid.get_height()):
		for x in range(no_grid.get_width()):
			var variation := sin(float(x + y) * 0.029) * 0.03 + cos(float(x - y) * 0.037) * 0.02
			no_grid.set_pixel(x, y, Color(0.31 + variation, 0.43 + variation, 0.28 + variation, 1.0))
	var negative_result: Dictionary = GridDetectorScript.detect(no_grid)
	if negative_result.get("found", false):
		push_error("Grid-free painted terrain produced a false positive: %s" % negative_result)
		get_tree().quit(1)
		return
	print("Grid detector test passed: %s, confidence %.2f" % [cells, result["confidence"]])
	get_tree().quit(0)
