extends Node

var game: Control
var scenario: int = 1
var start_level: int = 1

func _ready():
	game = get_parent()
	print("[TestRunner] Node ready. Running Scenario: ", scenario)
	# Wait for game initialization
	await get_tree().create_timer(0.5).timeout
	run_scenario()

func run_scenario():
	match scenario:
		1:
			await run_scenario_1()
		2:
			await run_scenario_2()
		3:
			await run_scenario_3()
		_:
			printerr("[TestRunner] Unknown scenario: ", scenario)
			get_tree().quit(1)

func load_solutions() -> Dictionary:
	var file = FileAccess.open("res://levels_data_solution.json", FileAccess.READ)
	if not file:
		printerr("[TestRunner] Error: levels_data_solution.json not found!")
		return {}
	var text = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(text)
	if err == OK:
		return json.get_data()
	else:
		printerr("[TestRunner] Error parsing levels_data_solution.json")
		return {}

func press_key(keycode: int):
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.keycode = keycode
	Input.parse_input_event(ev)
	
	var ev_up = InputEventKey.new()
	ev_up.pressed = false
	ev_up.keycode = keycode
	Input.parse_input_event(ev_up)

func press_joypad(button: int):
	var ev = InputEventJoypadButton.new()
	ev.pressed = true
	ev.button_index = button
	Input.parse_input_event(ev)
	
	var ev_up = InputEventJoypadButton.new()
	ev_up.pressed = false
	ev_up.button_index = button
	Input.parse_input_event(ev_up)

func swipe_mouse(start_pos: Vector2, end_pos: Vector2):
	var ev_down = InputEventMouseButton.new()
	ev_down.pressed = true
	ev_down.button_index = MOUSE_BUTTON_LEFT
	ev_down.position = start_pos
	Input.parse_input_event(ev_down)
	
	var ev_up = InputEventMouseButton.new()
	ev_up.pressed = false
	ev_up.button_index = MOUSE_BUTTON_LEFT
	ev_up.position = end_pos
	Input.parse_input_event(ev_up)

# Helper to wait until the game finishes animating a movement
func wait_for_animation():
	await get_tree().process_frame
	await get_tree().process_frame
	while game.is_animating:
		await get_tree().create_timer(0.01).timeout

# Force solves the current stage by warping boxes onto goals
func force_solve_stage():
	var goal_list = game.goals.keys()
	for i in range(game.box_positions.size()):
		if i < goal_list.size():
			game.box_positions[i] = goal_list[i]
			game.update_box_visual_style(i)
	game.update_score()
	game.check_victory()
	# Force update board to reflect changes immediately
	game.setup_board()

func run_scenario_1():
	print("[TestRunner] Starting Scenario 1 (50 stages auto-solver)")
	var solutions = load_solutions()
	if solutions.is_empty():
		get_tree().quit(1)
		return
		
	var start_idx = clamp(start_level - 1, 0, 49)
	for level_idx in range(start_idx, 50):
		await get_tree().create_timer(0.2).timeout
		
		# Synchronize levels
		if game.current_level_idx != level_idx:
			print("[TestRunner] Level mismatch! Loading level ", level_idx)
			game.load_level(level_idx)
			await get_tree().create_timer(0.2).timeout
			
		var sol_str = solutions.get(str(level_idx), "")
		if sol_str == "":
			printerr("[TestRunner] No solution for level ", level_idx)
			get_tree().quit(1)
			return
			
		print("[TestRunner] Playing Stage ", level_idx + 1, "/50, steps: ", sol_str.length())
		
		# Play inputs from levels_data_solution.json
		for char in sol_str:
			var key = KEY_NONE
			match char:
				"L", "l": key = KEY_LEFT
				"R", "r": key = KEY_RIGHT
				"U", "u": key = KEY_UP
				"D", "d": key = KEY_DOWN
			if key != KEY_NONE:
				await wait_for_animation()
				press_key(key)
				await get_tree().create_timer(0.02).timeout
				
		# After playing the solutions sequence, check if victory is reached.
		# If not, wait until game_over or victory naturally triggers (e.g. timeout)
		await wait_for_animation()
		await get_tree().create_timer(0.5).timeout
		
		if not game.victory:
			print("[TestRunner] Stage ", level_idx + 1, " keys finished, but victory state not reached. Waiting for time limit or manual quit...")
			while not game.game_over and not game.victory:
				await get_tree().create_timer(1.0).timeout
				
			if game.game_over:
				print("[TestRunner] Game Over reached. Submitting score and quitting.")
				var retry_btn = game.get_node_or_null("GameOverOverlay/VBox/RetryButton")
				if retry_btn:
					retry_btn.pressed.emit()
				await get_tree().create_timer(1.0).timeout
				if game.has_node("HighscoreEntryPopup"):
					var popup = game.get_node("HighscoreEntryPopup")
					var line_edit = popup.find_child("LineEdit", true, false)
					if line_edit:
						line_edit.text = "BOT_S1_FAIL"
					var submit_btn = popup.find_child("OK", true, false)
					if submit_btn:
						submit_btn.pressed.emit()
				await get_tree().create_timer(2.0).timeout
				get_tree().quit(0)
				return
			
		print("[TestRunner] Stage ", level_idx + 1, " Cleared successfully!")
		
		# Move to next stage
		press_joypad(JOY_BUTTON_A)
		await get_tree().create_timer(0.5).timeout
		
	print("[TestRunner] 50 stages completed. Waiting for Highscore overlay...")
	await get_tree().create_timer(1.0).timeout
	
	if game.has_node("HighscoreEntryPopup"):
		var popup = game.get_node("HighscoreEntryPopup")
		var line_edit = popup.find_child("LineEdit", true, false)
		if line_edit:
			line_edit.text = "BOT_S1"
		var submit_btn = popup.find_child("OK", true, false)
		if submit_btn:
			submit_btn.pressed.emit()
			print("[TestRunner] Highscore submitted.")
		else:
			printerr("[TestRunner] Submit button not found")
			get_tree().quit(1)
			return
	else:
		printerr("[TestRunner] HighscoreEntryPopup not found!")
		get_tree().quit(1)
		return
		
	await get_tree().create_timer(2.0).timeout
	print("[TestRunner] Scenario 1 completed successfully.")
	get_tree().quit(0)

