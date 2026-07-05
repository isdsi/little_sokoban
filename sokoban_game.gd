extends Control

const TEXTURE_HEART = preload("res://assets/heart.png")
const TEXTURE_PLAYER_FACE = preload("res://assets/player_face.png")
const TEXTURE_BOX_X = preload("res://assets/box_x.png")
const TEXTURE_ARROW_UP = preload("res://assets/arrow_up.png")
const TEXTURE_ARROW_DOWN = preload("res://assets/arrow_down.png")
const TEXTURE_ARROW_LEFT = preload("res://assets/arrow_left.png")
const TEXTURE_ARROW_RIGHT = preload("res://assets/arrow_right.png")

# Sokoban Level 1 Map Layout (Imabayashi Original 1982)
const LEVEL_LAYOUT = [
	"    #####          ",
	"    #   #          ",
	"    #$  #          ",
	"  ###  $##         ",
	"  #  $ $ #         ",
	"### # ## #   ######",
	"#   # ## #####  ..#",
	"# $  $          ..#",
	"##### ### #@##  ..#",
	"    #     #########",
	"    #######        "
]

const CELL_SIZE = 44
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
var wall_style = StyleBoxFlat.new()
var floor_style = StyleBoxFlat.new()
var goal_style = StyleBoxFlat.new()
var box_style = StyleBoxFlat.new()
var box_on_goal_style = StyleBoxFlat.new()
var player_style = StyleBoxFlat.new()

# HUD Nodes (will be linked from the scene)
@onready var score_label = $HUD/ScoreLabel
@onready var time_label = $HUD/TimeLabel
@onready var lives_label = $HUD/LivesLabel

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
	
	# Parse layout and initialize positions
	parse_layout()
	
	# Setup AStarGrid2D
	astar.region = Rect2i(0, 0, cols, rows)
	astar.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	# Setup visual board
	setup_board()
	
	# Connect UI buttons
	$HUD/Buttons/UndoButton.pressed.connect(undo)
	$HUD/Buttons/RestartButton.pressed.connect(reset_level)
	
	# Connect Touch Controls (D-pad)
	$TouchControls/Dpad/Up.pressed.connect(func(): handle_direction_input(Vector2i.UP))
	$TouchControls/Dpad/Down.pressed.connect(func(): handle_direction_input(Vector2i.DOWN))
	$TouchControls/Dpad/Left.pressed.connect(func(): handle_direction_input(Vector2i.LEFT))
	$TouchControls/Dpad/Right.pressed.connect(func(): handle_direction_input(Vector2i.RIGHT))
	
	# Connect Overlays
	$VictoryOverlay/VBox/RestartButton.pressed.connect(restart_full_game)
	$GameOverOverlay/VBox/RetryButton.pressed.connect(restart_full_game)
	
	# Setup button Xbox prompts
	setup_button_xbox_prompt($HUD/Buttons/UndoButton, "Y", Color(0.98, 0.82, 0.08), "UNDO")
	setup_button_xbox_prompt($HUD/Buttons/RestartButton, "X", Color(0.25, 0.61, 1.0), "RESET")
	setup_button_xbox_prompt($VictoryOverlay/VBox/RestartButton, "A", Color(0.29, 0.85, 0.38), "PLAY AGAIN")
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

func setup_styles():
	# Tech Wall
	wall_style.bg_color = Color(0.28, 0.33, 0.42)
	wall_style.set_corner_radius_all(6)
	wall_style.border_width_left = 2
	wall_style.border_width_top = 2
	wall_style.border_color = Color(0.38, 0.45, 0.56)
	
	# Floor Grid
	floor_style.bg_color = Color(0.12, 0.15, 0.20)
	floor_style.border_width_left = 1
	floor_style.border_width_top = 1
	floor_style.border_width_right = 1
	floor_style.border_width_bottom = 1
	floor_style.border_color = Color(0.16, 0.20, 0.26)
	
	# Glowing Goal (Gold Ring)
	goal_style.bg_color = Color(0.96, 0.77, 0.19, 0.25)
	goal_style.border_width_left = 3
	goal_style.border_width_top = 3
	goal_style.border_width_right = 3
	goal_style.border_width_bottom = 3
	goal_style.border_color = Color(0.96, 0.77, 0.19, 0.8)
	goal_style.set_corner_radius_all(10)
	
	# Normal Box (Amber Box)
	box_style.bg_color = Color(0.85, 0.55, 0.15)
	box_style.set_corner_radius_all(6)
	box_style.border_width_left = 3
	box_style.border_width_top = 3
	box_style.border_width_right = 3
	box_style.border_width_bottom = 3
	box_style.border_color = Color(0.95, 0.7, 0.3)
	
	# Placed Box (Glowing Emerald Green Box)
	box_on_goal_style.bg_color = Color(0.06, 0.7, 0.38)
	box_on_goal_style.set_corner_radius_all(6)
	box_on_goal_style.border_width_left = 3
	box_on_goal_style.border_width_top = 3
	box_on_goal_style.border_width_right = 3
	box_on_goal_style.border_width_bottom = 3
	box_on_goal_style.border_color = Color(0.2, 0.85, 0.5)
	box_on_goal_style.shadow_color = Color(0.06, 0.7, 0.38, 0.45)
	box_on_goal_style.shadow_size = 10
	
	# Glowing Player (Pink circular bot)
	player_style.bg_color = Color(0.93, 0.28, 0.54)
	player_style.set_corner_radius_all(17)
	player_style.border_width_left = 2
	player_style.border_width_top = 2
	player_style.border_color = Color(0.98, 0.5, 0.7)
	player_style.shadow_color = Color(0.93, 0.28, 0.54, 0.4)
	player_style.shadow_size = 8

