extends Control

var texture_heart: Texture2D
var texture_box_x: Texture2D
var current_theme = "default"
var menu_callback: Callable
const TEXTURE_ARROW_UP = preload("res://assets/arrow_up.png")
const TEXTURE_ARROW_DOWN = preload("res://assets/arrow_down.png")
const TEXTURE_ARROW_LEFT = preload("res://assets/arrow_left.png")
const TEXTURE_ARROW_RIGHT = preload("res://assets/arrow_right.png")

var current_level_idx = 0
var current_layout = []

var cell_size = 44.0
var cols = 19
var rows = 11

# Game state
var player_pos = Vector2i()
var box_positions = []
var walls = {}
var goals = {}

var undo_stack = []
var box_nodes = []
var player_node: Panel
var board_container: Control
var hearts_container: HBoxContainer

# Controls & Animations
var is_animating = false
var path_to_walk = []
var walking = false
var swipe_start_pos = Vector2()
var min_swipe_length = 50.0

# Gameplay stats
var score = 0
var time_remaining = 300.0
var lives = 3
var game_over = false
var victory = false

# Pathfinding
var astar = AStarGrid2D.new()

# Styleboxes for dynamic rendering
var wall_style = StyleBoxTexture.new()
var floor_style = StyleBoxTexture.new()
var goal_style = StyleBoxTexture.new()
var box_style = StyleBoxTexture.new()
var box_on_goal_style = StyleBoxTexture.new()
var player_style = StyleBoxTexture.new()

# HUD Nodes (will be linked from the scene)
@onready var score_label = $HUD/ScoreLabel
@onready var time_label = $HUD/TimeLabel
@onready var lives_label = $HUD/LivesLabel
@onready var title_label = $HUD/TitleLabel

@onready var victory_overlay = $VictoryOverlay
@onready var victory_score_label = $VictoryOverlay/VBox/ScoreLabel
@onready var game_over_overlay = $GameOverOverlay

func _ready():
	# Configure StyleBoxes programmatically for visual excellence
	setup_styles()
	
	# Configure D-pad arrow textures and clear text
	$TouchControls/Dpad/Up.icon = TEXTURE_ARROW_UP
	$TouchControls/Dpad/Up.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$TouchControls/Dpad/Up.text = ""
	$TouchControls/Dpad/Down.icon = TEXTURE_ARROW_DOWN
	$TouchControls/Dpad/Down.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$TouchControls/Dpad/Down.text = ""
	$TouchControls/Dpad/Left.icon = TEXTURE_ARROW_LEFT
	$TouchControls/Dpad/Left.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$TouchControls/Dpad/Left.text = ""
	$TouchControls/Dpad/Right.icon = TEXTURE_ARROW_RIGHT
	$TouchControls/Dpad/Right.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$TouchControls/Dpad/Right.text = ""
	
	# Initialize HUD hearts container
	lives_label.text = "LIVES:"
	hearts_container = HBoxContainer.new()
	hearts_container.name = "HeartsContainer"
	hearts_container.size = Vector2(150, 30)
	$HUD.add_child(hearts_container)
	# Position to the right of LivesLabel
	hearts_container.position = lives_label.position + Vector2(80, 0)
	
	# Setup AStarGrid2D
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	# Load Stage 1
	load_level(0)
	
	# Resize buttons container and create Menu button
	$HUD/Buttons.size = Vector2(300, 50)
	var undo_btn = $HUD/Buttons/UndoButton
	var menu_btn = Button.new()
	menu_btn.name = "MenuButton"
	menu_btn.size = Vector2(90, 36)
	menu_btn.position = Vector2(204, 0)
	menu_btn.add_theme_font_size_override("font_size", 14)
	menu_btn.add_theme_stylebox_override("normal", undo_btn.get_theme_stylebox("normal"))
	menu_btn.add_theme_stylebox_override("pressed", undo_btn.get_theme_stylebox("pressed"))
	menu_btn.add_theme_stylebox_override("hover", undo_btn.get_theme_stylebox("hover"))
	menu_btn.pressed.connect(open_menu_dialog)
	$HUD/Buttons.add_child(menu_btn)

	# Connect UI buttons
	$HUD/Buttons/UndoButton.pressed.connect(undo)
	$HUD/Buttons/RestartButton.pressed.connect(reset_level)
	
	# Connect Touch Controls (D-pad)
	$TouchControls/Dpad/Up.pressed.connect(func(): handle_direction_input(Vector2i.UP))
	$TouchControls/Dpad/Down.pressed.connect(func(): handle_direction_input(Vector2i.DOWN))
	$TouchControls/Dpad/Left.pressed.connect(func(): handle_direction_input(Vector2i.LEFT))
	$TouchControls/Dpad/Right.pressed.connect(func(): handle_direction_input(Vector2i.RIGHT))
	
	# Connect Overlays
	$VictoryOverlay/VBox/RestartButton.pressed.connect(load_next_level)
	$GameOverOverlay/VBox/RetryButton.pressed.connect(restart_full_game)
	
	# Setup button Xbox prompts
	setup_button_xbox_prompt($HUD/Buttons/UndoButton, "Y", Color(0.98, 0.82, 0.08), "UNDO")
	setup_button_xbox_prompt($HUD/Buttons/RestartButton, "X", Color(0.25, 0.61, 1.0), "RESET")
	setup_button_xbox_prompt(menu_btn, "M", Color(0.93, 0.28, 0.54), "MENU")
	setup_button_xbox_prompt($VictoryOverlay/VBox/RestartButton, "A", Color(0.29, 0.85, 0.38), "NEXT STAGE")
	setup_button_xbox_prompt($GameOverOverlay/VBox/RetryButton, "A", Color(0.29, 0.85, 0.38), "TRY AGAIN")
	
	# Prevent UI buttons from capturing keyboard/gamepad focus
	disable_all_button_focus(self)
	
	# Initial UI update
	update_hud()

