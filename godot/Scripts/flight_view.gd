class_name FlightView
extends Control
## Canvas rendering translated from the original HTML game's illustration system.

const HELICOPTER_BODY = preload("res://Assets/Art/helicopter-body.svg")
const HELICOPTER_FLASH = preload("res://Assets/Art/helicopter-body-flash.svg")
const FIELD_PAD = preload("res://Assets/Art/field-landing-pad.svg")
const RESCUE_BASE = preload("res://Assets/Art/rescue-base.svg")

const CHARACTER_ATLASES = {
	"survivor_idle":preload("res://Assets/Art/Characters/survivor-idle.svg"),
	"survivor_wave":preload("res://Assets/Art/Characters/survivor-wave.svg"),
	"survivor_walk":preload("res://Assets/Art/Characters/survivor-walk.svg"),
	"rescuer_idle":preload("res://Assets/Art/Characters/rescuer-idle.svg"),
	"rescuer_run":preload("res://Assets/Art/Characters/rescuer-run.svg"),
	"rescuer_walk":preload("res://Assets/Art/Characters/rescuer-walk.svg"),
	"rescuer_help":preload("res://Assets/Art/Characters/rescuer-help.svg")
}
var character_frames: Dictionary = {}
var crew_phase := 0.0
var crew_facing := 1
var crew_moving := false
var previous_crew_x := 0.0
var previous_crew_index := -1
var previous_clock := -1.0
const PATIENT = preload("res://Assets/Art/stretcher-patient.svg")

const ORANGE := Color("f28a50")
const CREAM := Color("ece9ce")
const MONO = preload("res://Assets/Fonts/IBMPlexMono-Regular.ttf")
const SANS = preload("res://Assets/Fonts/DMSans.ttf")
var world_labels: Array[Dictionary] = []
var flight: FlightModel
var backdrop: Texture2D
const WORLD_HEIGHT := 760.0
const SAFE_TOP := 128.0
var camera_x := 0.0
var camera_y := 0.0
var camera_initialized := false
var camera_view_size := Vector2.ZERO
var world_width := 1440.0
var grading: GradientTexture2D

func _ready() -> void:
	for key: String in CHARACTER_ATLASES:
		var frames: Array[AtlasTexture] = []
		for i in 12:
			var frame := AtlasTexture.new()
			frame.atlas = CHARACTER_ATLASES[key]
			frame.region = Rect2(i*150,0,150,150)
			frames.append(frame)
		character_frames[key] = frames
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.06,0.13,0.12,0.02),Color(0.06,0.13,0.12,0.17)])
	grading = GradientTexture2D.new()
	grading.gradient = gradient
	grading.width = 4
	grading.height = 256
	grading.fill_from = Vector2(0,0)
	grading.fill_to = Vector2(0,1)

func _process(dt: float) -> void:
	if flight == null or size.y <= 0:
		return
	_update_character_animation()
	_update_camera(dt)
	queue_redraw()

func reset_camera() -> void:
	camera_initialized = false
	camera_x = 0
	camera_y = 0

func world_scale() -> float:
	return size.y / WORLD_HEIGHT

func world_to_screen(point: Vector2) -> Vector2:
	return (point-Vector2(camera_x,camera_y))*world_scale()

func _update_camera(dt: float) -> void:
	if size.y <= 0:
		return
	if camera_view_size != size:
		camera_initialized = false
		camera_view_size = size
	world_width = size.x / world_scale()
	var target_x := clampf(flight.position.x-world_width*0.5,0,maxf(0,float(flight.mission.width)-world_width))
	# Centre flight below the instruments. A deployed rig gets space beneath it.
	var focus_y := flight.position.y
	if flight.cable > 0:
		focus_y = lerpf(focus_y,maxf(focus_y,flight.rig_position().y+36),0.35)
	var screen_center := SAFE_TOP+(size.y-SAFE_TOP)*0.44
	var target_y := clampf(focus_y-screen_center/world_scale(),-480,190)
	if not camera_initialized:
		camera_x = target_x
		camera_y = target_y
		camera_initialized = true
	elif flight.status != FlightModel.Status.PAUSED:
		var blend := 1-exp(-3.4*dt)
		camera_x = lerpf(camera_x,target_x,blend)
		camera_y = lerpf(camera_y,target_y,blend)