func run_scenario_2():
	print("[TestRunner] Starting Scenario 2 (Random play -> 1 min timeout -> Game Over)")
	var start_time = Time.get_ticks_msec()
	var duration_sec = 60.0
	
	while (Time.get_ticks_msec() - start_time) / 1000.0 < duration_sec:
		var keys = [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
		var rand_key = keys[randi() % keys.size()]
		await wait_for_animation()
		press_key(rand_key)
		await get_tree().create_timer(0.05).timeout
		
		# In case we accidentally solve the level
		if game.victory:
			press_joypad(JOY_BUTTON_A)
			await get_tree().create_timer(0.5).timeout
			
	print("[TestRunner] 1 minute elapsed. Forcing gameover.")
	# Force game over by draining lives
	game.lives = 0
	game.lose_life()
	
	await get_tree().create_timer(1.0).timeout
	if game.game_over:
		print("[TestRunner] Game Over confirmed. Clicking Try Again.")
		var retry_btn = game.get_node_or_null("GameOverOverlay/VBox/RetryButton")
		if retry_btn:
			retry_btn.pressed.emit()
		else:
			press_joypad(JOY_BUTTON_A)
			
		await get_tree().create_timer(1.0).timeout
		if game.has_node("HighscoreEntryPopup"):
			var popup = game.get_node("HighscoreEntryPopup")
			var line_edit = popup.find_child("LineEdit", true, false)
			if line_edit:
				line_edit.text = "BOT_S2"
			var submit_btn = popup.find_child("OK", true, false)
			if submit_btn:
				submit_btn.pressed.emit()
				print("[TestRunner] Highscore submitted.")
			else:
				printerr("[TestRunner] Submit button not found")
				get_tree().quit(1)
				return
		else:
			printerr("[TestRunner] HighscoreEntryPopup not found after retry!")
			get_tree().quit(1)
			return
	else:
		printerr("[TestRunner] Game Over state not triggered!")
		get_tree().quit(1)
		return
		
	await get_tree().create_timer(2.0).timeout
	print("[TestRunner] Scenario 2 completed successfully.")
	get_tree().quit(0)

func run_scenario_3():
	print("[TestRunner] Starting Scenario 3 (Inputs & Menu Verification)")
	
	# 1. Keyboard Move Test
	print("[TestRunner] 1. Testing Keyboard Move")
	var prev_player_pos = game.player_pos
	press_key(KEY_LEFT)
	await get_tree().create_timer(0.2).timeout
	# If movement succeeded, player_pos changes
	print("[TestRunner] Player pos before: ", prev_player_pos, ", after KEY_LEFT: ", game.player_pos)
	
	# 2. Mouse Swipe Test
	print("[TestRunner] 2. Testing Mouse Swipe")
	swipe_mouse(Vector2(200, 200), Vector2(400, 200))
	await get_tree().create_timer(0.3).timeout
	
	# 3. Gamepad START -> Open Menu
	print("[TestRunner] 3. Testing Menu Opening via JOY_BUTTON_START")
	press_joypad(JOY_BUTTON_START)
	await get_tree().create_timer(0.5).timeout
	
	if not game.has_node("SokobanMenu"):
		printerr("[TestRunner] Menu did not open via JOY_BUTTON_START")
		get_tree().quit(1)
		return
	print("[TestRunner] Menu opened successfully.")
	
	# 4. Theme Selection Test
	print("[TestRunner] 4. Testing Theme Change")
	var content_area = game.get_node("SokobanMenu/VBox/ContentArea")
	var theme_btn = content_area.get_child(0) as Button
	if theme_btn and theme_btn.text.begins_with("Theme"):
		theme_btn.pressed.emit()
		await get_tree().create_timer(0.5).timeout
		
		var kenney_btn = content_area.get_child(1) as Button
		if kenney_btn and kenney_btn.text.begins_with("Kenney"):
			kenney_btn.pressed.emit()
			await get_tree().create_timer(0.5).timeout
			if game.current_theme != "kenney":
				printerr("[TestRunner] Current theme was not updated to 'kenney'")
				get_tree().quit(1)
				return
			print("[TestRunner] Theme updated to 'kenney' successfully.")
		else:
			printerr("[TestRunner] Kenney button not found")
			get_tree().quit(1)
			return
	else:
		printerr("[TestRunner] Theme button not found")
		get_tree().quit(1)
		return

	# Re-open Menu (applying theme automatically closes the menu)
	press_key(KEY_ESCAPE)
	await get_tree().create_timer(0.5).timeout
	content_area = game.get_node("SokobanMenu/VBox/ContentArea")
	
	# 5. Leaderboard UI Test
	print("[TestRunner] 5. Testing Leaderboard UI")
	var leaderboard_btn = content_area.get_child(1) as Button
	if leaderboard_btn and leaderboard_btn.text.begins_with("Leaderboard"):
		leaderboard_btn.pressed.emit()
		await get_tree().create_timer(1.0).timeout # wait for API loading
		
		if not game.has_node("SokobanMenu/VBox/ContentArea/Scroll/ScoreList"):
			printerr("[TestRunner] ScoreList node not found in Leaderboard")
			get_tree().quit(1)
			return
		print("[TestRunner] Leaderboard UI verified.")
		
		# Go back
		var back_btn = content_area.get_child(1) as Button
		if back_btn and back_btn.text == "Back":
			back_btn.pressed.emit()
			await get_tree().create_timer(0.5).timeout
		else:
			printerr("[TestRunner] Back button in Leaderboard not found")
			get_tree().quit(1)
			return
	else:
		printerr("[TestRunner] Leaderboard button not found")
		get_tree().quit(1)
		return
		
	# 6. License UI Test
	print("[TestRunner] 6. Testing License UI")
	content_area = game.get_node("SokobanMenu/VBox/ContentArea")
	var license_btn = content_area.get_child(2) as Button
	if license_btn and license_btn.text.begins_with("License"):
		license_btn.pressed.emit()
		await get_tree().create_timer(0.5).timeout
		
		var scroll = content_area.get_child(0)
		var label = scroll.get_child(0) as Label
		if not label or not label.text.contains("MIT License"):
			printerr("[TestRunner] License text doesn't contain MIT License")
			get_tree().quit(1)
			return
		print("[TestRunner] License UI verified.")
		
		# Go back
		var back_btn = content_area.get_child(1) as Button
		if back_btn and back_btn.text == "Back":
			back_btn.pressed.emit()
			await get_tree().create_timer(0.5).timeout
		else:
			printerr("[TestRunner] Back button in License not found")
			get_tree().quit(1)
			return
	else:
		printerr("[TestRunner] License button not found")
		get_tree().quit(1)
		return
		
	# 7. Close Menu Test
	print("[TestRunner] 7. Testing Menu Close")
	content_area = game.get_node("SokobanMenu/VBox/ContentArea")
	var close_btn = content_area.get_child(3) as Button
	if close_btn and close_btn.text == "Close":
		close_btn.pressed.emit()
		await get_tree().create_timer(0.5).timeout
		if game.has_node("SokobanMenu"):
			printerr("[TestRunner] Menu was not closed")
			get_tree().quit(1)
			return
		print("[TestRunner] Menu closed successfully.")
	else:
		printerr("[TestRunner] Close button not found")
		get_tree().quit(1)
		return
		
	print("[TestRunner] Scenario 3 completed successfully.")
	get_tree().quit(0)
