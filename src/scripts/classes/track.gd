class_name Track extends Panel

# TODO: Set size of a frame in pixels so placing clips is accurate 
# TODO: Track scaling when scale signal has been emitted.



var snap_limit: float = 20:
	get: return Project.frame_to_timeline(snap_limit)
var preview: PanelContainer = null



func _ready() -> void:
	# Connecting signals
	Project._on_timeline_scale_changed.connect(adjust_scaling)	
	Project._is_resizing_clip.connect(resizing_clip)
	mouse_exited.connect(remove_preview)

	# Creating preview panel
	preview = preload("res://resources/clip_preview.tscn").instantiate()
	preview.visible = false
	preview.size.y = size.y
	add_child(preview)


func load_project() -> void:
	for l_clip_timestamp: int in Project.tracks[get_index()]:
		add_new_clip(Project.tracks[get_index()][l_clip_timestamp])


func adjust_scaling() -> void: 
	for l_clip: PanelContainer in get_children():
		if not l_clip.name.begins_with('_'): # Preview container
			l_clip.size.x = Project.frame_to_timeline(Project.clips[l_clip.name.to_int()].duration)
			l_clip.position.x = Project.frame_to_timeline(Project.clips[l_clip.name.to_int()].timeline_start)


func _can_drop_data(a_position: Vector2, a_data: Variant) -> bool:
	var l_type: int = -1 
	var l_duration: int = -1
	var l_offset: int = -100

	if typeof(a_data) == TYPE_INT:
		l_type = Project.file_data[a_data].type
		l_duration = Project.file_data[a_data].duration	
		for l_snap_offset: int in snap_limit:
			if _to_fit_or_not_to_fit(range(
					Project.pos_to_frame(a_position.x - preview.size.x / 2) + l_snap_offset,
					Project.pos_to_frame(a_position.x - preview.size.x / 2) + l_duration + l_snap_offset)):
				l_offset = l_snap_offset
				break
			if _to_fit_or_not_to_fit(range(
					Project.pos_to_frame(a_position.x - preview.size.x / 2) - l_snap_offset,
					Project.pos_to_frame(a_position.x - preview.size.x / 2) + l_duration - l_snap_offset)):
				l_offset = -l_snap_offset
				break
	elif a_data[0] == "CLIP":
		l_type = Project.file_data[Project.clips[a_data[1]].file_id].type
		l_duration = Project.file_data[Project.clips[a_data[1]].file_id].duration
		var l_clip: ClipData = Project.clips[a_data[1]]
		for l_snap_offset: int in snap_limit:
			if _to_fit_or_not_to_fit(range(
					Project.pos_to_frame(a_position.x - a_data[3]) + l_snap_offset,
					Project.pos_to_frame(a_position.x - a_data[3]) + l_duration + l_snap_offset),
				range(l_clip.timeline_start, l_clip.timeline_start + l_clip.duration),
				get_index()):
				l_offset = l_snap_offset
				break
			if _to_fit_or_not_to_fit(range(
					Project.pos_to_frame(a_position.x - a_data[3]) - l_snap_offset, 
					Project.pos_to_frame(a_position.x - a_data[3]) + l_duration - l_snap_offset)):
				l_offset = -l_snap_offset
				break
	else:
		remove_preview()
		return false

	if l_offset == -100:
		remove_preview()
		return false
	if l_type == File.VIDEO:
		if typeof(a_data) == TYPE_INT:
			preview.size.x = l_duration / Project.frame_to_timeline(Project._file_data[a_data][0].get_framerate() * Project.frame_rate)
		elif a_data[0] == "CLIP":
			preview.size.x = l_duration / Project.frame_to_timeline(Project._file_data[Project.clips[a_data[1]].file_id][0].get_framerate() * Project.frame_rate)
	elif l_type == File.AUDIO:
		preview.size.x = Project.frame_to_timeline(l_duration * Project.frame_rate)
	else:
		preview.size.x = Project.frame_to_timeline(l_duration)

	if typeof(a_data) == TYPE_INT:
		set_preview(a_position.x - preview.size.x/2 + Project.frame_to_timeline(l_offset))
	else:
		set_preview(a_position.x - a_data[3] + Project.frame_to_timeline(l_offset))
	return true


func _to_fit_or_not_to_fit(a_range: Array, a_excluded_range: Array = [], a_excluded_track: int = -1) -> bool: # returns spaces of adjustment needed if to fit
	for l_range_i: int in a_range:
		if l_range_i < 0:
			return false
		if l_range_i in Project._track_data[get_index()]:
			if get_index() == a_excluded_track and l_range_i in a_excluded_range:
				break
			return false
	return true