func _update_character_animation() -> void:
	if flight.crew_index != previous_crew_index or flight.clock < previous_clock:
		crew_phase = 0
		crew_moving = false
		previous_crew_x = flight.crew_x
	elif flight.clock > previous_clock and flight.crew_index>=0:
		var distance := flight.crew_x-previous_crew_x
		crew_moving = absf(distance)>0.001
		if crew_moving:
			crew_facing = 1 if distance>0 else -1
			crew_phase += absf(distance)*TAU/(40.0 if flight.crew_state==0 else 32.0)
	previous_crew_x = flight.crew_x
	previous_crew_index = flight.crew_index
	previous_clock = flight.clock

func _draw_character(p: Vector2, animation: String, phase: float, facing := 1) -> void:
	var frame := int(fposmod(phase,TAU)/TAU*12)%12
	var destination := Rect2(p+Vector2(-25,-46),Vector2(50,50))
	if facing<0:
		# Godot normalizes the rectangle before flipping its texture. Keep the same bounds.
		destination.size.x = -50
	draw_texture_rect(character_frames[animation][frame],destination,false)

func _world_transform() -> void:
	var factor := world_scale()
	draw_set_transform(-Vector2(camera_x,camera_y)*factor,0,Vector2.ONE*factor)

func _draw() -> void:
	if flight == null or size.y <= 0:
		return
	world_labels.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("718b87"))
	if backdrop:
		var image_size := backdrop.get_size()
		var factor := maxf(size.x / image_size.x, size.y / image_size.y)
		var image_width := image_size.x * factor
		var travel := maxf(0, image_width - size.x)
		var progress := camera_x / maxf(1, float(flight.mission.width) - world_width)
		var vertical_travel := maxf(0,image_size.y*factor-size.y)
		var image_y := -clampf(vertical_travel*0.5+camera_y*0.15,0,vertical_travel)
		draw_texture_rect(backdrop,Rect2(Vector2(-travel*progress,image_y),image_size*factor),false,Color(0.91,0.94,0.88))
	# A soft upper wash and lower shade reproduce the original canvas grading.
	draw_texture_rect(grading,Rect2(Vector2.ZERO,size),false)
	_world_transform()
	_draw_terrain()
	_draw_base()
	_draw_landing_zones()
	for hazard: Dictionary in flight.mission.hazards:
		if _visible(float(hazard.x), 400):
			_draw_hazard(hazard)
	_draw_survivors()
	_draw_ground_crew()
	_draw_birds()
	_draw_helicopter()
	_draw_winch()
	_draw_atmosphere()
	draw_set_transform(Vector2.ZERO)
	_draw_world_labels()

# Labels remain readable independently of the world's camera scale.
func _world_label(point: Vector2, text: String, tint: Color = CREAM) -> void:
	world_labels.append({"point":point,"text":text,"tint":tint})

func _draw_world_labels() -> void:
	var occupied: Array[Rect2] = []
	for label: Dictionary in world_labels:
		var point: Vector2 = world_to_screen(label.point)
		if point.x < 0 or point.x > size.x or point.y < SAFE_TOP or point.y > size.y+40:
			continue
		var extent := SANS.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		var rect := Rect2(point-Vector2(extent.x/2+10,17),Vector2(extent.x+20,34))
		rect.position.x = clampf(rect.position.x,8,maxf(8,size.x-rect.size.x-8))
		rect.position.y = maxf(126,rect.position.y)
		for previous: Rect2 in occupied:
			if rect.intersects(previous.grow(4)):
				var above := previous.position.y-rect.size.y-6
				rect.position.y = above if above >= SAFE_TOP else previous.end.y+6
		occupied.append(rect)
		var box := StyleBoxFlat.new()
		box.bg_color = Color("192c2c")
		box.border_color = Color(label.tint,0.65)
		box.set_border_width_all(1)
		box.set_corner_radius_all(5)
		draw_style_box(box,rect)
		draw_string(SANS,rect.position+Vector2(10,23),label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,label.tint)

func _visible(x: float, margin := 120.0) -> bool:
	return x > camera_x - margin and x < camera_x + world_width + margin

