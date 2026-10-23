extends SceneTree

var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://Scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "Native app does not restrict play to landscape")
	check(scene.flight.status == FlightModel.Status.READY, "Scene did not start ready")
	check(scene.view.size.y > 0, "Flight viewport has no height")
	check(scene.radio_message.text == scene.flight.message, "Footer radio message is missing")
	Input.action_press("flight_up")
	await physics_frame
	await process_frame
	Input.action_release("flight_up")
	check(scene.flight.status == FlightModel.Status.PLAYING, "Throttle did not start flight")
	scene._pause()
	await process_frame
	check(scene.overlay.visible, "Pause overlay was not shown")
	scene._pause()
	# Rotating to portrait must stop the flight and release both thumbs.
	scene.held.left = true
	scene._set_portrait_blocked(true)
	check(scene.rotation_overlay.visible and scene.flight.status == FlightModel.Status.PAUSED, "Portrait did not block and pause flight")
	check(not scene._control("left"), "Portrait retained a held flight input")
	var paused_position: Vector2 = scene.flight.position
	await create_timer(0.06).timeout
	check(scene.flight.position == paused_position, "Flight moved while portrait was blocked")
	scene._pause()
	check(scene.flight.status == FlightModel.Status.PAUSED, "Portrait allowed flight to resume")
	scene._set_portrait_blocked(false)
	check(not scene.rotation_overlay.visible and scene.flight.status == FlightModel.Status.PLAYING, "Landscape did not restore the flight")
	scene._pause()
	scene._set_portrait_blocked(true)
	scene._set_portrait_blocked(false)
	check(scene.flight.status == FlightModel.Status.PAUSED, "Rotation resumed a manually paused flight")
	scene._pause()
	# Android Back must pause instead of exiting, and backgrounding releases inputs.
	check(not scene.get_tree().quit_on_go_back, "Android Back still exits the game")
	scene.held.left = true
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.flight.status == FlightModel.Status.PAUSED and not scene._control("left"), "Android Back did not pause and release controls")
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.flight.status == FlightModel.Status.PLAYING, "Android Back did not resume")
	scene._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(scene.flight.status == FlightModel.Status.PAUSED, "Backgrounding did not pause flight")
	scene._pause()
	# Utility panels must pause safely and release held mobile inputs.
	scene._show_manual()
	check(scene.flight.status == FlightModel.Status.PAUSED, "Manual did not pause flight")
	scene._pause()
	check(scene.flight.status == FlightModel.Status.PLAYING, "Manual did not restore flight")
	scene._show_settings()
	check(scene.flight.status == FlightModel.Status.PAUSED, "Settings did not pause flight")
	scene._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not scene.settings_panel.visible, "Android Back did not close settings")
	check(scene.flight.status == FlightModel.Status.PLAYING, "Settings did not restore flight")
	for button in scene.control_buttons.values():
		check(button.size.x >= 100 and button.size.y >= 100, "Mobile flight target is too small")
	var left_touch := InputEventScreenTouch.new()
	left_touch.index = 0
	left_touch.pressed = true
	left_touch.position = scene.control_buttons.left.get_global_rect().get_center()
	scene._input(left_touch)
	var up_touch := InputEventScreenTouch.new()
	up_touch.index = 1
	up_touch.pressed = true
	up_touch.position = scene.control_buttons.up.get_global_rect().get_center()
	scene._input(up_touch)
	check(scene._control("left") and scene._control("up"), "Independent thumbs cannot steer and climb together")
	left_touch.pressed = false
	scene._input(left_touch)
	check(not scene._control("left") and scene._control("up"), "Releasing one thumb cancelled the other")
	scene._clear_controls()
	scene.flight.toggle_winch()
	check(scene.flight.winch == FlightModel.Winch.LOWERING, "Winch did not deploy")
	scene._select_mission(1)
	check(scene.flight.mission.name == "Storm Coast", "Mission selector did not change mission")
	scene._select_mission(0)
	scene._toggle_sound()
	check(not scene.muted and scene.audio.stream != null, "Sound cue did not initialize")
	await process_frame
	# Capture only with the real renderer; headless uses a dummy rendering device.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rotorlift-godot-preview.png")
	print("Scene checks: %d failures" % failures)
	quit(1 if failures else 0)
