extends SceneTree
var failures := 0
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://Scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.view.set_process(false)
	var flight: FlightModel = scene.flight
	var view: FlightView = scene.view
	flight.status = FlightModel.Status.PLAYING
	view.size = Vector2(1200,555)
	view.reset_camera()
	view._update_camera(0)
	var low_camera := view.camera_y
	flight.position = Vector2(1500,200)
	for i in 120:
		view._update_camera(1.0/60)
	check(view.camera_y<low_camera-200,"Climbing did not move the camera upward")
	var helicopter := view.world_to_screen(flight.position)
	var rotor := view.world_to_screen(flight.position-Vector2(0,80))
	check(absf(helicopter.x-view.size.x*0.5)<10,"Helicopter did not centre horizontally")
	check(rotor.y>116+20,"Rotor disappeared behind the top bar")
	check(helicopter.y>160 and helicopter.y<view.size.y-160,"Helicopter did not stay in the clear flight area")
	for i in 5:
		var bird := view.world_to_screen(flight.bird_position(i))
		check(bird.y>128 and bird.y<view.size.y-40,"Bird near the helicopter is hidden by instruments")
	# A long deployed line must remain visible along with its helicopter.
	flight.winch = FlightModel.Winch.LOWERING
	flight.cable = 400
	flight.swing = 0
	for i in 120:
		view._update_camera(1.0/60)
	check(view.world_to_screen(flight.position-Vector2(0,80)).y>128,"Winch framing hid the rotors")
	check(view.world_to_screen(flight.rig_position()+Vector2(0,36)).y<view.size.y-16,"Winch framing hid the stretcher")
	var paused_camera := Vector2(view.camera_x,view.camera_y)
	flight.status = FlightModel.Status.PAUSED
	view._update_camera(0.5)
	check(paused_camera==Vector2(view.camera_x,view.camera_y),"Camera moved during pause")
	view.reset_camera()
	check(not view.camera_initialized,"Mission restart did not reset camera framing")
	print("Camera checks: %d failures" % failures)
	quit(1 if failures else 0)