func _poly(points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for p: Array in points:
		polygon.append(Vector2(float(p[0]), float(p[1])))
	draw_colored_polygon(polygon, color)
	if color.a >= 0.9:
		var edge := polygon.duplicate()
		edge.append(polygon[0])
		draw_polyline(edge,color,0.5,true)

func _ellipse(center: Vector2, radius: Vector2, color: Color, outline := false, width := 1.0) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var angle := TAU * i / 48
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if outline:
		draw_polyline(points, color, width, true)
	else:
		draw_colored_polygon(points, color)

func _noise(seed: float) -> float:
	return fposmod(sin(seed * 127.1 + 311.7) * 43758.5453, 1)

func _text(p: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(MONO, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_terrain() -> void:
	var points: Array = flight.mission.terrain
	var fire: bool = flight.mission.theme == "fire"
	var top := Color("4b5037") if fire else Color("465a54") if flight.mission.theme == "coast" else Color("425b4b")
	var terrain := PackedVector2Array([Vector2(0, 950)])
	for point: Dictionary in points:
		terrain.append(Vector2(float(point.x), float(point.y) + 16))
	terrain.append(Vector2(float(flight.mission.width), 950))
	draw_colored_polygon(terrain, Color("293e3d"))
	for i in range(points.size() - 1):
		var a: Dictionary = points[i]
		var b: Dictionary = points[i + 1]
		if float(b.x) < camera_x - 200 or float(a.x) > camera_x + world_width + 200:
			continue
		var middle := float(a.x) + (float(b.x) - float(a.x)) * 0.55
		_poly([[a.x, float(a.y) + 15], [b.x, float(b.y) + 15], [middle, 950]], Color("314745") if i % 2 else Color("243b3c"))
		_poly([[float(a.x) + 5, float(a.y) + 22], [middle - 18, float(a.y) + 115], [float(a.x) + 40, 950]], Color(0.05, 0.11, 0.12, 0.25))
		_poly([[a.x, a.y], [b.x, b.y], [float(b.x) + 15, float(b.y) + 19], [float(a.x) + 15, float(a.y) + 19]], top)
		draw_line(Vector2(float(a.x), float(a.y)), Vector2(float(b.x), float(b.y)), Color("737451") if fire else Color("6f8063"), 1.5, true)
		for j in int((float(b.x) - float(a.x)) / 26):
			var x := float(a.x) + j * 26 + 8
			var y := flight.ground(x)
			draw_line(Vector2(x, y), Vector2(x - 2, y - 4 - _noise(x) * 7), Color(0.62, 0.67, 0.46, 0.35), 1, true)
	if flight.mission.theme == "coast":
		draw_rect(Rect2(camera_x, 724, world_width, 200), Color(0.15, 0.29, 0.31, 0.86))
		for i in 40:
			var x := i * 145 + sin(flight.clock + i) * 12
			draw_line(Vector2(x, 733 + i % 3 * 9), Vector2(x + 65, 733 + i % 3 * 9), Color(0.79, 0.87, 0.82, 0.3), 1, true)
	for tree in flight.trees:
		if _visible(float(tree.x)):
			_tree(float(tree.x), flight.ground(float(tree.x)), float(tree.height), Color("203e38"))

func _tree(x: float, bottom: float, height: float, color: Color) -> void:
	draw_line(Vector2(x,bottom),Vector2(x,bottom-height*0.75),Color("594f3a"),maxf(3,height*0.045),true)
	var canopy := flight.tree_polygon(x,bottom,height)
	draw_colored_polygon(canopy,color)
	var outline := canopy.duplicate()
	outline.append(canopy[0])
	draw_polyline(outline,color.lightened(0.08),0.7,true)
	for j in range(2,7):
		var t := j / 7.0
		var y := bottom-height+height*t
		draw_line(Vector2(x,y-height*0.08),Vector2(x-height*t*0.20,y),color.lightened(0.15),1.5,true)
		draw_line(Vector2(x,y-height*0.07),Vector2(x+height*t*0.19,y+2),color.darkened(0.18),2,true)

func _draw_base() -> void:
	var y := flight.ground(245)-4
	draw_texture_rect(RESCUE_BASE,Rect2(0,y-132,470,164),false)
	_text(Vector2(43,y-63),"RESCUE",8,Color("34433a"))
	_text(Vector2(387,y-22),"F",9,Color("34433a"))
	_world_label(Vector2(245,y-160),"Home base")
	var sway := sin(flight.clock*2)*3
	_poly([[414,y-88],[461,y-78+sway],[460,y-63+sway],[414,y-69]],Color("db743d"))
	_poly([[428,y-85],[437,y-83],[436,y-65],[427,y-67]],Color("dfd3b7"))

func _draw_hazard(hazard: Dictionary) -> void:
	var x := float(hazard.x)
	var bottom := flight.ground(x)
	var top := bottom - float(hazard.height)
	if hazard.type == "tree":
		pass # Trees are drawn from the shared collision geometry.
	elif hazard.type == "fire":
		for i in range(4, 0, -1):
			_ellipse(Vector2(x, bottom - 28), Vector2(35 + i * 12, 22 + i * 8), Color(0.99, 0.38, 0.1, 0.018))
		for j in 7:
			var offset := float(j - 3) * 12
			var height := float(hazard.height) * (0.65 + sin(flight.clock * 8 + j) * 0.18)
			_poly([[x + offset - 16, bottom], [x + offset - 9, bottom - height * 0.5], [x + offset + sin(flight.clock * 6 + j) * 12, bottom - height], [x + offset + 8, bottom - height * 0.35], [x + offset + 16, bottom]], Color("e58442") if j % 2 else Color("d55e32"))
			_poly([[x + offset - 8, bottom], [x + offset + 2, bottom - height * 0.58], [x + offset + 8, bottom]], Color("edbe6e"))
	else:
		var wire := flight.wire_points(hazard)
		for anchor in [wire[0], wire[-1]]:
			_draw_pole(anchor.x, flight.ground(anchor.x), anchor.y - 25)
		draw_polyline(wire, Color("343e38"), 2, true)

func _draw_pole(x: float, bottom: float, top: float) -> void:
	var color := Color("849283")
	draw_line(Vector2(x-18,bottom),Vector2(x-4,top),color,4,true)
	draw_line(Vector2(x+18,bottom),Vector2(x+4,top),color,4,true)
	for j in 6:
		var t := j / 6.0
		var y := lerpf(top,bottom,t)
		var next_y := lerpf(top,bottom,(j+1)/6.0)
		var w := lerpf(4,18,t)
		var next_w := lerpf(4,18,(j+1)/6.0)
		draw_line(Vector2(x-w,y),Vector2(x+next_w,next_y),color,1.5,true)
		draw_line(Vector2(x+w,y),Vector2(x-next_w,next_y),color.darkened(0.2),1,true)
	draw_line(Vector2(x-25,top+25),Vector2(x+25,top+25),color,3,true)
	for offset in [-20,0,20]:
		draw_rect(Rect2(x+offset-3,top+19,6,8),Color("bbc5ad"))
	draw_circle(Vector2(x,top),3,ORANGE if sin(flight.clock*3)>0 else ORANGE.darkened(0.6))

func _draw_landing_zones() -> void:
	for target: Dictionary in flight.mission.targets:
		if target.get("mode","winch")!="landing":
			continue
		var x := float(target.landing_x)
		var y := flight.ground(x)
		if not _visible(x,240):
			continue
		# A rough clearing with a temporary fabric marker, not another built helipad.
		draw_texture_rect(FIELD_PAD,Rect2(x-100,y-6,200,24),false)
		for i in 18:
			var offset := -83+i*9
			var dust := _noise(x+i)
			draw_line(Vector2(x+offset,y+3+dust*7),Vector2(x+offset+4,y+3+dust*7),Color("9b9470"),1.2,true)

		for side in [-1,1]:
			var pole := Vector2(x+side*94,y)
			draw_line(pole,pole-Vector2(0,35),Color("a69971"),2,true)
			var flap := sin(flight.clock*3+side)*3
			_poly([[pole.x,pole.y-35],[pole.x+20,pole.y-31+flap],[pole.x,pole.y-23]],Color("d6a66d"))
		_world_label(Vector2(x,y-160),"Field landing",Color("d6e9b5"))
		for side in [-1,1]:
			var marker := Vector2(x+side*112,y-7)
			draw_line(marker,marker+Vector2(-side*12,-7),Color("c4e1ad"),2,true)
			draw_line(marker,marker+Vector2(-side*12,7),Color("c4e1ad"),2,true)

func _draw_ground_crew() -> void:
	if flight.crew_index<0:
		return
	var p := Vector2(flight.crew_x,flight.ground(flight.crew_x))
	var pose := "rescuer_help" if flight.crew_state==1 else "rescuer_walk" if crew_moving and flight.crew_state==2 else "rescuer_run" if crew_moving else "rescuer_idle"
	var phase := crew_phase if crew_moving else flight.clock*(5 if flight.crew_state==1 else 2)
	_draw_character(p,pose,phase,crew_facing)
	if flight.crew_state==2:
		var escort_x := p.x-crew_facing*22
		var escort := Vector2(escort_x,flight.ground(escort_x))
		_draw_character(escort,"survivor_walk" if crew_moving else "survivor_idle",crew_phase+0.5 if crew_moving else flight.clock*2,crew_facing)
	if flight.crew_state!=1:
		_world_label(p+Vector2(0,-85),"Rescuer")

func _draw_survivors() -> void:
	for i in flight.targets.size():
		if flight.targets[i] != FlightModel.Survivor.WAITING and flight.contact != i:
			continue
		var target: Dictionary = flight.mission.targets[i]
		var p := Vector2(float(target.x), float(target.y))
		if not _visible(p.x):
			continue
		_ellipse(p + Vector2(0, -1), Vector2(28, 6), Color(0.94, 0.52, 0.25, 0.5), true, 1.3)
		if flight.targets[i] == FlightModel.Survivor.WAITING:
			_person(p)
		var center := flight.pickup_center(i)
		var ground_rescue: bool = target.get("mode","winch") == "landing" and flight.crew_index == i
		var ground_distance := absf(flight.crew_x-p.x)
		var active := (ground_rescue and flight.crew_state==1) or flight.contact == i
		var ready := not ground_rescue and active and flight.winch == FlightModel.Winch.READY_TO_HOIST
		var approaching: bool = (ground_rescue and flight.crew_state==0 and ground_distance<140) or (target.get("mode","winch") != "landing" and flight.cable > 0 and flight.hook_position().distance_to(center) < 230)
		if active or approaching:
			var tint := Color("9dd6a0") if ready else ORANGE
			var radius := FlightModel.PICKUP_RADIUS
			draw_circle(center,radius,Color(tint,0.12 if active else 0.06))
			draw_arc(center,radius,0,TAU,64,Color(tint,0.75),1.5,true)
			if active:
				draw_arc(center,radius+6,0,TAU,64,Color(tint,0.2),1,true)
				var duration := 3.0 if ground_rescue else flight.pickup_duration(i)
				var progress := flight.crew_progress if ground_rescue else flight.pickup_progress
				var fraction := 1.0 if ready else clampf(progress/duration,0,1)
				draw_arc(center,radius,-PI/2,-PI/2+TAU*maxf(0.001,fraction),64,Color("d7f1aa"),3.5,true)
				_world_label(center+Vector2(0,-radius-24),"Ready to hoist" if ready else "%.1f s" % maxf(0,duration-progress),tint)
			else:
				var prompt := ("Tap rescue to help" if ground_distance<20 else "Walk closer") if ground_rescue else "Keep hook here"
				_world_label(center+Vector2(0,-radius-24),prompt,tint)
		# The numbered orange locator, dotted line and smoke match the original.
		var tag := p - Vector2(21, 157)
		if not active and not approaching:
			_world_label(p-Vector2(0,145),"%02d%s" % [i+1," · Land rescue" if target.get("mode","winch")=="landing" else ""],ORANGE)
		for j in 9:
			var y := tag.y + 47 + j * 7
			draw_line(Vector2(p.x, y), Vector2(p.x, y + 2), Color(0.96, 0.58, 0.33, 0.5), 1)
		for j in 6:
			var progress := fposmod(flight.clock * 0.15 + j / 6.0, 1)
			var smoke := p + Vector2(38 + sin(progress * 7 + i) * 10, -8 - progress * 90)
			draw_circle(smoke, 4 + progress * 10, Color(0.9, 0.56, 0.32, (1 - progress) * 0.24))

func _person(p: Vector2) -> void:
	var time := flight.clock+p.x*0.013
	var waving := fposmod(time,5.0)<3.5
	_draw_character(p,"survivor_wave" if waving else "survivor_idle",time*(5 if waving else 2))

func _draw_winch() -> void:
	if flight.cable <= 0:
		return
	var hook := flight.hook_position()
	draw_polyline(flight.winch_points(),Color(0.06,0.13,0.12,0.4),3,true)
	draw_polyline(flight.winch_points(),CREAM,1.5,true)
	draw_line(hook,flight.rig_position(),CREAM,1.5,true)
	draw_arc(hook, 6, 0, PI * 1.6, 16, ORANGE, 2, true)
	if flight.cable>=22:
		_draw_rescue_rig(flight.rig_position())

func _draw_specialist(p: Vector2, working: bool) -> void:
	_draw_character(p,"rescuer_help" if working else "rescuer_idle",flight.clock*(5 if working else 2))

func _draw_rescue_rig(hook: Vector2) -> void:
	# Four-point bridle, basket stretcher, and a blue-uniformed rescue specialist.
	var left := hook + Vector2(-27,25)
	var right := hook + Vector2(27,25)
	draw_line(hook,left,CREAM,1,true)
	draw_line(hook,right,CREAM,1,true)
	draw_line(left,right,Color("e7a45d"),4,true)
	draw_polyline(PackedVector2Array([left-Vector2(2,5),left+Vector2(0,4),right+Vector2(0,4),right+Vector2(2,-5)]),CREAM,2,true)
	_draw_specialist(hook+Vector2(-18,32),flight.contact>=0 and flight.attached<0)
	if flight.attached >= 0:
		draw_texture_rect(PATIENT,Rect2(hook+Vector2(-12,10),Vector2(44,18)),false)
		for x in [-3,12]:
			draw_line(hook+Vector2(x,14),hook+Vector2(x,25),CREAM,2,true)


func _draw_helicopter() -> void:
	var p := flight.position
	var factor := world_scale()
	# Soft ground shadow gives the aircraft height without changing its silhouette.
	var altitude := flight.ground(p.x) - p.y
	_ellipse(Vector2(p.x + 12, flight.ground(p.x) + 8), Vector2(66, 7), Color(0.03, 0.08, 0.07, clampf(0.23 - altitude * 0.0004, 0.02, 0.2)))
	draw_set_transform(world_to_screen(p), flight.velocity.x * 0.00045, Vector2(flight.facing, 1) * factor)
	draw_texture_rect(HELICOPTER_FLASH if flight.invincible > 0 and int(flight.clock * 12) % 2 == 0 else HELICOPTER_BODY,Rect2(-190,-80,290,135),false)
	var rotor_center := Vector2(-155, -29)
	var tail_angle := flight.clock * 33
	for j in 2:
		var direction := Vector2(cos(tail_angle + j * PI / 2), sin(tail_angle + j * PI / 2)) * 25
		draw_line(rotor_center - direction, rotor_center + direction, Color("b9c7ba"), 3, true)
	draw_circle(rotor_center, 5, Color("304f4c"))
	# Only one rescuer: doorway, winch rig, or ground crew.
	if flight.crew_index<0 and flight.cable<22:
		_draw_specialist(Vector2(-14,20),false)
	_ellipse(Vector2(-7,-70),Vector2(143,7),Color(0.15,0.24,0.22,0.13))
	var length := 115 + absf(sin(flight.clock * 42)) * 32
	draw_line(Vector2(-7-length,-70-sin(flight.clock*28)*2),Vector2(-7+length,-70+sin(flight.clock*28)*2),Color(0.16,0.22,0.19,0.85),3,true)
	draw_circle(Vector2(-146,-61),2.5,Color("f2a674") if sin(flight.clock*5)>0.5 else Color("a64e2d"))
	_world_transform()

func _draw_birds() -> void:
	for i in flight.birds.size():
		var bird := flight.bird_position(i)
		var state: Dictionary = flight.birds[i]
		var alpha := 1.0
		var angle := 0.0
		var flap := sin(flight.clock * 4 + i) * 6
		if state.dead:
			alpha *= clampf(5.0 - float(state.age),0,1)
			if alpha <= 0:
				continue
			angle = float(state.age) * 7 if not state.grounded else 1.2
			flap = -3 # Folded wings; no flapping after a strike.
		var silhouette := PackedVector2Array([Vector2(-8,-flap),Vector2(-4,-3),Vector2.ZERO,Vector2(4,-3),Vector2(8,-flap)])
		for j in silhouette.size():
			silhouette[j] = bird + (silhouette[j]*1.8).rotated(angle)
		draw_polyline(silhouette,Color(0.88,0.88,0.73,alpha*0.75),5,true)
		draw_polyline(silhouette,Color(0.08,0.14,0.13,alpha),3,true)

func _draw_atmosphere() -> void:
	for i in 6:
		var x := camera_x + fposmod(i * 390 + flight.clock * (4 + i) - camera_x * 0.12, world_width + 600) - 200
		var y := 500 + i % 3 * 55
		for j in range(5, 0, -1):
			_ellipse(Vector2(x,y),Vector2(j*48,j*11),Color(0.79,0.86,0.8,0.009))
	if flight.mission.theme == "fire":
		for i in 32:
			var x := camera_x + fposmod(_noise(i) * world_width + flight.clock * (4 + _noise(i+5)*12), world_width)
			var y := 760 - fposmod(_noise(i+3)*760+flight.clock*(8+_noise(i+9)*16),760)
			draw_circle(Vector2(x,y),1+_noise(i+6),Color(0.98,0.64,0.31,0.25+_noise(i+7)*0.4))