func setup_button_xbox_prompt(btn: Button, xbox_char: String, xbox_color: Color, action_text: String):
	btn.text = ""
	
	# Clear any previous child containers
	var old_container = btn.get_node_or_null("HBoxPrompt")
	if old_container:
		old_container.queue_free()
		
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxPrompt"
	hbox.size = btn.size
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(hbox)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Left Label (Xbox Prompt)
	var prompt_lbl = Label.new()
	prompt_lbl.text = "[%s]" % xbox_char
	prompt_lbl.add_theme_color_override("font_color", xbox_color)
	prompt_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(prompt_lbl)
	
	# Right Label (Action Text)
	var action_lbl = Label.new()
	action_lbl.text = " %s" % action_text
	action_lbl.add_theme_color_override("font_color", Color.WHITE)
	action_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(action_lbl)

func disable_all_button_focus(node: Node):
	if node is Button:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		disable_all_button_focus(child)

func load_theme_texture(theme_name: String, filename: String) -> Texture2D:
	var path = "res://assets/" + theme_name + "/" + filename
	if ResourceLoader.exists(path):
		return load(path)
	else:
		return load("res://assets/default/" + filename)

func setup_styles():
	wall_style.texture = load_theme_texture(current_theme, "wall.png")
	floor_style.texture = load_theme_texture(current_theme, "floor.png")
	goal_style.texture = load_theme_texture(current_theme, "goal.png")
	box_style.texture = load_theme_texture(current_theme, "box.png")
	box_on_goal_style.texture = load_theme_texture(current_theme, "box_on_goal.png")
	player_style.texture = load_theme_texture(current_theme, "player.png")
	texture_heart = load_theme_texture(current_theme, "heart.png")
	texture_box_x = load_theme_texture(current_theme, "box_x.png")

func load_level(idx: int):
	current_level_idx = idx
	var raw_layout = LevelsData.LEVELS[current_level_idx]
	rows = raw_layout.size()
	cols = 0
	for line in raw_layout:
		cols = max(cols, line.length())
	
	# Calculate dynamic cell size to fit 880x480 screen area
	var max_w = 880.0
	var max_h = 480.0
	var scale_x = max_w / cols
	var scale_y = max_h / rows
	cell_size = floor(min(44.0, min(scale_x, scale_y)))
	
	current_layout.clear()
	for line in raw_layout:
		var padded_line = line
		while padded_line.length() < cols:
			padded_line += " "
		current_layout.append(padded_line)
	
	parse_layout()
	
	# Update AStarGrid2D
	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2(cell_size, cell_size)
	astar.update()
	
	setup_board()
	update_hud()