func parse_layout():
	box_positions.clear()
	walls.clear()
	goals.clear()
	
	for r in range(rows):
		var line = LEVEL_LAYOUT[r]
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

func setup_board():
	if board_container:
		board_container.queue_free()
		
	board_container = Control.new()
	board_container.size = Vector2(cols * CELL_SIZE, rows * CELL_SIZE)
	board_container.position = (Vector2(1152, 648) - board_container.size) / 2
	board_container.position.y -= 25 # offset up for visual balance
	add_child(board_container)
	move_child(board_container, 1) # Draw behind HUD and overlays (so overlays render on top of the board)
	# Make sure board container receives input for clicking
	board_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Instantiating tiles
	for r in range(rows):
		for c in range(cols):
			var cell = LEVEL_LAYOUT[r][c]
			var pos = Vector2i(c, r)
			
			if cell != " ":
				# Floor
				var floor_tile = Panel.new()
				floor_tile.size = Vector2(CELL_SIZE, CELL_SIZE)
				floor_tile.position = Vector2(c, r) * CELL_SIZE
				floor_tile.add_theme_stylebox_override("panel", floor_style)
				board_container.add_child(floor_tile)
				
			if cell == "#":
				# Wall
				var wall_tile = Panel.new()
				wall_tile.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)
				wall_tile.position = Vector2(c, r) * CELL_SIZE + Vector2(1, 1)
				wall_tile.add_theme_stylebox_override("panel", wall_style)
				board_container.add_child(wall_tile)
				
			elif cell == ".":
				# Goal
				var goal_tile = Panel.new()
				goal_tile.size = Vector2(20, 20)
				goal_tile.position = Vector2(c, r) * CELL_SIZE + Vector2((CELL_SIZE - 20)/2, (CELL_SIZE - 20)/2)
				goal_tile.add_theme_stylebox_override("panel", goal_style)
				board_container.add_child(goal_tile)
				
	# Instantiate Player
	player_node = Panel.new()
	player_node.size = Vector2(34, 34)
	player_node.position = Vector2(player_pos) * CELL_SIZE + Vector2((CELL_SIZE - 34)/2, (CELL_SIZE - 34)/2)
	player_node.add_theme_stylebox_override("panel", player_style)
	board_container.add_child(player_node)
	
	var player_face = TextureRect.new()
	player_face.texture = TEXTURE_PLAYER_FACE
	player_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_face.size = Vector2(20, 20)
	player_face.position = (player_node.size - player_face.size) / 2
	player_node.add_child(player_face)
	
	# Instantiate Boxes
	box_nodes.clear()
	for i in range(box_positions.size()):
		var b_pos = box_positions[i]
		var box_tile = Panel.new()
		box_tile.size = Vector2(CELL_SIZE - 6, CELL_SIZE - 6)
		box_tile.position = Vector2(b_pos) * CELL_SIZE + Vector2(3, 3)
		
		if goals.has(b_pos):
			box_tile.add_theme_stylebox_override("panel", box_on_goal_style)
		else:
			box_tile.add_theme_stylebox_override("panel", box_style)
			
		board_container.add_child(box_tile)
		box_nodes.append(box_tile)
		
		# Crate style X mark
		var x_mark = TextureRect.new()
		x_mark.texture = TEXTURE_BOX_X
		x_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		x_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		x_mark.size = Vector2(24, 24)
		x_mark.position = (box_tile.size - x_mark.size) / 2
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

func _unhandled_input(event):
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
		if focused:
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
						var grid_click = Vector2i(local_click / CELL_SIZE)
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
	var p_offset = (CELL_SIZE - 34) / 2
	var player_pixel_pos = Vector2(player_target) * CELL_SIZE + Vector2(p_offset, p_offset)
	tween.tween_property(player_node, "position", player_pixel_pos, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Interpolate box in parallel
	if box_idx != -1:
		var b_offset = 3
		var box_pixel_pos = Vector2(box_target) * CELL_SIZE + Vector2(b_offset, b_offset)
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
	parse_layout()
	setup_board()
	undo_stack.clear()
	time_remaining = 300.0
	walking = false
	path_to_walk.clear()
	is_animating = false
	update_hud()

func restart_full_game():
	# Hard reset back to initial setup
	lives = 3
	score = 0
	game_over = false
	victory = false
	victory_overlay.visible = false
	game_over_overlay.visible = false
	reset_level()

func update_hud():
	score_label.text = "SCORE: %d" % score
	time_label.text = "TIME: %ds" % int(time_remaining)
	
	# Update hearts inside hearts_container
	if hearts_container:
		# Clear old heart icons
		for child in hearts_container.get_children():
			child.queue_free()
		# Add new heart icons
		for i in range(lives):
			var heart_rect = TextureRect.new()
			heart_rect.texture = TEXTURE_HEART
			heart_rect.custom_minimum_size = Vector2(24, 24)
			heart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hearts_container.add_child(heart_rect)
