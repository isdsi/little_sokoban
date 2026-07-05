extends Panel

var dragging = false
var drag_offset = Vector2()
var gamepad_speed = 500.0 # Pixels per second

var style_box = StyleBoxFlat.new()

func _ready():
	# Configure visual aesthetics (Modern round card with shadow)
	style_box.bg_color = Color(0.18, 0.5, 0.9, 1.0)
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_right = 12
	style_box.corner_radius_bottom_left = 12
	
	style_box.shadow_color = Color(0, 0, 0, 0.15)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(0, 4)
	
	add_theme_stylebox_override("panel", style_box)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _process(delta):
	# Don't move via gamepad/keyboard if we are actively dragging with mouse
	if dragging:
		return
		
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length() > 0:
		var target_pos = position + input_dir * gamepad_speed * delta
		var viewport_rect = get_viewport_rect()
		target_pos.x = clamp(target_pos.x, 0.0, viewport_rect.size.x - size.x)
		target_pos.y = clamp(target_pos.y, 0.0, viewport_rect.size.y - size.y)
		position = target_pos

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = position - get_global_mouse_position()
				# Active/Pressed state styling
				style_box.bg_color = Color(0.12, 0.4, 0.75, 1.0)
				style_box.shadow_size = 4
				style_box.shadow_offset = Vector2(0, 2)
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				dragging = false
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				# Determine if we are still hovering
				if get_rect().has_point(get_local_mouse_position()):
					style_box.bg_color = Color(0.25, 0.6, 1.0, 1.0)
					style_box.shadow_size = 12
					style_box.shadow_offset = Vector2(0, 6)
				else:
					style_box.bg_color = Color(0.18, 0.5, 0.9, 1.0)
					style_box.shadow_size = 8
					style_box.shadow_offset = Vector2(0, 4)
	elif event is InputEventMouseMotion:
		if dragging:
			var target_pos = get_global_mouse_position() + drag_offset
			var viewport_rect = get_viewport_rect()
			target_pos.x = clamp(target_pos.x, 0.0, viewport_rect.size.x - size.x)
			target_pos.y = clamp(target_pos.y, 0.0, viewport_rect.size.y - size.y)
			position = target_pos

func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER:
			if not dragging:
				# Hover state styling
				style_box.bg_color = Color(0.25, 0.6, 1.0, 1.0)
				style_box.shadow_size = 12
				style_box.shadow_offset = Vector2(0, 6)
		NOTIFICATION_MOUSE_EXIT:
			if not dragging:
				# Normal state styling
				style_box.bg_color = Color(0.18, 0.5, 0.9, 1.0)
				style_box.shadow_size = 8
				style_box.shadow_offset = Vector2(0, 4)