func parse_layout():
	box_positions.clear()
	walls.clear()
	goals.clear()
	
	for r in range(rows):
		var line = current_layout[r]
		for c in range(cols):
			var cell = line[c]
			var pos = Vector2i(c, r)
			match cell:
				"#":
					walls[pos] = true
				".":
					goals[pos] = true
				"$":
					box_positions.append(pos)
				"@":
					player_pos = pos
				"*":
					goals[pos] = true
					box_positions.append(pos)
				"+":
					goals[pos] = true
					player_pos = pos

func get_inside_cells() -> Dictionary:
	var inside = {}
	if current_layout.is_empty():
		return inside
		
	var queue = [player_pos]
	var visited = {}
	visited[player_pos] = true
	
	while not queue.is_empty():
		var curr = queue.pop_front()
		inside[curr] = true
		
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = curr + dir
			if neighbor.x >= 0 and neighbor.x < cols and neighbor.y >= 0 and neighbor.y < rows:
				if not visited.has(neighbor) and current_layout[neighbor.y][neighbor.x] != "#":
					visited[neighbor] = true
					queue.append(neighbor)
	return inside

func setup_board():
	if board_container:
		board_container.queue_free()
		
	board_container = Control.new()
	board_container.size = Vector2(cols * cell_size, rows * cell_size)
	var target_pos = (Vector2(1152, 648) - board_container.size) / 2
	board_container.position = Vector2i(target_pos.x, target_pos.y - 25)
	add_child(board_container)
	move_child(board_container, 1) # Draw behind HUD and overlays (so overlays render on top of the board)
	# Make sure board container receives input for clicking
	board_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var inside_cells = get_inside_cells()
	
	# Instantiating tiles
	for r in range(rows):
		for c in range(cols):
			var cell = current_layout[r][c]
			var pos = Vector2i(c, r)
			
			if inside_cells.has(pos):
				# Floor
				var floor_tile = Panel.new()
				floor_tile.size = Vector2(cell_size, cell_size)
				floor_tile.position = Vector2(c, r) * cell_size
				floor_tile.add_theme_stylebox_override("panel", floor_style)
				board_container.add_child(floor_tile)
				
			if cell == "#":
				# Wall
				var wall_tile = Panel.new()
				wall_tile.size = Vector2(cell_size, cell_size)
				wall_tile.position = Vector2(c, r) * cell_size
				wall_tile.add_theme_stylebox_override("panel", wall_style)
				board_container.add_child(wall_tile)
				
			elif cell == "." or cell == "*" or cell == "+":
				# Goal
				var goal_tile_size = cell_size * (20.0 / 44.0)
				var goal_tile = Panel.new()
				goal_tile.size = Vector2(goal_tile_size, goal_tile_size)
				goal_tile.position = (Vector2(c, r) * cell_size + Vector2((cell_size - goal_tile_size)/2, (cell_size - goal_tile_size)/2)).round()
				goal_tile.add_theme_stylebox_override("panel", goal_style)
				board_container.add_child(goal_tile)
				
	# Instantiate Player
	var p_size = cell_size * (34.0 / 44.0)
	player_node = Panel.new()
	player_node.size = Vector2(p_size, p_size)
	player_node.position = (Vector2(player_pos) * cell_size + Vector2((cell_size - p_size)/2, (cell_size - p_size)/2)).round()
	player_node.add_theme_stylebox_override("panel", player_style)
	board_container.add_child(player_node)
	
	# Instantiate Boxes
	box_nodes.clear()
	for i in range(box_positions.size()):
		var b_pos = box_positions[i]
		var box_tile = Panel.new()
		var b_size = cell_size * (38.0 / 44.0)
		box_tile.size = Vector2(b_size, b_size)
		var box_offset = (cell_size - b_size) / 2
		box_tile.position = (Vector2(b_pos) * cell_size + Vector2(box_offset, box_offset)).round()
		
		if goals.has(b_pos):
			box_tile.add_theme_stylebox_override("panel", box_on_goal_style)
		else:
			box_tile.add_theme_stylebox_override("panel", box_style)
			
		board_container.add_child(box_tile)
		box_nodes.append(box_tile)
		
		# Crate style X mark
		var x_mark = TextureRect.new()
		x_mark.texture = texture_box_x
		x_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		x_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		x_mark.size = Vector2(b_size, b_size)
		x_mark.position = Vector2(0, 0)
		box_tile.add_child(x_mark)

