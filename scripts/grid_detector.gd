class_name GridDetector
extends RefCounted

# Preserve thin and dotted grid lines on high-resolution maps. At 512 px,
# one-pixel dots in a 4K source can disappear during bilinear downscaling.
const MAX_ANALYSIS_SIZE := 1536
const MIN_GRID_LINES := 5
const MIN_SPACING := 10

static func detect(source: Image) -> Dictionary:
	if source.is_empty() or source.get_width() < 80 or source.get_height() < 80:
		return {"found": false, "reason": "Image is too small"}
	var image := source.duplicate()
	var original_size := Vector2(source.get_width(), source.get_height())
	var scale := minf(1.0, float(MAX_ANALYSIS_SIZE) / maxf(original_size.x, original_size.y))
	if scale < 1.0:
		image.resize(maxi(1, roundi(original_size.x * scale)), maxi(1, roundi(original_size.y * scale)), Image.INTERPOLATE_BILINEAR)
	var vertical_scores := _axis_scores(image, true)
	var horizontal_scores := _axis_scores(image, false)
	var vertical := _find_period(vertical_scores)
	var horizontal := _find_period(horizontal_scores)
	if not vertical.get("found", false) or not horizontal.get("found", false):
		return {"found": false, "reason": "No regular square grid found"}
	var spacing_x_original: float = float(vertical["spacing"]) / scale
	var spacing_y_original: float = float(horizontal["spacing"]) / scale
	var normalized := _normalize_square_harmonics(spacing_x_original, spacing_y_original)
	spacing_x_original = normalized.x
	spacing_y_original = normalized.y
	var square_ratio := spacing_x_original / spacing_y_original
	if square_ratio < 0.82 or square_ratio > 1.22:
		return {"found": false, "reason": "Detected lines are not a square grid (%.1f × %.1f px)" % [spacing_x_original, spacing_y_original]}
	var first_x: float = float(vertical["first"]) / scale
	var first_y: float = float(horizontal["first"]) / scale
	var last_x: float = float(vertical["last"]) / scale
	var last_y: float = float(horizontal["last"]) / scale
	var extended_x := _extend_axis_to_image_edges(first_x, last_x, spacing_x_original, original_size.x)
	var extended_y := _extend_axis_to_image_edges(first_y, last_y, spacing_y_original, original_size.y)
	first_x = extended_x.x
	last_x = extended_x.y
	first_y = extended_y.x
	last_y = extended_y.y
	var columns := maxi(1, roundi((last_x - first_x) / spacing_x_original))
	var rows := maxi(1, roundi((last_y - first_y) / spacing_y_original))
	if columns < 4 or rows < 4:
		return {"found": false, "reason": "Too few complete grid cells found"}
	return {
		"found": true,
		"origin": Vector2(first_x / original_size.x, first_y / original_size.y),
		# Derive spacing from both outer anchors so fractional detection error does
		# not accumulate toward the bottom-right of large maps.
		"spacing": Vector2(
			(last_x - first_x) / float(columns) / original_size.x,
			(last_y - first_y) / float(rows) / original_size.y
		),
		"end": Vector2(last_x / original_size.x, last_y / original_size.y),
		"cells": Vector2i(columns, rows),
		"confidence": minf(float(vertical["confidence"]), float(horizontal["confidence"]))
	}

static func _extend_axis_to_image_edges(first: float, last: float, spacing: float, image_length: float) -> Vector2:
	# A landscape often omits its outer border line while leaving a complete cell
	# between the first/last visible grid line and the image edge. Treat the image
	# edge as that missing boundary, but ignore margins smaller than 65% of a cell.
	var result := Vector2(first, last)
	var leading_margin := first
	var trailing_margin := image_length - last
	var leading_cells := floori((leading_margin + spacing * 0.35) / spacing)
	var trailing_cells := floori((trailing_margin + spacing * 0.35) / spacing)
	if leading_cells > 0:
		result.x = maxf(0.0, first - float(leading_cells) * spacing)
	if trailing_cells > 0:
		result.y = minf(image_length, last + float(trailing_cells) * spacing)
	return result

static func _normalize_square_harmonics(spacing_x: float, spacing_y: float) -> Vector2:
	var result := Vector2(spacing_x, spacing_y)
	var ratio := maxf(spacing_x, spacing_y) / minf(spacing_x, spacing_y)
	for harmonic in range(2, 5):
		if absf(ratio - float(harmonic)) <= 0.12:
			if spacing_x > spacing_y:
				result.x /= float(harmonic)
			else:
				result.y /= float(harmonic)
			break
	return result

