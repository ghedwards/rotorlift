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
	check(scene.view.size == scene.size, "Game does not fill the screen")
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
	# One finger owns the stick while another operates the winch.
	var controls: FlightControls = scene.touch_controls
	var left_touch := InputEventScreenTouch.new()
	left_touch.index = 0
	left_touch.pressed = true
	left_touch.position = controls.joystick_center()
	controls.handle_event(left_touch)
	var small_drag := InputEventScreenDrag.new()
	small_drag.index = 0
	small_drag.position = controls.joystick_center()+Vector2(3,2)
	controls.handle_event(small_drag)
	check(controls.stick == Vector2.ZERO,"Joystick dead zone allowed accidental movement")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = controls.joystick_center()+Vector2(30,-30)
	controls.handle_event(drag)
	check(controls.stick.x>0 and controls.stick.y<0, "Joystick cannot steer and climb diagonally")
	var before_winch := controls.stick
	var winch_touch := InputEventScreenTouch.new()
	winch_touch.index = 1
	winch_touch.pressed = true
	winch_touch.position = controls.winch_center()
	controls.handle_event(winch_touch)
	check(scene.flight.winch == FlightModel.Winch.LOWERING, "Second thumb did not deploy winch")
	check(controls.stick == before_winch, "Winch touch changed the joystick")
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = -1
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse.pressed = true
	emulated_mouse.position = winch_touch.position
	controls.handle_event(emulated_mouse)
	check(scene.flight.winch == FlightModel.Winch.LOWERING, "Emulated mouse duplicated a touch action")
	winch_touch.pressed = false
	controls.handle_event(winch_touch)
	check(controls.stick == before_winch, "Releasing winch cancelled steering")
	left_touch.pressed = false
	controls.handle_event(left_touch)
	check(controls.stick == Vector2.ZERO, "Releasing stick retained input")
	# The rescue button mirrors the current attempt rather than accumulating time.
	scene.flight.contact = 0
	var duration: float = scene.flight.pickup_duration(0)
	scene.flight.pickup_progress = duration/2
	scene._refresh()
	check(is_equal_approx(controls.rescue_progress,0.5) and is_equal_approx(controls.rescue_remaining,duration/2),"Button countdown does not match survivor loading")
	scene.flight.contact = -1
	scene.flight.pickup_progress = 0
	scene._refresh()
	check(controls.rescue_progress<0,"Cancelled pickup retained its button countdown")
	scene.flight.contact = 0
	scene.flight.winch = FlightModel.Winch.READY_TO_HOIST
	scene._refresh()
	check(controls.rescue_progress == 1 and controls.rescue_remaining == 0,"Ready-to-hoist button retained a countdown")
	scene.flight.contact = -1
	scene.flight.winch = FlightModel.Winch.LOWERING
	scene._refresh()
	# Opening the top menu pauses and drops every active pointer.
	left_touch.pressed = true
	controls.handle_event(left_touch)
	controls.handle_event(drag)
	scene._show_menu()
	check(scene.flight.status == FlightModel.Status.PAUSED and controls.stick == Vector2.ZERO, "Menu did not pause and release joystick")
	check(not controls.enabled and scene.menu_panel.visible, "Menu did not block game controls")
	scene._menu_action("settings")
	check(scene.settings_panel.visible and scene.flight.status == FlightModel.Status.PAUSED, "Menu settings resumed flight")
	scene.settings_panel.hide()
	check(scene.flight.status == FlightModel.Status.PLAYING, "Closing menu settings lost resume state")
	scene._show_menu()
	scene._menu_action("info")
	check(scene.manual_open and scene.flight.status == FlightModel.Status.PAUSED, "Menu manual did not pause")
	scene._pause()
	check(scene.flight.status == FlightModel.Status.PLAYING, "Closing menu manual lost resume state")
	scene._select_mission(1)
	check(scene.flight.mission.name == "Storm Coast", "Mission selector did not change mission")
	scene._select_mission(0)
	scene._toggle_sound()
	check(not scene.muted and scene.audio.stream != null, "Sound cue did not initialize")
	# Dialogs must fit the scaled landscape phone viewport, with all assists visible.
	root.size = Vector2i(844,390)
	scene._update_display_scale()
	await process_frame
	await process_frame
	scene._show_settings()
	await process_frame
	await process_frame
	var screen := Rect2(Vector2.ZERO,scene.get_viewport_rect().size)
	check(screen.encloses(scene.settings_panel.get_global_rect()),"Settings extend beyond phone viewport")
	check(scene.settings_scroll.get_global_rect().encloses(scene.assist_checks[2].get_global_rect()),"Auto-hoist control is clipped on a landscape phone")
	check(is_equal_approx(scene.mission_picker.global_position.y,scene.assist_checks[0].global_position.y),"First settings rows are not aligned")
	check(is_equal_approx(scene.sound_button.global_position.y,scene.assist_checks[1].global_position.y),"Second settings rows are not aligned")
	check(is_equal_approx(scene.mission_picker.size.y,scene.assist_checks[0].size.y),"Settings controls have inconsistent heights")
	scene.settings_panel.hide()
	scene._show_menu()
	await process_frame
	check(screen.encloses(scene.menu_panel.get_global_rect()),"Menu extends beyond phone viewport")
	scene.menu_panel.hide()
	scene._show_manual()
	await process_frame
	check(screen.encloses(scene.overlay_card.get_global_rect()),"Manual extends beyond phone viewport")
	scene._pause()
	await process_frame
	# Capture only with the real renderer; headless uses a dummy rendering device.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rotorlift-godot-preview.png")
	print("Scene checks: %d failures" % failures)
	quit(1 if failures else 0)