func _process(delta):
	# Countdown timer
	if not game_over and not victory:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			lose_life()
		update_hud()
		
	# Pathfinding walking execution
	if walking and not path_to_walk.is_empty():
		if not is_animating:
			var next_pos = path_to_walk.pop_front()
			var dir = next_pos - player_pos
			var moved = try_move(dir)
			if not moved:
				# Stopped or path got blocked
				walking = false
				path_to_walk.clear()

func handle_direction_input(dir: Vector2i):
	# Interrupt walking on manual arrow input
	walking = false
	path_to_walk.clear()
	try_move(dir)

func open_debug_goto_dialog():
	if has_node("DebugGotoPopup"):
		return
		
	var popup = Control.new()
	popup.name = "DebugGotoPopup"
	popup.size = Vector2(250, 80)
	popup.position = (Vector2(1152, 648) - popup.size) / 2
	add_child(popup)
	
	var bg_panel = Panel.new()
	bg_panel.size = popup.size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	panel_style.set_corner_radius_all(10)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.22, 0.75, 0.97, 0.8)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 15
	bg_panel.add_theme_stylebox_override("panel", panel_style)
	popup.add_child(bg_panel)
	
	var vbox = VBoxContainer.new()
	vbox.size = popup.size - Vector2(20, 20)
	vbox.position = Vector2(10, 10)
	popup.add_child(vbox)
	
	var label = Label.new()
	label.text = "GOTO STAGE (1-50):"
	label.add_theme_color_override("font_color", Color(0.22, 0.75, 0.97))
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Enter stage num..."
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.max_length = 2
	vbox.add_child(line_edit)
	
	line_edit.grab_focus.call_deferred()
	
	line_edit.text_submitted.connect(func(new_text: String):
		var num = new_text.to_int()
		if num >= 1 and num <= 50:
			load_level(num - 1)
			victory_overlay.visible = false
			game_over_overlay.visible = false
			victory = false
			game_over = false
		popup.queue_free()
	)
	
	line_edit.gui_input.connect(func(ie: InputEvent):
		if ie is InputEventKey and ie.pressed:
			if ie.keycode == KEY_ESCAPE:
				popup.queue_free()
	)

