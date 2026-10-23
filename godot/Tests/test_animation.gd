extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://Scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.view.set_process(false)
	var flight = scene.flight
	var view = scene.view
	flight.crew_index = 5
	flight.crew_x = 6000
	view._update_character_animation()
	check(not view.crew_moving, "Disembarking must not look like a running stride")
	flight.clock += 0.1
	flight.crew_x += 9
	view._update_character_animation()
	check(view.crew_moving and view.crew_facing == 1, "Rightward travel must run facing right")
	var phase: float = view.crew_phase
	view._update_character_animation()
	check(view.crew_phase == phase, "Animation must freeze when simulation time is paused")
	flight.clock += 0.1
	view._update_character_animation()
	check(not view.crew_moving, "Stopped crew must return to idle")
	flight.clock += 0.1
	flight.crew_x -= 9
	view._update_character_animation()
	check(view.crew_moving and view.crew_facing == -1, "Leftward travel must face left")
	check(view.character_frames.size() == 7, "Missing animation states")
	for frames in view.character_frames.values():
		check(frames.size() == 12, "Incomplete animation cycle")
	print("Character animation checks: %d failures" % failures)
	quit(1 if failures else 0)
