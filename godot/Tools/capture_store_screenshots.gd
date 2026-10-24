extends SceneTree
## Staged real-game captures; requires a renderer (not --headless).
var game
var surface: SubViewport
func _initialize() -> void:
	call_deferred("capture_all")
func capture_all() -> void:
	for format in [{"name":"google-play","size":Vector2i(1920,1080)},{"name":"app-store-iphone","size":Vector2i(2868,1320)}]:
		for action in InputMap.get_actions():
			if action.begins_with("flight_"): InputMap.erase_action(action)
		surface=SubViewport.new()
		surface.size=format.size
		surface.size_2d_override=Vector2i(1200,roundi(1200.0*format.size.y/format.size.x))
		surface.size_2d_override_stretch=true
		surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		game=load("res://Scenes/main.tscn").instantiate()
		surface.add_child(game)
		game.set_process(false)
		await process_frame
		await process_frame
		for shot in 4:
			stage(shot)
			game._refresh()
			game.view.reset_camera()
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			var folder="res://builds/store-listing/"+format.name
			DirAccess.make_dir_recursive_absolute(folder)
			var capture=surface.get_texture().get_image()
			capture.convert(Image.FORMAT_RGB8)
			var path=folder+"/%02d-%s.png" % [shot+1,["winch-rescue","storm-coast","ground-rescue","wildfire-flight"][shot]]
			assert(capture.save_png(path)==OK)
			print("Captured "+path)
		game.queue_free()
		surface.queue_free()
		await process_frame
	await capture_feature()
	quit()
func stage(shot: int) -> void:
	game._select_mission([0,1,0,2][shot])
	var f=game.flight
	f.status=FlightModel.Status.PLAYING
	f.clock=12.0
	f.elapsed=86.0
	if shot in [0,1]:
		var target: Dictionary=f.mission.targets[0 if shot==0 else 1]
		f.position=Vector2(float(target.x)-15,float(target.y)-225)
		f.winch=FlightModel.Winch.LOWERING
		if shot==0:
			f.contact=0
			f.contact_anchor=f.pickup_center(0)
			f.cable=f.winch_origin().distance_to(f.contact_anchor)
			f.contact_cable=f.cable
			f.pickup_progress=1.4
		else:
			f.cable=150
			f.swing=0.12
	elif shot==2:
		for i in f.targets.size():
			var target: Dictionary=f.mission.targets[i]
			if target.get("mode","")=="landing":
				f.position=Vector2(float(target.landing_x),f.ground(float(target.landing_x))-56)
				f.crew_index=i
				f.crew_x=float(target.x)-12
				f.crew_state=1
				f.crew_progress=1.4
				break
	else:
		f.position=Vector2(2500,340)
		f.velocity=Vector2(80,0)

func capture_feature() -> void:
	var target=SubViewport.new()
	target.size=Vector2i(1024,500)
	target.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var backdrop=TextureRect.new()
	backdrop.texture=load("res://Assets/alpine-backdrop.png")
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size=Vector2(1024,500)
	backdrop.modulate=Color(0.35,0.45,0.38)
	target.add_child(backdrop)
	var icon=TextureRect.new()
	icon.texture=load("res://Assets/Art/app-icon.svg")
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.position=Vector2(66,96)
	icon.size=Vector2(308,308)
	target.add_child(icon)
	for item in [{"text":"ROTORLIFT","font":72,"y":150},{"text":"Bring them home.","font":34,"y":243},{"text":"Helicopter rescue","font":23,"y":300}]:
		var label=Label.new()
		label.text=item.text
		label.position=Vector2(410,item.y)
		label.add_theme_font_override("font",load("res://Assets/Fonts/BarlowCondensed-SemiBold.ttf") if item.font==72 else load("res://Assets/Fonts/DMSans.ttf"))
		label.add_theme_font_size_override("font_size",item.font)
		label.add_theme_color_override("font_color",Color("eeedcf"))
		target.add_child(label)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var graphic=target.get_texture().get_image()
	graphic.convert(Image.FORMAT_RGB8)
	assert(graphic.save_png("res://builds/store-listing/google-play-feature-1024x500.png")==OK)
	var icon_image=Image.load_from_file("res://Assets/Art/app-icon.svg")
	icon_image.convert(Image.FORMAT_RGB8)
	icon_image.save_png("res://builds/store-listing/app-store-icon-1024.png")
	icon_image.resize(512,512,Image.INTERPOLATE_LANCZOS)
	icon_image.save_png("res://builds/store-listing/google-play-icon-512.png")
	target.queue_free()