static func _axis_scores(image: Image, vertical: bool) -> PackedFloat32Array:
	var length := image.get_width() if vertical else image.get_height()
	var cross_length := image.get_height() if vertical else image.get_width()
	var scores := PackedFloat32Array()
	scores.resize(length)
	for position in range(1, length - 1):
		var total := 0.0
		var samples := 0
		for cross in range(0, cross_length, 2):
			var center := image.get_pixel(position, cross) if vertical else image.get_pixel(cross, position)
			var before := image.get_pixel(position - 1, cross) if vertical else image.get_pixel(cross, position - 1)
			var after := image.get_pixel(position + 1, cross) if vertical else image.get_pixel(cross, position + 1)
			var neighbor_luminance := (before.get_luminance() + after.get_luminance()) * 0.5
			total += absf(center.get_luminance() - neighbor_luminance)
			samples += 1
		scores[position] = total / maxf(1.0, float(samples))
	return _smooth(scores)

static func _smooth(values: PackedFloat32Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(values.size())
	for index in values.size():
		var total := 0.0
		var count := 0
		for offset in range(-1, 2):
			var sample := index + offset
			if sample >= 0 and sample < values.size():
				total += values[sample]
				count += 1
		result[index] = total / maxf(1.0, float(count))
	return result

static func _find_period(scores: PackedFloat32Array) -> Dictionary:
	if scores.size() < MIN_SPACING * MIN_GRID_LINES:
		return {"found": false}
	var mean := 0.0
	for score in scores:
		mean += score
	mean /= float(scores.size())
	var best := {"quality": 0.0}
	var candidates := {}
	# Large maps with relatively few cells can exceed 120 px between lines even
	# after analysis downscaling. Search the full range that can still contain the
	# minimum required number of grid lines, otherwise a half-spacing harmonic can
	# incorrectly split every real cell into four.
	var max_spacing := floori(float(scores.size()) / float(MIN_GRID_LINES - 1))
	for spacing in range(MIN_SPACING, max_spacing + 1):
		for offset in range(spacing):
			var line_scores: Array[float] = []
			var candidate_position := offset
			while candidate_position < scores.size():
				line_scores.append(_local_peak(scores, candidate_position))
				candidate_position += spacing
			if line_scores.size() < MIN_GRID_LINES:
				continue
			line_scores.sort()
			var reliable_count := maxi(MIN_GRID_LINES, int(line_scores.size() * 0.65))
			var reliable_total := 0.0
			for index in range(line_scores.size() - reliable_count, line_scores.size()):
				reliable_total += line_scores[index]
			var line_mean := reliable_total / float(reliable_count)
			var quality := line_mean / maxf(mean, 0.0001)
			if quality > float(candidates.get(spacing, {"quality": 0.0})["quality"]):
				candidates[spacing] = {"quality": quality, "spacing": spacing, "offset": offset}
			if quality > float(best["quality"]):
				best = {"quality": quality, "spacing": spacing, "offset": offset}
	if float(best["quality"]) < 1.55:
		return {"found": false}
	best = _prefer_supported_finer_harmonic(best, candidates)
	var spacing: int = best["spacing"]
	var offset: int = best["offset"]
	var threshold := mean * 1.25
	var lines: Array[int] = []
	var position := offset
	while position < scores.size():
		var peak_position := _local_peak_position(scores, position)
		if scores[peak_position] >= threshold:
			lines.append(peak_position)
		position += spacing
	if lines.size() < MIN_GRID_LINES:
		return {"found": false}
	return {
		"found": true,
		"spacing": spacing,
		"first": lines.front(),
		"last": lines.back(),
		"confidence": clampf((float(best["quality"]) - 1.0) / 2.0, 0.0, 1.0)
	}

static func _prefer_supported_finer_harmonic(best: Dictionary, candidates: Dictionary) -> Dictionary:
	# A grid remains periodic at 2× and 3× its real spacing. Prefer the finer
	# candidate only when its full line sequence is almost as strong, which means
	# the intervening lines are real. Weak half-cell texture therefore does not
	# subdivide genuinely large squares.
	var result := best
	for _pass in range(4):
		var next := result
		var coarse_spacing := int(result["spacing"])
		for harmonic in range(5, 1, -1):
			var expected := float(coarse_spacing) / float(harmonic)
			var finer := {"quality": 0.0}
			for candidate_spacing in range(maxi(MIN_SPACING, roundi(expected) - 3), roundi(expected) + 4):
				if candidates.has(candidate_spacing) and float(candidates[candidate_spacing]["quality"]) > float(finer["quality"]):
					finer = candidates[candidate_spacing]
			if float(finer["quality"]) >= float(result["quality"]) * 0.735:
				next = finer
				break
		if next == result:
			break
		result = next
	return result

static func _local_peak(scores: PackedFloat32Array, position: int) -> float:
	return scores[_local_peak_position(scores, position)]

static func _local_peak_position(scores: PackedFloat32Array, position: int) -> int:
	var best_position := clampi(position, 0, scores.size() - 1)
	var best_score := scores[best_position]
	for candidate in range(maxi(0, position - 2), mini(scores.size(), position + 3)):
		if scores[candidate] > best_score:
			best_score = scores[candidate]
			best_position = candidate
	return best_position