func open_menu_dialog():
	if has_node("SokobanMenu"):
		get_node("SokobanMenu").queue_free()
		return
		
	var menu = Control.new()
	menu.name = "SokobanMenu"
	menu.size = Vector2(300, 240)
	menu.position = (Vector2(1152, 648) - menu.size) / 2
	add_child(menu)
	
	var bg_panel = Panel.new()
	bg_panel.size = menu.size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.15, 0.95)
	panel_style.set_corner_radius_all(12)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.93, 0.28, 0.54, 0.8)
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 20
	bg_panel.add_theme_stylebox_override("panel", panel_style)
	menu.add_child(bg_panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size = menu.size - Vector2(40, 40)
	vbox.position = Vector2(20, 20)
	vbox.add_theme_constant_override("separation", 12)
	menu.add_child(vbox)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "SOKOBAN MENU"
	title.add_theme_color_override("font_color", Color(0.93, 0.28, 0.54))
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var content_area = VBoxContainer.new()
	content_area.name = "ContentArea"
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("separation", 10)
	vbox.add_child(content_area)
	
	menu_callback = func():
		for child in content_area.get_children():
			child.queue_free()
			
		var theme_btn = Button.new()
		theme_btn.text = "Theme"
		theme_btn.custom_minimum_size = Vector2(0, 36)
		content_area.add_child(theme_btn)
		
		var license_btn = Button.new()
		license_btn.text = "License"
		license_btn.custom_minimum_size = Vector2(0, 36)
		content_area.add_child(license_btn)
		
		var close_btn = Button.new()
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(0, 36)
		content_area.add_child(close_btn)
		
		var base_btn = $HUD/Buttons/UndoButton
		for btn in [theme_btn, license_btn, close_btn]:
			btn.add_theme_stylebox_override("normal", base_btn.get_theme_stylebox("normal"))
			btn.add_theme_stylebox_override("pressed", base_btn.get_theme_stylebox("pressed"))
			btn.add_theme_stylebox_override("hover", base_btn.get_theme_stylebox("hover"))
			btn.focus_mode = Control.FOCUS_NONE
			
		close_btn.pressed.connect(func(): menu.queue_free())
		
		theme_btn.pressed.connect(func():
			for child in content_area.get_children():
				child.queue_free()
				
			var def_btn = Button.new()
			def_btn.text = "Default" + (" (Active)" if current_theme == "default" else "")
			def_btn.custom_minimum_size = Vector2(0, 36)
			content_area.add_child(def_btn)
			
			var kenney_btn = Button.new()
			kenney_btn.text = "Kenney" + (" (Active)" if current_theme == "kenney" else "")
			kenney_btn.custom_minimum_size = Vector2(0, 36)
			content_area.add_child(kenney_btn)
			
			var back_btn = Button.new()
			back_btn.text = "Back"
			back_btn.custom_minimum_size = Vector2(0, 36)
			content_area.add_child(back_btn)
			
			for btn in [def_btn, kenney_btn, back_btn]:
				btn.add_theme_stylebox_override("normal", base_btn.get_theme_stylebox("normal"))
				btn.add_theme_stylebox_override("pressed", base_btn.get_theme_stylebox("pressed"))
				btn.add_theme_stylebox_override("hover", base_btn.get_theme_stylebox("hover"))
				btn.focus_mode = Control.FOCUS_NONE
				
			back_btn.pressed.connect(menu_callback)
			
			def_btn.pressed.connect(func():
				current_theme = "default"
				setup_styles()
				setup_board()
				update_hud()
				menu.queue_free()
			)
			
			kenney_btn.pressed.connect(func():
				current_theme = "kenney"
				setup_styles()
				setup_board()
				update_hud()
				menu.queue_free()
			)
		)
		
		license_btn.pressed.connect(func():
			menu.size = Vector2(400, 320)
			menu.position = (Vector2(1152, 648) - menu.size) / 2
			bg_panel.size = menu.size
			vbox.size = menu.size - Vector2(40, 40)
			
			for child in content_area.get_children():
				child.queue_free()
				
			var scroll = ScrollContainer.new()
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content_area.add_child(scroll)
			
			var text_lbl = Label.new()
			text_lbl.text = "LICENSE INFORMATION\n\n" \
				+ "XSokoban Map Data:\n" \
				+ "Public Domain / Benchmark Set\n\n" \
				+ "Kenney Sokoban Assets:\n" \
				+ "CC0 1.0 Universal\n" \
				+ "Free to use in personal/commercial work\n\n" \
				+ "Little Sokoban Game:\n" \
				+ "MIT License\n" \
				+ "Copyright (c) 2026 Ringos"
			text_lbl.add_theme_font_size_override("font_size", 12)
			text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(text_lbl)
			
			var back_btn = Button.new()
			back_btn.text = "Back"
			back_btn.custom_minimum_size = Vector2(0, 36)
			content_area.add_child(back_btn)
			
			back_btn.add_theme_stylebox_override("normal", base_btn.get_theme_stylebox("normal"))
			back_btn.add_theme_stylebox_override("pressed", base_btn.get_theme_stylebox("pressed"))
			back_btn.add_theme_stylebox_override("hover", base_btn.get_theme_stylebox("hover"))
			back_btn.focus_mode = Control.FOCUS_NONE
			
			back_btn.pressed.connect(func():
				menu.size = Vector2(300, 240)
				menu.position = (Vector2(1152, 648) - menu.size) / 2
				bg_panel.size = menu.size
				vbox.size = menu.size - Vector2(40, 40)
				menu_callback.call()
			)
		)
		
	menu_callback.call()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			if not has_node("DebugGotoPopup"):
				open_menu_dialog()
				return
				
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_G:
			open_debug_goto_dialog()
			return
			
	if is_animating or victory or game_over:
		return
		
	if event.is_action_pressed("ui_left"):
		handle_direction_input(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		handle_direction_input(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_up"):
		handle_direction_input(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		handle_direction_input(Vector2i.DOWN)

func _input(event):
	if game_over or victory:
		# Process joypad confirm buttons even when game is over or won
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_A:
				restart_full_game()
		return
		
	# Release UI focus if keyboard or gamepad input is detected
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var focused = get_viewport().gui_get_focus_owner()
		if focused and not focused is LineEdit:
			focused.release_focus()
			
	# Xbox Controller actions mapping
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_Y:
				undo()
			JOY_BUTTON_X:
				reset_level()
		
	# Drag/Swipe gesture logic for touch/mouse
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start_pos = event.position
		else:
			var swipe_dist = event.position - swipe_start_pos
			if swipe_dist.length() >= min_swipe_length:
				var dir = Vector2i()
				if abs(swipe_dist.x) > abs(swipe_dist.y):
					dir = Vector2i.RIGHT if swipe_dist.x > 0 else Vector2i.LEFT
				else:
					dir = Vector2i.DOWN if swipe_dist.y > 0 else Vector2i.UP
				handle_direction_input(dir)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				swipe_start_pos = event.position
			else:
				var swipe_dist = event.position - swipe_start_pos
				if swipe_dist.length() >= min_swipe_length:
					var dir = Vector2i()
					if abs(swipe_dist.x) > abs(swipe_dist.y):
						dir = Vector2i.RIGHT if swipe_dist.x > 0 else Vector2i.LEFT
					else:
						dir = Vector2i.DOWN if swipe_dist.y > 0 else Vector2i.UP
					handle_direction_input(dir)
				else:
					# Short click -> pathfind!
					if swipe_dist.length() < 10.0 and board_container:
						var local_click = board_container.get_local_mouse_position()
						var grid_click = Vector2i(local_click / cell_size)
						# Ensure inside layout boundaries
						if grid_click.x >= 0 and grid_click.x < cols and grid_click.y >= 0 and grid_click.y < rows:
							pathfind_to(grid_click)

func pathfind_to(target: Vector2i):
	# Cancel previous walking
	walking = false
	path_to_walk.clear()
	
	if walls.has(target) or box_positions.has(target):
		return
		
	# Update AStar nodes based on current walls and box configurations
	for r in range(rows):
		for c in range(cols):
			astar.set_point_solid(Vector2i(c, r), false)
	for w in walls:
		astar.set_point_solid(w, true)
	for b in box_positions:
		astar.set_point_solid(b, true)
		
	var path = astar.get_id_path(player_pos, target)
	if path.size() > 1:
		path_to_walk.clear()
		for pt in path:
			path_to_walk.append(Vector2i(pt))
		path_to_walk.remove_at(0) # remove start point
		walking = true

func try_move(dir: Vector2i) -> bool:
	if victory or game_over or is_animating:
		return false
		
	var next_pos = player_pos + dir
	if walls.has(next_pos):
		return false
		
	var box_idx = box_positions.find(next_pos)
	if box_idx != -1:
		var box_next = next_pos + dir
		if walls.has(box_next) or box_positions.has(box_next):
			return false
			
		# Save state to undo stack
		save_state()
		
		# Move logically
		box_positions[box_idx] = box_next
		player_pos = next_pos
		
		# Animate box and player movement
		animate_move(player_pos, box_idx, box_next)
		
		# Update score & check level conditions
		update_box_visual_style(box_idx)
		update_score()
		check_victory()
		return true
	else:
		# Just step
		save_state()
		player_pos = next_pos
		animate_move(player_pos)
		return true

func animate_move(player_target: Vector2i, box_idx: int = -1, box_target: Vector2i = Vector2i()):
	is_animating = true
	var tween = create_tween()
	
	# Interpolate player
	var p_size = cell_size * (34.0 / 44.0)
	var p_offset = (cell_size - p_size) / 2
	var player_pixel_pos = (Vector2(player_target) * cell_size + Vector2(p_offset, p_offset)).round()
	tween.tween_property(player_node, "position", player_pixel_pos, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Interpolate box in parallel
	if box_idx != -1:
		var b_size = cell_size * (38.0 / 44.0)
		var b_offset = (cell_size - b_size) / 2
		var box_pixel_pos = (Vector2(box_target) * cell_size + Vector2(b_offset, b_offset)).round()
		var tween_box = create_tween()
		tween_box.tween_property(box_nodes[box_idx], "position", box_pixel_pos, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	tween.finished.connect(func():
		is_animating = false
	)

func update_box_visual_style(idx: int):
	var b_pos = box_positions[idx]
	var b_node = box_nodes[idx]
	if goals.has(b_pos):
		b_node.add_theme_stylebox_override("panel", box_on_goal_style)
	else:
		b_node.add_theme_stylebox_override("panel", box_style)

func save_state():
	var state = {
		"player_pos": player_pos,
		"box_positions": box_positions.duplicate()
	}
	undo_stack.push_back(state)
	if undo_stack.size() > 100:
		undo_stack.pop_front()

func undo():
	if is_animating or game_over or victory or undo_stack.is_empty():
		return
		
	var prev_state = undo_stack.pop_back()
	
	# Find which box was restored (if any)
	var box_idx = -1
	var prev_box_pos = Vector2i()
	for i in range(box_positions.size()):
		if box_positions[i] != prev_state["box_positions"][i]:
			box_idx = i
			prev_box_pos = prev_state["box_positions"][i]
			break
			
	player_pos = prev_state["player_pos"]
	box_positions = prev_state["box_positions"].duplicate()
	
	animate_move(player_pos, box_idx, prev_box_pos)
	
	if box_idx != -1:
		update_box_visual_style(box_idx)
		
	update_score()
	walking = false
	path_to_walk.clear()

func update_score():
	var active_goals = 0
	for pos in box_positions:
		if goals.has(pos):
			active_goals += 1
	score = active_goals * 100

func check_victory():
	# Game won when all boxes are on goals
	var active_goals = 0
	for pos in box_positions:
		if goals.has(pos):
			active_goals += 1
			
	if active_goals == goals.size():
		victory = true
		walking = false
		path_to_walk.clear()
		victory_score_label.text = "Score: %d | Time Left: %ds" % [score, int(time_remaining)]
		
		# Set text in the next stage button dynamically
		if current_level_idx < 49:
			setup_button_xbox_prompt($VictoryOverlay/VBox/RestartButton, "A", Color(0.29, 0.85, 0.38), "NEXT STAGE")
		else:
			setup_button_xbox_prompt($VictoryOverlay/VBox/RestartButton, "A", Color(0.29, 0.85, 0.38), "PLAY AGAIN")
			
		victory_overlay.visible = true

func lose_life():
	lives -= 1
	walking = false
	path_to_walk.clear()
	
	if lives > 0:
		# Reset level with countdown warning
		reset_level()
	else:
		game_over = true
		game_over_overlay.visible = true

func reset_level():
	# Soft reset of positions, does not reset score/lives
	load_level(current_level_idx)

func restart_full_game():
	# Hard reset back to initial setup
	lives = 3
	score = 0
	game_over = false
	victory = false
	victory_overlay.visible = false
	game_over_overlay.visible = false
	load_level(0)

func load_next_level():
	victory_overlay.visible = false
	if current_level_idx < 49:
		load_level(current_level_idx + 1)
	else:
		restart_full_game()

func update_hud():
	score_label.text = "SCORE: %d" % score
	time_label.text = "TIME: %ds" % int(time_remaining)
	
	# Update stage indicator title
	if title_label:
		title_label.text = "SOKOBAN - STAGE %d / 50" % (current_level_idx + 1)
	
	# Update hearts inside hearts_container
	if hearts_container:
		# Clear old heart icons
		for child in hearts_container.get_children():
			child.queue_free()
		# Add new heart icons
		for i in range(lives):
			var heart_rect = TextureRect.new()
			heart_rect.texture = texture_heart
			heart_rect.custom_minimum_size = Vector2(24, 24)
			heart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hearts_container.add_child(heart_rect)