func set_preview(a_position: float) -> void:
	preview.position.x = Project.frame_to_timeline(Project.pos_to_frame(a_position))
	preview.visible = true


func remove_preview() -> void:
	preview.visible = false


func _drop_data(_position: Vector2, a_data: Variant) -> void:
	remove_preview()

	if typeof(a_data) == TYPE_INT:
		var l_clip: ClipData = ClipData.new()
		l_clip.file_id = a_data
		l_clip.timeline_start = Project.pos_to_frame(preview.position.x)
		l_clip.duration = Project.file_data[l_clip.file_id].duration
		add_new_clip(Project.add_clip(l_clip, get_index()))
	else: # Array ["CLIP", clip id, clip object, mouse offset]
		Project.remove_clip_timedata(a_data[2].get_track_id(), a_data[1])
		Project.clips[a_data[1]].timeline_start = preview.position.x / Project.timeline_scale
		Project.move_clip(a_data[1], a_data[2].position.x, a_data[2].get_track_id(), get_index())
		a_data[2].queue_free()
		add_new_clip(a_data[1])
	Project._set_frame_forced.emit()


func add_new_clip(a_clip_id: int) -> void:
	var l_clip: PanelContainer = preload("res://resources/clip.tscn").instantiate()
	l_clip.set_clip_properties(a_clip_id)
	l_clip.position.x = Project.frame_to_timeline(Project.clips[a_clip_id].timeline_start)
	l_clip.size.x = preview.size.x
	l_clip.size.y = size.y
	l_clip.mouse_filter = Control.MOUSE_FILTER_PASS

	add_child(l_clip)
	Project._clip_nodes[a_clip_id] = l_clip
	l_clip.name = str(a_clip_id)
	Project.add_clip_timedata(get_index(), a_clip_id)


func resizing_clip(a_clip_id: int, a_track_id: int, a_left: bool) -> void:
	if a_track_id != get_index():
		return
	# TODO: Remember that we need to change Project.tracks[track_id][start_time]
	# We could possibly do this with move_clip and just change the duration before that
	# For video clips we need to change the start time in clip_data
	if Project.file_data[Project.clips[a_clip_id].file_id].type == File.VIDEO:
		print("VIDEO")
	else:
		if a_left:
			var l_clip: ClipData = Project.clips[a_clip_id]
			var l_duration: int = l_clip.duration + (l_clip.timeline_start - Project.pos_to_frame(get_local_mouse_position().x))
			if l_duration < 1:
				return
			if !_to_fit_or_not_to_fit(range(
					Project.pos_to_frame(get_local_mouse_position().x),
					Project.pos_to_frame(get_local_mouse_position().x) + l_duration),
					range(l_clip.timeline_start, l_clip.timeline_start + l_clip.duration),
					get_index()):
				return
			if !_to_fit_or_not_to_fit(range(
					Project.pos_to_frame(get_local_mouse_position().x), 
					Project.pos_to_frame(get_local_mouse_position().x) + l_duration),
					range(l_clip.timeline_start, l_clip.timeline_start + l_clip.duration),
					get_index()):
				return
			Project._clip_nodes[a_clip_id].position.x = l_clip.timeline_start - (l_clip.timeline_start - Project.pos_to_frame(get_local_mouse_position().x))
			Project._clip_nodes[a_clip_id].size.x = l_duration
		else:
			var l_clip: ClipData = Project.clips[a_clip_id]
			var l_duration: int = pos_to_frame(get_local_mouse_position().x) - l_clip.timeline_start
			if l_duration < 1:
				return
			if !_to_fit_or_not_to_fit(range(
					Project.pos_to_frame(get_local_mouse_position().x),
					Project.pos_to_frame(get_local_mouse_position().x) + l_duration),
					range(l_clip.timeline_start, l_clip.timeline_start + l_clip.duration),
					get_index()):
				return
			if !_to_fit_or_not_to_fit(range(
					Project.pos_to_frame(get_local_mouse_position().x), 
					Project.pos_to_frame(get_local_mouse_position().x) + l_duration),
					range(l_clip.timeline_start, l_clip.timeline_start + l_clip.duration),
					get_index()):
				return
			Project._clip_nodes[a_clip_id].size.x = l_duration


func reset_clip(a_clip_id: int) -> void:
	Project._clip_nodes[a_clip_id].position.x = Project.frame_to_timeline(Project.clips[a_clip_id].timeline_start)
	Project._clip_nodes[a_clip_id].size.x = Project.frame_to_timeline(Project.clips[a_clip_id].duration)
